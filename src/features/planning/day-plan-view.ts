/**
 * PLAN3 part (b) (ADR-147): the screen model of the day-plan proposal. The database decides every limit, reason and
 * decision (`day_plan`, `day_plan_load`, migrations 0109/0110); this module groups and words what they return and
 * never computes a rule of its own. No maximum load (PLAN3-4, D-23).
 */
import type { Database } from "@/lib/supabase/database.types";
import { memberNumbers } from "@/features/team/member-label";

type Fn = Database["public"]["Functions"];
export type DayPlanLine = Fn["day_plan"]["Returns"][number];
export type DayPlanLoadRow = Fn["day_plan_load"]["Returns"][number];

export type DayPlanMember = {
  member_id: string;
  name: string | null;
  /** CGR-139: her position in the team ordered by user id (as /team and the handover); null when not known. */
  no: number | null;
  /** CGR-139: she is the person planning ("(du)"). */
  me: boolean;
  /** Planned minutes of this team and day now / with the proposal's undecided lines; null when the load does not list her. */
  minutesNow: number | null;
  minutesWith: number | null;
  /** PLAN3-14: she has visits that day in another team (yes/no only). */
  otherTeams: boolean;
  lines: DayPlanLine[];
};

export type DayPlanGroups = { members: DayPlanMember[]; withoutProposal: DayPlanLine[] };

/** The team's members as `team_cases` lists them (every membership ordered by user id) with the caller marked. */
export type DayPlanRosterEntry = { user_id: string; me: boolean };

/**
 * PLAN3-9: one block per member (load order, every member of the load), then the lines with "kein Vorschlag".
 * CGR-139: with the team's roster each member also carries her team position and whether she is the caller.
 */
export function groupDayPlan(
  lines: readonly DayPlanLine[],
  load: readonly DayPlanLoadRow[],
  roster: readonly DayPlanRosterEntry[] = [],
): DayPlanGroups {
  const numbers = memberNumbers(roster);
  const meId = roster.find((r) => r.me)?.user_id ?? null;
  const ident = (id: string) => ({ no: numbers.get(id) ?? null, me: meId !== null && id === meId });
  const members: DayPlanMember[] = load.map((r) => ({
    member_id: r.member_id,
    name: r.member_name ?? null,
    ...ident(r.member_id),
    minutesNow: r.minutes_now ?? null,
    minutesWith: r.minutes_with_proposal ?? null,
    otherTeams: r.other_team_visits === true,
    lines: [],
  }));
  const byId = new Map(members.map((m) => [m.member_id, m]));
  const withoutProposal: DayPlanLine[] = [];
  for (const l of lines) {
    if (!l.member_id) {
      withoutProposal.push(l);
      continue;
    }
    let m = byId.get(l.member_id);
    if (!m) {
      m = {
        member_id: l.member_id,
        name: l.member_name ?? null,
        ...ident(l.member_id),
        minutesNow: null,
        minutesWith: null,
        otherTeams: false,
        lines: [],
      };
      byId.set(l.member_id, m);
      members.push(m);
    }
    m.lines.push(l);
  }
  return { members, withoutProposal };
}

/** CGR-78 (b): the lines a tick box is offered for. None is ticked by default; the screen ticks one line per tap. */
export function tickableLineIds(lines: readonly DayPlanLine[]): string[] {
  return lines.filter((l) => l.decision === "open" && l.bulk_allowed && !!l.member_id).map((l) => l.suggestion_id);
}

/** The minute categories of the visit ("A 30 min · B 15 min"), plus the needs assessment where it is one. */
export function minuteCategoryText(l: Pick<DayPlanLine, "minutes_a" | "minutes_b" | "minutes_c" | "is_needs_assessment">): string {
  const parts = (
    [
      ["A", l.minutes_a],
      ["B", l.minutes_b],
      ["C", l.minutes_c],
    ] as const
  )
    .filter(([, m]) => typeof m === "number" && m > 0)
    .map(([c, m]) => `${c} ${m} min`);
  const text = parts.length > 0 ? parts.join(" · ") : "ohne geplante Minuten";
  return l.is_needs_assessment ? `${text} · Bedarfsabklärung` : text;
}

/** PLAN3-9: the two facts a line shows where they apply. */
export function lineFlags(l: Pick<DayPlanLine, "changes_assignment" | "not_continuity">): string[] {
  const out: string[] = [];
  if (l.changes_assignment) out.push("ändert bisherige Zuteilung");
  if (l.not_continuity) out.push("nicht Bezugspflege/Stellvertretung");
  return out;
}

const DECISIONS: Readonly<Record<string, string>> = {
  confirmed: "bestätigt",
  corrected: "geändert und bestätigt",
  rejected: "abgelehnt",
  // PLAN3-9 (1) (`cra` CGR-138 (3), ADR-156): a decided "kein Vorschlag" sets nobody, so its text must not end in
  // "bestätigt". Engineering's text after `cra`'s example; the wording is OPEN for `uxa`.
  not_found: "„kein Vorschlag“, entschieden",
};

/** The state of a decided line (never who decided it: `day_plan` returns no confirmer). Null while open. */
export function lineDecisionText(decision: string): string | null {
  if (decision === "open") return null;
  return DECISIONS[decision] ?? "entschieden";
}

/**
 * PLAN3-9 (1) (ADR-156, `cra` CGR-138): a decided line whose visit has no responsible member now says "Noch offen" (the
 * wording of `/visits`), so a page of decided lines never reads as a covered day. The yes/no comes from `day_plan`
 * (0115); a missing value counts as nobody. Null on an open line (its decision controls are shown) or once the visit
 * has a responsible member.
 */
export function lineStillOpenText(l: Pick<DayPlanLine, "decision" | "visit_has_responsible">): string | null {
  if (l.decision === "open") return null;
  return l.visit_has_responsible === true ? null : "Noch offen";
}

/** PLAN3-4 / UXR-98: this team's planned minutes now and with the proposal; the scope is said, no judgement. */
export function loadText(now: number | null, withProposal: number | null): string | null {
  if (now === null || withProposal === null) return null;
  if (now === withProposal) return `${now} Minuten in eurem Team`;
  return `${now} → ${withProposal} Minuten in eurem Team`;
}

function addDays(iso: string, days: number): string {
  const d = new Date(`${iso}T12:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

/** PLAN3-1: a proposal is asked for today to today + 14 (Europe/Zurich); the database checks again (0109). */
export function dayPlanDateBounds(today: string): { min: string; max: string } {
  return { min: today, max: addDays(today, 14) };
}

export function isDayPlanDate(value: string, today: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const d = new Date(`${value}T12:00:00Z`);
  if (Number.isNaN(d.getTime()) || d.toISOString().slice(0, 10) !== value) return false;
  const { min, max } = dayPlanDateBounds(today);
  return value >= min && value <= max;
}
