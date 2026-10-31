import "server-only";

import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import type { Database } from "@/lib/supabase/database.types";

export type AlertCategory = Database["public"]["Functions"]["active_safety_alert_categories"]["Returns"][number];

/** DOOR1-2/-4: the active safety-alert categories for the record form (labels only, no values; migration 0073). */
export async function getActiveAlertCategories(): Promise<AlertCategory[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("active_safety_alert_categories");
  if (error) {
    logEvent("error", "door.categories_load_failed", errorFields(error));
    return [];
  }
  return data ?? [];
}
