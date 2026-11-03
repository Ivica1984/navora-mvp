"use server";

// AIG1 part (b) (ADR-129): the confirm commands of the proposal screen. The database decides (migration 0097, 0103):
// confirm_suggestion confirms, changes or rejects ONE value (a "nicht gefunden" proposal only as "nicht gefunden");
// confirm_suggestions confirms an explicit ticked list, only of bulk-eligible values (AIG1-5), and runs the consuming
// command's checks per value. Both are audited and idempotent.

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import { refusalText } from "./labels";

/** A value the consuming command refused in a ticked confirm: its suggestion id (one she sent) and the reason text. */
export type RefusedValue = { id: string; text: string };

export type ConfirmResult = { ok: true; confirmed?: number; refused?: RefusedValue[] } | { ok: false; error: string };

const MESSAGES = {
  invalid: "Ungültige Eingabe.",
  rejected: "Nicht gespeichert: Dieser Vorschlag ist nicht mehr offen oder nicht in deinem Team.",
  bulk: "Nicht gespeichert: Diese Werte werden einzeln bestätigt.",
  failed: "Konnte nicht gespeichert werden.",
};

const one = z.object({
  suggestionId: z.uuid(),
  outcome: z.enum(["confirmed", "corrected", "rejected", "not_found"]),
  // Only a member id for the one field with a consuming command (responsible member); null otherwise.
  value: z.uuid().nullable(),
  idempotencyKey: z.uuid(),
});

function asObject(data: unknown): Record<string, unknown> {
  return data && typeof data === "object" && !Array.isArray(data) ? (data as Record<string, unknown>) : {};
}

export async function confirmSuggestion(input: unknown): Promise<ConfirmResult> {
  const parsed = one.safeParse(input);
  if (!parsed.success) return { ok: false, error: MESSAGES.invalid };
  const { suggestionId, outcome, value, idempotencyKey } = parsed.data;
  if ((outcome === "corrected") !== (value !== null)) return { ok: false, error: MESSAGES.invalid };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("confirm_suggestion", {
    p_suggestion_id: suggestionId,
    p_outcome: outcome,
    // A correction carries the chosen member's id; everything else no value (the proposal stays in the ledger).
    p_value: value,
    p_idempotency_key: idempotencyKey,
  });
  if (error) {
    logEvent("warn", "command.failed", { op: "confirm_suggestion", ...errorFields(error) });
    return { ok: false, error: error.code === "22023" ? MESSAGES.invalid : MESSAGES.failed };
  }
  const r = asObject(data);
  if (r.result === "ok" || r.result === "duplicate") {
    revalidatePath("/team/vorschlaege");
    revalidatePath("/visits/[visitId]", "page");
    revalidatePath("/operations/assistenten/rueckblick/[stopId]", "page");
    return { ok: true };
  }
  if (r.result === "refused") return { ok: false, error: refusalText(typeof r.reason === "string" ? r.reason : null) };
  return { ok: false, error: r.result === "rejected" ? MESSAGES.rejected : MESSAGES.failed };
}

const many = z.object({
  suggestionIds: z.array(z.uuid()).min(1).max(200),
  idempotencyKey: z.uuid(),
});

export async function confirmSuggestions(input: unknown): Promise<ConfirmResult> {
  const parsed = many.safeParse(input);
  if (!parsed.success || new Set(parsed.data.suggestionIds).size !== parsed.data.suggestionIds.length) {
    return { ok: false, error: MESSAGES.invalid };
  }
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("confirm_suggestions", {
    p_suggestion_ids: parsed.data.suggestionIds,
    p_idempotency_key: parsed.data.idempotencyKey,
  });
  if (error) {
    logEvent("warn", "command.failed", { op: "confirm_suggestions", ...errorFields(error) });
    if (error.code === "42501") return { ok: false, error: MESSAGES.bulk };
    return { ok: false, error: error.code === "22023" ? MESSAGES.invalid : MESSAGES.failed };
  }
  const r = asObject(data);
  if (r.result === "ok" || r.result === "duplicate") {
    revalidatePath("/team/vorschlaege");
    // AIG1-C3 (2) / UXR-66: confirm_suggestions returns each refused id (one she sent) with its reason, so the screen
    // keeps the reason on that line. Only ids from her own list are kept.
    const sent = new Set(parsed.data.suggestionIds);
    const refused: RefusedValue[] = Array.isArray(r.refused)
      ? r.refused
          .map((x) => asObject(x))
          .filter((x) => typeof x.suggestion_id === "string" && sent.has(x.suggestion_id))
          .map((x) => ({
            id: x.suggestion_id as string,
            text: refusalText(typeof x.reason === "string" ? x.reason : null),
          }))
      : [];
    return { ok: true, confirmed: typeof r.confirmed === "number" ? r.confirmed : undefined, refused };
  }
  return { ok: false, error: r.result === "rejected" ? MESSAGES.rejected : MESSAGES.failed };
}
