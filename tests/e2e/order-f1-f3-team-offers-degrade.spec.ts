import { execFileSync } from "node:child_process";
import { expect, test, type Page } from "@playwright/test";

// ORDER-F1-F3 (PO Active now 2026-11-26 02:39 point 2, scope (c)). On staging (path 3 red on 4ac388cf) the offer list
// read `public.team_order_offers()` took 6 934 ms of an 8 s statement timeout; one more step and the whole /team
// re-render would have thrown (57014), taking every other section of the carer's page with it. Here the failure is
// forced deterministically by revoking EXECUTE from `authenticated` (42501): the same app code path (PostgREST error),
// no timing dependence (pattern of order-f1-list-degrade.spec.ts and perf1-field-degrade.spec.ts).
// Asserts: /team keeps its heading and its other sections; one visible line stands in the offer section; the list is
// never shown as empty («Zurzeit kein Schichtangebot»); no horizontal scroll at 390 px; after the restore the list is
// back. Fixture: local Supabase only (port 54322); the grant is restored in `finally` and again in afterAll (one worker,
// serial run, playwright.config.ts), so no later spec sees the revoked state. Synthetic seed account only.
const NURSE = "pflegebs.test@navora.test"; // member of «Testteam Basel» (supabase/seed.sql)
const PASSWORD = "navora-local-only";
const DB_URL = process.env.E2E_DB_URL ?? "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
const LOCAL_DB = /^postgres(ql)?:\/\/[^@]+@(127\.0\.0\.1|localhost):54322\//;
const NOTICE = "Schichtangebote konnten nicht geladen werden, bitte neu laden.";
const EMPTY = "Zurzeit kein Schichtangebot für deine Teams.";

function psql(sql: string): string {
  if (!LOCAL_DB.test(DB_URL)) throw new Error("ORDER-F1-F3 fixture: only the local Supabase database (port 54322)");
  return execFileSync("psql", [DB_URL, "-X", "-q", "-At", "-v", "ON_ERROR_STOP=1", "-c", sql], { encoding: "utf8" }).trim();
}
// Exactly the grant of the canonical file (supabase/schema/functions/public.team_order_offers.sql).
const breakList = () => psql("revoke execute on function public.team_order_offers() from authenticated");
const restoreList = () => psql("grant execute on function public.team_order_offers() to authenticated");

async function signIn(page: Page) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(NURSE);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

test.describe("ORDER-F1-F3: /team when the shift offer list read fails", () => {
  test.afterAll(() => {
    restoreList();
  });

  for (const width of [390, 1440]) {
    test(`at ${width} px only the offer section shows the failure; the rest of /team stands`, async ({ page }) => {
      await page.setViewportSize({ width, height: 900 });
      await signIn(page);
      await page.goto("/team");
      // Control: with the list available the section renders its list and the notice is absent.
      await expect(page.getByRole("list", { name: "Schichtangebote" })).toHaveCount(1);
      await expect(page.getByText(NOTICE)).toHaveCount(0);

      breakList();
      try {
        await page.reload();
        await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
        const section = page.getByTestId("shift-offers");
        await expect(section.getByRole("heading", { name: "Schichtangebote" })).toBeVisible();
        const notice = section.getByTestId("shift-offers-failed");
        await expect(notice).toHaveCount(1);
        await expect(notice).toHaveRole("alert");
        await expect(notice).toHaveText(NOTICE);
        // Never a silent «none»: no list, no empty-state sentence.
        await expect(page.getByRole("list", { name: "Schichtangebote" })).toHaveCount(0);
        await expect(page.getByText(EMPTY)).toHaveCount(0);
        // The rest of the page stays: the team's other entries are still there.
        await expect(page.getByTestId("reach-link")).toHaveCount(1);
        expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
      } finally {
        restoreList();
      }

      // After the restore the list is back and the notice is gone.
      await page.reload();
      await expect(page.getByTestId("shift-offers-failed")).toHaveCount(0);
      await expect(page.getByRole("list", { name: "Schichtangebote" })).toHaveCount(1);
    });
  }
});
