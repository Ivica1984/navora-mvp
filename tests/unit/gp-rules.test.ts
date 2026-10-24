import { describe, expect, it } from "vitest";
import {
  GP_CHANNELS,
  GP_CHANNEL_LABEL,
  gpInformedEntryLine,
  gpInformedText,
  informedOnProblem,
  isGpChannel,
  latestNoticeByCase,
} from "@/features/gp/rules";
import { ENTRY_TITLE, entryLines } from "@/features/handover/rules";

// ORD0 (migration 0061, ADR-075): labels and form pre-checks for "Hausärztin/Hausarzt informiert". The database decides
// (pgTAP 063); these helpers only label.
describe("ORD0: doctor informed", () => {
  it("ORD0-1: offers exactly the four fixed channel codes of the database, each with a label", () => {
    expect([...GP_CHANNELS]).toEqual(["elektronisch", "brief", "telefon", "persoenlich"]);
    for (const c of GP_CHANNELS) expect(GP_CHANNEL_LABEL[c]).toBeTruthy();
    expect(isGpChannel("telefon")).toBe(true);
    expect(isGpChannel("fax")).toBe(false);
    expect(isGpChannel(null)).toBe(false);
  });

  it("ORD0-3: the case card reads 'informiert am <Datum> (<Kanal>)'", () => {
    expect(gpInformedText({ informed_on: "2026-10-12", channel: "telefon" })).toBe(
      "Hausärztin/Hausarzt informiert am 12.10.2026 (Telefon)",
    );
    expect(gpInformedText({ informed_on: "2026-10-01", channel: "persoenlich" })).toContain("(Persönlich)");
  });

  it("ORD0-3: HAND1 lists the record as an entry with date and channel, nothing else", () => {
    expect(ENTRY_TITLE.gp_informed).toBe("Hausärztin/Hausarzt informiert");
    expect(entryLines("gp_informed", { informed_on: "2026-10-12", channel: "brief" })).toEqual(["am 12.10.2026 (Brief)"]);
    expect(gpInformedEntryLine({})).toBeNull();
  });

  it("keeps the newest record per case", () => {
    const m = latestNoticeByCase([
      { case_id: "a", informed_on: "2026-10-01", channel: "brief", recorded_at: "2026-10-02T08:00:00Z" },
      { case_id: "a", informed_on: "2026-10-05", channel: "telefon", recorded_at: "2026-10-06T08:00:00Z" },
      { case_id: "b", informed_on: "2026-10-03", channel: "elektronisch", recorded_at: "2026-10-03T08:00:00Z" },
    ]);
    expect(m.get("a")?.channel).toBe("telefon");
    expect(m.get("b")?.channel).toBe("elektronisch");
  });

  it("pre-checks the date like the server: not in the future (the case lower bound is checked by the server)", () => {
    expect(informedOnProblem("2026-10-24", "2026-10-24")).toBeNull();
    expect(informedOnProblem("2026-10-20", "2026-10-24")).toBeNull();
    expect(informedOnProblem("2026-10-25", "2026-10-24")).toBe("future");
    expect(informedOnProblem("", "2026-10-24")).toBe("missing");
  });
});
