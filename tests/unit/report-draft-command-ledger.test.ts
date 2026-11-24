import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { reportDraftPromptDigest } from "@/lib/ai/report-draft/prompt-version";

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
const KEY = "a2160000-0000-4000-8000-000000000005";
const RSV = "a2160000-0000-4000-8000-000000000006";

type Rpc = { data: unknown; error: unknown };
let gate: Rpc;
let record: Rpc;
let decide: Rpc;
let reserve: Rpc;
let settle: Rpc;
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
    if (fn === "reserve_report_draft_call") return Promise.resolve(reserve);
    if (fn === "settle_report_draft_call") return Promise.resolve(settle);
    return Promise.resolve({ data: null, error: { message: "unexpected" } });
  },
  from() {
    return { select: () => ({ eq: () => ({ maybeSingle: async () => ({ data: { organizations: { simulation: true } }, error: null }) }) }) };
  },
};

vi.mock("server-only", () => ({}));
vi.mock("@/lib/auth/session", () => ({ requireUser: async () => ({ supabase: fakeClient }) }));
const { logEvent } = vi.hoisted(() => ({ logEvent: vi.fn() }));
vi.mock("@/lib/log", () => ({ logEvent: (...a: unknown[]) => logEvent(...a), errorFields: () => ({}) }));

const claude = vi.fn(async () =>
  new Response(
    JSON.stringify({
      content: [{ type: "text", text: JSON.stringify({ lines: [{ text: "Klientin wach.", sources: ["s1"] }], unplaced: [] }) }],
      stop_reason: "end_turn",
      usage: { input_tokens: 812, output_tokens: 64 },
    }),
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
  reserve = { data: { result: "ok", reservation_id: RSV, attempt: 1 }, error: null };
  settle = { data: { result: "ok", settled_micro_chf: 1, cost_basis: "measured_tokens" }, error: null };
});
afterEach(() => {
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
});

const propose = async (text = "Klientin wach.") =>
  (await import("@/features/field/report-draft-command")).proposeReportDraft({ visitId: VISIT, day: DAY, text, idempotencyKey: KEY });
const called = (fn: string) => calls.filter((c) => c.fn === fn);

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
    // #1697 R7 / AUT-197 (0170): the proposal names the reservation of this call; the database checks it is settled ok.
    expect(rec.args.p_reservation_id).toBe(RSV);
    expect(Object.keys(rec.args).sort()).toEqual(["p_idempotency_key", "p_lines", "p_model", "p_report_id", "p_reservation_id"]);
    expect(rec.args.p_model).toBe("claude-test");
    expect(rec.args.p_lines).toEqual([{ text: "Klientin wach.", sources: ["s1"] }]);
  });

  it("AI1: the call is reserved first with the request key and settled after with outcome, tokens and latency", async () => {
    const r = await propose();
    expect(r.ok).toBe(true);
    const order = calls.map((c) => c.fn).filter((f) => f.endsWith("_report_draft_call"));
    expect(order).toEqual(["reserve_report_draft_call", "settle_report_draft_call"]);
    expect(called("reserve_report_draft_call")[0].args).toEqual({
      p_report_id: REPORT,
      p_idempotency_key: KEY,
      p_prompt_digest: reportDraftPromptDigest(), // AUT-167: the server's prompt digest goes with every reservation
    });
    const st = called("settle_report_draft_call")[0].args;
    expect(st).toMatchObject({ p_reservation_id: RSV, p_outcome: "ok", p_input_tokens: 812, p_output_tokens: 64 });
    expect(st.p_latency_ms).toBeGreaterThanOrEqual(0);
    expect(Object.keys(st).sort()).toEqual(["p_input_tokens", "p_latency_ms", "p_outcome", "p_output_tokens", "p_reservation_id"]);
  });

  it("AI1 T-2: a repeat of the key (double tap) makes no provider call and no second draft", async () => {
    reserve = { data: { result: "duplicate", attempt: 1, settled: false }, error: null };
    const r = await propose();
    expect(r).toEqual({ ok: false, error: "Der Entwurf wird schon erstellt. Bitte einen Moment warten." });
    expect(claude).not.toHaveBeenCalled();
    expect(called("settle_report_draft_call")).toHaveLength(0);
  });

  it("AI1: a third attempt is refused by the database: no call, rule draft, plain notice", async () => {
    reserve = { data: { result: "rejected", reason: "attempt_limit" }, error: null };
    const r = await propose();
    expect(claude).not.toHaveBeenCalled();
    expect(r).toMatchObject({ ok: true, modelBlocked: "attempt_limit", assist: { origin: "rule", label: "regelbasiert, keine KI" } });
    if (r.ok) expect(r.notice).toMatch(/schon zweimal ein KI-Entwurf/);
    expect(called("settle_report_draft_call")).toHaveLength(0);
  });

  it("AI1: caps, missing price, database switch or a failed reservation: no call (fail closed)", async () => {
    for (const res of [
      { data: { result: "rejected", reason: "budget_day" }, error: null },
      { data: { result: "rejected", reason: "budget_month" }, error: null },
      { data: { result: "rejected", reason: "price_missing" }, error: null },
      { data: { result: "rejected", reason: "switched_off" }, error: null },
      { data: { result: "rejected", reason: "prompt_version_mismatch" }, error: null },
      { data: { result: "rejected", reason: "prompt_unregistered" }, error: null },
      { data: { result: "ok" }, error: null },
      { data: null, error: { message: "boom" } },
    ]) {
      reserve = res;
      const r = await propose();
      expect(r, JSON.stringify(res)).toMatchObject({ ok: true, assist: { origin: "rule" } });
      if (r.ok) expect(r.notice).toBe("Der KI-Entwurf ist gerade nicht verfügbar. Hier ist der regelbasierte Entwurf.");
    }
    expect(claude).not.toHaveBeenCalled();
  });

  it("AI1 ADR-227 point 6: notes over 4000 characters are refused for the model before anything is reserved", async () => {
    const r = await propose("Klientin wach. " + "x".repeat(4000));
    expect(called("reserve_report_draft_call")).toHaveLength(0);
    expect(claude).not.toHaveBeenCalled();
    expect(r).toMatchObject({ ok: true, modelBlocked: "too_long_for_model", assist: { origin: "rule" } });
    if (r.ok) expect(r.notice).toMatch(/zu lang für den KI-Entwurf/);
  });

  it("AI1: a failed model call is still settled (counted), with the tokens the API reported", async () => {
    claude.mockImplementationOnce(async () =>
      new Response(JSON.stringify({ content: [{ type: "text", text: "{\"lines\": [" }], stop_reason: "max_tokens", usage: { input_tokens: 900, output_tokens: 1024 } }), {
        status: 200,
      }),
    );
    const r = await propose();
    expect(r).toEqual({ ok: false, error: "Der Entwurf konnte nicht erstellt werden. Du kannst den Bericht wie bisher selbst schreiben." });
    expect(called("settle_report_draft_call")[0].args).toMatchObject({ p_outcome: "max_tokens", p_input_tokens: 900, p_output_tokens: 1024 });
    expect(called("record_report_draft_proposal")).toHaveLength(0);
  });

  it("AI1: a failed settle does not hide the draft (the call stays charged at its reserve)", async () => {
    settle = { data: null, error: { message: "boom" } };
    const r = await propose();
    expect(r).toMatchObject({ ok: true, assist: { origin: "model" } });
  });

  it("AI1 #1697 R4: a bounded settle keeps the draft and logs settle_bounded with the count only (no text)", async () => {
    settle = { data: { result: "ok", settled_micro_chf: 51360, cost_basis: "bounded" }, error: null };
    logEvent.mockClear();
    const r = await propose();
    expect(r).toMatchObject({ ok: true, assist: { origin: "model" } });
    expect(logEvent).toHaveBeenCalledWith("warn", "report_draft.settle_bounded", { op: "report_draft.model", code: "bounded", count: 812 });
    expect(logEvent.mock.calls.some((c) => c[1] === "report_draft.settle_failed")).toBe(false);
  });

  it("AI1 #1697 R4: a measured settle logs no settle_bounded line", async () => {
    logEvent.mockClear();
    await propose();
    expect(logEvent.mock.calls.some((c) => c[1] === "report_draft.settle_bounded")).toBe(false);
  });

  it("AI1: a request without a key is refused before anything", async () => {
    const r = await (await import("@/features/field/report-draft-command")).proposeReportDraft({ visitId: VISIT, day: DAY, text: "A." });
    expect(r.ok).toBe(false);
    expect(calls).toHaveLength(0);
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
    expect(called("reserve_report_draft_call")).toHaveLength(0);
  });

  it("ledger write refused or failed: the model draft is not shown; rule substitute with its own label", async () => {
    record = { data: { result: "rejected", reason: "stop_rule" }, error: null };
    const r = await propose();
    expect(r).toMatchObject({ ok: true, modelBlocked: "ledger_missing", assist: { origin: "rule", label: "regelbasiert, keine KI" } });
    if (r.ok) expect(r.assist.lines.every((l) => l.suggestionId === undefined)).toBe(true);
  });

  it.each(["reservation_missing", "reservation_not_ok", "reservation_used", "reservation_unversioned"])(
    "#1697 R7 (0170): the database refuses the proposal (%s): the model draft is not shown; rule substitute",
    async (reason) => {
      record = { data: { result: "rejected", reason }, error: null };
      const r = await propose();
      expect(r).toMatchObject({ ok: true, modelBlocked: "ledger_missing", assist: { origin: "rule", label: "regelbasiert, keine KI" } });
      if (r.ok) expect(r.assist.lines.every((l) => l.suggestionId === undefined)).toBe(true);
    },
  );
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
