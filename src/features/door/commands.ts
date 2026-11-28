"use server";

// DOOR1-3 (migration 0073, ADR-086): record a safety-alert value. The database checks who may record (the case's team, or
// admin/operations at intake), validates, refuses a code-like note (NV004), is idempotent and audits without the note.

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import type { CommandResult } from "@/lib/commands/result";
import { errorFields, logEvent } from "@/lib/log";
import { ALERT_NOTE_MAX, ALERT_SOURCES, ALERT_VALUES, CODE_REFUSED, alertValueError } from "./rules";

const schema = z.object({
  caseId: z.uuid(),
  category: z.string().regex(/^[a-z][a-z0-9_]{2,40}$/),
  value: z.enum(ALERT_VALUES),
  note: z.string().trim().max(ALERT_NOTE_MAX),
  source: z.enum(ALERT_SOURCES),
  refusesCodes: z.boolean(),
  idempotencyKey: z.uuid(),
});

export async function recordSafetyAlertValue(input: unknown): Promise<CommandResult> {
  const p = schema.safeParse(input);
  if (!p.success) return { ok: false, error: "Ungültige Eingabe." };
  const invalid = alertValueError(p.data.value, p.data.note, p.data.refusesCodes);
  if (invalid) return { ok: false, error: invalid };

  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("record_safety_alert_value", {
    p_case_id: p.data.caseId,
    p_category: p.data.category,
    p_value: p.data.value,
    p_note: (p.data.note || null) as string,
    p_source: p.data.source,
    p_idempotency_key: p.data.idempotencyKey,
  });
  if (error) {
    // Never log the note (it may name a person or, despite the guard, a code).
    logEvent("warn", "command.failed", { op: "record_safety_alert_value", ...errorFields(error) });
    if (error.code === "NV004") return { ok: false, error: CODE_REFUSED };
    return { ok: false, error: error.code === "22023" ? "Ungültige Eingabe." : "Speichern fehlgeschlagen." };
  }
  if (data === "rejected") return { ok: false, error: "Nicht gespeichert: nur das Team des Falls oder die Aufnahme (Admin/Operations)." };
  if (data !== "ok" && data !== "duplicate") return { ok: false, error: "Speichern fehlgeschlagen." };
  revalidatePath("/field");
  revalidatePath("/intake");
  return { ok: true };
}
