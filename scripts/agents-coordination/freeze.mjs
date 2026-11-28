// COORD6 (ADR-110): frozen decision packages stay frozen without anyone watching.
// DECISION_PACKAGES.md "Frozen packages", README rule 9 (STR-17 F1, F2). Format checks on docs/agents only:
// the check enforces that an unfreeze trigger is NAMED; whether it is true is the reviewer's judgement.
//
// Pure functions (unit-tested) plus one git reader (`readBase`) that only runs `git show <rev>:<docs/agents path>`.

import { execFileSync } from "node:child_process";
import { AWAITING, bare, packageStatusOf, parseFirstTable, readPackageIndex } from "./parse.mjs";

/** COORD6-1: the marker directly after the status link, e.g. "[awaiting-approval: owner](D-22.md) · frozen since 2026-10-27 14:45". */
export const FROZEN_MARKER = /^\[[^\]]+\]\([^)]+\)\s*(?:·\s*)?frozen since \d{4}-\d{2}-\d{2} \d{2}:\d{2}(?!\d)/;
/** COORD6-2: a line in a package file. */
export const UNFREEZE_LINE = /^Unfreeze: [1-5] \S/;
/** COORD6-3: a reference inside a table row. */
export const UNFREEZE_REF = /Unfreeze: [1-5] /g;
/** COORD6-4: from this instant the journal finding is an error (2026-11-04 00:00 Europe/Zurich = CET, UTC+1). */
export const JOURNAL_ERROR_FROM = new Date("2026-11-03T23:00:00Z");
const NO_NEW_EVIDENCE = /no new evidence/i;

const escape = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const mentions = (text, id) => new RegExp(`(?<![A-Za-z0-9-])${escape(id)}(?![A-Za-z0-9])`).test(text);
const unfreezeRefs = (text) => (text ?? "").match(UNFREEZE_REF)?.length ?? 0;

/** COORD6-1. `indexText` is decisions/INDEX.md as it is now. */
export function frozenMarkerErrors(indexText) {
  const errors = [];
  for (const r of parseFirstTable(indexText)) {
    if (r["Package status"] === undefined) continue;
    const id = bare(r.ID);
    const cell = (r["Package status"] ?? "").trim();
    const { status } = packageStatusOf(cell);
    if (AWAITING.test(status) && !FROZEN_MARKER.test(cell)) {
      errors.push(`decisions/INDEX.md: ${id}: "${status}" needs "frozen since YYYY-MM-DD HH:MM" directly after the status link (README rule 9, COORD6-1)`);
    }
  }
  return errors;
}

/**
 * Raw row line per ID in a table: the first table under "## <heading>" (heading null = first table in the file).
 * Returns Map<id, line>.
 */
export function rowLines(text, heading) {
  const lines = (text ?? "").split("\n");
  let i = 0;
  if (heading) {
    i = lines.findIndex((l) => l.trim() === `## ${heading}` || l.trim().startsWith(`## ${heading} `));
    if (i < 0) return new Map();
    i += 1;
  }
  const out = new Map();
  let idCol = -1;
  for (; i < lines.length; i++) {
    const line = lines[i].trim();
    if (heading && line.startsWith("## ")) break;
    if (!line.startsWith("|")) {
      if (idCol >= 0) break;
      continue;
    }
    const cells = line.replace(/^\|/, "").replace(/\|$/, "").split(/(?<!\\)\|/).map((c) => c.trim());
    if (idCol < 0) {
      idCol = cells.indexOf("ID");
      if (idCol < 0) return out;
      continue;
    }
    if (cells.every((c) => /^:?-+:?$/.test(c))) continue;
    const id = bare(cells[idCol]);
    if (id && !out.has(id)) out.set(id, lines[i]);
  }
  return out;
}

/** Lines of `head` that are not in `base` (multiset difference: the lines a diff adds). */
export function addedLines(base, head) {
  const count = new Map();
  for (const l of (base ?? "").split("\n")) count.set(l, (count.get(l) ?? 0) + 1);
  const out = [];
  for (const l of (head ?? "").split("\n")) {
    const n = count.get(l) ?? 0;
    if (n > 0) count.set(l, n - 1);
    else out.push(l);
  }
  return out;
}

/** JOURNAL.md → [{ heading, text }], one per "## " entry. */
export function journalEntries(text) {
  const entries = [];
  let cur = null;
  for (const line of (text ?? "").split("\n")) {
    if (line.startsWith("## ")) {
      cur = { heading: line.trim(), text: line };
      entries.push(cur);
    } else if (cur) cur.text += `\n${line}`;
  }
  return entries;
}

/**
 * COORD6-2 to COORD6-4, COORD6-6. `base` and `head` hold the texts of
 *   index (decisions/INDEX.md), decisions (OPEN_DECISIONS.md), journal (JOURNAL.md),
 *   packages: { "<ID>": text | null }   (decisions/<ID>.md; only the IDs awaiting on the base are read)
 * `now` is a Date. Returns { errors, warnings }.
 */
export function freezeFindings({ base, head, now }) {
  const errors = [];
  const warnings = [];
  const frozen = readPackageIndex(base.index).filter((p) => AWAITING.test(p.status)).map((p) => p.id);
  if (frozen.length === 0) return { errors, warnings };

  const baseIndexRows = rowLines(base.index, null);
  const headIndexRows = rowLines(head.index, null);
  const baseOpenRows = rowLines(base.decisions, "Open");
  const headOpenRows = rowLines(head.decisions, "Open");
  const headDecidedRows = rowLines(head.decisions, "Decided");
  const baseDecidedRows = rowLines(base.decisions, "Decided");

  for (const id of frozen) {
    const b = base.packages?.[id] ?? null;
    const h = head.packages?.[id] ?? null;
    const packageChanged = b !== h;
    const packageUnfreeze = addedLines(b, h).some((l) => UNFREEZE_LINE.test(l));
    if (packageChanged && !packageUnfreeze) {
      errors.push(`decisions/${id}.md: ${id} is frozen (awaiting-approval on the base) and changed without an added line "Unfreeze: <trigger 1-5> <reference>" (README rule 9, COORD6-2)`);
    }
    // COORD6-3: a changed row must carry a new "Unfreeze: n " reference (or the package file adds the line).
    const rows = [
      ["decisions/INDEX.md", baseIndexRows.get(id), headIndexRows.get(id)],
      ["OPEN_DECISIONS.md (Open)", baseOpenRows.get(id), headOpenRows.get(id)],
    ];
    for (const [file, br, hr] of rows) {
      if (br === hr) continue;
      if (packageUnfreeze) continue;
      if (hr !== undefined && unfreezeRefs(hr) > unfreezeRefs(br)) continue;
      // Row moved out of Open (COORD6-6): its new Decided row may carry the reference.
      if (hr === undefined && unfreezeRefs(headDecidedRows.get(id)) > unfreezeRefs(baseDecidedRows.get(id))) continue;
      errors.push(`${file}: ${id} is frozen (awaiting-approval on the base) and its row changed without "Unfreeze: <trigger 1-5> <reference>" in the row or an added Unfreeze line in decisions/${id}.md (README rule 9, COORD6-3)`);
    }
  }

  // COORD6-4: only entries added in the diff (a "## " heading the base does not have).
  const baseHeadings = new Set(journalEntries(base.journal).map((e) => e.heading));
  const asError = now.getTime() >= JOURNAL_ERROR_FROM.getTime();
  for (const e of journalEntries(head.journal)) {
    if (baseHeadings.has(e.heading) || !NO_NEW_EVIDENCE.test(e.text)) continue;
    const named = frozen.filter((id) => mentions(e.text, id));
    if (named.length === 0) continue;
    const msg = `JOURNAL.md: entry "${e.heading.slice(3)}" writes "no new evidence" about frozen package(s) ${named.join(", ")}; write nothing about a frozen package (README rule 9, COORD6-4${asError ? "" : "; an error from 2026-11-04 00:00 Europe/Zurich"})`;
    (asError ? errors : warnings).push(msg);
  }
  return { errors, warnings };
}

const git = (dir, args) => execFileSync("git", ["-C", dir, ...args], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"], maxBuffer: 64 * 1024 * 1024 });

/**
 * COORD6-5: base texts from git, or { skip: reason }. The base is the merge base of `ref` and HEAD, so a branch
 * that is behind its base is compared with the commit it started from. Reads only files under the agents folder.
 */
export function readBase(dir, ref) {
  let prefix;
  let rev;
  try {
    prefix = git(dir, ["rev-parse", "--show-prefix"]).trim();
  } catch {
    return { skip: `${dir} is not inside a git work tree` };
  }
  try {
    const tip = git(dir, ["rev-parse", "--verify", "--quiet", `${ref}^{commit}`]).trim();
    rev = git(dir, ["merge-base", tip, "HEAD"]).trim();
  } catch {
    return { skip: `base revision "${ref}" or its merge base with HEAD cannot be resolved (shallow clone or no remote?)` };
  }
  const show = (file) => {
    try {
      return git(dir, ["show", `${rev}:${prefix}${file}`]);
    } catch {
      return null;
    }
  };
  return { rev, show };
}
