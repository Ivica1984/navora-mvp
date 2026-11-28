import "server-only";

// ORD0-3 (migration 0061): "Hausärztin/Hausarzt informiert" records the caller may read (RLS: the case's team and
// coordinators of the organisation). Date and channel code only; no free text, no health data.

import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import type { GpNotice } from "./rules";

export async function getGpNotices(): Promise<GpNotice[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase
    .from("case_gp_notices")
    .select("case_id, informed_on, channel, recorded_at")
    .order("recorded_at", { ascending: false })
    .limit(500);
  if (error) {
    logEvent("error", "gp.notices_load_failed", errorFields(error));
    throw new Error("Angaben zur Hausärztin/zum Hausarzt konnten nicht geladen werden.");
  }
  return data ?? [];
}
