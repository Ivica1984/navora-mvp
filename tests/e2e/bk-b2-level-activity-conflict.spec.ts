import { expect, test, type Page } from "@playwright/test";
import { zurichDay } from "./support/durchgang-time";

// BK-b2 (brief docs/agents/briefs/BK.md, PO amendment 2026-11-13 21:39 (4); `cra` CGR-216 (a); draft ADR-196): a level
// whose matrix cell (QAM-0.2, PROPOSED) for a chosen activity is «-» is shown to the client at the activities field,
// naming the activity, and the form stays (no summary, nothing written). Synthetic local-only account `kundebs.test`
// (supabase/seed.sql). Words PROPOSED for `uxa`. Nothing is confirmed, so no order is added.
const CLIENT = "kundebs.test@navora.test";
const PASSWORD = "navora-local-only";

async function signIn(page: Page) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(CLIENT);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(/\/order$/);
}

const deDate = (iso: string) => iso.split("-").reverse().join(".");

for (const width of [390, 1440]) {
  test(`at ${width} px AGS with «Venöse und kapillare Blutentnahme» is refused at the activities field, naming it`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 });
    await signIn(page);
    const form = page.getByRole("form", { name: "Auftrag" });
    await form.getByLabel(/^Datum/).fill(deDate(zurichDay(Date.now(), 13)));
    await form.getByLabel("Beginn", { exact: true }).fill("08:00");
    await form.getByLabel("Ende", { exact: true }).fill("12:00");
    await form.getByLabel("Einsatzort (Postleitzahl)").selectOption("4102");
    await form.getByRole("radio", { name: "AGS", exact: true }).check();
    await form.getByRole("checkbox", { name: "Venöse und kapillare Blutentnahme", exact: true }).check();
    await form.getByRole("button", { name: "Weiter zur Zusammenfassung" }).click();

    // CGR-218 (A): the seed client is a `home` account, read as NH-EXT; the words say it is a simulation safety limit.
    const expected =
      "Für AGS ist diese Auswahl hier nicht möglich: Venöse und kapillare Blutentnahme. " +
      "Das ist eine Sicherheitsgrenze der Simulation, keine Entscheidung eines Teams. Bitte die Tätigkeit entfernen.";
    await expect(page.getByTestId("order-problems")).toContainText(expected);
    await expect(page.getByTestId("order-field-tags-problem")).toHaveText(expected);
    await expect(page.getByTestId("order-summary")).toHaveCount(0);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  });
}

// CGR-218 (A) (PO 2026-11-14 13:39 (2)): FaGe with «Vitalzeichen, Gewicht» (B1, «D» in the plain table) on the seed home
// order is refused before the summary, naming the activity (pgTAP 139 refuses it at confirm as well).
test("FaGe with «Vitalzeichen, Gewicht» on a home order is refused at the activities field, naming it", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 900 });
  await signIn(page);
  const form = page.getByRole("form", { name: "Auftrag" });
  await form.getByLabel(/^Datum/).fill(deDate(zurichDay(Date.now(), 13)));
  await form.getByLabel("Beginn", { exact: true }).fill("08:00");
  await form.getByLabel("Ende", { exact: true }).fill("12:00");
  await form.getByLabel("Einsatzort (Postleitzahl)").selectOption("4102");
  await form.getByRole("radio", { name: "FaGe", exact: true }).check();
  await form.getByRole("checkbox", { name: "Vitalzeichen, Gewicht", exact: true }).check();
  await form.getByRole("button", { name: "Weiter zur Zusammenfassung" }).click();
  await expect(page.getByTestId("order-field-tags-problem")).toHaveText(
    "Für FaGe ist diese Auswahl hier nicht möglich: Vitalzeichen, Gewicht. " +
      "Das ist eine Sicherheitsgrenze der Simulation, keine Entscheidung eines Teams. Bitte die Tätigkeit entfernen.",
  );
  await expect(page.getByTestId("order-summary")).toHaveCount(0);
});
