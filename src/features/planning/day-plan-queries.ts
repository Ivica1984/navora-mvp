import "server-only";

// PLAN3 part (b) (ADR-147): what /team/tagesplan reads. Only existing readers, no new grant: `team_cases` (the caller's
// teams and their clients), `team_day_proposal_state`, `day_plan`, `day_plan_load` (0109/0110; active members of the
// team only, no confirmer, no actor of the team switch).

import type { Database } from "@/lib/supabase/database.types";
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import type { DayPlanLine, DayPlanLoadRow, DayPlanRosterEntry } from "./day-plan-view";

type Fn = Database["public"]["Functions"];
export type DayPlanState = Fn["team_day_proposal_state"]["Returns"][number];

export type DayPlanTeam = {
  team_id: string;
  team_name: string;
  /** case id → client name, from the caller's own case list (`team_cases`). */
  clients: Record<string, string>;
  /**
   * CGR-139: the team's members as `team_cases` lists them (every membership ordered by user id, the caller marked), so
   * an unnamed member reads "Teammitglied <n> (ohne Namen)" with the number /team and the handover use. Ids only.
   */
  roster: DayPlanRosterEntry[];
};

/** The caller's teams with a running case, and the names of their clients (team_cases: own teams only). */
export async function getDayPlanTeams(): Promise<DayPlanTeam[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("team_cases");
  if (error) {
    logEvent("error", "plan3.team_cases_failed", errorFields(error));
    throw new Error("Teams konnten nicht geladen werden.");
  }
  const teams = new Map<string, DayPlanTeam>();
  for (const c of data ?? []) {
    let t = teams.get(c.team_id);
    if (!t) {
      t = { team_id: c.team_id, team_name: c.team_name, clients: {}, roster: [] };
      teams.set(c.team_id, t);
    }
    if (t.roster.length === 0 && Array.isArray(c.members)) {
      for (const m of c.members as unknown[]) {
        if (typeof m !== "object" || m === null) continue;
        const r = m as Record<string, unknown>;
        if (typeof r.user_id === "string") t.roster.push({ user_id: r.user_id, me: r.me === true });
      }
    }
    if (c.client_name) t.clients[c.case_id] = c.client_name;
  }
  return [...teams.values()];
}

/** PLAN3-10 / PLAN3-6: may the team ask (its own switch, the organisation's agent state)? Null outside the team. */
export async function getDayPlanState(teamId: string): Promise<DayPlanState | null> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("team_day_proposal_state", { p_team_id: teamId });
  if (error) {
    logEvent("error", "plan3.state_failed", errorFields(error));
    throw new Error("Der Tagesvorschlag konnte nicht geladen werden.");
  }
  return data?.[0] ?? null;
}

/** PLAN3-3/-4/-9: the newest proposal of the team and day, and every member's minutes now and with it. */
export async function getDayPlan(teamId: string, date: string): Promise<{ lines: DayPlanLine[]; load: DayPlanLoadRow[] }> {
  const { supabase } = await requireUser();
  const [lines, load] = await Promise.all([
    supabase.rpc("day_plan", { p_team_id: teamId, p_date: date }),
    supabase.rpc("day_plan_load", { p_team_id: teamId, p_date: date }),
  ]);
  if (lines.error || load.error) {
    logEvent("error", "plan3.day_plan_failed", errorFields((lines.error ?? load.error)!));
    throw new Error("Der Vorschlag konnte nicht geladen werden.");
  }
  return { lines: lines.data ?? [], load: load.data ?? [] };
}
