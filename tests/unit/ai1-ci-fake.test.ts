import { describe, expect, it, vi } from "vitest";
import { configuredReportDraftMode, resolveReportDraftProvider } from "@/lib/ai/report-draft/config";
import { buildReportDraft } from "@/lib/ai/report-draft/draft";
import { CLAUDE_MAX_OUTPUT_TOKENS } from "@/lib/ai/report-draft/anthropic-provider";
import {
  CI_FAKE_MODEL_ID,
  CI_FAKE_ORIGIN_LABEL,
  ciFakeCallTag,
  createCiFakeProvider,
} from "@/lib/ai/report-draft/ci-fake-provider";
import { segmentInput } from "@/lib/ai/report-draft/segment";
import { ModelCallError } from "@/lib/ai/report-draft/contract";

// AI1 / ADR-227 addendum 2026-11-24 09:45 + 12:17 (#1697 F1, F2, F5): the CI fake provider and its guards.
const ci = {
  AI_REPORT_DRAFT_MODE: "model",
  AI_MODEL_PROVIDER: "ci-fake",
  GITHUB_ACTIONS: "true",
  NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:54321",
};
const ctx = { simulationOrg: true, ledgerReady: true, fetch: vi.fn() };

describe("ci-fake resolver guards", () => {
  it("is used only when every condition holds, on the model path, never labelled as AI", () => {
    for (const url of ["http://127.0.0.1:54321", "http://localhost:54321"]) {
      const r = resolveReportDraftProvider({ ...ci, NEXT_PUBLIC_SUPABASE_URL: url }, ctx);
      expect(r.modelBlocked, url).toBeUndefined();
      expect(r.provider?.kind).toBe("model");
      expect(r.provider?.modelId).toBe(CI_FAKE_MODEL_ID);
      expect(r.provider?.label).toBe(CI_FAKE_ORIGIN_LABEL);
      expect(r.provider?.label).not.toMatch(/\bKI-Entwurf\b|Claude/);
    }
    expect(ctx.fetch).not.toHaveBeenCalled();
  });

  it("is refused with its own reason for each missing condition", () => {
    const cases: Array<[string, Record<string, string | undefined>]> = [
      ["no GITHUB_ACTIONS", { ...ci, GITHUB_ACTIONS: undefined }],
      ["GITHUB_ACTIONS not exactly true", { ...ci, GITHUB_ACTIONS: "1" }],
      ["RENDER set", { ...ci, RENDER: "true" }],
      ["RENDER set but empty", { ...ci, RENDER: "" }],
      ["staging host", { ...ci, NEXT_PUBLIC_SUPABASE_URL: "https://qpmdryxkktbqqkqpsnkj.supabase.co" }],
      ["other host", { ...ci, NEXT_PUBLIC_SUPABASE_URL: "http://10.0.0.5:54321" }],
      ["substring trick", { ...ci, NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1.evil.example:54321" }],
      ["https on loopback", { ...ci, NEXT_PUBLIC_SUPABASE_URL: "https://127.0.0.1:54321" }],
      ["other port", { ...ci, NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:5432" }],
      ["no port", { ...ci, NEXT_PUBLIC_SUPABASE_URL: "http://localhost" }],
      ["ipv6 loopback", { ...ci, NEXT_PUBLIC_SUPABASE_URL: "http://[::1]:54321" }],
      ["other loopback", { ...ci, NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.2:54321" }],
      ["credentials", { ...ci, NEXT_PUBLIC_SUPABASE_URL: "http://u:p@127.0.0.1:54321" }],
      ["no url", { ...ci, NEXT_PUBLIC_SUPABASE_URL: undefined }],
    ];
    for (const [name, env] of cases) {
      const r = resolveReportDraftProvider(env, ctx);
      expect(r.provider?.kind, name).toBe("rule");
      expect(r.modelBlocked, name).toBe("ci_fake_outside_ci");
    }
  });

  it("keeps the order kill switch → live project → ci-fake, then simulation org and ledger", () => {
    expect(resolveReportDraftProvider({ ...ci, AI_KILL_SWITCH: "on" }, ctx).modelBlocked).toBe("kill_switch");
    expect(
      resolveReportDraftProvider({ ...ci, NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:54321/jwmfxrmougneeceldhsa" }, ctx)
        .modelBlocked,
    ).toBe("live_project");
    expect(resolveReportDraftProvider(ci, { ...ctx, simulationOrg: false }).modelBlocked).toBe("not_simulation_org");
    expect(resolveReportDraftProvider(ci, { ...ctx, ledgerReady: false }).modelBlocked).toBe("ledger_missing");
  });

  it("leaves not_staging unchanged for the real providers in CI", () => {
    for (const kind of ["anthropic", "openai-compatible"]) {
      const r = resolveReportDraftProvider({ ...ci, AI_MODEL_PROVIDER: kind, AI_MODEL_API_KEY: "k", AI_MODEL_NAME: "m" }, ctx);
      expect(r.modelBlocked, kind).toBe("not_staging");
    }
  });
});

describe("/api/version word for the fake (F1)", () => {
  it("reports ci-fake in CI and misconfigured on any deployed server", () => {
    expect(configuredReportDraftMode(ci)).toBe("ci-fake");
    expect(configuredReportDraftMode({ ...ci, RENDER: "true" })).toBe("misconfigured");
    expect(
      configuredReportDraftMode({
        ...ci,
        GITHUB_ACTIONS: undefined,
        RENDER: "true",
        NEXT_PUBLIC_SUPABASE_URL: "https://qpmdryxkktbqqkqpsnkj.supabase.co",
      }),
    ).toBe("misconfigured");
    // The kill switch wins first, as for every kind.
    expect(configuredReportDraftMode({ ...ci, RENDER: "true", AI_KILL_SWITCH: "on" })).toBe("rule");
  });
});

describe("ci-fake provider", () => {
  const input = { segments: segmentInput("Patientin mobilisiert. Blutdruck 130/80 gemessen."), facts: [{ id: "f1", text: "Beginn 08:00" }] };

  it("quotes only, passes the draft check, reports usage within the answer cap", async () => {
    const out = await createCiFakeProvider().propose(input);
    expect(out.lines).toEqual([
      { text: "Beginn 08:00", sources: ["f1"] },
      { text: "Patientin mobilisiert.", sources: ["s1"] },
      { text: "Blutdruck 130/80 gemessen.", sources: ["s2"] },
    ]);
    expect(out.usage!.inputTokens).toBeGreaterThan(0);
    expect(out.usage!.outputTokens).toBeLessThanOrEqual(CLAUDE_MAX_OUTPUT_TOKENS);
    const draft = await buildReportDraft({ text: "Patientin mobilisiert. Blutdruck 130/80 gemessen.", facts: input.facts }, createCiFakeProvider());
    expect(draft.ok).toBe(true);
  });

  it("appends one line per call with the note digest, never the text", async () => {
    const append = vi.fn(async () => {});
    const p = createCiFakeProvider({ callsFile: "/tmp/calls", append });
    await p.propose(input);
    await p.propose(input);
    expect(append).toHaveBeenCalledTimes(2);
    expect(append).toHaveBeenCalledWith("/tmp/calls", `${ciFakeCallTag(input)}\n`);
    const line = (append.mock.calls[0] as unknown as [string, string])[1];
    expect(line).toMatch(/^[0-9a-f]{16}\n$/);
    expect(ciFakeCallTag({ ...input, segments: segmentInput("Anderer Text.") })).not.toBe(ciFakeCallTag(input));
  });

  it("fails the call when the counter cannot be written", async () => {
    const p = createCiFakeProvider({ callsFile: "/x", append: async () => Promise.reject(new Error("EACCES")) });
    await expect(p.propose(input)).rejects.toBeInstanceOf(ModelCallError);
  });
});
