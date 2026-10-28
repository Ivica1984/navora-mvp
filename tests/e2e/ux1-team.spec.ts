import { expect, test, type Page } from "@playwright/test";
import { REACH_GAP_TEXT } from "@/features/push/rules";

// UX1 part (g) (ADR-109): UX1-24 (`uxa` UXR-7; `cra` C-3) on /team at phone width.
// Synthetic local-only accounts from supabase/seed.sql: pflege.test, nurse in Testteam Nord (2 members, push off).
const PASSWORD = "navora-local-only";
const PHONE = { width: 390, height: 844 };

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

test.describe("UX1 part (g) at 390 × 844", () => {
  test.use({ viewport: PHONE });

  test("UX1-24: while not every member receives signals outside the app, the line is open, amber, with text and link", async ({ page }) => {
    await signIn(page, "pflege.test@navora.test");
    await page.goto("/team");
    const status = page.getByTestId("push-team-status");
    await expect(status).toHaveAttribute("data-reach", "gap");
    // Shown without expanding: the details element is open and the text and link are visible.
    await expect(status).toHaveAttribute("open", "");
    const gap = status.getByTestId("push-team-gap");
    await expect(gap).toBeVisible();
    await expect(gap).toContainText(REACH_GAP_TEXT);
    const link = gap.getByRole("link", { name: "Meine Einstellungen" });
    await expect(link).toBeVisible();
    await expect(link).toHaveAttribute("href", "/settings");
    // Amber, not the P1 colour.
    await expect(status).toHaveClass(/border-amber-800/);
    await expect(status).not.toHaveClass(/rose-/);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
    expect(overflow).toBeLessThanOrEqual(0);
  });
});
