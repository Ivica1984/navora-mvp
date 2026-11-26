import { expect, test, type Locator, type Page } from "@playwright/test";
import { minutesBack, zurichDay } from "../e2e/support/durchgang-time";
import { TAKE_HEADING } from "@/features/field/heading";
import { INVOICE_LABEL, SEND_BUTTON } from "@/features/invoices/rules";
import { addDays, dayLabel, weekStart } from "@/features/home-plan/rules";
import { assertBelowRowCap, busyFromOrderLines, freeDayOffset, orderDaysFromLines, PATH5_MAX_WEEKS, path5GapDay, smokeAccounts, smokeDayOffsets, smokePath3Slot, type Role } from "./target";

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

/**
 * Clicks a button that submits a server action and waits for that action's own response (LEARNINGS 2026-11-25, #1729:
 * never wait only for the same message text the previous step already showed). Needed where one page submits the same
 * kind of action several times in a row: on `/heim` the message sits in the URL, so «Aus dem Dienst entfernt.» of the
 * previous removal satisfies the next wait at once, the next click lands on a page the previous redirect is replacing,
 * and the click is lost (path 7 on 89fe091e, job 139582842069: 20 of 28 removals reached `navora-staging`).
 */
async function submitAndWait(page: Page, button: Locator) {
  const answered = page.waitForResponse((r) => r.request().method() === "POST" && !!r.request().headers()["next-action"]);
  await button.click();
  await answered;
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

// HD-2 (brief HD.md §6 (2); founder FE-109 (C)): the home turns a gap into an external order with one tap, checks and
// sends it; the Basel nurse takes it in /team; the home's week and /order read «Gedeckt» for that cell (one source).
// A sent order stays on staging (no withdraw command yet, PR #1641), so the path picks the first Rhein 2 Früh gap of its
// week that has no order yet (weeks shared with path 4; path 4 uses Spät, never Früh) and on whose day the client has no
// order at all: path 1's /order orders 07:00–15:30 move forward into these weeks and the Basel nurse holds their takes
// (staging-smoke 45656894809, 45669102936: cell «K», no team eligible). No such day in the week → the next week.
test("path 5: the home orders a gap externally, the Basel nurse takes it, the home's week reads «Gedeckt» (390 px)", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 900 });
  let week = weekStart(zurichDay(Date.now(), 120 + 7 * (offsets.day - 40)));

  await signIn(page, "kunde");
  await page.goto("/heim");
  await expect(page.getByRole("heading", { name: "Dienstplanung" })).toBeVisible();
  if (await page.getByTestId("heim-empty").isVisible()) {
    await page.getByTestId("heim-load-example").click();
    await expect(page.getByTestId("heim-message")).toHaveText("Beispieldaten geladen (synthetisch).");
  }
  // The nurse must be free that day: any client order (a path-1 /order order is no gap order) excludes the day.
  const used = await clientOrderDays(page);
  let pick: string | null = null;
  for (let tries = 0; ; tries++) {
    await page.goto(`/heim?ansicht=woche&datum=${week}`);
    await expect(page.getByTestId("heim-day").first()).toBeVisible();
    const candidates = await page.locator('[data-testid="heim-day"]').filter({
      has: page.locator('[data-testid="heim-cell"][data-station="Rhein 2"][data-shift="F"] [data-testid="heim-prepare-order"]'),
    }).evaluateAll((els) => els.map((e) => e.getAttribute("data-date") ?? ""));
    pick = path5GapDay(candidates, used);
    if (pick) break;
    expect(tries, `staging-smoke path 5: no Rhein 2 Früh gap free of client orders in ${PATH5_MAX_WEEKS} weeks`).toBeLessThan(PATH5_MAX_WEEKS - 1);
    week = addDays(week, 7);
  }
  const day = pick;
  const cellOf = () => page.locator(`[data-testid="heim-day"][data-date="${day}"] [data-testid="heim-cell"][data-station="Rhein 2"][data-shift="F"]`);
  await cellOf().getByTestId("heim-prepare-order").click();
  await expect(page.getByTestId("heim-message")).toHaveText("Auftrag vorbereitet, noch nicht gesendet. Bitte prüfen und senden.");
  const review = page.getByTestId("heim-order-review");
  const postcode = review.getByTestId("heim-order-postcode");
  if ((await postcode.inputValue()) === "") await postcode.selectOption("4051");
  for (const box of await review.getByTestId("heim-order-tag").all()) if (await box.isChecked()) await box.uncheck();
  await review.locator('[data-testid="heim-order-tag"][value="C1"]').check();
  await review.getByTestId("heim-order-check").click();
  // UXR-269: wait for the checked screen (its summary names C1 only) before «Senden».
  await expect(review.getByTestId("heim-order-send-summary")).toHaveText(/Tätigkeiten: C1 · [^,]*$/);
  await expect(review.getByTestId("heim-order-sentence")).toContainText("Schichtauftrag · HF · ");
  await review.getByTestId("heim-order-send").click();
  await expect(page.getByTestId("heim-message")).toHaveText("Auftrag gesendet: Angebot an alle passenden Teams gleichzeitig.");
  await page.goto(`/heim?ansicht=woche&datum=${day}`);
  await expect(cellOf().getByTestId("heim-cell-order")).toHaveAttribute("data-code", "A");
  await expect(cellOf().getByTestId("heim-prepare-order")).toHaveCount(0);
  const orderId = await cellOf().getByTestId("heim-cell-order").getAttribute("data-order-id");

  await signIn(page, "pflegeBs");
  await takeAsHerself(page, `${deDate(day)} 07:00`);

  await signIn(page, "kunde");
  await page.goto(`/heim?ansicht=woche&datum=${day}`);
  await expect(cellOf().getByTestId("heim-cell-order")).toHaveAttribute("data-code", "G");
  await expect(cellOf().getByTestId("heim-cell-order-headline")).toHaveText("Externer Auftrag: Gedeckt · Person bestätigt, geprüft für HF");
  await expect(cellOf().getByTestId("heim-cell-status")).toContainText("+ 1 extern von");
  expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(0);
  await page.goto("/order");
  const covered = page.getByTestId("client-orders").locator(`li[data-order-id="${orderId}"]`);
  await expect(covered.getByTestId("order-cover-state")).toHaveText(/^Gedeckt · Person benannt, geprüft für HF$/);
});

test("path 6: the home orders a gap externally and withdraws it; the gap stays and /order reads «Zurückgezogen» (390 px)", async ({ page }) => {
  // HD-2 slice 5 (migration 0163). A late shift of the path-5 week; the order is never taken (no nurse step).
  await page.setViewportSize({ width: 390, height: 900 });
  const week = weekStart(zurichDay(Date.now(), 120 + 7 * (offsets.day - 40)));
  await signIn(page, "kunde");
  await page.goto(`/heim?ansicht=woche&datum=${week}`);
  await expect(page.getByRole("heading", { name: "Dienstplanung" })).toBeVisible();
  const free = page.locator('[data-testid="heim-day"]').filter({
    has: page.locator('[data-testid="heim-cell"][data-station="Rhein 2"][data-shift="S"] [data-testid="heim-prepare-order"]'),
  }).first();
  const day = (await free.getAttribute("data-date"))!;
  const cellOf = () => page.locator(`[data-testid="heim-day"][data-date="${day}"] [data-testid="heim-cell"][data-station="Rhein 2"][data-shift="S"]`);
  await cellOf().getByTestId("heim-prepare-order").click();
  const review = page.getByTestId("heim-order-review");
  const postcode = review.getByTestId("heim-order-postcode");
  if ((await postcode.inputValue()) === "") await postcode.selectOption("4051");
  for (const box of await review.getByTestId("heim-order-tag").all()) if (await box.isChecked()) await box.uncheck();
  await review.locator('[data-testid="heim-order-tag"][value="C1"]').check();
  const grade = review.getByTestId("heim-order-grade");
  if (await grade.count()) await grade.selectOption("nurse_hf_fh");
  await review.getByTestId("heim-order-check").click();
  // UXR-269 (#1656): a box ticked after «Prüfen» is not sent; the screen asks to check again and nothing goes out.
  await expect(review.getByTestId("heim-order-send-summary")).toHaveText(/Tätigkeiten: C1 · [^,]*$/);
  const extraCode = (await review.locator('[data-testid="heim-order-tag"]:not([value="C1"])').first().getAttribute("value"))!;
  const extra = review.locator(`[data-testid="heim-order-tag"][value="${extraCode}"]`);
  await extra.check();
  await review.getByTestId("heim-order-send").click();
  await expect(page.getByTestId("heim-message")).toHaveText(
    "Geändert nach dem Prüfen: Es wurde nichts gesendet. Bitte die Angaben unten erneut prüfen.");
  await expect(extra).toBeChecked();
  await extra.uncheck();
  await review.getByTestId("heim-order-check").click();
  await expect(review.getByTestId("heim-order-send-summary")).toHaveText(/Tätigkeiten: C1 · [^,]*$/);
  await review.getByTestId("heim-order-send").click();
  await expect(page.getByTestId("heim-message")).toHaveText("Auftrag gesendet: Angebot an alle passenden Teams gleichzeitig.");
  await page.goto(`/heim?ansicht=woche&datum=${day}`);
  const orderId = await cellOf().getByTestId("heim-cell-order").getAttribute("data-order-id");
  await cellOf().getByTestId("heim-order-withdraw").click();
  await expect(page.getByTestId("heim-message")).toHaveText("Auftrag zurückgezogen. Kein Team erhält das Angebot mehr; die Lücke bleibt.");
  await page.goto(`/heim?ansicht=woche&datum=${day}`);
  await expect(cellOf().getByTestId("heim-cell-order")).toHaveCount(0);
  await expect(cellOf()).toHaveAttribute("data-status", "gap");
  expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(0);
  await page.goto("/order");
  const withdrawn = page.getByTestId("client-orders").locator(`li[data-order-id="${orderId}"]`);
  await expect(withdrawn.getByTestId("order-cover-state")).toHaveText(/^Zurückgezogen · Beginn /);
});

// FE-128 (brief HD.md §5b, PO amendment 2026-11-25 10:39): staging holds the home's planning inputs empty (0171/0172
// have no backfill). Path 7 fills only what is «nicht eingetragen», through the forms on /heim, with the example values
// of the synthetic test home (`institution_load_example`, «Beispielwert des Heims»: rest 11 h, 6 days in a row, 42 h,
// classes F/S/N, Pensum of the eight example persons). A value the home has entered is never changed; a person who is
// not one of the eight example persons keeps «nicht eingetragen» (the draft then names her). Synthetic data only.
const EXAMPLE_CLASS: Record<string, string> = { F: "early", S: "late", N: "night" };
const EXAMPLE_PENSUM: Record<string, string> = {
  "Anna Muster": "100", "Ben Beispiel": "80", "Carla Test": "100", "David Probe": "60",
  "Eva Fiktiv": "100", "Felix Demo": "80", "Gina Simul": "90", "Hugo Platz": "100",
};
async function fillMissingPlanningInputs(page: Page) {
  await page.goto("/heim?ansicht=einstellungen");
  const limits = page.getByTestId("heim-limits-form");
  if (((await limits.getByTestId("heim-limits-now").textContent()) ?? "").includes("nicht eingetragen")) {
    if ((await limits.getByTestId("heim-limits-rest").inputValue()) === "") await limits.getByTestId("heim-limits-rest").fill("11");
    if ((await limits.getByTestId("heim-limits-days").inputValue()) === "") await limits.getByTestId("heim-limits-days").fill("6");
    if ((await limits.getByTestId("heim-limits-weekly").inputValue()) === "") {
      await limits.getByTestId("heim-limits-weekly-value").check();
      await limits.getByTestId("heim-limits-weekly").fill("42");
    }
    await limits.getByTestId("heim-limits-save").click();
    await expect(page.getByTestId("heim-message")).toHaveText("Planungsgrenzen des Heims gespeichert.");
    await expect(page.getByTestId("heim-limits-now")).not.toContainText("nicht eingetragen");
  }
  for (const [code, cls] of Object.entries(EXAMPLE_CLASS)) {
    const type = page.locator(`[data-testid="heim-shift-type"][data-code="${code}"]`);
    if ((await type.count()) !== 1 || (await type.getByTestId("heim-shift-class-now").textContent()) !== "Klasse: keine Klasse") continue;
    await type.getByTestId("heim-shift-class").selectOption(cls);
    // Several types in a row on one page with the same message: wait for this save itself, then for its new state.
    await submitAndWait(page, type.getByTestId("heim-shift-class-save"));
    await expect(page.getByTestId("heim-message")).toHaveText(/^Schichtklasse gespeichert\./);
    await expect(type.getByTestId("heim-shift-class-now")).not.toHaveText("Klasse: keine Klasse");
  }
  await page.goto("/heim?ansicht=personal");
  const missing: string[] = [];
  for (const li of await page.getByTestId("heim-staff-list").locator("li").all()) {
    const name = ((await li.getByTestId("heim-staff-link").textContent()) ?? "").trim();
    if (name in EXAMPLE_PENSUM && (await li.getByTestId("heim-staff-no-pensum").count()) === 1) missing.push(name);
  }
  for (const name of missing) {
    const pensum = EXAMPLE_PENSUM[name];
    await page.goto("/heim?ansicht=personal");
    await page.getByTestId("heim-staff-link").filter({ hasText: name }).first().click();
    const form = page.getByTestId("heim-staff-planning-form");
    await form.getByTestId("heim-staff-pensum-value").check();
    await form.getByTestId("heim-staff-pensum").fill(pensum);
    await form.getByTestId("heim-staff-planning-save").click();
    await expect(page.getByTestId("heim-message")).toHaveText("Pensum und Schichtmodell gespeichert.");
    await expect(page.getByTestId("heim-staff-planning-now")).toHaveText(new RegExp(`^Pensum ${pensum} % · `));
  }
}

// Path 7 (HD-3a, brief HD.md §5b «staging-smoke Pfad automatisch generieren → übernehmen → Lücke als Auftrag»): the
// home asks for a plan of a week, takes it over, sees each shown person in her shown shift, prepares an external
// order for a remaining gap and discards it (path 5 already sends one), then removes every row the take-over saved, so
// staging keeps no row of the run. Weeks of its own, 400 days and more ahead (paths 4 to 6 use 120 to 330 days), offset
// by the run number; a week a failed earlier run left planned (nothing new to propose) is skipped, at most 8 times.
// Fixed, checkable rules, no AI.
test("path 7: the home asks for a plan, takes it over, prepares an order for a remaining gap, then removes the plan (390 px)", async ({ page }) => {
  test.setTimeout(300_000);
  await page.setViewportSize({ width: 390, height: 900 });
  let week = weekStart(zurichDay(Date.now(), 400 + 7 * (offsets.day - 40)));

  await signIn(page, "kunde");
  await page.goto("/heim");
  await expect(page.getByRole("heading", { name: "Dienstplanung" })).toBeVisible();
  if (await page.getByTestId("heim-empty").isVisible()) {
    await page.getByTestId("heim-load-example").click();
    await expect(page.getByTestId("heim-message")).toHaveText("Beispieldaten geladen (synthetisch).");
  }
  await fillMissingPlanningInputs(page);

  const draft = page.getByTestId("heim-draft");
  for (let tries = 0; ; tries++) {
    await page.goto(`/heim?ansicht=woche&datum=${week}`);
    await page.getByTestId("heim-draft-start").click();
    await expect(draft.getByTestId("heim-draft-summary")).toHaveText(/^\d+ Dienste? vorgeschlagen · /);
    if ((await draft.getByTestId("heim-draft-row").count()) > 0) break;
    expect(tries, "staging-smoke path 7: nothing to propose in 8 weeks in a row").toBeLessThan(8);
    week = addDays(week, 7);
  }
  await expect(draft.getByTestId("heim-draft-mark")).toContainText("Optimierung (feste Regeln)");
  await expect(draft.getByTestId("heim-draft-mark")).toContainText("Arbeitszeitgesetz nicht abschliessend geprüft");
  expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(0);

  const shown: Array<{ date: string; station: string; shift: string; person: string }> = [];
  for (const day of await draft.getByTestId("heim-draft-day").all()) {
    const date = (await day.getAttribute("data-date")) as string;
    for (const r of await day.getByTestId("heim-draft-row").all()) {
      const person = ((await r.textContent()) ?? "").split(" · ").at(-1)!.replace(/\s*\([^)]*\)\s*$/, "").trim();
      shown.push({ date, station: (await r.getAttribute("data-station")) as string, shift: (await r.getAttribute("data-shift")) as string, person });
    }
  }
  const n = shown.length;
  await draft.getByTestId("heim-draft-apply").click();
  await expect(page.getByTestId("heim-message")).toHaveText(`Vorschlag übernommen: ${n} ${n === 1 ? "Dienst" : "Dienste"} eingeteilt.`);
  const cellOf = (s: { date: string; station: string; shift: string }) =>
    page.locator(`[data-testid="heim-day"][data-date="${s.date}"] [data-testid="heim-cell"][data-station="${s.station}"][data-shift="${s.shift}"]`);
  for (const s of shown) await expect(cellOf(s).getByTestId("heim-assigned").filter({ hasText: s.person })).toHaveCount(1);

  // A remaining gap as an external order: prepared, checked on its review screen, discarded (nothing is sent).
  const gapDay = page.locator('[data-testid="heim-day"]').filter({ has: page.getByTestId("heim-prepare-order") }).first();
  await expect(gapDay).toBeVisible();
  await gapDay.getByTestId("heim-prepare-order").first().click();
  await expect(page.getByTestId("heim-message")).toHaveText("Auftrag vorbereitet, noch nicht gesendet. Bitte prüfen und senden.");
  await page.getByTestId("heim-order-discard").click();
  await expect(page.getByTestId("heim-message")).toHaveText("Entwurf verworfen. Die Lücke bleibt.");

  // Clean up: every row the take-over saved, removed in the week; then the same week proposes the same count again.
  await page.goto(`/heim?ansicht=woche&datum=${week}`);
  // Each removal: its own server-action response, the message, and the person gone from exactly that cell, before the
  // next click (from the second removal on, the message alone is already on screen from the previous one).
  for (const s of shown) {
    const chip = cellOf(s).getByTestId("heim-assigned").filter({ hasText: s.person });
    await submitAndWait(page, chip.getByRole("button", { name: `${s.person} entfernen` }));
    await expect(page.getByTestId("heim-message")).toHaveText("Aus dem Dienst entfernt.");
    await expect(chip).toHaveCount(0);
  }
  await page.getByTestId("heim-draft-start").click();
  await expect(draft.getByTestId("heim-draft-summary")).toHaveText(new RegExp(`^${n} Dienste? vorgeschlagen · `));
});

// Path 8 (HD-3s, brief HD-3s.md acceptance «geteilte Dienstart anlegen → Plan vorschlagen → übernehmen → Woche zeigt
// einen Arbeitstag mit zwei Zeiten»): the home keeps one synthetic split shift type «GS» 07:00–11:30 und 16:00–20:00
// with the minimum staffing 1 on its first station («Beispielwert des Heims»); the run creates both once, through the
// forms on /heim, and never changes them afterwards (same times: the type stays usable while planned). Then it asks for
// a plan of a week of its own (600 days and more ahead, offset by the run number; paths 4 to 7 use 120 to 400+ days),
// takes it over, reads one working day with two times for each shown split row, and removes every saved row again, so
// staging keeps no plan row of the run. Fixed, checkable rules, no AI.
test("path 8: the home plans a split shift (two blocks), takes it over, the week shows two times, then removes the plan (390 px)", async ({ page }) => {
  test.setTimeout(300_000);
  await page.setViewportSize({ width: 390, height: 900 });
  const CODE = "GS";
  const TIMES = "07:00–11:30 und 16:00–20:00";
  let week = weekStart(zurichDay(Date.now(), 600 + 7 * (offsets.day - 40)));

  await signIn(page, "kunde");
  await page.goto("/heim");
  await expect(page.getByRole("heading", { name: "Dienstplanung" })).toBeVisible();
  if (await page.getByTestId("heim-empty").isVisible()) {
    await page.getByTestId("heim-load-example").click();
    await expect(page.getByTestId("heim-message")).toHaveText("Beispieldaten geladen (synthetisch).");
  }
  await fillMissingPlanningInputs(page);

  await page.goto("/heim?ansicht=einstellungen");
  const type = page.locator(`[data-testid="heim-shift-type"][data-code="${CODE}"]`);
  if ((await type.count()) === 0) {
    const f = page.getByTestId("heim-split-form");
    await f.getByTestId("heim-split-code").fill(CODE);
    await f.getByTestId("heim-split-label").fill("Geteilt");
    await f.getByTestId("heim-split-b1-starts").fill("07:00");
    await f.getByTestId("heim-split-b1-ends").fill("11:30");
    await f.getByTestId("heim-split-b2-starts").fill("16:00");
    await f.getByTestId("heim-split-b2-ends").fill("20:00");
    await submitAndWait(page, f.getByTestId("heim-split-save"));
    await expect(page.getByTestId("heim-message")).toHaveText("Geteilter Dienst gespeichert: ein Arbeitstag mit zwei Blöcken.");
  }
  await expect(type.getByTestId("heim-shift-times")).toHaveText(TIMES);
  await expect(type.getByTestId("heim-shift-class-now")).toHaveText("Klasse: Geteilt");
  const rule = page.locator(`[data-testid="heim-rule-form"][data-shift="${CODE}"]`).first();
  if ((await rule.textContent())?.includes("keine Vorgabe")) {
    await rule.locator('input[name="total"]').fill("1");
    await submitAndWait(page, rule.getByRole("button", { name: "Speichern" }));
    await expect(page.getByTestId("heim-message")).toHaveText("Vorgabe gespeichert.");
  }

  const draft = page.getByTestId("heim-draft");
  const splitRows = draft.locator(`[data-testid="heim-draft-row"][data-shift="${CODE}"]`);
  for (let tries = 0; ; tries++) {
    await page.goto(`/heim?ansicht=woche&datum=${week}`);
    await page.getByTestId("heim-draft-start").click();
    await expect(draft.getByTestId("heim-draft-summary")).toHaveText(/^\d+ Dienste? vorgeschlagen · /);
    if ((await splitRows.count()) > 0) break;
    expect(tries, "staging-smoke path 8: no split shift to propose in 8 weeks in a row").toBeLessThan(8);
    week = addDays(week, 7);
  }
  await expect(splitRows.first()).toContainText(TIMES);
  const shown: Array<{ date: string; station: string; shift: string; person: string }> = [];
  for (const day of await draft.getByTestId("heim-draft-day").all()) {
    const date = (await day.getAttribute("data-date")) as string;
    for (const r of await day.getByTestId("heim-draft-row").all()) {
      const person = ((await r.textContent()) ?? "").split(" · ").at(-1)!.replace(/\s*\([^)]*\)\s*$/, "").trim();
      shown.push({ date, station: (await r.getAttribute("data-station")) as string, shift: (await r.getAttribute("data-shift")) as string, person });
    }
  }
  const n = shown.length;
  await draft.getByTestId("heim-draft-apply").click();
  await expect(page.getByTestId("heim-message")).toHaveText(`Vorschlag übernommen: ${n} ${n === 1 ? "Dienst" : "Dienste"} eingeteilt.`);
  const cellOf = (s: { date: string; station: string; shift: string }) =>
    page.locator(`[data-testid="heim-day"][data-date="${s.date}"] [data-testid="heim-cell"][data-station="${s.station}"][data-shift="${s.shift}"]`);
  for (const s of shown) {
    await expect(cellOf(s).getByTestId("heim-assigned").filter({ hasText: s.person })).toHaveCount(1);
    if (s.shift === CODE) {
      await expect(cellOf(s).getByTestId("heim-cell-times")).toContainText(TIMES);
    }
  }
  expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(0);

  // Clean up: every row the take-over saved (as path 7).
  await page.goto(`/heim?ansicht=woche&datum=${week}`);
  for (const s of shown) {
    const chip = cellOf(s).getByTestId("heim-assigned").filter({ hasText: s.person });
    await submitAndWait(page, chip.getByRole("button", { name: `${s.person} entfernen` }));
    await expect(page.getByTestId("heim-message")).toHaveText("Aus dem Dienst entfernt.");
    await expect(chip).toHaveCount(0);
  }
});
