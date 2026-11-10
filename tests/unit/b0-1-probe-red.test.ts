// B0-1 negative case PROBE (ADR-178). Deliberately red. This file lives only on the probe branch
// `probe/b0-1-negative-20261110` and must never reach recovery/main; the probe PR is closed unmerged.
import { describe, expect, it } from "vitest";

describe("B0-1 probe", () => {
  it("is deliberately red so the merge-commit run must report red", () => {
    expect("B0-1 probe red").toBe("green");
  });
});
