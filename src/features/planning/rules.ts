// PLAN2 self-planning — pure helpers (ADR-042). The database generates the visits; this formats and checks input.

export const WEEKDAYS: ReadonlyArray<{ iso: number; short: string }> = [
  { iso: 1, short: "Mo" }, { iso: 2, short: "Di" }, { iso: 3, short: "Mi" }, { iso: 4, short: "Do" },
  { iso: 5, short: "Fr" }, { iso: 6, short: "Sa" }, { iso: 7, short: "So" },
];

export type Schedule = {
  freq_times: number | null;
  freq_period: string | null;
  freq_weekdays: number[] | null;
  window_start: string | null;
  window_end: string | null;
};

const hhmm = (t: string | null) => (t ? t.slice(0, 5) : "");

/** "täglich 08:00–09:00", "2× pro Woche (Mo, Do) 08:00–09:00", or null when not planned automatically. */
export function describeSchedule(s: Schedule): string | null {
  if (!s.freq_period || !s.window_start || !s.window_end) return null;
  const window = `${hhmm(s.window_start)}–${hhmm(s.window_end)}`;
  if (s.freq_period === "day") return `täglich ${window}`;
  const days = s.freq_weekdays?.length
    ? ` (${s.freq_weekdays.map((d) => WEEKDAYS.find((w) => w.iso === d)?.short ?? d).join(", ")})`
    : "";
  return `${s.freq_times}× pro Woche${days} ${window}`;
}

/** Client-side mirror of the database check in set_care_plan_schedule. */
export function scheduleError(period: string, times: number, weekdays: number[], start: string, end: string): string | null {
  if (period !== "day" && period !== "week") return "Rhythmus wählen.";
  if (!/^\d{2}:\d{2}$/.test(start) || !/^\d{2}:\d{2}$/.test(end) || end <= start) return "Zeitfenster: Ende nach Beginn.";
  if (period === "day") return weekdays.length > 0 ? "Täglich gilt für jeden Tag; keine Wochentage wählen." : null;
  if (!Number.isInteger(times) || times < 1 || times > 7) return "1 bis 7 Mal pro Woche.";
  if (weekdays.length > 0 && weekdays.length !== times) return `Genau ${times} Wochentag${times === 1 ? "" : "e"} wählen oder keine.`;
  return null;
}

/** Why nothing (more) is planned automatically for a case. */
export const BLOCKED_LABEL: Record<string, string> = {
  series_off: "Automatische Planung ist ausgeschaltet.",
  case_paused: "Fall pausiert: keine neuen Einsätze.",
  case_closed: "Fall abgeschlossen.",
  reopened_not_ready: "Wiedereröffnet: zuerst die Aufnahme-Checkliste erfüllen.",
  assessment_first: "Zuerst die Bedarfsabklärung planen und durchführen.",
  order_missing: "Ohne ärztliche Verordnung wird keine B-Leistung geplant.",
};

export const REASON_LABEL: Record<string, string> = {
  ...BLOCKED_LABEL,
  items_without_schedule: "Einige Leistungen haben keinen Rhythmus und werden nicht automatisch geplant.",
  order_missing_or_expired: "B-Leistungen ohne gültige Verordnung wurden weggelassen.",
  minutes_exceed_window: "An einigen Tagen passen die Minuten nicht ins Zeitfenster.",
  already_planned: "Wo das Team schon von Hand geplant hat, entsteht kein zweiter Einsatz.",
  no_team: "Kein Team zugewiesen.",
};

export const PLANNING_MESSAGES: Record<string, string> = {
  invalid: "Bitte die Angaben prüfen.",
  failed: "Die Planung konnte nicht gespeichert werden.",
  rejected: "Nur das zuständige Team plant diesen Fall.",
  unchanged: "Keine Änderung.",
};
