// HD-3s-F2-F1 (CGR-289 (c), ADR-230): the hand path rejects a visit inside the window of a live take of its person
// (pause of a split take included) and names the take. Pure helpers: parse the server's facts, build the German text.
// The server decides; this only words what it returned. The home is named only when the server sent it (the take
// belongs to the planning team, CGR-137); never derived here.

export type TakeWindowFacts = {
  workDate: string; // YYYY-MM-DD, Europe/Zurich
  blocks: string; // «07:00 – 11:30 und 16:00 – 20:00» or «08:00 – 10:00»
  split: boolean;
  ownTeam: boolean;
  clientName: string | null;
};

export const TAKE_WINDOW_REASON = "member_take_window";

/** The backstop trigger's error (migration 0185): any other writer is refused without facts. */
export function isTakeWindowError(error: { code?: string; message?: string } | null | undefined): boolean {
  return !!error && error.code === "P0001" && error.message === TAKE_WINDOW_REASON;
}

export function parseTakeWindow(raw: unknown): TakeWindowFacts | null {
  if (!raw || typeof raw !== "object") return null;
  const r = raw as Record<string, unknown>;
  if (typeof r.work_date !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(r.work_date)) return null;
  if (typeof r.blocks !== "string" || r.blocks.trim() === "") return null;
  return {
    workDate: r.work_date,
    blocks: r.blocks,
    split: r.split === true,
    ownTeam: r.own_team === true,
    clientName: r.own_team === true && typeof r.client_name === "string" && r.client_name.trim() !== "" ? r.client_name : null,
  };
}

const WEEKDAYS = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"];

/** «Do 19.11.2026» from «2026-11-19» (a calendar date, no time zone shift). */
export function workDateLabel(isoDate: string): string {
  const [y, m, d] = isoDate.split("-").map(Number);
  const wd = WEEKDAYS[new Date(Date.UTC(y, m - 1, d)).getUTCDay()];
  return `${wd} ${String(d).padStart(2, "0")}.${String(m).padStart(2, "0")}.${y}`;
}

export type TakeWindowAction = "plan" | "move" | "take";

const LEAD: Record<TakeWindowAction, string> = {
  plan: "Nicht gespeichert: Die verantwortliche Person",
  move: "Nicht verschoben: Die verantwortliche Person",
  take: "Nicht übernommen: Du",
};

const WAY_OUT: Record<TakeWindowAction, string> = {
  plan: "Bitte eine andere Person oder eine andere Zeit wählen.",
  move: "Bitte eine andere Zeit wählen.",
  take: "Der Einsatz bleibt offen im Team.",
};

export function takeWindowText(facts: TakeWindowFacts | null, action: TakeWindowAction): string {
  const has = action === "take" ? "hast" : "hat";
  const pause = "Bei einem geteilten Dienst gilt auch die Pause zwischen den Blöcken als belegt.";
  if (!facts) {
    return `${LEAD[action]} ${has} zu dieser Zeit eine laufende Übernahme. ${pause} ${WAY_OUT[action]}`;
  }
  const where = facts.ownTeam ? (facts.clientName ? ` für ${facts.clientName}` : "") : " in einem anderen Team";
  const kind = facts.split ? "geteilte Übernahme" : "Übernahme";
  const pauseLine = facts.split ? ` Die Pause zwischen den Blöcken gilt als belegt.` : "";
  return `${LEAD[action]} ${has} am ${workDateLabel(facts.workDate)} eine laufende ${kind}${where}: ${facts.blocks}.${pauseLine} ${WAY_OUT[action]}`;
}
