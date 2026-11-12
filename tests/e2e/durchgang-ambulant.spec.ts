import { expect, test, type Browser, type Locator, type Page } from "@playwright/test";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { REFERENCE_NOT_VALIDATED, monthStart } from "@/features/billing/rules";
import { TEAM_OFFERS_HEADING } from "@/features/field/todo";
import {
  ASSESSMENT_MINUTES,
  CARE_MINUTES,
  CORRECTION_BACK,
  INTERNAL_CODE,
  type CorrectionBack,
  durchgangSlots,
  effectiveEventTimes,
  minutesBack,
  sequenceViolations,
  zurichDay,
  type Slot,
} from "./support/durchgang-time";
import { ActLog } from "./support/act-count";

// BD-2 (block BD, brief docs/agents/briefs/BD.md; ADR-181): ONE continuous run of the home-care flow, steps 1 to 9 of
// PRODUCT_BLOCKS.md §5 (ambulant), as far as they are proven to run (BD-3). Synthetic local-only accounts of
// Testorganisation S (supabase/seed.sql, ADR-180: the one simulation organisation, synthetic Basel-Stadt), so the QUAL1
// matrix is asked on every assignment and again at start. The run proves the QUAL1 MECHANISM with the PROPOSED v0.2
// cells, not the cells (CGR-177 (d)); it proves a software path and is no clinical release of the flow (CGR-145/-146).
//
// Rules of the run (BD acceptance, `uxa` G-1 to G-6):
//   G-1 every step is entered by a control on the previous screen or the shell menu; `page.goto` only for /login.
//   G-2 the nurse works at 390 × 844 (her own browser context); Operations at the desktop default.
//   G-3 each hand-over asserts what the next person sees first, and the stored fact (read as that person, RLS applies).
//   G-6 no internal code (D-, CR-, CGR-, SIG-) in any text the run passes.
//   Q-BD-1 option (A): the nurse records each visit's start and departure through «Zeiten ansehen und korrigieren» (F3)
//   with the reason «Testlauf: simulierte Einsatzdauer» before signing; the original visit_events stay unchanged.
//   CGR-180 (1): the corrected times form a possible sequence (the assessment's completion is set back too): the care
//   visit starts after the needs assessment ended, and the nurse's two visits do not overlap (asserted on the stored facts).
//   «Der abrechenbare Hauptpfad nutzt eine Zeitkorrektur (F3) mit dem Grund ‹Testlauf: simulierte Einsatzdauer›.»
//   AUT-88: every human act of the run goes through tap/submit/fill/choose/tick and is counted per step (one sign-in per
//   person; the F3 «Testlauf» corrections tagged test-only). The table is attached to the run and printed to the log;
//   it is a measured baseline, never asserted as a limit.
//
// Steps 1b (ASM1) and 3-4 (PLAN3/AIG1) are in the run since the seed completion of ADR-183 (G-a: the synthetic
// instrument list of Testorganisation S; G-b: `plan3_day_proposal` on for org S, no administrator in the run):
//   step 1b — after the completed assessment visit the registered nurse records the ASM1 assessment naming herself
//            (`record_assessment`, confirmed at once), then writes the care-plan item against it (ASM1-7). ASM1 is
//            display only: the gate `assessment_first` reads the completed assessment VISIT (CGR-175, 0014).
//   steps 3-4 — the care visit is planned «Team (noch niemand)»; a member of Testteam Basel switches the team's day
//            proposal on (PLAN3-10, a team act), asks for today (`propose_day_plan`) and confirms the one line per value
//            (AIG1, `confirm_suggestion`). The proposal is rule-based; no client data to any AI service (D-35 rule A).
// Not in this run (BD-3: named, not faked): steps 6-7 dictation and AI draft — PLANNED (B6), «nicht nachgewiesen».
const PASSWORD = "navora-local-only";
const OPS = "opsbs.test@navora.test"; //         org S, operations (J1 intake)
const NURSE = "pflegebs.test@navora.test"; //    org S, registered nurse, Testteam Basel
const NURSE_ID = "00000000-0000-4000-a000-0000000009e6"; // her user id (seed, ADR-180)
const INSTRUMENT_S = "00000000-0000-4000-a000-000000000974"; // «Testinstrument Bedarf 1.0» of org S (seed, ADR-183 G-a)
const ASM1_REF = "BD-DURCHGANG-1"; // an opaque synthetic reference (ASM1-3: at least one digit, no file name)
const OTHER_NURSE = "pflege.test@navora.test"; // org A, nurse of Testteam Nord (negative: no read of org S)
const TEAM_S = "00000000-0000-4000-a000-0000000001b9"; // Testteam Basel (seed, ADR-180)
const F3_REASON = "Testlauf: simulierte Einsatzdauer";
const TITLE = "Durchgang Übergangspflege Basel";
const FIRST = "Bea";
const LAST = "Durchgangtest";

// AUT-88 act count (support/act-count.ts). «submit» = the saving button of a form with entries; «tap» = any other
// control (menu link, command button, disclosure); «input» = one field filled, chosen or ticked.
const acts = new ActLog();
let testOnlyDepth = 0;
const actOptions = () => ({ testOnly: testOnlyDepth > 0 });
async function tap(target: Locator) {
  acts.act("tap", actOptions());
  await target.click();
}
async function submit(target: Locator) {
  acts.act("submit", actOptions());
  await target.click();
}
async function fill(target: Locator, value: string) {
  acts.act("input", actOptions());
  await target.fill(value);
}
async function choose(target: Locator, value: string | { label: string }) {
  acts.act("input", actOptions());
  await target.selectOption(value);
}
async function tick(target: Locator) {
  acts.act("input", actOptions());
  await target.check();
}

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

async function person(browser: Browser, email: string, phone: boolean): Promise<Page> {
  const context = await browser.newContext(phone ? { viewport: { width: 390, height: 844 } } : {});
  const page = await context.newPage();
  acts.act("sign-in"); // one act; the e-mail and password fields inside it are not counted separately
  await signIn(page, email);
  return page;
}

/**
 * `uxa` G-6: the visible text of the page carries no internal code. A soft assertion: a hit still fails the test, but
 * the run goes on, so one CI run names every G-6 hit and every later break (BD-3) instead of stopping at the first.
 */
async function noInternalCode(page: Page, where: string) {
  const text = await page.locator("body").innerText();
  expect.soft(text.match(INTERNAL_CODE)?.[0] ?? null, `internal code on ${where}`).toBeNull();
}

/** The stored facts, read through the API as the signed-in synthetic person (anon key + her session; RLS applies). */
async function asPerson(email: string): Promise<SupabaseClient> {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_ANON_KEY;
  if (!url || !key) throw new Error("SUPABASE_URL and SUPABASE_ANON_KEY of the local stack are needed for the stored-fact reads");
  const db = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  const { error } = await db.auth.signInWithPassword({ email, password: PASSWORD });
  if (error) throw new Error(`sign-in for the stored-fact read failed: ${error.message}`);
  return db;
}

/** Runs one visit on /field at 390 px: depart, start, complete; then F3 corrections (option (A)); then signs the report. */
async function runVisit(nurse: Page, slot: Slot, back: CorrectionBack, label: string) {
  acts.step(`5 ${label}: unterwegs, Start, Abschluss`);
  await tap(nurse.getByTestId("tab-bar").getByRole("link", { name: "Heute" }));
  await nurse.waitForURL(/\/field/);
  const card = nurse.getByRole("article", { name: new RegExp(`${slot.from} – ${slot.to}, ${FIRST} ${LAST}`) });
  await expect(card, `${label}: the planned visit is in her day`).toContainText("Geplant");
  await noInternalCode(nurse, `/field before ${label}`);
  for (const [button, status] of [
    ["Losfahren", "Unterwegs"],
    ["Einsatz starten", "Gestartet"], // QUAL1-17: the matrix is asked again at start; the qualified nurse is not refused
    ["Einsatz abschliessen", "Abgeschlossen"],
  ] as const) {
    await tap(card.getByRole("button", { name: button }));
    await expect(card, `${label}: ${button}`).toContainText(status);
    await expect(card.getByTestId("command-error")).toHaveCount(0);
  }

  // Q-BD-1 option (A): departure first, then start, then (if set) completion, all earlier than recorded, so the order
  // departed < started < completed holds at every save (0040 neighbour check).
  const now = Date.now();
  acts.step(`5 ${label}: Zeitkorrektur F3 (Testlauf)`);
  testOnlyDepth += 1; // AUT-88: the F3 «Testlauf» corrections exist only because the run cannot wait real minutes
  await tap(card.getByText("Zeiten ansehen und korrigieren"));
  const timeline = card.getByRole("list", { name: "Zeitverlauf" });
  const steps: [string, number][] = [["Losgefahren", back.departed], ["Gestartet", back.started]];
  if (back.completed !== undefined) steps.push(["Abgeschlossen", back.completed]);
  for (const [event, minutes] of steps) {
    const row = timeline.getByRole("listitem").filter({ hasText: event });
    await tap(row.getByRole("button", { name: "Korrigieren" }));
    await fill(row.getByLabel("Richtige Uhrzeit"), minutesBack(now, minutes));
    await fill(row.getByLabel("Begründung"), F3_REASON);
    await submit(row.getByRole("button", { name: "Korrektur speichern" }));
    // B0-3 part 5 (ADR-173): the save's own outcome first (the form closes only on `ok`), then the refreshed row.
    await expect(row.getByLabel("Richtige Uhrzeit"), `${label}: ${event} correction saved`).toHaveCount(0);
    await expect(row).toContainText("korrigiert");
    await expect(row).toContainText(F3_REASON);
  }
  testOnlyDepth -= 1;

  // F6/F7: the draft from the visit data waits at completion; one confirmation signs it (registered nurse: final).
  // The reload is the run waiting for the refreshed card, not a human act (not counted).
  acts.step(`8 ${label}: Bericht unterschreiben`);
  await nurse.reload();
  const again = nurse.getByRole("article", { name: new RegExp(`${slot.from} – ${slot.to}, ${FIRST} ${LAST}`) });
  const report = again.getByTestId("visit-report");
  const review = report.getByRole("form", { name: "Bericht prüfen und unterschreiben" });
  await expect(review.getByTestId("report-facts")).toContainText("Leistungen");
  await fill(review.getByLabel("Zusammenfassung (optional)"), `Synthetischer Bericht (${label}), Durchgang BD.`);
  await submit(review.getByRole("button", { name: "Bericht unterschreiben" }));
  await expect(report.getByTestId("report-status"), `${label}: report final`).toHaveText("Bericht abgeschlossen");
  await expect(report.getByTestId("command-error")).toHaveCount(0);
  await noInternalCode(nurse, `/field after ${label}`);
}

test("BD-2: referral → case → team takes it → assessment visit → care plan → care visit → report → billable fact (Testorganisation S)", async ({ browser }) => {
  test.setTimeout(240_000);
  const slots = durchgangSlots();
  test.skip(slots === null, "too close to midnight in Zurich: the run's visits and corrections must stay on one day (ADR-113)");
  const { assessment, care } = slots!;
  const today = zurichDay();

  // ── Step 1 (J1): Operations records the referral and opens the case; the menu offers «Aufnahme» (G-1). ─────────────
  acts.step("1 Anfrage erfassen und Fall eröffnen (Operations)");
  const ops = await person(browser, OPS, false);
  await tap(ops.getByTestId("shell-sidebar").getByRole("link", { name: "Aufnahme" }));
  await ops.waitForURL(/\/intake$/);
  const form = ops.getByRole("form", { name: "Neue Anfrage" });
  await fill(form.getByLabel("Zuweisende Stelle"), "Testspital Durchgang");
  await choose(form.getByLabel(/^Dringlichkeit/), "mittel");
  await choose(form.getByLabel("Quelle der Dringlichkeit"), { label: "vom Zuweiser angegeben" });
  await fill(form.getByLabel("Region"), "Basel-Stadt");
  await fill(form.getByLabel("Titel"), TITLE);
  await fill(form.getByLabel("Bedarf (Zusammenfassung)"), "Synthetischer Bedarf, Durchgang BD.");
  await fill(form.getByLabel("Leistungen (mit Komma getrennt)"), "Grundpflege");
  await submit(form.getByRole("button", { name: "Anfrage speichern" }));
  const request = ops.getByRole("article", { name: `Anfrage ${TITLE}` });
  await tap(request.getByRole("button", { name: "Prüfen und in Fall überführen" }));
  await fill(request.getByLabel("Vorname"), FIRST);
  await fill(request.getByLabel("Nachname"), LAST);
  await fill(request.getByLabel("Wohngemeinde"), "Basel");
  await choose(request.getByLabel("Kanton"), "BS");
  await fill(request.getByLabel("Krankenversicherer"), "Testkasse");
  await choose(request.getByLabel("Versicherungsart"), "KVG");
  // A and C minutes only in this run: no category-B minutes, so no medical order as of the visit date is needed (0051).
  await choose(request.getByLabel("Ärztliche Verordnung"), "present");
  await fill(request.getByLabel("Verordnung gültig bis"), zurichDay(Date.now(), 90));
  await fill(request.getByLabel("Gewünschter Beginn"), today);
  await fill(request.getByLabel("Erwartete Stunden pro Woche"), "4");
  await tick(request.getByRole("checkbox"));
  await submit(request.getByRole("button", { name: "Fall eröffnen" }));
  await expect(request, "the referral became a case").toHaveCount(0);
  await noInternalCode(ops, "/intake");
  await ops.context().close();

  // BD-7 (a)(ii) (`lca` L-1): while the offer is open, `team_offers()` (0086) gives it to the nurse of Testteam Basel and
  // to nobody of another organisation. Read under RLS through the same RPC the screens use; no human act (AUT-88).
  {
    const own = await asPerson(NURSE);
    const { data: ownOffers, error: ownOfferError } = await own.rpc("team_offers");
    expect(ownOfferError).toBeNull();
    expect(ownOffers!.filter((o) => o.request_title === TITLE).map((o) => o.team_id), "the open offer reaches Testteam Basel")
      .toEqual([TEAM_S]);
    await own.auth.signOut();
    const other = await asPerson(OTHER_NURSE);
    const { data: otherOffers, error: otherOfferError } = await other.rpc("team_offers");
    expect(otherOfferError, "team_offers as a nurse of another organisation").toBeNull();
    expect(otherOffers!.filter((o) => o.request_title === TITLE || o.team_id === TEAM_S),
      "team_offers: no offer of the run for a nurse of another organisation").toEqual([]);
    await other.auth.signOut();
  }

  // ── Step 1 (J2): the nurse sees the offer first on /field (UXR-155), without the client's name, and takes it. ──────
  acts.step("1 Team übernimmt den Fall (Pflege)");
  const nurse = await person(browser, NURSE, true);
  await nurse.waitForURL(/\/field$/);
  const cue = nurse.getByTestId("todo-links").getByTestId("todo-team-offers");
  await expect(cue, "G-3: what she sees first is the team offer").toHaveText(`${TEAM_OFFERS_HEADING} (1)`);
  await expect(nurse.getByTestId("todo-links")).not.toContainText(LAST);
  await noInternalCode(nurse, "/field (offer)");
  await tap(cue);
  await expect(nurse).toHaveURL(/\/team#anfragen$/);
  const offer = nurse.getByRole("article", { name: `Anfrage Teamsuche: ${TITLE}` });
  await expect(offer).toContainText("für Testteam Basel");
  await expect(nurse.getByText(LAST)).toHaveCount(0);
  await tap(offer.getByRole("button", { name: "Fall übernehmen" }));
  await expect(offer).toHaveCount(0);

  // ── Step 1b: the first visit is the needs assessment (CR-002 gate `assessment_first`: B and C closed before it). ───
  acts.step("1b Abklärungsbesuch planen");
  const teamCase = nurse.getByRole("article", { name: `Fall ${FIRST} ${LAST}` });
  await expect(teamCase).toContainText("Testteam Basel");
  await expect(teamCase).toContainText("Bedarfsabklärung ausstehend");
  await noInternalCode(nurse, "/team (case taken)");
  await tap(teamCase.getByRole("button", { name: "Abklärungsbesuch planen" }));
  let plan = teamCase.getByRole("form", { name: "Einsatz planen" });
  await expect(plan.getByLabel("B", { exact: true }), "BD-4: no care visit before the assessment").toBeDisabled();
  await expect(plan.getByLabel("C", { exact: true })).toBeDisabled();
  await fill(plan.getByLabel("Datum"), today);
  await fill(plan.getByLabel("Von"), assessment.from);
  await fill(plan.getByLabel("Bis"), assessment.to);
  await fill(plan.getByLabel("A", { exact: true }), String(ASSESSMENT_MINUTES));
  // Step 2 (QUAL1): the matrix is asked on this assignment (0121 backstop); the registered nurse is not refused.
  await submit(plan.getByRole("button", { name: "Einsatz speichern" }));
  await expect(plan, "the assessment visit is saved (no QUAL1 refusal)").toHaveCount(0);
  await expect(teamCase.getByRole("list", { name: "Geplante Einsätze" })).toContainText(`${assessment.from}–${assessment.to}`);

  await runVisit(nurse, assessment, CORRECTION_BACK.assessment, "Abklärungsbesuch");

  // The completed assessment visit opens the gate (0014 trigger): /team now offers «Einsatz planen» with B and C open.
  acts.step("1b Pflegeplan: Leistung erfassen");
  await tap(nurse.getByTestId("tab-bar").getByRole("link", { name: "Team" }));
  await nurse.waitForURL(/\/team/);
  await expect(teamCase).toContainText("Bedarfsabklärung erfolgt");

  // ASM1 (G-a, ADR-183): the registered nurse records what the instrument says, naming herself as the assessing nurse,
  // so the record is confirmed at once. Synthetic values; ASM1 is display only and blocks or derives nothing (ADR-123).
  acts.step("1b Bedarfsabklärung erfassen (ASM1)");
  const assessmentSection = teamCase.getByRole("region", { name: "Bedarfsabklärung", exact: true });
  await expect(assessmentSection).toContainText("Noch keine Bedarfsabklärung erfasst.");
  await tap(assessmentSection.getByRole("button", { name: "Bedarfsabklärung erfassen" }));
  const asm1 = assessmentSection.getByRole("form", { name: "Bedarfsabklärung erfassen" });
  await fill(asm1.getByLabel("Datum der Abklärung"), today);
  await choose(asm1.getByLabel("Instrument"), INSTRUMENT_S);
  await choose(asm1.getByLabel("Abklärende Pflegefachperson"), NURSE_ID);
  await fill(asm1.getByLabel("Referenz der vollständigen Abklärung"), ASM1_REF);
  await fill(asm1.getByLabel("Minuten C", { exact: true }), String(CARE_MINUTES));
  await fill(asm1.getByLabel("Zeitraum C", { exact: true }), "pro Tag");
  await submit(asm1.getByRole("button", { name: "Bedarfsabklärung speichern" }));
  const currentAssessment = assessmentSection.getByTestId("assessment-current");
  await expect(currentAssessment, "the ASM1 record is saved").toContainText(`Bedarfsabklärung vom ${today.slice(8, 10)}.${today.slice(5, 7)}.${today.slice(0, 4)}`);
  await expect(currentAssessment.getByTestId("assessment-state"), "named herself: confirmed at once").toHaveText("Status: bestätigt");
  await expect(assessmentSection.getByTestId("assessment-error")).toHaveCount(0);
  await noInternalCode(nurse, "/team (assessment)");

  // Care plan: one item, category C (synthetic values; no care rule asserted), written against that record (ASM1-7).
  const carePlan = teamCase.getByRole("region", { name: "Pflegeplan" });
  await tap(carePlan.getByRole("button", { name: "Leistung hinzufügen" }));
  const item = carePlan.getByRole("form", { name: "Leistung hinzufügen" });
  await fill(item.getByLabel("Leistung", { exact: true }), "Grundpflege");
  await choose(item.getByLabel("Kategorie"), "C");
  await fill(item.getByLabel("Minuten pro Einsatz"), String(CARE_MINUTES));
  await fill(item.getByLabel("Häufigkeit"), "1x täglich");
  await fill(item.getByLabel("Überprüfung am"), zurichDay(Date.now(), 60));
  await fill(item.getByLabel(/Pflegeziel/), "Selbständig waschen am Lavabo");
  await submit(item.getByRole("button", { name: "Leistung speichern" }));
  await expect(carePlan).toContainText("Ziel: Selbständig waschen am Lavabo");

  await expect(carePlan.getByTestId("plan-assessment").getByTestId("plan-basis"), "the item is written against the ASM1 record")
    .toContainText("Bedarfsabklärung vom");

  // ── Step 3 (PLAN3): the care visit is planned for the team, nobody responsible yet, so the day proposal covers it. ──
  acts.step("3 Pflegeeinsatz für das Team planen");
  await tap(teamCase.getByRole("button", { name: "Einsatz planen" }));
  plan = teamCase.getByRole("form", { name: "Einsatz planen" });
  await expect(plan.getByLabel("C", { exact: true })).toBeEnabled();
  await fill(plan.getByLabel("Datum"), today);
  await fill(plan.getByLabel("Von"), care.from);
  await fill(plan.getByLabel("Bis"), care.to);
  await fill(plan.getByLabel("C", { exact: true }), String(CARE_MINUTES));
  // The label wraps the picker, so its text includes the options: matched by its start, not exactly.
  await choose(plan.getByLabel(/^Verantwortlich/), { label: "Team (noch niemand)" });
  await submit(plan.getByRole("button", { name: "Einsatz speichern" }));
  await expect(plan, "the care visit is saved").toHaveCount(0);
  const planned = teamCase.getByRole("list", { name: "Geplante Einsätze" });
  await expect(planned).toContainText(`${care.from}–${care.to}`);
  await expect(planned).toContainText("noch niemand verantwortlich");
  await noInternalCode(nurse, "/team (planned for the team)");

  // The team switches its own day proposal on (PLAN3-10; the organisation's switch is on by the seed, ADR-183 G-b) and
  // asks for today. The link «Tagesvorschlag» on /team is the entry (G-1).
  acts.step("3 Tagesvorschlag einschalten und anfordern");
  await tap(nurse.getByRole("link", { name: "Tagesvorschlag", exact: true }));
  await nurse.waitForURL(/\/team\/tagesplan/);
  await expect(nurse.getByTestId("day-plan-switch-state")).toHaveText("Der Tagesvorschlag ist für euer Team ausgeschaltet.");
  await tap(nurse.getByTestId("day-plan-switch"));
  await expect(nurse.getByTestId("day-plan-switch-state")).toContainText("Tagesvorschlag eingeschaltet");
  const ask = nurse.getByRole("form", { name: "Tag vorschlagen" });
  await fill(ask.getByLabel("Tag", { exact: true }), today);
  await submit(ask.getByRole("button", { name: "Tag vorschlagen" }));
  await nurse.waitForURL(new RegExp(`datum=${today}`));
  await expect(nurse.getByTestId("day-plan-error")).toHaveCount(0);

  // ── Step 4 (AIG1): the proposal names the member who knows the client (she performed the assessment visit,
  // PLAN3-3); the team confirms the one value. Nothing is ticked in advance (PLAN3-9).
  acts.step("4 Vorschlag je Wert bestätigen (AIG1)");
  const lines = nurse.getByTestId("day-plan-line");
  await expect(lines, "one open visit of the day: the care visit").toHaveCount(1);
  const mine = nurse.getByRole("region", { name: /^Einsätze .+ \(du\)$/ });
  const line = mine.getByTestId("day-plan-line");
  await expect(line, "G-3: the line is proposed to her").toContainText(care.from);
  await expect(line.getByTestId("day-plan-reason")).toHaveText("kennt Klient:in (1 Besuch)");
  await expect(line.getByTestId("day-plan-tick")).not.toBeChecked();
  await noInternalCode(nurse, "/team/tagesplan (proposal)");
  await tap(line.getByRole("button", { name: "Bestätigen", exact: true }));
  await expect(line.getByTestId("day-plan-decision"), "the value is confirmed").toHaveText("bestätigt");
  await expect(line.getByTestId("day-plan-refusal")).toHaveCount(0);
  await expect(line.getByTestId("day-plan-still-open")).toHaveCount(0);
  await noInternalCode(nurse, "/team/tagesplan (confirmed)");

  // ── Steps 5 and 8: the care visit at 390 px, F3 option (A), report signed. ─────────────────────────────────────────
  await runVisit(nurse, care, CORRECTION_BACK.care, "Pflegeeinsatz");

  // ── Step 9 (J5): the team creates the billing facts with the existing control (UXR-157: the button stays until B8). ─
  acts.step("9 Abrechnungsfakten erzeugen");
  await tap(nurse.getByTestId("tab-bar").getByRole("link", { name: "Team" }));
  await nurse.waitForURL(/\/team/);
  const preview = nurse.getByRole("region", { name: "Abrechnungsvorschau" });
  await expect(preview.getByTestId("estimate-label")).toContainText("Schätzung – keine Rechnung");
  await tap(preview.getByRole("button", { name: "Abrechnungsfakten erzeugen" }));
  await expect(preview.getByRole("status")).toContainText("2 neue Abrechnungsfakten erfasst");
  // BD-7 (b) (`lca` L-2): no seeded rate is validated (0043, CGR-08), so the team's preview says so. If a seed ever marks
  // a rate validated without a D-11 / D-18 decision, this line goes and BD turns red (FE-060: no tariff is proven).
  await expect(preview.getByRole("article", { name: "Vorschau Testteam Basel" }).getByTestId("reference-not-validated"),
    "the reference rates are shown as not validated").toHaveText(REFERENCE_NOT_VALIDATED);
  await noInternalCode(nurse, "/team (billing)");
  await nurse.context().close();

  // AUT-88: the measured act count of this run, attached and logged (a baseline, not asserted).
  const actTable = acts.markdown();
  console.log(actTable);
  await test.info().attach("aut-88-act-count.md", { body: actTable, contentType: "text/markdown" });

  // ── Stored facts (G-3, BD-2 «the stored fact»), read as the nurse under RLS. ──────────────────────────────────────
  const db = await asPerson(NURSE);
  const { data: visits, error: visitError } = await db
    .from("care_visits")
    .select("id, case_id, status, is_needs_assessment, visit_date, time_start, responsible_user_id")
    .eq("team_id", TEAM_S)
    .eq("visit_date", today)
    .order("time_start");
  expect(visitError).toBeNull();
  expect(visits, "exactly the two visits of the run").toHaveLength(2);
  const [aVisit, cVisit] = visits!;
  expect(aVisit).toMatchObject({ status: "completed", is_needs_assessment: true });
  expect(cVisit).toMatchObject({ status: "completed", is_needs_assessment: false });
  const ids = [aVisit.id, cVisit.id];
  expect(cVisit.case_id).toBe(aVisit.case_id);
  const caseId = aVisit.case_id as string;

  // Steps 3-4 (PLAN3/AIG1): the care visit holds the member of the confirmed day-plan line, and the day plan of the team
  // (the same reader the screen uses, as the nurse) has exactly that one line, confirmed, proposing her.
  expect(cVisit.responsible_user_id, "the confirmed value is the visit's responsible member").toBe(NURSE_ID);
  const { data: dayPlan, error: dayPlanError } = await db.rpc("day_plan", { p_team_id: TEAM_S, p_date: today });
  expect(dayPlanError).toBeNull();
  expect(dayPlan, "one day-plan line: the care visit").toHaveLength(1);
  expect(dayPlan![0]).toMatchObject({ visit_id: cVisit.id, member_id: NURSE_ID, reason: "knows_client", decision: "confirmed" });

  // Step 1b (ASM1): one record of the case, the org-S instrument and the synthetic reference; the care-plan item points
  // at it (ASM1-7, set by trigger on insert). She named herself, so the record is confirmed by its own entry
  // (`private.assessment_confirmed`: entered_by = assessor, 0100) and no separate confirmation act exists; the screen
  // showed «Status: bestätigt» above.
  const { data: records, error: recordError } = await db
    .from("assessment_records").select("id, instrument_id, document_ref, minutes_c, assessment_date").eq("case_id", caseId);
  expect(recordError).toBeNull();
  expect(records, "one ASM1 record of the run").toHaveLength(1);
  expect(records![0]).toMatchObject({ instrument_id: INSTRUMENT_S, document_ref: ASM1_REF, minutes_c: CARE_MINUTES, assessment_date: today });
  const { data: confirmations, error: confirmationError } = await db
    .from("assessment_confirmations").select("record_id").eq("record_id", records![0].id);
  expect(confirmationError).toBeNull();
  expect(confirmations, "confirmed by her own entry: no separate confirmation row").toEqual([]);
  const { data: items, error: itemError } = await db.from("care_plan_items").select("id, assessment_id").eq("case_id", caseId);
  expect(itemError).toBeNull();
  expect(items, "one care-plan item of the run").toHaveLength(1);
  expect(items![0].assessment_id, "the item is written against the ASM1 record").toBe(records![0].id);

  // RLS4 (0099): `performer_id`, `signed_by` and the snapshot are not selectable through the table API; status is.
  const { data: reports, error: reportError } = await db.from("visit_reports").select("visit_id, status, version").in("visit_id", ids);
  expect(reportError).toBeNull();
  for (const id of ids) {
    expect(reports!.filter((r) => r.visit_id === id).map((r) => r.status), `final report of ${id}`).toEqual(["final"]);
  }

  // CGR-176 (1): the correction rows carry the reason; the original visit_events times are unchanged. The actor column is
  // not selectable through the table API (RLS3, 0070: acts are not listed per person), so it is not read here; the
  // corrections were saved in the nurse's own session (only members of the visit's team may correct, 0008).
  const { data: corrections, error: correctionError } = await db
    .from("visit_time_corrections").select("id, visit_id, event_id, corrected_at, created_at, reason").in("visit_id", ids);
  expect(correctionError).toBeNull();
  expect(corrections, "three corrections of the assessment, two of the care visit").toHaveLength(5);
  for (const c of corrections!) expect(c).toMatchObject({ reason: F3_REASON });
  const { data: events, error: eventError } = await db
    .from("visit_events").select("id, visit_id, event_type, occurred_at").in("visit_id", ids);
  expect(eventError).toBeNull();
  for (const c of corrections!) {
    const original = events!.find((e) => e.id === c.event_id);
    expect(original, `event ${c.event_id} still there`).toBeTruthy();
    expect(["departed", "started", "completed"]).toContain(original!.event_type);
    expect(Date.parse(original!.occurred_at), "the recorded time is kept, the correction is its own row")
      .toBeGreaterThan(Date.parse(c.corrected_at));
  }

  // CGR-180 (1): in effective time (as private.effective_event_time computes it) the care visit starts at or after the
  // assessment's completion, and the same nurse's two visits do not overlap.
  const span = (visitId: string) => effectiveEventTimes(
    events!.filter((e) => e.visit_id === visitId),
    corrections!.filter((c) => c.visit_id === visitId),
  );
  expect(sequenceViolations(span(aVisit.id), span(cVisit.id)), "the stored times form a possible care sequence").toEqual([]);

  // Step 9: one fact per final report, billable, with an EMPTY reason list (BD-2 amendment 02:39). Warnings are not
  // asserted: they are information, not reasons (e.g. `reference_not_validated`, CGR-08).
  const { data: facts, error: factError } = await db
    .from("billable_facts").select("visit_id, report_id, billable, reasons, order_basis, planned_minutes_a, planned_minutes_c").in("visit_id", ids);
  expect(factError).toBeNull();
  expect(facts).toHaveLength(2);
  for (const f of facts!) expect(f.report_id, `fact of ${f.visit_id} names its final report`).toBeTruthy();
  expect(facts!.find((f) => f.visit_id === aVisit.id)).toMatchObject({ billable: true, reasons: [], planned_minutes_a: ASSESSMENT_MINUTES });
  expect(facts!.find((f) => f.visit_id === cVisit.id)).toMatchObject({ billable: true, reasons: [], planned_minutes_c: CARE_MINUTES });
  // BD-7: the month's preview row of Testteam Basel, read as the nurse (the reader the screen uses), is unvalidated and
  // is the positive side of the negative read below.
  const month = monthStart(today);
  const { data: ownPreview, error: ownPreviewError } = await db.rpc("billing_preview", { p_month: month });
  expect(ownPreviewError).toBeNull();
  expect(ownPreview!.filter((r) => r.team_id === TEAM_S).map((r) => r.reference_validated), "Testteam Basel: one preview row, not validated")
    .toEqual([false]);
  await db.auth.signOut();

  // ── Negative (BD brief): a nurse of another organisation reads none of the run's records. ──────────────────────────
  const other = await asPerson(OTHER_NURSE);
  for (const table of ["care_visits", "visit_events", "visit_time_corrections", "visit_reports", "billable_facts"] as const) {
    const column = table === "care_visits" ? "id" : "visit_id";
    const { data, error } = await other.from(table).select(column).in(column, ids);
    expect(error, `${table} as a nurse of another organisation`).toBeNull();
    expect(data, `${table}: no row of the run for a nurse of another organisation`).toEqual([]);
  }
  for (const table of ["assessment_records", "care_plan_items"] as const) {
    const { data, error } = await other.from(table).select("id").eq("case_id", caseId);
    expect(error, `${table} as a nurse of another organisation`).toBeNull();
    expect(data, `${table}: no row of the run for a nurse of another organisation`).toEqual([]);
  }
  const { data: otherPlan, error: otherPlanError } = await other.rpc("day_plan", { p_team_id: TEAM_S, p_date: today });
  // PLAN3-8: the reader returns only lines of her own teams (0116 `day_plan`), so none of the run reaches her.
  expect(otherPlanError).toBeNull();
  expect(otherPlan, "day_plan: no line for a nurse of another organisation").toEqual([]);
  // BD-7 (a)(i) (`lca` L-1): `billing_preview` (0043) lists only teams in her scope (`is_org_member`), so no Testteam Basel row.
  const { data: otherPreview, error: otherPreviewError } = await other.rpc("billing_preview", { p_month: month });
  expect(otherPreviewError, "billing_preview as a nurse of another organisation").toBeNull();
  expect(otherPreview!.filter((r) => r.team_id === TEAM_S), "billing_preview: no Testteam Basel row for a nurse of another organisation")
    .toEqual([]);
  // BD-7 (a)(iii) (`lca` L-1): the referral and its team search are read only by coordinators of their own organisation
  // (0015 `coordinators_read`); by title and by the run's case, no row reaches her.
  for (const [table, column, value] of [
    ["partner_requests", "request_title", TITLE],
    ["partner_requests", "converted_case_id", caseId],
    ["matching_requests", "request_title", TITLE],
    ["matching_requests", "case_id", caseId],
  ] as const) {
    const { data, error } = await other.from(table).select("id").eq(column, value);
    expect(error, `${table} by ${column} as a nurse of another organisation`).toBeNull();
    expect(data, `${table}: no row of the run for a nurse of another organisation (by ${column})`).toEqual([]);
  }
  await other.auth.signOut();
});
