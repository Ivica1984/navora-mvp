export type CaseStatus = "neu" | "teampruefung" | "laufend";

export type CaseUrgency = "niedrig" | "mittel" | "hoch";


export type CaseAssignedTeam = {
  id: string;
  name: string;
  region: string | null;
  status: string | null;
  open_slots: number | null;
  utilization: number | null;
};

export type CaseRow = {
  id: string;
  created_at: string;

  name: string | null;
  region: string | null;
  status: CaseStatus | string | null;

  bedarf: string | null;
  urgency: CaseUrgency | string | null;
  time_info: string | null;

  first_name: string | null;
  last_name: string | null;
  date_of_birth: string | null;
  gender: string | null;

  address: string | null;
  plz: string | null;
  ort: string | null;
  phone: string | null;

  emergency_contact_name: string | null;
  emergency_contact_phone: string | null;

  mobility_status: string | null;
  cognitive_status: string | null;

  diagnosis_tags: string[] | null;
  care_needs: string[] | null;

  care_level: string | null;
  referral_source: string | null;
  insurance_provider: string | null;

  start_date: string | null;
  next_step: string | null;
  notes: string | null;

  assigned_team: string | null;
  assigned_team_id: string | null;
  teams?: CaseAssignedTeam | null;
};

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

export function getCaseDisplayName(careCase: CaseRow) {
  const firstName = careCase.first_name ?? "";
  const lastName = careCase.last_name ?? "";
  const fullName = `${firstName} ${lastName}`.trim();

  return fullName || careCase.name || "Unbenannter Fall";
}

export function getCaseNeedSummary(careCase: CaseRow) {
  if (Array.isArray(careCase.care_needs) && careCase.care_needs.length > 0) {
    return careCase.care_needs.join(", ");
  }

  if (careCase.bedarf) {
    return careCase.bedarf;
  }

  return "Bedarf noch nicht erfasst";
}

export function getCaseRegion(careCase: CaseRow) {
  return careCase.region || careCase.ort || "Region offen";
}
