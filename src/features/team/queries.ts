import "server-only";

import type { Database } from "@/lib/supabase/database.types";
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";

export type TeamOffer = Database["public"]["Functions"]["team_offers"]["Returns"][number];

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
