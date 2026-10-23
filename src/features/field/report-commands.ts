"use server";

// F6: signed visit report (migration 0016). The database checks team, performer, registered nurse
// for countersignature, immutability after signing and the correction reason.

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import type { CommandResult } from "@/lib/commands/result";
import { errorFields, logEvent } from "@/lib/log";
import { reportRejectionMessage } from "./report";

const summary = z.string().trim().max(4000).nullable();
const key = z.uuid();

const schemas = {
  create: z.object({ visitId: z.uuid(), summary, idempotencyKey: key }),
  edit: z.object({ reportId: z.uuid(), summary, idempotencyKey: key }),
  // CSR1 / CGR-02 (0041): the hash of the snapshot shown (field_reports.snapshot_hash) — she signs what she saw.
  sign: z.object({ reportId: z.uuid(), snapshotHash: z.string().regex(/^[0-9a-f]{64}$/), idempotencyKey: key }),
  countersign: z.object({ reportId: z.uuid(), idempotencyKey: key }),
  correct: z.object({ reportId: z.uuid(), reason: z.string().trim().min(3).max(300), summary, idempotencyKey: key }),
  withdraw: z.object({ reportId: z.uuid(), idempotencyKey: key }),
};

const INVALID = "Bitte die Eingaben prüfen (Zusammenfassung höchstens 4000 Zeichen, Begründung 3–300 Zeichen).";
const FAILED = "Bericht konnte nicht gespeichert werden.";

type RpcResult = { data: unknown; error: { code?: string; message?: string } | null };

function interpret(op: string, { data, error }: RpcResult): CommandResult {
  if (error) {
    logEvent("warn", "command.failed", { op, ...errorFields(error) });
    return { ok: false, error: error.code === "22023" ? INVALID : FAILED };
  }
  const result = data as { result?: string; reason?: string } | null;
  if (result?.result === "ok" || result?.result === "duplicate") {
    revalidatePath("/field");
    return { ok: true };
  }
  if (result?.result === "rejected") return { ok: false, error: reportRejectionMessage(result.reason) };
  return { ok: false, error: FAILED };
}

export async function createReportDraft(input: unknown): Promise<CommandResult> {
  const parsed = schemas.create.safeParse(input);
  if (!parsed.success) return { ok: false, error: INVALID };
  const { supabase } = await requireUser();
  return interpret(
    "create_report_draft",
    await supabase.rpc("create_report_draft", {
      p_visit_id: parsed.data.visitId,
      // The generated RPC type marks every argument as required; null means "no summary".
      p_summary: parsed.data.summary as string,
      p_idempotency_key: parsed.data.idempotencyKey,
    }),
  );
}

export async function updateReportDraft(input: unknown): Promise<CommandResult> {
  const parsed = schemas.edit.safeParse(input);
  if (!parsed.success) return { ok: false, error: INVALID };
  const { supabase } = await requireUser();
  return interpret(
    "update_report_draft",
    await supabase.rpc("update_report_draft", {
      p_report_id: parsed.data.reportId,
      p_summary: parsed.data.summary as string,
      p_idempotency_key: parsed.data.idempotencyKey,
    }),
  );
}

export async function signReport(input: unknown): Promise<CommandResult> {
  const parsed = schemas.sign.safeParse(input);
  if (!parsed.success) return { ok: false, error: INVALID };
  const { supabase } = await requireUser();
  return interpret(
    "sign_report",
    await supabase.rpc("sign_report", {
      p_report_id: parsed.data.reportId,
      p_snapshot_hash: parsed.data.snapshotHash,
      p_idempotency_key: parsed.data.idempotencyKey,
    }),
  );
}

export async function countersignReport(input: unknown): Promise<CommandResult> {
  const parsed = schemas.countersign.safeParse(input);
  if (!parsed.success) return { ok: false, error: INVALID };
  const { supabase } = await requireUser();
  return interpret(
    "countersign_report",
    await supabase.rpc("countersign_report", {
      p_report_id: parsed.data.reportId,
      p_idempotency_key: parsed.data.idempotencyKey,
    }),
  );
}

export async function correctReport(input: unknown): Promise<CommandResult> {
  const parsed = schemas.correct.safeParse(input);
  if (!parsed.success) return { ok: false, error: INVALID };
  const { supabase } = await requireUser();
  return interpret(
    "correct_report",
    await supabase.rpc("correct_report", {
      p_report_id: parsed.data.reportId,
      p_reason: parsed.data.reason,
      p_summary: parsed.data.summary as string,
      p_idempotency_key: parsed.data.idempotencyKey,
    }),
  );
}

/**
 * CSR1 / CGR-24-W (migration 0049): the performer withdraws her untouched correction draft. No reason: nothing changed.
 * The database refuses a draft with changes (`draft_has_changes`), anyone else and a signed correction.
 */
export async function withdrawReportCorrection(input: unknown): Promise<CommandResult> {
  const parsed = schemas.withdraw.safeParse(input);
  if (!parsed.success) return { ok: false, error: INVALID };
  const { supabase } = await requireUser();
  return interpret(
    "withdraw_report_correction",
    await supabase.rpc("withdraw_report_correction", {
      p_report_id: parsed.data.reportId,
      p_idempotency_key: parsed.data.idempotencyKey,
    }),
  );
}

/**
 * F7: sign at completion with one confirmation. A changed summary is saved to the draft first; then the
 * report is signed. Both steps are the F6 commands (idempotent, audited, performer only). CSR1 / CGR-02: the sign
 * carries the hash of the facts she saw; if they changed since, the database refuses (`facts_changed`) and the card
 * reloads with the current facts. The summary is not part of the hashed facts, so saving it first does not refuse.
 */
export async function signAtCompletion(input: unknown): Promise<CommandResult> {
  const parsed = schemas.sign.extend({ summary, previousSummary: summary }).safeParse(input);
  if (!parsed.success) return { ok: false, error: INVALID };
  const { reportId, snapshotHash, summary: text, previousSummary, idempotencyKey } = parsed.data;
  const { supabase } = await requireUser();
  if ((text ?? "") !== (previousSummary ?? "")) {
    const saved = interpret("update_report_draft", await supabase.rpc("update_report_draft", {
      p_report_id: reportId, p_summary: text as string, p_idempotency_key: crypto.randomUUID(),
    }));
    if (!saved.ok) return saved;
  }
  return interpret("sign_report", await supabase.rpc("sign_report", {
    p_report_id: reportId, p_snapshot_hash: snapshotHash, p_idempotency_key: idempotencyKey,
  }));
}
