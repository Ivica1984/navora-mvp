import "server-only";

import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import type { Database } from "@/lib/supabase/database.types";

type Fn = Database["public"]["Functions"];
export type TeamAbsence = Fn["team_absences"]["Returns"][number];
export type OpenVisit = Fn["team_open_visits"]["Returns"][number];
export type TeamColleague = { teamId: string; teamName: string; userId: string; name: string; isMe: boolean };

/**
 * ABS1: absences of the caller's teams, "Offen im Team" from the given day, and the members she can record an
 * absence for (her own teams only; RLS on team_memberships, ADR-031). No reason exists to read.
 */
export async function getAbsenceView(day: string): Promise<{ absences: TeamAbsence[]; open: OpenVisit[]; colleagues: TeamColleague[] }> {
  const { supabase, user } = await requireUser();
  const [absences, open, members] = await Promise.all([
    supabase.rpc("team_absences"),
    supabase.rpc("team_open_visits", { p_from: day }),
    supabase.from("team_memberships").select("team_id, user_id, teams(name)"),
  ]);
  for (const r of [absences, open, members]) {
    if (r.error) {
      logEvent("error", "absence.load_failed", errorFields(r.error));
      throw new Error("Abwesenheiten und offene Einsätze konnten nicht geladen werden.");
    }
  }
  const memberRows = (members.data ?? []) as unknown as { team_id: string; user_id: string; teams: { name: string | null } | null }[];
  // Only teams the caller belongs to (an org member may read other teams' memberships through other policies).
  const myTeams = new Set(memberRows.filter((m) => m.user_id === user.id).map((m) => m.team_id));
  const ids = [...new Set(memberRows.filter((m) => myTeams.has(m.team_id)).map((m) => m.user_id))];
  const names = new Map<string, string>();
  if (ids.length > 0) {
    const profiles = await supabase.from("member_profiles").select("user_id, display_name").in("user_id", ids);
    if (profiles.error) logEvent("warn", "absence.names_failed", errorFields(profiles.error));
    for (const p of profiles.data ?? []) names.set(p.user_id, p.display_name);
  }
  const colleagues = memberRows
    .filter((m) => myTeams.has(m.team_id))
    .map((m) => ({
      teamId: m.team_id,
      teamName: m.teams?.name ?? "Team",
      userId: m.user_id,
      name: m.user_id === user.id ? "Ich" : (names.get(m.user_id) ?? "Teammitglied"),
      isMe: m.user_id === user.id,
    }))
    .sort((a, b) => Number(b.isMe) - Number(a.isMe) || a.name.localeCompare(b.name, "de-CH"));
  return { absences: absences.data ?? [], open: open.data ?? [], colleagues };
}
