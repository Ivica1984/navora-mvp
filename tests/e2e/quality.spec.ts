import { expect, test, type Page } from "@playwright/test";

// QG1 — quality hold on a visit. Synthetic local-only accounts from supabase/seed.sql.
// No clinical event types exist until D-16; the UI says so instead of offering invented ones.
const NURSE = "pflege.test@navora.test"; // Testteam Nord
const COACH = "coach.test@navora.test"; //  org A, coach
const OPS = "ops.test@navora.test"; //      org A, operations
const PASSWORD = "navora-local-only";
// The seed and the app use the Europe/Zurich calendar date (ADR-068); CI's clock runs in UTC.
function zurichDay(offset = 0): string {
  const [y, m, d] = new Date().toLocaleDateString("sv-SE", { timeZone: "Europe/Zurich" }).split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d + offset)).toISOString().slice(0, 10);
}
const SEED_DAY = zurichDay();

async function signIn(page: Page, email: string, landing: RegExp) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(landing);
}

test("the team sets a quality hold; only coach or admin lift it, with a reason (QG1)", async ({ page }) => {
  await signIn(page, NURSE, /\/field$/);
  await page.goto(`/field?datum=${SEED_DAY}`);
  const card = page.getByRole("article", { name: /08:00 – 08:45/ });
  const quality = card.getByTestId("quality");

  await quality.getByRole("button", { name: "Ereignis melden" }).click();
  await expect(quality.getByTestId("no-types")).toContainText("D-16");
  await quality.getByRole("button", { name: "Schliessen" }).click();

  // UX1-8 (ADR-104, selector change only): the hold is set from the card's "Mehr" menu (two taps); "Ereignis melden"
  // above stays one tap on the card (UX1-9).
  await card.getByTestId("visit-more").click();
  await card.getByRole("button", { name: "Abrechnungssperre setzen" }).click();
  await quality.getByLabel("Begründung für die Abrechnungssperre").fill("E2E: Leistung strittig");
  await quality.getByRole("button", { name: "Sperre setzen" }).click();
  await expect(quality.getByTestId("quality-hold")).toHaveText("Abrechnungssperre");
  // CSR1 / CGR-13: the hold reads as a billing hold, not as a stop of care.
  await expect(quality.getByTestId("quality-hold-meaning")).toContainText("nur die Abrechnung");
  await expect(quality).not.toContainText("Stopp");
  await expect(card.getByRole("button", { name: "Abrechnungssperre setzen" })).toHaveCount(0);

  // Operations sees the hold but may not lift it (provisional role rule, D-16).
  await page.context().clearCookies();
  await signIn(page, OPS, /\/operations$/);
  const opsHold = page.getByTestId("hold").filter({ hasText: "E2E: Leistung strittig" });
  await opsHold.getByRole("button", { name: "Sperre aufheben" }).click();
  await opsHold.getByLabel("Begründung").fill("Versuch durch Operations");
  await opsHold.getByRole("button", { name: "Aufheben" }).click();
  await expect(opsHold.getByTestId("command-error")).toContainText("Coach oder Admin");

  await page.context().clearCookies();
  await signIn(page, COACH, /\/operations$/);
  const hold = page.getByTestId("hold").filter({ hasText: "E2E: Leistung strittig" });
  await hold.getByRole("button", { name: "Sperre aufheben" }).click();
  await hold.getByLabel("Begründung").fill("Mit Team geklärt, Leistung korrekt");
  await hold.getByRole("button", { name: "Aufheben" }).click();
  await expect(page.getByTestId("hold").filter({ hasText: "E2E: Leistung strittig" })).toHaveCount(0);
});

// COND2-2 (migration 0087, ADR-101): seed event 704 on visit 502 (10:00, Testteam Nord) was taken in review by
// austritt.test, whose access has since ended. Her claim has lapsed (0085): the team sees it as ended and takes it over.
test("the team takes over a quality review whose reviewer left (COND2-2, 390 px)", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await signIn(page, NURSE, /\/field$/);
  await page.goto(`/field?datum=${SEED_DAY}`);
  const event = page.getByRole("article", { name: /10:00 – 10:30/ }).getByTestId("quality-event")
    .filter({ hasText: "Testereignis Übernahme" });

  await expect(event.getByTestId("event-status")).toHaveText("Übernahme beendet – Zugang beendet");
  await expect(event).not.toContainText("austritt");
  await event.getByRole("button", { name: "Übernehmen" }).click();

  await expect(event.getByTestId("event-status")).toHaveText("in Prüfung");
  await expect(event.getByRole("button", { name: "Übernehmen" })).toHaveCount(0);
  await expect(event.getByRole("button", { name: "Abschliessen" })).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1)).toBe(true);

  await page.reload();
  await expect(page.getByRole("article", { name: /10:00 – 10:30/ }).getByTestId("quality-event")
    .filter({ hasText: "Testereignis Übernahme" }).getByTestId("event-status")).toHaveText("in Prüfung");
});
