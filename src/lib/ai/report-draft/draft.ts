import { checkDraft } from "./control";
import type { CheckedDraft, Fact, Provider, ProviderKind, Segment } from "./contract";
import { segmentInput } from "./segment";

export type ReportDraft =
  | ({ ok: true; origin: ProviderKind; label: string; modelId?: string; segments: Segment[] } & CheckedDraft)
  | { ok: false; error: "input_too_long" | "provider_failed"; origin: ProviderKind };

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
  } catch {
    return { ok: false, error: "provider_failed", origin: provider.kind };
  }
  return { ok: true, origin: provider.kind, label: provider.label, modelId: provider.modelId, segments, ...checkDraft(draftInput, output) };
}
