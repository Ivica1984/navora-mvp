import "server-only";

import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import type { Database } from "@/lib/supabase/database.types";
import type { FieldReport } from "./report";
import type { FieldNote, FieldVisit } from "./types";
import { teamsWithoutQualification } from "./qualification";

/**
 * Visits of the signed-in user's teams on one day (F1).
 * Scope and data minimisation live in the database: public.field_visits()
 * (migration 0006, SECURITY INVOKER, pgTAP 008).
 */
export async function getFieldVisits(day: string): Promise<FieldVisit[]> {
  const { supabase } = await requireUser();

  const { data, error } = await supabase.rpc("field_visits", { p_date: day });

  if (error) {
    logEvent("error", "field.load_failed", errorFields(error));
    throw new Error("Deine Einsätze konnten nicht geladen werden.");
  }

  return data ?? [];
}

/**
 * Observations of the day's visits and handover notes for them (F4).
 * Team-scoped by RLS on visit_observations; public.field_notes() (migration 0009, pgTAP 011).
 */
export async function getFieldNotes(day: string): Promise<FieldNote[]> {
  const { supabase } = await requireUser();

  const { data, error } = await supabase.rpc("field_notes", { p_date: day });

  if (error) {
    logEvent("error", "field.notes_load_failed", errorFields(error));
    throw new Error("Beobachtungen konnten nicht geladen werden.");
  }

  return data ?? [];
}

/**
 * Latest report version per visit of the day (F6). Team-scoped in the database:
 * public.field_reports() (migration 0016, pgTAP 016).
 */
export async function getFieldReports(day: string): Promise<FieldReport[]> {
  const { supabase } = await requireUser();

  const { data, error } = await supabase.rpc("field_reports", { p_date: day });

  if (error) {
    logEvent("error", "field.reports_load_failed", errorFields(error));
    throw new Error("Berichte konnten nicht geladen werden.");
  }

  return data ?? [];
}

export type CountersignItem = Database["public"]["Functions"]["field_countersign_queue"]["Returns"][number];

/** F7: reports of the caller's teams waiting for her countersignature, any date (registered nurses only). */
export async function getCountersignQueue(): Promise<CountersignItem[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("field_countersign_queue");
  if (error) {
    logEvent("error", "field.countersign_queue_failed", errorFields(error));
    throw new Error("Gegenzeichnungen konnten nicht geladen werden.");
  }
  return data ?? [];
}

export type ReturnedItem = Database["public"]["Functions"]["field_returned_reports"]["Returns"][number];

/** F6R-5: the caller's reports returned to her by a registered nurse, any date, until she signs again. */
export async function getReturnedReports(): Promise<ReturnedItem[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("field_returned_reports");
  if (error) {
    logEvent("error", "field.returned_reports_failed", errorFields(error));
    throw new Error("Zurückgegebene Berichte konnten nicht geladen werden.");
  }
  return data ?? [];
}

export type SinceLastRowDb = Database["public"]["Functions"]["field_since_last"]["Returns"][number];

/**
 * HAND1: everything recorded about each visit's client since the caller was last there.
 * Team-scoped and ordered in the database: public.field_since_last() (migration 0033, pgTAP 033).
 */
export async function getSinceLast(day: string): Promise<SinceLastRowDb[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("field_since_last", { p_date: day });
  if (error) {
    logEvent("error", "field.since_last_load_failed", errorFields(error));
    throw new Error("«Seit deinem letzten Einsatz» konnte nicht geladen werden.");
  }
  return data ?? [];
}

export type DoorNote = Database["public"]["Functions"]["field_door_notes"]["Returns"][number];

/**
 * DOOR1-1: access and language notes of the case of each visit of the day the user reads (her team's visits, or a
 * visit she covers while the cover runs). public.field_door_notes() (migration 0072, pgTAP 072). Display only.
 */
export async function getDoorNotes(day: string): Promise<DoorNote[]> {
  const { supabase } = await requireUser();

  const { data, error } = await supabase.rpc("field_door_notes", { p_date: day });

  if (error) {
    logEvent("error", "field.door_notes_load_failed", errorFields(error));
    throw new Error("Zugangs- und Sprachhinweise konnten nicht geladen werden.");
  }

  return data ?? [];
}

export type SafetyAlert = Database["public"]["Functions"]["field_safety_alerts"]["Returns"][number];

/**
 * DOOR1-3/-4: the latest safety-alert value per active category of each visit's case on that day (the team, or the
 * covering member while her cover runs). public.field_safety_alerts() (migration 0073, pgTAP 073). Display only.
 */
export async function getSafetyAlerts(day: string): Promise<SafetyAlert[]> {
  const { supabase } = await requireUser();

  const { data, error } = await supabase.rpc("field_safety_alerts", { p_date: day });

  if (error) {
    logEvent("error", "field.safety_alerts_load_failed", errorFields(error));
    throw new Error("Sicherheitshinweise konnten nicht geladen werden.");
  }

  return data ?? [];
}

export type SafetyAlertHistoryEntry = Database["public"]["Functions"]["field_safety_alert_history"]["Returns"][number];

/**
 * DOOR1-13: every value of the access arrangement of the day's cases (newest first), then the intake note as the
 * earliest entry (source referral). public.field_safety_alert_history() (migration 0080, pgTAP 080). Display only.
 */
export async function getSafetyAlertHistory(day: string): Promise<SafetyAlertHistoryEntry[]> {
  const { supabase } = await requireUser();

  const { data, error } = await supabase.rpc("field_safety_alert_history", { p_date: day });

  if (error) {
    logEvent("error", "field.safety_alert_history_load_failed", errorFields(error));
    throw new Error("Verlauf der Zugangsregelung konnte nicht geladen werden.");
  }

  return data ?? [];
}

export type TeamOpenReport = Database["public"]["Functions"]["team_open_reports"]["Returns"][number];

/**
 * LEAVE1-12 (1) (migration 0075): for a registered nurse, the members of her teams with open reports in that team,
 * counts by kind and the date an access ended. No content, no reason. Empty for everyone else.
 */
export async function getTeamOpenReports(): Promise<TeamOpenReport[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("team_open_reports");
  if (error) {
    logEvent("error", "field.team_open_reports_failed", errorFields(error));
    throw new Error("Offene Berichte im Team konnten nicht geladen werden.");
  }
  return data ?? [];
}

/**
 * UX2-22 (ADR-124): the teams in which the signed-in member's qualification is not yet recorded (ADM2-6 state). One
 * read of her own `team_memberships` rows (RLS `read_own_team_membership`, migration 0003; no new read scope, no
 * other member's row). The database refusal (ADM2-16, 0094) stays the guard; the screen only stops offering it.
 */
export async function getOwnQualificationGaps(): Promise<string[]> {
  const { supabase, user } = await requireUser();

  const { data, error } = await supabase.from("team_memberships").select("team_id, qualification").eq("user_id", user.id);

  if (error) {
    logEvent("error", "field.own_membership_load_failed", errorFields(error));
    throw new Error("Deine Teamzugehörigkeit konnte nicht geladen werden.");
  }

  return teamsWithoutQualification(data ?? []);
}
