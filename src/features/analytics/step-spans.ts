// AN3 "Wo die Nicht-Pflegezeit hingeht" (brief docs/agents/briefs/AN3.md, ADR-144). Pure module, unit-tested.
// Per team and month, the median span of each administrative step NAVORA already timestamps, beside the care share.
// Figures (a), (b), the care share, the returned share and time corrections are reused from AN1 (`pilot_kpis`) and
// AN2 (`pilot_hypotheses`); only the new figures come from `pilot_step_spans`. Never per person, no target (AN3-5).

export type StepUnit = "%" | "Min." | "Std." | "Tage" | "";

export type StepFigureDefinition = {
  key: string;
  /** Which read returns the figure: AN1, AN2 or the AN3 function. */
  from: "kpi" | "hypothesis" | "span";
  label: string;
  unit: StepUnit;
  definition: string;
  source: string;
};

/** AN3-5 (`cra` 2026-11-03 05:30): no label or note may use one of these words. */
export const TARGET_WORDS = ["Ziel", "Soll", "besser", "zu langsam"] as const;

/** The measures `public.pilot_step_spans` returns (migration 0108). */
export const STEP_SPAN_MEASURES = [
  "travel_share_in_visits",
  "referral_to_case_ready_hours",
  "inform_gp_done_hours",
  "inform_gp_open_at_month_end",
  "inform_gp_open_age_days",
  "proposal_decided_hours",
  "proposals_corrected",
  "proposals_rejected",
  "proposals_expired_undecided",
] as const;

export const STEP_FIGURES: readonly StepFigureDefinition[] = [
  {
    key: "direct_care_share", from: "kpi", unit: "%",
    label: "Anteil direkte Pflegezeit an bestätigter Arbeitszeit (North Star)",
    definition: "Die Kennzahl WORK1-6 wie gebaut: Pflegeminuten der bestätigten Arbeitstage ÷ bestätigte bezahlte Arbeitsminuten derselben Tage.",
    source: "Bestätigte Arbeitstage (WORK1-6)",
  },
  {
    key: "travel_share_in_visits", from: "span", unit: "%",
    label: "Wegzeit im Einsatz",
    definition: "Wegminuten ÷ (Weg + Pflege + Pause) der abgeschlossenen Einsätze mit erfasster Abfahrt und Abschluss, mit Zeitkorrekturen. Nur der Weg zum Einsatz: Rückweg und Wege zwischen den Tagen werden nicht gemessen.",
    source: "Einsatzereignisse F1–F4",
  },
  {
    key: "report_final_minutes", from: "kpi", unit: "Min.",
    label: "Einsatzende bis Bericht abgeschlossen",
    definition: "Median der Minuten vom Einsatzende bis zur ersten abgeschlossenen Fassung des Berichts (Unterschrift, oder Gegenzeichnung, falls nötig).",
    source: "Berichte F6/F7 (AN1)",
  },
  {
    key: "countersign_latency_hours", from: "hypothesis", unit: "Std.",
    label: "Unterschrift bis Gegenzeichnung",
    definition: "Median der Stunden von der ersten Unterschrift bis zur Gegenzeichnung, nur Berichte mit Gegenzeichnungspflicht, Rückgaben eingeschlossen. Eine Tatsache, kein Richtwert: nur zusammen mit den Rückgaben und den Zeitkorrekturen desselben Teams lesen.",
    source: "Berichte F6R (AN2)",
  },
  {
    key: "report_returned_share", from: "hypothesis", unit: "%",
    label: "Berichte mit Rückgabe",
    definition: "Anteil der Berichte mit Gegenzeichnungspflicht, die mindestens einmal zurückgegeben wurden.",
    source: "Rückgaben F6R-9 (AN2)",
  },
  {
    key: "time_correction_share", from: "kpi", unit: "%",
    label: "Einsätze mit Zeitkorrektur",
    definition: "Anteil der abgeschlossenen Einsätze mit mindestens einer begründeten Zeitkorrektur.",
    source: "Zeitkorrekturen F3 (AN1)",
  },
  {
    key: "referral_to_case_ready_hours", from: "span", unit: "Std.",
    label: "Partneranfrage bis Fall bereit",
    definition: "Median der Stunden vom Eingang der Partneranfrage bis der daraus erfasste Fall bereit für den Teamentscheid ist; Fälle, die im Monat bereit wurden. Ohne Fälle, die nicht aus einer Partneranfrage entstanden.",
    source: "Aufnahme J1",
  },
  {
    key: "inform_gp_done_hours", from: "span", unit: "Std.",
    label: "Aufgabe «Hausärztin/Hausarzt informieren» bis erledigt",
    definition: "Median der Stunden vom Öffnen der Aufgabe bis zur Erfassung «informiert»; Aufgaben, die im Monat erfasst wurden. Mit dem Fallabschluss geschlossene Aufgaben zählen nicht.",
    source: "Aufgaben ORD0",
  },
  {
    key: "inform_gp_open_at_month_end", from: "span", unit: "",
    label: "Davon offen am Monatsende",
    definition: "Aufgaben «Hausärztin/Hausarzt informieren», die am Ende des Monats (im laufenden Monat: jetzt) offen sind.",
    source: "Aufgaben ORD0",
  },
  {
    key: "inform_gp_open_age_days", from: "span", unit: "Tage",
    label: "Alter der offenen Aufgaben",
    definition: "Median der Tage, seit die am Monatsende offenen Aufgaben «Hausärztin/Hausarzt informieren» geöffnet wurden.",
    source: "Aufgaben ORD0",
  },
  {
    key: "proposal_decided_hours", from: "span", unit: "Std.",
    label: "Vorschlag bis Entscheid",
    definition: "Median der Stunden von der Erstellung eines Assistenzvorschlags bis zum ersten Entscheid (übernommen, geändert oder abgelehnt); Vorschläge, die im Monat entschieden wurden. Eine Tatsache, kein Richtwert: nur zusammen mit den geänderten, abgelehnten und abgelaufenen Vorschlägen desselben Teams lesen.",
    source: "AIG1-Protokoll",
  },
  {
    key: "proposals_corrected", from: "span", unit: "",
    label: "Davon geändert",
    definition: "Entschiedene Vorschläge des Monats, deren erster Entscheid eine Änderung des vorgeschlagenen Werts war. Basis: alle entschiedenen Vorschläge des Monats.",
    source: "AIG1-Protokoll",
  },
  {
    key: "proposals_rejected", from: "span", unit: "",
    label: "Davon abgelehnt",
    definition: "Entschiedene Vorschläge des Monats, deren erster Entscheid eine Ablehnung war. Basis: alle entschiedenen Vorschläge des Monats.",
    source: "AIG1-Protokoll",
  },
  {
    key: "proposals_expired_undecided", from: "span", unit: "",
    label: "Abgelaufen ohne Entscheid",
    definition: "Vorschläge des Monats ohne Entscheid, deren Einsatz nicht mehr offen ist. Getrennt gezählt, nicht im Median.",
    source: "AIG1-Protokoll (AIG1-C4)",
  },
];

/** One row from any of the three reads, reduced to what the block needs. */
export type StepSourceRow = {
  organization_id: string;
  team_id: string | null;
  team_name: string | null;
  key: string;
  value: number | string | null;
  base: number | null;
  too_few: boolean | null;
  note: string | null;
};

export type StepFigure = StepFigureDefinition & {
  value: number | string | null;
  base: number | null;
  tooFew: boolean;
  note: string | null;
};

export type StepScope = { key: string; title: string; figures: StepFigure[] };

/** Organisation first, then teams by id; every scope lists every figure (a missing source row shows no value). */
export function buildStepScopes(kpis: StepSourceRow[], hypotheses: StepSourceRow[], spans: StepSourceRow[]): StepScope[] {
  const bySource: Record<StepFigureDefinition["from"], StepSourceRow[]> = { kpi: kpis, hypothesis: hypotheses, span: spans };
  const scopes = new Map<string, { title: string; team_id: string | null; organization_id: string }>();
  for (const r of [...kpis, ...hypotheses, ...spans]) {
    const key = r.team_id ?? `org:${r.organization_id}`;
    if (!scopes.has(key)) {
      scopes.set(key, {
        title: r.team_id ? `Team ${r.team_name ?? ""}`.trim() : "Ganze Organisation",
        team_id: r.team_id,
        organization_id: r.organization_id,
      });
    }
  }
  const ordered = [...scopes.entries()].sort(([a], [b]) => (a.startsWith("org:") ? -1 : b.startsWith("org:") ? 1 : a.localeCompare(b)));
  return ordered.map(([key, s]) => ({
    key,
    title: s.title,
    figures: STEP_FIGURES.map((def) => {
      const r = bySource[def.from].find(
        (x) => x.key === def.key && x.organization_id === s.organization_id && (x.team_id ?? null) === s.team_id,
      );
      return { ...def, value: r?.value ?? null, base: r?.base ?? null, tooFew: Boolean(r?.too_few), note: r?.note ?? null };
    }),
  }));
}

/** "4.5 Std.", "12 Min.", "–" (de-CH). */
export function formatStep(unit: StepUnit, value: number | string | null): string {
  if (value === null || value === undefined) return "–";
  const n = typeof value === "string" ? Number(value) : value;
  if (!Number.isFinite(n)) return "–";
  const text = new Intl.NumberFormat("de-CH", { maximumFractionDigits: unit === "" || unit === "Min." ? 0 : 1 }).format(n);
  return unit ? `${text} ${unit}` : text;
}
