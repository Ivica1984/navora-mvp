#!/usr/bin/env node
// Validates the official agent collaboration layer in docs/agents/ (approved 2026-10-21):
//   NEXT_CAPABILITY.md (po) · IMPLEMENTATION_STATUS.md (eng) · OPEN_DECISIONS.md (all)
// Reads the first Markdown table under a given heading. No dependencies, so it also runs
// in agent sandboxes without `npm ci`. Protocol and table formats: docs/agents/README.md
//   node scripts/agents-check.mjs     (AGENTS_DIR overrides the folder, for tests)

import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const DIR = process.env.AGENTS_DIR ?? join(dirname(fileURLToPath(import.meta.url)), "..", "docs", "agents");

const PO_STATUS = ["draft", "approved", "accepted", "changes-requested", "withdrawn"];
const STATE = ["not-started", "analysing", "in-progress", "in-review", "ready-for-review", "delivered", "blocked"];
const ORIGIN = ["po", "eng-proposal"];
const OWNER = ["po", "eng", "owner", "legal", "clinical"];
const KIND = ["product", "technical", "legal", "financial", "regulatory", "clinical", "production"];
const NON_ENG_KINDS = ["legal", "financial", "regulatory", "clinical", "production"];
const ID = /^[A-Z][A-Z0-9]*(-[A-Za-z0-9]+)*$/;
const NONE = new Set(["", "–", "-", "—"]);

const errors = [];
const warnings = [];

function read(file) {
  const path = join(DIR, file);
  if (!existsSync(path)) {
    errors.push(`${file}: missing`);
    return "";
  }
  return readFileSync(path, "utf8");
}

/** First Markdown table under `## heading` → array of row objects keyed by header cell. */
function table(file, text, heading, columns) {
  const lines = text.split("\n");
  const start = lines.findIndex((l) => l.trim() === `## ${heading}`);
  if (start < 0) {
    errors.push(`${file}: heading "## ${heading}" not found`);
    return [];
  }
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
      const expected = columns.join(" | ");
      if (header.join(" | ") !== expected) errors.push(`${file}: "${heading}" columns must be: ${expected}`);
      continue;
    }
    if (cells.every((c) => /^:?-+:?$/.test(c))) continue;
    if (cells.length !== header.length) {
      errors.push(`${file}: row "${cells[0]}" has ${cells.length} cells, expected ${header.length}`);
      continue;
    }
    rows.push(Object.fromEntries(header.map((h, j) => [h, cells[j]])));
  }
  return rows;
}

const list = (v) => (NONE.has((v ?? "").trim()) ? [] : v.split(",").map((s) => s.trim()).filter(Boolean));
const bare = (v) => (v ?? "").replace(/[`*]/g, "").trim();

function enumCheck(file, id, col, value, allowed) {
  if (!allowed.includes(bare(value))) errors.push(`${file}: ${id}: ${col} "${value}" must be one of ${allowed.join(", ")}`);
}

function ids(file, rows) {
  const seen = new Set();
  for (const r of rows) {
    const id = bare(r.ID);
    if (!ID.test(id)) errors.push(`${file}: invalid ID "${r.ID}"`);
    if (seen.has(id)) errors.push(`${file}: duplicate ID ${id}`);
    seen.add(id);
  }
  return seen;
}

const queue = table("NEXT_CAPABILITY.md", read("NEXT_CAPABILITY.md"), "Priority queue",
  ["Rank", "ID", "Capability", "PO status", "Brief", "Why"]);
const status = table("IMPLEMENTATION_STATUS.md", read("IMPLEMENTATION_STATUS.md"), "Items",
  ["ID", "Origin", "State", "Summary", "Next", "PRs", "ADRs", "Blocked by", "Deviations"]);
const decText = read("OPEN_DECISIONS.md");
const open = table("OPEN_DECISIONS.md", decText, "Open",
  ["ID", "Owner", "Kind", "Question", "Recommendation", "Blocks", "Opened"]);
const decided = table("OPEN_DECISIONS.md", decText, "Decided", ["ID", "Owner", "Answer", "Date"]);

const queueIds = ids("NEXT_CAPABILITY.md", queue);
const statusIds = ids("IMPLEMENTATION_STATUS.md", status);
const openIds = ids("OPEN_DECISIONS.md", open);
const decidedIds = new Set(decided.map((d) => bare(d.ID)));
for (const id of openIds) if (decidedIds.has(id)) errors.push(`OPEN_DECISIONS.md: ${id} is both open and decided`);

// Priority queue (po)
queue.forEach((q, i) => {
  const id = bare(q.ID);
  if (Number(q.Rank) !== i + 1) errors.push(`NEXT_CAPABILITY.md: ${id}: rank ${q.Rank} should be ${i + 1} (ranks follow the row order)`);
  enumCheck("NEXT_CAPABILITY.md", id, "PO status", q["PO status"], PO_STATUS);
  const brief = list(q.Brief)[0];
  if (brief) {
    const path = brief.replace(/^.*\]\(/, "").replace(/\)$/, "").replace(/`/g, "");
    if (!existsSync(join(DIR, path))) errors.push(`NEXT_CAPABILITY.md: ${id}: brief ${path} does not exist`);
  } else if (bare(q["PO status"]) === "approved") {
    warnings.push(`${id} is approved but has no brief`);
  }
  if (!statusIds.has(id)) errors.push(`NEXT_CAPABILITY.md: ${id} has no row in IMPLEMENTATION_STATUS.md (engineering must acknowledge every priority)`);
});

// Implementation status (eng)
for (const s of status) {
  const id = bare(s.ID);
  enumCheck("IMPLEMENTATION_STATUS.md", id, "Origin", s.Origin, ORIGIN);
  enumCheck("IMPLEMENTATION_STATUS.md", id, "State", s.State, STATE);
  // origin po: in the PO queue, or a published PO brief (draft items waiting to enter the queue)
  if (bare(s.Origin) === "po" && !queueIds.has(id) && !existsSync(join(DIR, "briefs", `${id}.md`))) {
    errors.push(`IMPLEMENTATION_STATUS.md: ${id}: origin po but neither in NEXT_CAPABILITY.md nor in briefs/`);
  }
  const blockers = list(s["Blocked by"]).map(bare);
  for (const b of blockers) if (!openIds.has(b)) errors.push(`IMPLEMENTATION_STATUS.md: ${id}: blocked by ${b}, which is not an open decision`);
  if (bare(s.State) === "blocked" && blockers.length === 0) errors.push(`IMPLEMENTATION_STATUS.md: ${id}: state blocked requires "Blocked by"`);
  const prs = list(s.PRs);
  if (bare(s.State) === "delivered" && prs.length === 0) errors.push(`IMPLEMENTATION_STATUS.md: ${id}: state delivered requires PRs`);
  for (const pr of prs) if (!/^#\d+$/.test(pr)) errors.push(`IMPLEMENTATION_STATUS.md: ${id}: PR "${pr}" must look like #23`);
  const q = queue.find((x) => bare(x.ID) === id);
  if (q && bare(s.State) === "delivered" && bare(q["PO status"]) === "approved") warnings.push(`${id} is delivered and waits for PO acceptance`);
}

// Decisions (all)
for (const d of open) {
  const id = bare(d.ID);
  enumCheck("OPEN_DECISIONS.md", id, "Owner", d.Owner, OWNER);
  enumCheck("OPEN_DECISIONS.md", id, "Kind", d.Kind, KIND);
  if (NON_ENG_KINDS.includes(bare(d.Kind)) && bare(d.Owner) === "eng") {
    errors.push(`OPEN_DECISIONS.md: ${id}: ${bare(d.Kind)} decisions cannot be owned by eng`);
  }
  for (const b of list(d.Blocks).map(bare)) {
    if (!statusIds.has(b)) errors.push(`OPEN_DECISIONS.md: ${id} blocks ${b}, which has no row in IMPLEMENTATION_STATUS.md`);
  }
}
for (const d of decided) {
  enumCheck("OPEN_DECISIONS.md", bare(d.ID), "Owner", d.Owner, OWNER);
  if (NONE.has(d.Answer.trim())) errors.push(`OPEN_DECISIONS.md: ${bare(d.ID)}: decided without an answer`);
}

if (errors.length) {
  console.error("docs/agents is inconsistent:\n- " + errors.join("\n- "));
  process.exit(1);
}
console.log(
  `agents: ok (${queue.length} priorities, ${status.length} status rows, ${open.length} open / ${decided.length} decided decisions)` +
    (warnings.length ? `\nneeds attention:\n- ${warnings.join("\n- ")}` : "")
);
