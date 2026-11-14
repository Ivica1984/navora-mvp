"use server";

// BK-b1s (AUT-117 (a), (c); ADR-195 addendum 11:10): the team changes its own reach. The only write is
// `set_team_reach` (migration 0130): the database checks that the caller is an active member of that team (or an
// organisation admin for a team without active members), re-runs every check and writes one audit row with old and
// new values. A change applies to new orders only (AUT-117 (b), BK-2n).
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import { REACH_PATH } from "./rules";

const fields = z.object({
  teamId: z.uuid(),
  postcodes: z.array(z.string().max(10)).max(200),
  maxDistanceKm: z.number().finite().nullable(),
  idempotencyKey: z.uuid(),
});

export type SetReachResult =
  | { ok: true; changed: boolean }
  | { ok: false; problems: string[] }
  | { ok: false; error: string };

export async function setTeamReach(input: unknown): Promise<SetReachResult> {
  const p = fields.safeParse(input);
  if (!p.success) return { ok: false, error: "Bitte die Angaben prüfen." };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("set_team_reach", {
    p_team_id: p.data.teamId,
    p_postcodes: p.data.postcodes,
    // null reaches the database, which refuses it as `max_distance_not_positive` (the form decides nothing).
    p_max_distance_km: p.data.maxDistanceKm as number,
    p_idempotency_key: p.data.idempotencyKey,
  });
  if (error) {
    logEvent("warn", "command.failed", { op: "set_team_reach", ...errorFields(error) });
    return { ok: false, error: "Speichern fehlgeschlagen." };
  }
  const r = (data ?? {}) as { result?: string; problems?: string[]; changed?: boolean };
  if (r.result === "ok" || r.result === "duplicate") {
    revalidatePath(REACH_PATH);
    return { ok: true, changed: r.changed ?? false };
  }
  if (r.result === "invalid") return { ok: false, problems: r.problems ?? [] };
  return { ok: false, error: "Nur ein Mitglied dieses Teams kann sein Einsatzgebiet ändern." };
}
