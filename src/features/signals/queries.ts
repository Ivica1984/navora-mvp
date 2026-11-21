import "server-only";

import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import type { EvaluatorHealth, OutsideWatchedVisit, SignalRow } from "./rules";

/**
 * SIG1-3: the caller's open P1 safety signals for the first render (public.my_signals, pgTAP 062). A failure never
 * blocks the page: the banner then starts empty and the poll retries.
 */
export async function getMySignals(): Promise<SignalRow[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("my_signals");
  if (error) {
    logEvent("error", "signals.load_failed", errorFields(error));
    return [];
  }
  return (data ?? []) as SignalRow[];
}

/**
 * SIG2-11 (0064): the scheduled evaluator's health for the caller's organisations in which she is Operations or an
 * administrator (public.signal_evaluator_health, pgTAP 064). A failure never blocks the page and shows no warning.
 */
export async function getSignalEvaluatorHealth(): Promise<EvaluatorHealth[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("signal_evaluator_health");
  if (error) {
    logEvent("error", "signals.evaluator_health_failed", errorFields(error));
    return [];
  }
  return (data ?? []) as EvaluatorHealth[];
}

/**
 * SIG2-C1 (2) (0068, pgTAP 069): planned visits of the next 7 days outside the watched hours. `ownTeams = false`
 * (/admin): administrators get their organisation; `ownTeams = true` (/team): the caller's own teams (decided by the
 * database). A failure never blocks the page; the
 * section then says it could not be loaded instead of showing an empty list.
 */
export async function getVisitsOutsideWatchedHours(ownTeams: boolean): Promise<OutsideWatchedVisit[] | null> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("visits_outside_watched_hours", { p_own_teams: ownTeams });
  if (error) {
    logEvent("error", "signals.outside_watched_failed", errorFields(error));
    return null;
  }
  return (data ?? []) as OutsideWatchedVisit[];
}
