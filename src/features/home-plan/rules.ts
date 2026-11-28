// HD-1 / HD-2 (migration 0159): pure rules of the home's own staff plan (/heim). No Next or Supabase imports,
// unit-tested (tests/unit/hd1-home-plan.test.ts). The database decides every status (`institution_plan`); this module
// only orders and words it. Fixed rules, no AI.

export const HOME_PLAN_PATH = "/heim";

export type PlanView = "woche" | "monat" | "personal" | "einstellungen" | "auftrag" | "vorschlag";
export const PLAN_VIEWS: ReadonlyArray<{ key: PlanView; label: string }> = [
  { key: "woche", label: "Woche" },
  { key: "monat", label: "Monat" },
  { key: "personal", label: "Mitarbeitende" },
  { key: "einstellungen", label: "Einstellungen" },
];

export type InstitutionRole = "lead" | "planner" | "viewer";
export type Station = { id: string; name: string };
// HD-3a: `shift_class` (0172), `pensum_pct` and `shift_model` (0171) as `institution_plan` returns them; optional so an
// older plan answer still reads.
// HD-3s (0182): a split shift has `shift_class` `split` and the two block fields (block 1 = starts_at..block1_ends_at,
// block 2 = block2_starts_at..ends_at); NULL for a shift with one block.
export type ShiftType = {
  id: string; code: string; label: string; starts_at: string; ends_at: string; shift_class?: string | null;
  block1_ends_at?: string | null; block2_starts_at?: string | null;
};
export type Staff = {
  id: string; display_name: string; grade: string; home_station_id: string | null; active: boolean;
  pensum_pct?: number | null; shift_model?: string | null;
};
export type Absence = { id: string; staff_id: string; starts_on: string; ends_on: string };
/**
 * One assigned person in a cell, as `institution_plan` returns it. `absent`: an absence day touches the shift (also the
 * night into an absence day, HD-1 R3). `inactive`: the person is no longer active; she stays listed but never counts as
 * present (HD-1 R1). The database decides both; this module only words them.
 */
export type AssignedPerson = {
  assignment_id: string;
  staff_id: string;
  display_name: string;
  grade: string;
  absent: boolean;
  inactive: boolean;
  /** HD-3a Q3 (migration 0173): the planning rules this shift breaks now (`private.institution_rule_breaches`). */
  rules?: PlanningRule[];
  /** HD-3a Q3: the rules a person confirmed by hand when the shift was saved (warning, not a block), or null. */
  override_rules?: PlanningRule[] | null;
};
export type CellStatus = "ok" | "gap" | "no_rule";
/**
 * HD-2 (migration 0162): the active external order of a cell. `state` is the home's draft state; `cover_state` and
 * `cover_detail` are the order's cover as /order reads it (`private.order_client_state`, one source). Only
 * `cover_state === "covered"` fills a slot (`external_covered`); the database decides that, this module only words it.
 */
export type CellOrder = {
  gap_order_id: string;
  state: "prepared" | "sent";
  order_id: string | null;
  grade: string | null;
  grade_fixed: boolean;
  starts_at: string | null;
  cover_state: string | null;
  cover_detail: string | null;
  latest_cover_at: string | null;
};
export type PlanCell = {
  date: string;
  station_id: string;
  shift_type_id: string;
  required_total: number | null;
  required_grade: string | null;
  required_grade_count: number;
  example: boolean;
  assigned: AssignedPerson[];
  present: number;
  grade_present: number;
  missing: number;
  status: CellStatus;
  /** HD-2: persons of an external order that are confirmed and checked (G); 0 or 1. */
  external_covered?: number;
  /** HD-2: the active external order of this cell, or null. */
  order?: CellOrder | null;
};
export type Plan = {
  institution: {
    id: string;
    display_name: string;
    simulation: boolean;
    role: InstitutionRole;
    /** HD-2: the home's postcode for its orders (set by the home), and whether this person may send orders. */
    order_postcode?: string | null;
    can_order?: boolean;
    /** HD-3a (0171, 0172): the home's planning limits; NULL = not entered. */
    min_rest_hours?: number | null;
    max_consecutive_days?: number | null;
    weekly_target_hours?: number | null;
    /** HD-3s S5 (0182): «Arbeitstage pro Woche», default 5; the daily target is a hint only. */
    work_days_per_week?: number | null;
    /** HD-3a-F3 (0189): «Abweichungsschwelle (Stunden)»; NULL = every deviation is shown. */
    monthly_target_deviation_hours?: number | null;
  };
  from: string;
  to: string;
  stations: Station[];
  shift_types: ShiftType[];
  staff: Staff[];
  absences: Absence[];
  cells: PlanCell[];
  /** HD-3a-F3 (0189): per person and calendar month of the range; absent in an older answer (T-1: database numbers). */
  month_targets?: MonthTarget[];
};
/** One `month_targets` entry of `institution_plan` (minutes; NULL where the database has no value). */
export type MonthTarget = {
  staff_id: string;
  month: string;
  target_minutes: number | null;
  planned_minutes: number;
  remaining_minutes: number | null;
  comparison_minutes: number | null;
  deviates: boolean | null;
};
/** The entry of one person for the month of `date` (the plan's own read), or null. */
export function monthTargetOf(plan: Pick<Plan, "month_targets">, staffId: string, date: string): MonthTarget | null {
  const month = `${date.slice(0, 7)}-01`;
  return (plan.month_targets ?? []).find((m) => m.staff_id === staffId && m.month === month) ?? null;
}

export const GRADE_LABEL: Record<string, string> = { ags_eba: "AGS", fage_efz: "FaGe", nurse_hf_fh: "HF" };
export const GRADE_CHOICES = [
  { value: "nurse_hf_fh", label: "HF" },
  { value: "fage_efz", label: "FaGe" },
  { value: "ags_eba", label: "AGS" },
] as const;

export const gradeLabel = (code: string | null): string => (code ? (GRADE_LABEL[code] ?? code) : "");

/**
 * HD-3a (FE-119, FE-120; migration 0171): the four neutral absence kinds. The database refuses every other value; there
 * is no sickness kind and no reason field (no health data). Fixed list, no AI.
 */
export const ABSENCE_KINDS = ["vacation", "training", "compensation", "absent"] as const;
export type AbsenceKind = (typeof ABSENCE_KINDS)[number];
const ABSENCE_KIND_LABEL: Record<AbsenceKind, string> = {
  vacation: "Ferien",
  training: "Weiterbildung",
  compensation: "Kompensation",
  absent: "Abwesend",
};
export const absenceKindLabel = (kind: AbsenceKind): string => ABSENCE_KIND_LABEL[kind];

export const canPlan = (role: InstitutionRole): boolean => role === "lead" || role === "planner";
export const canSettle = (role: InstitutionRole): boolean => role === "lead";

/** Shown wherever the plan is edited: the database checks no working-time law (ArG), only absence and overlap. */
// HD-3a Q3: rest time, days in a row, Pensum and shift model are checked on every hand assignment (warning, not a
// block); the values are the home's, rest and days in a row are founder parameters not checked against the law.
export const WORKING_TIME_NOTE =
  "Beim Einteilen prüft NAVORA Schichtmodell, Ruhezeit, Arbeitstage in Folge und Pensum nach den Werten des Heims " +
  "(Arbeitszeitgesetz nicht abschliessend geprüft). Ein Verstoss ist eine Warnung; Abwesenheit und Doppelbelegung sind gesperrt.";

/**
 * HD-3a Q3: the planning rules a shift can break, in the database's fixed order. HD-3a-F3 (FE-135 option A, migration
 * 0189): `month_target_full` replaces `pensum_full` for a person with a monthly target in the shift's month (never both).
 * HD-PEN-HAND (ENG-PH1, migration 0190): `hours_unknown` when neither applies (no monthly target for the month and no
 * Pensum or no Wochensoll): the hours cannot be checked, a warning to confirm or cancel. Exactly one of the three.
 */
export const PLANNING_RULES = ["shift_model", "rest", "consecutive", "pensum_full", "month_target_full", "hours_unknown"] as const;
export type PlanningRule = (typeof PLANNING_RULES)[number];
const RULE_TEXT: Record<PlanningRule, string> = {
  shift_model: "Schichtmodell der Person passt nicht zu dieser Dienstart",
  rest: "Ruhezeit zu kurz",
  consecutive: "zu viele Arbeitstage in Folge",
  pensum_full: "über dem Pensum dieser Woche",
  month_target_full: "über dem Monatssoll dieses Monats",
  // HD-PEN-HAND-F1 UXR-317: the rule is a label only; which value is missing is said once, by `hoursUnknownNext` (the
  // reason in the warning box), so the stored-shift mark reads «Regel: Stunden nicht prüfbar» with one colon. Wording
  // placeholder until the `cra` gate.
  hours_unknown: "Stunden nicht prüfbar",
};
export const ruleText = (r: PlanningRule): string => RULE_TEXT[r];
export function isPlanningRule(v: unknown): v is PlanningRule {
  return typeof v === "string" && (PLANNING_RULES as ReadonlyArray<string>).includes(v);
}
/** A comma list from a form or URL to known rules only (unknown words are dropped, order as in the database). */
export function parseRules(v: unknown): PlanningRule[] {
  if (typeof v !== "string") return [];
  const words = new Set(v.split(","));
  return PLANNING_RULES.filter((r) => words.has(r));
}
/** The warning line of a stored shift: the rules it breaks now; «bestätigt» when every one was confirmed by hand. */
export function ruleWarning(a: Pick<AssignedPerson, "rules" | "override_rules">): string | null {
  const now = a.rules ?? [];
  if (now.length === 0) return null;
  const confirmed = new Set(a.override_rules ?? []);
  const all = now.every((r) => confirmed.has(r));
  return `Regel: ${now.map(ruleText).join(", ")}${all ? " (von Hand bestätigt)" : ""}`;
}
/**
 * HD-PEN-HAND (ADR-232 point 5): the plan answer is cast from JSON, so a rule code this app does not know (a newer
 * migration before the app deploy) would render as «undefined». Keeps only known codes on every assigned person;
 * returns a new plan, the input is not changed.
 */
export function withKnownRules(plan: Plan): Plan {
  const known = (v: unknown): PlanningRule[] => (Array.isArray(v) ? v.filter(isPlanningRule) : []);
  return {
    ...plan,
    cells: (plan.cells ?? []).map((c) => ({
      ...c,
      assigned: (c.assigned ?? []).map((a) => ({
        ...a,
        rules: known(a.rules),
        override_rules: a.override_rules == null ? null : known(a.override_rules),
      })),
    })),
  };
}
export const EXAMPLE_NOTE = "Beispielwert des Heims (synthetisch), keine Vorgabe von NAVORA.";

// --- Dates (calendar dates as YYYY-MM-DD; no time zone involved) ------------------------------------------------------
const ISO = /^\d{4}-\d{2}-\d{2}$/;

export function isIsoDate(s: unknown): s is string {
  if (typeof s !== "string" || !ISO.test(s)) return false;
  const d = new Date(`${s}T00:00:00Z`);
  return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === s;
}

export function addDays(date: string, n: number): string {
  const d = new Date(`${date}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

/** Monday of the ISO week of `date`. */
export function weekStart(date: string): string {
  const day = new Date(`${date}T00:00:00Z`).getUTCDay(); // 0 = Sunday
  return addDays(date, -((day + 6) % 7));
}

export function monthStart(date: string): string {
  return `${date.slice(0, 7)}-01`;
}

export function monthEnd(date: string): string {
  const [y, m] = date.slice(0, 7).split("-").map(Number);
  return new Date(Date.UTC(y, m, 0)).toISOString().slice(0, 10);
}

export function daysBetween(from: string, to: string): string[] {
  const out: string[] = [];
  for (let d = from; d <= to; d = addDays(d, 1)) out.push(d);
  return out;
}

/** The date range a view reads (the month is at most 31 days; the database refuses more than 42). */
export function rangeFor(view: PlanView, date: string): { from: string; to: string } {
  if (view === "woche" || view === "einstellungen" || view === "auftrag" || view === "vorschlag") {
    const from = weekStart(date);
    return { from, to: addDays(from, 6) };
  }
  return { from: monthStart(date), to: monthEnd(date) };
}

/** The ISO week number (for «KW 48»). */
export function isoWeek(date: string): number {
  const d = new Date(`${date}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7)); // the Thursday of the same ISO week
  const yearStart = Date.UTC(d.getUTCFullYear(), 0, 1);
  return Math.ceil(((d.getTime() - yearStart) / 86_400_000 + 1) / 7);
}

const WEEKDAY = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"];
const MONTH = ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"];

export function dayLabel(date: string): string {
  const d = new Date(`${date}T00:00:00Z`);
  return `${WEEKDAY[d.getUTCDay()]} ${d.getUTCDate()}.${d.getUTCMonth() + 1}.`;
}

export function weekdayShort(date: string): string {
  return WEEKDAY[new Date(`${date}T00:00:00Z`).getUTCDay()];
}

export function monthLabel(date: string): string {
  return `${MONTH[Number(date.slice(5, 7)) - 1]} ${date.slice(0, 4)}`;
}

export function isWeekend(date: string): boolean {
  const day = new Date(`${date}T00:00:00Z`).getUTCDay();
  return day === 0 || day === 6;
}

// --- Plan reading ---------------------------------------------------------------------------------------------------
export function cellKey(date: string, stationId: string, shiftTypeId: string): string {
  return `${date}|${stationId}|${shiftTypeId}`;
}

export function indexCells(cells: ReadonlyArray<PlanCell>): Map<string, PlanCell> {
  return new Map(cells.map((c) => [cellKey(c.date, c.station_id, c.shift_type_id), c]));
}

/** One short line for a cell: what is planned against what the home requires. */
export function cellStatusText(cell: PlanCell): string {
  if (cell.status === "no_rule") return cell.present === 0 ? "keine Vorgabe" : `${cell.present} eingeteilt · keine Vorgabe`;
  const ext = cell.external_covered ?? 0;
  const base = ext > 0 ? `${cell.present} + ${ext} extern von ${cell.required_total}` : `${cell.present} von ${cell.required_total}`;
  if (cell.status === "ok") return `${base} · besetzt`;
  const parts: string[] = [];
  if (cell.missing > 0) parts.push(`${cell.missing} fehlt`);
  // HD-2 slice 6: like `ext_grade` in `institution_plan`, a covered order of the required grade counts for the grade.
  const extGrade = ext > 0 && cell.order?.cover_state === "covered" && cell.order.grade === cell.required_grade ? 1 : 0;
  if (cell.required_grade && cell.grade_present + extGrade < cell.required_grade_count) {
    const lack = cell.required_grade_count - cell.grade_present - extGrade;
    parts.push(`${lack} ${gradeLabel(cell.required_grade)} fehlt`);
  }
  return `${base} · Lücke: ${parts.join(", ")}`;
}

// --- HD-2: the external order of a cell in the home's words (brief HD.md §3, §3a) ----------------------------------
export type OrderTone = "draft" | "wait" | "ok" | "alert";
export type OrderLine = { code: "E" | "A" | "T" | "G" | "K" | "N"; headline: string; detail: string | null; tone: OrderTone; next: string | null };

/** Next action of the home where the order does not cover the shift (K, N): HD.md §3 «intern besetzen oder zurückziehen». */
export const NEXT_INTERNAL = "Nächste Handlung: eine zulässige eigene Person einteilen oder den Auftrag zurückziehen.";

/**
 * The words of §3 for one cell order. Never «Gedeckt» unless the database read `covered`; «Angebot läuft wieder» only
 * for `no_longer_covered` without detail (a real release with an open offer, FE-110 (b), migration 0161).
 */
export function orderLine(o: CellOrder): OrderLine {
  if (o.state === "prepared") {
    return { code: "E", headline: "Auftrag vorbereitet, nicht gesendet", detail: "Prüfen und senden oder verwerfen.", tone: "draft", next: null };
  }
  const level = o.grade ? gradeLabel(o.grade) : null;
  switch (o.cover_state) {
    case "covered":
      return { code: "G", headline: level ? `Gedeckt · Person bestätigt, geprüft für ${level}` : "Gedeckt · Person bestätigt, geprüft", detail: null, tone: "ok", next: null };
    case "not_covered": {
      const detail =
        o.cover_detail === "started" ? "Die Schicht hat begonnen." :
        o.cover_detail === "cover_time_reached" ? "Bis jetzt hat kein Team diese Schicht übernommen." :
        "Kein passendes Team ist frei.";
      return { code: "K", headline: "Nicht gedeckt", detail, tone: "alert", next: NEXT_INTERNAL };
    }
    case "no_longer_covered":
      return o.cover_detail === "no_offer_open"
        ? { code: "N", headline: "Nicht mehr gedeckt · kein Angebot offen", detail: "Die Übernahme gilt nicht mehr.", tone: "alert", next: NEXT_INTERNAL }
        : { code: "N", headline: "Nicht mehr gedeckt · Angebot läuft wieder", detail: "Die Übernahme gilt nicht mehr. Das Angebot geht wieder an alle passenden Teams.", tone: "alert", next: NEXT_INTERNAL };
    default:
      if (o.cover_detail === "awaiting_acknowledgement") {
        return { code: "T", headline: "Team hat übernommen · Person bestätigt noch", detail: "Zählt noch nicht als besetzt.", tone: "wait", next: null };
      }
      if (o.cover_detail === "take_fell_away_no_offer") {
        return { code: "A", headline: "Noch nicht gedeckt · kein Angebot offen", detail: "Die eingeteilte Person kann nicht.", tone: "alert", next: NEXT_INTERNAL };
      }
      if (o.cover_detail === "take_fell_away") {
        return { code: "A", headline: "Angebot versandt · noch nicht gedeckt", detail: "Die eingeteilte Person kann nicht. Das Angebot geht wieder an alle passenden Teams.", tone: "wait", next: null };
      }
      return { code: "A", headline: "Angebot versandt · noch nicht gedeckt", detail: "An alle passenden Teams gleichzeitig.", tone: "wait", next: null };
  }
}

/**
 * HD-2 slice 5: «Auftrag zurückziehen» for a sent order in A, K or N (HD.md §3), to a planner who may order. Never for
 * G (a confirmed person) or T (a take awaiting confirmation); the database refuses those as well, and after the start.
 */
export function canWithdrawOrder(plan: Pick<Plan, "institution">, order: CellOrder): boolean {
  if (!canPlan(plan.institution.role) || plan.institution.can_order !== true || order.state !== "sent") return false;
  const code = orderLine(order).code;
  return code === "A" || code === "K" || code === "N";
}

/** «Externen Auftrag vorbereiten» is offered on a gap without an active order, to a planner whose access may order. */
export function canPrepareOrder(plan: Pick<Plan, "institution">, cell: PlanCell): boolean {
  return canPlan(plan.institution.role) && plan.institution.can_order === true && cell.status === "gap" && !cell.order;
}

/** The requirement in words, e.g. «Vorgabe 3, davon 1 HF». */
export function requirementText(cell: Pick<PlanCell, "required_total" | "required_grade" | "required_grade_count">): string {
  if (cell.required_total === null) return "keine Vorgabe";
  return cell.required_grade
    ? `Vorgabe ${cell.required_total}, davon ${cell.required_grade_count} ${gradeLabel(cell.required_grade)}`
    : `Vorgabe ${cell.required_total}`;
}

export function isAbsent(absences: ReadonlyArray<Absence>, staffId: string, date: string): boolean {
  return absences.some((a) => a.staff_id === staffId && a.starts_on <= date && date <= a.ends_on);
}

/**
 * Who can still be assigned to a cell: active, not absent that day and not already in any shift that day. The
 * database checks again (absence, double booking, overlap across midnight); this only keeps the list short.
 */
export function assignableStaff(plan: Plan, date: string): Staff[] {
  const busy = new Set(plan.cells.filter((c) => c.date === date).flatMap((c) => c.assigned.map((a) => a.staff_id)));
  return plan.staff.filter((s) => s.active && !busy.has(s.id) && !isAbsent(plan.absences, s.id, date));
}

export type PersonDay = {
  date: string;
  /** The calendar day itself is an absence day. */
  absent: boolean;
  /** One entry per shift starting on this day (a night across midnight appears on its start day only). */
  shifts: {
    assignment_id: string;
    code: string;
    label: string;
    time: string;
    station: string;
    /** From the cell: the shift touches an absence day (also the night into one) or the person is inactive. */
    counts: boolean;
    /** HD-3a Q3: the rule warning of this shift (same text as the week), or null. */
    warning: string | null;
  }[];
};

/** The plan of one staff member (her days in the range), from the same cells as the week. */
export function personPlan(plan: Plan, staffId: string): PersonDay[] {
  const shift = new Map(plan.shift_types.map((t) => [t.id, t]));
  const station = new Map(plan.stations.map((s) => [s.id, s.name]));
  return daysBetween(plan.from, plan.to).map((date) => ({
    date,
    absent: isAbsent(plan.absences, staffId, date),
    shifts: plan.cells
      .filter((c) => c.date === date && c.assigned.some((a) => a.staff_id === staffId))
      .map((c) => {
        const t = shift.get(c.shift_type_id);
        const a = c.assigned.find((x) => x.staff_id === staffId)!;
        return {
          assignment_id: a.assignment_id,
          code: t?.code ?? "?",
          label: t?.label ?? "",
          time: t ? `${t.starts_at}–${t.ends_at}` : "",
          station: station.get(c.station_id) ?? "",
          counts: !a.absent && !a.inactive,
          warning: ruleWarning(a),
        };
      }),
  }));
}

/**
 * The month grid cell of one person on one day: shift codes, «A» when absent, empty when free. A shift that does not
 * count (the night into an absence day, or a person no longer active) is shown in brackets: it is planned, not staffed.
 */
export function monthCode(day: PersonDay): string {
  // HD-3a Q3: «!» marks a shift with a rule warning (the week and the personal plan name the rule).
  const codes = day.shifts
    .map((s) => `${s.counts || day.absent ? s.code : `(${s.code})`}${s.warning ? "!" : ""}`)
    .join("/");
  if (day.absent) return codes ? `A (${codes})` : "A";
  return codes;
}

/**
 * The persons of the month grid: every active person, and an inactive person as long as she is still assigned in the
 * range (HD-1 R1: her shifts stay visible as gaps until the home re-plans them).
 */
export function monthPeople(plan: Plan): Staff[] {
  const assigned = new Set(plan.cells.flatMap((c) => c.assigned.map((a) => a.staff_id)));
  return plan.staff.filter((s) => s.active || assigned.has(s.id));
}

/** Number of gap cells per day (for the month overview). */
export function gapsPerDay(plan: Plan): Map<string, number> {
  const out = new Map<string, number>();
  for (const c of plan.cells) if (c.status === "gap") out.set(c.date, (out.get(c.date) ?? 0) + 1);
  return out;
}

/** HD-2: the external orders of each day as their state letters (E, A, T, G, K, N), for the month view. */
export function ordersPerDay(plan: Plan): Map<string, string[]> {
  const out = new Map<string, string[]>();
  for (const c of plan.cells) if (c.order) out.set(c.date, [...(out.get(c.date) ?? []), orderLine(c.order).code]);
  return out;
}

/** HD-2: the cell of a draft (review screen), found through the one plan read. */
export function cellOfDraft(plan: Plan, gapOrderId: string | undefined): PlanCell | null {
  if (!gapOrderId) return null;
  return plan.cells.find((c) => c.order?.gap_order_id === gapOrderId) ?? null;
}

/** HD-2: activity codes from a query value «A1,A2» (only the known code shape; the database checks them again). */
export function tagList(v: unknown): string[] {
  if (typeof v !== "string") return [];
  return [...new Set(v.split(",").map((t) => t.trim()).filter((t) => /^[A-Z][A-Z0-9]{0,5}$/.test(t)))];
}

/**
 * UXR-269: what the review screen shows (boxes) and what the last «Prüfen» checked (snapshot) of one gap order.
 * «Senden» sends only when both are the same; otherwise nothing is sent and the screen checks again. Tags compare as
 * a set (order and repeats do not matter). The database checks every hard rule again on what it receives.
 */
export type OrderChoice = { postcode: string | null; grade: string | null; tags: string[] };

export function sameOrderChoice(shown: OrderChoice, checked: OrderChoice): boolean {
  if ((shown.postcode ?? null) !== (checked.postcode ?? null)) return false;
  if ((shown.grade ?? null) !== (checked.grade ?? null)) return false;
  const a = [...new Set(shown.tags)].sort();
  const b = [...new Set(checked.tags)].sort();
  return a.length === b.length && a.every((t, i) => t === b[i]);
}

/**
 * UXR-269: the line next to «Senden», built from the same checked values that are sent: grade, day and time, postcode
 * and place, every activity by code and name (a code without a name stays as its code).
 */
export function orderSendSummary(p: {
  grade: string; day: string; time: string; postcode: string; place: string | null;
  tags: string[]; activities: ReadonlyArray<{ code: string; label_de: string }>;
}): string {
  const names = new Map(p.activities.map((a) => [a.code, a.label_de]));
  const acts = p.tags.map((t) => (names.has(t) ? `${t} · ${names.get(t)}` : t)).join(", ");
  return `Wird gesendet: ${gradeLabel(p.grade)} · ${p.day} ${p.time} · ${p.postcode}${p.place ? ` ${p.place}` : ""} · Tätigkeiten: ${acts}`;
}

export function countMinutes(t: ShiftType): number {
  const [sh, sm] = t.starts_at.split(":").map(Number);
  const [eh, em] = t.ends_at.split(":").map(Number);
  const start = sh * 60 + sm;
  const end = eh * 60 + em;
  return end > start ? end - start : 24 * 60 - start + end;
}

/** Planned hours of a person in the range that count (not absent, active; shift length as entered, breaks not deducted). */
export function plannedHours(plan: Plan, staffId: string): number {
  const minutes = new Map(plan.shift_types.map((t) => [t.id, countMinutes(t)]));
  let total = 0;
  for (const c of plan.cells) {
    if (c.assigned.some((a) => a.staff_id === staffId && !a.absent && !a.inactive)) total += minutes.get(c.shift_type_id) ?? 0;
  }
  return Math.round((total / 60) * 10) / 10;
}

// --- Messages of the commands ---------------------------------------------------------------------------------------
const PROBLEM_TEXT: Record<string, string> = {
  rejected: "Dafür fehlt Ihnen das Recht in diesem Heim.",
  not_found: "Nicht gefunden. Bitte die Seite neu laden.",
  staff_inactive: "Diese Person ist nicht mehr aktiv.",
  already_assigned: "Diese Person ist in diesem Dienst bereits eingeteilt.",
  staff_absent: "Diese Person ist in diesem Dienst abwesend (auch eine Nacht in einen Abwesenheitstag zählt).",
  staff_overlap: "Diese Person hat zur gleichen Zeit schon einen anderen Dienst.",
  shift_type_in_use:
    "Diese Dienstart ist im Plan eingeteilt; ihre Zeiten bleiben unverändert. Für andere Zeiten bitte eine neue Dienstart anlegen.",
  dates_not_valid: "Bitte gültige Daten angeben (bis höchstens ein Jahr).",
  absence_overlaps: "Für diese Tage ist schon eine Abwesenheit erfasst.",
  kind_not_valid: "Bitte eine Art der Abwesenheit wählen: Ferien, Weiterbildung, Kompensation oder Abwesend.",
  input_not_valid: "Bitte die Angaben prüfen.",
  // HD-3a slice 4: «Entwurf übernehmen» refused as a whole (migrations 0175, 0177); nothing was saved.
  rows_not_valid: "Der Vorschlag war nicht lesbar. Es wurde nichts übernommen. Bitte neu vorschlagen.",
  duplicate_row: "Der Vorschlag enthielt einen Dienst doppelt. Es wurde nichts übernommen. Bitte neu vorschlagen.",
  period_too_long: "Ein Vorschlag umfasst höchstens einen Monat. Es wurde nichts übernommen.",
  apply_id_used: "Dieser Vorschlag gehört zu einem anderen Heim. Es wurde nichts übernommen. Bitte neu vorschlagen.",
  // HD-3a-F1 R-6-1 (migration 0186): without the home's weekly target the database cannot check the weekly hours (R-h).
  weekly_target_missing:
    "Nicht übernommen: Für dieses Heim ist kein Wochensoll eingetragen; ohne Wochensoll lässt sich die Stundengrenze nicht prüfen. "
    + "Bitte unter «Planungsgrenzen» das Wochensoll eintragen und neu vorschlagen. Es wurde nichts übernommen.",
  rule_warning: "Nicht eingeteilt: Diese Einteilung verletzt eine Planungsregel. Bitte unten prüfen und bestätigen oder abbrechen.",
  name_exists: "Diesen Namen gibt es schon.",
  not_simulation: "Beispieldaten gibt es nur im Simulationskonto.",
  not_empty: "Beispieldaten lassen sich nur in ein leeres Heim laden.",
  range_not_valid: "Dieser Zeitraum lässt sich nicht anzeigen.",
  // HD-2: gap → external order
  already_ordered: "Für diese Lücke gibt es schon einen Auftrag (vorbereitet oder gesendet).",
  not_a_gap: "Dieser Dienst hat keine Lücke (mehr). Es wird nichts bestellt.",
  starts_in_past: "Dieser Dienst hat schon begonnen oder liegt in der Vergangenheit.",
  no_client_account: "Für dieses Heim ist kein Auftraggeber-Konto eingerichtet.",
  not_client_member: "Sie dürfen in diesem Heim planen, aber keine externen Aufträge senden.",
  grade_not_missing: "Es fehlt eine bestimmte Stufe; der Auftrag gilt nur für diese Stufe.",
  not_prepared: "Dieser Auftrag ist nicht mehr im Entwurf.",
  missing_postcode: "Bitte die Postleitzahl des Heims wählen.",
  missing_grade: "Bitte die Stufe wählen.",
  missing_activity_tags: "Bitte mindestens eine Tätigkeit wählen.",
  level_activity_conflict: "Mindestens eine Tätigkeit ist für diese Stufe nicht zulässig.",
  postcode_not_in_list: "Diese Postleitzahl ist nicht in der Liste.",
  postcode_outside_regions: "Diese Postleitzahl liegt ausserhalb der Regionen.",
  required_tag_not_in_tags: "Eine Pflicht-Tätigkeit muss auch als Tätigkeit gewählt sein.",
  tag_unknown: "Unbekannte Tätigkeit.",
  duplicate: "Dieser Auftrag wurde schon gesendet.",
  // UXR-269: the boxes changed after «Prüfen»; nothing was sent.
  order_changed_recheck: "Geändert nach dem Prüfen: Es wurde nichts gesendet. Bitte die Angaben unten erneut prüfen.",
  // HD-2 slice 5: withdrawal refusals
  not_sent: "Dieser Auftrag ist nicht gesendet; ein Entwurf wird verworfen.",
  already_withdrawn: "Dieser Auftrag ist schon zurückgezogen.",
  order_started: "Die Schicht hat begonnen; der Auftrag lässt sich nicht mehr zurückziehen.",
  covered: "Eine Person ist bestätigt; der Auftrag wird hier nicht zurückgezogen.",
  awaiting_acknowledgement: "Ein Team hat übernommen und die Person bestätigt noch; der Auftrag wird jetzt nicht zurückgezogen.",
  visit_under_way: "Der Einsatz läuft schon; der Auftrag lässt sich nicht mehr zurückziehen.",
  // HD-3a FE-128: planning inputs. The app refuses what is not a number; the database refuses what is out of range.
  rest_not_whole: "Ruhezeit: bitte ganze Stunden eingeben (zum Beispiel 11). Nichts wurde gespeichert.",
  days_not_whole: "Arbeitstage in Folge: bitte eine ganze Zahl eingeben (zum Beispiel 6). Nichts wurde gespeichert.",
  weekly_not_number: "Wochensoll: bitte Stunden eingeben (zum Beispiel 42 oder 42,5) oder «nicht eingetragen» wählen. Nichts wurde gespeichert.",
  weekly_choice_missing: "Wochensoll: bitte «Wert» oder «nicht eingetragen» wählen. Nichts wurde gespeichert.",
  limits_not_valid: "Ruhezeit 1 bis 24 Stunden, Arbeitstage in Folge 1 bis 14. Nichts wurde gespeichert.",
  weekly_target_hours_not_valid: "Wochensoll 1 bis 80 Stunden. Nichts wurde gespeichert.",
  pensum_not_whole: "Pensum: bitte ganze Prozent eingeben (zum Beispiel 80) oder «nicht eingetragen» wählen. Nichts wurde gespeichert.",
  pensum_choice_missing: "Pensum: bitte «Wert» oder «nicht eingetragen» wählen. Nichts wurde gespeichert.",
  pensum_not_valid: "Pensum 10 bis 100 %. Nichts wurde gespeichert.",
  pensum_conflict: "Pensum: «nicht eingetragen» gewählt und eine Zahl eingegeben. Bitte eines davon. Nichts wurde gespeichert.",
  weekly_conflict: "Wochensoll: «nicht eingetragen» gewählt und eine Zahl eingegeben. Bitte eines davon. Nichts wurde gespeichert.",
  shift_model_unknown: "Bitte ein Schichtmodell wählen. Nichts wurde gespeichert.",
  shift_model_not_valid: "Bitte ein Schichtmodell wählen. Nichts wurde gespeichert.",
  shift_class_unknown: "Bitte Früh, Spät, Nacht oder «keine Klasse» wählen. Nichts wurde gespeichert.",
  shift_class_not_valid: "Bitte Früh, Spät, Nacht oder «keine Klasse» wählen. Nichts wurde gespeichert.",
  // HD-3s: the split shift (two blocks). V1-V5 with the same codes as the database (split.ts, migration 0182).
  time_format: "Geteilter Dienst: bitte jede Zeit als HH:MM eingeben (00:00 bis 23:59). Nichts wurde gespeichert.",
  zero_length: "Geteilter Dienst: ein Block muss länger als 0 Minuten sein. Nichts wurde gespeichert.",
  block_crosses_midnight: "Geteilter Dienst: ein Block darf nicht über Mitternacht gehen. Nichts wurde gespeichert.",
  block_order: "Geteilter Dienst: Block 2 muss nach dem Ende von Block 1 beginnen. Nichts wurde gespeichert.",
  no_pause: "Geteilter Dienst: zwischen Block 1 und Block 2 braucht es eine Pause. Nichts wurde gespeichert.",
  shift_type_is_split: "Diese Dienstart ist ein geteilter Dienst. Bitte die zwei Blöcke unter «Geteilter Dienst» ändern. Nichts wurde gespeichert.",
  split_shift_not_orderable: "Ein geteilter Dienst kann noch nicht als externer Auftrag gesendet werden (ein Auftrag hat eine Zeit). Die Lücke bleibt.",
  work_days_not_whole: "Arbeitstage pro Woche: bitte eine ganze Zahl eingeben (1 bis 7). Nichts wurde gespeichert.",
  work_days_per_week_not_valid: "Arbeitstage pro Woche: 1 bis 7. Nichts wurde gespeichert.",
  changed_meanwhile: "Diese Werte wurden inzwischen geändert. Nichts wurde gespeichert. Die Seite zeigt jetzt die aktuellen Werte.",
  // HD-3a-F1 R-6-2 (b): the form sent no readable shown values (an old or altered form); nothing was saved.
  expected_not_valid: "Das Formular war nicht mehr aktuell. Nichts wurde gespeichert. Bitte die Seite neu laden und noch einmal speichern.",
  // HD-3a-F3 (migration 0189): the monthly target and the deviation threshold.
  target_not_number:
    "Monatssoll: bitte Stunden eingeben (zum Beispiel 120 oder 120,5; keine negativen Werte) oder «kein Monatssoll» wählen. Nichts wurde gespeichert.",
  target_choice_missing: "Monatssoll: bitte «Wert» oder «kein Monatssoll» wählen. Nichts wurde gespeichert.",
  target_conflict: "Monatssoll: «kein Monatssoll» gewählt und eine Zahl eingegeben. Bitte eines davon. Nichts wurde gespeichert.",
  target_not_valid: "Monatssoll: mehr als 0 und höchstens 744 Stunden (31 Tage). Nichts wurde gespeichert.",
  month_not_valid: "Dieser Monat lässt sich nicht speichern. Bitte die Seite neu laden. Nichts wurde gespeichert.",
  threshold_not_number:
    "Abweichungsschwelle: bitte Stunden eingeben (zum Beispiel 8 oder 8,5) oder «keine Schwelle» wählen. Nichts wurde gespeichert.",
  threshold_choice_missing: "Abweichungsschwelle: bitte «Wert» oder «keine Schwelle» wählen. Nichts wurde gespeichert.",
  threshold_conflict: "Abweichungsschwelle: «keine Schwelle» gewählt und eine Zahl eingegeben. Bitte eines davon. Nichts wurde gespeichert.",
  threshold_not_valid: "Abweichungsschwelle: mehr als 0 und höchstens 744 Stunden, höchstens zwei Nachkommastellen. Nichts wurde gespeichert.",
  failed: "Das hat nicht geklappt. Bitte erneut versuchen.",
};

const DONE_TEXT: Record<string, string> = {
  assigned_with_warning: "Eingeteilt, mit bestätigter Regelwarnung. Die Warnung bleibt auf dem Dienst sichtbar.",
  assigned: "Eingeteilt.",
  unassigned: "Aus dem Dienst entfernt.",
  absence: "Abwesenheit erfasst. Betroffene Dienste zeigen jetzt die Lücke.",
  absence_removed: "Abwesenheit entfernt.",
  staff_added: "Person hinzugefügt.",
  staff_changed: "Gespeichert.",
  station_added: "Station hinzugefügt.",
  shift_saved: "Dienstart gespeichert.",
  rule_saved: "Vorgabe gespeichert.",
  example: "Beispieldaten geladen (synthetisch).",
  order_prepared: "Auftrag vorbereitet, noch nicht gesendet. Bitte prüfen und senden.",
  order_sent: "Auftrag gesendet: Angebot an alle passenden Teams gleichzeitig.",
  order_discarded: "Entwurf verworfen. Die Lücke bleibt.",
  order_withdrawn: "Auftrag zurückgezogen. Kein Team erhält das Angebot mehr; die Lücke bleibt.",
  limits_saved: "Planungsgrenzen des Heims gespeichert.",
  split_saved: "Geteilter Dienst gespeichert: ein Arbeitstag mit zwei Blöcken.",
  work_days_saved: "Arbeitstage pro Woche gespeichert.",
  staff_planning_saved: "Pensum und Schichtmodell gespeichert.",
  monthly_target_saved: "Monatssoll gespeichert. Für diesen Monat gilt es statt des Wochenbudgets.",
  monthly_target_removed: "Monatssoll entfernt. Für diesen Monat gilt wieder das Wochenbudget (Pensum × Wochensoll).",
  threshold_saved: "Abweichungsschwelle gespeichert.",
};

/** HD-3a slice 4: the answer of «Entwurf übernehmen», with the counts the database returned (no state). */
function draftText(code: string, applied: number, refused: number): string | null {
  const n = (k: number, one: string, many: string) => `${k} ${k === 1 ? one : many}`;
  if (code === "draft_applied") return `Vorschlag übernommen: ${n(applied, "Dienst", "Dienste")} eingeteilt.`;
  if (code === "draft_applied_partly") {
    return `Vorschlag teilweise übernommen: ${n(applied, "Dienst", "Dienste")} eingeteilt, ${n(refused, "Vorschlag", "Vorschläge")} `
      + `abgelehnt, weil sich der Plan seither geändert hat. Diese Dienste bleiben offen.`;
  }
  if (code === "draft_already_applied") return `Dieser Vorschlag wurde schon übernommen (${n(applied, "Dienst", "Dienste")}). Nichts wurde doppelt eingeteilt.`;
  return null;
}

/**
 * HD-3a FE-128: the answer of «Klasse speichern» with the count the database returned (`affected_assignments`: saved
 * shifts from today on whose person's shift model no longer fits; nothing was removed). Read back, not computed (T-1).
 */
function shiftClassText(affected: number): string {
  if (affected === 0) return "Schichtklasse gespeichert. Keine eingeteilte Person ist betroffen.";
  return `Schichtklasse gespeichert. ${affected} ${affected === 1 ? "Einteilung passt" : "Einteilungen passen"} ab heute nicht mehr `
    + "zum Schichtmodell der Person. Nichts wurde entfernt; die Warnung steht im Plan.";
}

export function messageText(
  code: string | undefined, counts?: { applied: number; refused: number; affected?: number },
): { kind: "ok" | "error"; text: string } | null {
  if (!code) return null;
  if (code === "shift_class_saved") return { kind: "ok", text: shiftClassText(counts?.affected ?? 0) };
  const draft = draftText(code, counts?.applied ?? 0, counts?.refused ?? 0);
  if (draft) return { kind: "ok", text: draft };
  if (code in DONE_TEXT) return { kind: "ok", text: DONE_TEXT[code] };
  if (code in PROBLEM_TEXT) return { kind: "error", text: PROBLEM_TEXT[code] };
  return null;
}

/** A return path for the commands: only /heim with a query, never another origin (no open redirect). */
export function safeReturnPath(input: unknown): string {
  if (typeof input !== "string" || !input.startsWith(`${HOME_PLAN_PATH}`)) return HOME_PLAN_PATH;
  if (input.startsWith("//") || input.includes("\\") || /[\r\n]/.test(input)) return HOME_PLAN_PATH;
  const rest = input.slice(HOME_PLAN_PATH.length);
  return rest === "" || rest.startsWith("?") ? input : HOME_PLAN_PATH;
}

export function withMessage(path: string, code: string): string {
  const url = new URL(path, "http://x");
  url.searchParams.set("meldung", code);
  if (!keepsWarning(code)) url.searchParams.delete("warnung");
  return `${url.pathname}${url.search}`;
}

/** HD-3a slice 4: the counts of «Entwurf übernehmen» next to the message code (whole numbers only). */
export function withDraftCounts(path: string, applied: number, refused: number): string {
  const url = new URL(path, "http://x");
  url.searchParams.set("uebernommen", String(Math.max(0, Math.trunc(applied))));
  url.searchParams.set("abgelehnt", String(Math.max(0, Math.trunc(refused))));
  return `${url.pathname}${url.search}`;
}
/**
 * HD-3a-F1 R-7-2: after a partial take-over the URL carries only the apply id (`lauf`), never a name; the page reads the
 * refused rows back from the run record (`institution_draft_run_refusals`, T-1).
 */
export function withApplyRun(path: string, applyId: string): string {
  const url = new URL(path, "http://x");
  if (UUID_RE.test(applyId)) url.searchParams.set("lauf", applyId);
  return `${url.pathname}${url.search}`;
}
/**
 * HD-3a-F1 R-7-2 (review 7228232661, 5): the answers whose refused rows the page reads back. A double click or a retry
 * shows the answer of the second call (`draft_already_applied`), which still carries the refused rows of the first.
 */
export const APPLY_RUN_CODES: ReadonlyArray<string> = ["draft_applied_partly", "draft_already_applied"];
export function carriesApplyRun(code: string | undefined, refused: number): boolean {
  return code === "draft_applied_partly" || (code === "draft_already_applied" && refused > 0);
}
export function parseApplyRun(v: string | undefined): string | null {
  return typeof v === "string" && UUID_RE.test(v) ? v : null;
}

/** One refused row of a take-over as `institution_draft_run_refusals` returns it. */
export type RunRefusal = { staff_id: string; date: string; shift_type_id: string; reason: string };

/**
 * HD-3a-F1 R-7-2: the persons whose rows «übernehmen» refused for a missing Pensum (`pensum_missing`), each with the
 * number of her refused shifts, in name order. A person no longer in the plan's staff list is named «Eine Person» (the
 * screen never shows an id).
 */
export function pensumMissingPersons(
  refused: ReadonlyArray<RunRefusal>, staff: ReadonlyArray<{ id: string; display_name: string }>,
): Array<{ id: string; name: string; shifts: number }> {
  const count = new Map<string, number>();
  for (const r of refused) if (r.reason === "pensum_missing") count.set(r.staff_id, (count.get(r.staff_id) ?? 0) + 1);
  const name = new Map(staff.map((s) => [s.id, s.display_name]));
  return [...count.entries()]
    .map(([id, shifts]) => ({ id, name: name.get(id) ?? "Eine Person", shifts }))
    .sort((a, b) => a.name.localeCompare(b.name, "de-CH") || a.id.localeCompare(b.id));
}

/**
 * HD-3a-F1 R-7-2: the line per person, with the next action. UXR-310 (HD-PEN-HAND): «übernehmen» refuses a row with
 * `pensum_missing` only when there is no monthly target for its month either (migration 0189), so the text names both.
 */
export function pensumMissingText(p: { name: string; shifts: number }): string {
  return `${p.name}: ${p.shifts} ${p.shifts === 1 ? "Dienst" : "Dienste"} nicht übernommen, weil weder Pensum noch Monatssoll `
    + "eingetragen ist. Bitte bei der Person das Pensum oder das Monatssoll eintragen und neu vorschlagen.";
}

/**
 * UXR-310 (HD-PEN-HAND): the staff list marks «· ohne Pensum» only when the person also has no monthly target in a
 * month the plan shows (with a target the hours are checked by it, R-m).
 */
export function withoutPensumAndTarget(plan: Pick<Plan, "staff" | "month_targets">, staffId: string): boolean {
  const s = plan.staff.find((x) => x.id === staffId);
  if (!s || !s.active || s.pensum_pct != null) return false;
  return !(plan.month_targets ?? []).some((m) => m.staff_id === staffId && m.target_minutes != null);
}

/**
 * HD-PEN-HAND (ENG-PH1): why the hours of a shift of this person on this day cannot be checked, and what can be entered
 * so they can. The same conditions as `private.institution_rule_breaches` (no monthly target for the month of the day,
 * and no Pensum or no Wochensoll); the database decides, this only names the gap. `who`: the lead can enter all three;
 * a planner can enter the Pensum, the Monatssoll and the Wochensoll are entered by the lead (UXR-305 pattern).
 */
export type HoursGapAction = { kind: "pensum" | "month_target" | "weekly_target"; label: string; lead_only: boolean };
export function hoursUnknownNext(
  plan: Pick<Plan, "staff" | "month_targets" | "institution">, staffId: string, date: string,
): { reason: string; actions: HoursGapAction[] } | null {
  const s = plan.staff.find((x) => x.id === staffId);
  if (!s || monthTargetOf(plan, staffId, date)?.target_minutes != null) return null;
  const noPensum = s.pensum_pct == null;
  const noWeekly = plan.institution.weekly_target_hours == null;
  if (!noPensum && !noWeekly) return null;
  const missing = noPensum && noWeekly ? "kein Pensum und kein Wochensoll des Heims"
    : noPensum ? "kein Pensum" : "kein Wochensoll des Heims";
  const actions: HoursGapAction[] = [];
  if (noPensum) actions.push({ kind: "pensum", label: "Pensum eintragen", lead_only: false });
  actions.push({ kind: "month_target", label: `Monatssoll ${monthLabel(date)} eintragen`, lead_only: true });
  if (noWeekly) actions.push({ kind: "weekly_target", label: "Wochensoll eintragen", lead_only: true });
  return { reason: `Für ${monthLabel(date)} ist kein Monatssoll und ${missing} eingetragen.`, actions };
}

/**
 * HD-PEN-HAND (PO decision, AUT-247): stored shifts of the shown range whose hours cannot be checked (`hours_unknown`
 * now), confirmed by hand or not (shifts saved before migration 0190 are unconfirmed), and the first affected person
 * (earliest day, then name) for the link. Zero → the page shows no line.
 */
export function hoursUnknownCount(plan: Pick<Plan, "cells">): { shifts: number; confirmed: number; first: { staff_id: string; date: string } | null } {
  const seen = new Set<string>();
  let confirmed = 0;
  let first: { staff_id: string; date: string; name: string } | null = null;
  for (const c of plan.cells ?? []) {
    for (const a of c.assigned ?? []) {
      if (seen.has(a.assignment_id) || !(a.rules ?? []).includes("hours_unknown")) continue;
      seen.add(a.assignment_id);
      if ((a.override_rules ?? []).includes("hours_unknown")) confirmed++;
      if (!first || c.date < first.date || (c.date === first.date && a.display_name.localeCompare(first.name, "de-CH") < 0)) {
        first = { staff_id: a.staff_id, date: c.date, name: a.display_name };
      }
    }
  }
  return { shifts: seen.size, confirmed, first: first && { staff_id: first.staff_id, date: first.date } };
}
/**
 * The count line. HD-PEN-HAND-F1 UXR-315: it counts only the shown week or month (`hoursUnknownCount` reads the cells of
 * the plan answer for that range), so it names the range; it is never a home-wide total. Wording placeholder until the
 * `cra` gate.
 */
export function hoursUnknownCountText(n: { shifts: number; confirmed: number }, view: "woche" | "monat", from: string): string {
  const range = view === "woche" ? "in dieser Woche" : `im ${monthLabel(from)}`;
  const what = `${n.shifts} ${n.shifts === 1 ? "Dienst" : "Dienste"} ohne Stundenprüfung ${range}`;
  return n.confirmed > 0 ? `${what} (davon ${n.confirmed} von Hand bestätigt)` : what;
}

/**
 * HD-PEN-HAND-F1 UXR-316: what the count line offers for its first affected shift, from the same cause as the warning
 * box (`hoursUnknownNext`, no new query). The home's missing Wochensoll comes first (one value for everybody with a
 * Pensum): the lead gets the link to «Einstellungen», a planner the sentence that the lead enters it. A missing Pensum
 * gives the link to that person (lead and planner may enter it). The database decides the rule; when the mirror finds
 * no gap although the row carries `hours_unknown`, the line falls back to the person, so it never offers nothing.
 */
export type HoursUnknownStep =
  | { kind: "weekly_target"; label: string }
  | { kind: "ask_lead"; text: string }
  | { kind: "person"; staff_id: string; date: string; label: string };
export function hoursUnknownSteps(
  plan: Pick<Plan, "staff" | "month_targets" | "institution">, first: { staff_id: string; date: string }, lead: boolean,
): HoursUnknownStep[] {
  const name = plan.staff.find((s) => s.id === first.staff_id)?.display_name ?? "erste Person";
  const gap = hoursUnknownNext(plan, first.staff_id, first.date);
  const person = (label: string): HoursUnknownStep => ({ kind: "person", staff_id: first.staff_id, date: first.date, label });
  if (!gap) return [person(`${name} ansehen`)];
  const steps: HoursUnknownStep[] = [];
  if (gap.actions.some((a) => a.kind === "weekly_target")) {
    steps.push(lead ? { kind: "weekly_target", label: "Wochensoll eintragen" }
      : { kind: "ask_lead", text: "Das Wochensoll des Heims fehlt; es trägt die Heimleitung ein." });
  }
  if (gap.actions.some((a) => a.kind === "pensum")) steps.push(person(`Pensum von ${name} eintragen`));
  return steps;
}
/** UXR-316: the count line's hint that its link opens only the first of several affected shifts. */
export function hoursUnknownFirstNote(shifts: number): string | null {
  return shifts > 1 ? `Der Link öffnet den ersten von ${shifts} Diensten.` : null;
}

/**
 * HD-PEN-HAND-F1 UXR-318: the messages after which a pending warning (`warnung`) stays in the URL. They are the saves
 * reached from the warning box's links (Pensum, Monatssoll, Wochensoll); the shift is still not assigned, so the box
 * stays and offers to assign again. Every other message drops it (assigned, cancelled, any error), as before.
 */
export const WARNING_RETURN_CODES = ["staff_planning_saved", "monthly_target_saved", "limits_saved"] as const;
export function keepsWarning(code: string | undefined): boolean {
  return code === "rule_warning" || (WARNING_RETURN_CODES as ReadonlyArray<string>).includes(code ?? "");
}
/**
 * UXR-318: the box after such a save («zurück») never sends a confirmation. «Jetzt einteilen» calls the hand assignment
 * without `confirm`, so the database reads every rule again under its locks: the gap closed → saved without override;
 * still open or a new rule → a fresh warning (message `rule_warning`), which again offers «Trotzdem einteilen». A rule
 * list from an older URL is therefore never confirmed after the facts changed.
 */
export function warningReturned(code: string | undefined): boolean {
  return (WARNING_RETURN_CODES as ReadonlyArray<string>).includes(code ?? "");
}
/** UXR-318: the working-time sentence of the box only for the rules it is about. */
export const showsWorkingTimeNote = (rules: ReadonlyArray<PlanningRule>): boolean =>
  rules.includes("rest") || rules.includes("consecutive");

/** HD-3a FE-128: the `affected_assignments` count of «Klasse speichern» next to the message code. */
export function withAffected(path: string, affected: number): string {
  const url = new URL(path, "http://x");
  url.searchParams.set("betroffen", String(Math.max(0, Math.trunc(affected))));
  return `${url.pathname}${url.search}`;
}
export function parseCount(v: unknown): number {
  return typeof v === "string" && /^\d{1,4}$/.test(v) ? Number(v) : 0;
}

/** HD-3a Q3: the pending hand assignment that broke a rule, carried in the URL to the confirmation form (no state). */
export type PendingWarning = { staff: string; station: string; shift: string; date: string; rules: PlanningRule[] };
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function withWarning(path: string, w: PendingWarning): string {
  const url = new URL(path, "http://x");
  url.searchParams.set("warnung", [w.staff, w.station, w.shift, w.date, w.rules.join(",")].join("~"));
  return `${url.pathname}${url.search}`;
}
/** Reads `warnung` back; anything malformed is ignored (the database checks everything again on confirmation). */
export function parseWarning(v: unknown): PendingWarning | null {
  if (typeof v !== "string") return null;
  const [staff, station, shift, date, rules, ...rest] = v.split("~");
  if (rest.length > 0 || ![staff, station, shift].every((x) => UUID_RE.test(x ?? "")) || !isIsoDate(date)) return null;
  const r = parseRules(rules);
  return r.length > 0 ? { staff, station, shift, date, rules: r } : null;
}
