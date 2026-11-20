import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

/**
 * BK-e2 Abschlusspaket (ADR-216): the /field command uses the model only when the database gate is open, shows a model
 * line only with its ledger row, and falls back to the rule substitute (its own label) on any ledger failure. CI never
 * calls a real model: `fetch` is a fake that answers like Claude. Synthetic data only.
 */

const VISIT = "a2160000-0000-4000-8000-000000000001";
const REPORT = "a2160000-0000-4000-8000-000000000002";
const TEAM = "a2160000-0000-4000-8000-000000000003";
const SID = "a2160000-0000-4000-8000-000000000004";
const DAY = "2026-11-19";

type Rpc = { data: unknown; error: unknown };
let gate: Rpc;
let record: Rpc;
let decide: Rpc;
const calls: Array<{ fn: string; args: Record<string, unknown> }> = [];

const fakeClient = {
  rpc(fn: string, args: Record<string, unknown>) {
    calls.push({ fn, args });
    if (fn === "field_reports")
      return Promise.resolve({
        data: [{ visit_id: VISIT, report_id: REPORT, status: "draft", i_am_performer: true, performer_access_ended: false, snapshot: {} }],
        error: null,
      });
    if (fn === "field_visits") return Promise.resolve({ data: [{ visit_id: VISIT, team_id: TEAM }], error: null });
    if (fn === "report_draft_model_gate") return Promise.resolve(gate);
    if (fn === "record_report_draft_proposal") return Promise.resolve(record);
    if (fn === "decide_report_draft_line") return Promise.resolve(decide);
    return Promise.resolve({ data: null, error: { message: "unexpected" } });
  },
  from() {
    return { select: () => ({ eq: () => ({ maybeSingle: async () => ({ data: { organizations: { simulation: true } }, error: null }) }) }) };
  },
};

vi.mock("server-only", () => ({}));
vi.mock("@/lib/auth/session", () => ({ requireUser: async () => ({ supabase: fakeClient }) }));
vi.mock("@/lib/log", () => ({ logEvent: () => undefined, errorFields: () => ({}) }));

const claude = vi.fn(async () =>
  new Response(
    JSON.stringify({ content: [{ type: "text", text: JSON.stringify({ lines: [{ text: "Klientin wach.", sources: ["s1"] }], unplaced: [] }) }] }),
    { status: 200 },
  ),
);

const ENV = {
  AI_REPORT_DRAFT_MODE: "model",
  AI_MODEL_PROVIDER: "anthropic",
  AI_MODEL_API_KEY: "test-key",
  AI_MODEL_NAME: "claude-test",
  NEXT_PUBLIC_SUPABASE_URL: "https://qpmdryxkktbqqkqpsnkj.supabase.co",
  AI_KILL_SWITCH: "off",
};

beforeEach(() => {
  calls.length = 0;
  claude.mockClear();
  for (const [k, v] of Object.entries(ENV)) vi.stubEnv(k, v);
  vi.stubGlobal("fetch", claude);
  gate = { data: { result: "ok", open: true, reason: null }, error: null };
  record = { data: { result: "ok", lines: [{ line_index: 0, suggestion_id: SID }] }, error: null };
  decide = { data: { result: "ok" }, error: null };
});
afterEach(() => {
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
});

const propose = async () => (await import("@/features/field/report-draft-command")).proposeReportDraft({ visitId: VISIT, day: DAY, text: "Klientin wach." });

describe("proposeReportDraft with the ledger (ADR-216)", () => {
  it("gate open: Claude drafts, every decision line is recorded first and carries its ledger id", async () => {
    const r = await propose();
    expect(r.ok).toBe(true);
    if (!r.ok) return;
    expect(r.assist.label).toBe("KI-Entwurf (Claude), synthetische Daten");
    expect(r.assist.lines.map((l) => l.suggestionId)).toEqual([SID]);
    expect(claude).toHaveBeenCalledTimes(1);
    const rec = calls.find((c) => c.fn === "record_report_draft_proposal")!;
    expect(rec.args.p_report_id).toBe(REPORT);
    expect(rec.args.p_model).toBe("claude-test");
    expect(rec.args.p_lines).toEqual([{ text: "Klientin wach.", sources: ["s1"] }]);
  });

  it("no threshold row: no model call, rule substitute, reason named", async () => {
    gate = { data: { result: "ok", open: false, reason: "no_threshold" }, error: null };
    const r = await propose();
    expect(claude).not.toHaveBeenCalled();
    expect(r).toMatchObject({ ok: true, modelBlocked: "no_threshold", assist: { origin: "rule", label: "regelbasiert, keine KI" } });
    expect(calls.some((c) => c.fn === "record_report_draft_proposal")).toBe(false);
  });

  it("stop rule reached or gate error: no model call", async () => {
    gate = { data: { result: "ok", open: false, reason: "stop_rule" }, error: null };
    expect(await propose()).toMatchObject({ ok: true, modelBlocked: "stop_rule", assist: { origin: "rule" } });
    gate = { data: null, error: { message: "boom" } };
    expect(await propose()).toMatchObject({ ok: true, modelBlocked: "ledger_missing", assist: { origin: "rule" } });
    expect(claude).not.toHaveBeenCalled();
  });

  it("kill switch on: no model call even with an open gate", async () => {
    vi.stubEnv("AI_KILL_SWITCH", "on");
    expect(await propose()).toMatchObject({ ok: true, modelBlocked: "kill_switch", assist: { origin: "rule" } });
    expect(claude).not.toHaveBeenCalled();
  });

  it("ledger write refused or failed: the model draft is not shown; rule substitute with its own label", async () => {
    record = { data: { result: "rejected", reason: "stop_rule" }, error: null };
    const r = await propose();
    expect(r).toMatchObject({ ok: true, modelBlocked: "ledger_missing", assist: { origin: "rule", label: "regelbasiert, keine KI" } });
    if (r.ok) expect(r.assist.lines.every((l) => l.suggestionId === undefined)).toBe(true);
  });
});

describe("decideReportDraftLine (one line per call, never bulk)", () => {
  const decideLine = async (decision: string) =>
    (await import("@/features/field/report-draft-command")).decideReportDraftLine({
      suggestionId: SID,
      decision,
      text: "Klientin wach.",
      idempotencyKey: "a2160000-0000-4000-8000-000000000009",
    });

  it("«Übernehmen» writes confirmed with the text; «Verwerfen» writes rejected without text", async () => {
    expect(await decideLine("taken")).toEqual({ ok: true });
    expect(calls.at(-1)).toMatchObject({ fn: "decide_report_draft_line", args: { p_outcome: "confirmed", p_text: "Klientin wach." } });
    expect(await decideLine("dropped")).toEqual({ ok: true });
    expect(calls.at(-1)).toMatchObject({ fn: "decide_report_draft_line", args: { p_outcome: "rejected", p_text: null } });
  });

  it("a refused or failed write is reported, so the line stays open on screen", async () => {
    decide = { data: { result: "rejected", reason: "not_performer" }, error: null };
    expect((await decideLine("taken")).ok).toBe(false);
    decide = { data: null, error: { message: "x" } };
    expect((await decideLine("dropped")).ok).toBe(false);
    expect((await decideLine("open")).ok).toBe(false);
  });
});
