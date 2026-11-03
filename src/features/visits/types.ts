import { todayInZurich } from "@/features/field/rules";
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

/** UX2-29 (ADR-132): one word per concept for the responsible member on every screen (as `/field` and `/team`). */
export const RESPONSIBLE_LABEL = "Verantwortlich";
export const RESPONSIBLE_NOBODY_TEXT = "noch niemand";
/**
 * UX2-29 as amended po 2026-11-03 06:30 (`cra` CGR-109, G-25 (c); ADR-132 addendum): an empty responsible member on a
 * visit no longer open. A past-tense text that claims no absence; who performed the visit stays on its report.
 */
export const RESPONSIBLE_NOT_RECORDED_TEXT = "nicht erfasst";
/** UXR-79 with UX2-29: the one placeholder of both responsible-member pickers (look-back, Vorschläge). */
export const RESPONSIBLE_PICK_TEXT = "Verantwortliche Person wählen";

/** The statuses of a visit that is still open (UX2-29 amendment); every other status, or none, is no longer open. */
export const OPEN_VISIT_STATUSES: readonly string[] = ["planned", "on_the_way", "started", "paused"];

/**
 * A visit is still open when it is dated today or later (Europe/Zurich) and its status is one of
 * `OPEN_VISIT_STATUSES`. A visit without a date is judged by its status only (nothing is dated before today).
 */
export function isVisitStillOpen(
  visit: { visit_date: string | null; status: string | null },
  today: string = todayInZurich()
): boolean {
  if (!visit.status || !OPEN_VISIT_STATUSES.includes(visit.status)) return false;
  const date = visit.visit_date?.slice(0, 10);
  return !date || date >= today;
}

/** The text for an empty responsible member: "noch niemand" while the visit is open, else "nicht erfasst". */
export function responsibleEmptyText(visit: { visit_date: string | null; status: string | null }, today: string = todayInZurich()) {
  return isVisitStillOpen(visit, today) ? RESPONSIBLE_NOBODY_TEXT : RESPONSIBLE_NOT_RECORDED_TEXT;
}

/**
 * RLS4-6 (ADR-122): who is responsible for the visit, from `responsible_user_id` (the legacy free-text
 * `team_member_name` is no longer read and no past visit is mapped). Empty: `responsibleEmptyText` (UX2-29 amended);
 * "Teammitglied" when the responsible member has no display name recorded.
 */
export function getVisitResponsibleLabel(
  visit: Pick<CareVisitRow, "responsible_user_id" | "responsible_name" | "visit_date" | "status">,
  today: string = todayInZurich()
) {
  if (!visit.responsible_user_id) return responsibleEmptyText(visit, today);
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
