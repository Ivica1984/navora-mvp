import "server-only";

import type { Database } from "@/lib/supabase/database.types";
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";

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
export type AdminTeam = { id: string; name: string; region: string | null; status: string | null; deactivated_at: string | null };

export type AdminData = {
  organizationId: string;
  members: AdminMember[];
  invitations: AdminInvitation[];
  teams: AdminTeam[];
  deadlines: AdminDeadline[];
  rules: AdminExceptionRule[];
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

  const [members, invitations, teams, deadlines, rules] = await Promise.all([
    supabase.rpc("admin_members", { p_organization_id: organizationId }),
    supabase.from("member_invitations")
      .select("id, email, role, display_name, team_id, qualification, created_at, expires_at")
      .eq("organization_id", organizationId).is("accepted_at", null).is("revoked_at", null)
      .order("created_at", { ascending: false }),
    supabase.from("teams").select("id, name, region, status, deactivated_at").eq("organization_id", organizationId).order("name"),
    supabase.rpc("admin_response_deadlines", { p_organization_id: organizationId }),
    supabase.rpc("admin_exception_rules", { p_organization_id: organizationId }),
  ]);
  for (const [name, r] of Object.entries({ members, invitations, teams, deadlines, rules })) {
    if (r.error) fail(`admin.${name}_failed`, r.error);
  }
  return {
    organizationId,
    members: members.data ?? [],
    invitations: (invitations.data ?? []) as AdminInvitation[],
    teams: (teams.data ?? []) as AdminTeam[],
    deadlines: deadlines.data ?? [],
    rules: rules.data ?? [],
  };
}
