import { expect, test, type Page } from "@playwright/test";

// PLATFORM1 (ADR-213): NAVORA operations lands on /platform and reads counts only; anybody else gets the notice.
const PASSWORD = "navora-local-only";

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
}

for (const width of [390, 1440]) {
  test(`NAVORA operations lands on /platform with counts (${width} px)`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 });
    await signIn(page, "navora.test@navora.test");
    await expect(page).toHaveURL(/\/platform$/);
    await expect(page.getByRole("heading", { level: 1, name: "NAVORA-Betrieb" })).toBeVisible();
    await expect(page.getByTestId("platform-orgs")).toBeVisible();
    await expect(page.getByTestId("platform-total-organizations")).toContainText(/\d+/);
    await expect(page.getByRole("rowheader", { name: /Testorganisation S/ })).toBeVisible();
    // counts only: no e-mail address or street of any seed person on the page
    await expect(page.locator("body")).not.toContainText("@navora.test");
    const sideways = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth);
    expect(sideways, "no sideways scroll of the page").toBe(false);
  });
}

test("a nurse opening /platform gets the notice and no counts", async ({ page }) => {
  await signIn(page, "pflege.test@navora.test");
  await expect(page).toHaveURL(/\/field$/);
  await page.goto("/platform");
  await expect(page.getByTestId("platform-no-access")).toBeVisible();
  await expect(page.getByTestId("platform-orgs")).toHaveCount(0);
});
