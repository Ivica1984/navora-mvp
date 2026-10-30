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
  date_in_future: "Das Datum der Bedarfsabklärung liegt nicht in der Zukunft.",
  instrument_not_valid: "Dieses Instrument ist am Datum der Bedarfsabklärung nicht gültig.",
  assessor_not_rn: "Die abklärende Person ist eine Pflegefachperson des Teams.",
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
    };
  }
  return out;
}
