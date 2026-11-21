import { execFileSync } from "node:child_process";
import { expect, test, type Page } from "@playwright/test";

// PERF1 (brief docs/agents/briefs/PERF1.md, scope (2)) — RED REPRODUCTION PROBE, unmerged branch only (FE-099 WORKING MODE 7).
// Reproduces the staging fault of `staging-smoke` path 3 (44902700301, 44906414779; root cause
// docs/engineering/STAGING_DB_SLOWDOWN_2026-11-21.md §4): when `public.team_visit_alerts` fails, the whole /field page
// fails, because getTeamVisitAlerts() throws (src/features/team/queries.ts). On staging the failure is the 8 s statement
// timeout (57014); here it is forced deterministically by revoking EXECUTE from `authenticated` (42501): same code path
// in the app (PostgREST error → throw), no timing dependence. Expected on recovery/main b8824049: RED.
// Fixture: local Supabase only (port 54322); the grant is restored in `finally` and again in afterAll (one worker,
// serial run, playwright.config.ts), so no later spec sees the revoked state. Synthetic seed accounts only.
const NURSE = "pflege.test@navora.test"; // org A, nurse, Testteam Nord (supabase/seed.sql)
const PASSWORD = "navora-local-only";
const DB_URL = process.env.E2E_DB_URL ?? "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
const LOCAL_DB = /^postgres(ql)?:\/\/[^@]+@(127\.0\.0\.1|localhost):54322\//;
// Working wording from the PERF1 brief (2); final wording at the `uxa` gate, content check by `cra`.
const NOTICE = "Hinweise zu Einsätzen konnten nicht geladen werden";

function psql(sql: string): string {
  if (!LOCAL_DB.test(DB_URL)) throw new Error("PERF1 probe fixture: only the local Supabase database (port 54322)");
  return execFileSync("psql", [DB_URL, "-X", "-q", "-At", "-v", "ON_ERROR_STOP=1", "-c", sql], { encoding: "utf8" }).trim();
}
// Exactly the grant of the migrations (0045 … 0080: revoke from public, anon; grant execute to authenticated).
const breakAlerts = () => psql("revoke execute on function public.team_visit_alerts() from authenticated");
const restoreAlerts = () => psql("grant execute on function public.team_visit_alerts() to authenticated");

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(/\/field$/);
}

test.describe("PERF1 probe: /field when the visit hint list fails", () => {
  test.afterAll(() => {
    restoreAlerts();
  });

  test("the day view stays and one visible notice replaces the hint list", async ({ page }) => {
    await signIn(page, NURSE);
    // Control: with the list available the day view renders and the notice is absent.
    await expect(page.getByRole("navigation", { name: "Tag wechseln" })).toBeVisible();
    await expect(page.getByText(NOTICE)).toHaveCount(0);

    breakAlerts();
    try {
      await page.reload();
      // PERF1 (2): the carer keeps her day view ... (that «Losfahren» still moves a card is the package's own e2e on a
      // dedicated visit, T-2; not in this probe, which changes no seed row).
      await expect(page.getByRole("navigation", { name: "Tag wechseln" })).toBeVisible();
      // ... and never a silent omission: one visible line says the hints could not be loaded.
      await expect(page.getByText(NOTICE)).toHaveCount(1);
    } finally {
      restoreAlerts();
    }

    // After the restore the page is as before (no lasting notice).
    await page.reload();
    await expect(page.getByRole("navigation", { name: "Tag wechseln" })).toBeVisible();
    await expect(page.getByText(NOTICE)).toHaveCount(0);
  });
});
