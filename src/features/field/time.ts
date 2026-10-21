// Visit time from the event timeline (F2) — pure TypeScript (ADR-002).
// DOMAIN_RULES: travel, care and pause are kept separate; no negative times.
// Times are facts for the team's own overview only: payroll relevance and
// billability are separate, later decisions (Lohnrelevanz ≠ Tarifabrechenbarkeit).

export type VisitEventType = "departed" | "started" | "paused" | "resumed" | "completed";
export type VisitEvent = { type: VisitEventType | string; at: string };

export type VisitTimes = {
  /** Minutes from departure to arrival (first start). null if no departure was recorded. */
  travelMinutes: number | null;
  /** Minutes of care: started/resumed until paused/completed (or now while running). */
  careMinutes: number | null;
  /** Minutes paused: paused until resumed (or now while paused). */
  pauseMinutes: number | null;
  /** True when the timeline is not in a consistent order (data must be checked, not guessed). */
  inconsistent: boolean;
};

const MINUTE = 60_000;

function minutes(ms: number): number {
  return Math.floor(ms / MINUTE);
}

/** Parses the jsonb timeline returned by public.field_visits(). Unknown shapes become an empty list. */
export function parseEvents(raw: unknown): VisitEvent[] {
  if (!Array.isArray(raw)) return [];
  return raw.filter(
    (e): e is VisitEvent =>
      typeof e === "object" && e !== null &&
      typeof (e as { type?: unknown }).type === "string" &&
      typeof (e as { at?: unknown }).at === "string" &&
      !Number.isNaN(Date.parse((e as { at: string }).at))
  );
}

export function computeVisitTimes(events: ReadonlyArray<VisitEvent>, now: Date = new Date()): VisitTimes {
  let travel: number | null = null;
  let care: number | null = null;
  let pause: number | null = null;
  let inconsistent = false;

  let departedAt: number | null = null;
  let careSince: number | null = null;
  let pauseSince: number | null = null;
  let last = -Infinity;

  for (const event of events) {
    const at = Date.parse(event.at);
    if (at < last) inconsistent = true; // never produce negative durations silently
    last = Math.max(last, at);

    switch (event.type) {
      case "departed":
        departedAt = at;
        break;
      case "started":
        if (departedAt !== null && travel === null) travel = Math.max(0, at - departedAt);
        careSince = at;
        break;
      case "paused":
        if (careSince !== null) care = (care ?? 0) + Math.max(0, at - careSince);
        careSince = null;
        pauseSince = at;
        break;
      case "resumed":
        if (pauseSince !== null) pause = (pause ?? 0) + Math.max(0, at - pauseSince);
        pauseSince = null;
        careSince = at;
        break;
      case "completed":
        if (careSince !== null) care = (care ?? 0) + Math.max(0, at - careSince);
        careSince = null;
        break;
    }
  }

  const nowMs = now.getTime();
  // Still travelling, still caring or still paused: count up to now.
  if (departedAt !== null && travel === null && careSince === null && pauseSince === null) {
    travel = Math.max(0, nowMs - departedAt);
  }
  if (careSince !== null) care = (care ?? 0) + Math.max(0, nowMs - careSince);
  if (pauseSince !== null) pause = (pause ?? 0) + Math.max(0, nowMs - pauseSince);

  return {
    travelMinutes: travel === null ? null : minutes(travel),
    careMinutes: care === null ? null : minutes(care),
    pauseMinutes: pause === null ? null : minutes(pause),
    inconsistent,
  };
}

export function formatMinutes(value: number | null): string {
  if (value === null) return "–";
  if (value < 60) return `${value} min`;
  const h = Math.floor(value / 60);
  const m = value % 60;
  return m === 0 ? `${h} h` : `${h} h ${m} min`;
}
