import { expect, test, type Page } from "@playwright/test";

// UX2-1 (ADR-131): one shell around every protected route. Phone (< 768 px): a bottom tab bar Heute (/field),
// Team (/team), Arbeitstag (/work) and "Mehr" (every other page the role may open, "Meine Einstellungen" among them,
// "Abmelden" last). Desktop: a sidebar with the same items. Items per role from the UX1-3 route → roles map.
// Synthetic local-only accounts from supabase/seed.sql:
//   pflege.test  nurse, Testteam Nord      ops.test  operations, no team
const PASSWORD = "navora-local-only";
const PHONE = { width: 390, height: 844 };
const DESKTOP = { width: 1440, height: 900 };

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

async function noHorizontalScroll(page: Page, width: number) {
  const scrollWidth = await page.evaluate(() => document.documentElement.scrollWidth);
  expect(scrollWidth, `${page.url()}: scrollWidth ${scrollWidth} at ${width} px`).toBeLessThanOrEqual(width);
}

test.describe("UX2-1 on a phone (390 × 844)", () => {
  test.use({ viewport: PHONE });

  for (const path of ["/field", "/team", "/work", "/settings"]) {
    test(`the nurse on ${path}: tab bar Heute, Team, Arbeitstag, Mehr; no sidebar; no sideways scroll`, async ({ page }) => {
      await signIn(page, "pflege.test@navora.test");
      await page.goto(path);
      await page.waitForLoadState("networkidle");
      const bar = page.getByTestId("tab-bar");
      await expect(bar).toBeVisible();
      await expect(page.getByTestId("shell-sidebar")).toBeHidden();
      await expect(bar.getByRole("link")).toHaveText(["Heute", "Team", "Arbeitstag"]);
      await expect(bar.getByRole("button", { name: "Mehr" })).toBeVisible();
      // Exactly one main menu is exposed at a time.
      await expect(page.getByRole("navigation", { name: "Hauptmenü" })).toHaveCount(1);
      // UX2-8 (part): every tab is at least 44 px high and inside the viewport.
      for (const tab of await bar.locator("a, button").all()) {
        const box = await tab.boundingBox();
        expect(box).not.toBeNull();
        expect(box!.height).toBeGreaterThanOrEqual(44);
        expect(box!.y + box!.height).toBeLessThanOrEqual(PHONE.height);
      }
      await noHorizontalScroll(page, PHONE.width);
    });
  }

  test("aria-current follows the route; a sub-route marks its tab", async ({ page }) => {
    await signIn(page, "pflege.test@navora.test");
    const bar = page.getByTestId("tab-bar");
    await page.goto("/field");
    await expect(bar.getByRole("link", { name: "Heute" })).toHaveAttribute("aria-current", "page");
    await expect(bar.getByRole("link", { name: "Team" })).not.toHaveAttribute("aria-current", /.*/);
    await bar.getByRole("link", { name: "Team" }).click();
    await page.waitForURL(/\/team$/);
    await expect(bar.getByRole("link", { name: "Team" })).toHaveAttribute("aria-current", "page");
    await page.goto("/team/vorschlaege");
    await expect(bar.getByRole("link", { name: "Team" })).toHaveAttribute("aria-current", "page");
    await bar.getByRole("link", { name: "Arbeitstag" }).click();
    await page.waitForURL(/\/work$/);
    await expect(bar.getByRole("link", { name: "Arbeitstag" })).toHaveAttribute("aria-current", "page");
  });

  test("Mehr opens the rest of her menu, Meine Einstellungen among it and Abmelden last; Escape closes it", async ({ page }) => {
    await signIn(page, "pflege.test@navora.test");
    await page.goto("/field");
    const more = page.getByTestId("tab-more-button");
    await expect(more).toHaveAttribute("aria-expanded", "false");
    await expect(page.getByTestId("tab-more")).toHaveCount(0);
    await more.click();
    await expect(more).toHaveAttribute("aria-expanded", "true");
    const panel = page.getByTestId("tab-more");
    await expect(panel.getByRole("link")).toHaveText(["Kennzahlen", "Meine Einstellungen"]);
    const last = await panel.evaluate((root) => {
      const items = Array.from(root.querySelectorAll("a, button")) as HTMLElement[];
      return (items[items.length - 1]?.textContent ?? "").trim();
    });
    expect(last).toBe("Abmelden");
    // Keyboard: Escape closes the list and returns focus to "Mehr".
    await page.keyboard.press("Escape");
    await expect(page.getByTestId("tab-more")).toHaveCount(0);
    await expect(more).toBeFocused();
    // The list is reachable by keyboard: Enter on "Mehr" opens it, Tab reaches its first item.
    await page.keyboard.press("Enter");
    await expect(panel.getByRole("link", { name: "Kennzahlen" })).toBeVisible();
    await page.keyboard.press("Tab");
    await expect(panel.getByRole("link", { name: "Kennzahlen" })).toBeFocused();
    await panel.getByRole("link", { name: "Meine Einstellungen" }).click();
    await page.waitForURL(/\/settings$/);
    // On /settings, "Mehr" carries the active page; the item inside it is aria-current.
    await page.getByTestId("tab-more-button").click();
    await expect(page.getByTestId("tab-more").getByRole("link", { name: "Meine Einstellungen" })).toHaveAttribute("aria-current", "page");
  });

  test("operations without a team: Arbeitstag as the only tab, her pages under Mehr; no Heute, no Team", async ({ page }) => {
    await signIn(page, "ops.test@navora.test");
    await page.goto("/operations");
    const bar = page.getByTestId("tab-bar");
    await expect(bar.getByRole("link")).toHaveText(["Arbeitstag"]);
    await page.getByTestId("tab-more-button").click();
    await expect(page.getByTestId("tab-more").getByRole("link")).toHaveText([
      "Ausnahmen",
      "Aufnahme",
      "Kennzahlen",
      "Meine Einstellungen",
    ]);
    await expect(page.getByTestId("tab-more").getByRole("link", { name: "Ausnahmen" })).toHaveAttribute("aria-current", "page");
    await noHorizontalScroll(page, PHONE.width);
  });

  test("UX2-7 (part): the SIG1 signal area stays above the page content inside the shell on /field and /team", async ({ page }) => {
    await signIn(page, "pflege.test@navora.test");
    for (const path of ["/field", "/team"]) {
      await page.goto(path);
      await page.waitForLoadState("networkidle");
      // The tab bar is at the bottom, so nothing of the shell comes before the page's own header and signals.
      const barTop = (await page.getByTestId("tab-bar").boundingBox())!.y;
      const heading = (await page.getByRole("heading", { level: 1 }).first().boundingBox())!;
      expect(heading.y, path).toBeLessThan(barTop);
      const headerFirst = await page.evaluate(() => {
        const bar = document.querySelector('[data-testid="tab-bar"]');
        const header = document.querySelector("header");
        if (!bar || !header) return null;
        return Boolean(header.compareDocumentPosition(bar) & Node.DOCUMENT_POSITION_FOLLOWING);
      });
      expect(headerFirst, `${path}: the page header comes before the tab bar`).toBe(true);
    }
  });
});

test.describe("UX2-1 on a desktop (1440 × 900)", () => {
  test.use({ viewport: DESKTOP });

  test("the nurse: a sidebar with the same items as the phone, no tab bar, aria-current on the page", async ({ page }) => {
    await signIn(page, "pflege.test@navora.test");
    await page.goto("/team");
    const sidebar = page.getByTestId("shell-sidebar");
    await expect(sidebar).toBeVisible();
    await expect(page.getByTestId("tab-bar")).toBeHidden();
    const menu = page.getByRole("navigation", { name: "Hauptmenü" });
    await expect(menu).toHaveCount(1);
    await expect(menu.getByRole("link")).toHaveText(["Mein Tag", "Dein Team", "Mein Arbeitstag", "Kennzahlen", "Meine Einstellungen"]);
    await expect(menu.getByRole("link", { name: "Dein Team" })).toHaveAttribute("aria-current", "page");
    await expect(sidebar.getByRole("button", { name: "Abmelden" })).toBeVisible();
    // UX2-12 (part): the product name is not a heading.
    await expect(sidebar.getByRole("heading")).toHaveCount(0);
    await expect(sidebar.getByText("NAVORA", { exact: true })).toBeVisible();
    await noHorizontalScroll(page, DESKTOP.width);
  });

  test("UX2-8 (part): the sidebar items are reachable by keyboard", async ({ page }) => {
    await signIn(page, "pflege.test@navora.test");
    await page.goto("/settings");
    const first = page.getByRole("navigation", { name: "Hauptmenü" }).getByRole("link").first();
    await first.focus();
    await expect(first).toBeFocused();
    await page.keyboard.press("Tab");
    await expect(page.getByRole("navigation", { name: "Hauptmenü" }).getByRole("link", { name: "Dein Team" })).toBeFocused();
  });
});
