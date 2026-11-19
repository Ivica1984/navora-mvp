// BK-e2a part 2 (ADR-207): the carer's decisions on a report draft in /field.
// Variant named by `cra` for the gate (CGR-213 (b), `uxa` variant, BK brief PO 03:26): nothing typed is dropped
// without a decision, every line is decided one by one (no accept-all), signing waits while anything is open.
// The draft is never binding; only the F6 signature makes the report final. Synthetic data only in Phase A.

import type { Fact, ProviderKind } from "@/lib/ai/report-draft/contract";
import type { ReportDraft } from "@/lib/ai/report-draft/draft";

export type LineDecision = "open" | "taken" | "dropped";
export type SegmentDecision = "open" | "inserted" | "omitted";

export type AssistLine = { text: string; sources: string[]; decision: LineDecision };
export type AssistSegment = { id: string; text: string; decision: SegmentDecision };

export type ReportAssist = {
  origin: ProviderKind;
  label: string;
  /** Segment texts by id, so a line can show where it comes from. */
  sourceText: Record<string, string>;
  /**
   * AUT-151 (ADR-211, `cra` condition (1)): lines that cite only recorded facts. Shown read-only as context
   * («aus den erfassten Daten», `uxa`), never a decision, never counted as open, never added to the summary.
   */
  context: string[];
  lines: AssistLine[];
  unplaced: AssistSegment[];
};

type OkDraft = Extract<ReportDraft, { ok: true }>;

export function assistFromDraft(draft: OkDraft): ReportAssist {
  const sourceText = Object.fromEntries(draft.segments.map((s) => [s.id, s.text]));
  // The control layer has already rejected unknown ids, so a line citing no segment cites only facts.
  const citesHerWords = (l: { sources: string[] }) => l.sources.some((id) => id in sourceText);
  return {
    origin: draft.origin,
    label: draft.label,
    sourceText,
    context: draft.lines.filter((l) => !citesHerWords(l)).map((l) => l.text),
    lines: draft.lines.filter(citesHerWords).map((l) => ({ text: l.text, sources: l.sources, decision: "open" })),
    unplaced: draft.unplaced.map((id) => ({ id, text: sourceText[id] ?? "", decision: "open" })),
  };
}

export function decideLine(a: ReportAssist, index: number, decision: LineDecision): ReportAssist {
  if (index < 0 || index >= a.lines.length) return a;
  return { ...a, lines: a.lines.map((l, i) => (i === index ? { ...l, decision } : l)) };
}

export function decideSegment(a: ReportAssist, id: string, decision: SegmentDecision): ReportAssist {
  if (!a.unplaced.some((u) => u.id === id)) return a;
  return { ...a, unplaced: a.unplaced.map((u) => (u.id === id ? { ...u, decision } : u)) };
}

/** Lines and unplaced segments still without a decision. Signing waits while this is above 0. */
export function openCount(a: ReportAssist): number {
  return a.lines.filter((l) => l.decision === "open").length + a.unplaced.filter((u) => u.decision === "open").length;
}

/**
 * UXR-251: whether «Bericht unterschreiben» may be used while a draft is shown.
 * Signing waits while anything is undecided («open»), and also once everything is decided but the draft has not
 * been placed into the summary yet («unplaced»); otherwise the chosen lines would be missing from the signed report.
 * Only «In die Zusammenfassung übernehmen» or «Entwurf verwerfen» (both remove the draft) clear it.
 */
export type SignGate = { kind: "clear" } | { kind: "open"; open: number } | { kind: "unplaced" } | { kind: "notes" };

/**
 * CGR-260 (a): with no draft shown, text still in «Deine Notizen» was never proposed, so it is not in the report.
 * Signing waits until she proposes it or empties the field herself (an explicit act). With a draft shown, the draft
 * decides the gate (its notes are part of it).
 */
export function signGate(a: ReportAssist | null, notes = ""): SignGate {
  if (!a) return notes.trim().length > 0 ? { kind: "notes" } : { kind: "clear" };
  const open = openCount(a);
  return open > 0 ? { kind: "open", open } : { kind: "unplaced" };
}

/** The wait line under the sign button (wording from `uxa` UXR-251; `cra` to confirm). Null when signing is allowed. */
export function signWaitText(g: SignGate): string | null {
  if (g.kind === "open")
    return `Noch ${g.open} ${g.open === 1 ? "Punkt" : "Punkte"} im Entwurf offen. Bitte zuerst entscheiden oder den Entwurf verwerfen.`;
  if (g.kind === "unplaced") return "Entwurf noch nicht in die Zusammenfassung übernommen. Bitte übernehmen oder den Entwurf verwerfen.";
  // CGR-260 (a); wording PROPOSED by `eng`, `uxa` and `cra` to confirm.
  if (g.kind === "notes") return "Deine Notizen sind noch nicht im Bericht. Bitte «Entwurf vorschlagen» oder die Notizen leeren.";
  return null;
}

/**
 * CGR-260 (b): «Entwurf verwerfen» is a confirmed act that names what would still have gone into the report:
 * lines not already dropped and sentences not already left out. Her notes stay on screen (and keep signing waiting,
 * CGR-260 (a)). Wording PROPOSED by `eng`, `uxa` and `cra` to confirm.
 */
export function discardPrompt(a: ReportAssist): string {
  const lines = a.lines.filter((l) => l.decision !== "dropped").length;
  const sentences = a.unplaced.filter((u) => u.decision !== "omitted").length;
  return `Entwurf verwerfen? ${lines} ${lines === 1 ? "Zeile" : "Zeilen"} und ${sentences} ${sentences === 1 ? "Satz" : "Sätze"} kommen nicht in den Bericht. Deine Notizen bleiben stehen.`;
}

/** UXR-253 (a): the heading counts every unused sentence and says how many are still open. */
export function unplacedHeading(a: ReportAssist): string {
  const open = a.unplaced.filter((u) => u.decision === "open").length;
  return `Nicht übernommen (${a.unplaced.length}), davon ${open} offen`;
}

/** UXR-254 (b): the apply button says what it does; when nothing goes in, it only closes the draft. */
export function applyLabel(a: ReportAssist): string {
  const open = openCount(a);
  if (open > 0) return `Noch ${open} offen`;
  const adds = a.lines.some((l) => l.decision === "taken") || a.unplaced.some((u) => u.decision === "inserted");
  return adds ? "In die Zusammenfassung übernehmen" : "Entwurf abschliessen";
}

/** The summary text after the carer's decisions: existing text, then taken lines, then inserted segments. */
export function composeSummary(existing: string, a: ReportAssist): string {
  const added = [
    ...a.lines.filter((l) => l.decision === "taken").map((l) => l.text),
    ...a.unplaced.filter((u) => u.decision === "inserted").map((u) => u.text),
  ];
  return [existing.trim(), ...added].filter((t) => t.length > 0).join("\n");
}

type Snapshot = {
  services?: unknown;
  events?: unknown;
};

const time = (iso: string) =>
  new Intl.DateTimeFormat("de-CH", { timeZone: "Europe/Zurich", hour: "2-digit", minute: "2-digit", hourCycle: "h23" }).format(
    new Date(iso),
  );

/**
 * Facts for the draft from the stored report snapshot (what the report already holds, F7).
 * Data minimisation: only the actual times and the services; never a name, an address or an observation.
 */
export function factsFromSnapshot(snapshot: unknown, opts: { services?: boolean } = {}): Fact[] {
  const snap = (snapshot && typeof snapshot === "object" ? snapshot : {}) as Snapshot;
  const events = Array.isArray(snap.events) ? (snap.events as { type?: unknown; at?: unknown }[]) : [];
  const at = (type: string) => {
    const e = events.find((x) => x?.type === type && typeof x?.at === "string");
    return e ? (e.at as string) : null;
  };
  const texts: string[] = [];
  const start = at("started");
  const end = at("completed");
  if (start && end) texts.push(`Einsatz ${time(start)}–${time(end)}`);
  const services = opts.services === false ? [] : Array.isArray(snap.services) ? snap.services.filter((s): s is string => typeof s === "string") : [];
  if (services.length > 0) texts.push(`Leistungen: ${services.join(", ")}`);
  return texts.map((text, i) => ({ id: `f${i + 1}`, text }));
}

/**
 * L-1497-1 (PO 2026-11-19 08:39): in Phase A no services go into a model payload; the rule substitute keeps them.
 * The /field command picks the facts by the kind of the provider the resolver returned.
 */
export function factsForProvider(snapshot: unknown, kind: ProviderKind): Fact[] {
  return factsFromSnapshot(snapshot, { services: kind !== "model" });
}

/** Who may ask for a draft: only the performer of the visit, only on an open draft (ADR-207 (1)). */
export function assistAllowed(
  report: { status: string | null; i_am_performer: boolean | null; performer_access_ended: boolean | null } | null,
): boolean {
  return report != null && report.status === "draft" && report.i_am_performer === true && report.performer_access_ended !== true;
}
