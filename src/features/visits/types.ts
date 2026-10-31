import type { TableRow } from "@/lib/supabase/tables";

export type VisitStatus =
  | "planned"
  | "assigned"
  | "accepted"
  | "on_the_way"
  | "started"
  | "paused"
  | "completed"
  | "cancelled"
  | "no_show"
  | "interrupted"
  | string;

/** Columns selected by getCareVisits() for /visits, plus the responsible member's display name (RLS4-6). */
export type CareVisitRow = Pick<
  TableRow<"care_visits">,
  | "id"
  | "case_id"
  | "visit_date"
  | "time_start"
  | "time_end"
  | "responsible_user_id"
  | "services_provided"
  | "notes"
  | "billable"
  | "status"
  | "created_at"
> & { responsible_name: string | null };

/**
 * RLS4-6 (ADR-122): who is responsible for the visit, from `responsible_user_id` (the legacy free-text
 * `team_member_name` is no longer read). "Noch offen" when nobody is responsible; "Teammitglied" when the
 * responsible member has no display name recorded.
 */
export function getVisitResponsibleLabel(visit: Pick<CareVisitRow, "responsible_user_id" | "responsible_name">) {
  if (!visit.responsible_user_id) return "Noch offen";
  const name = visit.responsible_name?.trim();
  return name ? name : "Teammitglied";
}

export function getVisitTimeRange(visit: CareVisitRow) {
  if (visit.time_start && visit.time_end) {
    return `${visit.time_start} – ${visit.time_end}`;
  }

  if (visit.time_start) {
    return `ab ${visit.time_start}`;
  }

  return "Zeit offen";
}

export function getVisitServices(visit: CareVisitRow) {
  if (
    Array.isArray(visit.services_provided) &&
    visit.services_provided.length > 0
  ) {
    return visit.services_provided.join(", ");
  }

  return "Leistungen noch nicht erfasst";
}

export function getVisitStatusLabel(status: string | null) {
  if (status === "planned") return "Geplant";
  if (status === "assigned") return "Zugewiesen";
  if (status === "accepted") return "Angenommen";
  if (status === "on_the_way") return "Unterwegs";
  if (status === "started") return "Gestartet";
  if (status === "paused") return "Pausiert";
  if (status === "completed") return "Abgeschlossen";
  if (status === "cancelled") return "Abgesagt";
  if (status === "no_show") return "Nicht angetroffen";
  if (status === "interrupted") return "Nicht abgeschlossen";

  return status || "Unbekannt";
}
