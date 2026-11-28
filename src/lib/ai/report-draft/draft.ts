import { checkDraft } from "./control";
import { ModelCallError, type CheckedDraft, type Fact, type ModelCallOutcome, type ModelUsage, type Provider, type ProviderKind, type Segment } from "./contract";
import { segmentInput } from "./segment";

export type ReportDraft =
  | ({ ok: true; origin: ProviderKind; label: string; modelId?: string; segments: Segment[]; usage?: ModelUsage } & CheckedDraft)
  | {
      ok: false;
      error: "input_too_long" | "provider_failed";
      origin: ProviderKind;
      outcome?: Exclude<ModelCallOutcome, "ok">;
      usage?: ModelUsage;
    };

/**
 * Typed text + recorded facts → checked draft. Unsigned and not binding: every line stays a proposal until
 * the carer confirms it, and only the F6 signing path makes a report final (BK-e2b).
 * A provider failure is reported; there is no silent switch to another provider.
 */
export async function buildReportDraft(input: { text: string; facts: Fact[] }, provider: Provider): Promise<ReportDraft> {
  let segments: Segment[];
  try {
    segments = segmentInput(input.text);
  } catch {
    return { ok: false, error: "input_too_long", origin: provider.kind };
  }
  const draftInput = { segments, facts: input.facts };
  let output;
  try {
    output = await provider.propose(draftInput);
  } catch (e) {
    // AI1: what the failed call still cost, so its reservation is settled with the measured tokens (ADR-227 point 1).
    const failed = e instanceof ModelCallError ? { outcome: e.outcome, usage: e.usage } : { outcome: "provider_error" as const };
    return { ok: false, error: "provider_failed", origin: provider.kind, ...failed };
  }
  return {
    ok: true,
    origin: provider.kind,
    label: provider.label,
    modelId: provider.modelId,
    segments,
    usage: output.usage,
    ...checkDraft(draftInput, output),
  };
}
