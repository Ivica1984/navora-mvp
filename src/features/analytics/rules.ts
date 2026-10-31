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
  "returning_referral_to_first_visit_days",
  "returning_previous_team_share",
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
  "absence_taken_before_cover_lead",
  "absence_last_take_minutes",
  "absence_taken_by_known_share",
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
    label: "Anteil direkte Pflegezeit an bestätigter Arbeitszeit (North Star)", unit: "%",
    definition: "Pflegeminuten der bestätigten Arbeitstage ÷ bestätigte bezahlte Arbeitsminuten derselben Tage (Beginn bis Ende ohne Pausen von 30 Minuten oder mehr). Nur bestätigte Tage; Basis = Anzahl bestätigter Tage. Nur pro Team, ab 3 Personen und 5 Tagen; nie pro Person.",
    source: "Von den Pflegenden bestätigte Arbeitstage (WORK1)",
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
  returning_previous_team_share: {
    label: "Rückkehrende Klient:innen beim früheren Team", unit: "%",
    definition: "Mit einem früheren Fall verknüpfte Zuweisungen des Monats: Anteil, der beim früheren Team bleibt (fortgesetzter Fall oder Übernahme durch das frühere Team). Basis: fortgesetzte Fälle und neue Fälle, die schon ein Team haben.",
    source: "Rückkehr RET1",
  },
  returning_referral_to_first_visit_days: {
    label: "Rückkehr: Zuweisung bis erster Einsatz", unit: "Tage",
    definition: "Median der Tage von der Verknüpfung bis zum ersten begonnenen Einsatz, nur rückkehrende Klient:innen. Zum Vergleich: «Zuweisung bis erster Einsatz» über alle Fälle.",
    source: "Rückkehr RET1, Einsatzereignisse",
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
  // ABS1 (migration 0048): aggregates only, never who was absent.
  absence_taken_before_cover_lead: {
    label: "Abwesenheit: im eigenen Team übernommen vor Nachbarteams", unit: "%",
    definition: "Einsätze, die durch eine in diesem Monat erfasste Abwesenheit frei wurden: Anteil, den jemand aus dem eigenen Team übernommen hat, bevor die Vorlaufzeit für Nachbarteams (COVER1) beginnt. Nicht gezählt: abgesagte Einsätze und solche, die ungenommen zurückgingen.",
    source: "Abwesenheit ABS1, Übernahmen COVER1",
  },
  absence_last_take_minutes: {
    label: "Abwesenheit: Zeit bis alles übernommen", unit: "Min.",
    definition: "Median der Minuten von der Erfassung einer Abwesenheit bis zur Übernahme ihres letzten freigegebenen Einsatzes; nur Abwesenheiten, deren Einsätze alle übernommen sind. Eine Abwesenheit in zwei Teams zählt pro Team.",
    source: "Abwesenheit ABS1",
  },
  absence_taken_by_known_share: {
    label: "Abwesenheit: von bekannter Pflegender übernommen", unit: "%",
    definition: "Übernommene freigegebene Einsätze: Anteil, den die Stellvertretung oder die Bezugspflegende des Falls übernommen hat (Fallangaben, wie sie heute erfasst sind).",
    source: "Abwesenheit ABS1, Kontinuität J6",
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
