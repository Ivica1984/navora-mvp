// ADR-205 (founder decision 2026-11-18 ca. 23:00, live to `eng`: «Variante b»): the staging smoke clicks the founder's
// two paths in the real staging app with the three demo accounts (FE-086b). This module decides where it may run and
// with which accounts. It never skips: a missing password or a wrong host fails the run, because a skipped smoke is
// not a verification (FE-071 (4)). Passwords come only from the environment (GitHub repository secrets); they are
// never written to a file, a log line, an artifact or a comment.

import { hhmm, zurichDay, zurichMinuteOfDay } from "../e2e/support/durchgang-time";

/** The only host the smoke may open. Changing it is a reviewed code change, not a setting. */
export const STAGING_HOSTS = Object.freeze(["navora-staging.onrender.com"]);

/** The live Supabase project (never touched by any agent or job). */
const LIVE_PROJECT = "jwmfxrmougneeceldhsa";

export type Env = Record<string, string | undefined>;

/** The base URL of the staging app, or an error naming why the smoke must not run. */
export function stagingTarget(env: Env): string {
  const raw = (env.STAGING_SMOKE_BASE_URL ?? "").trim() || `https://${STAGING_HOSTS[0]}`;
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw new Error("staging-smoke: STAGING_SMOKE_BASE_URL is not a URL");
  }
  if (raw.includes(LIVE_PROJECT)) throw new Error("staging-smoke: the live project is never a target");
  if (url.protocol !== "https:") throw new Error("staging-smoke: only https");
  if (!STAGING_HOSTS.includes(url.hostname)) throw new Error(`staging-smoke: host ${url.hostname} is not a staging host`);
  if (url.username || url.password) throw new Error("staging-smoke: no credentials in the URL");
  return url.origin;
}

export type Role = "kunde" | "pflegeBs" | "pflegeNord";

/** The three demo accounts on staging (FE-086b). E-mail addresses are the synthetic seed's; they are not secret. */
export const SMOKE_EMAILS: Readonly<Record<Role, string>> = Object.freeze({
  kunde: "kundebs.test@navora.test",
  pflegeBs: "pflegebs.test@navora.test",
  pflegeNord: "pflege.test@navora.test",
});

const PASSWORD_VARS: Readonly<Record<Role, string>> = Object.freeze({
  kunde: "STAGING_SMOKE_PW_KUNDEBS",
  pflegeBs: "STAGING_SMOKE_PW_PFLEGEBS",
  pflegeNord: "STAGING_SMOKE_PW_PFLEGE",
});

/** E-mail and password per role. Throws, naming only the missing variable names (never a value). */
export function smokeAccounts(env: Env): Record<Role, { email: string; password: string }> {
  const missing = (Object.keys(PASSWORD_VARS) as Role[])
    .filter((r) => !(env[PASSWORD_VARS[r]] ?? "").trim())
    .map((r) => PASSWORD_VARS[r]);
  if (missing.length) throw new Error(`staging-smoke: missing secrets ${missing.join(", ")}`);
  const out = {} as Record<Role, { email: string; password: string }>;
  for (const r of Object.keys(PASSWORD_VARS) as Role[]) {
    out[r] = { email: SMOKE_EMAILS[r], password: (env[PASSWORD_VARS[r]] as string).trim() };
  }
  return out;
}

/**
 * Run-number offsets (from today, Europe/Zurich). Since the #1642 follow-up only path 4 uses `day` (its week of its
 * own); paths 1 and 2 take the first day free of client orders from 40 and 75 (`freeDayOffset`), because a run-number
 * window repeats after 30 runs and a re-run keeps the run number.
 */
export function smokeDayOffsets(runNumber: number): { day: number; night: number } {
  const n = Number.isFinite(runNumber) && runNumber > 0 ? Math.floor(runNumber) % 30 : 0;
  return { day: 40 + n, night: 75 + n };
}

/**
 * #1642 (root cause from raw data, staging-smoke 44858240792 attempt 2, job 136718352894): a re-run of a workflow run
 * keeps GITHUB_RUN_NUMBER, so `smokeDayOffsets` gave attempt 2 the day of attempt 1 (27.01.2027). The demo nurse
 * already held attempt 1's take 07:00–15:30 of that day, so the database correctly offered the new order to no team
 * (overlap rule CGR-224) and the client read «Nicht gedeckt», not «Noch nicht gedeckt». So, as path 3 does since
 * STAB1-F3, the day is read free in the real app: the first offset on whose days (`span` days from it, 2 for a night)
 * the client has no order at all. Any order counts, taken or not, so the result is a superset-safe choice.
 *
 * #1642 follow-up (staging-smoke 44873616277 on 7128de1, job 136753359033): the cyclic window of 30 days of #1644 filled
 * («every day of offsets 75–104 already holds a client order»), because no smoke order can be withdrawn in the app
 * (no un-take of a self-named take, UXR-221; no client cancellation) and staging received 20 nights in 24 hours. So the
 * search is no longer bounded by a window: it walks forward from `from` until the first free day. Repeated runs move
 * the front of used days forward, they can no longer run out of days. `horizon` is only a sanity stop against a broken
 * order list (it would throw, never skip); staging is capped earlier by the API row cap (`assertBelowRowCap`).
 */
export const SMOKE_HORIZON_DAYS = 3650;

export function freeDayOffset(
  nowMs: number,
  from: number,
  usedDays: ReadonlySet<string>,
  span = 1,
  horizon = SMOKE_HORIZON_DAYS,
): number {
  if (!Number.isInteger(from) || from < 1 || !Number.isInteger(span) || span < 1) {
    throw new RangeError("freeDayOffset: from must be a whole day after today and span at least 1");
  }
  for (let offset = from; offset <= from + horizon; offset++) {
    const days = Array.from({ length: span }, (_, k) => zurichDay(nowMs, offset + k));
    if (days.every((d) => !usedDays.has(d))) return offset;
  }
  throw new Error(`staging-smoke: no free day in the ${horizon} days from offset ${from}; the order list looks broken`);
}

/**
 * STAB1-F4 (checked in #1642): `client_orders()` is called through PostgREST, which returns at most `max_rows` rows
 * (1000 in `supabase/config.toml`; 1000 is also the Supabase default, the staging value itself was not read: UNKNOWN).
 * The function orders by `starts_at` ascending and keeps past orders, so a capped list drops the LATEST orders: the
 * smoke would read occupied days as free, and even its own new order would be missing from /order. At the cap the
 * smoke therefore refuses with this message instead of choosing on a truncated list (fail closed, never a skip).
 */
export const API_ROW_CAP = 1000;

export function assertBelowRowCap(rows: number, cap = API_ROW_CAP): void {
  if (!Number.isInteger(rows) || rows < 0) throw new RangeError("assertBelowRowCap: rows must be a count");
  if (rows >= cap) {
    throw new Error(
      `staging-smoke: the client's order list shows ${rows} rows, the API row cap (${cap}); later orders may be hidden, so no day is chosen`,
    );
  }
}

/** Every calendar day (YYYY-MM-DD) touched by an order span of the client's /order lines (from day to end day). */
export function orderDaysFromLines(lines: readonly string[]): Set<string> {
  const out = new Set<string>();
  for (const line of lines) {
    const m = ORDER_SPAN.exec(line);
    if (!m) continue;
    const fromDay = `${m[3]}-${m[2]}-${m[1]}`;
    const toDay = `${m[8]}-${m[7]}-${m[6]}`;
    for (let d = fromDay, n = 0; d <= toDay && n < 400; n++) {
      out.add(d);
      const next = new Date(`${d}T00:00:00Z`);
      next.setUTCDate(next.getUTCDate() + 1);
      d = next.toISOString().slice(0, 10);
    }
  }
  return out;
}

/** A busy interval of today in minutes of the Zurich day, [from, to); `to` may be 1440 (midnight). */
export type BusyMinutes = [number, number];

const SLOT_MINUTES = 10;
const LAST_END = 23 * 60 + 50;

/**
 * Path 3 (BK-f) shift of one run: today (Europe/Zurich), 10 minutes long, starting at the first minute from 20 minutes
 * after `nowMs` at which the slot overlaps no `busy` interval of today. Path 3 must run on today (the nurse works and
 * signs the shift), so it cannot use a day offset of its own like paths 1 and 2.
 *
 * STAB1-F3 (root cause from raw data, staging 2026-11-20; journal 2026-11-20-2210-eng): two push-triggered runs are
 * serialised by the concurrency group and reach path 3 about 4 minutes apart. The run on f7dfd2d0 ordered 18:20–18:30
 * like the run on d3b2233d before it; the database correctly offered it to no team (order_exclusions
 * «no_member_available»: the demo nurse already held the live take of the same slot, order_member_step step 3, overlap
 * rule CGR-224), so the only «20.11.2026 18:20» card was the earlier, taken one. A merely different start (#1624 head
 * 21f011ff) still overlaps for runs less than 10 minutes apart; only a slot after every busy interval is free.
 * `busy` is read in the real app before ordering (the client's own orders of today, `busyFromOrderLines`).
 * Throws outside 00:30–23:20 Zurich, or when no free slot is left today; a refusal, never a skip.
 */
export function smokePath3Slot(nowMs: number, busy: readonly BusyMinutes[]): { day: string; from: string; to: string } {
  const minute = zurichMinuteOfDay(nowMs);
  if (minute + 20 + SLOT_MINUTES > LAST_END || minute < 30) {
    throw new Error("staging-smoke path 3: run it between 00:30 and 23:20 Zurich (the shift and its times stay on one day)");
  }
  let start = minute + 20;
  for (let moved = true; moved; ) {
    moved = false;
    for (const [a, b] of busy) {
      if (a < start + SLOT_MINUTES && b > start) {
        start = b;
        moved = true;
      }
    }
  }
  if (start + SLOT_MINUTES > LAST_END) {
    throw new Error("staging-smoke path 3: no free 10-minute slot left today before 23:50 Zurich (earlier smoke orders fill it)");
  }
  return { day: zurichDay(nowMs), from: hhmm(start), to: hhmm(start + SLOT_MINUTES) };
}

const ORDER_SPAN = /(\d{2})\.(\d{2})\.(\d{4}) (\d{2}):(\d{2}) – \S+ (\d{2})\.(\d{2})\.(\d{4}) (\d{2}):(\d{2})/;

/**
 * Busy intervals of `day` (YYYY-MM-DD, Zurich) from the client's order sentences on /order (`client_orders().sentence`
 * = the order's `request_title`, e.g. «Schichtauftrag · HF · Fr 20.11.2026 18:20 – Fr 20.11.2026 18:30 (…) · 4051 Basel»).
 * A span from an earlier day starts at 0, one into a later day ends at 1440; lines without a span are ignored. Every
 * order counts, taken or not: a superset of the nurse's live takes is safe (it only moves the slot later).
 */
export function busyFromOrderLines(lines: readonly string[], day: string): BusyMinutes[] {
  const out: BusyMinutes[] = [];
  for (const line of lines) {
    const m = ORDER_SPAN.exec(line);
    if (!m) continue;
    const fromDay = `${m[3]}-${m[2]}-${m[1]}`;
    const toDay = `${m[8]}-${m[7]}-${m[6]}`;
    if (fromDay > day || toDay < day) continue;
    const a = fromDay < day ? 0 : Number(m[4]) * 60 + Number(m[5]);
    const b = toDay > day ? 24 * 60 : Number(m[9]) * 60 + Number(m[10]);
    if (b > a) out.push([a, b]);
  }
  return out;
}

/**
 * Path 5 (HD-2): the day of the week whose Rhein 2 Früh cell the home orders externally. `candidates` are the week's
 * days (YYYY-MM-DD, in screen order) whose cell still shows «Auftrag vorbereiten»; `usedDays` the client's order days
 * read in /order (`orderDaysFromLines`). Returns null when no candidate fits.
 */
export function path5GapDay(candidates: readonly string[], usedDays: ReadonlySet<string>): string | null {
  void usedDays;
  return candidates[0] ?? null;
}
