#!/usr/bin/env node
// MET-1 (#1873): read-only baseline of NAVORA package lead times from GitHub and the repository.
//
// It measures; it changes nothing. It reads only:
//   (a) package PRs and their issue comments (GitHub REST, GET only),
//   (b) the first-parent history of the integration branch (local git, read only),
//   (c) `docs/product/ABNAHMEAKTE.md` §2 at the same revision (local git, read only).
// No AI, no estimate, no imputation: a value that cannot be derived from a marker is `null` with a reason.
//
// Event markers (exactly as they appear in the repository, see the report for the evidence):
//   READY    an issue comment on the PR whose text starts with «Paket prüfbereit:» or «Paket prüfbereit (» (optional **)
//   WINDOW   a PO comment whose first 400 characters say «gate window … opened» or «Gate-Fenster … geöffnet»
//   GATE     a comment that starts with «<role>-gate: #<pr> <sha> <verdict>» (optional `), role cra|uxa|lca|aia|csa
//   MERGE    `merged_at` of the PR (GitHub); cross-checked against the first-parent merge commit «PO merge #<pr>»
//            (older subjects «Merge pull request #<pr>» / «Merge PR #<pr>» are accepted and listed)
//   ACCEPT_C a comment that starts with «**PO acceptance» or «**PO-Abnahme» (GitHub timestamp)
//   ACCEPT_A the «Entscheid … YYYY-MM-DD HH:MM» of the ABNAHMEAKTE §2 block whose status line names #<pr>
//            (a PO run label in Europe/Zurich, minute resolution; not the moment the text was written)
//
// A case is a PR whose FIRST READY lies inside the window. The window is given in Europe/Zurich local dates.
//
// CLI:
//   node scripts/met1-delivery-baseline.mjs --from 2026-11-21 --to 2026-11-28 [--ref origin/recovery/main]
//        [--json <file>]     writes the raw events and KPIs as JSON to <file>; prints the Markdown tables to stdout
// Access: uses `gh api` when `gh` is on PATH (authenticated), otherwise fetch with GITHUB_TOKEN when set.
// Fail-closed: an API or git error stops the run with exit 1; it never prints a partial result as complete.
import { execFileSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

const REPO = process.env.GITHUB_REPOSITORY || "Ivica1984/navora-mvp";
const TZ = "Europe/Zurich";

// ---------------------------------------------------------------- pure parsing (no I/O)

const LEAD = /^[\s*`_>]*/;
const strip = (body) => (body || "").replace(LEAD, "");

export function isReady(body) {
  // «Paket prüfbereit:» and the re-report form «Paket prüfbereit (Nachtrag, neuer Kopf):»
  return /^Paket prüfbereit(:|\s*\()/.test(strip(body));
}
export function isWindowOpened(body) {
  // two forms seen: «**PO: Gate-Fenster X geöffnet**» (from 2026-11-26) and, earlier, a PO run comment whose first
  // paragraph says «Gate window X opened»; both must be a PO comment and name the window within its first 400 chars
  const s = strip(body);
  return /^PO\b/.test(s) && /(gate window|Gate-Fenster)[^.\n]{0,60}?\b(opened|geöffnet)\b/i.test(s.slice(0, 400));
}
/** @returns {{role:string, pr:number, sha:string, verdict:string} | null} */
export function parseGate(body) {
  const m = strip(body).match(/^(cra|uxa|lca|aia|csa)-gate:\s*#(\d+)\s+`?([0-9a-f]{7,40})`?\s+`?([a-z-]+)/i);
  return m ? { role: m[1].toLowerCase(), pr: Number(m[2]), sha: m[3].toLowerCase(), verdict: m[4].toLowerCase() } : null;
}
export function isAcceptComment(body) {
  return /^PO[ -](acceptance|Abnahme)\b/i.test(strip(body));
}

/** Europe/Zurich wall time "YYYY-MM-DD HH:MM" → ISO UTC. Uses the real offset of that instant (CET/CEST). */
export function zurichToUtc(date, time) {
  const guess = new Date(`${date}T${time}:00Z`);
  const parts = new Intl.DateTimeFormat("en-GB", { timeZone: TZ, timeZoneName: "longOffset" }).formatToParts(guess);
  const off = (parts.find((p) => p.type === "timeZoneName")?.value || "GMT+00:00").replace("GMT", "") || "+00:00";
  return new Date(`${date}T${time}:00${off === "" ? "Z" : off}`).toISOString();
}
export function toZurich(iso) {
  if (!iso) return null;
  return new Intl.DateTimeFormat("sv-SE", { timeZone: TZ, dateStyle: "short", timeStyle: "short" }).format(new Date(iso));
}

/** ABNAHMEAKTE §2 → [{ heading, decided_local, decided_utc, approx, prs:[n] }] */
export function parseAkte(text) {
  const sec2 = text.split(/^## 2\./m)[1]?.split(/^## 3\./m)[0] ?? "";
  const out = [];
  let heading = null;
  for (const line of sec2.split("\n")) {
    if (line.startsWith("### ")) heading = line.slice(4).trim();
    else if (heading && line.startsWith("- **Status:**")) {
      const m = line.match(/Entscheid[^0-9]{0,40}(\d{4}-\d{2}-\d{2})\s+(?:ca\.\s*)?(\d{2}:\d{2})/);
      const approx = /Entscheid[^0-9]{0,40}\d{4}-\d{2}-\d{2}\s+ca\./.test(line) || /geschrieben ca\./.test(line);
      out.push({
        heading,
        decided_local: m ? `${m[1]} ${m[2]}` : null,
        decided_utc: m ? zurichToUtc(m[1], m[2]) : null,
        approx,
        prs: [...new Set([...line.matchAll(/#(\d{3,5})\b/g)].map((x) => Number(x[1])))],
      });
      heading = null;
    }
  }
  return out;
}

const hours = (a, b) => (a && b ? Math.round(((Date.parse(b) - Date.parse(a)) / 3.6e6) * 100) / 100 : null);

/** One case from raw PR data. Pure. */
export function buildCase(pr, comments, mergeCommit, akte) {
  const anomalies = [];
  const c = [...comments].sort((x, y) => x.created_at.localeCompare(y.created_at));
  const ready = c.filter((x) => isReady(x.body));
  const windows = c.filter((x) => isWindowOpened(x.body));
  const gates = c.map((x) => ({ ...parseGate(x.body), at: x.created_at, id: x.id })).filter((g) => g.role);
  const acceptC = c.filter((x) => isAcceptComment(x.body));
  const head = (pr.head_sha || "").toLowerCase();
  const end = pr.merged_at || null;

  const readyBeforeEnd = ready.filter((r) => !end || r.created_at <= end);
  const lastReady = readyBeforeEnd.at(-1) || null;
  if (ready.length > 1) anomalies.push(`${ready.length} READY comments (re-reports after head changes or duplicates)`);
  const win = lastReady ? windows.find((w) => w.created_at >= lastReady.created_at) || null : null;
  if (lastReady && !win) anomalies.push("no WINDOW comment after the last READY");
  if (windows.length > 1) anomalies.push(`${windows.length} WINDOW comments`);

  // the first clear line per role that names the final head, after the window
  const finalClear = {};
  for (const g of gates) {
    if (g.pr !== pr.number) anomalies.push(`gate line ${g.role} names #${g.pr} on PR #${pr.number} (comment ${g.id})`);
    if (g.verdict !== "clear") anomalies.push(`gate line ${g.role} ${g.verdict} at ${g.at} (comment ${g.id})`);
    if (g.verdict === "clear" && head.startsWith(g.sha) && (!win || g.at >= win.created_at) && !finalClear[g.role])
      finalClear[g.role] = g.at;
  }
  const staleGates = gates.filter((g) => g.verdict === "clear" && !head.startsWith(g.sha));
  if (staleGates.length) anomalies.push(`${staleGates.length} clear gate line(s) name an earlier head than the final head`);
  const roles = Object.keys(finalClear).sort();
  const lastGate = roles.length ? roles.map((r) => finalClear[r]).sort().at(-1) : null;
  // whether a package needed gates is in its brief, which this script does not read: listed, not judged
  if (end && !roles.length) anomalies.push("no clear gate line naming the final head in the comments (required gates: not read)");
  if (lastGate && end && lastGate > end) anomalies.push("a final-head gate line is later than the merge");

  if (end && !mergeCommit) anomalies.push("merged_at set, but no first-parent merge commit for this PR on the ref");
  if (end && mergeCommit && !/^PO merge #/.test(mergeCommit.subject))
    anomalies.push(`merge commit subject is not «PO merge #…»: «${mergeCommit.subject.slice(0, 60)}»`);
  const mergeSkewMin = end && mergeCommit ? Math.round((Date.parse(mergeCommit.date) - Date.parse(end)) / 60000) : null;
  if (mergeSkewMin !== null && Math.abs(mergeSkewMin) > 2) anomalies.push(`merge commit time differs from merged_at by ${mergeSkewMin} min`);

  const akteHits = akte.filter((a) => a.prs.includes(pr.number));
  if (akteHits.length > 1) anomalies.push(`#${pr.number} named in ${akteHits.length} ABNAHMEAKTE status lines`);
  const a = akteHits[0] || null;
  if (a?.approx) anomalies.push(`ABNAHMEAKTE time for «${a.heading.slice(0, 40)}» is approximate («ca.» / run label)`);
  if (acceptC.length > 1) anomalies.push(`${acceptC.length} acceptance comments`);
  const accC = acceptC[0]?.created_at || null;
  if (end && !accC && a) anomalies.push("acceptance in ABNAHMEAKTE, but no acceptance comment on this PR");
  if (end && accC && !a) anomalies.push("acceptance comment on the PR, but this PR is not named in an ABNAHMEAKTE status line");
  const accA = a?.decided_utc || null;
  const akteVsComment = accA && accC ? Math.round((Date.parse(accC) - Date.parse(accA)) / 60000) : null;

  const firstReady = ready[0]?.created_at || null;
  return {
    pr: pr.number,
    title: pr.title,
    state: end ? "merged" : pr.state,
    head: head.slice(0, 8),
    events: {
      opened: pr.created_at,
      ready_first: firstReady,
      ready_last: lastReady?.created_at || null,
      ready_count: ready.length,
      window: win?.created_at || null,
      gate_final_clear: finalClear,
      gate_last: lastGate,
      merged: end,
      merge_commit: mergeCommit ? { sha: mergeCommit.sha.slice(0, 8), date: mergeCommit.date, subject: mergeCommit.subject } : null,
      accept_comment: accC,
      accept_akte: a ? { heading: a.heading, local: a.decided_local, utc: accA, approx: a.approx } : null,
      akte_minus_comment_min: akteVsComment,
    },
    durations_h: {
      K1_ready_to_window: hours(lastReady?.created_at, win?.created_at),
      K2_window_to_last_gate: hours(win?.created_at, lastGate),
      K3_last_gate_to_merge: hours(lastGate, end),
      K4_first_ready_to_merge: hours(firstReady, end),
      K5c_merge_to_accept_comment: hours(end, accC),
      K5a_merge_to_accept_akte: hours(end, accA),
      K6_first_ready_to_accept_comment: hours(firstReady, accC),
      K7_opened_to_accept_comment: hours(pr.created_at, accC),
    },
    anomalies,
  };
}

export function summarise(cases) {
  const keys = Object.keys(cases[0]?.durations_h || {});
  const out = {};
  for (const k of keys) {
    const vals = [];
    const excluded = [];
    for (const c of cases) {
      const v = c.durations_h[k];
      if (v === null) excluded.push(c.pr);
      else if (v < 0) excluded.push(c.pr); // negative = marker order contradiction; listed, never averaged
      else vals.push(v);
    }
    vals.sort((a, b) => a - b);
    const med = vals.length ? (vals.length % 2 ? vals[(vals.length - 1) / 2] : (vals[vals.length / 2 - 1] + vals[vals.length / 2]) / 2) : null;
    out[k] = {
      n: vals.length,
      median: med === null ? null : Math.round(med * 100) / 100,
      min: vals[0] ?? null,
      max: vals.at(-1) ?? null,
      sum: vals.length ? Math.round(vals.reduce((s, v) => s + v, 0) * 100) / 100 : null,
      excluded,
      negative: cases.filter((c) => (c.durations_h[k] ?? 0) < 0).map((c) => c.pr),
    };
  }
  return out;
}

// ---------------------------------------------------------------- I/O (read only)

function hasGh() {
  try {
    execFileSync("gh", ["--version"], { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}
const USE_GH = hasGh();

async function get(path) {
  if (USE_GH) return JSON.parse(execFileSync("gh", ["api", "-X", "GET", `repos/${REPO}${path}`], { encoding: "utf8", maxBuffer: 64e6 }));
  const headers = { Accept: "application/vnd.github+json" };
  if (process.env.GITHUB_TOKEN) headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
  const res = await fetch(`https://api.github.com/repos/${REPO}${path}`, { headers });
  if (!res.ok) throw new Error(`GET ${path}: HTTP ${res.status}`);
  return res.json();
}
async function getAll(path) {
  const out = [];
  for (let page = 1; ; page++) {
    const sep = path.includes("?") ? "&" : "?";
    const d = await get(`${path}${sep}per_page=100&page=${page}`);
    out.push(...d);
    if (d.length < 100) return out;
  }
}
function git(args) {
  return execFileSync("git", args, { encoding: "utf8", maxBuffer: 64e6 });
}

function parseArgs(argv) {
  const a = { ref: "origin/recovery/main" };
  for (let i = 0; i < argv.length; i++) {
    const k = argv[i].replace(/^--/, "");
    a[k] = argv[++i];
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(a.from || "") || !/^\d{4}-\d{2}-\d{2}$/.test(a.to || ""))
    throw new Error("usage: --from YYYY-MM-DD --to YYYY-MM-DD [--ref <rev>] [--json <file>]");
  return a;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const retrieved = new Date().toISOString();
  const from = zurichToUtc(args.from, "00:00");
  const toExclusive = new Date(Date.parse(zurichToUtc(args.to, "00:00")) + 864e5).toISOString();
  const refSha = git(["rev-parse", args.ref]).trim();

  // merge commits on the integration branch (first parent), keyed by PR number
  const mergeByPr = {};
  for (const line of git(["log", "--first-parent", "--format=%H%x09%cI%x09%s", refSha]).split("\n")) {
    const [sha, date, subject] = line.split("\t");
    const m = subject?.match(/^(?:PO merge #|Merge pull request #|Merge PR #)(\d+)/);
    if (m && !mergeByPr[m[1]]) mergeByPr[m[1]] = { sha, date: new Date(date).toISOString(), subject };
  }
  const akte = parseAkte(git(["show", `${refSha}:docs/product/ABNAHMEAKTE.md`]));

  // every PR updated since the window start (issues endpoint carries the comment count)
  const issues = await getAll(`/issues?state=all&since=${from}&sort=created&direction=desc`);
  const prs = issues.filter((i) => i.pull_request && i.comments > 0);
  const cases = [];
  const scanned = [];
  for (const i of prs) {
    const comments = await getAll(`/issues/${i.number}/comments`);
    const firstReady = comments.filter((c) => isReady(c.body)).map((c) => c.created_at).sort()[0];
    scanned.push(i.number);
    if (!firstReady || firstReady < from || firstReady >= toExclusive) continue;
    const p = await get(`/pulls/${i.number}`);
    const pr = { number: p.number, title: p.title, state: p.state, created_at: p.created_at, merged_at: p.merged_at, head_sha: p.head.sha };
    cases.push(buildCase(pr, comments, mergeByPr[p.number] || null, akte));
  }
  cases.sort((a, b) => a.events.ready_first.localeCompare(b.events.ready_first));
  const kpis = summarise(cases);
  const result = { retrieved, timezone: TZ, window: { from_local: args.from, to_local: args.to, from_utc: from, to_utc_exclusive: toExclusive }, ref: { name: args.ref, sha: refSha }, scanned_prs: scanned.length, cases, kpis };
  if (args.json) writeFileSync(args.json, JSON.stringify(result, null, 2) + "\n");

  const z = (iso) => toZurich(iso) ?? "—";
  const f = (v) => (v === null || v === undefined ? "UNKNOWN" : String(v));
  console.log(`MET-1 baseline · retrieved ${retrieved} (UTC) · window ${args.from} – ${args.to} ${TZ} · ref ${args.ref} ${refSha.slice(0, 8)} · PRs scanned ${scanned.length} · cases ${cases.length}\n`);
  console.log("| PR | state | READY first (n) | WINDOW | last gate (roles) | MERGE | ACCEPT comment | ACCEPT Akte |");
  console.log("|---|---|---|---|---|---|---|---|");
  for (const c of cases) {
    const e = c.events;
    console.log(`| #${c.pr} | ${c.state} | ${z(e.ready_first)} (${e.ready_count}) | ${z(e.window)} | ${z(e.gate_last)} (${Object.keys(e.gate_final_clear).join(", ") || "—"}) | ${z(e.merged)} | ${z(e.accept_comment)} | ${e.accept_akte ? e.accept_akte.local + (e.accept_akte.approx ? " (ca.)" : "") : "—"} |`);
  }
  console.log("\n| KPI | n | median h | min h | max h | excluded (no marker) | negative |");
  console.log("|---|---|---|---|---|---|---|");
  for (const [k, v] of Object.entries(kpis))
    console.log(`| ${k} | ${v.n} | ${f(v.median)} | ${f(v.min)} | ${f(v.max)} | ${v.excluded.map((n) => "#" + n).join(", ") || "—"} | ${v.negative.map((n) => "#" + n).join(", ") || "—"} |`);
  console.log("\nAnomalies per case:");
  for (const c of cases) for (const a of c.anomalies) console.log(`- #${c.pr}: ${a}`);
}

if (import.meta.url === pathToFileURL(process.argv[1] || "").href) {
  main().catch((e) => {
    console.error(`MET-1 baseline: ${e.message}`);
    process.exit(1);
  });
}
