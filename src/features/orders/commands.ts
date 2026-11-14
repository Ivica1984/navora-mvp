"use server";

// BK-a (ADR-194): preview (writes nothing) and «Bestätigen & Absenden» (the only write). The database checks that the
// caller is a member of the client account, re-runs every check and refuses anybody else (BK-1n).
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import { CLIENT_ORDER_PATH, orderProblemText } from "./rules";

const time = z.string().regex(/^\d{2}:\d{2}$/);
const fields = z.object({
  clientAccountId: z.uuid(),
  startDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable(),
  startTime: time.nullable(),
  endTime: time.nullable(),
  postcode: z.string().regex(/^\d{4}$/).nullable(),
  grade: z.string().max(40).nullable(),
  activityTags: z.array(z.string().max(20)).max(40),
  requiredTags: z.array(z.string().max(20)).max(40),
  radiusKm: z.number().positive().max(500).nullable(),
});

export type OrderFields = z.infer<typeof fields>;

export type OrderPreview = {
  problems: string[];
  sentence: string | null;
  shiftLabel: string | null;
  weekend: boolean | null;
  durationMinutes: number | null;
  /** BK-b1 / CGR-217: information items, never a block. */
  info: string[];
  sameOrderSentence: string | null;
};

function args(f: OrderFields) {
  return {
    p_client_account_id: f.clientAccountId,
    p_start_date: f.startDate as string,
    p_start_time: f.startTime as string,
    p_end_time: f.endTime as string,
    p_postcode: f.postcode as string,
    p_grade: f.grade as string,
    p_activity_tags: f.activityTags,
    p_required_tags: f.requiredTags,
    p_radius_km: f.radiusKm as number,
  };
}

type PreviewRow = {
  problems?: string[];
  sentence?: string | null;
  shift_label?: string | null;
  weekend?: boolean | null;
  duration_minutes?: number | null;
  info?: string[];
  same_order_sentence?: string | null;
};

export async function previewClientOrder(input: unknown): Promise<{ ok: true; preview: OrderPreview } | { ok: false; error: string }> {
  const p = fields.safeParse(input);
  if (!p.success) return { ok: false, error: "Bitte die Angaben prüfen." };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("preview_client_order", args(p.data));
  if (error) {
    logEvent("warn", "command.failed", { op: "preview_client_order", ...errorFields(error) });
    return { ok: false, error: "Vorschau fehlgeschlagen." };
  }
  const r = (data ?? {}) as PreviewRow;
  return {
    ok: true,
    preview: {
      problems: r.problems ?? [],
      sentence: r.sentence ?? null,
      shiftLabel: r.shift_label ?? null,
      weekend: r.weekend ?? null,
      durationMinutes: r.duration_minutes ?? null,
      info: r.info ?? [],
      sameOrderSentence: r.same_order_sentence ?? null,
    },
  };
}

export async function confirmClientOrder(
  input: unknown,
): Promise<{ ok: true } | { ok: false; error: string; problems?: string[] }> {
  const p = fields.extend({ idempotencyKey: z.uuid() }).safeParse(input);
  if (!p.success) return { ok: false, error: "Bitte die Angaben prüfen." };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("confirm_client_order", {
    ...args(p.data),
    p_idempotency_key: p.data.idempotencyKey,
  });
  if (error) {
    logEvent("warn", "command.failed", { op: "confirm_client_order", ...errorFields(error) });
    return { ok: false, error: "Absenden fehlgeschlagen." };
  }
  const r = (data ?? {}) as { result?: string; problems?: string[] };
  if (r.result === "ok" || r.result === "duplicate") {
    revalidatePath(CLIENT_ORDER_PATH);
    return { ok: true };
  }
  if (r.result === "invalid") {
    const problems = r.problems ?? [];
    return { ok: false, error: problems.map(orderProblemText).join(" "), problems };
  }
  return { ok: false, error: orderProblemText("not_client") };
}
