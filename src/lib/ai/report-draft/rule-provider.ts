import type { Provider } from "./contract";

/** The test substitute is labelled as what it is (FE-088 (4), FE-090 (4)); it is never called AI. */
export const RULE_ORIGIN_LABEL = "regelbasiert, keine KI · synthetische Daten";

/** Deterministic substitute: each recorded fact, then each segment, becomes one line citing itself. No call out. */
export const ruleProvider: Provider = {
  kind: "rule",
  label: RULE_ORIGIN_LABEL,
  async propose(input) {
    return {
      lines: [
        ...input.facts.map((f) => ({ text: f.text, sources: [f.id] })),
        ...input.segments.map((s) => ({ text: s.text, sources: [s.id] })),
      ],
      unplaced: [],
    };
  },
};
