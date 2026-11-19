import { describe, expect, it, vi } from "vitest";

import { checkDraft } from "@/lib/ai/report-draft/control";
import { resolveReportDraftProvider } from "@/lib/ai/report-draft/config";
import { buildReportDraft } from "@/lib/ai/report-draft/draft";
import {
  ALLOWED_MODEL_HOSTS,
  createModelProvider,
  ModelConfigError,
} from "@/lib/ai/report-draft/model-provider";
import { ANTHROPIC_HOST, createAnthropicProvider } from "@/lib/ai/report-draft/anthropic-provider";
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

  // AUT-151, `cra` condition (2) (CLINICAL_GOVERNANCE.md 2026-11-19 03:50): a line that cites only facts must equal
  // the fact text exactly, else it is rejected. ADR-211: it must cite exactly one fact.
  it("accepts a line that cites only a recorded fact when it equals the fact text exactly", () => {
    const r = checkDraft(input(""), { lines: [{ text: "Einsatz 07:02–07:48 (F1–F4)", sources: ["f1"] }], unplaced: [] });
    expect(r.lines).toEqual([{ text: "Einsatz 07:02–07:48 (F1–F4)", sources: ["f1"] }]);
    expect(r.rejected).toEqual([]);
  });

  it("rejects a facts-only line whose text differs from the fact (AUT-151 (2))", () => {
    const r = checkDraft(input(""), {
      lines: [
        { text: "Einsatz 07:02–07:48", sources: ["f1"] },
        { text: "Einsatz 07:02–07:58 (F1–F4)", sources: ["f1"] },
        { text: "einsatz 07:02–07:48 (f1–f4)", sources: ["f1"] },
      ],
      unplaced: [],
    });
    expect(r.lines).toEqual([]);
    expect(r.rejected.map((x) => x.reason)).toEqual(["fact_mismatch", "fact_mismatch", "fact_mismatch"]);
  });

  it("rejects a facts-only line that cites more than one fact (AUT-151 (2), ADR-211)", () => {
    const r = checkDraft(input(""), {
      lines: [{ text: "Einsatz 07:02–07:48 (F1–F4)", sources: ["f1", "f2"] }],
      unplaced: [],
    });
    expect(r.rejected.map((x) => x.reason)).toEqual(["fact_mismatch"]);
  });

  it("keeps a line that cites a fact and a segment, whatever its wording (AUT-151 (3): she decides it)", () => {
    const r = checkDraft(input("Klientin wach."), {
      lines: [{ text: "Klientin um 07:02 wach.", sources: ["f1", "s1"] }],
      unplaced: [],
    });
    expect(r.lines).toEqual([{ text: "Klientin um 07:02 wach.", sources: ["f1", "s1"] }]);
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
    const r = resolveReportDraftProvider({}, { ledgerReady: false, simulationOrg: true });
    expect(r.provider?.kind).toBe("rule");
    expect(r.modelBlocked).toBeUndefined();
  });

  it("mode off gives no provider at all", () => {
    expect(resolveReportDraftProvider({ AI_REPORT_DRAFT_MODE: "off" }, { ledgerReady: false, simulationOrg: true }).provider).toBeNull();
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
      const r = resolveReportDraftProvider(env, { ledgerReady: false, simulationOrg, allowedHosts, fetch });
      expect(r.provider?.kind, reason).toBe("rule");
      expect(r.modelBlocked).toBe(reason);
    }
    expect(fetch).not.toHaveBeenCalled();
  });

  it("with the shipped allowlist the model stays blocked and says why", () => {
    const r = resolveReportDraftProvider(modelEnv, { ledgerReady: false, simulationOrg: true });
    expect(r.provider?.kind).toBe("rule");
    expect(r.modelBlocked).toBe("host_not_allowed");
  });

  it("uses the model only when every guard holds", () => {
    const r = resolveReportDraftProvider(modelEnv, {
      simulationOrg: true,
      ledgerReady: true,
      allowedHosts: ["ai.example.ch"],
      fetch: vi.fn(),
    });
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

/**
 * Founder decision 2026-11-18 ca. 23:58 (live session with `eng`): Claude through the Anthropic API directly,
 * synthetic data, staging only. Exception to FE-085 (A) for Phase A synthetic data; real persons keep D-35.
 */
describe("createAnthropicProvider (Claude, founder decision 2026-11-18)", () => {
  it("allows exactly the Anthropic API host", () => {
    expect(ANTHROPIC_HOST).toBe("api.anthropic.com");
    expect(() => createAnthropicProvider({ apiKey: "", model: "c", fetch: vi.fn() })).toThrow(/api_key_missing/);
    expect(() => createAnthropicProvider({ apiKey: "k", model: "", fetch: vi.fn() })).toThrow(/model_missing/);
  });

  it("sends only segments and facts to the messages API and parses the JSON text", async () => {
    const answer = { lines: [{ text: "Klientin wach.", sources: ["s1"] }], unplaced: ["s2"] };
    const fetch = vi.fn(async () =>
      new Response(JSON.stringify({ content: [{ type: "text", text: JSON.stringify(answer) }] }), { status: 200 }),
    );
    const p = createAnthropicProvider({ apiKey: "k", model: "claude-x", fetch });
    expect(p.kind).toBe("model");
    expect(p.label).toMatch(/^KI-Entwurf · Claude claude-x · synthetische Daten/);
    const i = input("Klientin wach. Verband gewechselt.");
    expect(await p.propose(i)).toEqual(answer);

    const [url, init] = fetch.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe("https://api.anthropic.com/v1/messages");
    const h = init.headers as Record<string, string>;
    expect(h["x-api-key"]).toBe("k");
    expect(h["anthropic-version"]).toBe("2023-06-01");
    const body = JSON.parse(String(init.body));
    expect(body.model).toBe("claude-x");
    expect(body.temperature).toBe(0);
    expect(body.messages).toHaveLength(1);
    expect(JSON.parse(body.messages[0].content)).toEqual({ segments: i.segments, facts: i.facts });
  });

  it("accepts a JSON answer wrapped in a code fence, refuses anything else", async () => {
    const answer = { lines: [], unplaced: [] };
    const fenced = createAnthropicProvider({
      apiKey: "k",
      model: "c",
      fetch: vi.fn(async () => new Response(JSON.stringify({ content: [{ type: "text", text: "```json\n" + JSON.stringify(answer) + "\n```" }] }))),
    });
    expect(await fenced.propose(input("A."))).toEqual(answer);
    const junk = createAnthropicProvider({
      apiKey: "k",
      model: "c",
      fetch: vi.fn(async () => new Response(JSON.stringify({ content: [{ type: "text", text: "Hier ist der Bericht." }] }))),
    });
    await expect(junk.propose(input("A."))).rejects.toThrow(/model_output_invalid/);
    const down = createAnthropicProvider({ apiKey: "k", model: "c", fetch: vi.fn(async () => new Response("x", { status: 529 })) });
    await expect(down.propose(input("A."))).rejects.toThrow(/model_http_529/);
  });
});

describe("resolveReportDraftProvider with AI_MODEL_PROVIDER=anthropic (staging only)", () => {
  const env = {
    AI_REPORT_DRAFT_MODE: "model",
    AI_MODEL_PROVIDER: "anthropic",
    AI_MODEL_API_KEY: "k",
    AI_MODEL_NAME: "claude-x",
    NEXT_PUBLIC_SUPABASE_URL: "https://qpmdryxkktbqqkqpsnkj.supabase.co",
  };

  it("uses Claude on staging in a simulation org", () => {
    const r = resolveReportDraftProvider(env, { simulationOrg: true, ledgerReady: true, fetch: vi.fn() });
    expect(r.provider?.kind).toBe("model");
    expect(r.provider?.label).toMatch(/Claude/);
  });

  it("stays on the rule substitute outside staging, with the stop switch, or outside a simulation org", () => {
    const cases: Array<[Record<string, string>, boolean, string]> = [
      [{ ...env, NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:54321" }, true, "not_staging"],
      [{ ...env, NEXT_PUBLIC_SUPABASE_URL: "https://jwmfxrmougneeceldhsa.supabase.co" }, true, "live_project"],
      [{ ...env, AI_KILL_SWITCH: "on" }, true, "kill_switch"],
      [env, false, "not_simulation_org"],
      [{ ...env, AI_MODEL_API_KEY: "" }, true, "api_key_missing"],
    ];
    for (const [e, simulationOrg, reason] of cases) {
      const r = resolveReportDraftProvider(e, { ledgerReady: false, simulationOrg, fetch: vi.fn() });
      expect(r.provider?.kind, reason).toBe("rule");
      expect(r.modelBlocked, reason).toBe(reason);
    }
  });

  it("refuses an unknown provider name", () => {
    const r = resolveReportDraftProvider({ ...env, AI_MODEL_PROVIDER: "other" }, { ledgerReady: false, simulationOrg: true, fetch: vi.fn() });
    expect(r.provider?.kind).toBe("rule");
    expect(r.modelBlocked).toBe("provider_unknown");
  });
});

describe("resolveReportDraftProvider: ledger guard in the single resolver (AUT-153)", () => {
  const anthropicEnv = {
    AI_REPORT_DRAFT_MODE: "model",
    AI_MODEL_PROVIDER: "anthropic",
    AI_MODEL_API_KEY: "k",
    AI_MODEL_NAME: "claude-x",
    NEXT_PUBLIC_SUPABASE_URL: "https://qpmdryxkktbqqkqpsnkj.supabase.co",
  };
  const compatibleEnv = {
    AI_REPORT_DRAFT_MODE: "model",
    AI_MODEL_BASE_URL: "https://ai.example.ch/v1",
    AI_MODEL_API_KEY: "k",
    AI_MODEL_NAME: "m",
    NEXT_PUBLIC_SUPABASE_URL: "https://qpmdryxkktbqqkqpsnkj.supabase.co",
  };

  it("no caller gets a model provider while the AI ledger is missing, for either provider", () => {
    const fetch = vi.fn();
    for (const env of [anthropicEnv, compatibleEnv]) {
      const r = resolveReportDraftProvider(env, { simulationOrg: true, ledgerReady: false, allowedHosts: ["ai.example.ch"], fetch });
      expect(r.provider).toBe(ruleProvider);
      expect(r.modelBlocked).toBe("ledger_missing");
    }
    expect(fetch).not.toHaveBeenCalled();
  });

  it("an earlier guard keeps its own reason; rule mode and «off» are not touched by the ledger flag", () => {
    expect(resolveReportDraftProvider({ ...anthropicEnv, AI_KILL_SWITCH: "on" }, { simulationOrg: true, ledgerReady: false }).modelBlocked).toBe(
      "kill_switch",
    );
    expect(resolveReportDraftProvider({}, { simulationOrg: true, ledgerReady: false })).toEqual({ provider: ruleProvider });
    expect(resolveReportDraftProvider({ AI_REPORT_DRAFT_MODE: "off" }, { simulationOrg: true, ledgerReady: false })).toEqual({ provider: null });
  });
});

describe("resolveReportDraftProvider: guard matrix (AUT-150)", () => {
  const env = {
    AI_REPORT_DRAFT_MODE: "model",
    AI_MODEL_PROVIDER: "anthropic",
    AI_MODEL_API_KEY: "k",
    AI_MODEL_NAME: "claude-x",
    NEXT_PUBLIC_SUPABASE_URL: "https://qpmdryxkktbqqkqpsnkj.supabase.co",
  };
  const ctx = { simulationOrg: true, ledgerReady: true, fetch: vi.fn() };

  it("the stop switch stops on every value except empty or «off»", () => {
    for (const value of ["on", "ON", "On", "1", "true", "yes", " off", "off ", "OFF", "stop"]) {
      const r = resolveReportDraftProvider({ ...env, AI_KILL_SWITCH: value }, ctx);
      expect(r.provider?.kind, JSON.stringify(value)).toBe("rule");
      expect(r.modelBlocked, JSON.stringify(value)).toBe("kill_switch");
    }
    for (const value of [undefined, "", "off"]) {
      const r = resolveReportDraftProvider({ ...env, AI_KILL_SWITCH: value }, ctx);
      expect(r.provider?.kind, JSON.stringify(value)).toBe("model");
    }
  });

  it("staging is recognised only by the exact host, not by a substring of the URL", () => {
    const notStaging = [
      "https://qpmdryxkktbqqkqpsnkj.supabase.co.evil.example",
      "https://evil.example/qpmdryxkktbqqkqpsnkj.supabase.co",
      "https://evil.example/?ref=qpmdryxkktbqqkqpsnkj",
      "https://xqpmdryxkktbqqkqpsnkj.supabase.co",
      "http://qpmdryxkktbqqkqpsnkj.supabase.co",
      "not a url",
      "",
    ];
    for (const url of notStaging) {
      const r = resolveReportDraftProvider({ ...env, NEXT_PUBLIC_SUPABASE_URL: url }, ctx);
      expect(r.provider?.kind, url).toBe("rule");
      expect(r.modelBlocked, url).toBe("not_staging");
    }
    const ok = resolveReportDraftProvider({ ...env, NEXT_PUBLIC_SUPABASE_URL: "https://qpmdryxkktbqqkqpsnkj.supabase.co/" }, ctx);
    expect(ok.provider?.kind).toBe("model");
  });

  it("any mention of the live project still blocks first", () => {
    const r = resolveReportDraftProvider(
      { ...env, NEXT_PUBLIC_SUPABASE_URL: "https://qpmdryxkktbqqkqpsnkj.supabase.co/?x=jwmfxrmougneeceldhsa" },
      ctx,
    );
    expect(r.modelBlocked).toBe("live_project");
  });
});
