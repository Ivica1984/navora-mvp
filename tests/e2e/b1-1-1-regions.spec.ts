import { expect, test, type Page } from "@playwright/test";

// B1.1-1 (Δ1, ADR-186): the region is chosen from the list; legacy values are listed for Operations as «Region nicht
// zugeordnet». Synthetic local-only accounts (supabase/seed.sql). «Basel Pilot» (org A seed, FE-066) is never mapped by
// any spec, so the section is present whatever ran before (workers: 1).
const OPS = "ops.test@navora.test"; //     org A, operations
const COACH = "coach.test@navora.test"; // org A, coach
const PASSWORD = "navora-local-only";

async function signIn(page: Page, email: string, landing: RegExp) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(landing);
}

for (const width of [390, 1440]) {
  test(`at ${width} px the intake region is a list and Operations sees «Region nicht zugeordnet»`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 });
    await signIn(page, OPS, /\/operations$/);

    await page.goto("/intake");
    const region = page.getByRole("form", { name: "Neue Anfrage" }).getByLabel("Region");
    await expect(region).toHaveJSProperty("tagName", "SELECT");
    await expect(region.locator("option:not([disabled])")).toHaveText(["Basel-Stadt", "Basel-Landschaft"]);

    await page.goto("/operations");
    const section = page.getByRole("region", { name: "Region nicht zugeordnet" });
    await expect(section).toBeVisible();
    const pilot = section.getByRole("form", { name: "Region zuordnen: Basel Pilot" });
    await expect(pilot).toBeVisible();
    await expect(pilot).toContainText("Teams");
    await expect(pilot.getByLabel("Region aus der Liste").locator("option:not([disabled])")).toHaveText(["Basel-Stadt", "Basel-Landschaft"]);
    expect(await section.evaluate((el) => el.scrollWidth - el.clientWidth)).toBeLessThanOrEqual(0);
  });
}

test("a coach does not see «Region nicht zugeordnet»", async ({ page }) => {
  await signIn(page, COACH, /\/(operations|coach|team)/);
  await page.goto("/operations");
  await expect(page.getByRole("region", { name: "Region nicht zugeordnet" })).toHaveCount(0);
});
