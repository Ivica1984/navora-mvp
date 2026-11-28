import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { CLAUDE_MAX_OUTPUT_TOKENS } from "@/lib/ai/report-draft/anthropic-provider";
import { MAX_INPUT_CHARS, MAX_MODEL_INPUT_CHARS } from "@/lib/ai/report-draft/segment";

/**
 * AI1 (ADR-227 points 1, 6): the reserve in the database must cover the longest answer the app can ask for, so a call
 * can never cost more output tokens than were reserved. The app cap and the 0166 limits row are one value.
 */
describe("AI1 limits: app and database agree", () => {
  const migration = readFileSync("supabase/migrations/20261021000166_ai1_call_budget_switch.sql", "utf8");

  it("max_output_tokens of the shipped limits row equals the provider's max_tokens", () => {
    const row = /values \('report_draft_model', (\d+), (\d+), (\d+), (\d+)\)/.exec(migration);
    expect(row, "limits row in 0166").not.toBeNull();
    const [, day, month, reserveIn, maxOut] = row!.map(Number);
    expect(maxOut).toBe(CLAUDE_MAX_OUTPUT_TOKENS);
    expect(day).toBe(300); // brief §5
    expect(month).toBe(50_000_000); // CHF 50 in micro-CHF, founder FE-099 (7) (2)
    expect(reserveIn).toBeGreaterThanOrEqual(MAX_MODEL_INPUT_CHARS); // estimate: at most one token per character plus prompt
  });

  it("the model input limit is below the rule draft's and nothing is cut (4000 vs 8000)", () => {
    expect(MAX_MODEL_INPUT_CHARS).toBe(4000);
    expect(MAX_INPUT_CHARS).toBe(8000);
  });

  it("the price ships empty (fail closed until a reviewed reading)", () => {
    expect(migration).not.toMatch(/price_in_micro_chf_per_mtok\s*=\s*\d/);
    expect(migration).toMatch(/insert into private\.ai_function_limits \(function_key, day_calls, month_cap_micro_chf, reserve_input_tokens, max_output_tokens\)/);
  });
});
