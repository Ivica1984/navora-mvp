import { expect, test, type Page } from "@playwright/test";

// J1 — referral intake → case + open matching request. Synthetic local-only accounts (supabase/seed.sql).
const OPS = "ops.test@navora.test"; //    org A, role operations
const NURSE = "pflege.test@navora.test"; // org A, role nurse
const PASSWORD = "navora-local-only";

async function signIn(page: Page, email: string, landing: RegExp) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(landing);
}

test.describe("referral intake (J1)", () => {
  test("operations records a referral, converts it after review, and the case surfaces in Operations", async ({ page }) => {
    await signIn(page, OPS, /\/operations$/);
    await page.goto("/intake");

    const form = page.getByRole("form", { name: "Neue Anfrage" });
    await form.getByLabel("Zuweisende Stelle").fill("Testspital Intake");
    await form.getByLabel("Dringlichkeit", { exact: true }).selectOption("hoch");
    await form.getByLabel("Quelle der Dringlichkeit").selectOption({ label: "vom Zuweiser angegeben" });
    await form.getByLabel("Region").fill("Bern West");
    await form.getByLabel("Titel").fill("Austritt E2E Intake");
    await form.getByLabel("Bedarf (Zusammenfassung)").fill("Synthetischer Bedarf für den E2E-Test.");
    await form.getByLabel("Leistungen (mit Komma getrennt)").fill("Grundpflege, Wundversorgung");
    await form.getByRole("button", { name: "Anfrage speichern" }).click();
    await expect(page.getByRole("status").filter({ hasText: "Anfrage gespeichert" })).toBeVisible();

    const card = page.getByRole("article", { name: "Anfrage Austritt E2E Intake" });
    await expect(card).toContainText("Grundpflege, Wundversorgung");
    await expect(card.getByTestId("urgency-source")).toHaveText("Dringlichkeit: hoch (vom Zuweiser angegeben)");
    await card.getByRole("button", { name: "Prüfen und in Fall überführen" }).click();
    await card.getByLabel("Vorname").fill("Erika");
    await card.getByLabel("Nachname").fill("Intaketest");
    // PO brief J1: residence only — insurer, insurance type and start are still missing.
    await card.getByLabel("Wohngemeinde").fill("Teststadt");
    await card.getByLabel("Kanton").selectOption("BE");
    // Without consent the browser blocks submission (required); the server refuses it too (pgTAP 012).
    await card.getByRole("checkbox").check();
    await card.getByRole("button", { name: "Fall eröffnen" }).click();
    await expect(card).toHaveCount(0);

    // Not ready: the case waits in intake and says why; no team search yet.
    const inIntake = page.getByRole("article", { name: "Fall in Aufnahme Erika Intaketest" });
    const why = inIntake.getByRole("status", { name: "Warum nicht bereit" });
    await expect(why).toContainText("Krankenversicherer fehlt");
    await expect(why).toContainText("Versicherungsart fehlt");
    await expect(why).toContainText("Gewünschter Beginn fehlt");
    await expect(inIntake.getByRole("list", { name: "Offene Aufgaben" })).toContainText("Hausärztin/Hausarzt erfassen");

    // Completing the facts makes it ready: the server opens the team search and the case leaves intake.
    await inIntake.getByRole("button", { name: "Angaben ergänzen" }).click();
    const facts = inIntake.getByRole("form", { name: "Angaben ergänzen" });
    await facts.getByLabel("Krankenversicherer").fill("Testkasse");
    await facts.getByLabel("Versicherungsart").selectOption("KVG");
    await facts.getByLabel("Gewünschter Beginn").fill(new Date(Date.now() + 2 * 86_400_000).toISOString().slice(0, 10));
    await facts.getByRole("button", { name: "Speichern und prüfen" }).click();
    await expect(inIntake).toHaveCount(0);

    // The new case has no team yet → Operations finds it in the case status list as "ohne Team".
    // (ADM1 changes removed the unvalidated "Weitere Hinweise" this test used to read; OPS1 raises
    // case_not_ready only after its working-time threshold.)
    await page.goto("/operations");
    const panel = page.getByTestId("ops-case-lifecycle");
    await panel.getByLabel("Fall suchen").fill("Intaketest");
    await expect(panel.getByRole("article", { name: "Fallstatus Erika Intaketest" })).toContainText("ohne Team");
  });

  test("at 390 px the urgency has no preset and the team's offer shows level and source (IPA1-7, IPA1-8)", async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await signIn(page, OPS, /\/operations$/);
    await page.goto("/intake");

    const form = page.getByRole("form", { name: "Neue Anfrage" });
    const urgency = form.getByLabel("Dringlichkeit", { exact: true });
    const source = form.getByLabel("Quelle der Dringlichkeit");
    // No preselected level and no preselected source.
    await expect(urgency).toHaveValue("");
    await expect(source).toHaveValue("");
    await form.getByLabel("Zuweisende Stelle").fill("Testspital IPA1");
    await form.getByLabel("Region").fill("Bern West");
    await form.getByLabel("Titel").fill("IPA1 Quelle E2E");
    await form.getByLabel("Bedarf (Zusammenfassung)").fill("Synthetischer Bedarf, IPA1-Test.");
    // Without a level the browser blocks submission (required); the database refuses it too (pgTAP 086).
    await form.getByRole("button", { name: "Anfrage speichern" }).click();
    await expect(page.getByRole("article", { name: "Anfrage IPA1 Quelle E2E" })).toHaveCount(0);

    await urgency.selectOption("niedrig");
    await source.selectOption({ label: "bei der Aufnahme eingeschätzt" });
    const start = new Date(Date.now() + 3 * 86_400_000).toISOString().slice(0, 10);
    await form.getByLabel("Gewünschter Beginn (laut Zuweiser)").fill(start);
    await form.getByRole("button", { name: "Anfrage speichern" }).click();
    await expect(page.getByRole("status").filter({ hasText: "Anfrage gespeichert" })).toBeVisible();

    const card = page.getByRole("article", { name: "Anfrage IPA1 Quelle E2E" });
    await expect(card.getByTestId("urgency-source")).toHaveText("Dringlichkeit: niedrig (bei der Aufnahme eingeschätzt)");
    await card.getByRole("button", { name: "Prüfen und in Fall überführen" }).click();
    await card.getByLabel("Vorname").fill("Iris");
    await card.getByLabel("Nachname").fill("Quelletest");
    await card.getByLabel("Wohngemeinde").fill("Teststadt");
    await card.getByLabel("Kanton").selectOption("BE");
    await card.getByLabel("Krankenversicherer").fill("Testkasse");
    await card.getByLabel("Versicherungsart").selectOption("KVG");
    await card.getByLabel("Gewünschter Beginn").fill(new Date(Date.now() + 86_400_000).toISOString().slice(0, 10));
    await card.getByRole("checkbox").check();
    await card.getByRole("button", { name: "Fall eröffnen" }).click();
    await expect(card).toHaveCount(0);

    await page.goto("/operations");
    await page.getByRole("button", { name: "Abmelden" }).click();
    await page.waitForURL(/\/login$/);

    // The team sees the level with its source and the referrer's date before it decides.
    await signIn(page, NURSE, /\/field$/);
    await page.goto("/team");
    const offer = page.getByRole("article", { name: "Anfrage Teamsuche: IPA1 Quelle E2E" });
    await expect(offer.getByTestId("urgency-source")).toHaveText("Dringlichkeit: niedrig (bei der Aufnahme eingeschätzt)");
    await expect(offer.getByTestId("referrer-start")).not.toHaveText("nicht angegeben");
    await expect(page.getByText("Quelletest")).toHaveCount(0);
    // The offer card fits 390 px (no horizontal overflow from the added lines).
    expect(await offer.evaluate((el) => el.scrollWidth - el.clientWidth)).toBeLessThanOrEqual(0);
  });

  test("a nurse has no intake access", async ({ page }) => {
    await signIn(page, NURSE, /\/field$/);
    await page.goto("/intake");
    await expect(page.getByText("Die Aufnahme ist Admin- und Operations-Rollen vorbehalten.")).toBeVisible();
    await expect(page.getByRole("form", { name: "Neue Anfrage" })).toHaveCount(0);
  });
});
