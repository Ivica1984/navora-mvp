// J5 — billing preview: pure helpers (ADR-002). Facts and rates live in the database (migration 0022).

export const NOT_BILLABLE_LABEL: Record<string, string> = {
  quality_hold: "Qualitäts-Stopp offen",
  report_not_final: "Bericht nicht abgeschlossen",
  not_generated: "noch nicht erfasst – «Abrechnungsfakten erzeugen»",
  b_without_valid_order: "Kategorie B ohne gültige Verordnung",
  no_insurer: "Krankenversicherer fehlt",
  below_minimum: "unter der Mindestdauer",
  no_planned_minutes: "keine Minuten pro Kategorie geplant",
  no_measured_time: "keine gemessene Pflegezeit",
};

export function notBillableText(reasons: unknown): string {
  if (!Array.isArray(reasons) || reasons.length === 0) return "Grund unbekannt";
  return reasons.map((r) => NOT_BILLABLE_LABEL[String(r)] ?? String(r)).join(", ");
}

export function formatChf(amount: number | null | undefined): string {
  if (amount === null || amount === undefined) return "–";
  return new Intl.NumberFormat("de-CH", { style: "currency", currency: "CHF" }).format(amount);
}

export type NotBillableItem = { visit_id: string; date: string; client: string | null; reasons: unknown };

export function parseNotBillable(raw: unknown): NotBillableItem[] {
  if (!Array.isArray(raw)) return [];
  return raw.filter((i): i is NotBillableItem => !!i && typeof i === "object" && typeof (i as NotBillableItem).visit_id === "string");
}

/** First day of the month as YYYY-MM-DD. */
export function monthStart(day: string): string {
  return `${day.slice(0, 7)}-01`;
}
