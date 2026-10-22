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
  "care_share_in_visits",
  "incomplete_visits",
  "direct_care_share",
  "referral_to_first_visit_days",
  "first_offer_acceptance",
  "report_final_minutes",
  "reports_final_within_10_min",
  "time_correction_share",
  "distinct_nurses_per_client",
  "primary_nurse_share",
  "handover_shown_before_start",
  "billable_per_care_minute",
  "plan_generated_share",
  "planning_actions_per_client_week",
  "open_p1_exceptions",
  "p1_median_close_hours",
  "cover_without_operations",
  "cover_median_hours",
] as const;

export const KPI: Record<string, KpiDefinition> = {
  care_share_in_visits: {
    label: "Pflegeanteil im Einsatz", unit: "%",
    definition: "Pflegeminuten ÷ (Weg + Pflege + Pause) der Einsätze mit erfasster Abfahrt und Abschluss, mit Zeitkorrekturen. Nicht enthalten: Dokumentation, Rückweg und Zeit ausserhalb der Einsätze.",
    source: "Einsatzereignisse F1–F4",
  },
  incomplete_visits: {
    label: "Unvollständige Einsätze (nicht gezählt)", unit: "",
    definition: "Abgeschlossene Einsätze ohne erfasste Abfahrt oder ohne Abschlusszeit; sie zählen nicht zum Pflegeanteil.",
    source: "Einsatzereignisse F1–F4",
  },
  direct_care_share: {
    label: "Direkter Pflegeanteil (North Star)", unit: "%",
    definition: "Pflegeminuten ÷ bezahlte Arbeitsminuten. Wird messbar, sobald die Arbeitszeit erfasst ist (D-23).",
    source: "Einsatzereignisse und Arbeitszeit",
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
  planning_actions_per_client_week: {
    label: "Planungsarbeit des Teams pro Klient:in und Woche", unit: "",
    definition: "Von Hand geplante, verschobene oder entfernte Einsätze ÷ Klient:innen ÷ Wochen des Monats (ohne Änderungen aus dem Pflegeplan).",
    source: "Planungsprotokoll J3/PLAN2",
  },
  handover_shown_before_start: {
    label: "Übergabe ohne Rapport: beim Start vorhanden", unit: "%",
    definition: "Abgeschlossene Einsätze, deren vorheriger Einsatz beim selben Fall von einer anderen Person gemacht wurde: Anteil, bei dem «Seit deinem letzten Einsatz» beim Start vorhanden war. Ob gelesen wurde, wird nicht erfasst (keine Lesebestätigung).",
    source: "Übergabe HAND1",
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
    definition: "Anteil der im Netzwerk angebotenen Einsätze, die Pflegende aus Nachbarteams übernommen haben.",
    source: "Übernahmen COVER1",
  },
  cover_median_hours: {
    label: "Zeit bis zur Übernahme", unit: "Std.",
    definition: "Median der Stunden vom ersten Angebot bis zur Übernahme durch ein Nachbarteam.",
    source: "Übernahmen COVER1",
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
