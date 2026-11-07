// VIS2 (ADR-121; PO brief docs/agents/briefs/VIS2.md; `cra` CGR-97). Display rules only: whether a client has another
// visit at an overlapping time is decided by the database (`client_visit_overlap`, migration 0098, pgTAP 098). Nothing
// here refuses, ranks or routes a visit.

/** The server's answer: null when there is none (not allowed to read the client, incomplete slot, read failed). */
export type OverlapFact = { overlap: boolean; timeStart: string | null; timeEnd: string | null } | null;

const HHMM = /^([01]\d|2[0-3]):[0-5]\d$/;
const DAY = /^\d{4}-\d{2}-\d{2}$/;
const hhmmOrNull = (v: unknown): string | null => (typeof v === "string" && HHMM.test(v) ? v : null);

/** Parses the RPC result (or a command result's `overlap`) defensively; anything unexpected is "no answer". */
export function parseOverlapFact(data: unknown): OverlapFact {
  if (typeof data !== "object" || data === null) return null;
  const d = data as { overlap?: unknown; time_start?: unknown; time_end?: unknown };
  if (typeof d.overlap !== "boolean") return null;
  const start = d.overlap ? hhmmOrNull(d.time_start) : null;
  const end = start ? hhmmOrNull(d.time_end) : null;
  return { overlap: d.overlap, timeStart: start && end ? start : null, timeEnd: start && end ? end : null };
}

function shortDate(day: string): string {
  const [y, m, d] = day.split("-");
  return `${d}.${m}.${y}`;
}

function dayPart(day: string, today: string): string {
  if (day === today) return "heute";
  const [y, m, d] = day.split("-").map(Number);
  const weekday = new Intl.DateTimeFormat("de-CH", { timeZone: "UTC", weekday: "long" }).format(new Date(Date.UTC(y, m - 1, d)));
  return `am ${weekday}, ${shortDate(day)}`;
}

/**
 * VIS2-1 / VIS2-2: the one `info` sentence before saving (wording `uxa` 23:55, PO note 2026-10-30 00:15). With a
 * visit she can read its times; with only a visit she cannot read (another team's) no time, team, member or service,
 * and never "kein Einsatz". No overlap or no answer: no sentence.
 */
export function overlapNote(day: string, fact: OverlapFact, today: string): string | null {
  if (!fact || !fact.overlap || !DAY.test(day)) return null;
  const when = dayPart(day, today);
  return fact.timeStart && fact.timeEnd
    ? `Bei dieser Person ist ${when} von ${fact.timeStart} bis ${fact.timeEnd} bereits ein Einsatz geplant.`
    : `Bei dieser Person ist ${when} zu einer Zeit, die sich mit diesem Einsatz überschneidet, bereits ein Einsatz geplant.`;
}

/**
 * VIS2-5 (2): after a save, the server's own check is shown on the card only when it found an overlap the form did not
 * show (times edited before the answer arrived, or a visit added meanwhile). Never a refusal.
 */
export function overlapAfterSave(shown: boolean, server: OverlapFact): OverlapFact {
  return !shown && server?.overlap ? server : null;
}

/** VIS2-5 (2) on /field: the server's overlap travels to today's view as `ueberschneidung` (display only). */
export function overlapParam(fact: OverlapFact): string | null {
  if (!fact?.overlap) return null;
  return fact.timeStart && fact.timeEnd ? `${fact.timeStart}-${fact.timeEnd}` : "1";
}

export function parseOverlapParam(raw: string | string[] | undefined): OverlapFact {
  const v = Array.isArray(raw) ? raw[0] : raw;
  if (v === "1") return { overlap: true, timeStart: null, timeEnd: null };
  const m = /^(\d{2}:\d{2})-(\d{2}:\d{2})$/.exec(v ?? "");
  if (!m || !HHMM.test(m[1]) || !HHMM.test(m[2])) return null;
  return { overlap: true, timeStart: m[1], timeEnd: m[2] };
}

// VIS2-3: cards of the same client whose times overlap on /field -------------------------------------------------------

export type CardLike = {
  visit_id: string;
  case_id: string | null;
  visit_date: string | null;
  time_start: string | null;
  time_end: string | null;
  planned_minutes_a: number | null;
  planned_minutes_b: number | null;
  planned_minutes_c: number | null;
  status: string | null;
};

const minutesOf = (t: string | null): number | null => {
  if (!t) return null;
  const m = /^(\d{2}):(\d{2})/.exec(t);
  return m ? Number(m[1]) * 60 + Number(m[2]) : null;
};

/**
 * The card's planned interval in minutes of its day, half-open, as the database reads it (`visit_wall_range`): no start
 * = the whole day; no end (or end = start) = start + planned minutes, else to the end of the day; an end before the
 * start runs to midnight on this card's day.
 */
export function cardInterval(v: CardLike): [number, number] {
  const s = minutesOf(v.time_start);
  if (s === null) return [0, 1440];
  const e = minutesOf(v.time_end);
  if (e === null || e === s) {
    const planned = (v.planned_minutes_a ?? 0) + (v.planned_minutes_b ?? 0) + (v.planned_minutes_c ?? 0);
    return [s, planned > 0 ? Math.min(s + planned, 1440) : 1440];
  }
  return [s, e < s ? 1440 : e];
}

/**
 * VIS2-3: for every card that shares its client (case) and an overlapping time with another card of the same day,
 * its position "n of m" within that group (connected overlaps form one group; ordered by start, then id, so the
 * numbering is stable across renders). Cancelled visits are not counted (as the database). Cards without a case or a
 * date are never grouped. Display only.
 */
export function sameSlotPositions(cards: ReadonlyArray<CardLike>): Map<string, { index: number; total: number }> {
  const out = new Map<string, { index: number; total: number }>();
  const byClientDay = new Map<string, CardLike[]>();
  for (const c of cards) {
    if (!c.case_id || !c.visit_date || c.status === "cancelled") continue;
    const key = `${c.case_id}|${c.visit_date}`;
    const list = byClientDay.get(key) ?? [];
    list.push(c);
    byClientDay.set(key, list);
  }
  for (const list of byClientDay.values()) {
    if (list.length < 2) continue;
    const sorted = [...list].sort((a, b) => {
      const [as] = cardInterval(a);
      const [bs] = cardInterval(b);
      return as - bs || (a.visit_id < b.visit_id ? -1 : a.visit_id > b.visit_id ? 1 : 0);
    });
    let group: CardLike[] = [];
    let groupEnd = -1;
    const flush = () => {
      if (group.length > 1) group.forEach((c, i) => out.set(c.visit_id, { index: i + 1, total: group.length }));
      group = [];
    };
    for (const c of sorted) {
      const [s, e] = cardInterval(c);
      if (group.length > 0 && s < groupEnd) {
        group.push(c);
        groupEnd = Math.max(groupEnd, e);
      } else {
        flush();
        group = [c];
        groupEnd = e;
      }
    }
    flush();
  }
  return out;
}

/** VIS2-3 (`uxa` wording): the part of the accessible name that tells two such cards apart. */
export function sameSlotLine(pos: { index: number; total: number }): string {
  return `${pos.index} von ${pos.total} zu dieser Zeit`;
}

/** VIS2-3: the visible `info` line: the position and the responsible member (as the card states her). */
export function sameSlotInfo(pos: { index: number; total: number }, responsible: string): string {
  return `${sameSlotLine(pos)} · Verantwortlich: ${responsible}`;
}

/** VIS2-3: the card's accessible name; unchanged for a card without a same-slot sibling. */
export function cardAccessibleName(time: string, client: string, pos: { index: number; total: number } | undefined): string {
  return pos ? `Einsatz ${time}, ${client}, ${sameSlotLine(pos)}` : `Einsatz ${time}, ${client}`;
}
