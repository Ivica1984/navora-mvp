import { expect, test, type Page } from "@playwright/test";

// UX1 parts (a) and (b) (ADR-103): phone width of /settings, /admin and /operations, and the menu by role.
// Synthetic local-only accounts from supabase/seed.sql:
//   pflege.test  nurse, Testteam Nord      coach.test  coach, no team
//   ops.test     operations, no team       admin.test  administrator of org A, no team
const PASSWORD = "navora-local-only";
const PHONE = { width: 390, height: 844 };

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

async function noHorizontalScroll(page: Page, path: string) {
  await page.goto(path);
  await page.waitForLoadState("networkidle");
  const width = await page.evaluate(() => document.documentElement.scrollWidth);
  expect(width, `${path}: scrollWidth ${width} at ${PHONE.width} px`).toBeLessThanOrEqual(PHONE.width);
}

/** Texts and markers with which a page tells a person it is not for her (existing refusals, unchanged). */
async function expectNoRefusal(page: Page, path: string) {
  await expect(page.getByTestId("admin-denied"), path).toHaveCount(0);
  await expect(page.getByTestId("no-kpis"), path).toHaveCount(0);
  await expect(page.getByText(/vorbehalten/), path).toHaveCount(0);
  await expect(page.getByTestId("access-ended"), path).toHaveCount(0);
}

test.describe("UX1-1 / UX1-2: no horizontal scroll at 390 px", () => {
  test.use({ viewport: PHONE });

  test("a nurse on /settings: no sideways scroll, the menu is collapsed, the push section reads in full", async ({ page }) => {
    await signIn(page, "pflege.test@navora.test");
    await noHorizontalScroll(page, "/settings");
    // Below 768 px the side column is not shown; the menu is one closed control at the top.
    await expect(page.getByRole("complementary")).toHaveCount(0);
    const menu = page.getByTestId("mobile-menu");
    await expect(menu).toBeVisible();
    await expect(menu.getByRole("link")).toHaveCount(0);
    await menu.locator("summary").click();
    await expect(menu.getByRole("link", { name: "Meine Einstellungen" })).toBeVisible();
    await menu.locator("summary").click();
    // "Abmelden" stays one tap away on the phone, outside the closed menu.
    await expect(page.getByRole("button", { name: "Abmelden" })).toBeVisible();
    // UX1-2 (deviation, ADR-103): the SIG2 flow at 390 px up to the step CI can reach. Without a DPF entry the channel
    // is off in CI (as in push.spec), so the switch is not offered; the state she sees is the confirmed "not active"
    // with the reason, fully inside the page width.
    const section = page.getByRole("region", { name: "Benachrichtigung ausserhalb der App" });
    await expect(section.getByTestId("push-status")).toHaveText("Benachrichtigung ausserhalb der App: nicht aktiv");
    await expect(section.getByTestId("push-information")).toBeVisible();
    await expect(section.getByTestId("push-channel-off")).toBeVisible();
    const box = await section.boundingBox();
    expect(box).not.toBeNull();
    expect(box!.x).toBeGreaterThanOrEqual(0);
    expect(box!.x + box!.width).toBeLessThanOrEqual(PHONE.width);
  });

  test("an administrator on /admin and /operations", async ({ page }) => {
    await signIn(page, "admin.test@navora.test");
    await noHorizontalScroll(page, "/admin");
    await expect(page.getByRole("region", { name: "Mitglieder" })).toBeVisible();
    await noHorizontalScroll(page, "/operations");
    await expect(page.getByRole("region", { name: "Pflegeteams" })).toBeVisible();
  });

  test("operations and a coach on /operations", async ({ page }) => {
    await signIn(page, "ops.test@navora.test");
    await noHorizontalScroll(page, "/operations");
    await page.goto("/settings");
    await page.getByRole("button", { name: "Abmelden" }).click();
    await page.waitForURL(/\/login$/);
    await signIn(page, "coach.test@navora.test");
    await noHorizontalScroll(page, "/operations");
  });
});

// UX1-3: the items each seed person sees (in order) are exactly the pages whose own check admits her.
const MENU: Record<string, { email: string; items: string[] }> = {
  nurse: {
    email: "pflege.test@navora.test",
    items: ["Mein Tag (mobil)", "Mein Arbeitstag", "KPI / Analytics", "Meine Einstellungen"],
  },
  coach: {
    email: "coach.test@navora.test",
    items: ["Operations Board", "Mein Arbeitstag", "KPI / Analytics", "Meine Einstellungen"],
  },
  operations: {
    email: "ops.test@navora.test",
    items: ["Operations Board", "Aufnahme", "Mein Arbeitstag", "KPI / Analytics", "Meine Einstellungen"],
  },
  admin: {
    email: "admin.test@navora.test",
    items: ["Operations Board", "Aufnahme", "Mein Arbeitstag", "KPI / Analytics", "Meine Einstellungen", "Administration"],
  },
};

for (const [role, { email, items }] of Object.entries(MENU)) {
  test(`UX1-3 / UX1-4: the ${role}'s menu shows only pages that admit her, and each opens without a refusal`, async ({ page }) => {
    await signIn(page, email);
    await page.goto("/settings");
    const menu = page.getByRole("navigation", { name: "Hauptmenü" });
    await expect(menu.getByRole("link")).toHaveText(items);
    // UX1-4: no item without a target; the first-MVP pages are not in the menu.
    await expect(page.getByText("Qualitätsmanagement")).toHaveCount(0);
    await expect(menu.locator('a[href="/teams"], a[href="/visits"]')).toHaveCount(0);

    const hrefs = await menu.getByRole("link").evaluateAll((links) => links.map((a) => a.getAttribute("href") ?? ""));
    for (const href of hrefs) {
      const response = await page.goto(href);
      expect(response?.status(), href).toBeLessThan(400);
      await page.waitForLoadState("networkidle");
      await expectNoRefusal(page, href);
    }
  });
}

test("UX1-5: a nurse who types /admin or /intake still gets the existing refusal", async ({ page }) => {
  await signIn(page, "pflege.test@navora.test");
  await page.goto("/admin");
  await expect(page.getByTestId("admin-denied")).toHaveText("Diese Seite ist der NAVORA-Administration vorbehalten.");
  await expect(page.getByRole("navigation", { name: "Hauptmenü" }).getByRole("link", { name: "Administration" })).toHaveCount(0);
  await page.goto("/intake");
  await expect(page.getByText("Die Aufnahme ist Admin- und Operations-Rollen vorbehalten.")).toBeVisible();
});
