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

test("referral → case → the team of the region takes it over (J1 + J2)", async ({ page }) => {
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
  await page.reload();
  await expect(page.getByRole("article", { name: "Anfrage Teamsuche: Journey Übergangspflege" })).toHaveCount(0);
});
