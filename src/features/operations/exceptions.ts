// OPS1 exception center — pure helpers (ADR-002). Exceptions themselves are derived in the
// database (public.operations_exceptions, migration 0019); this only formats and groups them.

export type ExceptionLike = {
  priority: string;
  since: string;
  taken: boolean;
  taken_by_me: boolean;
  /** ADM1: display name of whoever took it over (null without a profile). */
  owner_name?: string | null;
  /** CSR1 / CGR-06: false for safety exceptions (P1 or escalating to P1); they close only with their cause. */
  closable?: boolean | null;
};

export const PRIORITY_LABEL: Record<string, string> = {
  P1: "Sicherheit",
  P2: "Kontinuität",
  P3: "Administration",
};

/** "seit 3 h", "seit 2 T", "in 5 h" (an uncovered visit lies in the future). */
export function formatAge(sinceIso: string, now = Date.now()): string {
  const minutes = Math.round((now - Date.parse(sinceIso)) / 60_000);
  const future = minutes < 0;
  const m = Math.abs(minutes);
  const text = m < 60 ? `${m} min` : m < 48 * 60 ? `${Math.round(m / 60)} h` : `${Math.round(m / 1440)} T`;
  return future ? `in ${text}` : `seit ${text}`;
}

export function countByPriority(items: ExceptionLike[]): Record<"P1" | "P2" | "P3", number> {
  const counts = { P1: 0, P2: 0, P3: 0 };
  for (const item of items) {
    if (item.priority === "P1" || item.priority === "P2" || item.priority === "P3") counts[item.priority] += 1;
  }
  return counts;
}

/** Who handles it: nobody, me, or a colleague. */
export function handlerLabel(item: ExceptionLike): string {
  if (!item.taken) return "offen – niemand übernommen";
  if (item.taken_by_me) return "von dir übernommen";
  return item.owner_name ? `von ${item.owner_name} übernommen` : "von Operations übernommen";
}

/**
 * CSR1 / CGR-06: whether a person may close it. Only an explicit `true` from the database allows it, so a
 * missing value never offers a close for a safety exception.
 */
export function canClose(item: Pick<ExceptionLike, "closable">): boolean {
  return item.closable === true;
}

// Shown where the database says closable = false: safety exceptions (CSR1 / CGR-06, 0039) and uncovered visits
// (CSR1 / CGR-22, 0044, provisional until D-28).
export const CLOSES_WITH_CAUSE =
  "Kein Schliessen von Hand: schliesst automatisch, sobald die Ursache behoben ist (z. B. jemand zuständig, Einsatz begonnen oder abgesagt, Ergebnis erfasst, Ereignis abgeschlossen).";

export type Comment = { text: string; at: string; mine: boolean };

export function parseComments(raw: unknown): Comment[] {
  if (!Array.isArray(raw)) return [];
  return raw.filter(
    (c): c is Comment => !!c && typeof c === "object" && typeof (c as Comment).text === "string" && typeof (c as Comment).at === "string",
  );
}
