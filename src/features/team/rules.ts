// Team planning rules (J3) — pure TypeScript (ADR-002).

/** Flags returned by the database for a planned visit (migration 0014). */
export const PLAN_FLAG_LABEL: Record<string, string> = {
  order_expired: "nach Ablauf der Verordnung",
  reassessment_due: "nach Überprüfungsdatum des Pflegeplans – Neubeurteilung",
  uncovered: "niemand verantwortlich (nächste 24 h)",
};


export type Minutes = { a: number; b: number; c: number };

/** Planned minutes per category from form inputs; empty → 0. Never only a total (PO brief J3). */
export function minutesFromForm(get: (name: string) => string): Minutes {
  const n = (k: string) => {
    const v = Number.parseInt(get(k), 10);
    return Number.isFinite(v) && v > 0 ? v : 0;
  };
  return { a: n("minutes_a"), b: n("minutes_b"), c: n("minutes_c") };
}

export function formatMinutesByCategory(m: { a?: number | null; b?: number | null; c?: number | null }): string {
  const parts = (["a", "b", "c"] as const)
    .filter((k) => (m[k] ?? 0) > 0)
    .map((k) => `${k.toUpperCase()} ${m[k]} min`);
  return parts.length ? parts.join(" · ") : "keine Minuten erfasst";
}

export const QUALIFICATION_LABEL: Record<string, string> = {
  registered_nurse: "Pflegefachperson",
  care_assistant: "Pflegeassistenz",
};
