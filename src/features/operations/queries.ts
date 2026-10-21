import { supabase } from "@/lib/supabase";
import { buildAttentionItems } from "./rules";
import type {
  CareNoteRow,
  MatchingRequestRow,
  OperationsDashboard,
  PartnerRequestRow,
  QualityEventRow,
} from "./types";
import type { CaseRow } from "@/features/cases/types";
import type { TeamRow } from "@/features/teams/types";
import type { CareVisitRow } from "@/features/visits/types";


export async function getOperationsDashboard(): Promise<OperationsDashboard> {
  const [
    partnerRequestsResult,
    casesResult,
    teamsResult,
    matchingRequestsResult,
    visitsResult,
    careNotesResult,
    qualityEventsResult,
  ] = await Promise.all([
    supabase
      .from("partner_requests")
      .select(
        `
        id,
        created_at,
        partner_name,
        partner_type,
        region,
        city,
        urgency,
        time_info,
        request_title,
        need_summary,
        requested_services,
        status,
        converted_case_id,
        notes
        `
      )
      .order("created_at", { ascending: false }),

    supabase
      .from("cases")
      .select(
        `
        id,
        created_at,
        name,
        region,
        status,
        bedarf,
        urgency,
        time_info,
        first_name,
        last_name,
        date_of_birth,
        gender,
        address,
        plz,
        ort,
        phone,
        emergency_contact_name,
        emergency_contact_phone,
        mobility_status,
        cognitive_status,
        diagnosis_tags,
        care_needs,
        care_level,
        referral_source,
        insurance_provider,
        start_date,
        next_step,
        notes,
        assigned_team,
        assigned_team_id
        `
      )
      .order("created_at", { ascending: false }),

    supabase
      .from("teams")
      .select(
        `
        id,
        name,
        region,
        care_focus,
        status,
        open_slots,
        utilization,
        lead_name,
        next_step,
        created_at,
        priority,
        coach_name
        `
      )
      .order("created_at", { ascending: true }),

    supabase
      .from("matching_requests")
      .select(
        `
        id,
        created_at,
        case_id,
        request_title,
        region,
        urgency,
        required_services,
        status,
        selected_team_id,
        notes
        `
      )
      .order("created_at", { ascending: false }),

    supabase
      .from("care_visits")
      .select(
        `
        id,
        case_id,
        visit_date,
        time_start,
        time_end,
        team_member_name,
        services_provided,
        notes,
        billable,
        status,
        created_at,
        team_id
        `
      )
      .order("visit_date", { ascending: true }),

    supabase
      .from("care_notes")
      .select(
        `
        id,
        created_at,
        visit_id,
        case_id,
        team_id,
        author_name,
        note_type,
        content,
        status
        `
      )
      .order("created_at", { ascending: false }),

    supabase
      .from("quality_events")
      .select(
        `
        id,
        created_at,
        case_id,
        visit_id,
        team_id,
        event_type,
        severity,
        title,
        description,
        status
        `
      )
      .order("created_at", { ascending: false }),
  ]);

  const results = [
    partnerRequestsResult,
    casesResult,
    teamsResult,
    matchingRequestsResult,
    visitsResult,
    careNotesResult,
    qualityEventsResult,
  ];

  const firstError = results.find((result) => result.error)?.error;

  if (firstError) {
    console.error("Error loading operations dashboard:", firstError);
    throw new Error("Operations Dashboard konnte nicht geladen werden.");
  }

  const partnerRequests = (partnerRequestsResult.data ?? []) as PartnerRequestRow[];
  const cases = (casesResult.data ?? []) as CaseRow[];
  const teams = (teamsResult.data ?? []) as TeamRow[];
  const matchingRequests = (matchingRequestsResult.data ??
    []) as MatchingRequestRow[];
  const visits = (visitsResult.data ?? []) as CareVisitRow[];
  const careNotes = (careNotesResult.data ?? []) as CareNoteRow[];
  const qualityEvents = (qualityEventsResult.data ?? []) as QualityEventRow[];

  const kpis = {
    openPartnerRequests: partnerRequests.filter((item) =>
      ["open", "ready_to_convert"].includes(item.status)
    ).length,
    urgentPartnerRequests: partnerRequests.filter(
      (item) => item.urgency === "hoch" || item.time_info === "Heute"
    ).length,
    newCases: cases.filter((item) => item.status === "neu").length,
    teamDecisionCases: cases.filter((item) => item.status === "teampruefung")
      .length,
    activeCases: cases.filter((item) => item.status === "laufend").length,
    activeTeams: teams.filter((item) => item.status === "active").length,
    overloadedTeams: teams.filter((item) => (item.utilization ?? 0) >= 90).length,
    openSlots: teams.reduce((sum, item) => sum + (item.open_slots ?? 0), 0),
    plannedVisits: visits.filter((item) => item.status === "planned").length,
    activeVisits: visits.filter(
      (item) => item.status === "started" || item.status === "on_the_way"
    ).length,
    completedVisits: visits.filter((item) => item.status === "completed").length,
    openCareNotes: careNotes.filter((item) =>
      ["draft", "submitted"].includes(item.status)
    ).length,
    openQualityEvents: qualityEvents.filter((item) => item.status === "open")
      .length,
  };

  const attentionItems = buildAttentionItems({
    partnerRequests,
    cases,
    teams,
    visits,
    careNotes,
    qualityEvents,
  });

  return {
    partnerRequests,
    cases,
    teams,
    matchingRequests,
    visits,
    careNotes,
    qualityEvents,
    kpis,
    attentionItems,
  };
}
