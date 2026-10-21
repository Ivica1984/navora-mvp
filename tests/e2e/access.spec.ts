import { expect, test, type Page } from "@playwright/test";

// F0 (criteria 3c/3d): team-scoped clinical read, seen through the UI.
// Seed visits: "Pflegekraft Test 1" = Testteam Nord (the nurse's team),
// "Pflegekraft Test 2" = Testteam West, "Pflegekraft Test 3" = Testteam Mitte.
const COACH = "coach.test@navora.test";
const NURSE = "pflege.test@navora.test";
const PASSWORD = "navora-local-only";

async function signIn(page: Page, email: string, landing: RegExp) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(landing);
}

test("a nurse sees only her own team's visits; a coach sees the organisation (F0)", async ({ page }) => {
  await signIn(page, NURSE, /\/field$/);
  await page.goto("/visits");
  await expect(page.getByText("Pflegekraft: Pflegekraft Test 1").first()).toBeVisible();
  await expect(page.getByText("Pflegekraft Test 2")).toHaveCount(0);
  await expect(page.getByText("Pflegekraft Test 3")).toHaveCount(0);

  await page.goto("/operations");
  await page.getByRole("button", { name: "Abmelden" }).click();
  await page.waitForURL(/\/login$/);

  await signIn(page, COACH, /\/operations$/);
  await page.goto("/visits");
  await expect(page.getByText("Pflegekraft Test 2").first()).toBeVisible();
  await expect(page.getByText("Pflegekraft Test 3").first()).toBeVisible();
});
