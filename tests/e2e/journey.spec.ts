import { expect, test, type Page } from "@playwright/test";

// Care journey front half: referral (J1) → team decision (J2). Synthetic local-only accounts.
const OPS = "ops.test@navora.test"; //    org A, operations
const NURSE = "pflege.test@navora.test"; // org A, nurse, Testteam Nord (Bern West, active)
const PASSWORD = "navora-local-only";

async function signIn(page: Page, email: string, landing: RegExp) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(landing);
}

async function signOut(page: Page) {
  await page.goto("/operations");
  await page.getByRole("button", { name: "Abmelden" }).click();
  await page.waitForURL(/\/login$/);
}

test("referral → case → team takes it over → team plans a visit → it is in the nurse's day (J1–J3)", async ({ page }) => {
  // Operations records and converts a referral in Bern West.
  await signIn(page, OPS, /\/operations$/);
  await page.goto("/intake");
  const form = page.getByRole("form", { name: "Neue Anfrage" });
  await form.getByLabel("Zuweisende Stelle").fill("Testheim Journey");
  await form.getByLabel("Region").fill("Bern West");
  await form.getByLabel("Titel").fill("Journey Übergangspflege");
  await form.getByLabel("Bedarf (Zusammenfassung)").fill("Synthetischer Bedarf, Journey-Test.");
  await form.getByLabel("Leistungen (mit Komma getrennt)").fill("Grundpflege");
  await form.getByRole("button", { name: "Anfrage speichern" }).click();
  const card = page.getByRole("article", { name: "Anfrage Journey Übergangspflege" });
  await card.getByRole("button", { name: "Prüfen und in Fall überführen" }).click();
  await card.getByLabel("Vorname").fill("Jonas");
  await card.getByLabel("Nachname").fill("Journeytest");
  // J1 (PO brief): complete funding facts → ready → the server opens the team search.
  await card.getByLabel("Wohngemeinde").fill("Teststadt");
  await card.getByLabel("Kanton").selectOption("BE");
  await card.getByLabel("Krankenversicherer").fill("Testkasse");
  await card.getByLabel("Versicherungsart").selectOption("KVG");
  await card.getByLabel("Ärztliche Verordnung").selectOption("present");
  await card.getByLabel("Verordnung gültig bis").fill(new Date(Date.now() + 90 * 86_400_000).toISOString().slice(0, 10));
  await card.getByLabel("Gewünschter Beginn").fill(new Date(Date.now() + 86_400_000).toISOString().slice(0, 10));
  await card.getByRole("checkbox").check();
  await card.getByRole("button", { name: "Fall eröffnen" }).click();
  await expect(card).toHaveCount(0);
  // (Operations' attention list shows the top 8 items only; intake.spec.ts checks the case appears there.)
  await signOut(page);

  // The nurse's team sees the offer — without the client's name — and takes it.
  await signIn(page, NURSE, /\/field$/);
  await page.getByRole("link", { name: "Teamanfragen" }).click();
  await expect(page).toHaveURL(/\/team$/);
  const offer = page.getByRole("article", { name: "Anfrage Teamsuche: Journey Übergangspflege" });
  await expect(offer).toContainText("für Testteam Nord");
  await expect(offer).toContainText("nicht automatisch geprüft");
  await expect(page.getByText("Journeytest")).toHaveCount(0);

  await offer.getByRole("button", { name: "Fall übernehmen" }).click();
  await expect(offer).toHaveCount(0);

  // J3: after acceptance the team sees the client and plans a visit for tomorrow (Swiss date).
  const teamCase = page.getByRole("article", { name: "Fall Jonas Journeytest" });
  await expect(teamCase).toContainText("Testteam Nord");
  await expect(teamCase).toContainText("Noch keine Einsätze geplant");
  await teamCase.getByRole("button", { name: "Einsatz planen" }).click();
  const planForm = teamCase.getByRole("form", { name: "Einsatz planen" });
  const tomorrow = await planForm.getByLabel("Datum").inputValue();
  await planForm.getByLabel("Von").fill("14:00");
  await planForm.getByLabel("Bis").fill("14:45");
  await planForm.getByRole("button", { name: "Einsatz speichern" }).click();
  await expect(teamCase.getByRole("list", { name: "Geplante Einsätze" })).toContainText("14:00–14:45");

  await page.goto(`/field?datum=${tomorrow}`);
  const visit = page.getByRole("article", { name: /14:00 – 14:45, Jonas Journeytest/ });
  await expect(visit).toContainText("Geplant");
  await expect(visit).toContainText("Grundpflege");
});
