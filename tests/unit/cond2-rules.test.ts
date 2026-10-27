import { describe, expect, it } from "vitest";
import { readPreparedEndCount } from "@/features/admin/rules";
import { canTakeOver, eventStatusText } from "@/features/quality/rules";
import { TAKE_ENDED } from "@/features/signals/rules";

describe("COND2-1 access-end step count (ADR-101)", () => {
  it("reads the count only from an ok result", () => {
    expect(readPreparedEndCount({ result: "ok", unexported_days: 2 })).toBe(2);
    expect(readPreparedEndCount({ result: "ok", unexported_days: 0 })).toBe(0);
  });

  it("carries no count for any other code or shape", () => {
    for (const result of ["rejected", "self", "unchanged", "duplicate"]) {
      expect(readPreparedEndCount({ result, unexported_days: 3 })).toBeNull();
    }
    expect(readPreparedEndCount({ result: "ok" })).toBeNull();
    expect(readPreparedEndCount({ result: "ok", unexported_days: -1 })).toBeNull();
    expect(readPreparedEndCount(null)).toBeNull();
    expect(readPreparedEndCount(3)).toBeNull();
  });
});

describe("COND2-2 take-over of a lapsed quality claim (ADR-101)", () => {
  it("offers Übernehmen only on an in-review event whose claim has lapsed", () => {
    expect(canTakeOver({ status: "in_review", claim_ended: true })).toBe(true);
    expect(canTakeOver({ status: "in_review", claim_ended: false })).toBe(false);
    expect(canTakeOver({ status: "in_review", claim_ended: null })).toBe(false);
    expect(canTakeOver({ status: "open", claim_ended: true })).toBe(false);
    expect(canTakeOver({ status: "closed", claim_ended: true })).toBe(false);
  });

  it("keeps the lapsed-claim status text (LEAVE1-C4)", () => {
    expect(eventStatusText({ status: "in_review", claim_ended: true })).toBe(TAKE_ENDED);
  });
});
