import "server-only";

import type { Database } from "@/lib/supabase/database.types";
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";

export type FieldQuality = Database["public"]["Functions"]["field_quality"]["Returns"][number];
export type QualityEventType = { code: string; label: string };
export type OpenHold = { id: string; visit_id: string; reason: string; set_at: string };

/** Events and holds of the day's visits of the caller's teams (QG1, public.field_quality, pgTAP 020). */
export async function getFieldQuality(day: string): Promise<FieldQuality[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("field_quality", { p_date: day });
  if (error) {
    logEvent("error", "field.quality_load_failed", errorFields(error));
    throw new Error("Qualitätsangaben konnten nicht geladen werden.");
  }
  return data ?? [];
}

/** Clinically approved event types (D-16). Empty until the clinical list is approved. */
export async function getQualityEventTypes(): Promise<QualityEventType[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.from("quality_event_types").select("code, label").eq("active", true).order("label");
  if (error) {
    logEvent("error", "quality.types_load_failed", errorFields(error));
    return [];
  }
  return data ?? [];
}

/** Open holds the caller may see (team or coordination role; RLS, migration 0020). */
export async function getOpenHolds(): Promise<OpenHold[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase
    .from("quality_holds")
    .select("id, visit_id, reason, set_at")
    .is("lifted_at", null)
    .order("set_at", { ascending: true });
  if (error) {
    logEvent("error", "quality.holds_load_failed", errorFields(error));
    throw new Error("Qualitäts-Stopps konnten nicht geladen werden.");
  }
  return data ?? [];
}
