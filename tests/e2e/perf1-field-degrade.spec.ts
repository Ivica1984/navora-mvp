import { execFileSync } from "node:child_process";
import { expect, test, type Page } from "@playwright/test";

// PERF1 (brief docs/agents/briefs/PERF1.md scope (2), PO amendment 2026-11-21 20:39 (1), (2); CGR-272). Started as the
// red reproduction probe (`probe/perf1-field-degrade-red`, red on recovery/main b8824049): when `public.team_visit_alerts`
// failed, the whole /field page failed, because getTeamVisitAlerts() threw. On staging the failure was the 8 s statement
// timeout (57014); here it is forced deterministically by revoking EXECUTE from `authenticated` (42501): same code path
// in the app (PostgREST error), no timing dependence.
// Asserts: /field keeps its day view and /team its page; one visible notice line stands where the list would be (on
// /field above the visit cards); no hint list is shown as empty without it; each failed load is counted per team and
// day (private.aux_list_failures); after the restore the notice is gone.
// Fixture: local Supabase only (port 54322); the grant is restored in `finally` and again in afterAll (one worker,
// serial run, playwright.config.ts), so no later spec sees the revoked state. Synthetic seed accounts only; no row of
// any other spec is changed (the counter table is read by no other spec).
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

const TEAM_NORD = "00000000-0000-4000-a000-000000000101"; // Testteam Nord (supabase/seed.sql)
const failuresToday = () =>
  Number(psql(`select coalesce(sum(failures), 0) from private.aux_list_failures
               where team_id = '${TEAM_NORD}' and list_key = 'team_visit_alerts' and day = (private.at_zurich(private.now()))::date`));

test.describe("PERF1: /field and /team when the visit hint list fails", () => {
  test.afterAll(() => {
    restoreAlerts();
  });

  for (const width of [390, 1440]) {
    test(`/field at ${width} px: the day view stays and one visible notice above the cards replaces the hint list`, async ({ page }) => {
      await page.setViewportSize({ width, height: 900 });
      await signIn(page, NURSE);
      // Control: with the list available the day view renders and the notice is absent.
      await expect(page.getByRole("navigation", { name: "Tag wechseln" })).toBeVisible();
      await expect(page.getByText(NOTICE)).toHaveCount(0);

      const before = failuresToday();
      breakAlerts();
      try {
        await page.reload();
        await expect(page.getByRole("navigation", { name: "Tag wechseln" })).toBeVisible();
        const notice = page.getByTestId("visit-alerts-unavailable");
        await expect(notice).toHaveCount(1);
        await expect(notice).toHaveText(NOTICE + ".");
        await expect(notice).toHaveAttribute("role", "status");
        // Where the list would be and above the visit cards (CGR-272).
        const cards = page.getByRole("list", { name: "Einsätze" });
        if (await cards.count()) {
          const [n, c] = await Promise.all([notice.boundingBox(), cards.boundingBox()]);
          expect(n && c && n.y < c.y).toBe(true);
        }
        // Never a silent omission: no follow-up list rendered as if empty; the notice on every render while it fails.
        await expect(page.getByTestId("followup-queue")).toHaveCount(0);
        await page.reload();
        await expect(page.getByTestId("visit-alerts-unavailable")).toHaveCount(1);
        // Each failed load is counted for her team and the Zurich day (team level, never per person).
        expect(failuresToday()).toBeGreaterThanOrEqual(before + 2);
      } finally {
        restoreAlerts();
      }

      await page.reload();
      await expect(page.getByRole("navigation", { name: "Tag wechseln" })).toBeVisible();
      await expect(page.getByText(NOTICE)).toHaveCount(0);
    });
  }

  test("/team: the team view stays and the notice stands in place of «Einsätze mit Handlungsbedarf»", async ({ page }) => {
    await signIn(page, NURSE);
    await page.goto("/team");
    await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
    await expect(page.getByText(NOTICE)).toHaveCount(0);
    breakAlerts();
    try {
      await page.reload();
      await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
      await expect(page.getByTestId("visit-alerts-unavailable")).toHaveText(NOTICE + ".");
      await expect(page.getByTestId("visit-alerts")).toHaveCount(0);
    } finally {
      restoreAlerts();
    }
    await page.reload();
    await expect(page.getByText(NOTICE)).toHaveCount(0);
  });
});
