"use server";

// BK-f (contract 2026-11-20 06:39 point 2 (f); migration 0156): «Bestätigen und senden» and «Neu prüfen». The database
// checks that the caller is an active member of the take team, records who confirmed and writes one audit row. «Gesendet»
// means the client reads the invoice in the portal; no PDF, no payment (R-12, FE-078).
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";

const sendFields = z.object({ draftId: z.uuid(), idempotencyKey: z.uuid() });
const buildFields = z.object({ reportId: z.uuid(), idempotencyKey: z.uuid() });

export type InvoiceCommandResult = { ok: true; state?: string | null; reason?: string | null } | { ok: false; error: string };

type Rpc = (fn: string, args?: Record<string, unknown>) => PromiseLike<{ data: unknown; error: { message: string } | null }>;

export async function sendTeamInvoiceDraft(input: unknown): Promise<InvoiceCommandResult> {
  const p = sendFields.safeParse(input);
  if (!p.success) return { ok: false, error: "Bitte erneut versuchen." };
  const { supabase } = await requireUser();
  const { data, error } = await (supabase.rpc as unknown as Rpc)("send_team_invoice_draft", {
    p_draft_id: p.data.draftId,
    p_idempotency_key: p.data.idempotencyKey,
  });
  if (error) {
    logEvent("warn", "command.failed", { op: "send_team_invoice_draft", ...errorFields(error) });
    return { ok: false, error: "Senden fehlgeschlagen." };
  }
  const r = (data ?? {}) as { result?: string; reason?: string };
  if (r.result === "ok" || r.result === "duplicate") {
    revalidatePath("/team");
    return { ok: true, state: "sent" };
  }
  if (r.reason === "not_draft") return { ok: false, error: "Diese Rechnung ist schon gesendet oder ungültig." };
  return { ok: false, error: "Nur ein Mitglied des Teams, das die Schicht übernommen hat, kann senden." };
}

export async function rebuildTeamInvoiceDraft(input: unknown): Promise<InvoiceCommandResult> {
  const p = buildFields.safeParse(input);
  if (!p.success) return { ok: false, error: "Bitte erneut versuchen." };
  const { supabase } = await requireUser();
  const { data, error } = await (supabase.rpc as unknown as Rpc)("build_team_invoice_draft", {
    p_report_id: p.data.reportId,
    p_idempotency_key: p.data.idempotencyKey,
  });
  if (error) {
    logEvent("warn", "command.failed", { op: "build_team_invoice_draft", ...errorFields(error) });
    return { ok: false, error: "Prüfen fehlgeschlagen." };
  }
  const r = (data ?? {}) as { result?: string; state?: string | null; reason?: string | null };
  if (r.result === "ok" || r.result === "duplicate") {
    revalidatePath("/team");
    revalidatePath("/field");
    return { ok: true, state: r.state ?? null, reason: r.reason ?? null };
  }
  return { ok: false, error: "Nur ein Mitglied des Teams, das die Schicht übernommen hat, kann das prüfen." };
}
