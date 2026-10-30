import "server-only";

// AIG1 part (b) (ADR-129): readers for the proposal screens. Every read goes through the AIG1 functions of migrations
// 0097/0103 as the signed-in person (no app grant exists on the AIG1 tables, AIG1-11 (1)); nothing here widens a read.

import { requireUser } from "@/lib/auth/session";
import type { Database } from "@/lib/supabase/database.types";
import { COORDINATOR_ROLES } from "@/lib/auth/nav";
import { errorFields, logEvent } from "@/lib/log";
import type { Provenance } from "./labels";

type Fn = Database["public"]["Functions"];
export type OpenSuggestion = Fn["open_suggestions"]["Returns"][number];
export type AgentHealthRow = Fn["agent_health"]["Returns"][number];
export type LookbackLine = Fn["agent_stop_lookback"]["Returns"][number];

export type TeamMemberOption = { user_id: string; name: string | null; me: boolean };

export type TeamSuggestions = {
  team_id: string;
  team_name: string;
  members: TeamMemberOption[];
  /** visit id → client name, from the team's own case list (team_cases). */
  clients: Record<string, string>;
  suggestions: OpenSuggestion[];
};

function arr(raw: unknown): Record<string, unknown>[] {
  return Array.isArray(raw) ? raw.filter((v): v is Record<string, unknown> => typeof v === "object" && v !== null) : [];
}

/**
 * AIG1-3/-5 confirm screen: the caller's teams (from her own case list, `team_cases`), their members for "Ändern" and
 * the undecided proposals of each team (`open_suggestions`: active members only, no confirmer, nothing decided).
 */
export async function getTeamSuggestions(): Promise<TeamSuggestions[]> {
  const { supabase } = await requireUser();
  const cases = await supabase.rpc("team_cases");
  if (cases.error) {
    logEvent("error", "aig1.team_cases_failed", errorFields(cases.error));
    throw new Error("Vorschläge konnten nicht geladen werden.");
  }
  const teams = new Map<string, TeamSuggestions>();
  for (const c of cases.data ?? []) {
    let t = teams.get(c.team_id);
    if (!t) {
      t = { team_id: c.team_id, team_name: c.team_name, members: [], clients: {}, suggestions: [] };
      teams.set(c.team_id, t);
    }
    for (const m of arr(c.members)) {
      const id = typeof m.user_id === "string" ? m.user_id : null;
      if (id && !t.members.some((x) => x.user_id === id)) {
        t.members.push({ user_id: id, name: typeof m.name === "string" ? m.name : null, me: m.me === true });
      }
    }
    for (const v of arr(c.upcoming)) {
      if (typeof v.visit_id === "string") t.clients[v.visit_id] = c.client_name;
    }
  }
  const out = [...teams.values()];
  // Display names of the team's members for "Ändern" (member_profiles: readable within the organisation).
  const ids = [...new Set(out.flatMap((t) => t.members.filter((m) => !m.name).map((m) => m.user_id)))];
  if (ids.length > 0) {
    const profiles = await supabase.from("member_profiles").select("user_id, display_name").in("user_id", ids);
    if (profiles.error) logEvent("warn", "aig1.member_names_failed", errorFields(profiles.error));
    const names = new Map((profiles.data ?? []).map((p) => [p.user_id, p.display_name]));
    for (const t of out) for (const m of t.members) m.name = m.name ?? names.get(m.user_id) ?? null;
  }
  const results = await Promise.all(out.map((t) => supabase.rpc("open_suggestions", { p_team_id: t.team_id })));
  results.forEach((r, i) => {
    if (r.error) {
      logEvent("error", "aig1.open_suggestions_failed", errorFields(r.error));
      throw new Error("Vorschläge konnten nicht geladen werden.");
    }
    out[i].suggestions = r.data ?? [];
  });
  return out;
}

/** The organisations in which the caller holds a coordination role (own memberships only, RLS). */
async function coordinatorOrganizations(): Promise<string[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.from("organization_memberships").select("organization_id, role");
  if (error) {
    logEvent("error", "aig1.memberships_failed", errorFields(error));
    return [];
  }
  return [...new Set((data ?? []).filter((m) => COORDINATOR_ROLES.includes(m.role)).map((m) => m.organization_id))];
}

/** AIG1-10 / AIG1-16: the health list of the caller's organisations (coordinators; empty for everybody else). */
export async function getAgentHealth(): Promise<AgentHealthRow[]> {
  const { supabase } = await requireUser();
  const orgs = await coordinatorOrganizations();
  const results = await Promise.all(orgs.map((o) => supabase.rpc("agent_health", { p_organization_id: o })));
  const rows: AgentHealthRow[] = [];
  for (const r of results) {
    if (r.error) {
      logEvent("error", "aig1.agent_health_failed", errorFields(r.error));
      throw new Error("Assistenten konnten nicht geladen werden.");
    }
    rows.push(...(r.data ?? []));
  }
  return rows;
}

/** AIG1-12/-13/-14: the look-back list of one stop (no person, no outcome column; record readers and coordinators). */
export async function getStopLookback(stopId: string): Promise<LookbackLine[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("agent_stop_lookback", { p_stop_id: stopId });
  if (error) {
    logEvent("error", "aig1.lookback_failed", errorFields(error));
    throw new Error("Die Liste konnte nicht geladen werden.");
  }
  return data ?? [];
}

export type VisitRecord = {
  id: string;
  visit_date: string | null;
  time_start: string | null;
  time_end: string | null;
  status: string | null;
  team_name: string | null;
  responsible_name: string | null;
  responsible_set: boolean;
  provenance: Provenance | null;
};

/**
 * The visit record as the look-back line and the confirm screen open it: the visit through its existing read path
 * (care_visits RLS: team, coordination; READ_PATHS), the responsible member's display name, and the AIG1-3 line of
 * its one AI-proposed field through `value_provenance` (one value; team members of the record only, AIG1-11 (2a)).
 * Returns null when the caller may not read the visit.
 */
export async function getVisitRecord(visitId: string): Promise<VisitRecord | null> {
  const { supabase } = await requireUser();
  const { data: v, error } = await supabase
    .from("care_visits")
    .select("id, team_id, visit_date, time_start, time_end, status, responsible_user_id")
    .eq("id", visitId)
    .maybeSingle();
  if (error) {
    logEvent("error", "aig1.visit_failed", errorFields(error));
    throw new Error("Der Einsatz konnte nicht geladen werden.");
  }
  if (!v) return null;
  const [team, profile, prov] = await Promise.all([
    v.team_id
      ? supabase.from("teams").select("name").eq("id", v.team_id).maybeSingle()
      : Promise.resolve({ data: null, error: null }),
    v.responsible_user_id
      ? supabase.from("member_profiles").select("display_name").eq("user_id", v.responsible_user_id).maybeSingle()
      : Promise.resolve({ data: null, error: null }),
    supabase.rpc("value_provenance", {
      p_entity_type: "care_visits",
      p_entity_id: visitId,
      p_field: "responsible_user_id",
    }),
  ]);
  if (prov.error) logEvent("warn", "aig1.provenance_failed", errorFields(prov.error));
  const p = prov.data?.[0] ?? null;
  return {
    id: v.id,
    visit_date: v.visit_date,
    time_start: v.time_start,
    time_end: v.time_end,
    status: v.status,
    team_name: team.data?.name ?? null,
    responsible_name: profile.data?.display_name ?? null,
    responsible_set: Boolean(v.responsible_user_id),
    provenance: p
      ? {
          agent_name: p.agent_name,
          status: p.status,
          not_found: p.not_found,
          confirmer_name: p.confirmer_name,
          confirmed_at: p.confirmed_at,
        }
      : null,
  };
}
