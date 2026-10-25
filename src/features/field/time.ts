// Visit time from the event timeline (F2) — pure TypeScript (ADR-002).
// DOMAIN_RULES: travel, care and pause are kept separate; no negative times.
// Times are facts for the team's own overview only: payroll relevance and
// billability are separate, later decisions (Lohnrelevanz ≠ Tarifabrechenbarkeit).

export type VisitEventType = "departed" | "started" | "paused" | "resumed" | "completed" | "interrupted";
export type VisitEvent = {
  type: VisitEventType | string;
  /** Effective time: the latest correction, else the recorded time (F3). */
  at: string;
  id?: number;
  /** Time recorded by the transition itself (F3: stays visible after a correction). */
  recorded_at?: string;
  corrected?: boolean;
  reason?: string | null;
};

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
      // CSR1 / CGR-20: ended as not completed. The clock stops; the minutes are shown, never counted as completed care.
      case "interrupted":
        if (careSince !== null) care = (care ?? 0) + Math.max(0, at - careSince);
        if (pauseSince !== null) pause = (pause ?? 0) + Math.max(0, at - pauseSince);
        careSince = null;
        pauseSince = null;
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

export const EVENT_LABEL: Record<string, string> = {
  departed: "Losgefahren",
  started: "Gestartet",
  paused: "Pause begonnen",
  resumed: "Fortgesetzt",
  completed: "Abgeschlossen",
  interrupted: "Nicht abgeschlossen beendet",
};

const ZONE = "Europe/Zurich";

/** "HH:MM" of an instant in Swiss local time. */
export function zurichTime(iso: string): string {
  return new Intl.DateTimeFormat("de-CH", { timeZone: ZONE, hour: "2-digit", minute: "2-digit", hourCycle: "h23" })
    .format(new Date(iso));
}

/** "YYYY-MM-DD" of an instant in Swiss local time. */
export function zurichDate(iso: string): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: ZONE, year: "numeric", month: "2-digit", day: "2-digit" })
    .format(new Date(iso));
}

function zurichOffsetMinutes(utcMs: number): number {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: ZONE, hourCycle: "h23", year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit",
  }).formatToParts(new Date(utcMs));
  const get = (t: string) => Number(parts.find((p) => p.type === t)?.value);
  const asUtc = Date.UTC(get("year"), get("month") - 1, get("day"), get("hour"), get("minute"));
  return Math.round((asUtc - Math.floor(utcMs / 60_000) * 60_000) / 60_000);
}

/**
 * Swiss wall-clock time ("YYYY-MM-DD", "HH:MM") → ISO instant. Returns null for
 * malformed input. Same rule as the database (`private.at_zurich`, ADR-081, DST1):
 * in the autumn repeated hour (02:00-02:59) the EARLIER instant (CEST) is chosen;
 * a time skipped in spring (02:00-02:59) is read in standard time (CET), i.e. it
 * resolves to the instant one hour later on the clock — both are shown back to
 * the user before saving.
 */
export function zurichLocalToIso(day: string, hhmm: string): string | null {
  const d = /^(\d{4})-(\d{2})-(\d{2})$/.exec(day);
  const t = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(hhmm);
  if (!d || !t) return null;
  const wall = Date.UTC(+d[1], +d[2] - 1, +d[3], +t[1], +t[2]);
  // The offsets in force around this wall time (at most two in Zurich: CET +60, CEST +120).
  const offsets = [...new Set([zurichOffsetMinutes(wall - 86_400_000), zurichOffsetMinutes(wall + 86_400_000)])];
  const valid = offsets
    .map((o) => wall - o * 60_000)
    .filter((utc) => zurichOffsetMinutes(utc) * 60_000 === wall - utc);
  // Valid readings: one on an ordinary day, two in the repeated hour (take the earlier), none in the gap.
  const utc = valid.length > 0 ? Math.min(...valid) : wall - Math.min(...offsets) * 60_000;
  return new Date(utc).toISOString();
}
