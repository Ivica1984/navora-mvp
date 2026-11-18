import { expect, test, type Page } from "@playwright/test";
import { zurichDay } from "./support/durchgang-time";
import { TAKE_HEADING } from "@/features/field/heading";

// BK-e1c at 390 × 844 (brief docs/agents/briefs/BK.md §PO amendment 2026-11-18 17:39, C1; R3b, UXR-248, CGR-257;
// ADR-203 (22)). Synthetic local-only accounts from supabase/seed.sql (Testorganisation S, simulation):
//   kundebs.test  client of «Testheim Rhein (synthetisch)»: orders one night shift tonight 23:45–07:00;
//   pflegebs.test registered nurse of Testteam Basel: takes it naming herself and starts it today (VIS1 allows a start on
//                 the visit's own day).
// The e2e job keeps the real clock (ADR-081, ADR-113), so «03:00 on day 2» cannot be set. `field_visits` does not read
// the clock (migration 0149): day 2 is reached as `/field?datum=<tomorrow>`, the only input of the predicate. There the
// running night visit is the first card, on the card itself, with its line, «Einsatz abschliessen» and «Ereignis melden»;
// completing it works and leads to the visit's own day. 23:45 is the latest start the day guard leaves room for
// (scripts/ci-e2e-day-guard.sh: no run starts within 20 min of midnight). No other spec uses pflegebs today.
const PASSWORD = "navora-local-only";

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

const deDate = (iso: string) => iso.split("-").reverse().join(".");

test("BK-e1c at 390 px: on day 2 the running night shift of day 1 is her first card, with its line, and «Einsatz abschliessen» completes it", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  const day1 = zurichDay(Date.now(), 0);
  const day2 = zurichDay(Date.now(), 1);
  const when = `${deDate(day1)} 23:45`;

  // 1. The client orders one HF night shift tonight.
  await signIn(page, "kundebs.test@navora.test");
  await page.goto("/order");
  const form = page.getByRole("form", { name: "Auftrag" });
  await form.getByLabel(/^Datum/).fill(deDate(day1));
  await form.getByLabel("Beginn", { exact: true }).fill("23:45");
  await form.getByLabel("Ende", { exact: true }).fill("07:00");
  await form.getByLabel("Einsatzort (Postleitzahl)").selectOption("4051");
  await form.getByRole("radio", { name: "HF", exact: true }).check();
  await form.getByRole("checkbox", { name: "Grundpflege", exact: true }).check();
  await form.getByRole("button", { name: "Weiter zur Zusammenfassung" }).click();
  await page.getByTestId("order-summary").getByRole("button", { name: "Bestätigen & Absenden" }).click();
  await expect(page.getByTestId("order-done")).toContainText("Auftrag bestätigt");
  await page.context().clearCookies();

  // 2. pflegebs takes it naming herself and starts the visit on day 1.
  await signIn(page, "pflegebs.test@navora.test");
  await page.goto("/team");
  const offer = page.getByTestId("shift-offer-card").filter({ hasText: when }).last();
  await expect(offer.getByRole("radio", { name: "Ich (Pflegekraft)" })).toBeChecked();
  await offer.getByRole("button", { name: "Übernehmen mit Pflegekraft" }).click();
  await expect(page.getByTestId("shift-offer-card").filter({ hasText: when }).last().getByTestId("shift-offer-tag")).toHaveText("Übernommen");

  await page.goto(`/field?datum=${day1}`);
  const tonight = page.getByRole("article", { name: /23:45 – 07:00/ });
  await expect(tonight).toHaveCount(1);
  await expect(tonight.getByTestId("carried-line")).toHaveCount(0);  // on its own day it is not «carried»
  await tonight.getByRole("button", { name: "Einsatz starten" }).click();
  await expect(tonight.getByTestId("visit-status")).toHaveText("Gestartet");
  await expect(tonight.getByTestId("command-error")).toHaveCount(0);

  // 3. Day 2: the running night visit is the first card, on the card itself (C1, UXR-248, CGR-257).
  await page.goto(`/field?datum=${day2}`);
  const first = page.getByTestId("next-visit");
  const card = first.getByRole("article", { name: /23:45 – 07:00/ });
  await expect(card).toHaveCount(1);
  await expect(card.getByRole("heading", { level: 2 })).toHaveText(TAKE_HEADING);
  await expect(card.getByTestId("carried-line")).toHaveText(/^Läuft seit gestern \d\d:\d\d$/);
  await expect(card.getByTestId("visit-status")).toHaveText("Gestartet");
  await expect(card.getByRole("button", { name: "Einsatz abschliessen" })).toBeVisible();
  await expect(card.getByRole("button", { name: "Ereignis melden" })).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(0);

  // 4. «Einsatz abschliessen» works there; she lands on the visit's own day, where it stays completed (PROPOSED, uxa).
  await card.getByRole("button", { name: "Einsatz abschliessen" }).click();
  await page.waitForURL((url) => url.searchParams.get("datum") === day1);
  const done = page.getByRole("article", { name: /23:45 – 07:00/ });
  await expect(done.getByTestId("visit-status")).toHaveText("Abgeschlossen");
  await expect(done.getByTestId("command-error")).toHaveCount(0);

  // 5. Completed, it is no longer carried to day 2 (C3).
  await page.goto(`/field?datum=${day2}`);
  await expect(page.getByRole("article", { name: /23:45 – 07:00/ })).toHaveCount(0);
});
