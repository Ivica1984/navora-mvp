// HAND1 — "since you were last here": pure formatting of the recorded entries (ADR-047).
// The database selects and orders the entries (public.field_since_last, migration 0033). This module only turns
// codes into labels. Free text (observations, notes, reasons, titles) is shown exactly as recorded:
// nothing is summarised, ranked or interpreted.

import { MEDICAL_ORDER_LABEL } from "@/features/intake/rules";
import { REASON_LABEL } from "@/features/lifecycle/rules";
import { EVENT_STATUS_LABEL, SEVERITY_LABEL } from "@/features/quality/rules";
import { WEEKDAYS } from "@/features/planning/rules";

export type SinceLastRow = {
  visit_id: string;
  rule: string;
  since_date: string | null;
  lookback: number;
  kind: string | null;
  entry_id: string | null;
  at: string | null;
  source_visit_date: string | null;
  source_visit_start: string | null;
  author: string | null;
  detail: unknown;
};

export type SinceLastEntry = {
  id: string;
  kind: string;
  at: string;
  sourceVisitDate: string | null;
  sourceVisitStart: string | null;
  author: string;
  detail: Record<string, unknown>;
};

export type SinceLast = { rule: string; sinceDate: string | null; lookback: number; entries: SinceLastEntry[] };

/** One block per visit card; entries keep the database order (oldest first). */
export function groupSinceLast(rows: SinceLastRow[]): Map<string, SinceLast> {
  const byVisit = new Map<string, SinceLast>();
  for (const row of rows) {
    let block = byVisit.get(row.visit_id);
    if (!block) {
      block = { rule: row.rule, sinceDate: row.since_date, lookback: row.lookback, entries: [] };
      byVisit.set(row.visit_id, block);
    }
    if (row.kind && row.entry_id && row.at) {
      block.entries.push({
        id: row.entry_id,
        kind: row.kind,
        at: row.at,
        sourceVisitDate: row.source_visit_date,
        sourceVisitStart: row.source_visit_start,
        author: row.author ?? "system",
        detail: row.detail && typeof row.detail === "object" ? (row.detail as Record<string, unknown>) : {},
      });
    }
  }
  return byVisit;
}

/** "12.10.2026" from "2026-10-12". */
export function formatDate(date: string | null | undefined): string {
  if (!date) return "";
  const [y, m, d] = date.slice(0, 10).split("-");
  return `${d}.${m}.${y}`;
}

/** Member label until ADM1 names exist (same numbering as /team: members ordered by user id). */
export function authorLabel(code: string): string {
  if (code === "me") return "Ich";
  if (code === "system") return "Automatisch";
  if (code.startsWith("member:")) return `Teammitglied ${code.slice("member:".length)}`;
  return "Person ausserhalb des Teams";
}

/** Which rule set the window; the card says it (brief: "The card says which rule applied"). */
export function ruleText(rule: string, sinceDate: string | null, lookback: number): string {
  if (rule === "since_own_visit") return `Seit deinem letzten Einsatz am ${formatDate(sinceDate)}`;
  if (rule === "last_visits") {
    return `Du warst noch nicht hier: die letzten ${lookback} abgeschlossenen Einsätze (ab ${formatDate(sinceDate)}) und alles danach`;
  }
  return "Du warst noch nicht hier; es gibt noch keinen abgeschlossenen Einsatz: alles bisher Erfasste";
}

export function emptyText(rule: string, sinceDate: string | null): string {
  if (rule === "since_own_visit") return `Nichts Neues seit deinem letzten Einsatz am ${formatDate(sinceDate)}.`;
  return "Noch nichts erfasst.";
}

export const ENTRY_TITLE: Record<string, string> = {
  observation: "Beobachtung",
  care_plan_added: "Pflegeplan: Leistung aufgenommen",
  care_plan_retired: "Pflegeplan: Leistung beendet",
  care_plan_schedule: "Pflegeplan: Rhythmus geändert",
  visit_moved: "Einsatz verschoben",
  visit_removed: "Einsatz entfernt",
  visit_cancelled: "Einsatz abgesagt",
  visit_no_show: "Niemand angetroffen",
  visit_no_show_outcome: "Niemand angetroffen: Ergebnis",
  visit_interrupted: "Einsatz nicht abgeschlossen",
  case_pause: "Fall pausiert",
  case_resume: "Fall fortgesetzt",
  case_close: "Fall abgeschlossen",
  case_reopen: "Fall wiedereröffnet",
  primary_nurse: "Bezugspflege geändert",
  medical_order: "Ärztliche Verordnung geändert",
  quality_event: "Qualitätsereignis",
};

const str = (v: unknown): string | null => (typeof v === "string" && v.length > 0 ? v : typeof v === "number" ? String(v) : null);
const oldNew = (v: unknown): { old: unknown; new: unknown } | null =>
  v && typeof v === "object" && "new" in (v as object) ? (v as { old: unknown; new: unknown }) : null;
const hhmm = (t: unknown) => (typeof t === "string" ? t.slice(0, 5) : "");

function slot(v: unknown): string {
  if (!v || typeof v !== "object") return "–";
  const s = v as Record<string, unknown>;
  const time = s.start ? ` ${hhmm(s.start)}${s.end ? `–${hhmm(s.end)}` : ""}` : "";
  return `${formatDate(str(s.date))}${time}`.trim() || "–";
}

const SCHEDULE_FIELD: Record<string, string> = {
  freq_times: "Anzahl",
  freq_period: "Rhythmus",
  freq_weekdays: "Wochentage",
  window_start: "Zeitfenster ab",
  window_end: "Zeitfenster bis",
};

function scheduleValue(field: string, v: unknown): string {
  if (v === null || v === undefined) return "–";
  if (field === "freq_period") return v === "day" ? "täglich" : v === "week" ? "pro Woche" : String(v);
  if (field === "freq_weekdays" && Array.isArray(v)) return v.map((d) => WEEKDAYS.find((w) => w.iso === d)?.short ?? String(d)).join(", ");
  if (field.startsWith("window_")) return hhmm(v);
  return String(v);
}

function personLabel(code: unknown): string {
  return typeof code === "string" ? authorLabel(code) : "nicht bestimmt";
}

/** The recorded facts of one entry as display lines. Free text is passed through unchanged. */
export function entryLines(kind: string, detail: Record<string, unknown>): string[] {
  const lines: string[] = [];
  const add = (line: string | null | false) => {
    if (line) lines.push(line);
  };
  const reasonCode = str(detail.reason_code);
  switch (kind) {
    case "observation":
      add(str(detail.content));
      add(detail.for_handover === true && "für die Übergabe markiert");
      add(detail.edited === true && "geändert (aktuelle Fassung)");
      break;
    case "care_plan_added":
      add([str(detail.service), str(detail.category) && `Kategorie ${detail.category}`, str(detail.minutes) && `${detail.minutes} Min.`, str(detail.frequency)]
        .filter(Boolean).join(" · "));
      add(str(detail.goal) && `Ziel: ${detail.goal}`);
      break;
    case "care_plan_retired":
      add([str(detail.service), str(detail.category) && `Kategorie ${detail.category}`].filter(Boolean).join(" · "));
      add(str(detail.reason) && `Begründung: ${detail.reason}`);
      break;
    case "care_plan_schedule": {
      add(str(detail.service));
      const changed = detail.changed && typeof detail.changed === "object" ? (detail.changed as Record<string, unknown>) : {};
      const parts = Object.keys(SCHEDULE_FIELD)
        .map((f) => {
          const c = oldNew(changed[f]);
          return c ? `${SCHEDULE_FIELD[f]}: ${scheduleValue(f, c.old)} → ${scheduleValue(f, c.new)}` : null;
        })
        .filter((p): p is string => p !== null);
      add(parts.length > 0 ? parts.join(" · ") : "Werte vor der Protokollierung nicht erfasst");
      break;
    }
    case "visit_moved":
      add(`${slot(detail.before)} → ${slot(detail.after)}`);
      add(str(detail.reason) && `Begründung: ${detail.reason}`);
      break;
    case "visit_removed":
      add(slot(detail.before));
      add(str(detail.reason) && `Begründung: ${detail.reason}`);
      break;
    case "visit_cancelled":
    case "visit_no_show":
    case "visit_no_show_outcome":
    case "visit_interrupted":
    case "case_pause":
    case "case_resume":
    case "case_close":
    case "case_reopen":
      add(reasonCode && (REASON_LABEL[reasonCode] ?? reasonCode));
      add(str(detail.note));
      add(str(detail.expected_end) && `voraussichtlich bis ${formatDate(str(detail.expected_end))}`);
      break;
    case "primary_nurse":
      add("primary_new" in detail && `Bezugspflege: ${personLabel(detail.primary_old)} → ${personLabel(detail.primary_new)}`);
      add("deputy_new" in detail && `Stellvertretung: ${personLabel(detail.deputy_old)} → ${personLabel(detail.deputy_new)}`);
      add(str(detail.reason) && `Begründung: ${detail.reason}`);
      break;
    case "medical_order": {
      const status = oldNew(detail.status);
      const label = (v: unknown) => (typeof v === "string" ? MEDICAL_ORDER_LABEL[v as keyof typeof MEDICAL_ORDER_LABEL] ?? v : "–");
      add(status && `Status: ${label(status.old)} → ${label(status.new)}`);
      const until = oldNew(detail.valid_until);
      add(until && `Gültig bis: ${formatDate(str(until.old)) || "–"} → ${formatDate(str(until.new)) || "–"}`);
      add(str(detail.reason) && `Begründung: ${detail.reason}`);
      break;
    }
    case "quality_event": {
      const severity = str(detail.severity);
      const status = str(detail.status);
      add(str(detail.title));
      add([severity && `Schwere: ${SEVERITY_LABEL[severity as keyof typeof SEVERITY_LABEL] ?? severity}`,
           status && `Status jetzt: ${EVENT_STATUS_LABEL[status] ?? status}`].filter(Boolean).join(" · "));
      break;
    }
    default:
      break;
  }
  return lines;
}

/** "Einsatz vom 12.10.2026 08:00" when the entry belongs to a visit. */
export function sourceText(date: string | null, start: string | null): string | null {
  if (!date) return null;
  return `Einsatz vom ${formatDate(date)}${start ? ` ${hhmm(start)}` : ""}`;
}
