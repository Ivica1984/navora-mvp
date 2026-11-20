import type { CheckedDraft, DraftInput, DraftLine, ProviderOutput, RejectReason } from "./contract";

export const MAX_LINE_CHARS = 2000;

/**
 * Control layer between any provider and the draft (Handbook V2.2 Engine 2/3 contract: «ohne Quelle kein Wert»).
 * - a line without a source, or citing an id that is not in the input, is rejected;
 * - every segment not cited by an accepted line is listed as unplaced, so nothing is dropped silently;
 * - the provider's own unplaced list is only a hint; ids that are not segments are ignored;
 * - a line that cites only facts must cite exactly one fact and equal its text exactly (AUT-151 (2), ADR-211);
 * - every number, time and unit token of a line must occur in the text of its cited sources (AUT-149, ADR-214).
 * The provider never decides what reaches the draft; this function does, the same for rule and model.
 */
export function checkDraft(input: DraftInput, output: ProviderOutput): CheckedDraft {
  const segmentIds = new Set(input.segments.map((s) => s.id));
  const factText = new Map(input.facts.map((f) => [f.id, f.text]));
  const known = new Set([...segmentIds, ...factText.keys()]);
  const sourceText = new Map<string, string>([...input.segments.map((s) => [s.id, s.text] as const), ...factText]);
  const lines: DraftLine[] = [];
  const rejected: CheckedDraft["rejected"] = [];

  for (const raw of output.lines ?? []) {
    const line: DraftLine = {
      text: typeof raw?.text === "string" ? raw.text : "",
      sources: Array.isArray(raw?.sources) ? raw.sources.filter((x): x is string => typeof x === "string") : [],
    };
    const reason =
      rejectReason(line, known) ?? factReason(line, segmentIds, factText) ?? valueReason(line, sourceText);
    if (reason) rejected.push({ line, reason });
    else lines.push({ text: line.text.trim(), sources: [...new Set(line.sources)] });
  }

  const cited = new Set(lines.flatMap((l) => l.sources));
  const unplaced = input.segments.map((s) => s.id).filter((id) => !cited.has(id));
  return { lines, rejected, unplaced };
}

function rejectReason(line: DraftLine, known: Set<string>): RejectReason | null {
  if (line.text.trim().length === 0) return "empty_text";
  if (line.text.length > MAX_LINE_CHARS) return "too_long";
  if (line.sources.length === 0) return "no_source";
  if (line.sources.some((id) => !known.has(id))) return "unknown_source";
  return null;
}

/** AUT-151 (2): a facts-only line is the recorded fact itself, word for word, or it is rejected. */
function factReason(line: DraftLine, segmentIds: Set<string>, factText: Map<string, string>): RejectReason | null {
  const ids = [...new Set(line.sources)];
  if (ids.some((id) => segmentIds.has(id))) return null;
  if (ids.length !== 1 || line.text.trim() !== factText.get(ids[0])?.trim()) return "fact_mismatch";
  return null;
}

/**
 * AUT-149 (ADR-214): values are compared as tokens, exactly. A number is a digit run with inner `.`, `,` or `:`
 * («120», «37,5», «07:02»); «120/80» is two numbers. A unit is one of a closed list, matched case-insensitively and
 * only when it is not part of a word («62kg» has one, «Milch» has none). Another spelling of the same value
 * («7:05» for «07:05», «37.5» for «37,5») is rejected: fail closed, her sentence stays listed for her decision.
 * Words are not compared (no clinical rule; negation and body side are S2 evaluation cases, `cra` 03:50).
 */
export const UNIT_TOKENS = ["mmhg", "mg", "ml", "kg", "min", "°c", "%", "l", "h"] as const;

const NUMBER = /\d+(?:[.,:]\d+)*/g;
const UNIT = new RegExp(`(?<!\\p{L})(${UNIT_TOKENS.join("|")})(?!\\p{L})`, "giu");

export function valueTokens(text: string): Set<string> {
  const tokens = new Set<string>();
  for (const m of text.matchAll(NUMBER)) tokens.add(`n:${m[0]}`);
  for (const m of text.matchAll(UNIT)) tokens.add(`u:${m[1].toLowerCase()}`);
  return tokens;
}

function valueReason(line: DraftLine, sourceText: Map<string, string>): RejectReason | null {
  const available = new Set<string>();
  for (const id of new Set(line.sources)) for (const t of valueTokens(sourceText.get(id) ?? "")) available.add(t);
  for (const t of valueTokens(line.text)) if (!available.has(t)) return "value_not_in_source";
  return null;
}
