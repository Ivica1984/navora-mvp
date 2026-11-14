import { readFile } from "node:fs/promises";
import { expect, test, type Page } from "@playwright/test";

// WORK1 (migration 0079, ADR-092) at phone width: information text on first use (WORK1-8), the proposal with both
// questions open (WORK1-2), confirm, correct (WORK1-3) and export the month (WORK1-4). Synthetic local-only account from
// supabase/seed.sql: assist.test (care assistant, Testteam Nord). The day is three days back, a day without her visit
// events, so start, end and both questions are hers to enter (gaps are never filled).
// COND1-5 (migration 0083, ADR-096): the seed gives assist.test a v1 acknowledgement, so she is shown v2 first
// (WORK1-C2); her own count of unexported days on /work and the administrator's count on /admin (WORK1-C3), shown only
// in the access-end step (COND1-5a, PO 16:20).
const NURSE = "assist.test@navora.test";
const ADMIN = "admin.test@navora.test"; // org A, role admin
const PASSWORD = "navora-local-only";

// Calendar days, not 24-hour steps (#635): in the evening of the first days after the autumn change, "now − 4 × 24 h"
// lands on the Zurich day three days back (the hour repeated at 02:00 shifts it), so both tests used one day and the
// second could not confirm it. Same arithmetic as field.spec (ADR-068).
function zurichDay(offsetDays: number): string {
  const [y, m, d] = new Date().toLocaleDateString("sv-SE", { timeZone: "Europe/Zurich" }).split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d + offsetDays)).toISOString().slice(0, 10);
}

async function signIn(page: Page, email = NURSE, landing: RegExp = /\/field/) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(landing);
}

test("the nurse confirms, corrects and exports her working day (WORK1-2, -3, -4, -8)", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  const day = zurichDay(-3);
  await signIn(page);
  await page.goto(`/work?datum=${day}`);

  // WORK1-8 / WORK1-C2: the information text comes first; she acknowledged v1 (seed), so v3 (COND1-5b) is shown before her
  // proposal. After acknowledging it, the proposal.
  const notice = page.getByRole("region", { name: "Information zu deinem Arbeitstag" });
  await expect(notice).toContainText("damit ihr die Pflege koordinieren könnt");
  await expect(notice).toContainText("siehst nur du");
  await expect(notice).toContainText("nur für einen angegebenen Prüfzweck gelesen");
  await expect(notice).toContainText("Ausserhalb einer solchen Prüfung sieht die Administration nur"); // COND1-5b (v3)
  await expect(notice).toContainText("erst ab drei Personen und fünf bestätigten Arbeitstagen");
  await notice.getByRole("button", { name: "Gelesen und verstanden" }).click();
  const proposal = page.getByRole("region", { name: "Vorschlag aus deinen Einsätzen" });
  await expect(proposal).toBeVisible();
  await expect(proposal).toContainText("Keine Einsatzzeiten an diesem Tag.");

  // WORK1-2: nothing is pre-answered; confirming waits for start, end and both questions.
  const confirm = page.getByRole("button", { name: "Arbeitstag bestätigen" });
  await expect(confirm).toBeDisabled();
  await page.getByLabel("Beginn des Arbeitstags?").fill("07:00");
  await page.getByLabel("Ende des Arbeitstags?").fill("15:30");
  const breaks = page.getByRole("group", { name: "Pausen von 30 Minuten oder mehr?" });
  await breaks.getByLabel("Ja, eintragen", { exact: true }).check();
  await breaks.getByLabel("Von", { exact: true }).fill("12:00");
  await breaks.getByLabel("Bis", { exact: true }).fill("12:30");
  await expect(confirm).toBeDisabled();
  await page.getByRole("group", { name: "Arbeit ausserhalb der Einsätze?" }).getByLabel("Keine", { exact: true }).check();
  await expect(confirm).toBeEnabled();
  await confirm.click();

  // WORK1-3: confirmed as version 1; paid time = start to end minus the break.
  await expect(page.getByRole("heading", { name: "Bestätigt (Fassung 1)" })).toBeVisible();
  await expect(page.getByTestId("paid-minutes")).toContainText("480 Min.");
  // WORK1-C3 (d): her own count, with a prompt to export.
  await expect(page.getByTestId("unexported-days")).toContainText("1 bestätigter Tag ist noch nicht exportiert.");

  // Correction: a new version with a reason code; the earlier version stays readable.
  await page.getByRole("button", { name: "Korrigieren" }).click();
  await page.getByLabel("Ende des Arbeitstags?").fill("16:00");
  const correct = page.getByRole("button", { name: "Korrektur bestätigen" });
  await expect(correct).toBeDisabled();
  await page.getByLabel("Grund").selectOption("time_wrong");
  await page.getByLabel("Notiz (nur für dich, höchstens 200 Zeichen)").fill("Synthetisch: später fertig");
  await correct.click();
  await expect(page.getByRole("heading", { name: "Bestätigt (Fassung 2)" })).toBeVisible();
  await expect(page.getByTestId("paid-minutes")).toContainText("510 Min.");
  await expect(page.getByRole("region", { name: "Frühere Fassungen" })).toContainText("Fassung 1");

  // WORK1-4: export of the month on her action; no note in the file.
  const exportRegion = page.getByRole("region", { name: "Monat exportieren" });
  await exportRegion.getByLabel("Monat").fill(day.slice(0, 7));
  const [download] = await Promise.all([
    page.waitForEvent("download"),
    exportRegion.getByRole("button", { name: "Als CSV herunterladen" }).click(),
  ]);
  expect(download.suggestedFilename()).toBe(`navora-arbeitszeit-${day.slice(0, 7)}.csv`);
  const csv = await readFile((await download.path())!, "utf8");
  expect(csv).toContain("datum;art;beginn;ende;minuten;fassung;bestaetigt_am");
  expect(csv).toContain(`${day};Arbeitstag;`);
  expect(csv).toContain(`${day};Bezahlte Arbeitszeit (Tag ohne Pausen);;;510;2;`);
  expect(csv).not.toContain("Synthetisch");
  // WORK1-C3: the export was made after her latest version, so nothing is left unexported.
  await expect(page.getByTestId("unexported-days")).toHaveText("Alle bestätigten Tage sind exportiert.");

  // Phone width: no horizontal scroll.
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(390);
});

test("the administrator sees her unexported days only in the access-end step (WORK1-C3, COND1-5a)", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  // She confirms one more day (four days back, no visit events) and does not export it.
  const day = zurichDay(-4);
  await signIn(page);
  await page.goto(`/work?datum=${day}`);
  await page.getByLabel("Beginn des Arbeitstags?").fill("08:00");
  await page.getByLabel("Ende des Arbeitstags?").fill("12:00");
  await page.getByRole("group", { name: "Pausen von 30 Minuten oder mehr?" }).getByLabel("Keine", { exact: true }).check();
  await page.getByRole("group", { name: "Arbeit ausserhalb der Einsätze?" }).getByLabel("Keine", { exact: true }).check();
  await page.getByRole("button", { name: "Arbeitstag bestätigen" }).click();
  await expect(page.getByRole("heading", { name: "Bestätigt (Fassung 1)" })).toBeVisible();
  // Her own count on /work is unchanged by COND1-5a.
  await expect(page.getByTestId("unexported-days")).toContainText("1 bestätigter Tag ist noch nicht exportiert.");
  await page.context().clearCookies();

  // COND1-5a: the member row itself shows no count (no standing per-person figure).
  await signIn(page, ADMIN, /\/operations$/);
  await page.goto("/admin");
  const row = page.getByRole("region", { name: "Mitglieder" }).locator('li[aria-label^="Mitglied "]', { hasText: NURSE });
  await expect(row.getByRole("button", { name: "Zugang beenden" })).toBeVisible();
  await expect(row.getByTestId("unexported-days")).toHaveCount(0);
  await expect(row).not.toContainText("Bestätigte Tage, die sie noch nicht exportiert hat");
  // After choosing to end her access: one number (no date, month or time) and the G-19 item (4) prompt (not ended here).
  await row.getByRole("button", { name: "Zugang beenden" }).click();
  const count = row.getByTestId("unexported-end-count");
  await expect(count).toHaveText("Bestätigte Tage, die sie noch nicht exportiert hat: 1");
  await expect(count).not.toContainText(day.slice(0, 7));
  await expect(row.getByTestId("unexported-end-prompt")).toContainText("Sie hat 1 bestätigten Tag noch nicht exportiert.");
  // Phone width: /admin keeps its desktop sidebar layout (as push.spec SIG2-C1), so the count's own box must not overflow.
  expect(await count.evaluate((el) => el.scrollWidth - el.clientWidth)).toBeLessThanOrEqual(0);
  await row.getByRole("button", { name: "Abbrechen" }).click();
  await expect(row.getByTestId("unexported-end-count")).toHaveCount(0);
});
