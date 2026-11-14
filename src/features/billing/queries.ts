import "server-only";

import type { Database } from "@/lib/supabase/database.types";
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";

export type BillingPreviewRow = Database["public"]["Functions"]["billing_preview"]["Returns"][number];

/** J5: monthly estimate per team (team members: own teams; coordination roles: organisation). */
export async function getBillingPreview(month: string): Promise<BillingPreviewRow[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("billing_preview", { p_month: month });
  if (error) {
    logEvent("error", "billing.preview_load_failed", errorFields(error));
    throw new Error("Abrechnungsvorschau konnte nicht geladen werden.");
  }
  return data ?? [];
}
