import { describe, expect, it } from "vitest";

import { assistFromDraft, decideLine, decideSegment, inputRecord } from "@/features/field/report-assist";
import { buildReportDraft } from "@/lib/ai/report-draft/draft";
import { ruleProvider } from "@/lib/ai/report-draft/rule-provider";
import type { Provider, ProviderOutput } from "@/lib/ai/report-draft/contract";

/**
 * BK-e2b (ADR-219, migration 0152): the input record stored with the open report when she places the draft into the
 * summary. Every segment once with her decision; lines as source ids and decision only; nothing while anything is open.
 * Shared test of the BK brief criterion 5: 40 segments → 40 placed or listed, none lost. Synthetic text only.
 */

const stub = (output: ProviderOutput): Provider => ({ kind: "model", label: "stub", propose: async () => output });

async function assistFor(text: string, provider: Provider) {
  const d = await buildReportDraft({ text, facts: [{ id: "f1", text: "Einsatz 07:02–07:48" }] }, provider);
  if (!d.ok) throw new Error(d.error);
  return assistFromDraft(d);
}

describe("inputRecord (BK-e2b)", () => {
  it("is null while a line or a listed sentence is still open", async () => {
    const a = await assistFor("Klientin wach. Wetter schön.", stub({ lines: [{ text: "Klientin wach.", sources: ["s1"] }], unplaced: [] }));
    expect(inputRecord(a)).toBeNull();
    expect(inputRecord(decideLine(a, 0, "taken"))).toBeNull(); // s2 is listed and still open
  });

  it("gives every segment one decision consistent with the lines, and keeps no line text", async () => {
    let a = await assistFor(
      "Klientin wach. Verband gewechselt. Im Bad gestürzt, keine sichtbare Verletzung. Wetter schön.",
      stub({
        lines: [
          { text: "Klientin wach.", sources: ["s1", "f1"] },
          { text: "Verband gewechselt.", sources: ["s2"] },
        ],
        unplaced: [],
      }),
    );
    a = decideLine(decideLine(a, 0, "taken"), 1, "dropped");
    a = decideSegment(decideSegment(a, "s3", "inserted"), "s4", "omitted");
    const r = inputRecord(a);
    expect(r).toEqual({
      origin: "model",
      segments: [
        { id: "s1", text: "Klientin wach.", decision: "taken" },
        { id: "s2", text: "Verband gewechselt.", decision: "dropped" },
        { id: "s3", text: "Im Bad gestürzt, keine sichtbare Verletzung.", decision: "inserted" },
        { id: "s4", text: "Wetter schön.", decision: "omitted" },
      ],
      lines: [
        { sources: ["s1", "f1"], decision: "taken" },
        { sources: ["s2"], decision: "dropped" },
      ],
    });
    expect(JSON.stringify(r!.lines)).not.toContain("Klientin");
  });

  it("a segment in a taken and a rejected line counts as taken", async () => {
    let a = await assistFor(
      "Klientin wach und ruhig.",
      stub({ lines: [{ text: "Klientin wach.", sources: ["s1"] }, { text: "Klientin ruhig.", sources: ["s1"] }], unplaced: [] }),
    );
    a = decideLine(decideLine(a, 0, "dropped"), 1, "taken");
    expect(inputRecord(a)!.segments).toEqual([{ id: "s1", text: "Klientin wach und ruhig.", decision: "taken" }]);
  });

  it("shared test: 40 segments → 40 placed or listed, none lost, ids s1…s40 in order", async () => {
    const text = Array.from({ length: 40 }, (_, i) => `Synthetischer Satz ${i + 1}.`).join(" ");
    let a = await assistFor(text, ruleProvider);
    // The rule substitute proposes one line per segment (and the fact as context); she takes even, drops odd ones.
    expect(a.lines).toHaveLength(40);
    a.lines.forEach((_, i) => (a = decideLine(a, i, i % 2 === 0 ? "taken" : "dropped")));
    const r = inputRecord(a)!;
    expect(r.origin).toBe("rule");
    expect(r.segments).toHaveLength(40);
    expect(r.segments.map((s) => s.id)).toEqual(Array.from({ length: 40 }, (_, i) => `s${i + 1}`));
    expect(r.segments.filter((s) => s.decision === "taken")).toHaveLength(20);
    expect(r.segments.filter((s) => s.decision === "dropped")).toHaveLength(20);
  });
});
