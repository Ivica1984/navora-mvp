import "server-only";

import type { Database } from "@/lib/supabase/database.types";
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import { loaded, unavailable, type AuxList } from "./aux-list";

export type TeamOffer = Database["public"]["Functions"]["team_offers"]["Returns"][number];
export type TeamCase = Database["public"]["Functions"]["team_cases"]["Returns"][number];
export type ContinuityRow = Database["public"]["Functions"]["continuity_by_case"]["Returns"][number];
export type TeamVisitAlert = Database["public"]["Functions"]["team_visit_alerts"]["Returns"][number];

/** Open matching requests offered to the caller's active teams (J2, public.team_offers, pgTAP 013). */
export async function getTeamOffers(): Promise<TeamOffer[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("team_offers");
  if (error) {
    logEvent("error", "team.offers_load_failed", errorFields(error));
    throw new Error("Anfragen konnten nicht geladen werden.");
  }
  return data ?? [];
}

/** Running cases of the caller's teams with upcoming visits (J3, public.team_cases, pgTAP 014). */
export async function getTeamCases(): Promise<TeamCase[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("team_cases");
  if (error) {
    logEvent("error", "team.cases_load_failed", errorFields(error));
    throw new Error("Fälle konnten nicht geladen werden.");
  }
  return data ?? [];
}

/** J6: continuity per client this month (team: own cases; coordination roles: organisation). Never per nurse. */
export async function getContinuity(month: string): Promise<ContinuityRow[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("continuity_by_case", { p_month: month });
  if (error) {
    logEvent("error", "team.continuity_load_failed", errorFields(error));
    throw new Error("Kontinuität konnte nicht geladen werden.");
  }
  return data ?? [];
}

/** CSR1 / CGR-04: overdue and stuck visits of the caller's teams (public.team_visit_alerts, pgTAP 038).
 * PERF1 (CGR-272): an auxiliary hint list, so a failed load degrades instead of throwing: the page keeps its day view
 * and commands and shows VISIT_ALERTS_UNAVAILABLE_NOTICE; the failure is logged and counted per team and day
 * (public.record_aux_list_failure → private.aux_list_failures, migration 0165). Never used for a safety list (CGR-273). */
export async function getTeamVisitAlerts(): Promise<AuxList<TeamVisitAlert>> {
  const { supabase } = await requireUser();
  try {
    const { data, error } = await supabase.rpc("team_visit_alerts");
    if (!error) return loaded(data);
    logEvent("error", "team.visit_alerts_unavailable", errorFields(error));
  } catch (e) {
    // A transport failure (no PostgREST answer) degrades the same way; its code only, never its message.
    logEvent("error", "team.visit_alerts_unavailable", errorFields(e));
  }
  // Best effort: the count must never take the page down either (its own failure is logged, not thrown).
  try {
    const counted = await supabase.rpc("record_aux_list_failure", { p_list: "team_visit_alerts" });
    if (counted.error) logEvent("warn", "team.visit_alerts_failure_not_counted", errorFields(counted.error));
  } catch (e) {
    logEvent("warn", "team.visit_alerts_failure_not_counted", errorFields(e));
  }
  return unavailable();
}
