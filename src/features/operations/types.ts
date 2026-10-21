import type { CaseSummaryRow } from "@/features/cases/types";
import type { TeamRow } from "@/features/teams/types";
import type { CareVisitRow } from "@/features/visits/types";


export type PartnerRequestRow = {
  id: string;
  created_at: string;
  partner_name: string;
  partner_type: string | null;
  region: string;
  city: string | null;
  urgency: string;
  time_info: string | null;
  request_title: string;
  need_summary: string;
  requested_services: string[] | null;
  status: string;
  converted_case_id: string | null;
  notes: string | null;
};

export type CareNoteRow = {
  id: string;
  created_at: string;
  visit_id: string | null;
  case_id: string | null;
  team_id: string | null;
  author_name: string | null;
  note_type: string;
  content: string;
  status: string;
};

export type QualityEventRow = {
  id: string;
  created_at: string;
  case_id: string | null;
  visit_id: string | null;
  team_id: string | null;
  event_type: string;
  severity: string;
  title: string;
  description: string | null;
  status: string;
};


export type AttentionPriority = "P1" | "P2" | "P3";

export type AttentionSeverity = "critical" | "warning" | "info";

export type AttentionEntityType =
  | "case"
  | "team"
  | "visit"
  | "partner_request"
  | "quality_event";

export type AttentionItem = {
  id: string;
  priority: AttentionPriority;
  severity: AttentionSeverity;
  category:
    | "capacity"
    | "case"
    | "matching"
    | "visit"
    | "quality"
    | "partner";
  title: string;
  description: string;
  recommendedAction: string;
  entityType: AttentionEntityType;
  entityId: string;
};

// --- Minimal row shapes selected for Operations (T10, SR-06) ------------------

export type PartnerRequestSummary = Pick<
  PartnerRequestRow,
  "id" | "created_at" | "partner_name" | "region" | "urgency" | "need_summary" | "status"
>;
export const PARTNER_REQUEST_SUMMARY_COLUMNS =
  "id, created_at, partner_name, region, urgency, need_summary, status";

/** Only the review status of notes — never their clinical content. */
export type CareNoteStatus = Pick<CareNoteRow, "id" | "visit_id" | "status">;
export const CARE_NOTE_STATUS_COLUMNS = "id, visit_id, status";

export type QualityEventSummary = Pick<
  QualityEventRow,
  "id" | "created_at" | "severity" | "title" | "description" | "status"
>;
export const QUALITY_EVENT_SUMMARY_COLUMNS = "id, created_at, severity, title, description, status";

export type OperationsVisit = Pick<
  CareVisitRow,
  "id" | "case_id" | "visit_date" | "time_start" | "time_end" | "team_member_name" | "status" | "created_at"
> & { team_id: string | null };
export const OPERATIONS_VISIT_COLUMNS =
  "id, case_id, team_id, visit_date, time_start, time_end, team_member_name, status, created_at";

/** Exactly what is sent to the browser for /operations. */
export type OperationsDashboard = {
  cases: CaseSummaryRow[];
  teams: TeamRow[];
  visits: OperationsVisit[];
  qualityEvents: QualityEventSummary[];
  attentionItems: AttentionItem[];
};
