import "server-only";

import type { Database } from "@/lib/supabase/database.types";
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";

export type PlanStatus = Database["public"]["Functions"]["team_plan_status"]["Returns"][number];

/**
 * PLAN2: keeps the four-week window current for the caller's cases that were not generated today
 * (the daily database job does the same; this covers environments without pg_cron), then reads the status.
 */
export async function getPlanStatus(): Promise<PlanStatus[]> {
  const { supabase } = await requireUser();
  const refreshed = await supabase.rpc("refresh_team_plans");
  if (refreshed.error) logEvent("warn", "planning.refresh_failed", errorFields(refreshed.error));
  const { data, error } = await supabase.rpc("team_plan_status");
  if (error) {
    logEvent("error", "planning.status_load_failed", errorFields(error));
    throw new Error("Planungsstatus konnte nicht geladen werden.");
  }
  return data ?? [];
}
