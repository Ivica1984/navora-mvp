// Pure Markdown-table reader for the agent collaboration layer (docs/agents).
// Same table rules as scripts/agents-check.mjs: the first table under "## <heading>".

export const NONE = new Set(["", "–", "-", "—"]);
export const bare = (v) => (v ?? "").replace(/[`*]/g, "").trim();
export const list = (v) => (NONE.has((v ?? "").trim()) ? [] : bare(v).split(",").map((s) => s.trim()).filter(Boolean));

/** Heading match: exact, or a prefix followed by a space or "(" (e.g. "## Next up (approved briefs …)"). */
export function parseTable(text, heading) {
  const lines = (text ?? "").split("\n");
  const h = `## ${heading}`;
  const start = lines.findIndex((l) => {
    const t = l.trim();
    return t === h || t.startsWith(`${h} `) || t.startsWith(`${h}(`);
  });
  if (start < 0) return [];
  const rows = [];
  let header = null;
  for (let i = start + 1; i < lines.length; i++) {
    const line = lines[i].trim();
    if (line.startsWith("## ")) break;
    if (!line.startsWith("|")) {
      if (header) break;
      continue;
    }
    const cells = line.replace(/^\|/, "").replace(/\|$/, "").split(/(?<!\\)\|/).map((c) => c.trim());
    if (!header) {
      header = cells;
      continue;
    }
    if (cells.every((c) => /^:?-+:?$/.test(c))) continue;
    if (cells.length !== header.length) continue;
    rows.push(Object.fromEntries(header.map((h, j) => [h, cells[j]])));
  }
  return rows;
}

/**
 * The three official files (plus, since COORD5, the decision-package index and package files) → typed rows.
 * `index` is decisions/INDEX.md; `packageFiles` maps a file name in decisions/ (e.g. "D-22.md") to its text.
 * @param {{ next: string, status: string, decisions: string, index?: string, packageFiles?: Record<string, string> }} texts
 */
export function readLayerTexts({ next, status, decisions, index = "", packageFiles = {} }) {
  return {
    packages: readPackageIndex(index).map((p) => ({
      ...p,
      approval: p.file && packageFiles[p.file] !== undefined ? packageSection(packageFiles[p.file], "Owner approval required?") : "",
    })),
    queue: [
      ...parseTable(next, "Priority queue").map((r) => ({
        rank: Number(bare(r.Rank)), id: bare(r.ID), capability: r.Capability, poStatus: bare(r["PO status"]), brief: r.Brief,
      })),
      // "Next up": approved briefs the PO has lined up after the queue (ranked after it, in their order).
      ...parseTable(next, "Next up").map((r, i) => ({
        rank: 1000 + (Number(bare(r.Order)) || i + 1), id: bare(r.ID), capability: r.Capability, poStatus: "approved", brief: r.Brief,
      })),
    ],
    status: parseTable(status, "Items").map((r) => ({
      id: bare(r.ID), origin: bare(r.Origin), state: bare(r.State), summary: r.Summary, next: r.Next,
      prs: list(r.PRs), blockedBy: list(r["Blocked by"]),
    })),
    open: parseTable(decisions, "Open").map((r) => ({
      id: bare(r.ID), owner: bare(r.Owner), kind: bare(r.Kind), question: r.Question, recommendation: r.Recommendation,
      blocks: list(r.Blocks),
    })),
    decided: parseTable(decisions, "Decided").map((r) => ({ id: bare(r.ID), owner: bare(r.Owner), answer: r.Answer, date: r.Date })),
  };
}

// ---- Decision packages (COORD5, docs/agents/DECISION_PACKAGES.md) ----

/** Package status values, in DECISION_PACKAGES.md "Package status". */
export const PACKAGE_STATUS = [
  "not-started", "inputs-requested", "po-decided",
  "awaiting-approval: owner", "awaiting-approval: clinical", "awaiting-approval: legal", "decided",
];
export const AWAITING = /^awaiting-approval: (owner|clinical|legal)$/;

/** First Markdown table in a file that has no "## " heading above it (decisions/INDEX.md). */
export function parseFirstTable(text) {
  const lines = (text ?? "").split("\n");
  const rows = [];
  let header = null;
  for (const raw of lines) {
    const line = raw.trim();
    if (!line.startsWith("|")) {
      if (header) break;
      continue;
    }
    const cells = line.replace(/^\|/, "").replace(/\|$/, "").split(/(?<!\\)\|/).map((c) => c.trim());
    if (!header) {
      header = cells;
      continue;
    }
    if (cells.every((c) => /^:?-+:?$/.test(c))) continue;
    if (cells.length !== header.length) continue;
    rows.push(Object.fromEntries(header.map((h, j) => [h, cells[j]])));
  }
  return rows;
}

/**
 * "[awaiting-approval: owner](D-22.md) (2026-10-24 05:15; …)" → { status: "awaiting-approval: owner", file: "D-22.md" }
 * "not-started" → { status: "not-started", file: null }. The status is returned as written; callers check it
 * against PACKAGE_STATUS.
 */
export function packageStatusOf(cell) {
  const s = (cell ?? "").trim();
  const link = s.match(/^\[([^\]]+)\]\(([^)]+)\)/);
  if (link) return { status: bare(link[1]), file: link[2].trim() };
  return { status: bare(s.split(/\s\(/)[0]), file: null };
}

/** decisions/INDEX.md → [{ id, status, file }] (rows in INDEX order). */
export function readPackageIndex(text) {
  return parseFirstTable(text)
    .filter((r) => r["Package status"] !== undefined)
    .map((r) => ({ id: bare(r.ID), ...packageStatusOf(r["Package status"]) }));
}

/** The body of "## <heading>" in a package file (up to the next "## "), trimmed; "" when absent. */
export function packageSection(text, heading) {
  const lines = (text ?? "").split("\n");
  const start = lines.findIndex((l) => l.trim().startsWith(`## ${heading}`));
  if (start < 0) return "";
  const out = [];
  for (let i = start + 1; i < lines.length; i++) {
    if (lines[i].trim().startsWith("## ")) break;
    out.push(lines[i]);
  }
  return out.join("\n").trim();
}
