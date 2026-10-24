// AN2 — "Pilot-Hypothesen" (migration 0057, ADR-070): what each measure means, which challenge row of
// NEXT_CAPABILITY.md it tests, and its source. Pure module, unit-tested. Values come from `pilot_hypotheses`.
import { NOT_BILLABLE_LABEL } from "@/features/billing/rules";

export type HypothesisUnit = "%" | "Min." | "Std." | "Tage" | "pro 100" | "";

export type HypothesisGroup = {
  /** The brief's measure number (docs/agents/briefs/AN2.md). */
  no: number;
  /** One line, German: the hypothesis the pilot tests. */
  hypothesis: string;
  /** The challenge row in NEXT_CAPABILITY.md ("Challenge review"), by its title. */
  challenge: string;
  source: string;
  measures: readonly string[];
};

export type MeasureDefinition = { label: string; unit: HypothesisUnit; definition: string };

export const HYPOTHESIS_GROUPS: readonly HypothesisGroup[] = [
  {
    no: 3,
    hypothesis: "Koordination beendet laufende Einsätze selten; das Team schliesst seine Einsätze selbst ab.",
    challenge: "Überfällige und hängende Einsätze schliesst eine Koordinationsperson mit Grund (CSR1 Teil 1)",
    source: "Einsatzereignisse «nicht abgeschlossen» (CGR-20, CGR-26)",
    measures: ["coordinator_ends"],
  },
  {
    no: 5,
    hypothesis: "Korrekturrunden sind meist spät erfasste Zeiten und werden oft ohne Änderung neu unterschrieben.",
    challenge: "Ein Zeitfehler nach der Unterschrift braucht eine Korrekturversion mit Grund und Gegenzeichnung",
    source: "Berichtsversionen F6/F7",
    measures: ["correction_versions_per_100", "correction_minutes_after_signature", "correction_unchanged_share"],
  },
  {
    no: 6,
    hypothesis: "Offene Korrekturen erledigt die Pflegeperson selbst; ein Signal an Operations bringt nichts.",
    challenge: "Eine offene Berichtskorrektur meldet sich bei Operations, das nicht handeln kann",
    source: "Signal «Berichtskorrektur nicht abgeschlossen» (CGR-24, CGR-24-W)",
    measures: ["correction_open_signals", "correction_open_hours", "correction_open_withdrawn_share", "correction_open_signed_share"],
  },
  {
    no: 7,
    hypothesis: "Nicht abrechenbare Fakten haben wenige, behebbare Gründe und werden bald abrechenbar.",
    challenge: "Eine Datenkorrektur in der Aufnahme lässt einen unterschriebenen Einsatz bis zur Berichtskorrektur nicht abrechenbar",
    source: "Abrechnungsfakten J5",
    measures: ["not_billable_facts", "not_billable_reason", "not_billable_days_to_billable"],
  },
  {
    no: 9,
    hypothesis: "Lange oder zerstückelte Einsätze sind selten.",
    challenge: "Pausen und Wiederaufnahmen werden von Hand gezählt (CGR-23)",
    source: "Einsatzereignisse F1–F4, Ausnahmeregel «Einsatz hängt»",
    measures: ["visits_many_pauses", "visits_open_past_p1"],
  },
  {
    no: 11,
    hypothesis: "Eine Qualitätssperre wird rasch aufgehoben.",
    challenge: "Eine Qualitätssperre hebt nur ein Coach oder eine Administratorin auf (QG1)",
    source: "Qualitätssperren QG1",
    measures: ["hold_lift_hours", "holds_still_open"],
  },
  {
    no: 12,
    hypothesis: "Abrechnungsfakten entstehen beim Abschluss, nicht in einem späteren Lauf.",
    challenge: "Abrechnungsfakten entstehen in einem späteren Lauf",
    source: "Abrechnungsfakten J5",
    measures: ["late_report_facts_share", "basis_changed_per_100"],
  },
];

export const MEASURE: Record<string, MeasureDefinition> = {
  coordinator_ends: {
    label: "Von Koordination beendet", unit: "",
    definition: "«Nicht abgeschlossen» erfasst von einer Koordinationsrolle (Admin, Coach, Operations) ausserhalb des Teams, während der Einsatz lief oder pausiert war. Basis: alle «nicht abgeschlossen» aus laufenden oder pausierten Einsätzen.",
  },
  correction_versions_per_100: {
    label: "Korrekturversionen pro 100 Berichte", unit: "pro 100",
    definition: "Korrekturversionen (auch zurückgezogene) pro 100 unterschriebene erste Berichtsversionen.",
  },
  correction_minutes_after_signature: {
    label: "Unterschrift bis Korrektur", unit: "Min.",
    definition: "Median der Minuten von der Unterschrift der korrigierten Version bis zur Korrekturversion.",
  },
  correction_unchanged_share: {
    label: "Korrektur ohne Änderung unterschrieben", unit: "%",
    definition: "Unterschriebene Korrekturversionen, deren Inhalt (Prüfsumme der Fakten) und Zusammenfassung gleich sind wie in der vorherigen Version.",
  },
  correction_open_signals: {
    label: "Korrekturen mit Signal «nicht abgeschlossen»", unit: "",
    definition: "Korrekturversionen, die länger als die Frist «Einsatzbericht nicht abgeschlossen» offen waren. Basis: alle Korrekturversionen.",
  },
  correction_open_hours: {
    label: "Signal offen", unit: "Std.",
    definition: "Median der Stunden vom Signal bis zur Unterschrift (bzw. Gegenzeichnung) oder zum Zurückziehen; noch offene nicht gezählt.",
  },
  correction_open_withdrawn_share: {
    label: "Beendet durch Zurückziehen", unit: "%",
    definition: "Beendete Signale, bei denen die Korrektur zurückgezogen wurde.",
  },
  correction_open_signed_share: {
    label: "Beendet durch Unterschrift", unit: "%",
    definition: "Beendete Signale, bei denen die Korrektur gültig wurde.",
  },
  not_billable_facts: {
    label: "Nicht abrechenbare Fakten", unit: "",
    definition: "Fakten der Einsätze des Monats, die nicht abrechenbar sind. Nicht enthalten: Fakten, deren einziger Grund die Mindestdauer ist. Basis: alle Fakten.",
  },
  not_billable_reason: {
    label: "Grund", unit: "",
    definition: "Nicht abrechenbare Fakten mit diesem Grund (ein Fakt kann mehrere Gründe haben). Basis: alle nicht abrechenbaren Fakten.",
  },
  not_billable_days_to_billable: {
    label: "Bis abrechenbar", unit: "Tage",
    definition: "Median der Tage bis zu einem späteren abrechenbaren Fakt desselben Einsatzes (ohne Fakten, die nur an der Mindestdauer scheitern).",
  },
  visits_many_pauses: {
    label: "Mehr als zwei Pausen", unit: "",
    definition: "Begonnene Einsätze mit mehr als zwei Pausen.",
  },
  visits_open_past_p1: {
    label: "Länger offen als geplant plus P1-Schwelle", unit: "",
    definition: "Begonnene Einsätze, die länger offen waren als das geplante Ende plus Frist und P1-Eskalation von «Einsatz hängt». Basis: begonnene Einsätze mit geplantem Ende.",
  },
  hold_lift_hours: {
    label: "Sperre bis Aufhebung", unit: "Std.",
    definition: "Median der Stunden von der Qualitätssperre bis zu ihrer Aufhebung.",
  },
  holds_still_open: {
    label: "Sperren noch offen", unit: "",
    definition: "Qualitätssperren der Einsätze des Monats, die noch nicht aufgehoben sind.",
  },
  late_report_facts_share: {
    label: "Fakt später als 24 Std. nach Einsatzende", unit: "%",
    definition: "Fakten aus dem Bericht, die mehr als 24 Stunden nach dem Einsatzende entstanden sind.",
  },
  basis_changed_per_100: {
    label: "Neu berechnet wegen geänderter Grundlage", unit: "pro 100",
    definition: "Fakten «Grundlage geändert» (Kostenträger J5-C1, Verordnung J5-C2) pro 100 Fakten.",
  },
};

/** AN2-M7: the fixed note the database returns on the CR-029 reason row (never in a total; D-18). */
export const BELOW_MINIMUM_NOTE = "Regel in rechtlicher Prüfung (D-18), nicht als Verlust werten.";

export const PERIOD_NOTE = "Einsätze mit Datum im Monat, mit ihren späteren Ereignissen bis jetzt.";

export function measureLabel(measure: string, detail: string | null): string {
  if (measure === "not_billable_reason") {
    if (detail === "none") return "Grund: ohne Angabe";
    return `Grund: ${(detail && NOT_BILLABLE_LABEL[detail]) ?? detail ?? "unbekannt"}`;
  }
  return MEASURE[measure]?.label ?? measure;
}

/** "80 pro 100", "25 Min.", "–". Swiss number format (de-CH). */
export function formatMeasure(measure: string, value: number | string | null | undefined): string {
  if (value === null || value === undefined) return "–";
  const n = typeof value === "string" ? Number(value) : value;
  if (!Number.isFinite(n)) return "–";
  const unit = MEASURE[measure]?.unit ?? "";
  const text = new Intl.NumberFormat("de-CH", { maximumFractionDigits: 1 }).format(n);
  return unit ? `${text} ${unit}` : text;
}

/** Rows of one group in display order: fixed measures first, reason rows (below_minimum first) in place. */
export function orderGroupRows<T extends { measure: string; detail: string | null }>(group: HypothesisGroup, rows: readonly T[]): T[] {
  const out: T[] = [];
  for (const m of group.measures) {
    const of = rows.filter((r) => r.measure === m);
    of.sort((a, b) => (a.detail === "below_minimum" ? -1 : b.detail === "below_minimum" ? 1 : (a.detail ?? "").localeCompare(b.detail ?? "")));
    out.push(...of);
  }
  return out;
}
