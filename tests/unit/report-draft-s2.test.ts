import { describe, expect, it } from "vitest";

import { CLAUDE_INFERENCE_GEO, createAnthropicProvider } from "@/lib/ai/report-draft/anthropic-provider";
import { buildReportDraft, type ReportDraft } from "@/lib/ai/report-draft/draft";
import { S2_CASES, type S2Case, type S2Category } from "@/lib/ai/report-draft/s2-cases";

/**
 * S2 evaluation set (BK-e2 package contract point 2, `aia` AUT-158 check 5, ADR-217). Every case runs the full path a
 * model draft takes on staging: Claude provider (fetch replaced, no network, no real model in CI) → JSON parse →
 * control layer. The counts are printed to the CI log as one block beginning «S2 report-draft evaluation».
 * Synthetic notes only. Hand-written answers: this proves the guards, not Claude's draft quality.
 */

type Observed = "rejected" | "unplaced" | "provider_failed" | "passes_control";

function fakeClaude(answer: string, seen: unknown[]): typeof fetch {
  return (async (_url: string | URL | Request, init?: RequestInit) => {
    seen.push(JSON.parse(String(init?.body)));
    return new Response(JSON.stringify({ content: [{ type: "text", text: answer }] }), { status: 200 });
  }) as typeof fetch;
}

async function runCase(c: S2Case): Promise<{ draft: ReportDraft; body: Record<string, unknown> }> {
  const seen: unknown[] = [];
  const provider = createAnthropicProvider({ apiKey: "test-key-not-real", model: "claude-s2-fixture", fetch: fakeClaude(c.answer, seen) });
  const draft = await buildReportDraft({ text: c.note, facts: c.facts }, provider);
  return { draft, body: seen[0] as Record<string, unknown> };
}

function observe(d: ReportDraft): Observed {
  if (!d.ok) return "provider_failed";
  if (d.rejected.length > 0) return "rejected";
  if (d.unplaced.length > 0) return "unplaced";
  return "passes_control";
}

describe("S2 evaluation set: synthetic notes through the Claude path and the control layer", () => {
  it("has unique ids and covers every category", () => {
    expect(new Set(S2_CASES.map((c) => c.id)).size).toBe(S2_CASES.length);
    const cats: S2Category[] = ["value", "source", "dropped", "fact", "format", "carer", "faithful"];
    for (const cat of cats) expect(S2_CASES.some((c) => c.category === cat)).toBe(true);
  });

  for (const c of S2_CASES) {
    it(`${c.id} (${c.category}): ${c.title}`, async () => {
      const { draft, body } = await runCase(c);
      // The call carries only segments and facts, and the explicit region (contract point 2).
      expect(body.inference_geo).toBe(CLAUDE_INFERENCE_GEO);
      const user = JSON.parse((body.messages as Array<{ content: string }>)[0].content);
      expect(Object.keys(user).sort()).toEqual(["facts", "segments"]);

      const e = c.expected;
      if (e.outcome === "provider_failed") {
        expect(draft).toMatchObject({ ok: false, error: "provider_failed", origin: "model" });
        return;
      }
      if (!draft.ok) throw new Error(`${c.id}: unexpected failure ${draft.error}`);
      switch (e.outcome) {
        case "rejected":
          expect(draft.rejected.map((r) => r.reason)).toContain(e.reason);
          break;
        case "unplaced":
          expect(draft.rejected).toEqual([]);
          expect(draft.unplaced).toEqual(e.ids);
          break;
        case "passes_control":
        case "accepted":
          expect(draft.rejected).toEqual([]);
          expect(draft.unplaced).toEqual([]);
          break;
      }
    });
  }

  it("prints the counts to the CI log", async () => {
    const rows = new Map<S2Category, { n: number; stopped: number; toCarer: number; accepted: number }>();
    for (const c of S2_CASES) {
      const { draft } = await runCase(c);
      const o = observe(draft);
      const r = rows.get(c.category) ?? { n: 0, stopped: 0, toCarer: 0, accepted: 0 };
      r.n += 1;
      if (c.category === "faithful") r.accepted += o === "passes_control" ? 1 : 0;
      else if (o === "passes_control") r.toCarer += 1;
      else r.stopped += 1;
      rows.set(c.category, r);
    }
    const lines = [
      `S2 report-draft evaluation: ${S2_CASES.length} synthetic cases, hand-written answers, Claude path with fetch replaced`,
      "category | cases | stopped or listed by control | passed to carer only | faithful accepted",
      ...[...rows].map(([cat, r]) => `${cat} | ${r.n} | ${r.stopped} | ${r.toCarer} | ${r.accepted}`),
    ];
    process.stdout.write(`${lines.join("\n")}\n`);

    // Every fault the control is built for is stopped or listed; only the named `carer` limit reaches her unchanged.
    for (const [cat, r] of rows) {
      if (cat === "carer") expect(r.toCarer).toBe(r.n);
      else if (cat === "faithful") expect(r.accepted).toBe(r.n);
      else expect(r.stopped).toBe(r.n);
    }
  });
});
