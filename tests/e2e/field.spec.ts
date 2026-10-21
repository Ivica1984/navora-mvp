import { expect, test, type Page } from "@playwright/test";

// F1 — the nurse's day (/field). Synthetic local-only accounts from supabase/seed.sql.
// Runs after auth.spec.ts (serial, one worker): by then visit 501 (08:00, Testteam Nord)
// is completed and visit 502 (10:00, Testteam Nord) is still "started".
const COACH = "coach.test@navora.test"; //  org A, coach, in no team
const NURSE = "pflege.test@navora.test"; // org A, nurse, Testteam Nord
const PASSWORD = "navora-local-only";

// The seed uses the database's current_date; CI's database runs in UTC.
const SEED_DAY = new Date().toISOString().slice(0, 10);

async function signIn(page: Page, email: string, landing: RegExp) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(landing);
}

test.describe("field tool (F1)", () => {
  test("a nurse lands on her day after sign-in", async ({ page }) => {
    await signIn(page, NURSE, /\/field$/);
    await expect(page.getByRole("navigation", { name: "Tag wechseln" })).toBeVisible();
    // Visiting "/" also lands a nurse in the field tool.
    await page.goto("/");
    await expect(page).toHaveURL(/\/field$/);
  });

  test("a nurse sees exactly her team's visits of the day, with minimal client context", async ({ page }) => {
    await signIn(page, NURSE, /\/field$/);
    await page.goto(`/field?datum=${SEED_DAY}`);

    const visits = page.getByRole("list", { name: "Einsätze" }).getByRole("article");
    await expect(visits).toHaveCount(2);
    await expect(page.getByRole("article", { name: /08:00 – 08:45/ })).toContainText("Testfall 08");
    await expect(page.getByRole("article", { name: /10:00 – 10:30/ })).toContainText("Testteam Nord");
    // Visit 503 (11:00) belongs to Testteam West; org-B visits are never visible.
    await expect(page.getByRole("article", { name: /11:00/ })).toHaveCount(0);
    await expect(page.getByText("Fremdteam B")).toHaveCount(0);

    // Data minimisation: no health or billing fields in the page payload.
    const html = await page.content();
    for (const field of ["diagnosis_tags", "cognitive_status", "mobility_status", "date_of_birth", "insurance_provider", "billable"]) {
      expect(html, `field ${field} must not be in the page payload`).not.toContain(`"${field}"`);
    }
  });

  test("a nurse completes a running visit; the change is saved", async ({ page }) => {
    await signIn(page, NURSE, /\/field$/);
    await page.goto(`/field?datum=${SEED_DAY}`);

    const card = page.getByRole("article", { name: /10:00 – 10:30/ });
    await expect(card).toContainText("Gestartet");
    await card.getByRole("button", { name: "Einsatz abschliessen" }).click();

    await expect(card).toContainText("Abgeschlossen");
    await expect(card.getByRole("button")).toHaveCount(0);

    await page.reload();
    await expect(page.getByRole("article", { name: /10:00 – 10:30/ })).toContainText("Abgeschlossen");
  });

  test("a coach who is in no team gets an empty day, not someone else's visits", async ({ page }) => {
    await signIn(page, COACH, /\/operations$/);
    await page.goto(`/field?datum=${SEED_DAY}`);
    await expect(page.getByText("Keine Einsätze deiner Teams an diesem Tag.")).toBeVisible();
  });

  test("day navigation and an invalid date parameter", async ({ page }) => {
    await signIn(page, NURSE, /\/field$/);
    await page.goto("/field?datum=2026-02-30");
    await expect(page.getByRole("heading", { level: 1 })).toHaveText("Heute");

    await page.getByRole("link", { name: "Folgetag →" }).click();
    await expect(page).toHaveURL(/\/field\?datum=\d{4}-\d{2}-\d{2}$/);
    await expect(page.getByRole("heading", { level: 1 })).not.toHaveText("Heute");
  });

  test("works on a phone-sized screen without horizontal scrolling", async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 740 });
    await signIn(page, NURSE, /\/field$/);
    await page.goto(`/field?datum=${SEED_DAY}`);
    await expect(page.getByRole("list", { name: "Einsätze" })).toBeVisible();
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
    expect(overflow).toBeLessThanOrEqual(0);
  });
});
