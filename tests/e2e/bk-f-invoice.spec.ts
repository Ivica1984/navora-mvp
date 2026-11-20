import { execFileSync } from "node:child_process";
import { expect, test, type Page } from "@playwright/test";
import { minutesBack, zurichDay, zurichMinuteOfDay } from "./support/durchgang-time";
import { INVOICE_LABEL, SEND_BUTTON } from "@/features/invoices/rules";

// BK-f e2e at 390 × 844 (PO package contract 2026-11-20 06:39 point 5: «carer signs → team sees the draft → one tap →
// client sees it under «Rechnungen»; protocol counts taps from «Bericht unterschreiben» to «gesendet», team level»).
// Synthetic local-only accounts from supabase/seed.sql (Testorganisation S, simulation):
//   kundebs.test  client of «Testheim Rhein (synthetisch)»: orders one HF shift tonight 22:30–23:30 (60 min);
//   kolleginbs.test registered nurse of Testteam Basel (seed price 68.00, «Beispielwert, kein Tarif»): takes it, works
//                 it, signs the report (final), then sends the draft from /team. Not pflegebs: BD-2 (durchgang-ambulant)
//                 asserts exactly two visits of pflegebs today (first CI run of this spec, job 136190356902).
// Fixture: the time tolerance row is NOT shipped by any migration (`lca` names the simulation value at the gate). This
// test inserts a row ONLY in the local CI database (port 54322, guarded) with the marker «e2e fixture, not a value» and
// deletes it at the end; it sets nothing on staging or production. Times: the take is before the order's start (22:30);
// she then works it now and corrects the recorded times with F3 «Testlauf» (the run cannot wait 60 real minutes), so
// the signed snapshot holds 60 recorded minutes against 60 ordered (inside any tolerance). Evening window, so no
// overlap with the BD-2 slots right after now.
const PASSWORD = "navora-local-only";
const F3_REASON = "Testlauf: simulierte Einsatzdauer";
const DB_URL = process.env.E2E_DB_URL ?? "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
const LOCAL_DB = /^postgres(ql)?:\/\/[^@]+@(127\.0\.0\.1|localhost):54322\//;
const FIXTURE_REF = "e2e fixture, not a value";

function psql(sql: string): string {
  if (!LOCAL_DB.test(DB_URL)) throw new Error("BK-f fixture: only the local Supabase database (port 54322)");
  return execFileSync("psql", [DB_URL, "-X", "-q", "-At", "-v", "ON_ERROR_STOP=1", "-c", sql], { encoding: "utf8" }).trim();
}

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

const deDate = (iso: string) => iso.split("-").reverse().join(".");

async function noSidewaysScroll(page: Page) {
  expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(0);
}

test("BK-f at 390 px: signed take report → invoice draft on /team → one tap «Bestätigen und senden» → client reads it under «Rechnungen»", async ({ page }) => {
  test.setTimeout(180_000);
  const minute = zurichMinuteOfDay(Date.now());
  // The F3 corrections go back 75 minutes and the take must be before 22:30, all on one Zurich day (ADR-113).
  test.skip(minute < 90 || minute > 22 * 60 + 10, "outside 01:30–22:10 Zurich: the run's times must stay on one day before the order start");
  await page.setViewportSize({ width: 390, height: 844 });
  const day = zurichDay();
  const when = `${deDate(day)} 22:30`;

  psql(`insert into public.invoice_time_tolerances (key, tolerance_minutes, lca_ref) values ('take_invoice', 15, '${FIXTURE_REF}')
        on conflict (key) do nothing`);
  try {
    // 1. The client orders one HF shift tonight, 60 minutes.
    await signIn(page, "kundebs.test@navora.test");
    await page.goto("/order");
    const form = page.getByRole("form", { name: "Auftrag" });
    await form.getByLabel(/^Datum/).fill(deDate(day));
    await form.getByLabel("Beginn", { exact: true }).fill("22:30");
    await form.getByLabel("Ende", { exact: true }).fill("23:30");
    await form.getByLabel("Einsatzort (Postleitzahl)").selectOption("4051");
    await form.getByRole("radio", { name: "HF", exact: true }).check();
    await form.getByRole("checkbox", { name: "Grundpflege", exact: true }).check();
    await form.getByRole("button", { name: "Weiter zur Zusammenfassung" }).click();
    await page.getByTestId("order-summary").getByRole("button", { name: "Bestätigen & Absenden" }).click();
    await expect(page.getByTestId("order-done")).toContainText("Auftrag bestätigt");
    await page.context().clearCookies();

    // 2. kolleginbs takes it naming herself (the take copies the team price, 0155).
    await signIn(page, "kolleginbs.test@navora.test");
    await page.goto("/team");
    // Contract point 2 (a): the team's own price, labelled as an example (seed 68.00, «Beispielwert, kein Tarif»).
    const price = page.getByTestId("team-price").filter({ hasText: "Testteam Basel" });
    await expect(price.getByTestId("team-price-current")).toHaveText("CHF 68.00");
    await expect(price).toContainText("Beispielwert, kein Tarif");
    const offer = page.getByTestId("shift-offer-card").filter({ hasText: when }).last();
    await offer.getByRole("button", { name: "Übernehmen mit Pflegekraft" }).click();
    await expect(page.getByTestId("shift-offer-card").filter({ hasText: when }).last().getByTestId("shift-offer-tag")).toHaveText("Übernommen");

    // 3. She works it on /field and records 60 minutes with F3 «Testlauf».
    await page.goto(`/field?datum=${day}`);
    const card = page.getByRole("article", { name: /22:30 – 23:30/ });
    await expect(card).toHaveCount(1);
    for (const [button, status] of [
      ["Losfahren", "Unterwegs"],
      ["Einsatz starten", "Gestartet"],
      ["Einsatz abschliessen", "Abgeschlossen"],
    ] as const) {
      await card.getByRole("button", { name: button }).click();
      await expect(card).toContainText(status);
      await expect(card.getByTestId("command-error")).toHaveCount(0);
    }
    const now = Date.now();
    await card.getByText("Zeiten ansehen und korrigieren").click();
    const timeline = card.getByRole("list", { name: "Zeitverlauf" });
    for (const [event, back] of [["Losgefahren", 75], ["Gestartet", 62], ["Abgeschlossen", 2]] as const) {
      const row = timeline.getByRole("listitem").filter({ hasText: event });
      await row.getByRole("button", { name: "Korrigieren" }).click();
      await row.getByLabel("Richtige Uhrzeit").fill(minutesBack(now, back));
      await row.getByLabel("Begründung").fill(F3_REASON);
      await row.getByRole("button", { name: "Korrektur speichern" }).click();
      await expect(row.getByLabel("Richtige Uhrzeit")).toHaveCount(0);
      await expect(row).toContainText("korrigiert");
    }

    // 4. «Bericht unterschreiben» (registered nurse: final at once). From here the taps are counted (Q8, team level).
    let taps = 0;
    await page.reload();
    const again = page.getByRole("article", { name: /22:30 – 23:30/ });
    const report = again.getByTestId("visit-report");
    await report.getByRole("form", { name: "Bericht prüfen und unterschreiben" }).getByRole("button", { name: "Bericht unterschreiben" }).click();
    taps += 1;
    await expect(report.getByTestId("report-status")).toHaveText("Bericht abgeschlossen");
    // Contract point 1: one line, nothing to type; the draft was built by the database without any input.
    await expect(report.getByTestId("report-invoice-line")).toHaveText("Rechnungsentwurf für das Team erstellt.");
    await noSidewaysScroll(page);

    // 5. /team «Rechnungsentwürfe»: hours, price, amount from the signed snapshot and the take snapshot; one tap sends.
    await page.goto("/team");
    const drafts = page.getByTestId("invoice-drafts");
    await expect(drafts.getByTestId("invoice-label")).toHaveText(INVOICE_LABEL);
    const draft = drafts.locator('[data-testid="invoice-draft"][data-state="draft"]').filter({ hasText: deDate(day) }).first();
    await expect(draft).toBeVisible();
    await expect(draft.getByTestId("invoice-hours")).toHaveText("1.00 Std.");
    await expect(draft.getByTestId("invoice-price")).toHaveText("CHF 68.00");
    await expect(draft.getByTestId("invoice-amount")).toHaveText("CHF 68.00");
    await draft.getByRole("button", { name: SEND_BUTTON }).click();
    taps += 1;
    const sent = drafts.locator('[data-testid="invoice-draft"][data-state="sent"]').filter({ hasText: deDate(day) }).first();
    await expect(sent.getByTestId("invoice-state")).toHaveText("Gesendet");
    await noSidewaysScroll(page);
    // Q8 protocol (team level, never per person): logged, not asserted as a limit.
    console.log(`BK-f Q8: taps from «Bericht unterschreiben» to «gesendet» = ${taps}`);
    test.info().annotations.push({ type: "Q8 taps sign→sent (team)", description: String(taps) });
    await page.context().clearCookies();

    // 6. The client reads the sent invoice under «Rechnungen»: amount, no member name (CGR-210 (c)).
    await signIn(page, "kundebs.test@navora.test");
    await page.goto("/order");
    const invoices = page.getByTestId("client-invoices");
    await expect(invoices.getByTestId("invoice-label")).toHaveText(INVOICE_LABEL);
    const mine = invoices.getByTestId("client-invoice").filter({ hasText: deDate(day) }).filter({ hasText: "CHF 68.00" });
    await expect(mine.first()).toBeVisible();
    await expect(mine.first().getByTestId("client-invoice-amount")).toHaveText("CHF 68.00");
    await expect(invoices).not.toContainText("Kollegin Basel S");
    await noSidewaysScroll(page);
  } finally {
    psql(`delete from public.invoice_time_tolerances where key = 'take_invoice' and lca_ref = '${FIXTURE_REF}'`);
  }
});
