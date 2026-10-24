import type { TenantRow } from "@/lib/supabase/tables";

export type CaseStatus = "neu" | "teampruefung" | "laufend";

export type CaseUrgency = "niedrig" | "mittel" | "hoch";


/** Full case row (all columns except the tenant key). Not sent to the browser. */
export type CaseRow = TenantRow<"cases">;

/**
 * The case fields the Operations view needs (T10, SR-06). Deliberately excludes
 * date of birth, gender, address, phone, emergency contacts, mobility and
 * cognitive status, diagnoses, insurance and free-text notes.
 */
export const CASE_SUMMARY_COLUMNS =
  "id, created_at, name, first_name, last_name, region, ort, status, urgency, bedarf, care_needs, assigned_team, assigned_team_id";

export type CaseSummaryRow = Pick<
  CaseRow,
  | "id"
  | "created_at"
  | "name"
  | "first_name"
  | "last_name"
  | "region"
  | "ort"
  | "status"
  | "urgency"
  | "bedarf"
  | "care_needs"
  | "assigned_team"
  | "assigned_team_id"
>;

export const CASE_COLUMNS = [
  {
    id: "neu",
    title: "Neue Fälle",
  },
  {
    id: "teampruefung",
    title: "In Teamprüfung",
  },
  {
    id: "laufend",
    title: "Laufend",
  },
] as const;

export function getCaseDisplayName(careCase: CaseSummaryRow) {
  const firstName = careCase.first_name ?? "";
  const lastName = careCase.last_name ?? "";
  const fullName = `${firstName} ${lastName}`.trim();

  return fullName || careCase.name || "Unbenannter Fall";
}

export function getCaseNeedSummary(careCase: CaseSummaryRow) {
  if (Array.isArray(careCase.care_needs) && careCase.care_needs.length > 0) {
    return careCase.care_needs.join(", ");
  }

  if (careCase.bedarf) {
    return careCase.bedarf;
  }

  return "Bedarf noch nicht erfasst";
}

export function getCaseRegion(careCase: CaseSummaryRow) {
  return careCase.region || careCase.ort || "Region offen";
}
