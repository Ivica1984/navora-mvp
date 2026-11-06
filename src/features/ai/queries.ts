import "server-only";

// AIG1 part (b) (ADR-129): readers for the proposal screens. Every read goes through the AIG1 functions of migrations
// 0097/0103 as the signed-in person (no app grant exists on the AIG1 tables, AIG1-11 (1)); nothing here widens a read.

import { memberNumbers, responsibleMemberLabel } from "@/features/team/member-label";
import { requireUser } from "@/lib/auth/session";
import type { Database } from "@/lib/supabase/database.types";
import { COORDINATOR_ROLES, PAGE_LABEL } from "@/lib/auth/nav";
import { FIELD_PATH, homePathForRoles } from "@/lib/auth/paths";
import { errorFields, logEvent } from "@/lib/log";
import { countOpenSuggestions, type PlanTeamMeasure, type Provenance, type StopMeasure, type TeamLookbackStop } from "./labels";

type Fn = Database["public"]["Functions"];
export type OpenSuggestion = Fn["open_suggestions"]["Returns"][number];
export type AgentHealthRow = Fn["agent_health"]["Returns"][number];
export type LookbackLine = Fn["agent_stop_lookback"]["Returns"][number];

/** CGR-139: `no` is her position in the team ordered by user id (team_cases; as /team and the handover), null if unknown. */
export type TeamMemberOption = { user_id: string; name: string | null; me: boolean; no: number | null };

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
  const out = await loadTeams();
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

/**
 * PLAN3-12 (ADR-148): how many proposals wait for the caller's teams, for the "Vorschläge" link on `/team`. The same
 * reader as the confirm screen (`open_suggestions`, per team the caller is a member of, as herself); no new read, no
 * name and no row leaves this function. `null` when a read failed: the link then reads plain "Vorschläge".
 */
export async function getOpenSuggestionCount(teamIds: string[]): Promise<number | null> {
  const { supabase } = await requireUser();
  const ids = [...new Set(teamIds)];
  const results = await Promise.all(ids.map((id) => supabase.rpc("open_suggestions", { p_team_id: id })));
  const perTeam = results.map((r) => {
    if (r.error) {
      logEvent("warn", "plan3.suggestion_count_failed", errorFields(r.error));
      return null;
    }
    return (r.data ?? []).length;
  });
  return countOpenSuggestions(perTeam);
}

/** The caller's teams with their members and clients (from `team_cases`), without proposals. */
async function loadTeams(): Promise<TeamSuggestions[]> {
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
        t.members.push({ user_id: id, name: typeof m.name === "string" ? m.name : null, me: m.me === true, no: null });
      }
    }
    // CGR-139: team_cases lists every membership of the team ordered by user id; the position is the /team number.
    const numbers = memberNumbers(t.members);
    for (const m of t.members) m.no = numbers.get(m.user_id) ?? null;
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

/**
 * PLAN3-13 (ADR-150): the look-back measure of one stop per team (`agent_stop_measures`, migration 0112), in the scope
 * of `agent_stop_lookback`. Null when the read failed: the page then says so rather than showing zeros.
 */
export async function getStopMeasures(stopId: string): Promise<StopMeasure[] | null> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("agent_stop_measures", { p_stop_id: stopId });
  if (error) {
    logEvent("warn", "plan3.stop_measures_failed", errorFields(error));
    return null;
  }
  return (data ?? []).map((r) => ({ ...r, lead_time_median_hours: r.lead_time_median_hours === null ? null : Number(r.lead_time_median_hours) }));
}

export type TeamLookbackStopRow = Fn["team_lookback_stops"]["Returns"][number];

/**
 * PLAN3-11 (ADR-149): the stops with at least one open look-back line of the caller's own teams (`team_lookback_stops`,
 * migration 0111). Null when the read failed: `/team` then shows no entry rather than a wrong "0 offen".
 */
export async function getTeamLookbackStops(): Promise<TeamLookbackStopRow[] | null> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("team_lookback_stops");
  if (error) {
    logEvent("warn", "plan3.team_lookback_failed", errorFields(error));
    return null;
  }
  return data ?? [];
}

/** PLAN3-11: the entries for `/team`, one per stop and team (type kept narrow for the client component). */
export function toTeamLookbackStops(rows: TeamLookbackStopRow[] | null): TeamLookbackStop[] {
  return (rows ?? []).map((r) => ({
    stop_id: r.stop_id,
    agent_name: r.agent_name,
    team_name: r.team_name,
    open_count: r.open_count,
    not_open_count: r.not_open_count,
  }));
}

export type VisitRecord = {
  id: string;
  team_id: string | null;
  responsible_user_id: string | null;
  visit_date: string | null;
  time_start: string | null;
  time_end: string | null;
  status: string | null;
  team_name: string | null;
  responsible_name: string | null;
  /** PLAN3-17 (2) (ADR-159): the picker label of the responsible member; null when nobody is responsible. */
  responsible_label: string | null;
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
  // PLAN3-17 (2) (ADR-159): the caller's own roster of the visit's team (`team_cases`, her own teams only) gives the
  // "(du)" mark and the /team number; a failed read or no membership falls back to the name (never a guessed number).
  let roster: TeamMemberOption[] | null = null;
  if (v.team_id && v.responsible_user_id) {
    try {
      roster = (await loadTeams()).find((t) => t.team_id === v.team_id)?.members ?? null;
    } catch {
      roster = null;
    }
  }
  return {
    id: v.id,
    team_id: v.team_id,
    responsible_user_id: v.responsible_user_id,
    visit_date: v.visit_date,
    time_start: v.time_start,
    time_end: v.time_end,
    status: v.status,
    team_name: team.data?.name ?? null,
    responsible_name: profile.data?.display_name ?? null,
    responsible_label: responsibleMemberLabel(v.responsible_user_id, profile.data?.display_name ?? null, roster),
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

export type RecordLookbackLine = Fn["record_lookback_lines"]["Returns"][number];

export type RecordLookback = {
  lines: RecordLookbackLine[];
  /** Members of the record's team for "Ändern" (from the caller's own case list, `team_cases`). */
  members: TeamMemberOption[];
};

/**
 * AIG1-C2 (a)/(d): the look-back lines of this record, for active members of the record's team only
 * (`record_lookback_lines`; a coordinator who is not a team member gets none, so the page shows her no control), and,
 * when there is a line of a visit still open, the team's members for "Ändern" (the confirm screen's source).
 */
export async function getRecordLookback(visitId: string, teamId: string | null): Promise<RecordLookback> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("record_lookback_lines", {
    p_entity_type: "care_visits",
    p_entity_id: visitId,
  });
  if (error) {
    logEvent("warn", "aig1.record_lookback_failed", errorFields(error));
    return { lines: [], members: [] };
  }
  const lines = data ?? [];
  if (!teamId || !lines.some((l) => l.record_open)) return { lines, members: [] };
  const team = (await loadTeams()).find((t) => t.team_id === teamId);
  return { lines, members: team?.members ?? [] };
}

/**
 * AIG1-C3 (1): the role's home for the record page's back link when the page was not opened from a list (own
 * memberships only, RLS; the same rule as the landing page after sign-in).
 */
export async function getHomeLink(): Promise<{ href: string; label: string }> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.from("organization_memberships").select("role");
  if (error) logEvent("warn", "aig1.memberships_failed", errorFields(error));
  const href = homePathForRoles((data ?? []).map((m) => m.role));
  return { href, label: href === FIELD_PATH ? PAGE_LABEL.field : PAGE_LABEL.operations };
}

const numOrNull = (v: unknown): number | null => (v === null || v === undefined ? null : Number(v));

/**
 * PLAN3-7 (ADR-151): the day-plan assistant's measures per team for one Zurich month (`plan3_team_measures`, migration
 * 0113), as the signed-in person may read them (own teams; coordinators every team). Null when the read failed: the
 * page then says so rather than showing zeros.
 */
export async function getPlanTeamMeasures(month: string): Promise<PlanTeamMeasure[] | null> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("plan3_team_measures", { p_month: month });
  if (error) {
    logEvent("warn", "plan3.team_measures_failed", errorFields(error));
    return null;
  }
  return (data ?? []).map((r) => ({
    ...r,
    enabled_since: r.enabled_since ?? null,
    decided_lines: numOrNull(r.decided_lines),
    confirmed_unchanged_share: numOrNull(r.confirmed_unchanged_share),
    corrected_share: numOrNull(r.corrected_share),
    rejected_share: numOrNull(r.rejected_share),
    confirm_actions_per_plan: numOrNull(r.confirm_actions_per_plan),
    minutes_to_last_decision_median: numOrNull(r.minutes_to_last_decision_median),
    no_proposal: numOrNull(r.no_proposal),
    no_proposal_share: numOrNull(r.no_proposal_share),
    no_proposal_not_active: numOrNull(r.no_proposal_not_active),
    no_proposal_needs_rn: numOrNull(r.no_proposal_needs_rn),
    no_proposal_absent: numOrNull(r.no_proposal_absent),
    no_proposal_overlap: numOrNull(r.no_proposal_overlap),
    continuity_before_share: numOrNull(r.continuity_before_share),
    continuity_after_share: numOrNull(r.continuity_after_share),
  }));
}
