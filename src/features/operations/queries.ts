import { supabase } from "@/lib/supabase";
import type {
  AttentionItem,
  CareNoteRow,
  MatchingRequestRow,
  OperationsDashboard,
  PartnerRequestRow,
  QualityEventRow,
} from "./types";
import type { CaseRow } from "@/features/cases/types";
import type { TeamRow } from "@/features/teams/types";
import type { CareVisitRow } from "@/features/visits/types";


function getHoursSince(dateString: string | null | undefined) {
  if (!dateString) return 0;

  const created = new Date(dateString).getTime();
  const now = Date.now();

  return Math.floor((now - created) / (1000 * 60 * 60));
}

function buildAttentionItems({
  partnerRequests,
  cases,
  teams,
  visits,
  careNotes,
  qualityEvents,
}: {
  partnerRequests: PartnerRequestRow[];
  cases: CaseRow[];
  teams: TeamRow[];
  visits: CareVisitRow[];
  careNotes: CareNoteRow[];
  qualityEvents: QualityEventRow[];
}): AttentionItem[] {
  const items: AttentionItem[] = [];

  for (const team of teams) {
    const utilization = team.utilization ?? 0;
    const openSlots = team.open_slots ?? 0;

    if (utilization >= 90) {
      items.push({
        id: `team-overload-${team.id}`,
        priority: "P1",
        severity: "critical",
        category: "capacity",
        title: `${team.name} ist überlastet`,
        description: `${utilization}% Auslastung, ${openSlots} freie Slots.`,
        recommendedAction:
          "Keine neuen Klientenfälle zuweisen und Coach-Fokus prüfen.",
        entityType: "team",
        entityId: team.id,
      });
    } else if (utilization >= 80 || openSlots <= 1) {
      items.push({
        id: `team-attention-${team.id}`,
        priority: "P2",
        severity: "warning",
        category: "capacity",
        title: `${team.name} braucht Aufmerksamkeit`,
        description: `${utilization}% Auslastung, ${openSlots} freie Slots.`,
        recommendedAction:
          "Kapazität beobachten und neue Zuweisungen vorsichtig prüfen.",
        entityType: "team",
        entityId: team.id,
      });
    }
  }

  for (const careCase of cases) {
    const assignedTeamId = (careCase as any).assigned_team_id as
      | string
      | null
      | undefined;

    const hoursOpen = getHoursSince(careCase.created_at);
    const displayName = `${careCase.first_name ?? ""} ${
      careCase.last_name ?? ""
    }`.trim();

    if (!assignedTeamId && careCase.status !== "laufend") {
      items.push({
        id: `case-without-team-${careCase.id}`,
        priority:
          careCase.urgency === "hoch" || hoursOpen >= 24 ? "P1" : "P2",
        severity:
          careCase.urgency === "hoch" || hoursOpen >= 24
            ? "critical"
            : "warning",
        category: "case",
        title: `${displayName || "Klientenfall"} ohne Pflegeteam`,
        description: `${careCase.region ?? "Region offen"} · seit ${hoursOpen}h offen.`,
        recommendedAction:
          "Matching starten oder passendes Pflegeteam aktiv anfragen.",
        entityType: "case",
        entityId: careCase.id,
      });
    }

    if (careCase.status === "teampruefung") {
      items.push({
        id: `team-decision-${careCase.id}`,
        priority: hoursOpen >= 24 ? "P1" : "P2",
        severity: hoursOpen >= 24 ? "critical" : "warning",
        category: "matching",
        title: `${displayName || "Klientenfall"} wartet auf Teamentscheid`,
        description: `${careCase.region ?? "Region offen"} · seit ${hoursOpen}h im Prozess.`,
        recommendedAction:
          "Rückmeldung des vorgeschlagenen Pflegeteams prüfen.",
        entityType: "case",
        entityId: careCase.id,
      });
    }
  }

  for (const request of partnerRequests) {
    const hoursOpen = getHoursSince(request.created_at);

    if (["open", "ready_to_convert"].includes(request.status)) {
      items.push({
        id: `partner-request-${request.id}`,
        priority:
          request.urgency === "hoch" || hoursOpen >= 24 ? "P1" : "P2",
        severity:
          request.urgency === "hoch" || hoursOpen >= 24
            ? "critical"
            : "warning",
        category: "partner",
        title: `Partneranfrage: ${request.partner_name}`,
        description: `${request.region} · ${request.need_summary}`,
        recommendedAction:
          "Anfrage prüfen und bei Bedarf in Klientenfall umwandeln.",
        entityType: "partner_request",
        entityId: request.id,
      });
    }
  }

  for (const visit of visits) {
    if (visit.status === "completed") {
      const relatedNote = careNotes.find((note) => note.visit_id === visit.id);

      if (!relatedNote || ["draft", "submitted"].includes(relatedNote.status)) {
        items.push({
          id: `visit-report-${visit.id}`,
          priority: "P2",
          severity: "warning",
          category: "visit",
          title: "Abgeschlossener Pflegeeinsatz braucht Berichtprüfung",
          description: `${visit.visit_date ?? "Datum offen"} · ${
            visit.team_member_name ?? "Pflegekraft offen"
          }`,
          recommendedAction:
            "Bericht prüfen, freigeben oder Korrektur anfordern.",
          entityType: "visit",
          entityId: visit.id,
        });
      }
    }
  }

  for (const event of qualityEvents) {
    if (event.status === "open") {
      items.push({
        id: `quality-${event.id}`,
        priority:
          event.severity === "critical" || event.severity === "high"
            ? "P1"
            : "P2",
        severity:
          event.severity === "critical" || event.severity === "high"
            ? "critical"
            : "warning",
        category: "quality",
        title: event.title,
        description: event.description ?? "Offenes Qualitätsereignis.",
        recommendedAction:
          "Qualitätsereignis prüfen und Verantwortlichkeit klären.",
        entityType: "quality_event",
        entityId: event.id,
      });
    }
  }

  return items.sort((a, b) => {
    const order = { P1: 0, P2: 1, P3: 2 };
    return order[a.priority] - order[b.priority];
  });
}

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
