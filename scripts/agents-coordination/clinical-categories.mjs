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
