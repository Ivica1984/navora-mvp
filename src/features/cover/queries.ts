import "server-only";

import type { Database } from "@/lib/supabase/database.types";
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";

type Fn = Database["public"]["Functions"];
export type CoverOffer = Fn["cover_offers"]["Returns"][number];
export type MyCover = Fn["my_covers"]["Returns"][number];

/** COVER1: records new offers and expiries (OPS1 sync pattern), then reads the caller's offers and accepted covers. */
export async function getCover(): Promise<{ offers: CoverOffer[]; mine: MyCover[] }> {
  const { supabase } = await requireUser();
  const synced = await supabase.rpc("sync_cover_offers");
  if (synced.error) logEvent("warn", "cover.sync_failed", errorFields(synced.error));
  const [offers, mine] = await Promise.all([supabase.rpc("cover_offers"), supabase.rpc("my_covers")]);
  for (const r of [offers, mine]) {
    if (r.error) {
      logEvent("error", "cover.load_failed", errorFields(r.error));
      throw new Error("Übernahme-Angebote konnten nicht geladen werden.");
    }
  }
  return { offers: offers.data ?? [], mine: mine.data ?? [] };
}
