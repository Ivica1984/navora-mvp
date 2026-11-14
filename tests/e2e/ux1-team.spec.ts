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
    // Shown without expanding: the member list starts open and the text and link are visible. UX2-15 (ADR-133): the
    // `details` moved inside the status block (changed assertion: `open` is on `push-team-details`, not on the block).
    await expect(status.getByTestId("push-team-details")).toHaveAttribute("open", "");
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

  test("UX2-15: folding the member list never hides the reach gap; summary at least 44 px; gap before any member list, amber", async ({ page }) => {
    await signIn(page, "pflege.test@navora.test");
    await page.goto("/team");
    const status = page.getByTestId("push-team-status");
    await expect(status).toHaveAttribute("data-reach", "gap");
    const details = status.getByTestId("push-team-details");
    const summary = status.getByTestId("push-team-summary");
    const gap = status.getByTestId("push-team-gap");
    await expect(details).toHaveAttribute("open", "");
    // Fold: the sentence and the link stay visible.
    await summary.click();
    await expect(details).not.toHaveAttribute("open", "");
    await expect(gap).toBeVisible();
    await expect(gap).toContainText(REACH_GAP_TEXT);
    await expect(gap.getByRole("link", { name: "Meine Einstellungen" })).toBeVisible();
    // Unfold again: still there.
    await summary.click();
    await expect(details).toHaveAttribute("open", "");
    await expect(gap).toBeVisible();
    const box = await summary.boundingBox();
    expect(box && box.height >= 44).toBeTruthy();
    // `cra` 17:30 answer 2: in the team status block, before any member list, amber.
    const gapBeforeMembers = await page.evaluate(() => {
      const g = document.querySelector('[data-testid="push-team-gap"]');
      const firstList = document.querySelector('[data-testid="push-team-members"]');
      return !!g && !!firstList && (g.compareDocumentPosition(firstList) & Node.DOCUMENT_POSITION_FOLLOWING) !== 0;
    });
    expect(gapBeforeMembers).toBe(true);
    await expect(gap).toHaveClass(/text-amber-900/);
    await expect(status).toHaveClass(/border-amber-800/);
    await expect(status).not.toHaveClass(/rose-/);
  });
});
