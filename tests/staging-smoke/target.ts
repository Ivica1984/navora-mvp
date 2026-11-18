// ADR-205 (founder decision 2026-11-18 ca. 23:00, live to `eng`: «Variante b»): the staging smoke clicks the founder's
// two paths in the real staging app with the three demo accounts (FE-086b). This module decides where it may run and
// with which accounts. It never skips: a missing password or a wrong host fails the run, because a skipped smoke is
// not a verification (FE-071 (4)). Passwords come only from the environment (GitHub repository secrets); they are
// never written to a file, a log line, an artifact or a comment.

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
 * Day offsets (from today, Europe/Zurich) of the two synthetic orders of one run. Each run uses other days than the
 * CI e2e specs (30–37) and, for 30 consecutive runs, other days than the runs before it, so the demo nurse is free at
 * the take (step 3) and no earlier smoke order is matched by mistake. Day shift: 40–69; night: 75–104 (no overlap).
 */
export function smokeDayOffsets(runNumber: number): { day: number; night: number } {
  const n = Number.isFinite(runNumber) && runNumber > 0 ? Math.floor(runNumber) % 30 : 0;
  return { day: 40 + n, night: 75 + n };
}
