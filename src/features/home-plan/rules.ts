// HD-1 / HD-2 (migration 0159): pure rules of the home's own staff plan (/heim). No Next or Supabase imports,
// unit-tested (tests/unit/hd1-home-plan.test.ts). The database decides every status (`institution_plan`); this module
// only orders and words it. Fixed rules, no AI.

export const HOME_PLAN_PATH = "/heim";

export type PlanView = "woche" | "monat" | "personal" | "einstellungen" | "auftrag";
export const PLAN_VIEWS: ReadonlyArray<{ key: PlanView; label: string }> = [
  { key: "woche", label: "Woche" },
  { key: "monat", label: "Monat" },
  { key: "personal", label: "Mitarbeitende" },
  { key: "einstellungen", label: "Einstellungen" },
];

export type InstitutionRole = "lead" | "planner" | "viewer";
export type Station = { id: string; name: string };
export type ShiftType = { id: string; code: string; label: string; starts_at: string; ends_at: string };
export type Staff = { id: string; display_name: string; grade: string; home_station_id: string | null; active: boolean };
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
  };
  from: string;
  to: string;
  stations: Station[];
  shift_types: ShiftType[];
  staff: Staff[];
  absences: Absence[];
  cells: PlanCell[];
};

export const GRADE_LABEL: Record<string, string> = { ags_eba: "AGS", fage_efz: "FaGe", nurse_hf_fh: "HF" };
export const GRADE_CHOICES = [
  { value: "nurse_hf_fh", label: "HF" },
  { value: "fage_efz", label: "FaGe" },
  { value: "ags_eba", label: "AGS" },
] as const;

export const gradeLabel = (code: string | null): string => (code ? (GRADE_LABEL[code] ?? code) : "");

export const canPlan = (role: InstitutionRole): boolean => role === "lead" || role === "planner";
export const canSettle = (role: InstitutionRole): boolean => role === "lead";

/** Shown wherever the plan is edited: the database checks no working-time law (ArG), only absence and overlap. */
export const WORKING_TIME_NOTE = "Arbeitszeitregeln (Ruhezeit, Höchstarbeitszeit) prüft NAVORA hier nicht.";
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
  if (view === "woche" || view === "einstellungen" || view === "auftrag") {
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
  if (cell.required_grade && cell.grade_present < cell.required_grade_count) {
    const lack = cell.required_grade_count - cell.grade_present;
    parts.push(`${lack} ${gradeLabel(cell.required_grade)} fehlt`);
  }
  return `${base} · Lücke: ${parts.join(", ")}`;
}

// --- HD-2: the external order of a cell in the home's words (brief HD.md §3, §3a) ----------------------------------
export type OrderTone = "draft" | "wait" | "ok" | "alert";
export type OrderLine = { code: "E" | "A" | "T" | "G" | "K" | "N"; headline: string; detail: string | null; tone: OrderTone; next: string | null };

/** Next action of the home where the order does not cover the shift (K, N). Withdrawing is not built yet (PR #1641). */
export const NEXT_INTERNAL = "Nächste Handlung: eine zulässige eigene Person einteilen.";

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
        };
      }),
  }));
}

/**
 * The month grid cell of one person on one day: shift codes, «A» when absent, empty when free. A shift that does not
 * count (the night into an absence day, or a person no longer active) is shown in brackets: it is planned, not staffed.
 */
export function monthCode(day: PersonDay): string {
  const codes = day.shifts.map((s) => (s.counts || day.absent ? s.code : `(${s.code})`)).join("/");
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
  input_not_valid: "Bitte die Angaben prüfen.",
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
  failed: "Das hat nicht geklappt. Bitte erneut versuchen.",
};

const DONE_TEXT: Record<string, string> = {
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
};

export function messageText(code: string | undefined): { kind: "ok" | "error"; text: string } | null {
  if (!code) return null;
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
  return `${url.pathname}${url.search}`;
}
