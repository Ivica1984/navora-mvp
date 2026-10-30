import { expect, test, type Page } from "@playwright/test";

// AIG1 part (b) (ADR-129, migrations 0097/0103). Synthetic local-only accounts from supabase/seed.sql, in organisations of
// their own (no org-A to org-D count changes):
// - teame.test (Testorganisation E, registered nurse of Testteam E): seven open proposals of the synthetic test agent for
//   tomorrow: 08:00-13:00 propose "Pflegekraft Bezug E" (bulk-eligible schedule field), 15:00 found no value.
// - opsf.test (Testorganisation F, operations): the agent stopped by its threshold; four values confirmed unchanged in the
//   stop window by "Pflegekraft Bestätigt F", one of them later replaced ("überholt").
// The confirm screen runs at 390 px, the health and look-back lists at desktop width (AIG1-10, AIG1-12 to AIG1-16).
const PASSWORD = "navora-local-only";
const AGENT = "Testassistent Bezugspflege";
const CONFIRMER_F = "Pflegekraft Bestätigt F";
const VISIT_E_1300 = "00000000-0000-4000-a000-0000000005a6";

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
    await expect(lines).toHaveCount(7);

    // AIG1-4: the agent found no value; the screen says so, never an empty value, and offers no tick and no plain confirm.
    const notFound = lines.filter({ hasText: "15:00" });
    await expect(notFound.getByTestId("suggestion-value")).toHaveText("Zuständig: nicht gefunden");
    await expect(notFound.getByTestId("suggestion-agent")).toHaveText(`vorgeschlagen von ${AGENT}`);
    await expect(notFound.getByTestId("suggestion-tick")).toHaveCount(0);
    await expect(notFound.getByRole("button", { name: "Bestätigen", exact: true })).toHaveCount(0);
    await notFound.getByRole("button", { name: "Als „nicht gefunden“ bestätigen" }).click();
    await expect(lines).toHaveCount(6);

    // AIG1-3: one proposed value, "vorgeschlagen von", changed to another member; the changed value is hers.
    const change = lines.filter({ hasText: "13:00" });
    await expect(change.getByTestId("suggestion-value")).toHaveText("Zuständig: Pflegekraft Bezug E");
    await expect(change.getByTestId("suggestion-agent")).toHaveText(`vorgeschlagen von ${AGENT}`);
    await expect(change.getByRole("button", { name: "Bestätigen", exact: true })).toBeVisible();
    await change.getByRole("button", { name: "Ändern" }).click();
    await change.getByRole("combobox").selectOption({ label: "Pflegekraft Team E (du)" });
    await change.getByRole("button", { name: "Geänderten Wert bestätigen" }).click();
    await expect(lines).toHaveCount(5);

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
    await expect(lines).toHaveCount(5);
    await expect(ticks).toHaveCount(5);
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
    await expect(lines).toHaveCount(2);
    await expect(lines.filter({ hasText: "11:00" })).toHaveCount(1);
    await expect(lines.filter({ hasText: "12:00" })).toHaveCount(1);
    expect(await checked()).toBe(0);
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
    await expect(row.getByTestId("agent-state")).toHaveText("gestoppt");
    await expect(row.getByTestId("agent-stop-share")).toHaveText("20 %");
    await expect(row.getByTestId("agent-stop-min")).toHaveText("5");
    await expect(row.getByTestId("agent-stop-window")).toHaveText("7 Tage");
    await expect(row.getByTestId("agent-min-reached")).toHaveText("Mindestzahl im letzten Fenster erreicht: ja");
    await expect(row.getByTestId("agent-last-share")).toContainText(/33[.,]33 %/);
    await expect(row.getByTestId("agent-stop-reason")).toContainText("Schwelle");
    // No person column.
    await expect(page.getByRole("table", { name: "Assistenten" })).not.toContainText(CONFIRMER_F);
  });

  test("the OPS1 exception opens the look-back list; it names no person, a superseded line shows 'überholt am', a line opens its record (AIG1-12, AIG1-13, AIG1-14)", async ({ page }) => {
    await page.goto("/operations");
    const exception = page.getByRole("article", { name: "Ausnahme Assistent gestoppt" });
    await expect(exception).toContainText(`${AGENT} · 3 offen`);
    await exception.getByTestId("lookback-link").click();
    await page.waitForURL(/\/operations\/assistenten\/rueckblick\//);

    const list = page.getByRole("list", { name: "Betroffene Werte" });
    const lines = list.getByTestId("lookback-line");
    await expect(lines).toHaveCount(4);
    await expect(page.getByTestId("lookback-open-count")).toHaveText("3 offen");
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

    // A line opens its record.
    await lines.filter({ hasNot: page.getByTestId("lookback-superseded") }).first().click();
    await page.waitForURL(/\/visits\/[0-9a-f-]{36}$/);
    await expect(page.getByTestId("visit-record")).toBeVisible();
    await expect(page.getByTestId("visit-responsible")).toHaveText("Pflegekraft Bezug F");
  });
});
