import "server-only";

import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import type { Database } from "@/lib/supabase/database.types";
import { intakeOrganization, intakeRowsWithUrgencyCheck, type Membership } from "./rules";
import { getRegionOptions } from "@/features/regions/queries";
import type { RegionOption } from "@/features/regions/rules";

export type IntakeCase = Database["public"]["Functions"]["intake_cases"]["Returns"][number];

/** RET1: a paused case, or one closed within the configured period, that a referral may be linked to. */
export type LinkableCase = Database["public"]["Functions"]["linkable_cases"]["Returns"][number];

export type OpenPartnerRequest = {
  id: string;
  created_at: string;
  partner_name: string;
  partner_type: string | null;
  region: string;
  city: string | null;
  /** CGR-215 (d): null is shown as «Dringlichkeit fehlt», never dropped (an intake row should always carry one). */
  urgency: string | null;
  /** IPA1-7: referrer_stated | intake_assessed | unknown (before IPA1-7). */
  urgency_source: string;
  /** IPA1-8: the referrer's requested first-visit date (shown only). */
  referrer_requested_start: string | null;
  time_info: string | null;
  request_title: string;
  need_summary: string;
  requested_services: string[] | null;
  status: string;
};

/** Caller's intake organisation (null = no intake role) and the open referrals of that organisation. */
export async function getIntakeData(): Promise<{
  organizationId: string | null;
  requests: OpenPartnerRequest[];
  cases: IntakeCase[];
  linkable: Record<string, LinkableCase[]>;
  /** B1.1-1: the organisation's region list (select field). */
  regions: RegionOption[];
}> {
  const { supabase } = await requireUser();

  const { data: memberships, error: mError } = await supabase
    .from("organization_memberships")
    .select("organization_id, role");
  if (mError) {
    logEvent("error", "intake.memberships_failed", errorFields(mError));
    throw new Error("Zugriffsrechte konnten nicht geladen werden.");
  }

  const organizationId = intakeOrganization((memberships ?? []) as Membership[]);
  if (!organizationId) return { organizationId: null, requests: [], cases: [], linkable: {}, regions: [] };

  const { data, error } = await supabase
    .from("partner_requests")
    .select(
      "id, created_at, partner_name, partner_type, region, city, urgency, urgency_source, referrer_requested_start, time_info, request_title, need_summary, requested_services, status",
    )
    .eq("organization_id", organizationId)
    .in("status", ["open", "ready_to_convert"])
    // BK-a (ADR-194): a client order (order_kind set, status client_confirmed) is never an intake row.
    .is("order_kind", null)
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

  // RET1: cases each referral may be linked to (explicit choice at intake; no automatic identity matching).
  // An intake row should always carry an urgency (check partner_requests_order_shape, migration 0129). CGR-215 (d):
  // a row without one is still listed («Dringlichkeit fehlt») and the gap is logged as an error event, never dropped.
  const { rows: requests, missingUrgency } = intakeRowsWithUrgencyCheck(data ?? []);
  if (missingUrgency.length > 0) {
    logEvent("error", "intake.urgency_missing", { count: missingUrgency.length });
  }
  const linkable: Record<string, LinkableCase[]> = {};
  await Promise.all(
    requests.map(async (r) => {
      const { data: rows, error: lError } = await supabase.rpc("linkable_cases", { p_request_id: r.id });
      if (lError) {
        logEvent("error", "intake.linkable_failed", errorFields(lError));
        throw new Error("Frühere Fälle konnten nicht geladen werden.");
      }
      linkable[r.id] = rows ?? [];
    }),
  );

  const { options: regions } = await getRegionOptions(supabase, organizationId);

  return { organizationId, requests, cases: cases ?? [], linkable, regions };
}
