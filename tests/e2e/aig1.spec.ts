import { expect, test, type Page } from "@playwright/test";

// AIG1 part (b) (ADR-129, migrations 0097/0103). Synthetic local-only accounts from supabase/seed.sql, in organisations of
// their own (no org-A to org-D count changes):
// - teame.test (Testorganisation E, registered nurse of Testteam E): eight open proposals of the synthetic test agent for
//   tomorrow: 08:00-13:00 propose "Pflegekraft Bezug E" (bulk-eligible schedule field), 14:00 (category B minutes)
//   proposes "Pflegekraft Assistenz E", a care assistant (refused not_qualified, AIG1-C3 (2)), 15:00 found no value.
// - opsf.test (Testorganisation F, operations): the agent stopped by its threshold; four values confirmed unchanged in the
//   stop window by "Pflegekraft Bestätigt F", one of them later replaced ("überholt").
//   AIG1-C1 / AIG1-C2 (ADR-130, migration 0104): of the three lines still holding their value, …5b1 is dated yesterday
//   ("Einsatz nicht mehr offen", counted apart), …5b2 is open with a valid member, …5b3 (category B minutes) holds a
//   member recorded as care assistant after the stop.
// - teamf.test (Testorganisation F, registered nurse of Testteam F): re-checks look-back values on the record page at 390 px.
//   AIG1-C4 (ADR-139, migration 0105): an undecided proposal of the stop window for …5b7, dated two days ago, has expired:
//   not on /team/vorschlaege, counted as "Abgelaufen ohne Entscheid: 1" on the health list. CGR-106: "Ändern" on …5b3.
// - opsg.test (Testorganisation G, operations): AIG1-C5: the agent stopped with one open line and was switched off; the
//   OPS1 exception and the look-back link stay.
// The confirm screen runs at 390 px, the health and look-back lists at desktop width (AIG1-10, AIG1-12 to AIG1-16).
const PASSWORD = "navora-local-only";
const AGENT = "Testassistent Bezugspflege";
const CONFIRMER_F = "Pflegekraft Bestätigt F";
const VISIT_E_1300 = "00000000-0000-4000-a000-0000000005a6";
const STOP_F = "00000000-0000-4000-a000-0000000006f1";
const VISIT_F_PAST = "00000000-0000-4000-a000-0000000005b1";
const VISIT_F_OPEN = "00000000-0000-4000-a000-0000000005b2";
const VISIT_F_UNQUALIFIED = "00000000-0000-4000-a000-0000000005b3";
const STOP_G = "00000000-0000-4000-a000-0000000006f2";

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

/** Today in Europe/Zurich as dd.mm.yyyy. */
function zurichToday(): string {
  const [y, m, d] = new Date().toLocaleDateString("sv-SE", { timeZone: "Europe/Zurich" }).split("-");
  return `${d}.${m}.${y}`;
}

test.describe.serial("AIG1 confirm screen at 390 px (Testorganisation E)", () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await signIn(page, "teame.test@navora.test");
    await page.goto("/team/vorschlaege");
  });

  test("one value at a time: 'vorgeschlagen von', 'nicht gefunden', confirm and change (AIG1-3, AIG1-4, AIG1-10)", async ({ page }) => {
    const lines = page.getByRole("list", { name: "Offene Vorschläge" }).getByTestId("suggestion");
    await expect(lines).toHaveCount(8);

    // AIG1-4: the agent found no value; the screen says so, never an empty value, and offers no tick and no plain confirm.
    const notFound = lines.filter({ hasText: "15:00" });
    await expect(notFound.getByTestId("suggestion-value")).toHaveText("Verantwortlich: nicht gefunden");
    await expect(notFound.getByTestId("suggestion-agent")).toHaveText(`vorgeschlagen von ${AGENT}`);
    await expect(notFound.getByTestId("suggestion-tick")).toHaveCount(0);
    await expect(notFound.getByRole("button", { name: "Bestätigen", exact: true })).toHaveCount(0);
    await notFound.getByRole("button", { name: "Als „nicht gefunden“ bestätigen" }).click();
    await expect(lines).toHaveCount(7);

    // AIG1-3: one proposed value, "vorgeschlagen von", changed to another member; the changed value is hers.
    const change = lines.filter({ hasText: "13:00" });
    await expect(change.getByTestId("suggestion-value")).toHaveText("Verantwortlich: Pflegekraft Bezug E");
    await expect(change.getByTestId("suggestion-agent")).toHaveText(`vorgeschlagen von ${AGENT}`);
    await expect(change.getByRole("button", { name: "Bestätigen", exact: true })).toBeVisible();
    await change.getByRole("button", { name: "Ändern" }).click();
    await change.getByRole("combobox").selectOption({ label: "Pflegekraft Team E (du)" });
    await change.getByRole("button", { name: "Geänderten Wert bestätigen" }).click();
    await expect(lines).toHaveCount(6);

    // The record shows the value and "vorgeschlagen von <Agent> / … bestätigt von <Name> am <Datum>" for this one value.
    await page.goto(`/visits/${VISIT_E_1300}`);
    await expect(page.getByTestId("visit-responsible")).toHaveText("Pflegekraft Team E");
    await expect(page.getByTestId("value-provenance")).toHaveText(
      `vorgeschlagen von ${AGENT} / geändert und bestätigt von Pflegekraft Team E am ${zurichToday()}`,
    );
  });

  test("the ticked list starts unticked, each box ticks one line, three ticked of five confirm exactly three (AIG1-5, CGR-78 (b))", async ({ page }) => {
    const lines = page.getByRole("list", { name: "Offene Vorschläge" }).getByTestId("suggestion");
    const ticks = page.getByTestId("suggestion-tick");
    const checked = () => ticks.evaluateAll((els) => els.filter((e) => (e as HTMLInputElement).checked).length);
    await expect(lines).toHaveCount(6);
    await expect(ticks).toHaveCount(6);
    expect(await checked()).toBe(0);
    // No "select all" and no "alle übernehmen".
    await expect(page.getByRole("button", { name: /alle/i })).toHaveCount(0);
    await expect(page.getByRole("checkbox", { name: /alle/i })).toHaveCount(0);
    const button = page.getByTestId("bulk-confirm");
    await expect(button).toHaveText("0 angekreuzte Werte bestätigen");
    await expect(button).toBeDisabled();

    for (const [i, time] of ["08:00", "09:00", "10:00"].entries()) {
      await lines.filter({ hasText: time }).getByTestId("suggestion-tick").check();
      await expect.poll(checked).toBe(i + 1);
    }
    await expect(button).toHaveText("3 angekreuzte Werte bestätigen");
    await button.click();
    await expect(page.getByTestId("bulk-result")).toHaveText("3 Werte bestätigt.");
    await expect(lines).toHaveCount(3);
    await expect(lines.filter({ hasText: "11:00" })).toHaveCount(1);
    await expect(lines.filter({ hasText: "12:00" })).toHaveCount(1);
    await expect(lines.filter({ hasText: "14:00" })).toHaveCount(1);
    expect(await checked()).toBe(0);
  });

  test("a refused value keeps its reason on its line; the result names both counts; tick rows are 44 px and tap by text (AIG1-C3 (2), (3))", async ({ page }) => {
    const lines = page.getByRole("list", { name: "Offene Vorschläge" }).getByTestId("suggestion");
    const ticks = page.getByTestId("suggestion-tick");
    const checked = () => ticks.evaluateAll((els) => els.filter((e) => (e as HTMLInputElement).checked).length);
    await expect(lines).toHaveCount(3);
    expect(await checked()).toBe(0);

    // UXR-69: the tick label (box and line text) is at least 44 px high; tapping its text ticks only that line.
    const label = lines.filter({ hasText: "11:00" }).getByTestId("suggestion-tick-label");
    const box = await label.boundingBox();
    expect(box?.height ?? 0).toBeGreaterThanOrEqual(44);
    await label.getByTestId("suggestion-value").click();
    await expect.poll(checked).toBe(1);
    await expect(lines.filter({ hasText: "11:00" }).getByTestId("suggestion-tick")).toBeChecked();

    await lines.filter({ hasText: "12:00" }).getByTestId("suggestion-tick").check();
    await lines.filter({ hasText: "14:00" }).getByTestId("suggestion-tick").check();
    await expect.poll(checked).toBe(3);
    await page.getByTestId("bulk-confirm").click();

    // UXR-66: both counts; the refused value stays with its own reason, the two others leave.
    await expect(page.getByTestId("bulk-result")).toHaveText("2 Werte bestätigt, 1 nicht übernommen.");
    await expect(lines).toHaveCount(1);
    const refused = lines.filter({ hasText: "14:00" });
    await expect(refused.getByTestId("suggestion-refusal")).toHaveText(
      "Nicht übernommen: Diese Person darf den Einsatz nicht durchführen (Mitgliedschaft oder Qualifikation).",
    );
  });
});

test.describe("AIG1 health and look-back lists at desktop width (Testorganisation F)", () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 900 });
    await signIn(page, "opsf.test@navora.test");
  });

  test("the health list shows state, last window, the written threshold and whether the minimum was reached (AIG1-10, AIG1-16)", async ({ page }) => {
    await page.goto("/operations/assistenten");
    const row = page.getByTestId("agent-health-row").filter({ hasText: AGENT });
    await expect(row).toHaveCount(1);
    // AIG1-C5 (c): the state is a status with its date.
    await expect(row.getByTestId("agent-state")).toHaveText(/^Gestoppt seit \d{2}\.\d{2}\.\d{4}$/);
    await expect(row.getByTestId("agent-stop-share")).toHaveText("20 %");
    await expect(row.getByTestId("agent-stop-min")).toHaveText("5");
    await expect(row.getByTestId("agent-stop-window")).toHaveText("7 Tage");
    await expect(row.getByTestId("agent-min-reached")).toHaveText("Mindestzahl im letzten Fenster erreicht: ja");
    await expect(row.getByTestId("agent-last-share")).toContainText(/33[.,]33 %/);
    await expect(row.getByTestId("agent-stop-reason")).toContainText("Schwelle");
    // AIG1-C4 (3): the expired proposal is counted apart, next to the decided count.
    await expect(row.getByTestId("agent-expired")).toHaveText("Abgelaufen ohne Entscheid: 1");
    // AIG1-C5 (b): the stop with open lines names its counts and links its look-back list.
    const stop = row.getByTestId("agent-stop-open");
    await expect(stop).toHaveCount(1);
    await expect(stop.getByTestId("agent-stop-counts")).toContainText("Werte: 2 offen · 1 nicht mehr offen");
    await expect(stop.getByRole("link", { name: "Betroffene Werte ansehen" })).toHaveAttribute(
      "href",
      `/operations/assistenten/rueckblick/${STOP_F}`,
    );
    // No person column.
    await expect(page.getByRole("table", { name: "Assistenten" })).not.toContainText(CONFIRMER_F);
  });

  test("the OPS1 exception opens the look-back list; it names no person, a superseded line shows 'überholt am', a line opens its record (AIG1-12, AIG1-13, AIG1-14)", async ({ page }) => {
    await page.goto("/operations");
    const exception = page.getByRole("article", { name: "Ausnahme Assistent gestoppt" });
    // AIG1-C1 (2): both counts, the past visit's line counted apart.
    await expect(exception).toContainText(`${AGENT} · Werte: 2 offen · 1 nicht mehr offen`);
    await exception.getByTestId("lookback-link").click();
    await page.waitForURL(/\/operations\/assistenten\/rueckblick\//);

    const list = page.getByRole("list", { name: "Betroffene Werte" });
    const lines = list.getByTestId("lookback-line");
    await expect(lines).toHaveCount(4);
    await expect(page.getByTestId("lookback-open-count")).toHaveText("Werte: 2 offen · 1 nicht mehr offen");
    // PLAN3-13 (ADR-150): the measure per team above the list, counts only (pgTAP 113 owns every count).
    const measure = page.getByTestId("stop-measure-row");
    await expect(measure).toHaveCount(1);
    await expect(measure.getByRole("rowheader")).toHaveText("Testteam F");
    await expect(measure.getByTestId("stop-measure-lines_at_stop")).toHaveText("4");
    await expect(measure.getByTestId("stop-measure-superseded")).toHaveText("1");
    await expect(measure.getByTestId("stop-measure-not_open_at_stop")).toHaveText("0");
    await expect(measure.getByTestId("stop-measure-became_not_open")).toHaveText("1");
    await expect(measure.getByTestId("stop-measure-days_to_zero_open")).toHaveText(/^noch \d offen$/);
    // AIG1-14: no confirmer's name, no "bestätigt von", no outcome, no person filter or sort.
    await expect(list).not.toContainText(CONFIRMER_F);
    await expect(list).not.toContainText("bestätigt von");
    await expect(page.locator("main")).not.toContainText(CONFIRMER_F);
    await expect(page.getByRole("combobox")).toHaveCount(0);
    await expect(page.getByRole("checkbox")).toHaveCount(0);
    await expect(page.locator("main").getByRole("button", { name: /sortier|filter/i })).toHaveCount(0);
    // AIG1-13 (b): the replaced value stays, labelled with its date, without tick or "erledigt".
    const superseded = lines.filter({ has: page.getByTestId("lookback-superseded") });
    await expect(superseded).toHaveCount(1);
    await expect(superseded.getByTestId("lookback-superseded")).toHaveText(`überholt am ${zurichToday()}`);
    await expect(superseded).not.toContainText(/erledigt/i);

    // AIG1-C1 (2)/(3): the past visit's line stays, says so with its date, and has no confirm control.
    const notOpen = lines.filter({ has: page.getByTestId("lookback-not-open") });
    await expect(notOpen).toHaveCount(1);
    await expect(notOpen.getByTestId("lookback-not-open")).toHaveText("Einsatz nicht mehr offen");
    await expect(list.getByRole("button")).toHaveCount(0);
    await expect(list).not.toContainText(/bestätigen|ändern/i);

    // A line opens its record. AIG1-C2 (d): Operations sees the record without a confirm or change control.
    await lines.filter({ hasNot: page.getByTestId("lookback-superseded") }).filter({ hasNot: page.getByTestId("lookback-not-open") }).first().click();
    await page.waitForURL(new RegExp(`/visits/${VISIT_F_OPEN}\\?`));
    await expect(page.getByTestId("visit-record")).toBeVisible();
    await expect(page.getByTestId("visit-responsible")).toHaveText("Pflegekraft Bezug F");
    await expect(page.getByRole("button", { name: "Erneut bestätigen" })).toHaveCount(0);
    await expect(page.getByRole("button", { name: "Ändern" })).toHaveCount(0);
    await expect(page.getByTestId("record-lookback")).toHaveCount(0);
    // AIG1-C3 (1): back to the same stop's list.
    await expect(page.getByTestId("record-back")).toHaveText("Zurück zur Liste");
    await page.getByTestId("record-back").click();
    await page.waitForURL(new RegExp(`/operations/assistenten/rueckblick/${STOP_F}$`));
  });
});

// PLAN3-7 (ADR-151): Operations opens the day-plan team measures from the health list. Testorganisation F has no
// day-plan line (only the synthetic test agent), so the page shows its empty state or a row without any day plan; pgTAP
// 114 owns every value. Never a person's name.
test.describe("PLAN3-7: Tagesvorschlag in Zahlen at desktop width (Testorganisation F)", () => {
  test("the page is reached from the health list, per team only, without a person", async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 900 });
    await signIn(page, "opsf.test@navora.test");
    await page.goto("/operations/assistenten");
    await page.getByTestId("plan-team-measures-link").click();
    await page.waitForURL(/\/operations\/assistenten\/tagesvorschlag$/);
    await expect(page.getByRole("heading", { level: 1 })).toHaveText("Tagesvorschlag in Zahlen");
    const section = page.getByTestId("plan-team-measures");
    await expect(section).toBeVisible();
    await expect(page.getByTestId("plan-team-measures-error")).toHaveCount(0);
    const rows = page.getByTestId("plan-team-measure-row");
    if ((await rows.count()) === 0) {
      await expect(page.getByTestId("plan-team-measures-empty")).toBeVisible();
    } else {
      await expect(rows.first().getByTestId("plan-team-measure-day_plans")).toHaveText(/^0 · 0 Zeilen$/);
    }
    await expect(page.locator("main")).not.toContainText(CONFIRMER_F);
    await expect(page.locator("main")).not.toContainText("bestätigt von");
    // ?monat=YYYY-MM selects a month.
    await page.goto("/operations/assistenten/tagesvorschlag?monat=2026-01");
    await expect(page.getByRole("main")).toContainText("(2026-01)");
  });
});

// PLAN3-11 (ADR-149, migration 0111): after a stop, the team finds its own look-back lines on `/team`. Runs before the
// AIG1-C1 / AIG1-C2 block below (one worker, file order): that block, with #814's CGR-106 "Ändern" test, decides every
// open line of stop F, and at "0 offen" `/team` shows no entry (AIG1-C5 (d)). Here the seeded count reads 2 (1 if the
// health and look-back tests above ever decide a line). This block only reads.
test.describe.serial("PLAN3-11: the team finds its own look-back lines on /team at 390 px (Testorganisation F)", () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await signIn(page, "teamf.test@navora.test");
  });

  test("/team shows the stop with both counts and one link; the list names no person and a line opens its record with 'Erneut bestätigen'", async ({ page }) => {
    await page.goto("/team");
    const entry = page.getByTestId("team-lookback-entry");
    await expect(entry).toHaveCount(1);
    await expect(entry).toContainText(new RegExp(`${AGENT} gestoppt · Werte: [12] offen · 1 nicht mehr offen`));
    await entry.getByRole("link", { name: "Werte prüfen" }).click();
    await page.waitForURL(new RegExp(`/team/rueckblick/${STOP_F}$`));

    const list = page.getByRole("list", { name: "Betroffene Werte" });
    await expect(list.getByTestId("lookback-line").first()).toBeVisible();
    // AIG1-14: no confirmer's name, no "bestätigt von" on the list.
    await expect(page.getByText(CONFIRMER_F)).toHaveCount(0);
    await expect(page.getByText(/bestätigt von/)).toHaveCount(0);
    // No horizontal scroll at 390 px.
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);

    // AIG1-C2: the line opens its record, which offers the team's action and links back to this list.
    await page.locator(`a[href^="/visits/${VISIT_F_UNQUALIFIED}?von=team-rueckblick"]`).click();
    await page.waitForURL(new RegExp(`/visits/${VISIT_F_UNQUALIFIED}\\?`));
    await expect(page.getByTestId("record-lookback").getByRole("button", { name: "Erneut bestätigen" })).toBeVisible();
    await expect(page.getByTestId("record-back")).toHaveText("Zurück zur Liste");
    await page.getByTestId("record-back").click();
    await page.waitForURL(new RegExp(`/team/rueckblick/${STOP_F}$`));
  });
});

test.describe.serial("AIG1-C1 / AIG1-C2: the team re-checks look-back values on the record page at 390 px (Testorganisation F)", () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await signIn(page, "teamf.test@navora.test");
  });

  test("an undecided proposal whose visit passed is not listed (AIG1-C4 (1))", async ({ page }) => {
    await page.goto("/team/vorschlaege");
    await expect(page.getByTestId("suggestions-empty")).toBeVisible();
    await expect(page.getByTestId("suggestion")).toHaveCount(0);
  });

  test("'Erneut bestätigen' on a line of an open visit: the line leaves the open count (AIG1-C2 (a))", async ({ page }) => {
    await page.goto(`/operations/assistenten/rueckblick/${STOP_F}`);
    const lines = page.getByRole("list", { name: "Betroffene Werte" }).getByTestId("lookback-line");
    await expect(lines).toHaveCount(4);
    await expect(page.getByTestId("lookback-open-count")).toHaveText("Werte: 2 offen · 1 nicht mehr offen");
    // The look-back page names only actions the product offers (AIG1-C2 (c)).
    await expect(page.getByTestId("lookback-explanation")).toContainText("erneut bestätigt oder ändert");

    await page.locator(`a[href^="/visits/${VISIT_F_OPEN}?"]`).click();
    await page.waitForURL(new RegExp(`/visits/${VISIT_F_OPEN}\\?`));
    const section = page.getByTestId("record-lookback");
    await expect(section.getByRole("button", { name: "Erneut bestätigen" })).toBeVisible();
    await expect(section.getByRole("button", { name: "Ändern" })).toBeVisible();
    // Never the ticked list (AIG1-13 (a)).
    await expect(page.getByRole("checkbox")).toHaveCount(0);
    await section.getByRole("button", { name: "Erneut bestätigen" }).click();
    await expect(page.getByTestId("record-lookback-result")).toHaveText("Erneut bestätigt. Der Wert ist nicht mehr auf der Liste.");
    await expect(page.getByTestId("record-lookback-line")).toHaveCount(0);
    await expect(page.getByTestId("value-provenance")).toHaveText(
      `vorgeschlagen von ${AGENT} / bestätigt von Pflegekraft Team F am ${zurichToday()}`,
    );

    // AIG1-C3 (1): "Zurück zur Liste" returns to the same stop's list.
    await expect(page.getByTestId("record-back")).toHaveText("Zurück zur Liste");
    await page.getByTestId("record-back").click();
    await page.waitForURL(new RegExp(`/operations/assistenten/rueckblick/${STOP_F}$`));
    await expect(lines).toHaveCount(3);
    await expect(page.getByTestId("lookback-open-count")).toHaveText("Werte: 1 offen · 1 nicht mehr offen");
  });

  test("a member no longer qualified for the visit (care assistant, category B): the not_qualified text, the count is unchanged (AIG1-C2 (a), AIG1-15)", async ({ page }) => {
    await page.goto(`/visits/${VISIT_F_UNQUALIFIED}`);
    const section = page.getByTestId("record-lookback");
    await section.getByRole("button", { name: "Erneut bestätigen" }).click();
    await expect(section.getByTestId("command-error")).toHaveText(
      "Nicht übernommen: Diese Person darf den Einsatz nicht durchführen (Mitgliedschaft oder Qualifikation).",
    );
    await expect(page.getByTestId("record-lookback-line")).toHaveCount(1);

    await page.goto(`/operations/assistenten/rueckblick/${STOP_F}`);
    await expect(page.getByTestId("lookback-open-count")).toHaveText("Werte: 1 offen · 1 nicht mehr offen");
  });

  test("'Ändern' to a qualified member: the record holds her and the line leaves the list (CGR-106)", async ({ page }) => {
    await page.goto(`/visits/${VISIT_F_UNQUALIFIED}`);
    const section = page.getByTestId("record-lookback");
    await section.getByRole("button", { name: "Ändern" }).click();
    await section.getByRole("combobox").selectOption({ label: "Pflegekraft Bezug F" });
    await section.getByRole("button", { name: "Geänderten Wert bestätigen" }).click();
    await expect(page.getByTestId("record-lookback-result")).toHaveText("Geändert und bestätigt. Der Wert ist nicht mehr auf der Liste.");
    await expect(page.getByTestId("record-lookback-line")).toHaveCount(0);
    await expect(page.getByTestId("visit-responsible")).toHaveText("Pflegekraft Bezug F");

    await page.goto(`/operations/assistenten/rueckblick/${STOP_F}`);
    await expect(page.getByTestId("lookback-open-count")).toHaveText("Werte: 0 offen · 1 nicht mehr offen");
  });

  test("a line of a visit no longer open: 'Einsatz nicht mehr offen', no confirm or change control (AIG1-C1 (2), AIG1-C2 (b))", async ({ page }) => {
    await page.goto(`/visits/${VISIT_F_PAST}`);
    const section = page.getByTestId("record-lookback");
    await expect(section.getByTestId("record-lookback-not-open")).toHaveText("Einsatz nicht mehr offen");
    await expect(section.getByRole("button")).toHaveCount(0);
  });
});

test.describe("AIG1-C5: a stop's follow-up does not depend on the agent's state (Testorganisation G, desktop)", () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 900 });
    await signIn(page, "opsg.test@navora.test");
  });

  test("after the stopped agent was switched off, Operations still reaches the look-back list from the exception and the health list (AIG1-C5 (a)-(c))", async ({ page }) => {
    await page.goto("/operations");
    const exception = page.getByRole("article", { name: "Ausnahme Assistent gestoppt" });
    await expect(exception).toContainText(`${AGENT} · Werte: 1 offen · 0 nicht mehr offen`);
    await exception.getByTestId("lookback-link").click();
    await page.waitForURL(new RegExp(`/operations/assistenten/rueckblick/${STOP_G}$`));
    await expect(page.getByRole("list", { name: "Betroffene Werte" }).getByTestId("lookback-line")).toHaveCount(1);

    await page.goto("/operations/assistenten");
    const row = page.getByTestId("agent-health-row").filter({ hasText: AGENT });
    await expect(row.getByTestId("agent-state")).toHaveText("Aus");
    const stop = row.getByTestId("agent-stop-open");
    await expect(stop.getByTestId("agent-stop-counts")).toContainText("Werte: 1 offen · 0 nicht mehr offen");
    await stop.getByRole("link", { name: "Betroffene Werte ansehen" }).click();
    await page.waitForURL(new RegExp(`/operations/assistenten/rueckblick/${STOP_G}$`));
  });
});
