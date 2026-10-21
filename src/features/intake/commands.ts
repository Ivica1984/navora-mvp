"use server";

// J1 intake commands (migrations 0010, 0013). The database checks the role
// (admin/operations), validates input, is idempotent and audits. Since the PO
// brief, conversion records the funding facts and the server opens the matching
// request only when the case is ready.

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import type { CommandResult } from "@/lib/commands/result";
import { errorFields, logEvent } from "@/lib/log";
import { CANTONS, INSURANCE_TYPES, MEDICAL_ORDER_STATUSES, URGENCIES, parseMissing, type ReadinessItem } from "./rules";

const recordSchema = z.object({
  organizationId: z.uuid(),
  partnerName: z.string().trim().min(2).max(120),
  partnerType: z.string().trim().max(60).optional(),
  region: z.string().trim().min(2).max(80),
  city: z.string().trim().max(80).optional(),
  urgency: z.enum(URGENCIES),
  timeInfo: z.string().trim().max(120).optional(),
  requestTitle: z.string().trim().min(3).max(160),
  needSummary: z.string().trim().min(3).max(2000),
  services: z.array(z.string().trim().min(1).max(80)).max(20),
  idempotencyKey: z.uuid(),
});

const factsSchema = z
  .object({
    residence_municipality: z.string().trim().min(2).max(80),
    residence_canton: z.enum(CANTONS),
    insurer_name: z.string().trim().min(2).max(120),
    insurance_type: z.enum(INSURANCE_TYPES),
    medical_order_status: z.enum(MEDICAL_ORDER_STATUSES),
    medical_order_valid_until: z.iso.date(),
    gp_named: z.boolean(),
    other_providers_active: z.boolean(),
    requested_start: z.iso.date(),
    language_notes: z.string().trim().max(500),
    access_notes: z.string().trim().max(500),
    expected_hours_per_week: z.number().positive().max(168),
  })
  .partial()
  .strict();

const convertSchema = z.object({
  requestId: z.uuid(),
  firstName: z.string().trim().min(1).max(100),
  lastName: z.string().trim().min(1).max(100),
  consentConfirmed: z.literal(true),
  facts: factsSchema,
  idempotencyKey: z.uuid(),
});

const updateSchema = z.object({ caseId: z.uuid(), facts: factsSchema, idempotencyKey: z.uuid() });

export type IntakeResult = { ok: true; ready: boolean; missing: ReadinessItem[] } | { ok: false; error: string };

const REJECTED = "Nicht gespeichert: fehlende Berechtigung (Aufnahme: Admin/Operations) oder Anfrage bereits überführt.";

function done(data: unknown, error: { code?: string } | null, op: string, invalid: string): CommandResult {
  if (error) {
    logEvent("warn", "command.failed", { op, ...errorFields(error) });
    return { ok: false, error: error.code === "22023" ? invalid : "Speichern fehlgeschlagen." };
  }
  if (data === "rejected") return { ok: false, error: REJECTED };
  if (data !== "ok" && data !== "duplicate") return { ok: false, error: "Speichern fehlgeschlagen." };
  revalidatePath("/intake");
  revalidatePath("/operations");
  return { ok: true };
}

export async function recordPartnerRequest(input: unknown): Promise<CommandResult> {
  const invalid = "Bitte Partner, Region, Dringlichkeit, Titel und Bedarf vollständig angeben.";
  const parsed = recordSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: invalid };
  const d = parsed.data;

  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("record_partner_request", {
    p_organization_id: d.organizationId,
    p_partner_name: d.partnerName,
    p_partner_type: d.partnerType ?? "",
    p_region: d.region,
    p_city: d.city ?? "",
    p_urgency: d.urgency,
    p_time_info: d.timeInfo ?? "",
    p_request_title: d.requestTitle,
    p_need_summary: d.needSummary,
    p_requested_services: d.services,
    p_idempotency_key: d.idempotencyKey,
  });
  return done(data, error, "record_partner_request", invalid);
}

function intakeResult(data: unknown, error: { code?: string } | null, op: string, invalid: string): IntakeResult {
  if (error) {
    logEvent("warn", "command.failed", { op, ...errorFields(error) });
    return { ok: false, error: error.code === "22023" ? invalid : "Speichern fehlgeschlagen." };
  }
  const res = (data ?? {}) as { result?: string; ready?: boolean; missing?: unknown };
  if (res.result === "rejected") return { ok: false, error: REJECTED };
  if (res.result !== "ok" && res.result !== "duplicate") return { ok: false, error: "Speichern fehlgeschlagen." };
  revalidatePath("/intake");
  revalidatePath("/operations");
  revalidatePath("/team");
  return { ok: true, ready: res.ready === true, missing: parseMissing(res.missing) };
}

export async function convertPartnerRequest(input: unknown): Promise<IntakeResult> {
  const invalid = "Bitte Vor- und Nachname angeben, die Einwilligung bestätigen und gültige Angaben machen (z. B. Kanton, Datum).";
  const parsed = convertSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: invalid };
  const d = parsed.data;

  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("convert_partner_request", {
    p_request_id: d.requestId,
    p_first_name: d.firstName,
    p_last_name: d.lastName,
    p_consent_confirmed: d.consentConfirmed,
    p_facts: d.facts,
    p_idempotency_key: d.idempotencyKey,
  });
  return intakeResult(data, error, "convert_partner_request", invalid);
}

export async function updateCaseIntake(input: unknown): Promise<IntakeResult> {
  const invalid = "Bitte gültige Angaben machen (z. B. Kanton, Datum).";
  const parsed = updateSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: invalid };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("update_case_intake", {
    p_case_id: parsed.data.caseId,
    p_facts: parsed.data.facts,
    p_idempotency_key: parsed.data.idempotencyKey,
  });
  return intakeResult(data, error, "update_case_intake", invalid);
}
