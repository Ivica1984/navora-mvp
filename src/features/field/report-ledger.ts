// BK-e2 Abschlusspaket (ADR-216): the /field side of the report-draft ledger (migration 0151, ADR-215).
// Pure helpers, so the fail-closed rules are unit-tested without a database:
// - the model is used only when the database gate says «open» (AUT-138, `aia` gate point 1);
// - a model draft is shown only once every decision line has its ledger row (no model text without its record);
// - each line decision of the carer is written as one ledger decision, never in bulk (`aia` gate point 7).

import type { LineDecision, ReportAssist } from "./report-assist";

/** Why the database keeps the model closed (0151 `report_draft_model_gate`), or `ledger_missing` on any doubt. */
export type LedgerClosedReason =
  | "ledger_missing"
  | "no_threshold"
  | "stop_rule"
  | "not_simulation_org"
  | "not_team_member"
  | "not_draft"
  | "not_performer";

const KNOWN: readonly LedgerClosedReason[] = [
  "ledger_missing",
  "no_threshold",
  "stop_rule",
  "not_simulation_org",
  "not_team_member",
  "not_draft",
  "not_performer",
];

export type LedgerGate = { ready: true } | { ready: false; reason: LedgerClosedReason };

/** Reads the gate answer. Anything but `{result: "ok", open: true}` keeps the model closed (fail closed). */
export function ledgerGate(res: { data: unknown; error: unknown }): LedgerGate {
  const d = (res.error ? null : res.data) as { result?: unknown; open?: unknown; reason?: unknown } | null;
  if (d && d.result === "ok" && d.open === true) return { ready: true };
  const reason = typeof d?.reason === "string" && (KNOWN as readonly string[]).includes(d.reason) ? d.reason : "ledger_missing";
  return { ready: false, reason: reason as LedgerClosedReason };
}

/** The lines the carer decides (those citing her words), in screen order; this order is the ledger `line_index`. */
export function ledgerLines(a: ReportAssist): Array<{ text: string; sources: string[] }> {
  return a.lines.map((l) => ({ text: l.text, sources: l.sources }));
}

/**
 * Puts the ledger ids on the lines. Returns null (the caller falls back to the rule substitute) unless the record
 * command answered ok (or duplicate) with exactly one id per line, indices 0…n-1.
 */
export function attachSuggestions(a: ReportAssist, res: { data: unknown; error: unknown }): ReportAssist | null {
  if (res.error) return null;
  const d = res.data as { result?: unknown; lines?: unknown } | null;
  if (!d || (d.result !== "ok" && d.result !== "duplicate") || !Array.isArray(d.lines)) return null;
  const ids = new Map<number, string>();
  for (const x of d.lines as Array<{ line_index?: unknown; suggestion_id?: unknown }>) {
    if (typeof x?.line_index === "number" && typeof x?.suggestion_id === "string") ids.set(x.line_index, x.suggestion_id);
  }
  if (ids.size !== a.lines.length || a.lines.some((_, i) => !ids.has(i))) return null;
  return { ...a, lines: a.lines.map((l, i) => ({ ...l, suggestionId: ids.get(i) })) };
}

/** «Übernehmen» = confirmed (text unchanged), «Verwerfen» = rejected. Re-opening a line writes nothing. */
export function ledgerOutcome(decision: LineDecision): "confirmed" | "rejected" | null {
  if (decision === "taken") return "confirmed";
  if (decision === "dropped") return "rejected";
  return null;
}
