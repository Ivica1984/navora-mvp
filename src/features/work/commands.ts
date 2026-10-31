"use server";

// WORK1 (migration 0079, ADR-092): acknowledge the information text, confirm or correct her day, export her month.
// The database decides everything again (only for herself, both questions answered, versions, audit, idempotency).

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import { CONFIRM_MESSAGES, INVALID_FIELD, NOTICE_VERSION, buildCsv, type MonthExport } from "./rules";

const key = z.uuid();
const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);

export async function acknowledgeWorkingTimeNotice(input: unknown): Promise<{ ok: boolean; message: string }> {
  const p = z.object({ idempotencyKey: key }).safeParse(input);
  if (!p.success) return { ok: false, message: CONFIRM_MESSAGES.invalid };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("acknowledge_working_time_notice", {
    p_text_version: NOTICE_VERSION, p_idempotency_key: p.data.idempotencyKey,
  });
  if (error) {
    logEvent("warn", "command.failed", { op: "acknowledge_working_time_notice", ...errorFields(error) });
    return { ok: false, message: CONFIRM_MESSAGES.failed };
  }
  const code = String((data as { result?: unknown } | null)?.result ?? "failed");
  revalidatePath("/work");
  return { ok: ["ok", "duplicate", "unchanged"].includes(code), message: code === "invalid" ? "Der Informationstext ist veraltet. Bitte Seite neu laden." : "" };
}

export async function confirmWorkingDay(input: unknown): Promise<{ ok: boolean; code: string; message: string; open?: string[] }> {
  const p = z.object({ day: isoDate, payload: z.record(z.string(), z.unknown()), idempotencyKey: key }).safeParse(input);
  if (!p.success) return { ok: false, code: "invalid", message: CONFIRM_MESSAGES.invalid };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("confirm_working_day", {
    p_date: p.data.day, p_payload: p.data.payload as never, p_idempotency_key: p.data.idempotencyKey,
  });
  if (error) {
    logEvent("warn", "command.failed", { op: "confirm_working_day", ...errorFields(error) });
    return { ok: false, code: "failed", message: CONFIRM_MESSAGES.failed };
  }
  const r = (data ?? {}) as { result?: string; field?: string; open?: string[] };
  const code = String(r.result ?? "failed");
  if (code === "ok") revalidatePath("/work");
  const message = code === "invalid" && r.field && INVALID_FIELD[r.field] ? INVALID_FIELD[r.field] : CONFIRM_MESSAGES[code] ?? CONFIRM_MESSAGES.failed;
  return { ok: code === "ok" || code === "duplicate", code, message, open: r.open };
}

/** WORK1-4: her confirmed month as CSV text (built here, never stored; the database audits the export). */
export async function exportWorkingMonth(input: unknown): Promise<{ ok: true; filename: string; csv: string } | { ok: false; message: string }> {
  const p = z.object({ month: z.string().regex(/^\d{4}-\d{2}$/), idempotencyKey: key }).safeParse(input);
  if (!p.success) return { ok: false, message: "Ungültiger Monat." };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("export_working_month", {
    p_month: `${p.data.month}-01`, p_idempotency_key: p.data.idempotencyKey,
  });
  if (error) {
    logEvent("warn", "command.failed", { op: "export_working_month", ...errorFields(error) });
    return { ok: false, message: "Export fehlgeschlagen." };
  }
  const r = (data ?? {}) as Partial<MonthExport> & { result?: string };
  if (r.result !== "ok" && r.result !== "duplicate") return { ok: false, message: "Export nicht möglich." };
  const csv = buildCsv({ month: String(r.month), days: r.days ?? [], unconfirmed: r.unconfirmed ?? [] });
  revalidatePath("/work");  // WORK1-C3 (d): her unexported-days count changes with the export
  return { ok: true, filename: `navora-arbeitszeit-${r.month}.csv`, csv };
}
