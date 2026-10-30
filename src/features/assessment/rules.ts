// ASM1 (migration 0100, ADR-123): the needs assessment as a recorded fact. Pure module (no "use server"), unit-tested in
// tests/unit/asm1-assessment.test.ts. Nothing here computes from the minutes: no sum, total, average, difference,
// per-period conversion, colour or warning (ASM1-11, `cra` CGR-81). Texts only show what was recorded.

export type Category = "A" | "B" | "C";
export const CATEGORIES: readonly Category[] = ["A", "B", "C"] as const;

/** One record as `public.team_case_assessments()` returns it (`records` array). */
export type AssessmentRecord = {
  id: string;
  assessment_date: string;
  instrument_name: string;
  instrument_version: string;
  instrument_third_party_mark: boolean;
  assessor_name: string | null;
  assessor_is_me: boolean;
  state: "confirmed" | "unconfirmed";
  document_ref: string | null;
  minutes_a: number | null;
  period_a: string | null;
  minutes_b: number | null;
  period_b: string | null;
  minutes_c: number | null;
  period_c: string | null;
  supersedes_id: string | null;
  superseded_by: string | null;
  supersede_reason: string | null;
  current: boolean;
  created_at: string;
};

export type NewerEvent = { kind: "resume" | "hospital_stay" | "serious_quality_event" | string; date: string };

/** One row of `public.team_case_assessments()` (one per case of the caller's teams). */
export type CaseAssessments = {
  case_id: string;
  records: AssessmentRecord[];
  current_id: string | null;
  plan_basis_date: string | null;
  plan_without_basis: boolean;
  newer_assessment_date: string | null;
  newer_events: NewerEvent[];
  /** ASM1-C5 (0101, CGR-102): the date of the record the plan rests on, when that record was corrected since. */
  corrected_basis_date: string | null;
  /** ASM1-C5: the entry date of that correction. */
  corrected_on: string | null;
  /** ASM1-C4 (0101): the case's latest review act, per case only. */
  plan_review: PlanReview | null;
};

/** ASM1-C4: "Pflegeplan gegen Bedarfsabklärung vom <Datum> geprüft", as the reader returns the latest act. */
export type PlanReview = {
  record_id: string;
  assessment_date: string;
  state_at_review: AssessmentRecord["state"];
  reviewed_on: string;
  reviewer_name: string | null;
};

/** The instrument entries a member may name (ASM1-6). */
export type Instrument = {
  id: string;
  name: string;
  version: string;
  valid_from: string;
  valid_to: string | null;
  third_party_mark: boolean;
};

/** Care-plan item fields ASM1-11 shows as written (team_cases().care_plan, 0014/0025). */
export type PlanItemAsWritten = {
  id: string;
  service: string;
  category: string;
  minutes: number;
  frequency: string;
  freq_times?: number | null;
  freq_period?: string | null;
};

export const STATE_LABEL: Record<AssessmentRecord["state"], string> = {
  confirmed: "bestätigt",
  unconfirmed: "nicht bestätigt",
};

/** ASM1-11 (4): the dated facts that exist today (ADR-123 lists them); any other kind is shown by its code. */
export const EVENT_LABEL: Record<string, string> = {
  resume: "Wiederaufnahme nach Unterbruch",
  hospital_stay: "Unterbruch wegen Spitalaufenthalt",
  serious_quality_event: "Schwerwiegendes Qualitätsereignis",
};

/** Why the database refused a record or a confirmation (migration 0100). German, shown inline. */
export const ASSESSMENT_REASONS: Record<string, string> = {
  not_team_member: "Nur Mitglieder des zuständigen Teams erfassen eine Bedarfsabklärung.",
  // ASM1-C3 (UXR-54): a refusal states the rule, not a false fact about what she typed.
  date_in_future: "Das Datum der Bedarfsabklärung darf nicht in der Zukunft liegen.",
  instrument_not_valid: "Dieses Instrument ist am Datum der Bedarfsabklärung nicht gültig.",
  assessor_not_rn: "Als abklärende Person kannst du nur eine Pflegefachperson des Teams wählen.",
  reference_invalid:
    "Die Referenz ist eine Kennung aus eurem Abklärungsinstrument: 3 bis 64 Zeichen, Buchstaben, Ziffern und _ : # -, mindestens eine Ziffer, ohne Leerzeichen, Punkt oder Schrägstrich (kein Dateiname, kein Titel).",
  reference_required: "Minuten werden nur mit der Referenz auf die vollständige Abklärung gespeichert.",
  period_required: "Zu jeder Minutenangabe gehört der Zeitraum, wie er in der Abklärung steht (und umgekehrt).",
  minutes_invalid: "Minuten: ganze Zahl von 0 bis 99999; Zeitraum höchstens 60 Zeichen.",
  supersede_not_found: "Die zu ersetzende Abklärung gehört nicht zu diesem Fall.",
  already_superseded: "Diese Abklärung wurde bereits ersetzt. Bitte die aktuelle Fassung ersetzen.",
  reason_required: "Ein Ersatz braucht einen Grund (10 bis 500 Zeichen).",
  not_assessor: "Nur die genannte Pflegefachperson bestätigt diese Abklärung.",
  already_confirmed: "Diese Abklärung ist bereits bestätigt.",
  superseded: "Eine ersetzte Abklärung wird nicht mehr bestätigt.",
};

/** ASM1-C4 (0101): why the database refused the review act. */
export const REVIEW_REASONS: Record<string, string> = {
  not_team_member: "Nur Mitglieder des zuständigen Teams prüfen den Pflegeplan.",
  not_rn: "Den Pflegeplan gegen die Bedarfsabklärung prüft eine Pflegefachperson des Teams.",
  not_current: "Inzwischen gibt es eine andere aktuelle Bedarfsabklärung. Bitte die Seite neu laden.",
  no_items: "Der Pflegeplan hat keine aktive Leistung.",
  nothing_to_review: "Der Pflegeplan ist bereits gegen die aktuelle Bedarfsabklärung geschrieben.",
};

/** ASM1-C3 (UXR-54): the reference rule, shown as hint text under the field before any refusal. */
export const REFERENCE_HINT =
  "Kennung aus eurem Abklärungsinstrument: 3 bis 64 Zeichen, Buchstaben, Ziffern und _ : # -, mindestens eine Ziffer, ohne Leerzeichen, Punkt oder Schrägstrich (kein Dateiname, kein Titel).";

/** ASM1-C1 (UXR-59): the "Zu erledigen" link and the section it jumps to (§5: link name from one constant, plus count). */
export const CONFIRM_TODO_LABEL = "Zu bestätigen: Bedarfsabklärung";
export const confirmTodoLabel = (count: number) => `${CONFIRM_TODO_LABEL} (${count})`;
/** The anchor of one record on /team (the jump target of ASM1-C1). */
export const recordAnchor = (recordId: string) => `bedarfsabklaerung-${recordId}`;

/**
 * ASM1-C1: the records that name her and wait for her confirmation: assessor_is_me, "nicht bestätigt", not superseded
 * (and, once ASM1-C6 is built, not voided). Her own read path only; nothing is counted for anyone else.
 */
export function recordsToConfirm(views: Record<string, CaseAssessments> | CaseAssessments[]): AssessmentRecord[] {
  const list = Array.isArray(views) ? views : Object.values(views);
  return list
    .flatMap((v) => v.records)
    .filter((r) => r.assessor_is_me && r.state === "unconfirmed" && !r.superseded_by)
    .sort((a, b) => a.assessment_date.localeCompare(b.assessment_date) || a.created_at.localeCompare(b.created_at));
}

const REF = /^[A-Za-z0-9][A-Za-z0-9_:#-]{2,63}$/;
/** ASM1-3 (same rule as the database check): an opaque identifier, never a file name, title or free text. */
export function isValidReference(ref: string): boolean {
  return REF.test(ref) && /[0-9]/.test(ref);
}

/** "Testinstrument Bedarf 1.0", with "(Marke Dritter)" when the name is a third party's mark (D-36 A). */
export function instrumentLabel(name: string, version: string, thirdPartyMark: boolean): string {
  return `${name} ${version}${thirdPartyMark ? " (Marke Dritter)" : ""}`;
}

/** Swiss date "30.10.2026" from an ISO date; the input unchanged when it is not one. */
export function formatDate(iso: string | null | undefined): string {
  if (!iso) return "";
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso);
  return m ? `${m[3]}.${m[2]}.${m[1]}` : iso;
}

/** The assessed minutes of one category with their period, as entered ("120 min pro Woche"); null when none. */
export function assessedMinutes(r: AssessmentRecord, c: Category): string | null {
  const key = c.toLowerCase() as "a" | "b" | "c";
  const minutes = r[`minutes_${key}`];
  const period = r[`period_${key}`];
  if (minutes === null || minutes === undefined) return null;
  return `${minutes} min ${period ?? ""}`.trim();
}

/** The line under the assessment: date, instrument, assessor and state (ASM1-10, ASM1-11 (3)). */
export function assessmentLine(r: AssessmentRecord): string {
  const who = r.assessor_name ?? "Pflegefachperson ohne erfassten Namen";
  return `Bedarfsabklärung vom ${formatDate(r.assessment_date)} · ${instrumentLabel(r.instrument_name, r.instrument_version, r.instrument_third_party_mark)} · ${who} · ${STATE_LABEL[r.state]}`;
}

/** ASM1-7: the marker text, or null when the plan rests on the current assessment. */
export function newerAssessmentText(view: Pick<CaseAssessments, "newer_assessment_date"> | null | undefined): string | null {
  return view?.newer_assessment_date ? `Neuere Bedarfsabklärung vom ${formatDate(view.newer_assessment_date)}` : null;
}

/** ASM1-7: which assessment the care plan was written against. */
export function planBasisText(view: Pick<CaseAssessments, "plan_basis_date" | "plan_without_basis"> | null | undefined): string | null {
  if (!view) return null;
  if (view.plan_basis_date && !view.plan_without_basis) return `Geschrieben gegen die Bedarfsabklärung vom ${formatDate(view.plan_basis_date)}`;
  if (view.plan_basis_date && view.plan_without_basis)
    return `Teilweise geschrieben gegen die Bedarfsabklärung vom ${formatDate(view.plan_basis_date)}, teilweise vor jeder erfassten Bedarfsabklärung`;
  if (view.plan_without_basis) return "Geschrieben vor jeder erfassten Bedarfsabklärung";
  return null;
}

/** ASM1-C5 (CGR-102): the record the plan rests on was corrected since; null when not. */
export function correctedBasisText(view: Pick<CaseAssessments, "corrected_basis_date" | "corrected_on"> | null | undefined): string | null {
  if (!view?.corrected_basis_date || !view.corrected_on) return null;
  return `Die Bedarfsabklärung vom ${formatDate(view.corrected_basis_date)}, gegen die der Pflegeplan geschrieben ist, wurde am ${formatDate(view.corrected_on)} korrigiert.`;
}

/** ASM1-C4: the act is offered while the marker, "vor jeder erfassten Bedarfsabklärung" or the ASM1-C5 fact shows. */
export function reviewOffered(view: CaseAssessments | null | undefined): boolean {
  if (!view?.current_id) return false;
  return !!view.newer_assessment_date || view.plan_without_basis || !!view.corrected_basis_date;
}

/** ASM1-C4 (d) (UXR-60): the command's label starts with a verb of confirming and names the current record's date. */
export function reviewLabel(current: Pick<AssessmentRecord, "assessment_date">): string {
  return `Als geprüft bestätigen: Pflegeplan gegen Bedarfsabklärung vom ${formatDate(current.assessment_date)}`;
}

/** ASM1-C4 (d) (3): the confirming step's sentence: the record date and what disappears for the team. */
export function reviewConfirmSentence(current: Pick<AssessmentRecord, "assessment_date">): string {
  return `Pflegeplan gegen die Bedarfsabklärung vom ${formatDate(current.assessment_date)} als geprüft bestätigen? Danach verschwinden für das Team die Hinweise «Neuere Bedarfsabklärung» und «… korrigiert». Die Leistungen bleiben, wie sie sind.`;
}

/** ASM1-C4 (d) (3): the action button inside the confirming step. */
export const REVIEW_CONFIRM_ACTION = "Als geprüft bestätigen";

/** ASM1-C4 / `cra` (a): the latest act in words, with the record's state at the act. */
export function planReviewText(review: PlanReview | null | undefined): string | null {
  if (!review) return null;
  const who = review.reviewer_name ?? "Pflegefachperson ohne erfassten Namen";
  return `Pflegeplan geprüft gegen die Bedarfsabklärung vom ${formatDate(review.assessment_date)} am ${formatDate(review.reviewed_on)} von ${who} (Bedarfsabklärung damals ${STATE_LABEL[review.state_at_review]})`;
}

/** ASM1-11 (4): "Neueres Ereignis seit der Bedarfsabklärung: <Art>, <Datum>". */
export function newerEventText(e: NewerEvent): string {
  return `Neueres Ereignis seit der Bedarfsabklärung: ${EVENT_LABEL[e.kind] ?? e.kind}, ${formatDate(e.date)}`;
}

/** The item as written: service, minutes per occurrence and frequency text, plus PLAN2's structure where recorded. */
export function itemAsWritten(i: PlanItemAsWritten): string {
  const structured =
    typeof i.freq_times === "number" && i.freq_period ? ` (Rhythmus erfasst: ${i.freq_times}× pro ${i.freq_period === "day" ? "Tag" : i.freq_period === "week" ? "Woche" : i.freq_period})` : "";
  return `${i.service} · ${i.minutes} min pro Einsatz · ${i.frequency}${structured}`;
}

/** ASM1-11: per category, the assessed minutes with their period and the plan's items of that category as written. */
export function categoryRows(current: AssessmentRecord | null, items: PlanItemAsWritten[]) {
  return CATEGORIES.map((c) => ({
    category: c,
    assessed: current ? assessedMinutes(current, c) : null,
    items: items.filter((i) => i.category === c).map(itemAsWritten),
  }));
}

/** The current record of a case, or null. */
export function currentRecord(view: CaseAssessments | null | undefined): AssessmentRecord | null {
  if (!view) return null;
  return view.records.find((r) => r.current) ?? null;
}

/** Normalises the reader's rows (jsonb arrays may arrive as unknown). */
export function toCaseAssessments(rows: unknown): Record<string, CaseAssessments> {
  const out: Record<string, CaseAssessments> = {};
  if (!Array.isArray(rows)) return out;
  for (const row of rows) {
    if (typeof row !== "object" || row === null || !("case_id" in row)) continue;
    const r = row as Record<string, unknown>;
    out[String(r.case_id)] = {
      case_id: String(r.case_id),
      records: Array.isArray(r.records) ? (r.records as AssessmentRecord[]) : [],
      current_id: (r.current_id as string | null) ?? null,
      plan_basis_date: (r.plan_basis_date as string | null) ?? null,
      plan_without_basis: r.plan_without_basis === true,
      newer_assessment_date: (r.newer_assessment_date as string | null) ?? null,
      newer_events: Array.isArray(r.newer_events) ? (r.newer_events as NewerEvent[]) : [],
      corrected_basis_date: (r.corrected_basis_date as string | null) ?? null,
      corrected_on: (r.corrected_on as string | null) ?? null,
      plan_review: r.plan_review && typeof r.plan_review === "object" ? (r.plan_review as PlanReview) : null,
    };
  }
  return out;
}
