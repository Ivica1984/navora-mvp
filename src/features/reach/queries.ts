import "server-only";

// BK-b1s (AUT-117 (c), ADR-195 addendum 11:10): readers of the team's reach screen. The reach comes only from
// `my_team_reach` (migration 0131: the caller's own teams, an active member only, LEAVE1-3); the postcode list is the
// reference table `postcodes` (places only, P-8). Nothing here widens a read.

import { requireUser } from "@/lib/auth/session";
import type { Database } from "@/lib/supabase/database.types";
import { errorFields, logEvent } from "@/lib/log";

export type TeamReach = Database["public"]["Functions"]["my_team_reach"]["Returns"][number];
export type PostcodeOption = { postcode: string; place_name: string; region_name: string };

export async function getMyTeamReach(): Promise<TeamReach[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("my_team_reach");
  if (error) {
    logEvent("error", "bk_b1s.my_team_reach_failed", errorFields(error));
    throw new Error("Einsatzgebiet konnte nicht geladen werden.");
  }
  return data ?? [];
}

export async function getPostcodeOptions(): Promise<PostcodeOption[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase
    .from("postcodes")
    .select("postcode, place_name, region_name")
    .order("postcode");
  if (error) {
    logEvent("error", "bk_b1s.postcodes_failed", errorFields(error));
    throw new Error("PLZ-Liste konnte nicht geladen werden.");
  }
  return data ?? [];
}
