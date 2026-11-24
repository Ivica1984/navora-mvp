// BK-e2 Abschlusspaket (ADR-216): the /field side of the report-draft ledger fails closed. Synthetic data only.
import { describe, expect, it } from "vitest";
import type { ReportAssist } from "@/features/field/report-assist";
import { attachSuggestions, ledgerGate, ledgerLines, ledgerOutcome } from "@/features/field/report-ledger";

const assist = (n: number): ReportAssist => ({
  origin: "model",
  label: "KI-Entwurf (Claude), synthetische Daten",
  sourceText: { s1: "Klientin wach.", s2: "Verband gewechselt." },
  context: ["Einsatz 07:02–07:48"],
  lines: Array.from({ length: n }, (_, i) => ({ text: `Zeile ${i}`, sources: [`s${i + 1}`], decision: "open" as const })),
  unplaced: [],
});
const id = (i: number) => `a2160000-0000-4000-8000-00000000000${i}`;

describe("ledgerGate (AUT-138: MODEL_LEDGER_READY comes only from the database gate)", () => {
  it("is ready only on an explicit open answer", () => {
    expect(ledgerGate({ data: { result: "ok", open: true, reason: null }, error: null })).toEqual({ ready: true });
  });
  it("keeps the database reason when closed (no threshold row, stop rule, not a simulation)", () => {
    for (const reason of ["no_threshold", "stop_rule", "not_simulation_org", "not_performer", "not_draft", "not_team_member", "prompt_unregistered"]) {
      expect(ledgerGate({ data: { result: "ok", open: false, reason }, error: null })).toEqual({ ready: false, reason });
    }
  });
  it("fails closed on an error, a missing answer, a truthy non-boolean or an unknown reason", () => {
    const closed = { ready: false, reason: "ledger_missing" };
    expect(ledgerGate({ data: null, error: { message: "boom" } })).toEqual(closed);
    expect(ledgerGate({ data: { result: "ok", open: true }, error: { message: "x" } })).toEqual(closed);
    expect(ledgerGate({ data: null, error: null })).toEqual(closed);
    expect(ledgerGate({ data: { result: "ok", open: "true" }, error: null })).toEqual(closed);
    expect(ledgerGate({ data: { result: "ok", open: false, reason: "whatever" }, error: null })).toEqual(closed);
  });
});

describe("attachSuggestions (no model line on screen without its ledger row)", () => {
  it("puts one ledger id on each decision line, in line order", () => {
    const res = { data: { result: "ok", lines: [{ line_index: 1, suggestion_id: id(2) }, { line_index: 0, suggestion_id: id(1) }] }, error: null };
    const a = attachSuggestions(assist(2), res);
    expect(a?.lines.map((l) => l.suggestionId)).toEqual([id(1), id(2)]);
  });
  it("accepts the idempotent repeat of the same key", () => {
    const res = { data: { result: "duplicate", lines: [{ line_index: 0, suggestion_id: id(1) }] }, error: null };
    expect(attachSuggestions(assist(1), res)?.lines[0].suggestionId).toBe(id(1));
  });
  it("returns null (fall back to the rule substitute) on a refusal, an error or a missing or extra id", () => {
    const one = [{ line_index: 0, suggestion_id: id(1) }];
    expect(attachSuggestions(assist(1), { data: { result: "rejected", reason: "stop_rule" }, error: null })).toBeNull();
    expect(attachSuggestions(assist(1), { data: { result: "ok", lines: one }, error: { message: "x" } })).toBeNull();
    expect(attachSuggestions(assist(2), { data: { result: "ok", lines: one }, error: null })).toBeNull();
    expect(attachSuggestions(assist(1), { data: { result: "ok", lines: [...one, { line_index: 1, suggestion_id: id(2) }] }, error: null })).toBeNull();
    expect(attachSuggestions(assist(1), { data: { result: "ok", lines: [{ line_index: 3, suggestion_id: id(1) }] }, error: null })).toBeNull();
  });
});

describe("ledgerLines and ledgerOutcome", () => {
  it("records only the decision lines with text and sources; fact context is not a model value", () => {
    expect(ledgerLines(assist(2))).toEqual([
      { text: "Zeile 0", sources: ["s1"] },
      { text: "Zeile 1", sources: ["s2"] },
    ]);
  });
  it("maps «Übernehmen» to confirmed and «Verwerfen» to rejected; re-opening writes nothing", () => {
    expect(ledgerOutcome("taken")).toBe("confirmed");
    expect(ledgerOutcome("dropped")).toBe("rejected");
    expect(ledgerOutcome("open")).toBeNull();
  });
});
