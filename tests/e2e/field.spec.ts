import { expect, test, type Page } from "@playwright/test";

// F1 — the nurse's day (/field). Synthetic local-only accounts from supabase/seed.sql.
// Runs after auth.spec.ts (serial, one worker): by then visit 501 (08:00, Testteam Nord)
// is completed and visit 502 (10:00, Testteam Nord) is still "started".
const COACH = "coach.test@navora.test"; //  org A, coach, in no team
const NURSE = "pflege.test@navora.test"; // org A, nurse, Testteam Nord
const ASSISTANT = "assist.test@navora.test"; // org A, care assistant, Testteam Nord (F7)
const PASSWORD = "navora-local-only";

// The seed and the app use the Europe/Zurich calendar date (ADR-068); CI's clock runs in UTC.
function zurichDay(offset = 0): string {
  const [y, m, d] = new Date().toLocaleDateString("sv-SE", { timeZone: "Europe/Zurich" }).split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d + offset)).toISOString().slice(0, 10);
}
const SEED_DAY = zurichDay();
// Visit 508 (Testteam Nord, 09:00) is planned for the day after and untouched by other tests.
const NEXT_DAY = zurichDay(1);
// Visit 509 (Testteam Nord, 18:00) two days ahead: the care assistant runs it in the F7 test below.
const DAY_AFTER_NEXT = zurichDay(2);
// Status buttons only (F4 adds "Beobachtung speichern" to completed visits).
const TRANSITION = /^(Losfahren|Einsatz starten|Pause|Fortsetzen|Einsatz abschliessen)$/;

async function signIn(page: Page, email: string, landing: RegExp) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(landing);
}

test.describe("field tool (F1)", () => {
  test("a nurse lands on her day after sign-in", async ({ page }) => {
    await signIn(page, NURSE, /\/field$/);
    await expect(page.getByRole("navigation", { name: "Tag wechseln" })).toBeVisible();
    // Visiting "/" also lands a nurse in the field tool.
    await page.goto("/");
    await expect(page).toHaveURL(/\/field$/);
  });

  test("a nurse sees exactly her team's visits of the day, with minimal client context", async ({ page }) => {
    await signIn(page, NURSE, /\/field$/);
    await page.goto(`/field?datum=${SEED_DAY}`);

    const visits = page.getByRole("list", { name: "Einsätze" }).getByRole("article");
    await expect(visits).toHaveCount(2);
    await expect(page.getByRole("article", { name: /08:00 – 08:45/ })).toContainText("Testfall 08");
    await expect(page.getByRole("article", { name: /10:00 – 10:30/ })).toContainText("Testteam Nord");
    // Visit 503 (11:00) belongs to Testteam West; org-B visits are never visible.
    await expect(page.getByRole("article", { name: /11:00/ })).toHaveCount(0);
    await expect(page.getByText("Fremdteam B")).toHaveCount(0);

    // Data minimisation: no health or billing fields in the page payload.
    const html = await page.content();
    for (const field of ["diagnosis_tags", "cognitive_status", "mobility_status", "date_of_birth", "insurance_provider", "billable"]) {
      expect(html, `field ${field} must not be in the page payload`).not.toContain(`"${field}"`);
    }
  });

  test("a nurse completes a running visit; the change is saved", async ({ page }) => {
    await signIn(page, NURSE, /\/field$/);
    await page.goto(`/field?datum=${SEED_DAY}`);

    const card = page.getByRole("article", { name: /10:00 – 10:30/ });
    await expect(card).toContainText("Gestartet");
    await card.getByRole("button", { name: "Einsatz abschliessen" }).click();

    await expect(card).toContainText("Abgeschlossen");
    await expect(card.getByRole("button", { name: TRANSITION })).toHaveCount(0);

    await page.reload();
    await expect(page.getByRole("article", { name: /10:00 – 10:30/ })).toContainText("Abgeschlossen");
  });

  test("a coach who is in no team gets an empty day, not someone else's visits", async ({ page }) => {
    await signIn(page, COACH, /\/operations$/);
    await page.goto(`/field?datum=${SEED_DAY}`);
    await expect(page.getByText("Keine Einsätze deiner Teams an diesem Tag.")).toBeVisible();
  });

  test("day navigation and an invalid date parameter", async ({ page }) => {
    await signIn(page, NURSE, /\/field$/);
    await page.goto("/field?datum=2026-02-30");
    await expect(page.getByRole("heading", { level: 1 })).toHaveText("Heute");

    await page.getByRole("link", { name: "Folgetag →" }).click();
    await expect(page).toHaveURL(/\/field\?datum=\d{4}-\d{2}-\d{2}$/);
    await expect(page.getByRole("heading", { level: 1 })).not.toHaveText("Heute");
  });

  test("full field path: depart, start, pause, resume, complete — with separate times (F2)", async ({ page }) => {
    await signIn(page, NURSE, /\/field$/);
    await page.goto(`/field?datum=${NEXT_DAY}`);

    const card = page.getByRole("article", { name: /09:00 – 09:45/ });
    await expect(card).toContainText("Geplant");
    await expect(card.getByRole("region", { name: "Erfasste Zeit" })).toHaveCount(0);

    const steps: Array<[string, string]> = [
      ["Losfahren", "Unterwegs"],
      ["Einsatz starten", "Gestartet"],
      ["Pause", "Pausiert"],
      ["Fortsetzen", "Gestartet"],
      ["Einsatz abschliessen", "Abgeschlossen"],
    ];
    for (const [button, status] of steps) {
      await card.getByRole("button", { name: button }).click();
      await expect(card).toContainText(status);
    }

    await expect(card.getByRole("button", { name: TRANSITION })).toHaveCount(0);
    const times = card.getByRole("region", { name: "Erfasste Zeit" });
    await expect(times).toContainText("Anfahrt");
    await expect(times).toContainText("Pflege");
    await expect(times).toContainText("Pause");
    await expect(times).not.toContainText("unstimmig");

    await page.reload();
    await expect(page.getByRole("article", { name: /09:00 – 09:45/ })).toContainText("Abgeschlossen");
    await expect(page.getByRole("article", { name: /09:00 – 09:45/ }).getByRole("region", { name: "Erfasste Zeit" })).toBeVisible();
  });

  test("time corrections need a reason, keep the original and refuse impossible orders (F3)", async ({ page }) => {
    // Corrections use Swiss wall-clock time on the day the event was recorded.
    const zurich = (offsetMin: number) =>
      new Intl.DateTimeFormat("de-CH", { timeZone: "Europe/Zurich", hour: "2-digit", minute: "2-digit", hourCycle: "h23" })
        .format(new Date(Date.now() + offsetMin * 60_000));
    test.skip(zurich(0) < "00:30", "too close to midnight in Zurich for a same-day correction");

    await signIn(page, NURSE, /\/field$/);
    await page.goto(`/field?datum=${NEXT_DAY}`);
    const card = page.getByRole("article", { name: /09:00 – 09:45/ });
    await card.getByText("Zeiten ansehen und korrigieren").click();
    const timeline = card.getByRole("list", { name: "Zeitverlauf" });

    // Impossible order: completion at 00:00 would lie before the start → refused with a clear message.
    const completed = timeline.getByRole("listitem").filter({ hasText: "Abgeschlossen" });
    await completed.getByRole("button", { name: "Korrigieren" }).click();
    await completed.getByLabel("Richtige Uhrzeit").fill("00:00");
    await completed.getByLabel("Begründung").fill("Test einer unmöglichen Reihenfolge");
    await completed.getByRole("button", { name: "Korrektur speichern" }).click();
    await expect(completed.getByTestId("command-error")).toContainText("Reihenfolge");
    await completed.getByRole("button", { name: "Abbrechen" }).click();

    // Valid correction: departure 20 minutes earlier, with a reason.
    const departed = timeline.getByRole("listitem").filter({ hasText: "Losgefahren" });
    await departed.getByRole("button", { name: "Korrigieren" }).click();
    await departed.getByLabel("Richtige Uhrzeit").fill(zurich(-20));
    await departed.getByLabel("Begründung").fill("Abfahrt zu spät getippt");
    await departed.getByRole("button", { name: "Korrektur speichern" }).click();

    await expect(departed).toContainText("korrigiert");
    await expect(departed).toContainText("Abfahrt zu spät getippt");
    await expect(card.getByRole("region", { name: "Erfasste Zeit" })).toContainText(/(19|20|21) min/);

    await page.reload();
    const again = page.getByRole("article", { name: /09:00 – 09:45/ });
    await again.getByText("Zeiten ansehen und korrigieren").click();
    await expect(again.getByRole("listitem").filter({ hasText: "Losgefahren" })).toContainText("korrigiert");
  });

  test("observations: recorded with provenance, edited as a new version, handed over to the next visit (F4)", async ({ page }) => {
    await signIn(page, NURSE, /\/field$/);
    await page.goto(`/field?datum=${SEED_DAY}`);

    // Visit 502 (10:00, completed earlier in this file) — client Testfall 08.
    const card = page.getByRole("article", { name: /10:00 – 10:30/ });
    const observations = card.getByRole("region", { name: "Beobachtungen" });
    await observations.getByLabel("Neue Beobachtung").fill("Klientin müde, trinkt wenig. Bitte morgen Trinkmenge beobachten.");
    await observations.getByLabel("Für die Übergabe markieren").check();
    await observations.getByRole("button", { name: "Beobachtung speichern" }).click();

    const entry = observations.getByRole("listitem").filter({ hasText: "trinkt wenig" });
    await expect(entry).toContainText("von dir");
    await expect(entry).toContainText("Übergabe");
    await expect(observations.getByLabel("Neue Beobachtung")).toHaveValue("");

    // Change = new version; the edited text replaces the old one in the view.
    await entry.getByRole("button", { name: "Ändern" }).click();
    await observations.getByLabel("Beobachtung ändern").fill("Klientin müde, trinkt wenig (ca. 0.5 l bis Mittag). Bitte morgen Trinkmenge beobachten.");
    await observations.getByRole("button", { name: "Änderung speichern" }).click();
    await expect(observations.getByRole("listitem").filter({ hasText: "ca. 0.5 l" })).toContainText("geändert");
    await expect(observations.getByText("trinkt wenig. Bitte", { exact: false })).toHaveCount(0);

    // HAND1: "since you were last here" on the same client's next visits. Visit 508 (tomorrow) is already
    // completed, so the section is collapsed there; it opens with one tap.
    await page.goto(`/field?datum=${NEXT_DAY}`);
    const done = page.getByRole("article", { name: /09:00 – 09:45/ }).getByTestId("since-last");
    await done.locator("summary").click();
    await expect(done.getByRole("listitem").filter({ hasText: "ca. 0.5 l bis Mittag" })).toContainText("Ich");

    // Visit 509 (day after tomorrow, planned): open before the start, with the rule that applied, in full text.
    // This nurse's last completed visit of the client is 508 (F2 test above); the observation came after it.
    await page.goto(`/field?datum=${DAY_AFTER_NEXT}`);
    const before = page.getByRole("article", { name: /18:00 – 18:30/ }).getByTestId("since-last");
    await expect(before).toHaveAttribute("open", "");
    await expect(before.getByTestId("since-last-rule")).toContainText("Seit deinem letzten Einsatz am");
    const sinceEntry = before.getByRole("listitem").filter({ hasText: "ca. 0.5 l bis Mittag" });
    await expect(sinceEntry).toContainText("Klientin müde, trinkt wenig (ca. 0.5 l bis Mittag). Bitte morgen Trinkmenge beobachten.");
    await expect(sinceEntry).toContainText("für die Übergabe markiert");
    await expect(sinceEntry).toContainText("Einsatz vom");
  });

  test("sign at completion: the draft from the visit data waits at completion and is signed with one confirmation; corrections are new versions (F6, F7)", async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await signIn(page, NURSE, /\/field$/);
    await page.goto(`/field?datum=${NEXT_DAY}`);

    // Visit 508 was run end to end by this nurse (F2 test above), a registered nurse → no countersignature.
    // F7: completing it already opened the draft; the nurse checks the facts and signs once.
    const card = page.getByRole("article", { name: /09:00 – 09:45/ });
    const report = card.getByTestId("visit-report");
    await expect(report.getByTestId("report-status")).toHaveText("Entwurf");
    const review = report.getByRole("form", { name: "Bericht prüfen und unterschreiben" });
    await expect(review.getByTestId("report-facts")).toContainText("Leistungen");
    await review.getByLabel("Zusammenfassung (optional)").fill("Synthetischer Bericht: Grundpflege wie geplant.");

    await review.getByRole("button", { name: "Bericht unterschreiben" }).click();
    await expect(report).toContainText("Grundpflege wie geplant");
    await expect(report.getByTestId("report-status")).toHaveText("Bericht abgeschlossen");
    await expect(report).toContainText("von dir");
    await expect(report.getByRole("button", { name: "Bericht unterschreiben" })).toHaveCount(0);
    await expect(report.getByRole("button", { name: "Zusammenfassung bearbeiten" })).toHaveCount(0);

    // CSR1 / CGR-03: signed means fixed. Times and observations are no longer offered for change; the hint names
    // the correction path (the database refuses them too, pgTAP 040).
    await card.getByText("Zeiten ansehen", { exact: true }).click();
    await expect(card.getByRole("list", { name: "Zeitverlauf" }).getByRole("button", { name: "Korrigieren", exact: true })).toHaveCount(0);
    await expect(card.getByRole("region", { name: "Beobachtungen" }).getByLabel("Neue Beobachtung")).toHaveCount(0);
    await expect(card.getByTestId("facts-locked")).toContainText("Bericht korrigieren");

    // Correction = new version with a reason; the signed version stays unchanged.
    await report.getByRole("button", { name: "Bericht korrigieren" }).click();
    await report.getByLabel("Begründung der Korrektur").fill("Leistung ergänzt");
    await report.getByRole("button", { name: "Neue Fassung anlegen" }).click();
    await expect(report.getByTestId("report-status")).toHaveText("Entwurf (Fassung 2)");
    await expect(report).toContainText("Korrektur: Leistung ergänzt");
    // The correction draft reopens the facts: they flow into the new version when it is signed.
    await expect(card.getByRole("region", { name: "Beobachtungen" }).getByLabel("Neue Beobachtung")).toBeVisible();
    await expect(card.getByTestId("facts-locked")).toHaveCount(0);

    await page.reload();
    await expect(page.getByRole("article", { name: /09:00 – 09:45/ }).getByTestId("report-status")).toHaveText("Entwurf (Fassung 2)");

    // CSR1 / CGR-02: she signs what she saw. An observation recorded in a second window after she opened the report
    // is not signed unseen: the signature is refused, the card reloads with it, and she signs the version she now sees.
    const shownCard = page.getByRole("article", { name: /09:00 – 09:45/ });
    const shownReport = shownCard.getByTestId("visit-report");
    const shownReview = shownReport.getByRole("form", { name: "Bericht prüfen und unterschreiben" });
    await expect(shownReview.getByTestId("report-facts")).not.toContainText("zweiten Fenster");

    const other = await page.context().newPage();
    await other.setViewportSize({ width: 390, height: 844 });
    await other.goto(`/field?datum=${NEXT_DAY}`);
    const otherObservations = other.getByRole("article", { name: /09:00 – 09:45/ }).getByRole("region", { name: "Beobachtungen" });
    await otherObservations.getByLabel("Neue Beobachtung").fill("Synthetisch: nachgetragen im zweiten Fenster.");
    await otherObservations.getByRole("button", { name: "Beobachtung speichern" }).click();
    await expect(otherObservations).toContainText("nachgetragen im zweiten Fenster");
    await other.close();

    await shownReview.getByRole("button", { name: "Bericht unterschreiben" }).click();
    await expect(shownReport.getByTestId("command-error")).toContainText("haben sich geändert");
    await expect(shownReport.getByTestId("report-status")).toHaveText("Entwurf (Fassung 2)");
    await expect(shownReview.getByRole("list", { name: "Beobachtungen im Bericht" })).toContainText("nachgetragen im zweiten Fenster");
    await shownReview.getByRole("button", { name: "Bericht unterschreiben" }).click();
    await expect(shownReport.getByTestId("report-status")).toHaveText("Bericht abgeschlossen (Fassung 2)");
    await expect(shownReport.getByTestId("command-error")).toHaveCount(0);

    // CSR1 / CGR-24-W: a correction opened by mistake and left untouched is withdrawn with one confirmation; the
    // signed version 2 stays in force and the facts are locked again.
    await shownReport.getByRole("button", { name: "Bericht korrigieren" }).click();
    await shownReport.getByLabel("Begründung der Korrektur").fill("Synthetisch: versehentlich geöffnet");
    await shownReport.getByRole("button", { name: "Neue Fassung anlegen" }).click();
    await expect(shownReport.getByTestId("report-status")).toHaveText("Entwurf (Fassung 3)");
    await shownReport.getByTestId("withdraw-correction").click();
    await shownReport.getByTestId("withdraw-correction-confirm").click();
    await expect(shownReport.getByTestId("report-status")).toHaveText("Bericht abgeschlossen (Fassung 2)");
    await expect(shownReport.getByTestId("command-error")).toHaveCount(0);
    await expect(shownCard.getByTestId("facts-locked")).toContainText("Bericht korrigieren");
  });

  test("a visit without a recorded start cannot get a report (no performer to sign) (F6)", async ({ page }) => {
    await signIn(page, NURSE, /\/field$/);
    await page.goto(`/field?datum=${SEED_DAY}`);
    // Visit 502 was seeded as "started" without a start event, then completed in this file.
    const report = page.getByRole("article", { name: /10:00 – 10:30/ }).getByTestId("visit-report");
    await report.getByRole("button", { name: "Berichtsentwurf erstellen" }).click();
    await expect(report.getByTestId("command-error")).toContainText("kein Start erfasst");
    await expect(report.getByTestId("report-status")).toHaveText("Bericht nicht automatisch erstellt");
  });

  test("a care assistant signs what she sees; the countersignature request reaches a registered nurse of the team (F7)", async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    const DAY_AFTER = zurichDay(2);

    // Visit 509 (18:00, Testfall 08) is run by the seeded care assistant of Testteam Nord.
    await signIn(page, ASSISTANT, /\/field$/);
    await page.goto(`/field?datum=${DAY_AFTER}`);
    const card = page.getByRole("article", { name: /18:00 – 18:30/ });
    await card.getByRole("button", { name: "Losfahren" }).click();
    await card.getByRole("button", { name: "Einsatz starten" }).click();
    const observations = card.getByRole("region", { name: "Beobachtungen" });
    await observations.getByLabel("Neue Beobachtung").fill("Haut am Rücken gerötet, Lagerung angepasst.");
    await observations.getByRole("button", { name: "Beobachtung speichern" }).click();
    await expect(observations).toContainText("Haut am Rücken gerötet");
    await card.getByRole("button", { name: "Einsatz abschliessen" }).click();

    // She sees the observation text she signs, then signs once.
    const review = card.getByTestId("visit-report").getByRole("form", { name: "Bericht prüfen und unterschreiben" });
    await expect(review.getByRole("list", { name: "Beobachtungen im Bericht" })).toContainText("Haut am Rücken gerötet, Lagerung angepasst.");
    await review.getByRole("button", { name: "Bericht unterschreiben" }).click();
    await expect(card.getByTestId("report-status")).toHaveText("Unterschrieben – Gegenzeichnung offen");

    // A registered nurse of the team sees the request at the top of her day and countersigns.
    await page.context().clearCookies();
    await signIn(page, NURSE, /\/field$/);
    const queue = page.getByTestId("countersign-queue");
    await expect(queue).toContainText("Testfall 08");
    await queue.getByRole("link", { name: /Testfall 08/ }).click();
    await page.waitForURL(new RegExp(`datum=${DAY_AFTER}`));
    const report = page.getByRole("article", { name: /18:00 – 18:30/ }).getByTestId("visit-report");
    await report.getByRole("button", { name: "Gegenzeichnen" }).click();
    await expect(report.getByTestId("report-status")).toHaveText("Bericht abgeschlossen");
  });

  test("works on a phone-sized screen without horizontal scrolling", async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 740 });
    await signIn(page, NURSE, /\/field$/);
    await page.goto(`/field?datum=${SEED_DAY}`);
    await expect(page.getByRole("list", { name: "Einsätze" })).toBeVisible();
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
    expect(overflow).toBeLessThanOrEqual(0);
  });

  // ABS1 (migration 0046): "Ich kann nicht arbeiten" at the top of /field in two taps (open, save), no reason field;
  // "Offen im Team" lists a visit of the team with nobody responsible, and one tap takes it. The absence itself is not
  // saved here (it would release seed visits other specs use): the database behaviour is pgTAP 046 and the
  // two-session take check. The open visit is planned here (Testfall 08, three days ahead, 21:00, "Team (noch niemand)").
  test("ABS1: absence is two taps from the top; an open team visit is taken with one tap, at phone width", async ({ page }) => {
    const day = new Date(Date.now() + 3 * 86_400_000).toISOString().slice(0, 10);
    await page.setViewportSize({ width: 390, height: 844 });
    await signIn(page, NURSE, /\/field$/);

    await page.goto("/team");
    const card = page.getByRole("article", { name: /Fall Testfall 08/ });
    await card.getByRole("button", { name: "Einsatz planen" }).click();
    const planForm = card.getByRole("form", { name: "Einsatz planen" });
    await planForm.getByLabel("Datum").fill(day);
    await planForm.getByLabel("Von").fill("21:00");
    await planForm.getByLabel("Bis").fill("21:30");
    await planForm.getByLabel("A", { exact: true }).fill("30");
    await planForm.getByLabel("Verantwortlich").selectOption("");
    await planForm.getByRole("button", { name: "Einsatz speichern" }).click();
    await expect(card.getByRole("list", { name: "Geplante Einsätze" })).toContainText("21:00–21:30");

    await page.goto(`/field?datum=${day}`);
    const absence = page.getByTestId("absence");
    const open = absence.getByTestId("absence-open");
    await expect(open).toBeInViewport();
    await open.click();
    const form = absence.getByRole("form", { name: "Abwesenheit erfassen" });
    await expect(form.getByTestId("absence-save")).toBeVisible();
    await expect(form.getByLabel(/Grund|Begründung|Notiz/)).toHaveCount(0);
    await form.getByRole("button", { name: "Abbrechen" }).click();
    await expect(form).toHaveCount(0);

    const team = page.getByTestId("open-in-team");
    await expect(team.getByRole("heading", { name: /Offen im Team/ })).toBeVisible();
    const visit = team.getByTestId("open-visit").filter({ hasText: "21:00" });
    await visit.getByRole("button", { name: "Übernehmen" }).click();
    await expect(team.getByTestId("open-visit").filter({ hasText: "21:00" })).toHaveCount(0);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
    expect(overflow).toBeLessThanOrEqual(0);
  });

  // CSR1 part 12 / ABS1-C6 (PO 2026-10-23 21:17): "krank seit gestern" from the app. The seed holds assist.test's planned
  // visit yesterday 07:00 (visit 532, never started) and no absence. A colleague records her absence from yesterday on
  // /field (the form offers yesterday, no earlier); the confirmation names the one open past visit with the fixed text
  // and links to /team, where that visit's overdue alert carries the CGR-32 label. The CGR-32 and CGR-34 tests below
  // run on this state (same file, one worker, declared order). The count itself is asserted in pgTAP 054.
  test("ABS1-C6: an absence from yesterday names the open past visit once and links to /team, at phone width", async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await signIn(page, NURSE, /\/field$/);
    const tz = { timeZone: "Europe/Zurich" };
    const today = new Date().toLocaleDateString("sv-SE", tz);
    const yesterday = new Date(Date.now() - 86_400_000).toLocaleDateString("sv-SE", tz);
    await page.goto("/field");
    const absence = page.getByTestId("absence");
    await absence.getByTestId("absence-open").click();
    const form = absence.getByRole("form", { name: "Abwesenheit erfassen" });
    const from = form.locator("input[name=from]");
    await expect(from).toHaveAttribute("min", yesterday);
    await expect(form.locator("input[name=until]")).toHaveAttribute("min", today);
    await form.locator("select[name=who]").selectOption("00000000-0000-4000-a000-000000000101|00000000-0000-4000-a000-000000000906");
    await from.fill(yesterday);
    await form.getByTestId("absence-save").click();
    const notice = absence.getByTestId("absence-past-planned");
    await expect(notice).toHaveCount(1);
    // ABS1-C7: singular at n = 1.
    await expect(notice).toContainText("1 vergangener Einsatz ist noch offen: bitte im Team entscheiden");
    await expect(page.getByText("vergangener Einsatz ist noch offen")).toHaveCount(1);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
    expect(overflow).toBeLessThanOrEqual(0);

    await notice.getByRole("link", { name: "Zum Team" }).click();
    await page.waitForURL(/\/team$/);
    const flagged = page.getByTestId("visit-alert").filter({ has: page.getByTestId("visit-alert-flag") });
    await expect(flagged).toHaveCount(1);
    await expect(flagged).toContainText("07:00");
    await expect(flagged.getByTestId("visit-alert-flag")).toHaveText("Zuständige Person abwesend gemeldet");
  });

  // CSR1 part 11 / CGR-32 (migration 0053): runs after the ABS1-C6 test above, which records assist.test absent from
  // yesterday; her planned visit yesterday 07:00 (visit 532, never started) keeps her as responsible; its overdue alert on
  // /team carries the fixed label once, with no reason. The flag itself is computed in the database (pgTAP 054).
  test("CGR-32: an overdue visit of a member reported absent shows \"Zuständige Person abwesend gemeldet\" once on /team, at phone width", async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await signIn(page, NURSE, /\/field$/);
    await page.goto("/team");
    const alerts = page.getByRole("region", { name: "Einsätze mit Handlungsbedarf" });
    await expect(alerts).toBeVisible();
    const flags = page.getByTestId("visit-alert-flag");
    await expect(flags).toHaveCount(1);
    await expect(flags).toHaveText("Zuständige Person abwesend gemeldet");
    const alert = alerts.getByTestId("visit-alert").filter({ has: flags });
    await expect(alert).toContainText("Einsatz nicht begonnen");
    await expect(alert).toContainText("07:00");
    await expect(alert).toContainText("zuständig:");
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
    expect(overflow).toBeLessThanOrEqual(0);
  });

  // CSR1 part 11 / CGR-34 (migration 0054): runs after the CGR-32 test above (same file, one worker, declared order).
  // The team cancels the flagged visit 532 (yesterday 07:00) with an existing reason; the server stores that its
  // responsible member was reported absent, and the card's cancellation entry shows the fixed text once. The stored
  // fact and the false cases are asserted in pgTAP 055.
  test("CGR-34: cancelling a flagged past visit shows \"nicht durchgeführt: zuständige Person abwesend gemeldet\" once, at phone width", async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await signIn(page, NURSE, /\/field$/);
    const yesterday = new Date(Date.now() - 86_400_000).toLocaleDateString("sv-SE", { timeZone: "Europe/Zurich" });
    await page.goto(`/field?datum=${yesterday}`);
    const visit = page.getByRole("article", { name: /07:00 – 07:30, Testfall 08/ });
    await expect(visit).toHaveCount(1);
    await visit.getByRole("button", { name: "Einsatz absagen" }).click();
    await visit.locator("select[name=code]").selectOption("team_cancelled");
    await visit.getByRole("button", { name: "Absage speichern" }).click();
    const entry = visit.getByTestId("cancel-reason");
    await expect(entry).toContainText("Abgesagt (Abgesagt durch das Team)");
    const fact = visit.getByTestId("cancel-responsible-absent");
    await expect(fact).toHaveCount(1);
    await expect(fact).toHaveText(/^\s*·\s*nicht durchgeführt: zuständige Person abwesend gemeldet\s*$/);
    await expect(visit.getByRole("button", { name: "Einsatz absagen" })).toHaveCount(0);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
    expect(overflow).toBeLessThanOrEqual(0);
  });
});
