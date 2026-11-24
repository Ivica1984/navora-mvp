import { createHash } from "node:crypto";
import { ModelCallError, type DraftInput, type Provider, type ProviderOutput } from "./contract";
import { CLAUDE_MAX_OUTPUT_TOKENS } from "./anthropic-provider";

/**
 * AI1 / ADR-227 addendum 2026-11-24 09:45 (point 1) and 12:17: a deterministic test substitute that takes the MODEL path
 * (reserve → call → settle → record, migrations 0166–0170) in CI only, so the e2e proves the database invariants
 * (double tap, kill switch, third attempt) without any network call. It is never AI and is never labelled as AI
 * (FE-088 (4), FE-090 (4)). Guards that keep it out of every deployed server are in config.ts (`ci_fake_outside_ci`).
 */
export const CI_FAKE_MODEL_ID = "ci-fake";
/** On-screen origin label (`uxa` gate: wording). Says what it is: a test substitute, no AI model, CI only. */
export const CI_FAKE_ORIGIN_LABEL = "Testersatz (kein KI-Modell), CI";

/** Rough token count for the fake's usage (chars / 4): a CI fixture value, not a measurement of any model. */
function fakeTokens(value: unknown): number {
  return Math.max(1, Math.ceil(JSON.stringify(value).length / 4));
}

/**
 * Digest of the note's segments: one line per call in the counter file, so a spec counts only the calls for its own
 * note text (#1697 F5; the provider is not given the report id, and the Provider contract is not widened for a fake).
 */
export function ciFakeCallTag(input: DraftInput): string {
  return createHash("sha256")
    .update(input.segments.map((s) => s.text).join("\n"))
    .digest("hex")
    .slice(0, 16);
}

export type CiFakeProviderOptions = {
  /** File the fake appends one line per call to (`NAVORA_CI_FAKE_CALLS`); none: no counter. Synthetic digests only. */
  callsFile?: string;
  append?: (file: string, line: string) => Promise<void>;
};

async function appendLine(file: string, line: string): Promise<void> {
  const fs = await import("node:fs/promises");
  await fs.appendFile(file, line, "utf8");
}

export function createCiFakeProvider(opts: CiFakeProviderOptions = {}): Provider {
  return {
    kind: "model",
    label: CI_FAKE_ORIGIN_LABEL,
    modelId: CI_FAKE_MODEL_ID,
    async propose(input: DraftInput): Promise<ProviderOutput> {
      if (opts.callsFile) {
        try {
          await (opts.append ?? appendLine)(opts.callsFile, `${ciFakeCallTag(input)}\n`);
        } catch {
          // A counter that cannot be written must not hide a call: the call fails and is settled as a provider error.
          throw new ModelCallError("provider_error");
        }
      }
      // Quotes only: each recorded fact, then each segment, as one line citing itself (no invention by construction).
      const lines = [
        ...input.facts.map((f) => ({ text: f.text, sources: [f.id] })),
        ...input.segments.map((s) => ({ text: s.text, sources: [s.id] })),
      ];
      return {
        lines,
        unplaced: [],
        usage: { inputTokens: fakeTokens(input), outputTokens: Math.min(fakeTokens(lines), CLAUDE_MAX_OUTPUT_TOKENS) },
      };
    },
  };
}
