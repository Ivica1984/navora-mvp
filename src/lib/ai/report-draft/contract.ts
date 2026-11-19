// Engine 3 (Voice-to-Report), BK-e2a: contract of the provider-neutral report-draft adapter (ADR-206, AUT-135).
// Synthetic data only in Phase A (FE-085 (2), D-35 rule A for real persons). A draft is never binding:
// the carer checks every line and signs through the existing F6 path (BK-e2b).

/** One piece of the carer's typed text. Ids are positional (s1, s2, …) and stable for the same text. */
export type Segment = { id: string; text: string };

/** A fact already recorded in NAVORA (F1–F4 times, place, order tags). Ids f1, f2, … set by the caller. */
export type Fact = { id: string; text: string };

export type DraftInput = { segments: Segment[]; facts: Fact[] };

/** A proposed report line. `sources` names the segment and fact ids it comes from. */
export type DraftLine = { text: string; sources: string[] };

export type ProviderOutput = { lines: DraftLine[]; unplaced: string[] };

export type ProviderKind = "rule" | "model";

export interface Provider {
  kind: ProviderKind;
  /** Origin label shown beside the draft. A rule provider is never labelled as AI (FE-088 (4), FE-090 (4)). */
  label: string;
  /** Model id of a model provider; written to the ledger row of each line (ADR-215 (2)), never shown as the label. */
  modelId?: string;
  propose(input: DraftInput): Promise<ProviderOutput>;
}

/**
 * `fact_mismatch` (AUT-151, `cra` condition (2), ADR-211): a line that cites only facts must cite exactly one fact and
 * repeat its text exactly; a reworded fact is not a recorded fact.
 */
/**
 * `value_not_in_source` (AUT-149, ADR-214): a number, time or unit token of the line occurs in none of its cited
 * segments or facts.
 */
export type RejectReason =
  | "no_source"
  | "unknown_source"
  | "empty_text"
  | "too_long"
  | "fact_mismatch"
  | "value_not_in_source";

export type CheckedDraft = {
  lines: DraftLine[];
  rejected: Array<{ line: DraftLine; reason: RejectReason }>;
  /** Segment ids not cited by any accepted line. Shown as «nicht übernommen» until the carer decides. */
  unplaced: string[];
};
