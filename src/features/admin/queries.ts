import "server-only";

import type { Database } from "@/lib/supabase/database.types";
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import { accessStateByUser, lastEventAtByUser, type AccessEvent, type AccessState } from "./rules";

type Fn = Database["public"]["Functions"];
export type AdminMember = Fn["admin_members"]["Returns"][number];
export type AdminDeadline = Fn["admin_response_deadlines"]["Returns"][number];
export type AdminExceptionRule = Fn["admin_exception_rules"]["Returns"][number];
export type AdminInvitation = {
  id: string;
  email: string;
  role: string;
  display_name: string;
  team_id: string | null;
  qualification: string | null;
  created_at: string;
  expires_at: string;
};
export type OpenReport = Fn["member_open_reports"]["Returns"][number];
export type AdminTeam = { id: string; name: string; region: string | null; status: string | null; deactivated_at: string | null };

export type AdminData = {
  organizationId: string;
  members: AdminMember[];
  invitations: AdminInvitation[];
  teams: AdminTeam[];
  deadlines: AdminDeadline[];
  rules: AdminExceptionRule[];
  /** LEAVE1 (0074): current access state per person (administrators read the record). */
  access: Record<string, AccessState>;
  /** ADM2-13 (0092): the time of her newest access event (a contract end is restored by an event after it). */
  lastAccessEventAt: Record<string, string>;
};

function fail(event: string, error: unknown): never {
  logEvent("error", event, errorFields(error as { code?: string; message?: string }));
  throw new Error("Administration konnte nicht geladen werden.");
}

/**
 * ADM1: everything the admin area shows, for the organisation the caller administers.
 * Returns null when the caller administers no organisation: the page then shows nothing
 * (the database functions return no rows for non-administrators anyway).
 */
export async function getAdminData(): Promise<AdminData | null> {
  const { supabase } = await requireUser();
  const own = await supabase.from("organization_memberships").select("organization_id, role").eq("role", "admin").limit(1);
  if (own.error) fail("admin.membership_failed", own.error);
  const organizationId = own.data?.[0]?.organization_id;
  if (!organizationId) return null;

  const [members, invitations, teams, deadlines, rules, accessEvents] = await Promise.all([
    supabase.rpc("admin_members", { p_organization_id: organizationId }),
    supabase.from("member_invitations")
      .select("id, email, role, display_name, team_id, qualification, created_at, expires_at")
      .eq("organization_id", organizationId).is("accepted_at", null).is("revoked_at", null)
      .order("created_at", { ascending: false }),
    supabase.from("teams").select("id, name, region, status, deactivated_at").eq("organization_id", organizationId).order("name"),
    supabase.rpc("admin_response_deadlines", { p_organization_id: organizationId }),
    supabase.rpc("admin_exception_rules", { p_organization_id: organizationId }),
    supabase.from("member_access_events").select("user_id, kind, reason_code, created_at, seq").eq("organization_id", organizationId),
  ]);
  for (const [name, r] of Object.entries({ members, invitations, teams, deadlines, rules, accessEvents })) {
    if (r.error) fail(`admin.${name}_failed`, r.error);
  }
  const memberRows = members.data ?? [];
  // RLS4-C2 (po 2026-10-30 07:20, ADR-122 addendum): no member's open reports are loaded with the list (no standing
  // per-person list of documentation backlog). LEAVE1-12 (1): they are read for one person when the administrator opens
  // the access-end step for her (readMemberOpenReports in ./commands), as COND1-5a does for her unexported-days count
  // (prepareMemberAccessEnd, COND2-1). The leavers of the next 14 days (ADM2-12) are read by the page through
  // getLeaverOpenReports (features/contract-end), for those leavers only.
  return {
    organizationId,
    members: memberRows,
    invitations: (invitations.data ?? []) as AdminInvitation[],
    teams: (teams.data ?? []) as AdminTeam[],
    deadlines: deadlines.data ?? [],
    rules: rules.data ?? [],
    access: accessStateByUser((accessEvents.data ?? []) as AccessEvent[]),
    lastAccessEventAt: lastEventAtByUser((accessEvents.data ?? []) as AccessEvent[]),
  };
}
