"use server";

// ADM1: pilot administration commands (migration 0025). Every command is checked again in the
// database (administrator of the organisation, idempotency, audit); these actions only validate shape.

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import type { CommandResult } from "@/lib/commands/result";
import { errorFields, logEvent } from "@/lib/log";
import { ADMIN_MESSAGES, DEADLINE_UNITS, PRIORITIES, QUALIFICATIONS, REFERRAL_TYPES, ROLES } from "./rules";

const key = z.uuid();
const reason = z.string().trim().min(3).max(300);
const name = z.string().trim().min(2).max(80);

type RpcResult = { data: unknown; error: { code?: string } | null };

function interpret(op: string, { data, error }: RpcResult): CommandResult {
  if (error) {
    logEvent("warn", "command.failed", { op, ...errorFields(error) });
    return { ok: false, error: error.code === "22023" ? ADMIN_MESSAGES.invalid : ADMIN_MESSAGES.failed };
  }
  if (data === "ok" || data === "duplicate") {
    revalidatePath("/admin");
    revalidatePath("/team");
    revalidatePath("/operations");
    return { ok: true };
  }
  return { ok: false, error: ADMIN_MESSAGES[String(data)] ?? ADMIN_MESSAGES.failed };
}

const invalid: CommandResult = { ok: false, error: ADMIN_MESSAGES.invalid };

export async function setDisplayName(input: unknown): Promise<CommandResult> {
  const p = z.object({ organizationId: z.uuid(), userId: z.uuid(), displayName: name, idempotencyKey: key }).safeParse(input);
  if (!p.success) return invalid;
  const { supabase } = await requireUser();
  return interpret("set_display_name", await supabase.rpc("set_display_name", {
    p_organization_id: p.data.organizationId, p_user_id: p.data.userId, p_display_name: p.data.displayName, p_idempotency_key: p.data.idempotencyKey }));
}

export async function inviteMember(input: unknown): Promise<CommandResult> {
  const p = z.object({
    organizationId: z.uuid(), email: z.email().max(254), role: z.enum(ROLES), displayName: name,
    teamId: z.uuid().nullable(), qualification: z.enum(QUALIFICATIONS).nullable(), idempotencyKey: key,
  }).refine((v) => (v.teamId === null) === (v.qualification === null)).safeParse(input);
  if (!p.success) return invalid;
  const { supabase } = await requireUser();
  // Account creation and the e-mail stay outside the app until D-26 (no service-role key on the server).
  return interpret("invite_member", await supabase.rpc("invite_member", {
    p_organization_id: p.data.organizationId, p_email: p.data.email, p_role: p.data.role, p_display_name: p.data.displayName,
    p_team_id: p.data.teamId as string, p_qualification: p.data.qualification as string, p_idempotency_key: p.data.idempotencyKey }));
}

export async function revokeInvitation(input: unknown): Promise<CommandResult> {
  const p = z.object({ invitationId: z.uuid(), idempotencyKey: key }).safeParse(input);
  if (!p.success) return invalid;
  const { supabase } = await requireUser();
  return interpret("revoke_invitation", await supabase.rpc("revoke_invitation", { p_invitation_id: p.data.invitationId, p_idempotency_key: p.data.idempotencyKey }));
}

export async function setMemberRole(input: unknown): Promise<CommandResult> {
  const p = z.object({ organizationId: z.uuid(), userId: z.uuid(), role: z.enum(ROLES), reason, idempotencyKey: key }).safeParse(input);
  if (!p.success) return invalid;
  const { supabase } = await requireUser();
  return interpret("set_member_role", await supabase.rpc("set_member_role", {
    p_organization_id: p.data.organizationId, p_user_id: p.data.userId, p_role: p.data.role, p_reason: p.data.reason, p_idempotency_key: p.data.idempotencyKey }));
}

export async function addTeamMember(input: unknown): Promise<CommandResult> {
  const p = z.object({ teamId: z.uuid(), userId: z.uuid(), qualification: z.enum(QUALIFICATIONS), idempotencyKey: key }).safeParse(input);
  if (!p.success) return invalid;
  const { supabase } = await requireUser();
  return interpret("add_team_member", await supabase.rpc("add_team_member", {
    p_team_id: p.data.teamId, p_user_id: p.data.userId, p_qualification: p.data.qualification, p_idempotency_key: p.data.idempotencyKey }));
}

export async function removeTeamMember(input: unknown): Promise<CommandResult> {
  const p = z.object({ teamId: z.uuid(), userId: z.uuid(), reason, idempotencyKey: key }).safeParse(input);
  if (!p.success) return invalid;
  const { supabase } = await requireUser();
  return interpret("remove_team_member", await supabase.rpc("remove_team_member", {
    p_team_id: p.data.teamId, p_user_id: p.data.userId, p_reason: p.data.reason, p_idempotency_key: p.data.idempotencyKey }));
}

export async function setMemberQualification(input: unknown): Promise<CommandResult> {
  const p = z.object({ teamId: z.uuid(), userId: z.uuid(), qualification: z.enum(QUALIFICATIONS), reason, idempotencyKey: key }).safeParse(input);
  if (!p.success) return invalid;
  const { supabase } = await requireUser();
  return interpret("set_member_qualification", await supabase.rpc("set_member_qualification", {
    p_team_id: p.data.teamId, p_user_id: p.data.userId, p_qualification: p.data.qualification, p_reason: p.data.reason, p_idempotency_key: p.data.idempotencyKey }));
}

export async function createTeam(input: unknown): Promise<CommandResult> {
  const p = z.object({ organizationId: z.uuid(), name, region: name, idempotencyKey: key }).safeParse(input);
  if (!p.success) return invalid;
  const { supabase } = await requireUser();
  return interpret("create_team", await supabase.rpc("create_team", {
    p_organization_id: p.data.organizationId, p_name: p.data.name, p_region: p.data.region, p_idempotency_key: p.data.idempotencyKey }));
}

export async function updateTeam(input: unknown): Promise<CommandResult> {
  const p = z.object({ teamId: z.uuid(), name, region: name, idempotencyKey: key }).safeParse(input);
  if (!p.success) return invalid;
  const { supabase } = await requireUser();
  return interpret("update_team", await supabase.rpc("update_team", {
    p_team_id: p.data.teamId, p_name: p.data.name, p_region: p.data.region, p_idempotency_key: p.data.idempotencyKey }));
}

export async function deactivateTeam(input: unknown): Promise<CommandResult> {
  const p = z.object({ teamId: z.uuid(), reason, idempotencyKey: key }).safeParse(input);
  if (!p.success) return invalid;
  const { supabase } = await requireUser();
  return interpret("deactivate_team", await supabase.rpc("deactivate_team", {
    p_team_id: p.data.teamId, p_reason: p.data.reason, p_idempotency_key: p.data.idempotencyKey }));
}

export async function setResponseDeadline(input: unknown): Promise<CommandResult> {
  const p = z.object({ organizationId: z.uuid(), referralType: z.enum(REFERRAL_TYPES), amount: z.number().int().min(1).max(240),
    unit: z.enum(DEADLINE_UNITS), idempotencyKey: key }).safeParse(input);
  if (!p.success) return invalid;
  const { supabase } = await requireUser();
  return interpret("set_response_deadline", await supabase.rpc("set_response_deadline", {
    p_organization_id: p.data.organizationId, p_referral_type: p.data.referralType, p_amount: p.data.amount, p_unit: p.data.unit,
    p_idempotency_key: p.data.idempotencyKey }));
}

export async function setExceptionRule(input: unknown): Promise<CommandResult> {
  const p = z.object({ organizationId: z.uuid(), exceptionType: z.string().min(1).max(60), priority: z.enum(PRIORITIES),
    amount: z.number().int().min(0).max(720).nullable(), escalate: z.number().int().min(0).max(720).nullable(), idempotencyKey: key }).safeParse(input);
  if (!p.success) return invalid;
  const { supabase } = await requireUser();
  return interpret("set_exception_rule", await supabase.rpc("set_exception_rule", {
    p_organization_id: p.data.organizationId, p_exception_type: p.data.exceptionType, p_priority: p.data.priority,
    p_amount: p.data.amount as number, p_escalate_to_p1_after_hours: p.data.escalate as number, p_idempotency_key: p.data.idempotencyKey }));
}

export async function resetExceptionRule(input: unknown): Promise<CommandResult> {
  const p = z.object({ organizationId: z.uuid(), exceptionType: z.string().min(1).max(60), idempotencyKey: key }).safeParse(input);
  if (!p.success) return invalid;
  const { supabase } = await requireUser();
  return interpret("reset_exception_rule", await supabase.rpc("reset_exception_rule", {
    p_organization_id: p.data.organizationId, p_exception_type: p.data.exceptionType, p_idempotency_key: p.data.idempotencyKey }));
}
