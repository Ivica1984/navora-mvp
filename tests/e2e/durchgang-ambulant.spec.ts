import { expect, test, type Browser, type Page } from "@playwright/test";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
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
//
// Not in this run yet (BD-3: named, not faked; the PR names each break):
//   step 1b ASM1 record — Testorganisation S has no assessment instrument (instruments are per organisation, seed has
//            them for Testorganisation A only); the care plan item is added, the ASM1 record is not.
//   steps 3-4 PLAN3/AIG1 — `plan3_day_proposal` is not switched on for Testorganisation S and S has no administrator who
//            could switch it on through the screen; the care visit is planned to the nurse by hand (`plan_visit`).
//   steps 6-7 dictation and AI draft — PLANNED (B6), «nicht nachgewiesen».
const PASSWORD = "navora-local-only";
const OPS = "opsbs.test@navora.test"; //         org S, operations (J1 intake)
const NURSE = "pflegebs.test@navora.test"; //    org S, registered nurse, Testteam Basel
const OTHER_NURSE = "pflege.test@navora.test"; // org A, nurse of Testteam Nord (negative: no read of org S)
const TEAM_S = "00000000-0000-4000-a000-0000000001b9"; // Testteam Basel (seed, ADR-180)
const F3_REASON = "Testlauf: simulierte Einsatzdauer";
const TITLE = "Durchgang Übergangspflege Basel";
const FIRST = "Bea";
const LAST = "Durchgangtest";

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
  await nurse.getByTestId("tab-bar").getByRole("link", { name: "Heute" }).click();
  await nurse.waitForURL(/\/field/);
  const card = nurse.getByRole("article", { name: new RegExp(`${slot.from} – ${slot.to}, ${FIRST} ${LAST}`) });
  await expect(card, `${label}: the planned visit is in her day`).toContainText("Geplant");
  await noInternalCode(nurse, `/field before ${label}`);
  for (const [button, status] of [
    ["Losfahren", "Unterwegs"],
    ["Einsatz starten", "Gestartet"], // QUAL1-17: the matrix is asked again at start; the qualified nurse is not refused
    ["Einsatz abschliessen", "Abgeschlossen"],
  ] as const) {
    await card.getByRole("button", { name: button }).click();
    await expect(card, `${label}: ${button}`).toContainText(status);
    await expect(card.getByTestId("command-error")).toHaveCount(0);
  }

  // Q-BD-1 option (A): departure first, then start, then (if set) completion, all earlier than recorded, so the order
  // departed < started < completed holds at every save (0040 neighbour check).
  const now = Date.now();
  await card.getByText("Zeiten ansehen und korrigieren").click();
  const timeline = card.getByRole("list", { name: "Zeitverlauf" });
  const steps: [string, number][] = [["Losgefahren", back.departed], ["Gestartet", back.started]];
  if (back.completed !== undefined) steps.push(["Abgeschlossen", back.completed]);
  for (const [event, minutes] of steps) {
    const row = timeline.getByRole("listitem").filter({ hasText: event });
    await row.getByRole("button", { name: "Korrigieren" }).click();
    await row.getByLabel("Richtige Uhrzeit").fill(minutesBack(now, minutes));
    await row.getByLabel("Begründung").fill(F3_REASON);
    await row.getByRole("button", { name: "Korrektur speichern" }).click();
    // B0-3 part 5 (ADR-173): the save's own outcome first (the form closes only on `ok`), then the refreshed row.
    await expect(row.getByLabel("Richtige Uhrzeit"), `${label}: ${event} correction saved`).toHaveCount(0);
    await expect(row).toContainText("korrigiert");
    await expect(row).toContainText(F3_REASON);
  }

  // F6/F7: the draft from the visit data waits at completion; one confirmation signs it (registered nurse: final).
  await nurse.reload();
  const again = nurse.getByRole("article", { name: new RegExp(`${slot.from} – ${slot.to}, ${FIRST} ${LAST}`) });
  const report = again.getByTestId("visit-report");
  const review = report.getByRole("form", { name: "Bericht prüfen und unterschreiben" });
  await expect(review.getByTestId("report-facts")).toContainText("Leistungen");
  await review.getByLabel("Zusammenfassung (optional)").fill(`Synthetischer Bericht (${label}), Durchgang BD.`);
  await review.getByRole("button", { name: "Bericht unterschreiben" }).click();
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
  const ops = await person(browser, OPS, false);
  await ops.getByTestId("shell-sidebar").getByRole("link", { name: "Aufnahme" }).click();
  await ops.waitForURL(/\/intake$/);
  const form = ops.getByRole("form", { name: "Neue Anfrage" });
  await form.getByLabel("Zuweisende Stelle").fill("Testspital Durchgang");
  await form.getByLabel(/^Dringlichkeit/).selectOption("mittel");
  await form.getByLabel("Quelle der Dringlichkeit").selectOption({ label: "vom Zuweiser angegeben" });
  await form.getByLabel("Region").fill("Basel-Stadt");
  await form.getByLabel("Titel").fill(TITLE);
  await form.getByLabel("Bedarf (Zusammenfassung)").fill("Synthetischer Bedarf, Durchgang BD.");
  await form.getByLabel("Leistungen (mit Komma getrennt)").fill("Grundpflege");
  await form.getByRole("button", { name: "Anfrage speichern" }).click();
  const request = ops.getByRole("article", { name: `Anfrage ${TITLE}` });
  await request.getByRole("button", { name: "Prüfen und in Fall überführen" }).click();
  await request.getByLabel("Vorname").fill(FIRST);
  await request.getByLabel("Nachname").fill(LAST);
  await request.getByLabel("Wohngemeinde").fill("Basel");
  await request.getByLabel("Kanton").selectOption("BS");
  await request.getByLabel("Krankenversicherer").fill("Testkasse");
  await request.getByLabel("Versicherungsart").selectOption("KVG");
  // A and C minutes only in this run: no category-B minutes, so no medical order as of the visit date is needed (0051).
  await request.getByLabel("Ärztliche Verordnung").selectOption("present");
  await request.getByLabel("Verordnung gültig bis").fill(zurichDay(Date.now(), 90));
  await request.getByLabel("Gewünschter Beginn").fill(today);
  await request.getByLabel("Erwartete Stunden pro Woche").fill("4");
  await request.getByRole("checkbox").check();
  await request.getByRole("button", { name: "Fall eröffnen" }).click();
  await expect(request, "the referral became a case").toHaveCount(0);
  await noInternalCode(ops, "/intake");
  await ops.context().close();

  // ── Step 1 (J2): the nurse sees the offer first on /field (UXR-155), without the client's name, and takes it. ──────
  const nurse = await person(browser, NURSE, true);
  await nurse.waitForURL(/\/field$/);
  const cue = nurse.getByTestId("todo-links").getByTestId("todo-team-offers");
  await expect(cue, "G-3: what she sees first is the team offer").toHaveText(`${TEAM_OFFERS_HEADING} (1)`);
  await expect(nurse.getByTestId("todo-links")).not.toContainText(LAST);
  await noInternalCode(nurse, "/field (offer)");
  await cue.click();
  await expect(nurse).toHaveURL(/\/team#anfragen$/);
  const offer = nurse.getByRole("article", { name: `Anfrage Teamsuche: ${TITLE}` });
  await expect(offer).toContainText("für Testteam Basel");
  await expect(nurse.getByText(LAST)).toHaveCount(0);
  await offer.getByRole("button", { name: "Fall übernehmen" }).click();
  await expect(offer).toHaveCount(0);

  // ── Step 1b: the first visit is the needs assessment (CR-002 gate `assessment_first`: B and C closed before it). ───
  const teamCase = nurse.getByRole("article", { name: `Fall ${FIRST} ${LAST}` });
  await expect(teamCase).toContainText("Testteam Basel");
  await expect(teamCase).toContainText("Bedarfsabklärung ausstehend");
  await noInternalCode(nurse, "/team (case taken)");
  await teamCase.getByRole("button", { name: "Abklärungsbesuch planen" }).click();
  let plan = teamCase.getByRole("form", { name: "Einsatz planen" });
  await expect(plan.getByLabel("B", { exact: true }), "BD-4: no care visit before the assessment").toBeDisabled();
  await expect(plan.getByLabel("C", { exact: true })).toBeDisabled();
  await plan.getByLabel("Datum").fill(today);
  await plan.getByLabel("Von").fill(assessment.from);
  await plan.getByLabel("Bis").fill(assessment.to);
  await plan.getByLabel("A", { exact: true }).fill(String(ASSESSMENT_MINUTES));
  // Step 2 (QUAL1): the matrix is asked on this assignment (0121 backstop); the registered nurse is not refused.
  await plan.getByRole("button", { name: "Einsatz speichern" }).click();
  await expect(plan, "the assessment visit is saved (no QUAL1 refusal)").toHaveCount(0);
  await expect(teamCase.getByRole("list", { name: "Geplante Einsätze" })).toContainText(`${assessment.from}–${assessment.to}`);

  await runVisit(nurse, assessment, CORRECTION_BACK.assessment, "Abklärungsbesuch");

  // The completed assessment visit opens the gate (0014 trigger): /team now offers «Einsatz planen» with B and C open.
  await nurse.getByTestId("tab-bar").getByRole("link", { name: "Team" }).click();
  await nurse.waitForURL(/\/team/);
  await expect(teamCase).toContainText("Bedarfsabklärung erfolgt");

  // Care plan: one item, category C (synthetic values; no care rule asserted).
  const carePlan = teamCase.getByRole("region", { name: "Pflegeplan" });
  await carePlan.getByRole("button", { name: "Leistung hinzufügen" }).click();
  const item = carePlan.getByRole("form", { name: "Leistung hinzufügen" });
  await item.getByLabel("Leistung", { exact: true }).fill("Grundpflege");
  await item.getByLabel("Kategorie").selectOption("C");
  await item.getByLabel("Minuten pro Einsatz").fill(String(CARE_MINUTES));
  await item.getByLabel("Häufigkeit").fill("1x täglich");
  await item.getByLabel("Überprüfung am").fill(zurichDay(Date.now(), 60));
  await item.getByLabel(/Pflegeziel/).fill("Selbständig waschen am Lavabo");
  await item.getByRole("button", { name: "Leistung speichern" }).click();
  await expect(carePlan).toContainText("Ziel: Selbständig waschen am Lavabo");

  // ── Step 2 + 4 (hand path until PLAN3 runs in org S): the team plans the care visit for the nurse. ────────────────
  await teamCase.getByRole("button", { name: "Einsatz planen" }).click();
  plan = teamCase.getByRole("form", { name: "Einsatz planen" });
  await expect(plan.getByLabel("C", { exact: true })).toBeEnabled();
  await plan.getByLabel("Datum").fill(today);
  await plan.getByLabel("Von").fill(care.from);
  await plan.getByLabel("Bis").fill(care.to);
  await plan.getByLabel("C", { exact: true }).fill(String(CARE_MINUTES));
  await plan.getByRole("button", { name: "Einsatz speichern" }).click();
  await expect(plan, "the care visit is saved (no QUAL1 refusal)").toHaveCount(0);
  await expect(teamCase.getByRole("list", { name: "Geplante Einsätze" })).toContainText(`${care.from}–${care.to}`);
  await noInternalCode(nurse, "/team (planned)");

  // ── Steps 5 and 8: the care visit at 390 px, F3 option (A), report signed. ─────────────────────────────────────────
  await runVisit(nurse, care, CORRECTION_BACK.care, "Pflegeeinsatz");

  // ── Step 9 (J5): the team creates the billing facts with the existing control (UXR-157: the button stays until B8). ─
  await nurse.getByTestId("tab-bar").getByRole("link", { name: "Team" }).click();
  await nurse.waitForURL(/\/team/);
  const preview = nurse.getByRole("region", { name: "Abrechnungsvorschau" });
  await expect(preview.getByTestId("estimate-label")).toContainText("Schätzung – keine Rechnung");
  await preview.getByRole("button", { name: "Abrechnungsfakten erzeugen" }).click();
  await expect(preview.getByRole("status")).toContainText("2 neue Abrechnungsfakten erfasst");
  await noInternalCode(nurse, "/team (billing)");
  await nurse.context().close();

  // ── Stored facts (G-3, BD-2 «the stored fact»), read as the nurse under RLS. ──────────────────────────────────────
  const db = await asPerson(NURSE);
  const { data: visits, error: visitError } = await db
    .from("care_visits")
    .select("id, status, is_needs_assessment, visit_date, time_start")
    .eq("team_id", TEAM_S)
    .eq("visit_date", today)
    .order("time_start");
  expect(visitError).toBeNull();
  expect(visits, "exactly the two visits of the run").toHaveLength(2);
  const [aVisit, cVisit] = visits!;
  expect(aVisit).toMatchObject({ status: "completed", is_needs_assessment: true });
  expect(cVisit).toMatchObject({ status: "completed", is_needs_assessment: false });
  const ids = [aVisit.id, cVisit.id];

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
  await db.auth.signOut();

  // ── Negative (BD brief): a nurse of another organisation reads none of the run's records. ──────────────────────────
  const other = await asPerson(OTHER_NURSE);
  for (const table of ["care_visits", "visit_events", "visit_time_corrections", "visit_reports", "billable_facts"] as const) {
    const column = table === "care_visits" ? "id" : "visit_id";
    const { data, error } = await other.from(table).select(column).in(column, ids);
    expect(error, `${table} as a nurse of another organisation`).toBeNull();
    expect(data, `${table}: no row of the run for a nurse of another organisation`).toEqual([]);
  }
  await other.auth.signOut();
});
