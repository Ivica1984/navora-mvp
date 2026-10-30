import { expect, test, type Page } from "@playwright/test";
import { QUALIFICATION_MISSING_MESSAGE } from "@/lib/commands/result";
import { OPEN_VISITS_UNQUALIFIED_TEXT } from "@/features/field/qualification";
import { ADMISSION_OFF_CONSEQUENCE, ADMISSION_ON_CONSEQUENCE, CONTRACT_END_REMOVE_CONSEQUENCE } from "@/features/admin/confirm-texts";

// UX2-22 and UX2-23 (G-23 preconditions; ADR-124). Synthetic local-only accounts of Testorganisation D from
// supabase/seed.sql (its own organisation, so no other fixture or count changes):
// - ohnequal.test: member of Testteam D whose qualification is not yet recorded (ADM2-6 state). Testteam D has one
//   planned visit today at 21:00 with nobody responsible: on her day and in "Offen im Team".
// - admind.test: administrator of Testorganisation D; team admission is on; vertragd.test's contract ends in 30 days.
// The server refusal (ADM2-16, `qualification_missing`) is unchanged and proven in pgTAP 094. A qualified member's
// /field keeps its controls: field.spec, ux1.spec and vis1.spec are unchanged and still assert them.
// Every step that changes data is undone before the test ends (workers: 1).
const UNQUALIFIED = "ohnequal.test@navora.test";
const ADMIN = "admind.test@navora.test";
const PASSWORD = "navora-local-only";

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

function zurichDay(n: number): string {
  const today = new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Zurich" }).format(new Date());
  const [y, m, d] = today.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d + n)).toISOString().slice(0, 10);
}

test("UX2-22: a member without a recorded qualification is offered no field action she cannot perform", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await signIn(page, UNQUALIFIED);
  await page.goto(`/field?datum=${zurichDay(0)}`);

  // The ADM2-16 sentence once, at the top, in `info`.
  const note = page.getByTestId("qualification-missing-note");
  await expect(note).toHaveCount(1);
  await expect(note).toHaveText(QUALIFICATION_MISSING_MESSAGE);
  await expect(note).toHaveAttribute("data-tone", "info");

  // Her team's visit is on her day, without "Losfahren", "Einsatz starten" or a completion control.
  const card = page.getByRole("article", { name: /21:00 – 21:30/ });
  await expect(card).toBeVisible();
  for (const name of ["Losfahren", "Einsatz starten", "Einsatz abschliessen", "Fortsetzen"]) {
    await expect(card.getByRole("button", { name })).toHaveCount(0);
  }

  // "Offen im Team": heading without a count, `info`, one line; no visit, no client name, no take control, no toggle.
  const open = page.getByTestId("open-in-team");
  await expect(open).toBeVisible();
  await expect(open.getByRole("heading", { level: 2 })).toHaveText("Offen im Team");
  await expect(open).toHaveAttribute("data-tone", "info");
  await expect(open).toContainText(OPEN_VISITS_UNQUALIFIED_TEXT);
  await expect(open.getByTestId("open-visit")).toHaveCount(0);
  await expect(open.getByTestId("open-visit-next")).toHaveCount(0);
  await expect(open.getByTestId("open-in-team-toggle")).toHaveCount(0);
  await expect(open.getByRole("button", { name: "Übernehmen" })).toHaveCount(0);
  await expect(open).not.toContainText("Testfall");
  await expect(page.getByRole("button", { name: "Übernehmen" })).toHaveCount(0);

  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(390);
});

test("UX2-23: switching team admission asks once; cancel changes nothing, confirm runs the command once", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await signIn(page, ADMIN);
  await page.goto("/admin");
  const section = page.getByRole("region", { name: "Aufnahme durch das Team" });
  const state = section.getByTestId("admission-switch");
  await expect(state).toHaveText("Eingeschaltet");

  // One tap opens the step under the control, focus on its sentence, and changes nothing.
  await section.getByRole("button", { name: "Ausschalten" }).click();
  const step = section.getByTestId("admission-confirm");
  await expect(step.getByTestId("admission-confirm-sentence")).toHaveText(ADMISSION_OFF_CONSEQUENCE);
  await expect(step.getByTestId("admission-confirm-sentence")).toBeFocused();
  await expect(state).toHaveText("Eingeschaltet");

  // "Abbrechen" closes it; still on.
  await step.getByRole("button", { name: "Abbrechen" }).click();
  await expect(step).toHaveCount(0);
  await page.reload();
  await expect(state).toHaveText("Eingeschaltet");

  // Confirm runs the existing command once.
  await section.getByRole("button", { name: "Ausschalten" }).click();
  await section.getByTestId("admission-confirm").getByRole("button", { name: "Ausschalten" }).click();
  await expect(state).toHaveText("Ausgeschaltet");
  await expect(section.getByTestId("admission-confirm")).toHaveCount(0);

  // Back on: the step names who admits colleagues afterwards (restores the seed's state).
  await section.getByRole("button", { name: "Einschalten" }).click();
  await expect(section.getByTestId("admission-confirm-sentence")).toHaveText(ADMISSION_ON_CONSEQUENCE);
  await section.getByTestId("admission-confirm").getByRole("button", { name: "Einschalten" }).click();
  await expect(state).toHaveText("Eingeschaltet");
});

test("UX2-23: removing a contract end asks once; cancel keeps it, confirm removes it", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await signIn(page, ADMIN);
  await page.goto("/admin");
  const member = page.getByRole("region", { name: "Mitglieder" }).locator('li[aria-label^="Mitglied "]', { hasText: "Pflegekraft Vertrag D" });
  const control = member.getByLabel("Vertragsende", { exact: true });
  const line = control.getByTestId("contract-end-line");
  await expect(line).toBeVisible();
  const before = await line.textContent();

  await control.getByRole("button", { name: "Vertragsende entfernen" }).click();
  const step = control.getByTestId("contract-end-remove-confirm");
  await expect(step.getByTestId("contract-end-remove-confirm-sentence")).toHaveText(CONTRACT_END_REMOVE_CONSEQUENCE);
  await expect(step.getByTestId("contract-end-remove-confirm-sentence")).toBeFocused();

  await step.getByRole("button", { name: "Abbrechen" }).click();
  await expect(step).toHaveCount(0);
  await page.reload();
  await expect(line).toHaveText(before ?? "");

  // Confirm runs the existing command once, then the seed's end date is recorded again.
  await control.getByRole("button", { name: "Vertragsende entfernen" }).click();
  await control.getByTestId("contract-end-remove-confirm").getByRole("button", { name: "Vertragsende entfernen" }).click();
  await expect(control.getByTestId("contract-end-notice")).toHaveText("Vertragsende entfernt.");

  await control.getByRole("button", { name: "Vertragsende erfassen" }).click();
  await control.getByRole("form", { name: "Vertragsende erfassen" }).getByLabel("Letzter Vertragstag").fill(zurichDay(30));
  await control.getByRole("form", { name: "Vertragsende erfassen" }).getByRole("button", { name: "Speichern" }).click();
  await page.reload();
  await expect(line).toHaveText(before ?? "");
});
