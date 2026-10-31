import { expect, test, type Browser, type Page } from "@playwright/test";

// ASM1 (migration 0100, ADR-123) at phone width, ASM1-10 and ASM1-11 (1); ASM1-C1 to ASM1-C4 (migration 0101, ADR-125). Synthetic local-only accounts of
// Testorganisation A (supabase/seed.sql): assist.test (care assistant, Testteam Nord) enters the assessment naming
// pflege.test (registered nurse, Nord); pflege.test confirms it, writes two care-plan items against it, records a newer
// assessment and corrects that one with a reason. Instrument "Testinstrument Bedarf 1.0" (…971) is a synthetic seed entry.
// The permission, append-only and validity paths are in pgTAP 100; the no-sum and no-colour rendering in
// tests/unit/asm1-assessment.test.ts. This test writes on Testfall 08 only (two records, one correction, two plan items).
const PASSWORD = "navora-local-only";
const ASSIST = "assist.test@navora.test";
const NURSE = "pflege.test@navora.test";
const NURSE_ID = "00000000-0000-4000-a000-000000000902";
const INSTRUMENT_ID = "00000000-0000-4000-a000-000000000971";

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

async function phone(browser: Browser, email: string): Promise<Page> {
  const context = await browser.newContext({ viewport: { width: 390, height: 844 } });
  const page = await context.newPage();
  await signIn(page, email);
  await page.goto("/team");
  return page;
}

function zurichDay(offset = 0): string {
  const [y, m, d] = new Date().toLocaleDateString("sv-SE", { timeZone: "Europe/Zurich" }).split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d + offset)).toISOString().slice(0, 10);
}
const swiss = (iso: string) => `${iso.slice(8, 10)}.${iso.slice(5, 7)}.${iso.slice(0, 4)}`;

const FIRST = zurichDay(-20);
const NEWER = zurichDay(-2);

test("record, see 'nicht bestätigt', confirm as the named nurse, supersede with a reason, see the marker on the care plan (ASM1-10)", async ({ browser }) => {
  // 1. The care assistant enters the assessment and names the registered nurse.
  const assist = await phone(browser, ASSIST);
  let card = assist.getByRole("article", { name: /Fall Testfall 08/ });
  let section = card.getByRole("region", { name: "Bedarfsabklärung" });
  await section.getByRole("button", { name: "Bedarfsabklärung erfassen" }).click();
  let form = section.getByRole("form", { name: "Bedarfsabklärung erfassen" });
  // ASM1-C3 (UXR-54): the reference rule is visible on the empty form, before any refusal
  await expect(form.getByTestId("reference-hint")).toContainText("mindestens eine Ziffer");
  await form.getByLabel("Datum der Abklärung").fill(FIRST);
  await form.getByLabel("Instrument").selectOption(INSTRUMENT_ID);
  await form.getByLabel("Abklärende Pflegefachperson").selectOption(NURSE_ID);
  // ASM1-3: a file name is refused with the reason, nothing is stored
  await form.getByLabel("Referenz der vollständigen Abklärung").fill("abklaerung.pdf");
  await form.getByRole("button", { name: "Bedarfsabklärung speichern" }).click();
  await expect(section.getByTestId("assessment-error")).toContainText("kein Dateiname");
  await form.getByLabel("Referenz der vollständigen Abklärung").fill("E2E-ASM1-1");
  await form.getByLabel("Minuten A", { exact: true }).fill("60");
  await form.getByLabel("Zeitraum A", { exact: true }).fill("pro Woche");
  await form.getByLabel("Minuten C", { exact: true }).fill("300");
  await form.getByLabel("Zeitraum C", { exact: true }).fill("pro Woche");
  await form.getByRole("button", { name: "Bedarfsabklärung speichern" }).click();
  const current = section.getByTestId("assessment-current");
  await expect(current).toContainText(`Bedarfsabklärung vom ${swiss(FIRST)}`);
  await expect(current.getByTestId("assessment-state")).toHaveText("Status: nicht bestätigt");
  // ASM1-C2 (UXR-55): the minutes with their period are shown once per card, in the care-plan block
  await expect(card.getByRole("region", { name: "Pflegeplan" }).getByTestId("plan-category-C")).toContainText("Bedarfsabklärung: 300 min pro Woche");
  await expect(card.getByText(/Kategorie C/)).toHaveCount(1);
  // she is not the named nurse: no confirm button for her
  await expect(current.getByRole("button", { name: "Als abklärende Pflegefachperson bestätigen" })).toHaveCount(0);
  // ASM1-C1: the record does not name her, so her "Zu erledigen" row shows no confirmation line
  await assist.goto("/field");
  await expect(assist.getByTestId("todo-assessment-confirm")).toHaveCount(0);
  await assist.context().close();

  // 2. The named registered nurse sees the work on her day (ASM1-C1), follows the link and confirms it.
  const nurse = await phone(browser, NURSE);
  await nurse.goto("/field");
  const todo = nurse.getByTestId("todo-assessment-confirm");
  await expect(todo).toHaveText(/^Zu bestätigen: Bedarfsabklärung \(\d+\)$/);
  const waiting = Number(/\((\d+)\)/.exec((await todo.textContent()) ?? "")?.[1] ?? "0");
  expect(waiting).toBeGreaterThanOrEqual(1);
  await todo.click();
  await nurse.waitForURL(/\/team#bedarfsabklaerung-/);
  card = nurse.getByRole("article", { name: /Fall Testfall 08/ });
  section = card.getByRole("region", { name: "Bedarfsabklärung" });
  await section.getByTestId("assessment-current").getByRole("button", { name: "Als abklärende Pflegefachperson bestätigen" }).click();
  await expect(section.getByTestId("assessment-current").getByTestId("assessment-state")).toHaveText("Status: bestätigt");
  // ASM1-C1: once confirmed, her line is gone (or counts one less)
  await nurse.goto("/field");
  if (waiting === 1) await expect(nurse.getByTestId("todo-assessment-confirm")).toHaveCount(0);
  else await expect(nurse.getByTestId("todo-assessment-confirm")).toHaveText(`Zu bestätigen: Bedarfsabklärung (${waiting - 1})`);
  await nurse.goto("/team");
  card = nurse.getByRole("article", { name: /Fall Testfall 08/ });
  section = card.getByRole("region", { name: "Bedarfsabklärung" });

  // 3. Two care-plan items of category C, written against that assessment (ASM1-7, ASM1-11).
  const plan = card.getByRole("region", { name: "Pflegeplan" });
  for (const [service, minutes, frequency] of [["E2E ASM1 Morgenpflege", "30", "2× täglich"], ["E2E ASM1 Duschen", "60", "1× wöchentlich"]]) {
    await plan.getByRole("button", { name: "Leistung hinzufügen" }).click();
    const item = plan.getByRole("form", { name: "Leistung hinzufügen" });
    await item.getByLabel("Leistung", { exact: true }).fill(service);
    await item.getByLabel("Kategorie").selectOption("C");
    await item.getByLabel("Minuten pro Einsatz").fill(minutes);
    await item.getByLabel("Häufigkeit").fill(frequency);
    await item.getByLabel("Überprüfung am").fill(zurichDay(60));
    await item.getByRole("button", { name: "Leistung speichern" }).click();
    await expect(plan).toContainText(service);
  }
  const basis = plan.getByTestId("plan-assessment");
  await expect(basis.getByTestId("plan-basis")).toContainText(`Bedarfsabklärung vom ${swiss(FIRST)}`);
  await expect(basis.getByTestId("plan-newer-assessment")).toHaveCount(0);
  // ASM1-11 (1): both items listed as written beside the assessed minutes with their period, no total anywhere
  const rowC = basis.getByTestId("plan-category-C");
  await expect(rowC).toContainText("Bedarfsabklärung: 300 min pro Woche");
  await expect(rowC).toContainText("E2E ASM1 Morgenpflege · 30 min pro Einsatz · 2× täglich");
  await expect(rowC).toContainText("E2E ASM1 Duschen · 60 min pro Einsatz · 1× wöchentlich");
  await expect(basis).not.toContainText(/\b90 min|Summe|Total|gesamt|Abweichung/);

  // 4. A newer assessment, entered by the nurse herself (confirmed at once): the marker appears on the care plan.
  await section.getByRole("button", { name: "Bedarfsabklärung erfassen" }).click();
  form = section.getByRole("form", { name: "Bedarfsabklärung erfassen" });
  await form.getByLabel("Datum der Abklärung").fill(NEWER);
  await form.getByLabel("Instrument").selectOption(INSTRUMENT_ID);
  await form.getByLabel("Abklärende Pflegefachperson").selectOption(NURSE_ID);
  await form.getByLabel("Referenz der vollständigen Abklärung").fill("E2E-ASM1-2");
  await form.getByLabel("Minuten C", { exact: true }).fill("360");
  await form.getByLabel("Zeitraum C", { exact: true }).fill("pro Woche");
  await form.getByRole("button", { name: "Bedarfsabklärung speichern" }).click();
  await expect(section.getByTestId("assessment-current")).toContainText(`Bedarfsabklärung vom ${swiss(NEWER)}`);
  await expect(section.getByTestId("assessment-current").getByTestId("assessment-state")).toHaveText("Status: bestätigt");
  await expect(basis.getByTestId("plan-newer-assessment")).toHaveText(`Neuere Bedarfsabklärung vom ${swiss(NEWER)}`);

  // 5. She corrects the newer one: a supersede with a reason; the old record stays, marked as replaced.
  await section.getByTestId("assessment-current").getByRole("button", { name: "Korrigieren (ersetzen)" }).click();
  form = section.getByRole("form", { name: "Bedarfsabklärung ersetzen" });
  await form.getByLabel("Instrument").selectOption(INSTRUMENT_ID);
  await form.getByLabel("Abklärende Pflegefachperson").selectOption(NURSE_ID);
  await form.getByLabel("Minuten C", { exact: true }).fill("330");
  await form.getByLabel("Grund für den Ersatz").fill("Synthetisch: Minuten C falsch übertragen");
  await form.getByRole("button", { name: "Ersatz speichern" }).click();
  // ASM1-C2 (`cra` 09:30): the "Ersetzt …" line of the current record is visible without opening the history
  await expect(section.getByTestId("assessment-current").getByTestId("assessment-supersede-reason")).toBeVisible();
  await expect(section.getByTestId("assessment-current")).toContainText("Grund: Synthetisch: Minuten C falsch übertragen");
  // ASM1-C2: the history waits in a closed details; the replaced record stays reachable there (ASM1-2)
  const history = section.getByTestId("assessment-history-details");
  await expect(history).not.toHaveAttribute("open", "");
  await history.getByText(/^Frühere Erfassungen \(\d+\)$/).click();
  await expect(section.getByRole("listitem", { name: `Bedarfsabklärung vom ${swiss(NEWER)} (ersetzt)` })).toContainText("Ersetzt:");
  await expect(card.getByText(/Kategorie C/)).toHaveCount(1);
  await expect(basis.getByTestId("plan-newer-assessment")).toHaveText(`Neuere Bedarfsabklärung vom ${swiss(NEWER)}`);
  await expect(basis.getByTestId("plan-category-C")).toContainText("Bedarfsabklärung: 330 min pro Woche");

  // 6. ASM1-C4 (AUT-26): one review act re-bases the plan; the items stay as written.
  // ASM1-C4 (d) (UXR-60): the command sits below the last category row, labelled as a command, and asks once
  const command = basis.getByRole("button", { name: `Als geprüft bestätigen: Pflegeplan gegen Bedarfsabklärung vom ${swiss(NEWER)}` });
  const commandBox = await command.boundingBox();
  const lastRowBox = await basis.getByTestId("plan-category-C").boundingBox();
  expect(commandBox!.y).toBeGreaterThanOrEqual(lastRowBox!.y + lastRowBox!.height);
  await command.click();
  const step = basis.getByTestId("plan-review-confirm");
  await expect(step.getByTestId("plan-review-confirm-sentence")).toContainText(swiss(NEWER));
  // "Abbrechen" records nothing: the marker stays
  await step.getByRole("button", { name: "Abbrechen" }).click();
  await expect(basis.getByTestId("plan-newer-assessment")).toHaveText(`Neuere Bedarfsabklärung vom ${swiss(NEWER)}`);
  await expect(basis.getByTestId("plan-review")).toHaveCount(0);
  await command.click();
  await basis.getByTestId("plan-review-confirm").getByRole("button", { name: "Als geprüft bestätigen", exact: true }).click();
  await expect(basis.getByTestId("plan-newer-assessment")).toHaveCount(0);
  await expect(basis.getByTestId("plan-basis")).toContainText(`Bedarfsabklärung vom ${swiss(NEWER)}`);
  await expect(basis.getByTestId("plan-review")).toContainText(`Pflegeplan geprüft gegen die Bedarfsabklärung vom ${swiss(NEWER)}`);
  await expect(plan).toContainText("E2E ASM1 Morgenpflege");
  await expect(plan).toContainText("E2E ASM1 Duschen");
  await expect(basis.getByRole("button", { name: /^Als geprüft bestätigen/ })).toHaveCount(0);
  await nurse.context().close();
});
