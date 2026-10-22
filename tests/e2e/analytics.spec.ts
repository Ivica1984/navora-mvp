import { expect, test, type Page } from "@playwright/test";

// AN1 — pilot impact dashboard. Synthetic local-only accounts from supabase/seed.sql.
const OPS = "ops.test@navora.test"; // coordinator: organisation and all teams
const NURSE = "pflege.test@navora.test"; // Testteam Nord only
const PASSWORD = "navora-local-only";

async function signIn(page: Page, email: string, landing: RegExp) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(landing);
}

test("Operations sees the organisation and every team, with definitions and sources (AN1)", async ({ page }) => {
  await signIn(page, OPS, /\/operations$/);
  await page.goto("/analytics");
  const org = page.getByRole("region", { name: "Ganze Organisation" });
  await expect(org).toBeVisible();
  await expect(org).toContainText("Quelle:");
  await expect(org.locator('[data-kpi="cover_without_operations"]')).toContainText("COVER1 ist noch nicht gebaut");
  await expect(page.getByRole("region", { name: "Team Testteam Nord" })).toBeVisible();
});

test("a nurse sees only her own team, never organisation figures (AN1)", async ({ page }) => {
  await signIn(page, NURSE, /\/field$/);
  await page.goto("/analytics");
  await expect(page.getByRole("region", { name: "Ganze Organisation" })).toHaveCount(0);
  await expect(page.getByRole("region", { name: /^Team / })).toHaveCount(1);
});
