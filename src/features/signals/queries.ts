import "server-only";

import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import type { EvaluatorHealth, SignalRow } from "./rules";

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
