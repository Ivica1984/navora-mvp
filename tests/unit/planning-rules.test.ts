import { describe, expect, it } from "vitest";
import { describeSchedule, orderNotice, scheduleError } from "@/features/planning/rules";

// PLAN2: client-side mirror of set_care_plan_schedule (migration 0025); the database stays the authority.
describe("planning rules (PLAN2)", () => {
  it("describes a schedule in the team's words", () => {
    expect(describeSchedule({ freq_times: 1, freq_period: "day", freq_weekdays: null, window_start: "08:00:00", window_end: "09:00:00" }))
      .toBe("täglich 08:00–09:00");
    expect(describeSchedule({ freq_times: 2, freq_period: "week", freq_weekdays: [1, 4], window_start: "08:00", window_end: "08:30" }))
      .toBe("2× pro Woche (Mo, Do) 08:00–08:30");
    expect(describeSchedule({ freq_times: 3, freq_period: "week", freq_weekdays: null, window_start: "14:00", window_end: "15:00" }))
      .toBe("3× pro Woche 14:00–15:00");
    expect(describeSchedule({ freq_times: null, freq_period: null, freq_weekdays: null, window_start: null, window_end: null })).toBeNull();
  });

  it("checks the frequency like the database", () => {
    expect(scheduleError("day", 1, [], "08:00", "09:00")).toBeNull();
    expect(scheduleError("day", 1, [1], "08:00", "09:00")).not.toBeNull();
    expect(scheduleError("week", 2, [1, 4], "08:00", "09:00")).toBeNull();
    expect(scheduleError("week", 2, [], "08:00", "09:00")).toBeNull();
    expect(scheduleError("week", 2, [1, 3, 5], "08:00", "09:00")).toContain("Genau 2");
    expect(scheduleError("week", 8, [], "08:00", "09:00")).not.toBeNull();
    expect(scheduleError("week", 1, [], "09:00", "08:00")).toContain("Ende nach Beginn");
  });

  it("says why B work stops when the order ends inside the four weeks (PO addendum)", () => {
    const items = [{ category: "B", freq_period: "week" }, { category: "A", freq_period: "day" }];
    expect(orderNotice("2026-11-02", items, "2026-10-22")).toBe("B-Leistungen geplant bis 02.11.2026: Verordnung erneuern");
    expect(orderNotice("2027-01-30", items, "2026-10-22")).toBeNull();
    expect(orderNotice("2026-11-02", [{ category: "A", freq_period: "day" }], "2026-10-22")).toBeNull();
    expect(orderNotice(null, items, "2026-10-22")).toBeNull();
  });
});
