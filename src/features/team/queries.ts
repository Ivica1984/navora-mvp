import "server-only";

import type { Database } from "@/lib/supabase/database.types";
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";

export type TeamOffer = Database["public"]["Functions"]["team_offers"]["Returns"][number];
export type TeamCase = Database["public"]["Functions"]["team_cases"]["Returns"][number];

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
