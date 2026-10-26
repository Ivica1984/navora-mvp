import { readFile } from "node:fs/promises";
import { expect, test, type Page } from "@playwright/test";

// WORK1 (migration 0079, ADR-092) at phone width: information text on first use (WORK1-8), the proposal with both
// questions open (WORK1-2), confirm, correct (WORK1-3) and export the month (WORK1-4). Synthetic local-only account from
// supabase/seed.sql: assist.test (care assistant, Testteam Nord). The day is three days back, a day without her visit
// events, so start, end and both questions are hers to enter (gaps are never filled).
const NURSE = "assist.test@navora.test";
const PASSWORD = "navora-local-only";

function zurichDay(offsetDays: number): string {
  const d = new Date(Date.now() + offsetDays * 86_400_000);
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Zurich", year: "numeric", month: "2-digit", day: "2-digit" }).format(d);
}

async function signIn(page: Page) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(NURSE);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(/\/field/);
}

test("the nurse confirms, corrects and exports her working day (WORK1-2, -3, -4, -8)", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  const day = zurichDay(-3);
  await signIn(page);
  await page.goto(`/work?datum=${day}`);

  // WORK1-8: the information text comes first; after acknowledging it, the proposal.
  const notice = page.getByRole("region", { name: "Information zu deinem Arbeitstag" });
  await expect(notice).toContainText("damit ihr die Pflege koordinieren könnt");
  await expect(notice).toContainText("siehst nur du");
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

  // Phone width: no horizontal scroll.
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(390);
});
