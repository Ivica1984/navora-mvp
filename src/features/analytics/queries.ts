import "server-only";

import type { Database } from "@/lib/supabase/database.types";
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";

export type KpiRow = Database["public"]["Functions"]["pilot_kpis"]["Returns"][number];
export type HypothesisRow = Database["public"]["Functions"]["pilot_hypotheses"]["Returns"][number];

/** AN1: aggregated pilot KPIs for one month (organisation and teams; never per nurse). Scope is enforced in the database. */
export async function getPilotKpis(month: string): Promise<KpiRow[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("pilot_kpis", { p_month: month });
  if (error) {
    logEvent("error", "analytics.kpis_load_failed", errorFields(error));
    throw new Error("Kennzahlen konnten nicht geladen werden.");
  }
  return data ?? [];
}

/** AN2: pilot hypotheses measured from events for one month (same scope and suppression as AN1). */
export async function getPilotHypotheses(month: string): Promise<HypothesisRow[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("pilot_hypotheses", { p_month: month });
  if (error) {
    logEvent("error", "analytics.hypotheses_load_failed", errorFields(error));
    throw new Error("Pilot-Hypothesen konnten nicht geladen werden.");
  }
  return data ?? [];
}
