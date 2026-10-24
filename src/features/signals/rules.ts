// SIG1 (migration 0060, ADR-074): fixed texts and pure helpers for P1 safety signals on /field, /team and OPS1.
// Pure module (no "use server"), unit-tested in tests/unit/signals-rules.test.ts.

/** The brief's fixed text per kind (SIG1-3). Never configurable; no client name, no free text. */
export const SIGNAL_TEXT: Record<string, string> = {
  visit_overdue: "Einsatz überfällig",
  visit_stuck: "Einsatz hängt",
  visit_uncovered: "Einsatz ohne Zuständige",
  visit_interrupted: "Einsatz abgebrochen",
  no_show: "Klientin öffnet nicht",
};

/** Polling interval: a new P1 shows within 60 s (SIG1-3); the server throttles evaluation to once per 15 s. */
export const SIGNAL_POLL_MS = 30_000;

export const TAKE_MESSAGES: Record<string, string> = {
  not_recipient: "Dieses Signal ist nicht an dich gerichtet.",
  signal_ended: "Die Ursache ist behoben, das Signal ist beendet.",
  failed: "Konnte nicht gespeichert werden. Bitte nochmals versuchen.",
  invalid: "Ungültige Eingabe.",
};

export type SignalRow = {
  signal_id: string;
  signal_kind: string;
  visit_id: string;
  visit_date: string;
  time_start: string | null;
  team_name: string;
  reason: string;
  delivered_at: string;
  taken_by_me: boolean;
  taken_by_name: string | null;
  taken_at: string | null;
  /** SIG2-5: nobody received it outside the app, so Operations got it at once. */
  outside_none?: boolean | null;
};

export function signalText(kind: string): string {
  return SIGNAL_TEXT[kind] ?? "Sicherheitssignal";
}

/** "24.10. 07:00 · Testteam Nord" — date and planned start of the visit, and the owning team. */
export function signalWhen(row: Pick<SignalRow, "visit_date" | "time_start" | "team_name">): string {
  const [, m, d] = row.visit_date.split("-");
  const time = row.time_start ? ` ${row.time_start.slice(0, 5)}` : "";
  return `${d}.${m}.${time} · ${row.team_name}`;
}

/** Link to the visit's day in the field tool. */
export function signalHref(row: Pick<SignalRow, "visit_date">): string {
  return `/field?datum=${row.visit_date}`;
}

/** SIG1-4: untaken signals at the top; taken ones leave the top list and show who took them. */
export function splitSignals<T extends Pick<SignalRow, "taken_by_name" | "taken_by_me">>(rows: T[]): { open: T[]; taken: T[] } {
  const open: T[] = [];
  const taken: T[] = [];
  for (const r of rows) (r.taken_by_name || r.taken_by_me ? taken : open).push(r);
  return { open, taken };
}

export function takenText(row: Pick<SignalRow, "taken_by_me" | "taken_by_name">): string {
  return row.taken_by_me ? "von dir übernommen" : `übernommen von ${row.taken_by_name ?? "Teammitglied"}`;
}

/** Why the person received it (Operations rows say so). */
export function reasonText(reason: string, outsideNone = false): string | null {
  if (reason === "operations_fallback") return "an Operations: niemand im Team im Dienst";
  // SIG2-5: "kein Empfänger ausserhalb der App" → Operations at once, without waiting for the untaken threshold.
  if (reason === "untaken" && outsideNone) return "an Operations: kein Empfänger ausserhalb der App";
  if (reason === "untaken") return "an Operations: nicht rechtzeitig übernommen";
  return null;
}

export function takeOutcome(data: unknown): { result: string; reason?: string } {
  if (data && typeof data === "object" && "result" in data) {
    const d = data as { result: unknown; reason?: unknown };
    return { result: String(d.result), reason: d.reason == null ? undefined : String(d.reason) };
  }
  return { result: "failed" };
}
