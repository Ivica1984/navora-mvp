// AN1 pilot impact dashboard — KPI definitions shown on the page (ADR-044). Pure module, unit-tested.

export type KpiDefinition = {
  label: string;
  unit: "%" | "Tage" | "Min." | "" | "Std.";
  definition: string;
  source: string;
  /** Reference values from the PO (CARE_OPERATING_MODEL.md, briefs), shown next to the figure. */
  reference?: string;
};

export const KPI_ORDER = [
  "direct_care_share",
  "referral_to_first_visit_days",
  "first_offer_acceptance",
  "report_final_minutes",
  "reports_final_within_10_min",
  "time_correction_share",
  "distinct_nurses_per_client",
  "primary_nurse_share",
  "billable_per_care_minute",
  "plan_generated_share",
  "open_p1_exceptions",
  "p1_median_close_hours",
  "cover_without_operations",
] as const;

export const KPI: Record<string, KpiDefinition> = {
  direct_care_share: {
    label: "Direkte Pflegezeit (North Star)", unit: "%",
    definition: "Pflegeminuten ÷ (Weg + Pflege + Pause) der abgeschlossenen Einsätze, mit Zeitkorrekturen.",
    source: "Einsatzereignisse F1–F4", reference: "Buurtzorg 60 % · NAVORA-Hypothese 75 %",
  },
  referral_to_first_visit_days: {
    label: "Zuweisung bis erster Einsatz", unit: "Tage",
    definition: "Median der Tage von der Zuweisung (Partneranfrage, sonst Fallerfassung) bis zum Start des ersten Einsatzes.",
    source: "Aufnahme J1, Einsatzereignisse",
  },
  first_offer_acceptance: {
    label: "Annahme innerhalb der Antwortfrist", unit: "%",
    definition: "Anteil der Teamanfragen des Monats, die ein Team innerhalb der Antwortfrist angenommen hat.",
    source: "Teamentscheide J2",
  },
  report_final_minutes: {
    label: "Einsatzende bis Bericht abgeschlossen", unit: "Min.",
    definition: "Median der Minuten vom Einsatzende bis zur Unterschrift (oder Gegenzeichnung, falls nötig) der ersten Fassung.",
    source: "Berichte F6/F7",
  },
  reports_final_within_10_min: {
    label: "Bericht innert 10 Minuten abgeschlossen", unit: "%",
    definition: "Anteil der abgeschlossenen Einsätze mit abgeschlossenem Bericht innert 10 Minuten nach Einsatzende.",
    source: "Berichte F7", reference: "Pilotziel 50 %",
  },
  time_correction_share: {
    label: "Einsätze mit Zeitkorrektur", unit: "%",
    definition: "Anteil der abgeschlossenen Einsätze mit mindestens einer begründeten Zeitkorrektur.",
    source: "Zeitkorrekturen F3",
  },
  distinct_nurses_per_client: {
    label: "Pflegende pro Klient:in", unit: "",
    definition: "Durchschnitt der verschiedenen Pflegenden, die bei einer Klient:in im Monat Einsätze durchgeführt haben.",
    source: "Kontinuität J6",
  },
  primary_nurse_share: {
    label: "Anteil Bezugspflege", unit: "%",
    definition: "Anteil der Einsätze, die die Bezugspflegende selbst durchgeführt hat.",
    source: "Kontinuität J6",
  },
  billable_per_care_minute: {
    label: "Abrechenbare Minuten pro Pflegeminute", unit: "",
    definition: "Abrechenbare Minuten ÷ gemessene Pflegeminuten der aktuellen, abrechenbaren Fakten (Regel J5-v2).",
    source: "Abrechnungsfakten J5",
  },
  plan_generated_share: {
    label: "Einsätze aus dem Pflegeplan", unit: "%",
    definition: "Anteil der Einsätze des Monats (ohne abgesagte), die aus dem Pflegeplan entstanden sind.",
    source: "Selbstplanung PLAN2",
  },
  open_p1_exceptions: {
    label: "Offene P1-Ausnahmen (jetzt)", unit: "",
    definition: "Anzahl offener Sicherheitsausnahmen im Ausnahmezentrum, unabhängig vom Monat.",
    source: "Ausnahmezentrum OPS1",
  },
  p1_median_close_hours: {
    label: "P1-Ausnahmen: Zeit bis geschlossen", unit: "Std.",
    definition: "Median der Stunden von der Entstehung bis zum Schliessen einer P1-Ausnahme.",
    source: "Ausnahmezentrum OPS1",
  },
  cover_without_operations: {
    label: "Unbesetzte Einsätze ohne Operations gelöst", unit: "%",
    definition: "Anteil der unbesetzten Einsätze, die Pflegende aus Nachbarteams übernommen haben.",
    source: "COVER1",
  },
};

/** "75 %", "2.5 Tage", "–" — Swiss number format (de-CH). */
export function formatKpi(kpi: string, value: number | string | null): string {
  if (value === null || value === undefined) return "–";
  const n = typeof value === "string" ? Number(value) : value;
  if (!Number.isFinite(n)) return "–";
  const unit = KPI[kpi]?.unit ?? "";
  const text = new Intl.NumberFormat("de-CH", { maximumFractionDigits: unit === "%" || unit === "Tage" ? 1 : 2 }).format(n);
  return unit ? `${text} ${unit}` : text;
}
