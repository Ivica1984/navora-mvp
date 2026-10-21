import "server-only";

import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import type { Database } from "@/lib/supabase/database.types";
import { intakeOrganization, type Membership } from "./rules";

export type IntakeCase = Database["public"]["Functions"]["intake_cases"]["Returns"][number];

export type OpenPartnerRequest = {
  id: string;
  created_at: string;
  partner_name: string;
  partner_type: string | null;
  region: string;
  city: string | null;
  urgency: string;
  time_info: string | null;
  request_title: string;
  need_summary: string;
  requested_services: string[] | null;
  status: string;
};

/** Caller's intake organisation (null = no intake role) and the open referrals of that organisation. */
export async function getIntakeData(): Promise<{ organizationId: string | null; requests: OpenPartnerRequest[]; cases: IntakeCase[] }> {
  const { supabase } = await requireUser();

  const { data: memberships, error: mError } = await supabase
    .from("organization_memberships")
    .select("organization_id, role");
  if (mError) {
    logEvent("error", "intake.memberships_failed", errorFields(mError));
    throw new Error("Zugriffsrechte konnten nicht geladen werden.");
  }

  const organizationId = intakeOrganization((memberships ?? []) as Membership[]);
  if (!organizationId) return { organizationId: null, requests: [], cases: [] };

  const { data, error } = await supabase
    .from("partner_requests")
    .select("id, created_at, partner_name, partner_type, region, city, urgency, time_info, request_title, need_summary, requested_services, status")
    .eq("organization_id", organizationId)
    .in("status", ["open", "ready_to_convert"])
    .order("created_at", { ascending: false });
  if (error) {
    logEvent("error", "intake.load_failed", errorFields(error));
    throw new Error("Anfragen konnten nicht geladen werden.");
  }

  // J1 (PO brief): cases still in intake, with the readiness list and open tasks.
  const { data: cases, error: cError } = await supabase.rpc("intake_cases");
  if (cError) {
    logEvent("error", "intake.cases_failed", errorFields(cError));
    throw new Error("Fälle in Aufnahme konnten nicht geladen werden.");
  }

  return { organizationId, requests: data ?? [], cases: cases ?? [] };
}
