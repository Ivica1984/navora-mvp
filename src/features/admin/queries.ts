import "server-only";

import type { Database } from "@/lib/supabase/database.types";
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import { accessStateByUser, type AccessEvent, type AccessState } from "./rules";

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
  /** LEAVE1-12 (1): her open reports by kind, visit date and team (no content, no reason). */
  openReports: Record<string, OpenReport[]>;
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
  // LEAVE1-12 (1): the open reports of each member, listed before an access end (pilot scale: one call per member).
  const memberRows = members.data ?? [];
  const lists = await Promise.all(memberRows.map((m) => supabase.rpc("member_open_reports", { p_user_id: m.user_id })));
  const openReports: Record<string, OpenReport[]> = {};
  lists.forEach((r, i) => {
    if (r.error) fail("admin.open_reports_failed", r.error);
    if ((r.data ?? []).length > 0) openReports[memberRows[i].user_id] = r.data ?? [];
  });
  // COND1-5a (PO 16:20): her unexported-days count is not loaded with the list (no standing per-person figure); it is
  // read for one person when the administrator opens the access-end step (memberUnexportedDays in ./commands).
  return {
    organizationId,
    members: memberRows,
    invitations: (invitations.data ?? []) as AdminInvitation[],
    teams: (teams.data ?? []) as AdminTeam[],
    deadlines: deadlines.data ?? [],
    rules: rules.data ?? [],
    access: accessStateByUser((accessEvents.data ?? []) as AccessEvent[]),
    openReports,
  };
}
