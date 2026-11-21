// DOOR1-14 (CGR-61, migration 0080, ADR-093): a migration that inserts a `clinical` row into
// public.safety_alert_categories must name, in `approval_ref`, a Clinical Rule Register row with status APPROVED
// (docs/agents/clinical/CLINICAL_RULE_REGISTER.md). The database checks only the form CR-nnn; this check, run by
// scripts/agents-check.mjs, checks the register. No dependencies.

/** Split a SQL VALUES list body into tuples of raw cell strings. Handles quoted literals ('' escapes) and nesting. */
function tuples(text) {
  const out = [];
  let depth = 0;
  let cell = "";
  let row = null;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (ch === "'") {
      let j = i + 1;
      while (j < text.length) {
        if (text[j] === "'" && text[j + 1] === "'") j += 2;
        else if (text[j] === "'") break;
        else j += 1;
      }
      if (row) cell += text.slice(i, j + 1);
      i = j;
      continue;
    }
    if (ch === "(") {
      depth += 1;
      if (depth === 1) { row = []; cell = ""; continue; }
    } else if (ch === ")") {
      depth -= 1;
      if (depth === 0 && row) { row.push(cell.trim()); out.push(row); row = null; continue; }
    } else if (ch === "," && depth === 1 && row) {
      row.push(cell.trim());
      cell = "";
      continue;
    }
    if (row) cell += ch;
  }
  return out;
}

const literal = (cell) => {
  const m = /^'((?:[^']|'')*)'(?:::\w+)?$/.exec(cell ?? "");
  return m ? m[1].replace(/''/g, "'") : null;
};

/**
 * Every insert into safety_alert_categories in `sql` that mentions 'clinical': { code, approvalRef, parsed }.
 * `parsed` is false when the statement could not be read (a SELECT form, a missing column list): fail closed.
 */
export function clinicalCategoryInserts(sql) {
  const found = [];
  const stripped = sql.replace(/--[^\n]*/g, "");
  const re = /insert\s+into\s+(?:public\.)?safety_alert_categories\b([\s\S]*?);/gi;
  let m;
  while ((m = re.exec(stripped))) {
    const body = m[1];
    if (!/'clinical'/i.test(body)) continue;
    const cols = /^\s*\(([^)]*)\)\s*values\s*([\s\S]*)$/i.exec(body);
    if (!cols) { found.push({ code: null, approvalRef: null, parsed: false }); continue; }
    const names = cols[1].split(",").map((c) => c.trim().toLowerCase());
    const iClass = names.indexOf("class");
    const iCode = names.indexOf("code");
    const iRef = names.indexOf("approval_ref");
    for (const row of tuples(cols[2].replace(/\bon\s+conflict[\s\S]*$/i, ""))) {
      const cls = literal(row[iClass]);
      if (iClass < 0 || cls === null) { found.push({ code: literal(row[iCode]), approvalRef: null, parsed: false }); continue; }
      if (cls !== "clinical") continue;
      found.push({ code: literal(row[iCode]), approvalRef: iRef < 0 ? null : literal(row[iRef]), parsed: true });
    }
  }
  return found;
}

/** Register rows by ID with their Status cell (table under "## Rules"). */
export function registerStatus(registerText) {
  const status = new Map();
  for (const line of registerText.split("\n")) {
    const cells = line.split("|").map((c) => c.trim());
    if (cells.length < 9 || !/^CR-\d{3}$/.test(cells[1])) continue;
    status.set(cells[1], cells[7].replace(/[`*]/g, ""));
  }
  return status;
}

/** Errors for `files` ([{ name, sql }]) against the register text (null = register missing). */
export function clinicalCategoryErrors(files, registerText) {
  const errors = [];
  const status = registerText === null ? null : registerStatus(registerText);
  for (const f of files) {
    for (const ins of clinicalCategoryInserts(f.sql)) {
      const what = `${f.name}: clinical safety-alert category ${ins.code ?? "(unreadable)"}`;
      if (!ins.parsed) { errors.push(`${what}: insert could not be read; write it as INSERT … (columns) VALUES (…) with literals`); continue; }
      if (!ins.approvalRef || !/^CR-\d{3}$/.test(ins.approvalRef)) { errors.push(`${what}: approval_ref must name a register row CR-nnn`); continue; }
      if (status === null) { errors.push(`${what}: clinical/CLINICAL_RULE_REGISTER.md is missing`); continue; }
      const s = status.get(ins.approvalRef);
      if (s !== "APPROVED") errors.push(`${what}: ${ins.approvalRef} is ${s ? `"${s}"` : "not in the register"}, needs APPROVED (DOOR1-14)`);
    }
  }
  return errors;
}

// COND1-10 = DOOR1-16 (PO 2026-10-26 14:30, CGR-68, interim part; ADR-097): a register row with status APPROVED must
// name an approval record, a file docs/agents/clinical/approvals/CR-nnn.md with the approver's role, the G-1 reference
// and the date. The Status cell alone, which any PR can change, is not enough. The required review by the named
// Clinical Owner (CODEOWNERS or similar) is the owner's, after G-1, and not checked here.

/** The approval record's path relative to docs/agents/clinical/, for a register ID. */
export const approvalRecordPath = (id) => `approvals/${id}.md`;

/** The register row's cells by ID (table under "## Rules"): the whole row text, to check that it names the record. */
function registerRows(registerText) {
  const rows = new Map();
  for (const line of registerText.split("\n")) {
    const cells = line.split("|").map((c) => c.trim());
    if (cells.length < 9 || !/^CR-\d{3}$/.test(cells[1])) continue;
    rows.set(cells[1], line);
  }
  return rows;
}

/** A field "Label: value" of an approval record (markdown emphasis and a list bullet are ignored), or null. */
function recordField(text, label) {
  for (const raw of text.split("\n")) {
    const line = raw.replace(/[*_`]/g, "").replace(/^\s*[-+]\s+/, "").trim();
    const m = new RegExp(`^${label}\\s*:\\s*(\\S.*)$`, "i").exec(line);
    if (m) return m[1].trim();
  }
  return null;
}

/** What an approval record lacks: [] when it names the approver's role, a G-1 reference and an ISO date. */
export function approvalRecordMissing(text) {
  const missing = [];
  if (!recordField(text, "Approver role")) missing.push("Approver role");
  if (!/\bG-1\b/.test(recordField(text, "G-1 reference") ?? "")) missing.push("G-1 reference");
  const date = recordField(text, "Date");
  if (!date || !/^\d{4}-\d{2}-\d{2}\b/.test(date)) missing.push("Date (YYYY-MM-DD)");
  return missing;
}

/**
 * Errors for every APPROVED register row: the row must name its record (approvals/CR-nnn.md) and the record must exist
 * with its three fields. `readRecord(relativePath)` returns the file text or null when the file is missing.
 */
export function approvalRecordErrors(registerText, readRecord) {
  if (registerText === null) return [];
  const errors = [];
  const rows = registerRows(registerText);
  for (const [id, status] of registerStatus(registerText)) {
    if (status !== "APPROVED") continue;
    const path = approvalRecordPath(id);
    if (!rows.get(id).includes(path)) {
      errors.push(`clinical/CLINICAL_RULE_REGISTER.md: ${id} is APPROVED but names no approval record (${path}) (DOOR1-16)`);
      continue;
    }
    const text = readRecord(path);
    if (text === null) {
      errors.push(`clinical/${path}: missing; ${id} is APPROVED (DOOR1-16)`);
      continue;
    }
    const missing = approvalRecordMissing(text);
    if (missing.length) errors.push(`clinical/${path}: names no ${missing.join(", no ")} (DOOR1-16)`);
  }
  return errors;
}
