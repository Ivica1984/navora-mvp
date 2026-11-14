// BK-a (brief docs/agents/briefs/BK.md; ADR-194): pure rules of the client's order form. No Next or Supabase imports,
// unit-tested (tests/unit/bk-a-client-order.test.ts). The database (migration 0129) re-runs every check at
// «Bestätigen & Absenden»; this module only words its codes and resolves date words for the client to see.

import { FIELD_PATH, HOME_PATH, homePathForRoles } from "@/lib/auth/paths";

/** ADR-192 (6): the client's only page. */
export const CLIENT_ORDER_PATH = "/order";

/** A client (member of a client account) with no organisation role lands on /order; everyone else as before. */
export function homePathFor(roles: ReadonlyArray<string>, isClient: boolean): string {
  if (isClient && roles.length === 0) return CLIENT_ORDER_PATH;
  const path = homePathForRoles(roles);
  return path === FIELD_PATH ? FIELD_PATH : HOME_PATH;
}

/** The three levels of the form (BK-1a) and the existing matrix grade codes behind them (QUAL1, PROPOSED). */
export const GRADE_OPTIONS = [
  { value: "ags_eba", label: "AGS" },
  { value: "fage_efz", label: "FaGe" },
  { value: "nurse_hf_fh", label: "HF" },
] as const;

export type GradeCode = (typeof GRADE_OPTIONS)[number]["value"];

/** Codes of private.client_order_check (migration 0129). */
export const ORDER_PROBLEM_CODES = [
  "not_client",
  "missing_start_date",
  "missing_start_time",
  "missing_end_time",
  "missing_postcode",
  "missing_grade",
  "missing_activity_tags",
  "end_equals_start",
  "starts_in_past",
  "postcode_not_in_list",
  "postcode_outside_regions",
  "grade_unknown",
  "tag_unknown",
  "required_tag_not_in_tags",
  "radius_not_positive",
] as const;

const PROBLEM_TEXT: Record<(typeof ORDER_PROBLEM_CODES)[number], string> = {
  not_client: "Sie können für dieses Konto keine Aufträge erfassen.",
  missing_start_date: "Bitte das Datum angeben.",
  missing_start_time: "Bitte die Beginnzeit angeben.",
  missing_end_time: "Bitte die Endzeit angeben.",
  missing_postcode: "Bitte die Postleitzahl des Einsatzorts wählen.",
  missing_grade: "Bitte die Stufe wählen (AGS, FaGe oder HF).",
  missing_activity_tags: "Bitte mindestens eine Tätigkeit wählen.",
  end_equals_start: "Beginn und Ende sind gleich. Bitte die Zeiten prüfen.",
  starts_in_past: "Der Beginn liegt in der Vergangenheit. Bitte Datum und Zeit prüfen.",
  postcode_not_in_list: "Diese Postleitzahl ist nicht in der Liste (Basel-Stadt, Basel-Landschaft).",
  postcode_outside_regions: "Für diese Postleitzahl nimmt das Netzwerk keine Aufträge an.",
  grade_unknown: "Bitte eine Stufe aus der Liste wählen.",
  tag_unknown: "Bitte nur Tätigkeiten aus der Liste wählen.",
  required_tag_not_in_tags: "Eine als zwingend markierte Tätigkeit ist nicht ausgewählt.",
  radius_not_positive: "Die Distanz muss grösser als 0 km sein oder leer bleiben.",
};

export function orderProblemText(code: string): string {
  return (PROBLEM_TEXT as Record<string, string>)[code] ?? "Der Auftrag kann so nicht gespeichert werden.";
}

/** UXR-197: the label line of the summary, only when the client's own plan has a matching entry. */
export function shiftLabelLine(label: string | null | undefined): string | null {
  return label && label.trim() ? `${label.trim()} · aus Ihrem Dienstplan` : null;
}

/** UXR-197: the optional radius (PO 18:40 (1)(b)); empty by default. */
export function radiusLine(km: number | null | undefined): string {
  if (km === null || km === undefined) return "Distanz: keine Vorgabe";
  return `Distanz: höchstens ${String(km).replace(".", ",")} km`;
}

/** BK-6: never silent. Until BK-c derives cover from offers, every confirmed order is «noch nicht gedeckt». */
export function coverStateText(state: string): string {
  switch (state) {
    // BK-c adds the offer states («Angebot bei Team 1 von 4», «… hat übernommen · Pflegekraft noch nicht benannt»).
    default:
      return "noch nicht gedeckt";
  }
}

export type DateResolution =
  | { kind: "date"; date: string }
  | { kind: "relative_date_ambiguous"; candidates: [string, string] }
  | { kind: "unknown" }
  | { kind: "empty" };

const WEEKDAYS = ["montag", "dienstag", "mittwoch", "donnerstag", "freitag", "samstag", "sonntag"];

/** Calendar arithmetic on ISO dates (UTC noon, so no time zone shifts the day). */
function addDays(iso: string, days: number): string {
  const d = new Date(`${iso}T12:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

function isoWeekday(iso: string): number {
  const wd = new Date(`${iso}T12:00:00Z`).getUTCDay();
  return wd === 0 ? 7 : wd;
}

function validDate(y: number, m: number, d: number): string | null {
  const dt = new Date(Date.UTC(y, m - 1, d, 12));
  if (dt.getUTCFullYear() !== y || dt.getUTCMonth() !== m - 1 || dt.getUTCDate() !== d) return null;
  return dt.toISOString().slice(0, 10);
}

/**
 * AUT-120: date words → a concrete date only when the words admit exactly one. A weekday named on that same weekday
 * admits today and the same day next week: both are returned for the client to pick. Nothing is guessed (BK-1b).
 * `today` is the Zurich calendar date (YYYY-MM-DD), passed in by the caller.
 */
export function resolveOrderDate(words: string, today: string): DateResolution {
  const w = words.trim().toLowerCase();
  if (!w) return { kind: "empty" };
  if (w === "heute") return { kind: "date", date: today };
  if (w === "morgen") return { kind: "date", date: addDays(today, 1) };
  if (w === "übermorgen") return { kind: "date", date: addDays(today, 2) };
  const idx = WEEKDAYS.indexOf(w);
  if (idx >= 0) {
    const target = idx + 1;
    const diff = (target - isoWeekday(today) + 7) % 7;
    if (diff === 0) return { kind: "relative_date_ambiguous", candidates: [today, addDays(today, 7)] };
    return { kind: "date", date: addDays(today, diff) };
  }
  const de = /^(\d{1,2})\.(\d{1,2})\.(\d{4})$/.exec(w);
  if (de) {
    const date = validDate(Number(de[3]), Number(de[2]), Number(de[1]));
    return date ? { kind: "date", date } : { kind: "unknown" };
  }
  const iso = /^(\d{4})-(\d{2})-(\d{2})$/.exec(w);
  if (iso) {
    const date = validDate(Number(iso[1]), Number(iso[2]), Number(iso[3]));
    return date ? { kind: "date", date } : { kind: "unknown" };
  }
  return { kind: "unknown" };
}

/** «So 22.11.2026» for a candidate date (UXR-196: never an ISO date on screen). */
export function dateLabel(iso: string): string {
  const [y, m, d] = iso.split("-");
  const wd = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"][isoWeekday(iso) - 1];
  return `${wd} ${d}.${m}.${y}`;
}

/** What the client has typed or chosen in the order form (BK-a). Nothing here is defaulted (BK-1b). */
export type OrderFormState = {
  dateWords: string;
  /** The candidate the client picked when the date words admit two dates (AUT-120). */
  picked: string | null;
  startTime: string;
  endTime: string;
  postcode: string;
  grade: string;
  tags: string[];
  required: string[];
  radius: string;
};

/**
 * UXR-199 (BK amendment 2026-11-14 00:39 (1)(a)): the form after «Bestätigen & Absenden». Every field is empty, so a
 * second press through the same form builds no complete order; the database preview names every missing field.
 */
export const EMPTY_ORDER_FORM: Readonly<OrderFormState> = Object.freeze({
  dateWords: "",
  picked: null,
  startTime: "",
  endTime: "",
  postcode: "",
  grade: "",
  tags: [],
  required: [],
  radius: "",
});

/** The order fields sent to the preview (the shape `previewClientOrder` checks). An empty entry stays null. */
export function orderFieldsFrom(state: OrderFormState, clientAccountId: string, today: string) {
  const resolution = resolveOrderDate(state.dateWords, today);
  const startDate =
    resolution.kind === "date"
      ? resolution.date
      : resolution.kind === "relative_date_ambiguous" && state.picked && resolution.candidates.includes(state.picked)
        ? state.picked
        : null;
  return {
    clientAccountId,
    startDate,
    startTime: state.startTime || null,
    endTime: state.endTime || null,
    postcode: state.postcode || null,
    grade: state.grade || null,
    activityTags: [...state.tags],
    requiredTags: state.required.filter((t) => state.tags.includes(t)),
    radiusKm: state.radius.trim() ? Number(state.radius.replace(",", ".")) : null,
  };
}

/**
 * UXR-200 (BK amendment 2026-11-14 00:39 (1)(c); DESIGN_SYSTEM §2, PROPOSED): the form fields a preview problem can
 * point at. Each field has a control id (the link target) and a problem id (its line, `aria-describedby`).
 */
export const ORDER_FORM_FIELDS = ["date", "startTime", "endTime", "postcode", "grade", "tags", "radius"] as const;
export type OrderFormField = (typeof ORDER_FORM_FIELDS)[number];

const PROBLEM_FIELD: Record<(typeof ORDER_PROBLEM_CODES)[number], OrderFormField | null> = {
  not_client: null,
  missing_start_date: "date",
  starts_in_past: "date",
  missing_start_time: "startTime",
  missing_end_time: "endTime",
  end_equals_start: "endTime",
  missing_postcode: "postcode",
  postcode_not_in_list: "postcode",
  postcode_outside_regions: "postcode",
  missing_grade: "grade",
  grade_unknown: "grade",
  missing_activity_tags: "tags",
  tag_unknown: "tags",
  required_tag_not_in_tags: "tags",
  radius_not_positive: "radius",
};

/** The field a problem code belongs to; null for a form-level problem (not_client, or a code this module lacks). */
export function orderProblemField(code: string): OrderFormField | null {
  return (PROBLEM_FIELD as Record<string, OrderFormField | null>)[code] ?? null;
}

/** The problems grouped per field, in the database's order; codes with no field stay in `form` (never dropped). */
export function orderProblemsByField(codes: ReadonlyArray<string>): {
  byField: Partial<Record<OrderFormField, string[]>>;
  form: string[];
} {
  const byField: Partial<Record<OrderFormField, string[]>> = {};
  const form: string[] = [];
  for (const code of codes) {
    const f = orderProblemField(code);
    if (f) (byField[f] ??= []).push(code);
    else form.push(code);
  }
  return { byField, form };
}

export const orderFieldControlId = (field: OrderFormField) => `order-field-${field}`;
export const orderFieldProblemId = (field: OrderFormField) => `order-field-${field}-problem`;

/** UXR-200: the summary opens only when the preview found no problem; otherwise the form stays with its problems. */
export function orderStepAfterPreview(problems: ReadonlyArray<string>): "summary" | "form" {
  return problems.length === 0 ? "summary" : "form";
}

/** UXR-201: «Datum nicht erkannt» only after the client left the date field, never while typing. */
export function dateUnknownShown(resolution: DateResolution, leftField: boolean): boolean {
  return leftField && resolution.kind === "unknown";
}

/** BK-b1 / CGR-217: information codes of public.preview_client_order (migration 0130). Never a problem: the confirm
 *  stays enabled. */
export const ORDER_INFO_CODES = ["same_order_already_confirmed"] as const;

/** CGR-217, words `uxa` 03:47 (PROPOSED); `cra` 05:26: «zwei Pflegekräfte» holds while one order means one person. */
export function orderInfoText(code: string, earlierSentence: string | null | undefined): string | null {
  if (code !== "same_order_already_confirmed") return null;
  const which = earlierSentence && earlierSentence.trim() ? ` (${earlierSentence.trim()})` : "";
  return (
    `Hinweis: Für dieses Konto ist bereits ein Auftrag mit gleichem Beginn, Ende, Stufe und Ort bestätigt${which}. ` +
    "Ein zweiter Auftrag bedeutet zwei Pflegekräfte für diese Zeit. Wenn das so gemeint ist, bestätigen Sie ihn."
  );
}
