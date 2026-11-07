/**
 * PLAN3-9 (2) (ADR-160, `uxa` UXR-103): one place decides a day-plan line. On `/team/vorschlaege` the open lines of a
 * PLAN3 day plan are not listed one by one with their own "Bestätigen"; each open day plan is one row that links to
 * its day on `/team/tagesplan`, where the lines are decided. The day of a line is `day_plan_lines.plan_date` as the
 * database returns it (`open_day_plan_lines`, migration 0117), never the visit date. Wording only; no rule.
 */
import { dayPlanDateBounds } from "@/features/planning/day-plan-view";

/** The PLAN3 agent (migration 0109). Its proposals are day-plan lines. */
export const DAY_PLAN_AGENT_KEY = "plan3_day_proposal";

export type OpenDayPlanLine = { suggestion_id: string; plan_date: string };
export type DayPlanRow = { plan_date: string; open: number };

export type SplitSuggestions<T> = {
  /** Proposals still decided one by one on this screen. */
  perLine: T[];
  /** One row per open day plan the day page can open, ordered by date. */
  days: DayPlanRow[];
  /** Open day-plan lines whose day could not be read: not listed per line (fail closed), named by count only. */
  unread: number;
};

/**
 * Splits the open proposals of one team. A day-plan line with a known day the day page can open becomes part of that
 * day's row. A line of a day before today stays on its own line, because `/team/tagesplan` opens today to 14 days
 * ahead only (ADR-160 deviation 1). A day-plan line whose day is unknown (read failed or row missing) is never shown
 * per line; it is counted in `unread`.
 */
export function splitDayPlanSuggestions<T extends { suggestion_id: string; agent_key: string }>(
  suggestions: readonly T[],
  lines: readonly OpenDayPlanLine[] | null,
  today: string,
): SplitSuggestions<T> {
  const dayOf = new Map((lines ?? []).map((l) => [l.suggestion_id, l.plan_date]));
  const { min } = dayPlanDateBounds(today);
  const perLine: T[] = [];
  const counts = new Map<string, number>();
  let unread = 0;
  for (const s of suggestions) {
    if (s.agent_key !== DAY_PLAN_AGENT_KEY) {
      perLine.push(s);
      continue;
    }
    const day = dayOf.get(s.suggestion_id);
    if (!day) {
      unread += 1;
    } else if (day < min) {
      perLine.push(s);
    } else {
      counts.set(day, (counts.get(day) ?? 0) + 1);
    }
  }
  const days = [...counts.entries()]
    .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
    .map(([plan_date, open]) => ({ plan_date, open }));
  return { perLine, days, unread };
}

/** "Tagesvorschlag Samstag, 07.11.2026: 5 offen" (date-only, so no time zone shift). */
export function dayPlanRowText(planDate: string, open: number): string {
  const [y, m, d] = planDate.split("-").map(Number);
  const weekday = new Intl.DateTimeFormat("de-CH", { timeZone: "UTC", weekday: "long" }).format(new Date(Date.UTC(y, m - 1, d)));
  const [yy, mm, dd] = planDate.split("-");
  return `Tagesvorschlag ${weekday}, ${dd}.${mm}.${yy}: ${open} offen`;
}

/** The day on `/team/tagesplan`, with the page's own parameters (`team`, `datum`). */
export function dayPlanRowHref(teamId: string, planDate: string): string {
  const q = new URLSearchParams({ team: teamId, datum: planDate });
  return `/team/tagesplan?${q.toString()}`;
}

/** Shown when open day-plan lines could not be placed on their day. Count only. */
export function dayPlanUnreadText(n: number): string {
  return n === 1
    ? "1 Zeile eines Tagesvorschlags konnte nicht zugeordnet werden. Öffne den Tagesvorschlag."
    : `${n} Zeilen eines Tagesvorschlags konnten nicht zugeordnet werden. Öffne den Tagesvorschlag.`;
}
