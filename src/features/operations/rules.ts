// Operations attention rules — pure TypeScript (ADR-002).
// No React, Next or Supabase imports allowed in this file.
//
// Status: IMPLEMENTED (legacy). Thresholds were taken unchanged from the
// recovered code and are NOT clinically or operationally validated
// (DOMAIN_RULES "Operations Attention"). Changing them needs product sign-off;
// tests in tests/unit/operations-rules.test.ts pin the current behaviour.

import type {
  AttentionItem,
  CareNoteStatus,
  OperationsVisit,
  PartnerRequestSummary,
  QualityEventSummary,
} from "./types";
import type { CaseSummaryRow } from "@/features/cases/types";
import type { TeamRow } from "@/features/teams/types";

export function getHoursSince(
  dateString: string | null | undefined,
  now: number = Date.now()
) {
  if (!dateString) return 0;

  const created = new Date(dateString).getTime();

  return Math.floor((now - created) / (1000 * 60 * 60));
}

export function buildAttentionItems({
  partnerRequests,
  cases,
  teams,
  visits,
  careNotes,
  qualityEvents,
  now = Date.now(),
}: {
  now?: number;
  partnerRequests: PartnerRequestSummary[];
  cases: CaseSummaryRow[];
  teams: TeamRow[];
  visits: Pick<OperationsVisit, "id" | "status" | "visit_date" | "team_member_name">[];
  careNotes: CareNoteStatus[];
  qualityEvents: QualityEventSummary[];
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
    const assignedTeamId = careCase.assigned_team_id;

    const hoursOpen = getHoursSince(careCase.created_at, now);
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
    const hoursOpen = getHoursSince(request.created_at, now);

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
