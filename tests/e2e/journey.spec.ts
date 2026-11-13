import { expect, test, type Page } from "@playwright/test";
import { TEAM_OFFERS_HEADING } from "@/features/field/todo";
import { ORG_A_TEAM_REGION, mapSeedRegionOrgA } from "./support/regions";

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

/** BD / UXR-155 (ADR-179): the count in the nurse's "Zu erledigen" team-offer link on /field, 0 when the link is absent. */
async function teamOfferCue(page: Page): Promise<number> {
  const link = page.getByTestId("todo-links").getByTestId("todo-team-offers");
  if ((await link.count()) === 0) return 0;
  const text = (await link.textContent()) ?? "";
  const m = text.match(new RegExp(`^${TEAM_OFFERS_HEADING} \\((\\d+)\\)$`));
  expect(m, `team-offer link text "${text}"`).not.toBeNull();
  return Number(m![1]);
}

async function signOut(page: Page) {
  await page.goto("/operations");
  await page.getByRole("button", { name: "Abmelden" }).click();
  await page.waitForURL(/\/login$/);
}

test("referral → case → team takes it over → team plans a visit → it is in the nurse's day (J1–J3)", async ({ page }) => {
  // Operations records and converts a referral in the region of Testteam Nord (B1.1-1: chosen from the list, after
  // the seed's legacy «Bern West» is mapped to Basel-Stadt on /operations).
  await signIn(page, OPS, /\/operations$/);
  await mapSeedRegionOrgA(page);
  await page.goto("/intake");
  const form = page.getByRole("form", { name: "Neue Anfrage" });
  await form.getByLabel("Zuweisende Stelle").fill("Testheim Journey");
  // IPA1-7: no preset urgency; the level is chosen with its source.
  await form.getByLabel(/^Dringlichkeit/).selectOption("mittel");
  await form.getByLabel("Quelle der Dringlichkeit").selectOption({ label: "vom Zuweiser angegeben" });
  await form.getByLabel("Region").selectOption(ORG_A_TEAM_REGION);
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
  await card.getByLabel("Erwartete Stunden pro Woche").fill("6");
  await card.getByRole("checkbox").check();
  await card.getByRole("button", { name: "Fall eröffnen" }).click();
  await expect(card).toHaveCount(0);
  // (Operations' attention list shows the top 8 items only; intake.spec.ts checks the case appears there.)
  await signOut(page);

  // The nurse's team sees the offer — without the client's name — and takes it.
  // BD / UXR-155 (ADR-179, `uxa` G-3 for J2): what she sees first, on her phone (390 × 844), is one neutral
  // "Zu erledigen" link to the team's offers, with the count and no client name; one tap lands on the offer card.
  const desktop = page.viewportSize();
  await page.setViewportSize({ width: 390, height: 844 });
  await signIn(page, NURSE, /\/field$/);
  const offersBefore = await teamOfferCue(page);
  expect(offersBefore, "the new offer is counted on /field").toBeGreaterThanOrEqual(1);
  const cue = page.getByTestId("todo-team-offers");
  await expect(cue).toBeVisible();
  await expect(cue).toHaveAttribute("data-tone", "info");
  await expect(page.getByTestId("todo-links")).not.toContainText("Journey");
  await cue.click();
  await expect(page).toHaveURL(/\/team#anfragen$/);
  const offer = page.getByRole("article", { name: "Anfrage Teamsuche: Journey Übergangspflege" });
  await expect(offer).toBeVisible();
  if (desktop) await page.setViewportSize(desktop);
  await expect(offer).toContainText("für Testteam Nord");
  await expect(offer.getByTestId("urgency-source")).toHaveText("Dringlichkeit: mittel (vom Zuweiser angegeben)");
  await expect(offer).toContainText("nicht automatisch geprüft");
  // J2 / F0 criterion 4: start, expected hours and required qualification before acceptance.
  const facts = offer.getByRole("definition");
  await expect(offer.getByLabel("Eckdaten")).toContainText("6 h/Woche");
  await expect(offer.getByLabel("Eckdaten")).toContainText("Pflegefachperson nötig");
  await expect(offer.getByTestId("response-due")).toBeVisible();
  await expect(facts.first()).not.toHaveText("nicht erfasst");
  await expect(page.getByText("Journeytest")).toHaveCount(0);

  await offer.getByRole("button", { name: "Fall übernehmen" }).click();
  await expect(offer).toHaveCount(0);

  // J3 (PO brief): the first visit is the needs assessment (category A, registered nurse).
  const teamCase = page.getByRole("article", { name: "Fall Jonas Journeytest" });
  await expect(teamCase).toContainText("Testteam Nord");
  await expect(teamCase).toContainText("Noch keine Einsätze geplant");

  // J6 (PO brief): the team names the primary nurse; the measure is per client. PLAN3-17 (2): the caller reads "(du)".
  const continuity = teamCase.getByRole("region", { name: "Kontinuität" });
  await expect(continuity.getByTestId("primary-missing")).toBeVisible();
  await continuity.getByRole("button", { name: "Bezugspflege bestimmen" }).click();
  await continuity.getByLabel("Bezugspflegende").selectOption({ label: "Ich (du) – Pflegefachperson" });
  await continuity.getByRole("button", { name: "Speichern" }).click();
  await expect(continuity.getByTestId("primary-nurse")).toHaveText("Ich (du) – Pflegefachperson");
  await teamCase.getByRole("button", { name: "Abklärungsbesuch planen" }).click();
  const planForm = teamCase.getByRole("form", { name: "Einsatz planen" });
  await expect(planForm.getByLabel("B", { exact: true })).toBeDisabled();
  const tomorrow = await planForm.getByLabel("Datum").inputValue();
  await planForm.getByLabel("Von").fill("14:00");
  await planForm.getByLabel("Bis").fill("14:45");
  await planForm.getByLabel("A", { exact: true }).fill("45");
  await planForm.getByRole("button", { name: "Einsatz speichern" }).click();
  await expect(teamCase.getByRole("list", { name: "Geplante Einsätze" })).toContainText("14:00–14:45");

  // Care plan with a KLV category, planned minutes, frequency, review date and a care goal.
  const plan = teamCase.getByRole("region", { name: "Pflegeplan" });
  await plan.getByRole("button", { name: "Leistung hinzufügen" }).click();
  const item = plan.getByRole("form", { name: "Leistung hinzufügen" });
  await item.getByLabel("Leistung", { exact: true }).fill("Grundpflege");
  await item.getByLabel("Kategorie").selectOption("C");
  await item.getByLabel("Minuten pro Einsatz").fill("30");
  await item.getByLabel("Häufigkeit").fill("1x täglich");
  await item.getByLabel("Überprüfung am").fill(new Date(Date.now() + 60 * 86_400_000).toISOString().slice(0, 10));
  await item.getByLabel(/Pflegeziel/).fill("Selbständig waschen am Lavabo");
  await item.getByRole("button", { name: "Leistung speichern" }).click();
  await expect(plan).toContainText("Ziel: Selbständig waschen am Lavabo");

  // The nurse's day shows the assessment with minutes per category and the care goal.
  await page.goto(`/field?datum=${tomorrow}`);
  // BD / UXR-155: the offer was taken, so it no longer counts on her /field (link gone when it was the only one).
  expect(await teamOfferCue(page), "the taken offer is no longer counted").toBe(offersBefore - 1);
  if (offersBefore === 1) await expect(page.getByTestId("todo-team-offers")).toHaveCount(0);
  const visit = page.getByRole("article", { name: /14:00 – 14:45, Jonas Journeytest/ });
  await expect(visit).toContainText("Geplant");
  await expect(visit).toContainText("Bedarfsabklärung");
  await expect(visit).toContainText("A 45 min");
  await expect(visit).toContainText("Selbständig waschen am Lavabo");
});
