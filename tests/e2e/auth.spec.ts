import { expect, test, type Page } from "@playwright/test";

// Synthetic local-only account from supabase/seed.sql.
const EMAIL = "coach.test@navora.test";
const PASSWORD = "navora-local-only";

async function signIn(page: Page, password = PASSWORD) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(EMAIL);
  await page.getByLabel("Passwort").fill(password);
  await page.getByRole("button", { name: "Anmelden" }).click();
}

test.describe("without a session", () => {
  for (const path of ["/", "/operations", "/teams", "/visits", "/matching", "/partners"]) {
    test(`${path} redirects to /login`, async ({ page }) => {
      await page.goto(path);
      await expect(page).toHaveURL(/\/login$/);
      await expect(page.getByRole("heading", { name: "Admin / Coach anmelden" })).toBeVisible();
    });
  }

  test("login page has no bypass link (SR-07)", async ({ page }) => {
    await page.goto("/login");
    await expect(page.getByText("Zum aktuellen internen MVP-Stand")).toHaveCount(0);
    await expect(page.locator('a[href="/matching"], a[href="/operations"]')).toHaveCount(0);
  });

  test("wrong password shows one generic error and stays on /login", async ({ page }) => {
    await signIn(page, "wrong-password");
    await expect(page.getByRole("alert").filter({ hasText: "Anmeldung fehlgeschlagen" })).toBeVisible();
    await expect(page).toHaveURL(/\/login$/);
  });
});

test.describe("with a session", () => {
  test("sign in, use the app, sign out", async ({ page }) => {
    await signIn(page);
    await expect(page).toHaveURL(/\/operations$/);
    await expect(page.getByRole("heading", { name: "Navora Operations Control Tower" })).toBeVisible();

    // Signed-in users skip the login page.
    await page.goto("/login");
    await expect(page).toHaveURL(/\/operations$/);

    await page.goto("/teams");
    await expect(page.getByRole("heading", { name: "Teams Übersicht" })).toBeVisible();

    // Demo pages stay hidden behind the flag, also for signed-in users (ADR-006).
    const matching = await page.goto("/matching");
    expect(matching?.status()).toBe(404);

    await page.goto("/operations");
    await page.getByRole("button", { name: "Abmelden" }).click();
    await expect(page).toHaveURL(/\/login$/);

    await page.goto("/operations");
    await expect(page).toHaveURL(/\/login$/);
  });

  test("starting a visit runs as a server action and moves it to started", async ({ page }) => {
    await signIn(page);
    await expect(page).toHaveURL(/\/operations$/);
    await page.goto("/visits");

    await page.getByRole("button").filter({ hasText: "Geplant" }).first().click();
    await page.getByRole("button", { name: "Einsatz starten" }).click();

    await expect(page.getByRole("button", { name: "Einsatz abschließen" })).toBeVisible();
  });

  test("no Supabase key or URL is shipped to the browser (ADR-017)", async ({ page }) => {
    const key = process.env.SUPABASE_ANON_KEY;
    test.skip(!key, "SUPABASE_ANON_KEY not set in the test environment");

    const scripts: string[] = [];
    page.on("response", async (response) => {
      if (!response.url().endsWith(".js")) return;
      try {
        scripts.push(await response.text());
      } catch {
        // body unavailable (e.g. redirect) — nothing to inspect
      }
    });

    await signIn(page);
    await expect(page).toHaveURL(/\/operations$/);
    await page.goto("/visits");
    await expect(page).toHaveURL(/\/visits$/);
    await page.waitForLoadState("networkidle");

    const html = await page.content();
    expect(html).not.toContain(key!);
    expect(scripts.length).toBeGreaterThan(0);
    for (const body of scripts) {
      expect(body).not.toContain(key!);
      expect(body).not.toContain("127.0.0.1:54321");
    }
  });
});
