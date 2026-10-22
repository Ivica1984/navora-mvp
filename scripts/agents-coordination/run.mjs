#!/usr/bin/env node
// Coordination watcher (GitHub side). Reads docs/agents, computes the hand-offs with plan.mjs and
// syncs them to GitHub issues: creates, updates (title/body/labels), comments and closes.
// Idempotent: run it as often as you like (push to recovery/main, hourly schedule, manual).
//
// Env: GITHUB_TOKEN, GITHUB_REPOSITORY (owner/repo), OWNER_LOGIN (assignee for human decisions).
// Flags: --dry-run (print the plan, change nothing).
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { readLayerTexts, parseTable, bare } from "./parse.mjs";
import { LABELS, closeReason, diffIssues, mergedLabels, planCoordination } from "./plan.mjs";

const DRY = process.argv.includes("--dry-run");
const DIR = process.env.AGENTS_DIR ?? join(process.cwd(), "docs", "agents");
const REPO = process.env.GITHUB_REPOSITORY;
const TOKEN = process.env.GITHUB_TOKEN;
const OWNER_LOGIN = process.env.OWNER_LOGIN ?? (REPO ? REPO.split("/")[0] : "");
const MARKER = (key) => `<!-- agents-coordination:key=${key} -->`;
const MARKER_RE = /<!-- agents-coordination:key=([^ ]+) -->/;

const read = (f) => readFileSync(join(DIR, f), "utf8");
const layer = readLayerTexts({ next: read("NEXT_CAPABILITY.md"), status: read("IMPLEMENTATION_STATUS.md"), decisions: read("OPEN_DECISIONS.md") });

// When did each side last change an item? Walk the recent history of each file (git, no API).
function lastChanges(file, heading, field) {
  const out = {};
  let log = [];
  try {
    log = execFileSync("git", ["log", "-n", "60", "--format=%H %ct", "--", join("docs", "agents", file)], { encoding: "utf8" })
      .trim().split("\n").filter(Boolean).map((l) => l.split(" "));
  } catch {
    return out;
  }
  // Oldest → newest; record the time each item's field took its current value.
  let previous = new Map();
  for (const [sha, ts] of log.reverse()) {
    let text = "";
    try {
      text = execFileSync("git", ["show", `${sha}:docs/agents/${file}`], { encoding: "utf8" });
    } catch {
      continue;
    }
    const now = new Map(parseTable(text, heading).map((r) => [bare(r.ID), bare(r[field])]));
    for (const [id, value] of now) if (previous.get(id) !== value) out[id] = Number(ts);
    previous = now;
  }
  return out;
}

const poTimes = lastChanges("NEXT_CAPABILITY.md", "Priority queue", "PO status");
const engTimes = lastChanges("IMPLEMENTATION_STATUS.md", "Items", "State");
const changed = {};
for (const id of new Set([...Object.keys(poTimes), ...Object.keys(engTimes)])) changed[id] = { po: poTimes[id] ?? 0, eng: engTimes[id] ?? 0 };

const { issues: planned, active } = planCoordination(layer, changed);

async function gh(method, path, body) {
  const res = await fetch(`https://api.github.com/repos/${REPO}${path}`, {
    method,
    headers: { Authorization: `Bearer ${TOKEN}`, Accept: "application/vnd.github+json", "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!res.ok) throw new Error(`${method} ${path}: HTTP ${res.status} ${await res.text()}`);
  return res.status === 204 ? null : res.json();
}

async function existingIssues() {
  const all = [];
  for (let page = 1; page < 20; page++) {
    const batch = await gh("GET", `/issues?state=open&labels=${LABELS.base}&per_page=100&page=${page}`);
    all.push(...batch.filter((i) => !i.pull_request));
    if (batch.length < 100) break;
  }
  return all
    .map((i) => ({ number: i.number, key: (i.body ?? "").match(MARKER_RE)?.[1], title: i.title,
                   body: (i.body ?? "").replace(MARKER_RE, "").trim(), labels: i.labels.map((l) => l.name) }))
    .filter((i) => i.key);
}

async function ensureLabels() {
  const colors = { [LABELS.base]: "5319e7", [LABELS.eng]: "1d76db", [LABELS.po]: "0e8a16", [LABELS.human]: "d93f0b",
                   [LABELS.active]: "fbca04", [LABELS.blocked]: "b60205", claimed: "c5def5" };
  for (const [name, color] of Object.entries(colors)) {
    try { await gh("POST", "/labels", { name, color }); } catch { /* exists */ }
  }
}

const summary = [`active capability: ${active ?? "none"}`, ...planned.map((p) => `${p.key}  [${p.labels.join(", ")}]`)];

if (DRY || !TOKEN || !REPO) {
  console.log(`agents-coordination (dry run${!TOKEN ? ", no token" : ""}):`);
  console.log(summary.join("\n"));
  process.exit(0);
}

await ensureLabels();
const existing = await existingIssues();
const { create, update, close } = diffIssues(planned, existing);

for (const p of create) {
  const issue = await gh("POST", "/issues", {
    title: p.title, body: `${MARKER(p.key)}\n${p.body}`, labels: p.labels,
    assignees: p.assignOwner && OWNER_LOGIN ? [OWNER_LOGIN] : [],
  });
  console.log(`created #${issue.number} ${p.key}`);
}
for (const { planned: p, existing: e } of update) {
  const becameActive = p.labels.includes(LABELS.active) && !e.labels.includes(LABELS.active);
  await gh("PATCH", `/issues/${e.number}`, { title: p.title, body: `${MARKER(p.key)}\n${p.body}`, labels: mergedLabels(p.labels, e.labels) });
  if (becameActive) await gh("POST", `/issues/${e.number}/comments`, { body: `**${p.id} is now the active capability.** Engineering starts on it.` });
  console.log(`updated #${e.number} ${p.key}`);
}
for (const e of close) {
  await gh("POST", `/issues/${e.number}/comments`, { body: closeReason(e.key, layer) });
  await gh("PATCH", `/issues/${e.number}`, { state: "closed", state_reason: "completed" });
  console.log(`closed #${e.number} ${e.key}`);
}
console.log(summary.join("\n"));
