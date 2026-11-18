import { describe, expect, it, vi } from "vitest";

import { checkDraft } from "@/lib/ai/report-draft/control";
import { resolveReportDraftProvider } from "@/lib/ai/report-draft/config";
import { buildReportDraft } from "@/lib/ai/report-draft/draft";
import {
  ALLOWED_MODEL_HOSTS,
  createModelProvider,
  ModelConfigError,
} from "@/lib/ai/report-draft/model-provider";
import { RULE_ORIGIN_LABEL, ruleProvider } from "@/lib/ai/report-draft/rule-provider";
import { MAX_INPUT_CHARS, segmentInput } from "@/lib/ai/report-draft/segment";
import type { DraftInput, Provider, ProviderOutput } from "@/lib/ai/report-draft/contract";

/**
 * BK-e2a (ADR-206): Engine 3 report draft behind the provider-neutral adapter (AUT-135, AUT-136).
 * Synthetic text only. The control layer, not the provider, decides what reaches the draft:
 * no line without a source, nothing dropped silently, no silent fallback from model to rule.
 */

const FACTS = [
  { id: "f1", text: "Einsatz 07:02–07:48 (F1–F4)" },
  { id: "f2", text: "Ort: 4051 Basel" },
];

function input(text: string): DraftInput {
  return { segments: segmentInput(text), facts: FACTS };
}

function stub(output: ProviderOutput, kind: Provider["kind"] = "model"): Provider {
  return { kind, label: "stub", propose: vi.fn(async () => output) };
}

describe("segmentInput", () => {
  it("splits typed text into ordered segments with stable ids", () => {
    const s = segmentInput("Klientin wach und orientiert. Medikamente gerichtet!\nBlutdruck gemessen; Wert notiert");
    expect(s.map((x) => x.id)).toEqual(["s1", "s2", "s3", "s4"]);
    expect(s.map((x) => x.text)).toEqual([
      "Klientin wach und orientiert.",
      "Medikamente gerichtet!",
      "Blutdruck gemessen;",
      "Wert notiert",
    ]);
  });

  it("drops empty pieces and keeps the same ids for the same text", () => {
    expect(segmentInput("  \n\n  ")).toEqual([]);
    expect(segmentInput("A. B.")).toEqual(segmentInput("A. B."));
  });

  it("refuses input above the size limit instead of truncating it", () => {
    expect(() => segmentInput("x".repeat(MAX_INPUT_CHARS + 1))).toThrow(/input_too_long/);
  });
});

describe("checkDraft (control layer, stop rule: no value without a source)", () => {
  it("rejects a line without a source and a line with an unknown source", () => {
    const i = input("Klientin wach. Verband gewechselt.");
    const r = checkDraft(i, {
      lines: [
        { text: "Klientin wach.", sources: ["s1"] },
        { text: "Vitalzeichen unauffällig.", sources: [] },
        { text: "Wunde verheilt.", sources: ["s9"] },
      ],
      unplaced: [],
    });
    expect(r.lines).toEqual([{ text: "Klientin wach.", sources: ["s1"] }]);
    expect(r.rejected.map((x) => x.reason)).toEqual(["no_source", "unknown_source"]);
    // s2 was cited by no accepted line, so it is listed, never dropped.
    expect(r.unplaced).toEqual(["s2"]);
  });

  it("accepts a line that cites only a recorded fact", () => {
    const r = checkDraft(input(""), { lines: [{ text: "Einsatz 07:02–07:48", sources: ["f1"] }], unplaced: [] });
    expect(r.lines).toHaveLength(1);
    expect(r.rejected).toEqual([]);
  });

  it("rejects empty and oversized lines", () => {
    const r = checkDraft(input("A."), {
      lines: [
        { text: "   ", sources: ["s1"] },
        { text: "y".repeat(2001), sources: ["s1"] },
      ],
      unplaced: [],
    });
    expect(r.rejected.map((x) => x.reason)).toEqual(["empty_text", "too_long"]);
    expect(r.unplaced).toEqual(["s1"]);
  });

  it("ignores unplaced ids that are not segments and lists each segment once", () => {
    const r = checkDraft(input("A. B."), {
      lines: [{ text: "A.", sources: ["s1"] }],
      unplaced: ["s2", "s2", "zz", "f1"],
    });
    expect(r.unplaced).toEqual(["s2"]);
  });

  it("40 segments: every one is placed in an accepted line or listed (shared test, ADR-202 (5))", () => {
    const text = Array.from({ length: 40 }, (_, n) => `Satz ${n + 1}.`).join(" ");
    const i = input(text);
    expect(i.segments).toHaveLength(40);
    // a provider that places only the even segments and forgets the odd ones
    const out: ProviderOutput = {
      lines: i.segments.filter((_, n) => n % 2 === 1).map((s) => ({ text: s.text, sources: [s.id] })),
      unplaced: [],
    };
    const r = checkDraft(i, out);
    const placed = new Set(r.lines.flatMap((l) => l.sources));
    for (const s of i.segments) {
      expect(placed.has(s.id) !== r.unplaced.includes(s.id), `${s.id} exactly once`).toBe(true);
    }
    expect(r.unplaced).toHaveLength(20);
  });
});

describe("ruleProvider (test substitute, never called AI)", () => {
  it("is labelled rule-based and makes one sourced line per fact and per segment", async () => {
    expect(ruleProvider.kind).toBe("rule");
    expect(RULE_ORIGIN_LABEL).toBe("regelbasiert, keine KI · synthetische Daten");
    expect(ruleProvider.label).toBe(RULE_ORIGIN_LABEL);
    const i = input("Klientin wach. Verband gewechselt.");
    const out = await ruleProvider.propose(i);
    expect(out.lines).toEqual([
      { text: "Einsatz 07:02–07:48 (F1–F4)", sources: ["f1"] },
      { text: "Ort: 4051 Basel", sources: ["f2"] },
      { text: "Klientin wach.", sources: ["s1"] },
      { text: "Verband gewechselt.", sources: ["s2"] },
    ]);
    expect(checkDraft(i, out).unplaced).toEqual([]);
  });
});

describe("createModelProvider (CH model, OpenAI-compatible; AUT-136 guards)", () => {
  const ok = { baseUrl: "https://ai.example.ch/v1", apiKey: "k", model: "m" };

  it("ships with an empty host allowlist: no model is reachable until a reviewed change names the host", () => {
    expect(ALLOWED_MODEL_HOSTS).toEqual([]);
    expect(Object.isFrozen(ALLOWED_MODEL_HOSTS)).toBe(true);
    expect(() => createModelProvider({ ...ok, fetch: vi.fn() })).toThrow(ModelConfigError);
  });

  it("refuses http, credentials in the URL and hosts outside the allowlist", () => {
    const allowedHosts = ["ai.example.ch"];
    expect(() => createModelProvider({ ...ok, baseUrl: "http://ai.example.ch/v1", allowedHosts, fetch: vi.fn() })).toThrow(/https_required/);
    expect(() => createModelProvider({ ...ok, baseUrl: "https://u:p@ai.example.ch/v1", allowedHosts, fetch: vi.fn() })).toThrow(/credentials_in_url/);
    expect(() => createModelProvider({ ...ok, baseUrl: "https://evil.example.com/v1", allowedHosts, fetch: vi.fn() })).toThrow(/host_not_allowed/);
    expect(() => createModelProvider({ ...ok, apiKey: "", allowedHosts, fetch: vi.fn() })).toThrow(/api_key_missing/);
  });

  it("sends only the segments and facts, with temperature 0, and parses the JSON answer", async () => {
    const answer = { lines: [{ text: "Klientin wach und orientiert.", sources: ["s1"] }], unplaced: ["s2"] };
    const fetch = vi.fn(async () =>
      new Response(JSON.stringify({ choices: [{ message: { content: JSON.stringify(answer) } }] }), { status: 200 }),
    );
    const p = createModelProvider({ ...ok, allowedHosts: ["ai.example.ch"], fetch });
    expect(p.kind).toBe("model");
    expect(p.label).toMatch(/^KI-Entwurf · Modell m · synthetische Daten/);
    const i = input("Klientin wach. Verband gewechselt.");
    const out = await p.propose(i);
    expect(out).toEqual(answer);

    const [url, init] = fetch.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe("https://ai.example.ch/v1/chat/completions");
    expect((init.headers as Record<string, string>).Authorization).toBe("Bearer k");
    const body = JSON.parse(String(init.body));
    expect(body.model).toBe("m");
    expect(body.temperature).toBe(0);
    const user = JSON.parse(body.messages.find((m: { role: string }) => m.role === "user").content);
    expect(user).toEqual({ segments: i.segments, facts: i.facts });
  });

  it("fails on a non-200 answer or malformed JSON instead of inventing a draft", async () => {
    const allowedHosts = ["ai.example.ch"];
    const bad = createModelProvider({ ...ok, allowedHosts, fetch: vi.fn(async () => new Response("no", { status: 500 })) });
    await expect(bad.propose(input("A."))).rejects.toThrow(/model_http_500/);
    const junk = createModelProvider({
      ...ok,
      allowedHosts,
      fetch: vi.fn(async () => new Response(JSON.stringify({ choices: [{ message: { content: "kein json" } }] }))),
    });
    await expect(junk.propose(input("A."))).rejects.toThrow(/model_output_invalid/);
  });
});

describe("resolveReportDraftProvider (one stop switch, simulation only)", () => {
  const modelEnv = {
    AI_REPORT_DRAFT_MODE: "model",
    AI_MODEL_BASE_URL: "https://ai.example.ch/v1",
    AI_MODEL_API_KEY: "k",
    AI_MODEL_NAME: "m",
    NEXT_PUBLIC_SUPABASE_URL: "https://qpmdryxkktbqqkqpsnkj.supabase.co",
  };

  it("defaults to the rule provider", () => {
    const r = resolveReportDraftProvider({}, { simulationOrg: true });
    expect(r.provider?.kind).toBe("rule");
    expect(r.modelBlocked).toBeUndefined();
  });

  it("mode off gives no provider at all", () => {
    expect(resolveReportDraftProvider({ AI_REPORT_DRAFT_MODE: "off" }, { simulationOrg: true }).provider).toBeNull();
  });

  it("never uses the model with the stop switch on, outside a simulation org, or on the live project", () => {
    const fetch = vi.fn();
    const allowedHosts = ["ai.example.ch"];
    const cases: Array<[Record<string, string>, boolean, string]> = [
      [{ ...modelEnv, AI_KILL_SWITCH: "on" }, true, "kill_switch"],
      [modelEnv, false, "not_simulation_org"],
      [{ ...modelEnv, NEXT_PUBLIC_SUPABASE_URL: "https://jwmfxrmougneeceldhsa.supabase.co" }, true, "live_project"],
    ];
    for (const [env, simulationOrg, reason] of cases) {
      const r = resolveReportDraftProvider(env, { simulationOrg, allowedHosts, fetch });
      expect(r.provider?.kind, reason).toBe("rule");
      expect(r.modelBlocked).toBe(reason);
    }
    expect(fetch).not.toHaveBeenCalled();
  });

  it("with the shipped allowlist the model stays blocked and says why", () => {
    const r = resolveReportDraftProvider(modelEnv, { simulationOrg: true });
    expect(r.provider?.kind).toBe("rule");
    expect(r.modelBlocked).toBe("host_not_allowed");
  });

  it("uses the model only when every guard holds", () => {
    const r = resolveReportDraftProvider(modelEnv, { simulationOrg: true, allowedHosts: ["ai.example.ch"], fetch: vi.fn() });
    expect(r.provider?.kind).toBe("model");
    expect(r.modelBlocked).toBeUndefined();
  });
});

describe("buildReportDraft", () => {
  it("returns origin, label, the checked lines and the unplaced list", async () => {
    const d = await buildReportDraft({ text: "Klientin wach. Verband gewechselt.", facts: FACTS }, ruleProvider);
    expect(d.ok).toBe(true);
    if (!d.ok) return;
    expect(d.origin).toBe("rule");
    expect(d.label).toBe(RULE_ORIGIN_LABEL);
    expect(d.lines).toHaveLength(4);
    expect(d.unplaced).toEqual([]);
  });

  it("reports a provider failure and does not fall back silently to another provider", async () => {
    const failing: Provider = { kind: "model", label: "x", propose: vi.fn(async () => Promise.reject(new Error("boom"))) };
    const d = await buildReportDraft({ text: "A.", facts: [] }, failing);
    expect(d).toEqual({ ok: false, error: "provider_failed", origin: "model" });
  });

  it("refuses an over-long input before any provider call", async () => {
    const p = stub({ lines: [], unplaced: [] });
    const d = await buildReportDraft({ text: "x".repeat(MAX_INPUT_CHARS + 1), facts: [] }, p);
    expect(d).toEqual({ ok: false, error: "input_too_long", origin: "model" });
    expect(p.propose).not.toHaveBeenCalled();
  });
});
