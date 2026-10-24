import { expect, test, type Page } from "@playwright/test";

// C1 — case lifecycle on /team. Synthetic local-only accounts from supabase/seed.sql.
const NURSE = "pflege.test@navora.test"; // Testteam Nord (case Testfall 08)
const PASSWORD = "navora-local-only";

async function signIn(page: Page, email: string, landing: RegExp) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(landing);
}

test("the team pauses a case with a reason and resumes it (C1)", async ({ page }) => {
  await signIn(page, NURSE, /\/field$/);
  await page.goto("/team");
  const card = page.getByRole("article", { name: /Fall Testfall 08/ });
  const lifecycle = card.getByTestId("case-lifecycle");

  await lifecycle.getByRole("button", { name: "Pausieren" }).click();
  const form = lifecycle.getByRole("form", { name: "Fall pausieren" });
  await expect(form.locator("select[name=code]")).toHaveAttribute("required", "");   // a reason is required
  await form.locator("select[name=code]").selectOption("hospital_stay");
  await form.getByRole("button", { name: "Pausieren" }).click();
  await expect(lifecycle.getByTestId("case-paused")).toContainText("Spitalaufenthalt");

  await lifecycle.getByRole("button", { name: "Fortsetzen" }).click();
  await expect(lifecycle.getByTestId("case-paused")).toHaveCount(0);
  await expect(lifecycle.getByRole("button", { name: "Pausieren" })).toBeVisible();
});

test("a visit suspended by a pause is marked on /field and has no depart button, at phone width (C1)", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await signIn(page, NURSE, /\/field$/);
  await page.goto("/team");
  const card = page.getByRole("article", { name: /Fall Testfall 08/ });

  // A visit three days ahead, then the pause.
  const day = new Date(Date.now() + 3 * 86_400_000).toISOString().slice(0, 10);
  await card.getByRole("button", { name: "Einsatz planen" }).click();
  const planForm = card.getByRole("form", { name: "Einsatz planen" });
  await planForm.getByLabel("Datum").fill(day);
  await planForm.getByLabel("Von").fill("16:00");
  await planForm.getByLabel("Bis").fill("16:30");
  await planForm.getByLabel("A", { exact: true }).fill("30");
  await planForm.getByRole("button", { name: "Einsatz speichern" }).click();
  await expect(card.getByRole("list", { name: "Geplante Einsätze" })).toContainText("16:00–16:30");

  const lifecycle = card.getByTestId("case-lifecycle");
  await lifecycle.getByRole("button", { name: "Pausieren" }).click();
  const form = lifecycle.getByRole("form", { name: "Fall pausieren" });
  await form.locator("select[name=code]").selectOption("hospital_stay");
  await form.getByRole("button", { name: "Pausieren" }).click();
  await expect(lifecycle.getByTestId("case-paused")).toBeVisible();

  await page.goto(`/field?datum=${day}`);
  const visit = page.getByRole("article", { name: /16:00 – 16:30, Testfall 08/ });
  await expect(visit.getByTestId("visit-status")).toHaveText(/^pausiert · Spital/);
  await expect(visit.getByRole("button", { name: "Losfahren" })).toHaveCount(0);

  // Resume restores the plan. C1 flake (failed on bdb0d1d): navigating away right after the click could abort
  // the resume command in flight; wait until the team view shows the case as running again.
  await page.goto("/team");
  const resumed = page.getByRole("article", { name: /Fall Testfall 08/ }).getByTestId("case-lifecycle");
  await resumed.getByRole("button", { name: "Fortsetzen" }).click();
  await expect(resumed.getByTestId("case-paused")).toHaveCount(0);
  await expect(resumed.getByRole("button", { name: "Pausieren" })).toBeVisible();
  await page.goto(`/field?datum=${day}`);
  await expect(page.getByRole("article", { name: /16:00 – 16:30, Testfall 08/ }).getByRole("button", { name: "Losfahren" })).toBeVisible();
});

test("a started visit ends as not completed with a reason, never only as complete, at phone width (CSR1 / CGR-20)", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await signIn(page, NURSE, /\/field$/);
  await page.goto("/team");
  const card = page.getByRole("article", { name: /Fall Testfall 08/ });

  // A visit five days ahead (no other test uses that slot).
  const day = new Date(Date.now() + 5 * 86_400_000).toISOString().slice(0, 10);
  await card.getByRole("button", { name: "Einsatz planen" }).click();
  const planForm = card.getByRole("form", { name: "Einsatz planen" });
  await planForm.getByLabel("Datum").fill(day);
  await planForm.getByLabel("Von").fill("17:00");
  await planForm.getByLabel("Bis").fill("17:30");
  await planForm.getByLabel("A", { exact: true }).fill("30");
  await planForm.getByRole("button", { name: "Einsatz speichern" }).click();
  await expect(card.getByRole("list", { name: "Geplante Einsätze" })).toContainText("17:00–17:30");

  await page.goto(`/field?datum=${day}`);
  const visit = page.getByRole("article", { name: /17:00 – 17:30, Testfall 08/ });
  await expect(visit.getByRole("button", { name: "Nicht abgeschlossen beenden" })).toHaveCount(0);   // only once started
  await visit.getByRole("button", { name: "Einsatz starten" }).click();
  await expect(visit.getByTestId("visit-status")).toHaveText("Gestartet");

  // Next to "Einsatz abschliessen" there is an honest end.
  await expect(visit.getByRole("button", { name: "Einsatz abschliessen" })).toBeVisible();
  await visit.getByRole("button", { name: "Nicht abgeschlossen beenden" }).click();
  const form = visit.getByRole("form", { name: "Einsatz nicht abgeschlossen beenden" });
  await expect(form).toContainText("D-31");
  await expect(form.locator("select[name=code]")).toHaveAttribute("required", "");   // a reason is required
  await form.locator("select[name=code]").selectOption("client_transferred");
  await form.getByRole("button", { name: "Nicht abgeschlossen speichern" }).click();

  await expect(visit.getByTestId("visit-status")).toHaveText("Nicht abgeschlossen");
  await expect(visit.getByTestId("interrupt-reason")).toContainText("Nicht abgeschlossen · Klient:in verlegt bzw. ins Spital gebracht");
  for (const name of ["Einsatz abschliessen", "Fortsetzen", "Einsatz starten", "Nicht abgeschlossen beenden"]) {
    await expect(visit.getByRole("button", { name })).toHaveCount(0);
  }
  // No report obligation: the card has no report section.
  await expect(visit.getByTestId("visit-report")).toHaveCount(0);

  // It stays so after a reload, and the page does not scroll sideways.
  await page.reload();
  await expect(page.getByRole("article", { name: /17:00 – 17:30, Testfall 08/ }).getByTestId("interrupt-reason")).toBeVisible();
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  expect(overflow).toBeLessThanOrEqual(0);
});

test("an interrupted visit keeps a signal until the team decides about the care still due, at phone width (CSR1 / CGR-25)", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await signIn(page, NURSE, /\/field$/);
  await page.goto("/team");
  const card = page.getByRole("article", { name: /Fall Testfall 08/ });

  // A visit six days ahead at 19:00 (no other test uses that slot).
  const day = new Date(Date.now() + 6 * 86_400_000).toISOString().slice(0, 10);
  await card.getByRole("button", { name: "Einsatz planen" }).click();
  const planForm = card.getByRole("form", { name: "Einsatz planen" });
  await planForm.getByLabel("Datum").fill(day);
  await planForm.getByLabel("Von").fill("19:00");
  await planForm.getByLabel("Bis").fill("19:30");
  await planForm.getByLabel("A", { exact: true }).fill("30");
  await planForm.getByRole("button", { name: "Einsatz speichern" }).click();
  await expect(card.getByRole("list", { name: "Geplante Einsätze" })).toContainText("19:00–19:30");

  await page.goto(`/field?datum=${day}`);
  const visit = page.getByRole("article", { name: /19:00 – 19:30, Testfall 08/ });
  await visit.getByRole("button", { name: "Einsatz starten" }).click();
  await expect(visit.getByTestId("visit-status")).toHaveText("Gestartet");
  await visit.getByRole("button", { name: "Nicht abgeschlossen beenden" }).click();
  const endForm = visit.getByRole("form", { name: "Einsatz nicht abgeschlossen beenden" });
  await endForm.locator("select[name=code]").selectOption("client_transferred");
  await endForm.getByRole("button", { name: "Nicht abgeschlossen speichern" }).click();
  await expect(visit.getByTestId("visit-status")).toHaveText("Nicht abgeschlossen");

  // The signal: on the card, in the /field queue and on /team, until a person decides.
  await expect(visit.getByTestId("interrupt-followup-open")).toContainText("Entscheid offen");
  await expect(page.getByTestId("followup-queue")).toContainText("Klient:in verlegt bzw. ins Spital gebracht");
  await page.goto("/team");
  const alert = page.getByTestId("visit-alert").filter({ hasText: "Einsatz nicht abgeschlossen: Entscheid offen" })
    .filter({ hasText: "19:00" });
  await expect(alert).toHaveCount(1);

  // One decision from the short list ends it; a decision needs a choice.
  await page.goto(`/field?datum=${day}`);
  const open = page.getByRole("article", { name: /19:00 – 19:30, Testfall 08/ }).getByTestId("interrupt-followup-open");
  await open.getByRole("button", { name: "Entscheid erfassen" }).click();
  const decision = open.getByRole("form", { name: "Entscheid zur noch fälligen Pflege" });
  await expect(decision).toContainText("D-31");
  await expect(decision.locator("select[name=decision]")).toHaveAttribute("required", "");
  await decision.locator("select[name=decision]").selectOption("follow_up_planned");
  await decision.getByLabel(/Notiz/).fill("Synthetisch: Folgeeinsatz morgen");
  await decision.getByRole("button", { name: "Entscheid speichern" }).click();

  const after = page.getByRole("article", { name: /19:00 – 19:30, Testfall 08/ });
  await expect(after.getByTestId("interrupt-followup")).toContainText("Entscheid: Folgeeinsatz geplant – Synthetisch: Folgeeinsatz morgen");
  await expect(after.getByTestId("interrupt-followup-open")).toHaveCount(0);
  await page.goto("/team");
  await expect(page.getByTestId("visit-alert").filter({ hasText: "Einsatz nicht abgeschlossen: Entscheid offen" }).filter({ hasText: "19:00" }))
    .toHaveCount(0);
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  expect(overflow).toBeLessThanOrEqual(0);
});

test("the performer sees who ended her visit and why, at phone width (CSR1 / CGR-26)", async ({ page, browser }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await signIn(page, NURSE, /\/field$/);
  await page.goto("/team");
  const card = page.getByRole("article", { name: /Fall Testfall 08/ });

  // A visit seven days ahead at 20:00 (no other test uses that slot); the registered nurse starts it.
  const day = new Date(Date.now() + 7 * 86_400_000).toISOString().slice(0, 10);
  await card.getByRole("button", { name: "Einsatz planen" }).click();
  const planForm = card.getByRole("form", { name: "Einsatz planen" });
  await planForm.getByLabel("Datum").fill(day);
  await planForm.getByLabel("Von").fill("20:00");
  await planForm.getByLabel("Bis").fill("20:30");
  await planForm.getByLabel("A", { exact: true }).fill("30");
  await planForm.getByRole("button", { name: "Einsatz speichern" }).click();
  await expect(card.getByRole("list", { name: "Geplante Einsätze" })).toContainText("20:00–20:30");
  await page.goto(`/field?datum=${day}`);
  const visit = page.getByRole("article", { name: /20:00 – 20:30, Testfall 08/ });
  await visit.getByRole("button", { name: "Einsatz starten" }).click();
  await expect(visit.getByTestId("visit-status")).toHaveText("Gestartet");

  // Another member of the team (the seeded care assistant) ends it as not completed, on her own phone.
  const other = await browser.newContext({ viewport: { width: 390, height: 844 } });
  const colleague = await other.newPage();
  await signIn(colleague, "assist.test@navora.test", /\/field$/);
  await colleague.goto(`/field?datum=${day}`);
  const theirs = colleague.getByRole("article", { name: /20:00 – 20:30, Testfall 08/ });
  await theirs.getByRole("button", { name: "Nicht abgeschlossen beenden" }).click();
  const endForm = theirs.getByRole("form", { name: "Einsatz nicht abgeschlossen beenden" });
  await endForm.locator("select[name=code]").selectOption("nurse_unavailable");
  await endForm.getByRole("button", { name: "Nicht abgeschlossen speichern" }).click();
  await expect(theirs.getByTestId("visit-status")).toHaveText("Nicht abgeschlossen");
  await expect(theirs.getByTestId("interrupt-ended-by")).toContainText("Beendet von Ich");
  await other.close();

  // The performer's card says who ended it and why.
  await page.reload();
  const mine = page.getByRole("article", { name: /20:00 – 20:30, Testfall 08/ });
  await expect(mine.getByTestId("visit-status")).toHaveText("Nicht abgeschlossen");
  await expect(mine.getByTestId("interrupt-reason")).toContainText("Pflegeperson abberufen oder unwohl");
  await expect(mine.getByTestId("interrupt-ended-by")).toContainText("Beendet von");
  await expect(mine.getByTestId("interrupt-ended-by")).toContainText("Pflegeassistenz");
  await expect(mine.getByTestId("interrupt-ended-by")).not.toContainText("Ich");
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  expect(overflow).toBeLessThanOrEqual(0);
});

test("Operations closes a case with a reason and reopens it in the app (C1, PO addendum)", async ({ page }) => {
  await signIn(page, "ops.test@navora.test", /\/operations$/);
  const panel = page.getByTestId("ops-case-lifecycle");
  await panel.getByLabel("Fall suchen").fill("Testfall 09");
  const card = panel.getByRole("article", { name: /Fallstatus Testfall 09/ });
  await expect(card.getByRole("button", { name: "Pausieren" })).toHaveCount(0);   // pausing stays with the team
  await card.getByRole("button", { name: "Fall abschliessen" }).click();
  const form = card.getByRole("form", { name: "Fall abschliessen" });
  await form.locator("select[name=code]").selectOption("goal_reached");
  await form.getByRole("button", { name: "Abschliessen" }).click();

  const closed = panel.getByRole("article", { name: /Abgeschlossen Testfall 09/ });
  await expect(closed).toBeVisible();
  await closed.getByRole("button", { name: "Wiedereröffnen" }).click();
  await closed.getByLabel("Begründung").fill("Rückkehr nach Hause");
  await closed.getByRole("button", { name: "Wiedereröffnen" }).click();
  await expect(panel.getByRole("article", { name: /Abgeschlossen Testfall 09/ })).toHaveCount(0);
  await panel.getByLabel("Fall suchen").fill("Testfall 09");
  await expect(panel.getByRole("article", { name: /Fallstatus Testfall 09/ })).toBeVisible();
});
