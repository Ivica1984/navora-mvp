import { expect, test, type Page } from "@playwright/test";

// F1 — the nurse's day (/field). Synthetic local-only accounts from supabase/seed.sql.
// Runs after auth.spec.ts (serial, one worker): by then visit 501 (08:00, Testteam Nord)
// is completed and visit 502 (10:00, Testteam Nord) is still "started".
const COACH = "coach.test@navora.test"; //  org A, coach, in no team
const NURSE = "pflege.test@navora.test"; // org A, nurse, Testteam Nord
const PASSWORD = "navora-local-only";

// The seed uses the database's current_date; CI's database runs in UTC.
const SEED_DAY = new Date().toISOString().slice(0, 10);
// Visit 508 (Testteam Nord, 09:00) is planned for the day after and untouched by other tests.
const NEXT_DAY = new Date(Date.now() + 86_400_000).toISOString().slice(0, 10);

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

  test("full field path: depart, start, pause, resume, complete — with separate times (F2)", async ({ page }) => {
    await signIn(page, NURSE, /\/field$/);
    await page.goto(`/field?datum=${NEXT_DAY}`);

    const card = page.getByRole("article", { name: /09:00 – 09:45/ });
    await expect(card).toContainText("Geplant");
    await expect(card.getByRole("region", { name: "Erfasste Zeit" })).toHaveCount(0);

    const steps: Array<[string, string]> = [
      ["Losfahren", "Unterwegs"],
      ["Einsatz starten", "Gestartet"],
      ["Pause", "Pausiert"],
      ["Fortsetzen", "Gestartet"],
      ["Einsatz abschliessen", "Abgeschlossen"],
    ];
    for (const [button, status] of steps) {
      await card.getByRole("button", { name: button }).click();
      await expect(card).toContainText(status);
    }

    await expect(card.getByRole("button")).toHaveCount(0);
    const times = card.getByRole("region", { name: "Erfasste Zeit" });
    await expect(times).toContainText("Anfahrt");
    await expect(times).toContainText("Pflege");
    await expect(times).toContainText("Pause");
    await expect(times).not.toContainText("unstimmig");

    await page.reload();
    await expect(page.getByRole("article", { name: /09:00 – 09:45/ })).toContainText("Abgeschlossen");
    await expect(page.getByRole("article", { name: /09:00 – 09:45/ }).getByRole("region", { name: "Erfasste Zeit" })).toBeVisible();
  });

  test("time corrections need a reason, keep the original and refuse impossible orders (F3)", async ({ page }) => {
    // Corrections use Swiss wall-clock time on the day the event was recorded.
    const zurich = (offsetMin: number) =>
      new Intl.DateTimeFormat("de-CH", { timeZone: "Europe/Zurich", hour: "2-digit", minute: "2-digit", hourCycle: "h23" })
        .format(new Date(Date.now() + offsetMin * 60_000));
    test.skip(zurich(0) < "00:30", "too close to midnight in Zurich for a same-day correction");

    await signIn(page, NURSE, /\/field$/);
    await page.goto(`/field?datum=${NEXT_DAY}`);
    const card = page.getByRole("article", { name: /09:00 – 09:45/ });
    await card.getByText("Zeiten ansehen und korrigieren").click();
    const timeline = card.getByRole("list", { name: "Zeitverlauf" });

    // Impossible order: completion at 00:00 would lie before the start → refused with a clear message.
    const completed = timeline.getByRole("listitem").filter({ hasText: "Abgeschlossen" });
    await completed.getByRole("button", { name: "Korrigieren" }).click();
    await completed.getByLabel("Richtige Uhrzeit").fill("00:00");
    await completed.getByLabel("Begründung").fill("Test einer unmöglichen Reihenfolge");
    await completed.getByRole("button", { name: "Korrektur speichern" }).click();
    await expect(completed.getByTestId("command-error")).toContainText("Reihenfolge");
    await completed.getByRole("button", { name: "Abbrechen" }).click();

    // Valid correction: departure 20 minutes earlier, with a reason.
    const departed = timeline.getByRole("listitem").filter({ hasText: "Losgefahren" });
    await departed.getByRole("button", { name: "Korrigieren" }).click();
    await departed.getByLabel("Richtige Uhrzeit").fill(zurich(-20));
    await departed.getByLabel("Begründung").fill("Abfahrt zu spät getippt");
    await departed.getByRole("button", { name: "Korrektur speichern" }).click();

    await expect(departed).toContainText("korrigiert");
    await expect(departed).toContainText("Abfahrt zu spät getippt");
    await expect(card.getByRole("region", { name: "Erfasste Zeit" })).toContainText(/(19|20|21) min/);

    await page.reload();
    const again = page.getByRole("article", { name: /09:00 – 09:45/ });
    await again.getByText("Zeiten ansehen und korrigieren").click();
    await expect(again.getByRole("listitem").filter({ hasText: "Losgefahren" })).toContainText("korrigiert");
  });

  test("observations: recorded with provenance, edited as a new version, handed over to the next visit (F4)", async ({ page }) => {
    await signIn(page, NURSE, /\/field$/);
    await page.goto(`/field?datum=${SEED_DAY}`);

    // Visit 502 (10:00, completed earlier in this file) — client Testfall 08.
    const card = page.getByRole("article", { name: /10:00 – 10:30/ });
    const observations = card.getByRole("region", { name: "Beobachtungen" });
    await observations.getByLabel("Neue Beobachtung").fill("Klientin müde, trinkt wenig. Bitte morgen Trinkmenge beobachten.");
    await observations.getByLabel("Für die Übergabe markieren").check();
    await observations.getByRole("button", { name: "Beobachtung speichern" }).click();

    const entry = observations.getByRole("listitem").filter({ hasText: "trinkt wenig" });
    await expect(entry).toContainText("von dir");
    await expect(entry).toContainText("Übergabe");
    await expect(observations.getByLabel("Neue Beobachtung")).toHaveValue("");

    // Change = new version; the edited text replaces the old one in the view.
    await entry.getByRole("button", { name: "Ändern" }).click();
    await observations.getByLabel("Beobachtung ändern").fill("Klientin müde, trinkt wenig (ca. 0.5 l bis Mittag). Bitte morgen Trinkmenge beobachten.");
    await observations.getByRole("button", { name: "Änderung speichern" }).click();
    await expect(observations.getByRole("listitem").filter({ hasText: "ca. 0.5 l" })).toContainText("geändert");
    await expect(observations.getByText("trinkt wenig. Bitte", { exact: false })).toHaveCount(0);

    // Handover: shown on the same client's visit of the team on the next day (visit 508).
    await page.goto(`/field?datum=${NEXT_DAY}`);
    const handover = page.getByRole("article", { name: /09:00 – 09:45/ }).getByRole("region", { name: "Übergabe" });
    await expect(handover).toContainText("ca. 0.5 l bis Mittag");
    await expect(handover).toContainText("von dir");
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
