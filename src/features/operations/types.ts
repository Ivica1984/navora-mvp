import type { CaseRow } from "@/features/cases/types";
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

export type MatchingRequestRow = {
  id: string;
  created_at: string;
  case_id: string | null;
  request_title: string;
  region: string;
  urgency: string;
  required_services: string[] | null;
  status: string;
  selected_team_id: string | null;
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

export type OperationsKpis = {
  openPartnerRequests: number;
  urgentPartnerRequests: number;
  newCases: number;
  teamDecisionCases: number;
  activeCases: number;
  activeTeams: number;
  overloadedTeams: number;
  openSlots: number;
  plannedVisits: number;
  activeVisits: number;
  completedVisits: number;
  openCareNotes: number;
  openQualityEvents: number;
};

export type OperationsDashboard = {
  partnerRequests: PartnerRequestRow[];
  cases: CaseRow[];
  teams: TeamRow[];
  matchingRequests: MatchingRequestRow[];
  visits: CareVisitRow[];
  careNotes: CareNoteRow[];
  qualityEvents: QualityEventRow[];
  kpis: OperationsKpis;
  attentionItems: AttentionItem[];
};
