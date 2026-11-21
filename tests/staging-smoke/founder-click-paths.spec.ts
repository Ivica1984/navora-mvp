import { expect, test, type Page } from "@playwright/test";
import { minutesBack, zurichDay } from "../e2e/support/durchgang-time";
import { TAKE_HEADING } from "@/features/field/heading";
import { INVOICE_LABEL, SEND_BUTTON } from "@/features/invoices/rules";
import { addDays, dayLabel, weekStart } from "@/features/home-plan/rules";
import { assertBelowRowCap, busyFromOrderLines, freeDayOffset, orderDaysFromLines, smokeAccounts, smokeDayOffsets, smokePath3Slot, type Role } from "./target";

// ADR-205 — staging smoke (founder decision 2026-11-18 ca. 23:00, «Variante b»). The founder's two click paths of
// `docs/product/FOUNDER_STAGING_UEBERSICHT.md`, in the real staging app, with the three demo accounts (FE-086b):
//   1. client orders a day shift → another team never sees it → the demo nurse of Testteam Basel sees the offer and
//      takes it naming herself → the client reads «Gedeckt» (the CI original is tests/e2e/bk-c2-take-status.spec.ts);
//   2. client orders a 22:00–07:00 night → the nurse takes it → her /field day shows one «Übernommene Schicht» card
//      22:00 – 07:00 (CI original tests/e2e/bk-e1b-take-card.spec.ts at 390 px).
// Only what a person sees is asserted, never a person's name or a count of orders (staging data grow with every run;
// the second Basel nurse of the CI seed does not exist on staging). Each run writes two synthetic orders and two takes
// on staging, on the first days without any client order (freeDayOffset, read in the app); they are synthetic by construction (demo accounts, Testheim Rhein).
// Path 3 (BK-f) below. Not here: the colleague and absence paths, BK-e1c after midnight (needs a started visit at night).

const accounts = smokeAccounts(process.env);
const offsets = smokeDayOffsets(Number(process.env.GITHUB_RUN_NUMBER ?? 0));
const deDate = (iso: string) => iso.split("-").reverse().join(".");

async function signIn(page: Page, role: Role) {
  await page.context().clearCookies();
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(accounts[role].email);
  await page.getByLabel("Passwort").fill(accounts[role].password);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

/** #1642: the days the client already has an order on, read in the real app (/order) before choosing a day. */
async function clientOrderDays(page: Page): Promise<Set<string>> {
  await page.goto("/order");
  return orderDaysFromLines(await clientOrderLines(page));
}

/** The client's /order lines, refused at the API row cap (STAB1-F4): a capped list would hide the latest orders. */
async function clientOrderLines(page: Page): Promise<string[]> {
  // The heading renders with an empty list too (an empty <ul> is not «visible» to Playwright).
  await expect(page.getByRole("heading", { level: 2, name: /^Ihre Aufträge \(\d+\)$/ })).toBeVisible();
  const lines = await page.getByTestId("client-orders").locator("li").allTextContents();
  assertBelowRowCap(lines.length);
  return lines;
}

async function order(page: Page, day: string, start: string, end: string) {
  await page.goto("/order");
  const form = page.getByRole("form", { name: "Auftrag" });
  await form.getByLabel(/^Datum/).fill(deDate(day));
  await form.getByLabel("Beginn", { exact: true }).fill(start);
  await form.getByLabel("Ende", { exact: true }).fill(end);
  await form.getByLabel("Einsatzort (Postleitzahl)").selectOption("4051");
  await form.getByRole("radio", { name: "HF", exact: true }).check();
  await form.getByRole("checkbox", { name: "Grundpflege", exact: true }).check();
  await form.getByRole("button", { name: "Weiter zur Zusammenfassung" }).click();
  await page.getByTestId("order-summary").getByRole("button", { name: "Bestätigen & Absenden" }).click();
  await expect(page.getByTestId("order-done")).toContainText("Auftrag bestätigt");
}

async function takeAsHerself(page: Page, when: string) {
  await page.goto("/team");
  const card = page.getByTestId("shift-offer-card").filter({ hasText: when }).last();
  await expect(card.getByTestId("shift-offer-tag")).toHaveText("Neues Angebot");
  await expect(card.getByRole("radio", { name: "Ich (Pflegekraft)" })).toBeChecked();
  await card.getByRole("button", { name: "Übernehmen mit Pflegekraft" }).click();
  const taken = page.getByTestId("shift-offer-card").filter({ hasText: when }).last();
  await expect(taken.getByTestId("shift-offer-tag")).toHaveText("Übernommen");
  await expect(taken.getByTestId("shift-offer-line")).toHaveText(/^Ihr habt diese Schicht übernommen\. Es geht: \S/);
}

test.describe.configure({ mode: "serial" });

test("staging is up and each demo account can sign in", async ({ page }) => {
  // Wakes a sleeping Render instance (navigationTimeout 90 s in the config).
  await page.goto("/login");
  await expect(page.getByRole("button", { name: "Anmelden" })).toBeVisible();
  for (const role of ["kunde", "pflegeBs", "pflegeNord"] as const) {
    await signIn(page, role);
    expect(new URL(page.url()).pathname).not.toMatch(/^\/login/);
  }
});

test("path 1: client orders → another team never sees it → Basel nurse takes it → client reads «Gedeckt»", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 900 });
  await signIn(page, "kunde");
  const now = Date.now();
  const day = zurichDay(now, freeDayOffset(now, 40, await clientOrderDays(page)));
  const when = `${deDate(day)} 07:00`;
  await order(page, day, "07:00", "15:30");
  const open = page.getByTestId("client-orders").locator("li", { hasText: when }).last();
  await expect(open.getByTestId("order-cover-state")).toHaveText(/^Noch nicht gedeckt/);

  await signIn(page, "pflegeNord");
  await page.goto("/team");
  await expect(page.getByTestId("shift-offers")).toBeVisible();
  await expect(page.getByTestId("shift-offer-card").filter({ hasText: when })).toHaveCount(0);

  await signIn(page, "pflegeBs");
  await takeAsHerself(page, when);

  await signIn(page, "kunde");
  await page.goto("/order");
  const covered = page.getByTestId("client-orders").locator("li", { hasText: when }).last();
  await expect(covered.getByTestId("order-cover-state")).toHaveText(/^Gedeckt · Person benannt, geprüft für HF$/);
  await expect(covered.getByTestId("order-cover-detail")).toHaveText(/^Team .+ · übernommen um \d\d:\d\d$/);
});

test("path 2: a 22:00–07:00 night taken by the nurse is one «Übernommene Schicht» card on her /field day (390 px)", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await signIn(page, "kunde");
  const now = Date.now();
  const day = zurichDay(now, freeDayOffset(now, 75, await clientOrderDays(page), 2));
  const when = `${deDate(day)} 22:00`;
  await order(page, day, "22:00", "07:00");

  await signIn(page, "pflegeBs");
  await takeAsHerself(page, when);

  await page.goto(`/field?datum=${day}`);
  const cards = page.getByRole("article", { name: /22:00 – 07:00/ });
  await expect(cards).toHaveCount(1);
  await expect(cards.first().getByRole("heading", { level: 2 })).toHaveText(TAKE_HEADING);
  expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(0);
});

// Path 3 (BK-f, PO amendment 2026-11-20 09:30 (1)): the nurse works a short shift today and signs it → the database
// builds the invoice draft → the team sends it with one tap → the client reads it under «Rechnungen». On staging this
// needs the team's price (set here through /team if none, synthetic 68.00 «Beispielwert, kein Tarif») and the time
// tolerance row, which `lca` names at the BK-f gate and a reviewed migration ships; until that row is applied this path
// is red with «Kein Rechnungsentwurf: Der Zeitabgleich ist noch nicht eingerichtet.» — a known limit, never a skip.
test("path 3: nurse signs a worked shift → invoice draft → team sends it → client reads it under «Rechnungen» (390 px)", async ({ page }) => {
  test.setTimeout(240_000);
  await page.setViewportSize({ width: 390, height: 844 });
  // STAB1-F3: the slot must not overlap any order of today (an earlier run's take blocks the nurse, CGR-224), so the
  // client's own order list is read in the app first and the slot starts after every busy interval of today.
  await signIn(page, "kunde");
  await page.goto("/order");
  const lines = await clientOrderLines(page);
  const now = Date.now();
  const { day, from, to } = smokePath3Slot(now, busyFromOrderLines(lines, zurichDay(now)));
  const when = `${deDate(day)} ${from}`;

  await order(page, day, from, to);

  await signIn(page, "pflegeBs");
  await page.goto("/team");
  const price = page.getByTestId("team-price").first(); // the demo nurse has one team; staging names may differ
  if ((await price.getByTestId("team-price-current").textContent())?.includes("noch keiner")) {
    await price.getByLabel("Neuer Preis pro Stunde (CHF)").fill("68.00");
    await price.getByTestId("team-price-save").click();
    await expect(price.getByTestId("team-price-current")).toHaveText("CHF 68.00");
  }
  await takeAsHerself(page, when);

  await page.goto(`/field?datum=${day}`);
  const card = page.getByRole("article", { name: new RegExp(`${from} – ${to}`) });
  await expect(card).toHaveCount(1);
  for (const [button, status] of [["Losfahren", "Unterwegs"], ["Einsatz starten", "Gestartet"], ["Einsatz abschliessen", "Abgeschlossen"]] as const) {
    await card.getByRole("button", { name: button }).click();
    await expect(card).toContainText(status);
  }
  const worked = Date.now();
  await card.getByText("Zeiten ansehen und korrigieren").click();
  const timeline = card.getByRole("list", { name: "Zeitverlauf" });
  for (const [event, back] of [["Losgefahren", 14], ["Gestartet", 12], ["Abgeschlossen", 2]] as const) {
    const row = timeline.getByRole("listitem").filter({ hasText: event });
    await row.getByRole("button", { name: "Korrigieren" }).click();
    await row.getByLabel("Richtige Uhrzeit").fill(minutesBack(worked, back));
    await row.getByLabel("Begründung").fill("Testlauf: simulierte Einsatzdauer");
    await row.getByRole("button", { name: "Korrektur speichern" }).click();
    await expect(row.getByLabel("Richtige Uhrzeit")).toHaveCount(0);
  }
  await page.reload();
  const report = page.getByRole("article", { name: new RegExp(`${from} – ${to}`) }).getByTestId("visit-report");
  await report.getByRole("form", { name: "Bericht prüfen und unterschreiben" }).getByRole("button", { name: "Bericht unterschreiben" }).click();
  await expect(report.getByTestId("report-status")).toHaveText("Bericht abgeschlossen");
  await expect(report.getByTestId("report-invoice-line")).toHaveText("Rechnungsentwurf für das Team erstellt.");

  await page.goto("/team");
  const drafts = page.getByTestId("invoice-drafts");
  await expect(drafts.getByTestId("invoice-label")).toHaveText(INVOICE_LABEL);
  const draft = drafts.locator('[data-testid="invoice-draft"][data-state="draft"]').filter({ hasText: deDate(day) }).first();
  await expect(draft.getByTestId("invoice-hours")).toHaveText("0.17 Std.");
  await draft.getByRole("button", { name: SEND_BUTTON }).click();
  await expect(drafts.locator('[data-testid="invoice-draft"][data-state="sent"]').filter({ hasText: deDate(day) }).first()).toBeVisible();

  await signIn(page, "kunde");
  await page.goto("/order");
  const invoices = page.getByTestId("client-invoices");
  await expect(invoices.getByTestId("invoice-label")).toHaveText(INVOICE_LABEL);
  await expect(invoices.getByTestId("client-invoice").filter({ hasText: deDate(day) }).first()).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(0);
});

// Path 4 (HD-1 / HD-2, founder 2026-11-20): the home plans its own staff on staging. The demo client is the lead of
// «Testheim Rhein (synthetisch)» (migration 0159 backfill). If the home is still empty the run loads the synthetic
// example once; then it plans one shift in a week of its own (offset by the run number), records an absence, reads the
// gap in the week and in the month, and removes both again, so staging keeps no row of the run.
test("path 4: the home assigns a person, records an absence, sees the gap in week and month, then removes both (390 px)", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 900 });
  let day = addDays(weekStart(zurichDay(Date.now(), 120 + 7 * (offsets.day - 40))), 2);
  const cellOf = () => page.locator(`[data-testid="heim-day"][data-date="${day}"] [data-testid="heim-cell"][data-station="Rhein 2"][data-shift="S"]`);

  await signIn(page, "kunde");
  await page.goto("/heim");
  await expect(page.getByRole("heading", { name: "Dienstplanung" })).toBeVisible();
  if (await page.getByTestId("heim-empty").isVisible()) {
    await page.getByTestId("heim-load-example").click();
    await expect(page.getByTestId("heim-message")).toHaveText("Beispieldaten geladen (synthetisch).");
  }

  // #1642: a run that failed before its clean-up (staging-smoke 44857264600: the Render deploy of d5107f3 went live
  // at 02:54:02 UTC, inside path 4) leaves Gina Simul assigned on its day; a later run whose week lands there moves on
  // by one week (at most 8) instead of failing on a person who is no longer free.
  for (let tries = 0; ; tries++) {
    await page.goto(`/heim?ansicht=woche&datum=${day}`);
    await expect(cellOf()).toBeVisible();
    if ((await cellOf().getByTestId("heim-assigned").filter({ hasText: "Gina Simul" }).count()) === 0) break;
    expect(tries, "staging-smoke path 4: Gina Simul is already assigned in 8 weeks in a row").toBeLessThan(8);
    day = addDays(day, 7);
  }
  await expect(cellOf()).toHaveAttribute("data-status", "gap");
  await cellOf().getByTestId("heim-assign-select").selectOption({ label: "Gina Simul (HF)" });
  await cellOf().getByTestId("heim-assign").click();
  await expect(page.getByTestId("heim-message")).toHaveText("Eingeteilt.");
  await expect(cellOf().getByTestId("heim-cell-status")).toHaveText("1 von 2 · Lücke: 1 fehlt");

  await page.goto(`/heim?ansicht=personal&datum=${day}`);
  await page.getByTestId("heim-staff-link").filter({ hasText: "Gina Simul" }).click();
  const absence = page.getByTestId("heim-absence-form");
  await absence.getByLabel("Abwesend von").fill(day);
  await absence.getByLabel("bis").fill(day);
  await absence.getByRole("button", { name: "Abwesenheit erfassen" }).click();
  await expect(page.getByTestId("heim-message")).toHaveText("Abwesenheit erfasst. Betroffene Dienste zeigen jetzt die Lücke.");

  await page.goto(`/heim?ansicht=woche&datum=${day}`);
  await expect(cellOf().getByTestId("heim-cell-status")).toHaveText("0 von 2 · Lücke: 2 fehlt, 1 HF fehlt");
  await page.goto(`/heim?ansicht=monat&datum=${day}`);
  const row = page.getByTestId("heim-month-row").filter({ hasText: "Gina Simul" });
  await expect(row.locator("td").nth(Number(day.slice(8)) - 1)).toHaveText("A (S)");
  expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(0);

  // Clean up: absence and assignment removed; the cell is a gap of the example requirement again.
  await page.goto(`/heim?ansicht=personal&datum=${day}`);
  await page.getByTestId("heim-staff-link").filter({ hasText: "Gina Simul" }).click();
  // #1642: the absence of this run's day, not the first one listed (a failed earlier run may have left another).
  await page.getByTestId("heim-absences").locator("li").filter({ hasText: `Abwesend ${dayLabel(day)}` }).first()
    .getByRole("button", { name: "entfernen" }).click();
  await expect(page.getByTestId("heim-message")).toHaveText("Abwesenheit entfernt.");
  await page.goto(`/heim?ansicht=woche&datum=${day}`);
  await cellOf().getByTestId("heim-assigned").filter({ hasText: "Gina Simul" }).getByRole("button", { name: /entfernen/ }).click();
  await expect(page.getByTestId("heim-message")).toHaveText("Aus dem Dienst entfernt.");
  await expect(cellOf().getByTestId("heim-cell-status")).toHaveText("0 von 2 · Lücke: 2 fehlt, 1 HF fehlt");
});
