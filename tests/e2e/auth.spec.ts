import { expect, test, type Page } from "@playwright/test";

// Synthetic local-only accounts from supabase/seed.sql (T9 roles are placeholders).
const COACH = "coach.test@navora.test"; //  org A, role coach, no team
const NURSE = "pflege.test@navora.test"; // org A, role nurse, Testteam Nord
const FOREIGN = "fremd.test@navora.test"; // org B, role admin
const PASSWORD = "navora-local-only";

async function signIn(page: Page, password = PASSWORD, email = COACH) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(password);
  await page.getByRole("button", { name: "Anmelden" }).click();
}

/** Signs in and fails with a precise reason: credentials rejected vs. session not kept. */
async function signInOk(page: Page, email = COACH) {
  await signIn(page, PASSWORD, email);
  const error = page.getByRole("alert").filter({ hasText: "Anmeldung fehlgeschlagen" });
  await page.waitForURL(/\/(operations|login)$/);
  await page.waitForLoadState("networkidle");
  await expect(error, "sign-in action returned an error (credentials rejected)").toHaveCount(0);
  await expect(page, "sign-in succeeded but the session was not kept (redirected back)").toHaveURL(/\/operations$/);
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
    await signInOk(page);
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

  test("a coach outside the team cannot start the team's visit (T9)", async ({ page }) => {
    await signInOk(page, COACH);
    await page.goto("/visits");

    // Runs before the nurse test, so visit 501 (Testteam Nord) is still planned.
    await page.getByRole("button").filter({ hasText: "Geplant" }).first().click();

    const dialog = page.waitForEvent("dialog");
    await page.getByRole("button", { name: "Einsatz starten" }).click();
    const message = await dialog;
    expect(message.message()).toContain("gehörst nicht zum zuständigen Team");
    await message.dismiss();
  });

  test("a team member starts a visit of her own team (server action + RLS)", async ({ page }) => {
    await signInOk(page, NURSE);
    await page.goto("/visits");

    await page.getByRole("button").filter({ hasText: "Geplant" }).first().click();
    await page.getByRole("button", { name: "Einsatz starten" }).click();

    await expect(page.getByRole("button", { name: "Einsatz abschließen" })).toBeVisible();

    // T10: completing goes through complete_visit() and does NOT make the visit billable (SR-09).
    await page.getByRole("button", { name: "Einsatz abschließen" }).click();
    await expect(page.getByRole("button", { name: "Einsatz abschließen" })).toHaveCount(0);
    const billable = page.getByText("Abrechenbar", { exact: true }).locator("..");
    await expect(billable).toContainText("Nein");
  });

  test("a coach's team change is saved by the audited command and survives a reload (T10)", async ({ page }) => {
    await signInOk(page, COACH);
    await page.goto("/teams");

    const focus = page.getByText("Coach-Fokus", { exact: true }).locator("..");
    const before = (await focus.textContent())?.includes("Aktiv") ? "Aktiv" : "Normal";
    const after = before === "Aktiv" ? "Normal" : "Aktiv";

    await page.getByRole("button", { name: "Coach-Fokus setzen" }).click();
    await expect(focus).toContainText(after);

    await page.reload();
    await expect(page.getByText("Coach-Fokus", { exact: true }).locator("..")).toContainText(after);
  });

  test("/operations sends no health fields to the browser (T10, SR-06)", async ({ page }) => {
    await signInOk(page, COACH);
    await expect(page.getByRole("heading", { name: "Navora Operations Control Tower" })).toBeVisible();

    const html = await page.content();
    for (const field of [
      "date_of_birth",
      "insurance_provider",
      "diagnosis_tags",
      "emergency_contact_phone",
      "cognitive_status",
      "mobility_status",
      "billable",
    ]) {
      expect(html, `field ${field} must not be in the page payload`).not.toContain(`"${field}"`);
    }
  });

  test("a nurse cannot change team settings (T9)", async ({ page }) => {
    await signInOk(page, NURSE);
    await page.goto("/teams");

    const dialog = page.waitForEvent("dialog");
    await page.getByRole("button", { name: "Coach-Fokus setzen" }).click();
    const message = await dialog;
    expect(message.message()).toContain("fehlende Berechtigung");
    await message.dismiss();
  });

  test("organisations are isolated in the UI (T9)", async ({ page }) => {
    await signInOk(page, COACH);
    await page.goto("/teams");
    await expect(page.getByText("Testteam Nord").first()).toBeVisible();
    await expect(page.getByText("Fremdteam B")).toHaveCount(0);
    await page.goto("/operations");
    await expect(page.getByText("Testfall B1")).toHaveCount(0);
    await page.getByRole("button", { name: "Abmelden" }).click();
    await expect(page).toHaveURL(/\/login$/);

    await signInOk(page, FOREIGN);
    await page.goto("/teams");
    await expect(page.getByText("Fremdteam B").first()).toBeVisible();
    await expect(page.getByText("Testteam Nord")).toHaveCount(0);
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

    await signInOk(page);
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
