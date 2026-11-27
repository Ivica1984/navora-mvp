import { describe, expect, it } from "vitest";
import { takeBlocksLine } from "@/features/field/heading";

// HD-3s-F2 (brief docs/agents/briefs/HD-3s-F2.md scope 3 and criterion «Unit: Anzeige beider Blöcke»; ADR-229 (3)).
// The /field card of a block of a two-block take names its block AND both blocks, never only one. Presentation only;
// the text comes from public.field_visits (take_block, take_blocks; migration 0184). Written before the code (red first).

const BOTH = "07:00 – 11:30 und 16:00 – 20:00";

describe("takeBlocksLine (HD-3s-F2 /field)", () => {
  it("block 1 names its part and both blocks", () => {
    expect(takeBlocksLine(1, BOTH)).toBe("Teil 1 von 2 · Geteilter Dienst 07:00 – 11:30 und 16:00 – 20:00");
  });

  it("block 2 names its part and both blocks (never only its own block)", () => {
    const line = takeBlocksLine(2, BOTH);
    expect(line).toBe("Teil 2 von 2 · Geteilter Dienst 07:00 – 11:30 und 16:00 – 20:00");
    expect(line).toContain("07:00 – 11:30");
    expect(line).toContain("16:00 – 20:00");
  });

  it("a one-block take or a visit not from a take has no line", () => {
    expect(takeBlocksLine(null, null)).toBeNull();
    expect(takeBlocksLine(undefined, undefined)).toBeNull();
  });

  it("fails closed: a block number without both blocks, or an unknown block number, shows no partial line", () => {
    expect(takeBlocksLine(1, null)).toBeNull();
    expect(takeBlocksLine(2, "")).toBeNull();
    expect(takeBlocksLine(3, BOTH)).toBeNull();
    expect(takeBlocksLine(null, BOTH)).toBeNull();
  });
});
