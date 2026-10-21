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
  | string;

export type CareVisitRow = {
  id: string;
  case_id: string | null;
  visit_date: string | null;
  time_start: string | null;
  time_end: string | null;
  team_member_name: string | null;
  services_provided: string[] | null;
  notes: string | null;
  billable: boolean | null;
  status: VisitStatus | null;
  created_at: string;
};

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

  return status || "Unbekannt";
}
