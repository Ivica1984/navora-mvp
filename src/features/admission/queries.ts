import "server-only";

import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import { readAdminAdmissions, readTeamAdmissions, type AdminAdmissions, type TeamAdmissions } from "./rules";

export type TeamAdmissionView = { teamId: string; teamName: string; admissions: TeamAdmissions };

/**
 * ADM2-4 / ADM2-10: the admission proposals of each of the caller's teams. The database returns null to anyone who is
 * not an active member of that team (or an administrator); such teams are left out. Empty when the switch is off.
 */
export async function getMyTeamAdmissions(): Promise<TeamAdmissionView[]> {
  const { supabase, user } = await requireUser();
  const own = await supabase.from("team_memberships").select("team_id, teams(name)").eq("user_id", user.id);
  if (own.error) {
    logEvent("error", "admission.teams_failed", errorFields(own.error));
    return [];
  }
  const rows = (own.data ?? []) as unknown as { team_id: string; teams: { name: string } | null }[];
  const lists = await Promise.all(rows.map((r) => supabase.rpc("team_admissions", { p_team_id: r.team_id })));
  const views: TeamAdmissionView[] = [];
  lists.forEach((r, i) => {
    if (r.error) {
      logEvent("error", "admission.read_failed", errorFields(r.error));
      return;
    }
    const admissions = readTeamAdmissions(r.data);
    if (admissions && admissions.enabled) {
      views.push({ teamId: rows[i].team_id, teamName: rows[i].teams?.name ?? "Team", admissions });
    }
  });
  return views;
}

/** ADM2-9: every admission of the organisation, for its administrators (null for everyone else). */
export async function getAdminAdmissions(organizationId: string): Promise<AdminAdmissions | null> {
  const { supabase } = await requireUser();
  const r = await supabase.rpc("admin_team_admissions", { p_organization_id: organizationId });
  if (r.error) {
    logEvent("error", "admission.admin_read_failed", errorFields(r.error));
    return null;
  }
  return readAdminAdmissions(r.data);
}
