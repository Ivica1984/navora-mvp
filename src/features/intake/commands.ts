"use server";

// J1 intake commands (migration 0010). The database checks the role
// (admin/operations), validates input, is idempotent and audits.

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import type { CommandResult } from "@/lib/commands/result";
import { errorFields, logEvent } from "@/lib/log";
import { URGENCIES } from "./rules";

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

const convertSchema = z.object({
  requestId: z.uuid(),
  firstName: z.string().trim().min(1).max(100),
  lastName: z.string().trim().min(1).max(100),
  consentConfirmed: z.literal(true),
  idempotencyKey: z.uuid(),
});

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

export async function convertPartnerRequest(input: unknown): Promise<CommandResult> {
  const invalid = "Bitte Vor- und Nachname angeben und die Einwilligung bestätigen.";
  const parsed = convertSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: invalid };
  const d = parsed.data;

  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("convert_partner_request", {
    p_request_id: d.requestId,
    p_first_name: d.firstName,
    p_last_name: d.lastName,
    p_consent_confirmed: d.consentConfirmed,
    p_idempotency_key: d.idempotencyKey,
  });
  return done(data, error, "convert_partner_request", invalid);
}
