"use server";

// ADM2 part (a) commands (migration 0091, ADR-114). Every rule is checked again in the database (active member of
// the team, switch, consent rule, administrator for "Vertrag erfasst", idempotency, audit); these actions only
// validate shape.

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import type { CommandResult } from "@/lib/commands/result";
import { errorFields, logEvent } from "@/lib/log";
import { ADMISSION_MESSAGES, ADMIN_ADMISSION_REJECTED, CLAIMED_QUALIFICATIONS, DECISIONS, OBJECTION_REASONS, PENSUM_BANDS } from "./rules";

const key = z.uuid();
const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
type RpcResult = { data: unknown; error: { code?: string } | null };

function interpret(op: string, { data, error }: RpcResult, rejected = ADMISSION_MESSAGES.rejected): CommandResult {
  if (error) {
    logEvent("warn", "command.failed", { op, ...errorFields(error) });
    return { ok: false, error: error.code === "22023" ? ADMISSION_MESSAGES.invalid : ADMISSION_MESSAGES.failed };
  }
  const result = typeof data === "string" ? data : (data as { result?: string } | null)?.result;
  if (result === "ok" || result === "duplicate" || result === "unchanged") {
    revalidatePath("/team");
    revalidatePath("/admin");
    return { ok: true };
  }
  if (result === "rejected") return { ok: false, error: rejected };
  return { ok: false, error: ADMISSION_MESSAGES[String(result)] ?? ADMISSION_MESSAGES.failed };
}

const invalid: CommandResult = { ok: false, error: ADMISSION_MESSAGES.invalid };

/** ADM2-1: the administrator switches team admission on or off. */
export async function setTeamAdmission(input: unknown): Promise<CommandResult> {
  const p = z.object({ organizationId: z.uuid(), enabled: z.boolean(), idempotencyKey: key }).safeParse(input);
  if (!p.success) return invalid;
  const { supabase } = await requireUser();
  return interpret("set_team_admission", await supabase.rpc("set_team_admission", {
    p_organization_id: p.data.organizationId, p_enabled: p.data.enabled, p_idempotency_key: p.data.idempotencyKey }),
    ADMIN_ADMISSION_REJECTED);
}

/** ADM2-2: "Kollegin vorschlagen" — display name, claimed qualification and Pensum band only. */
export async function proposeCandidate(input: unknown): Promise<CommandResult> {
  const p = z.object({
    teamId: z.uuid(), displayName: z.string().trim().min(2).max(80), qualification: z.enum(CLAIMED_QUALIFICATIONS),
    pensumBand: z.enum(PENSUM_BANDS), idempotencyKey: key,
  }).safeParse(input);
  if (!p.success) return invalid;
  const { supabase } = await requireUser();
  return interpret("propose_team_candidate", await supabase.rpc("propose_team_candidate", {
    p_team_id: p.data.teamId, p_display_name: p.data.displayName, p_claimed_qualification: p.data.qualification,
    p_pensum_band: p.data.pensumBand, p_idempotency_key: p.data.idempotencyKey }));
}

/** ADM2-5: "Zustimmen", "Einwand" (code), "Einwand zurückziehen", or the proposer's withdrawal. */
export async function decideCandidate(input: unknown): Promise<CommandResult> {
  const p = z.object({
    proposalId: z.uuid(), decision: z.enum(DECISIONS), reason: z.enum(OBJECTION_REASONS).nullable(), idempotencyKey: key,
  }).refine((v) => (v.decision === "objection") === (v.reason !== null)).safeParse(input);
  if (!p.success) return invalid;
  const { supabase } = await requireUser();
  return interpret("decide_team_candidate", await supabase.rpc("decide_team_candidate", {
    p_proposal_id: p.data.proposalId, p_decision: p.data.decision, p_reason: p.data.reason as string,
    p_idempotency_key: p.data.idempotencyKey }));
}

/** ADM2-6: "Vertrag erfassen" — the hand-made account (by its e-mail, D-26), start date, optional end date. No judgement field. */
export async function recordContract(input: unknown): Promise<CommandResult> {
  const p = z.object({
    proposalId: z.uuid(), email: z.email().max(254), startDate: date, endDate: date.nullable(), idempotencyKey: key,
  }).refine((v) => v.endDate === null || v.endDate >= v.startDate).safeParse(input);
  if (!p.success) return invalid;
  const { supabase } = await requireUser();
  return interpret("record_member_contract", await supabase.rpc("record_member_contract", {
    p_proposal_id: p.data.proposalId, p_email: p.data.email, p_start_date: p.data.startDate,
    p_end_date: p.data.endDate as string, p_idempotency_key: p.data.idempotencyKey }), ADMIN_ADMISSION_REJECTED);
}
