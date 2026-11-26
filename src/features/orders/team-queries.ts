import "server-only";

// BK-c2 (ADR-200 (6)): the shift-order offers of the caller's teams on `/team`. The database decides every state
// (`team_order_offers()`, `order_take_candidates()`; RLS and LEAVE1-3 inside); this file only reads and words.
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import { teamOfferView, type TakeCandidateRow, type TeamOfferView, type TeamOrderOfferRow } from "./offer-rules";

export type TeamShiftOffer = { row: TeamOrderOfferRow; view: TeamOfferView };

/** ORDER-F1-F3 (c): the offer list fails alone. A database error (for example the statement timeout 57014) or a
 * transport failure is logged with its code (`orders.team_offers_failed`, as before, so the Render log still names it)
 * and returns `null`; `/team` then shows one line in the offer section, never a thrown page and never «no offer». */
export async function getTeamShiftOffers(): Promise<TeamShiftOffer[] | null> {
  const { supabase, user } = await requireUser();
  let rows: TeamOrderOfferRow[];
  try {
    const offers = await supabase.rpc("team_order_offers");
    if (offers.error) {
      logEvent("error", "orders.team_offers_failed", errorFields(offers.error));
      return null;
    }
    rows = (offers.data ?? []) as unknown as TeamOrderOfferRow[];
  } catch (e) {
    logEvent("error", "orders.team_offers_failed", errorFields(e));
    return null;
  }
  const candidates = new Map<string, TakeCandidateRow[]>();
  await Promise.all(
    rows
      .filter((r) => r.offer_state === "open")
      .map(async (r) => {
        const c = await supabase.rpc("order_take_candidates", { p_order_id: r.order_id, p_team_id: r.team_id });
        if (c.error) logEvent("warn", "orders.take_candidates_failed", errorFields(c.error));
        candidates.set(`${r.order_id}:${r.team_id}`, (c.data ?? []) as TakeCandidateRow[]);
      }),
  );
  const ids = new Set<string>();
  for (const r of rows) for (const id of [r.taken_member_id, r.taken_by, r.released_member_id]) if (id) ids.add(id);
  for (const list of candidates.values()) for (const c of list) ids.add(c.user_id);
  const names = new Map<string, string>();
  if (ids.size > 0) {
    const profiles = await supabase.from("member_profiles").select("user_id, display_name").in("user_id", [...ids]);
    if (profiles.error) logEvent("warn", "orders.team_names_failed", errorFields(profiles.error));
    for (const p of profiles.data ?? []) if (p.display_name) names.set(p.user_id, p.display_name);
  }
  const list = rows.map((row) => ({
    row,
    view: teamOfferView(row, user.id, names, candidates.get(`${row.order_id}:${row.team_id}`) ?? []),
  }));
  // Template §3 (UXR-221): the named person's own card that waits for her first, then by shift start.
  const waitsForMe = (o: TeamShiftOffer) => (o.view.kind === "taken" && o.view.actions ? 0 : 1);
  return list.sort((a, b) => waitsForMe(a) - waitsForMe(b) || a.row.starts_at.localeCompare(b.row.starts_at));
}
