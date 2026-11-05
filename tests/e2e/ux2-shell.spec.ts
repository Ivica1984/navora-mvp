import { expect, test, type Page } from "@playwright/test";

// UX2-1 (ADR-131): one shell around every protected route. Phone (< 768 px): a bottom tab bar Heute (/field),
// Team (/team), Arbeitstag (/work) and "Mehr" (every other page the role may open, "Meine Einstellungen" among them,
// "Abmelden" last). Desktop: a sidebar with the same items. Items per role from the UX1-3 route → roles map.
// Synthetic local-only accounts from supabase/seed.sql:
//   pflege.test  nurse, Testteam Nord      ops.test  operations, no team      coach.test  coach, no team
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

  // UX2-31 (1) (uxa UXR-75): her home (/operations, where sign-in lands) is her first tab.
  test("UX2-31: operations without a team: Ausnahmen first, then Arbeitstag; the rest under Mehr; no Heute, no Team", async ({ page }) => {
    await signIn(page, "ops.test@navora.test");
    await expect(page).toHaveURL(/\/operations$/);
    const bar = page.getByTestId("tab-bar");
    await expect(bar.getByRole("link")).toHaveText(["Ausnahmen", "Arbeitstag"]);
    await expect(bar.getByRole("link", { name: "Ausnahmen" })).toHaveAttribute("aria-current", "page");
    await page.getByTestId("tab-more-button").click();
    await expect(page.getByTestId("tab-more").getByRole("link")).toHaveText(["Aufnahme", "Kennzahlen", "Meine Einstellungen"]);
    await noHorizontalScroll(page, PHONE.width);
  });

  test("UX2-31: a coach without a team: Ausnahmen is the first tab", async ({ page }) => {
    await signIn(page, "coach.test@navora.test");
    await page.goto("/operations");
    await expect(page.getByTestId("tab-bar").getByRole("link").first()).toHaveText("Ausnahmen");
  });

  // UX2-31 (2) (uxa UXR-78, WCAG 2.2 2.4.11): a control reached by Tab or Shift+Tab is never under the fixed tab bar or
  // the sticky page header. A spacer makes the page long enough whatever the seed holds today; the controls are the
  // page's own.
  const FOCUSABLE = 'a[href], button:not([disabled]), input:not([disabled]):not([type="hidden"]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

  async function pageControls(page: Page): Promise<number> {
    return page.evaluate((selector) => {
      const content = document.querySelector('[data-testid="shell-content"]')!;
      const header = Array.from(content.querySelectorAll("header")).find((el) => getComputedStyle(el).position === "sticky");
      const controls = Array.from(content.querySelectorAll<HTMLElement>(selector)).filter(
        (el) => el.getClientRects().length > 0 && el.tabIndex >= 0 && !(header && header.contains(el)),
      );
      controls.forEach((el, i) => el.setAttribute("data-ux231", String(i)));
      return controls.length;
    }, FOCUSABLE);
  }

  async function addSpacer(page: Page, where: "start" | "end") {
    await page.evaluate((at) => {
      const content = document.querySelector('[data-testid="shell-content"]')!;
      const spacer = document.createElement("div");
      spacer.style.height = "2000px";
      spacer.setAttribute("aria-hidden", "true");
      if (at === "start") content.prepend(spacer);
      else content.append(spacer);
    }, where);
  }

  test("UX2-31: on /field, Tab to the last control leaves it fully above the tab bar", async ({ page }) => {
    await signIn(page, "pflege.test@navora.test");
    await page.goto("/field");
    await page.waitForLoadState("networkidle");
    await addSpacer(page, "start");
    const count = await pageControls(page);
    expect(count, "the page has at least two controls below its header").toBeGreaterThanOrEqual(2);
    await page.evaluate(() => window.scrollTo(0, 0));
    await page.locator(`[data-ux231="${count - 2}"]`).evaluate((el: HTMLElement) => el.focus({ preventScroll: true }));
    await page.keyboard.press("Tab");
    const last = page.locator(`[data-ux231="${count - 1}"]`);
    await expect(last).toBeFocused();
    const box = (await last.boundingBox())!;
    const barTop = (await page.getByTestId("tab-bar").boundingBox())!.y;
    expect(box.y, "the control is inside the viewport").toBeGreaterThanOrEqual(0);
    expect(box.y + box.height, "the control's bottom edge is above the tab bar's top edge").toBeLessThanOrEqual(barTop);
  });

  test("UX2-31: on /field, Shift+Tab to the first control below the sticky header leaves it fully below the header", async ({ page }) => {
    await signIn(page, "pflege.test@navora.test");
    await page.goto("/field");
    await page.waitForLoadState("networkidle");
    await addSpacer(page, "end");
    const count = await pageControls(page);
    expect(count).toBeGreaterThanOrEqual(2);
    await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
    await page.locator('[data-ux231="1"]').evaluate((el: HTMLElement) => el.focus({ preventScroll: true }));
    await page.keyboard.press("Shift+Tab");
    const first = page.locator('[data-ux231="0"]');
    await expect(first).toBeFocused();
    const box = (await first.boundingBox())!;
    const header = page.getByTestId("shell-content").locator("header").first();
    const headerBox = (await header.boundingBox())!;
    expect(box.y, "the control's top edge is below the sticky header").toBeGreaterThanOrEqual(headerBox.y + headerBox.height);
    expect(box.y + box.height, "the control is above the tab bar").toBeLessThanOrEqual(
      (await page.getByTestId("tab-bar").boundingBox())!.y,
    );
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
