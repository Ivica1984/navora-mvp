import { describe, expect, it } from "vitest";
import {
  busyFromOrderLines,
  freeDayOffset,
  orderDaysFromLines,
  SMOKE_EMAILS,
  smokeAccounts,
  smokeDayOffsets,
  smokePath3Slot,
  stagingTarget,
} from "../staging-smoke/target";

const minuteOf = (t: string) => Number(t.slice(0, 2)) * 60 + Number(t.slice(3, 5));
const busyInterval = (s: { from: string; to: string }): [number, number] => [minuteOf(s.from), minuteOf(s.to)];

// ADR-205: where the staging smoke may run, with which accounts, on which days. Guards, not a skip: every refusal throws.
const PW = { STAGING_SMOKE_PW_KUNDEBS: "a", STAGING_SMOKE_PW_PFLEGEBS: "b", STAGING_SMOKE_PW_PFLEGE: "c" };

describe("stagingTarget", () => {
  it("defaults to the staging host", () => {
    expect(stagingTarget({})).toBe("https://navora-staging.onrender.com");
    expect(stagingTarget({ STAGING_SMOKE_BASE_URL: "  " })).toBe("https://navora-staging.onrender.com");
    expect(stagingTarget({ STAGING_SMOKE_BASE_URL: "https://navora-staging.onrender.com/login" })).toBe(
      "https://navora-staging.onrender.com",
    );
  });
  it.each([
    ["http://navora-staging.onrender.com", /only https/],
    ["https://navora.onrender.com", /not a staging host/],
    ["https://navora-staging.onrender.com.evil.example", /not a staging host/],
    ["http://127.0.0.1:3000", /only https/],
    ["https://jwmfxrmougneeceldhsa.supabase.co", /live project/],
    ["https://u:p@navora-staging.onrender.com", /no credentials/],
    ["not a url", /not a URL/],
  ])("refuses %s", (url, why) => {
    expect(() => stagingTarget({ STAGING_SMOKE_BASE_URL: url })).toThrow(why);
  });
});

describe("smokeAccounts", () => {
  it("pairs the seed e-mails with the three secrets", () => {
    const a = smokeAccounts({ ...PW, STAGING_SMOKE_PW_PFLEGE: " c " });
    expect(a.kunde).toEqual({ email: SMOKE_EMAILS.kunde, password: "a" });
    expect(a.pflegeBs).toEqual({ email: "pflegebs.test@navora.test", password: "b" });
    expect(a.pflegeNord).toEqual({ email: "pflege.test@navora.test", password: "c" });
  });
  it("fails, naming only the missing variables, never a value", () => {
    let message = "";
    try {
      smokeAccounts({ STAGING_SMOKE_PW_KUNDEBS: "secret-value", STAGING_SMOKE_PW_PFLEGE: "" });
    } catch (e) {
      message = (e as Error).message;
    }
    expect(message).toBe("staging-smoke: missing secrets STAGING_SMOKE_PW_PFLEGEBS, STAGING_SMOKE_PW_PFLEGE");
    expect(message).not.toContain("secret-value");
  });
});

describe("smokeDayOffsets", () => {
  it("keeps clear of the CI e2e days (30–37) and the day and night ranges never meet", () => {
    for (let n = 0; n < 200; n++) {
      const { day, night } = smokeDayOffsets(n);
      expect(day).toBeGreaterThanOrEqual(40);
      expect(day).toBeLessThanOrEqual(69);
      expect(night).toBeGreaterThanOrEqual(75);
      expect(night).toBeLessThanOrEqual(104);
    }
  });
  it("gives 30 consecutive runs 30 different days", () => {
    const days = new Set(Array.from({ length: 30 }, (_, i) => smokeDayOffsets(1000 + i).day));
    expect(days.size).toBe(30);
  });
  it("treats a missing or odd run number as run 0", () => {
    expect(smokeDayOffsets(Number.NaN)).toEqual({ day: 40, night: 75 });
    expect(smokeDayOffsets(-3)).toEqual({ day: 40, night: 75 });
  });
});

describe("smokePath3Slot", () => {
  // 2026-11-20 17:53 and 17:58 Zurich (CET, UTC+1): the two push-triggered runs of staging-smoke 44776130634 and
  // 44777149305 reached path 3 about this far apart.
  const at = (hh: number, mm: number) => Date.UTC(2026, 10, 20, hh - 1, mm);
  it("gives two runs a few minutes apart different shifts (staging-smoke 44777149305)", () => {
    const a = smokePath3Slot(at(17, 53), []);
    const b = smokePath3Slot(at(17, 58), []);
    expect(a.from).not.toBe(b.from);
    expect(a.to).not.toBe(b.to);
  });
  it("gives every minute of the day its own start", () => {
    const starts = new Set(Array.from({ length: 60 }, (_, i) => smokePath3Slot(at(10, 0) + i * 60_000, []).from));
    expect(starts.size).toBe(60);
  });
  it("starts 20 minutes after the current minute, lasts 10 minutes, today in Zurich", () => {
    expect(smokePath3Slot(at(17, 53) + 59_000, [])).toEqual({ day: "2026-11-20", from: "18:13", to: "18:23" });
  });
  // STAB1-F3 root cause (raw data, staging 2026-11-20): the run on f7dfd2d0 did not find a second card at all. Its order
  // 2c718c3c (18:20–18:30) got NO offer: order_exclusions «no_member_available» for Testteam Basel, because the demo
  // nurse held the live take of the earlier run's order b42c7fb3 for the same slot (order_member_step step 3, the
  // overlap rule CGR-224). A start that is merely different is not enough: the slot must not OVERLAP an earlier slot.
  it("gives a run 4 minutes after another a slot that does not overlap the earlier one (STAB1-F3)", () => {
    const first = smokePath3Slot(at(17, 54), []);
    const busy = [busyInterval(first)];
    const second = smokePath3Slot(at(17, 58), busy);
    expect(minuteOf(second.from)).toBeGreaterThanOrEqual(minuteOf(first.to));
  });
  it("skips every busy interval of today, also back to back and crossing midnight", () => {
    const busy: Array<[number, number]> = [[18 * 60 + 14, 18 * 60 + 24], [18 * 60 + 24, 18 * 60 + 34], [22 * 60, 24 * 60]];
    expect(smokePath3Slot(at(17, 54), busy)).toEqual({ day: "2026-11-20", from: "18:34", to: "18:44" });
    expect(smokePath3Slot(at(17, 20), busy)).toEqual({ day: "2026-11-20", from: "17:40", to: "17:50" });
    expect(() => smokePath3Slot(at(21, 45), busy)).toThrow(/no free 10-minute slot/);
  });
  it("reads busy intervals of today from the client's order sentences (client_orders, request_title)", () => {
    const lines = [
      "Schichtauftrag · HF · Fr 20.11.2026 18:20 – Fr 20.11.2026 18:30 (0 Std. 10 Min.) · 4051 Basel",
      "Schichtauftrag · HF · Do 19.11.2026 22:00 – Fr 20.11.2026 07:00 (9 Std.) · 4051 Basel",
      "Schichtauftrag · HF · Fr 20.11.2026 22:00 – Sa 21.11.2026 07:00 (9 Std.) · 4051 Basel",
      "Schichtauftrag · HF · Sa 21.11.2026 07:00 – Sa 21.11.2026 15:00 (8 Std.) · 4051 Basel",
      "Gedeckt · Testteam Basel",
    ];
    expect(busyFromOrderLines(lines, "2026-11-20")).toEqual([[1100, 1110], [0, 420], [1320, 1440]]);
  });
  it("refuses outside 00:30–23:20 Zurich", () => {
    expect(() => smokePath3Slot(at(0, 29), [])).toThrow(/between 00:30 and 23:20/);
    expect(() => smokePath3Slot(at(23, 21), [])).toThrow(/between 00:30 and 23:20/);
    expect(smokePath3Slot(at(0, 30), []).from).toBe("00:50");
    expect(smokePath3Slot(at(23, 20), [])).toEqual({ day: "2026-11-20", from: "23:40", to: "23:50" });
  });
});

describe("freeDayOffset / orderDaysFromLines (#1642)", () => {
  // 2026-11-21 04:43 Zurich: staging-smoke 44858240792 attempt 2 (run number 27, offset 67 = 27.01.2027 like attempt 1).
  const now = Date.UTC(2026, 10, 21, 3, 43);
  const attempt1 = "Schichtauftrag · HF · Mi 27.01.2027 07:00 – Mi 27.01.2027 15:30 (8.5 Std.) · 4051 Basel";
  const night = "Schichtauftrag · HF · Do 04.03.2027 22:00 – Fr 05.03.2027 07:00 (9 Std.) · 4051 Basel";

  it("reproduces the re-run collision: the run-number offset lands on attempt 1's day, the free day moves past it", () => {
    const start = 40 + (27 % 30);
    const used = orderDaysFromLines([attempt1]);
    expect(used.has("2027-01-27")).toBe(true);
    expect(freeDayOffset(now, start, 40, 69, new Set())).toBe(67); // the old behaviour: day of attempt 1
    expect(freeDayOffset(now, start, 40, 69, used)).toBe(68);
  });
  it("reads every day of a span, so a night blocks both of its days", () => {
    expect([...orderDaysFromLines([night])]).toEqual(["2027-03-04", "2027-03-05"]);
    expect(orderDaysFromLines(["Auftrag ohne Zeitraum", ""]).size).toBe(0);
  });
  it("needs all days of a night free and wraps inside the range", () => {
    const used = new Set(["2027-03-05"]); // offset 104 is 2027-03-05
    expect(freeDayOffset(now, 103, 75, 104, used, 2)).toBe(75); // 103 needs 103+104, 104 needs 104+105: both touch it
    expect(freeDayOffset(now, 69, 40, 69, new Set([zurich(now, 69)]))).toBe(40);
  });
  it("refuses, never skips, when the whole range is used or the start is outside it", () => {
    const all = new Set(Array.from({ length: 30 }, (_, i) => zurich(now, 40 + i)));
    expect(() => freeDayOffset(now, 50, 40, 69, all)).toThrow(/no free day/);
    expect(() => freeDayOffset(now, 39, 40, 69, new Set())).toThrow(RangeError);
  });
});

function zurich(nowMs: number, offset: number): string {
  return new Date(nowMs + offset * 86_400_000).toLocaleDateString("sv-SE", { timeZone: "Europe/Zurich" });
}
