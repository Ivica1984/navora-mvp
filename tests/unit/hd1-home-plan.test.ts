import { describe, expect, it } from "vitest";
import {
  addDays, assignableStaff, cellStatusText, daysBetween, gapsPerDay, isIsoDate, isoWeek, messageText, monthCode, monthEnd,
  personPlan, plannedHours, rangeFor, requirementText, safeReturnPath, weekStart, withMessage, type Plan, type PlanCell,
} from "@/features/home-plan/rules";

// HD-1 / HD-2: the pure rules of /heim. The database decides every status; these only order and word it.

const cell = (over: Partial<PlanCell>): PlanCell => ({
  date: "2026-11-25", station_id: "s1", shift_type_id: "f", required_total: 3, required_grade: "nurse_hf_fh",
  required_grade_count: 1, example: false, assigned: [], present: 0, grade_present: 0, missing: 3, status: "gap", ...over,
});

const plan: Plan = {
  institution: { id: "i", display_name: "Testheim", simulation: true, role: "planner" },
  from: "2026-11-23",
  to: "2026-11-29",
  stations: [{ id: "s1", name: "Rhein 2" }],
  shift_types: [
    { id: "f", code: "F", label: "Früh", starts_at: "07:00", ends_at: "15:30" },
    { id: "n", code: "N", label: "Nacht", starts_at: "22:30", ends_at: "07:15" },
  ],
  staff: [
    { id: "a", display_name: "Anna Muster", grade: "nurse_hf_fh", home_station_id: "s1", active: true },
    { id: "b", display_name: "Ben Beispiel", grade: "fage_efz", home_station_id: "s1", active: true },
    { id: "c", display_name: "Carla Test", grade: "fage_efz", home_station_id: null, active: true },
    { id: "d", display_name: "David Probe", grade: "ags_eba", home_station_id: null, active: false },
  ],
  absences: [{ id: "x", staff_id: "c", starts_on: "2026-11-25", ends_on: "2026-11-26" }],
  cells: [
    cell({
      assigned: [
        { assignment_id: "1", staff_id: "a", display_name: "Anna Muster", grade: "nurse_hf_fh", absent: false },
        { assignment_id: "2", staff_id: "c", display_name: "Carla Test", grade: "fage_efz", absent: true },
      ],
      present: 1, grade_present: 1, missing: 2,
    }),
    cell({ shift_type_id: "n", required_total: null, required_grade: null, required_grade_count: 0, status: "no_rule", missing: 0 }),
    cell({ date: "2026-11-24", shift_type_id: "n", required_total: 1, required_grade: null, required_grade_count: 0, status: "ok",
      assigned: [{ assignment_id: "3", staff_id: "b", display_name: "Ben Beispiel", grade: "fage_efz", absent: false }],
      present: 1, missing: 0 }),
  ],
};

describe("HD-1 dates", () => {
  it("week starts on Monday and the month has its real length", () => {
    expect(weekStart("2026-11-25")).toBe("2026-11-23");
    expect(weekStart("2026-11-29")).toBe("2026-11-23");
    expect(weekStart("2026-11-23")).toBe("2026-11-23");
    expect(monthEnd("2026-02-10")).toBe("2026-02-28");
    expect(monthEnd("2028-02-10")).toBe("2028-02-29");
    expect(rangeFor("woche", "2026-11-25")).toEqual({ from: "2026-11-23", to: "2026-11-29" });
    expect(rangeFor("monat", "2026-11-25")).toEqual({ from: "2026-11-01", to: "2026-11-30" });
    expect(daysBetween("2026-12-30", "2027-01-02")).toEqual(["2026-12-30", "2026-12-31", "2027-01-01", "2027-01-02"]);
    expect(addDays("2026-03-28", 2)).toBe("2026-03-30"); // across the DST change: calendar dates, no clock
  });

  it("ISO week numbers", () => {
    expect(isoWeek("2026-11-23")).toBe(48);
    expect(isoWeek("2027-01-01")).toBe(53);
    expect(isoWeek("2026-01-01")).toBe(1);
  });

  it("refuses non-dates", () => {
    expect(isIsoDate("2026-02-30")).toBe(false);
    expect(isIsoDate("2026-11-25")).toBe(true);
    expect(isIsoDate("x")).toBe(false);
  });
});

describe("HD-2 status words", () => {
  it("names the gap and the missing grade", () => {
    expect(cellStatusText(plan.cells[0])).toBe("1 von 3 · Lücke: 2 fehlt");
    expect(cellStatusText(cell({ present: 3, grade_present: 0, missing: 0 }))).toBe("3 von 3 · Lücke: 1 HF fehlt");
    expect(cellStatusText(cell({ present: 3, grade_present: 1, missing: 0, status: "ok" }))).toBe("3 von 3 · besetzt");
  });

  it("never invents a requirement", () => {
    expect(cellStatusText(plan.cells[1])).toBe("keine Vorgabe");
    expect(requirementText(plan.cells[1])).toBe("keine Vorgabe");
    expect(requirementText(plan.cells[0])).toBe("Vorgabe 3, davon 1 HF");
  });
});

describe("HD-2 plan per person", () => {
  it("assignable: active, not absent, not already in a shift that day", () => {
    expect(assignableStaff(plan, "2026-11-25").map((s) => s.id)).toEqual(["b"]);
    expect(assignableStaff(plan, "2026-11-24").map((s) => s.id)).toEqual(["a", "c"]);
  });

  it("the person's days come from the same cells as the week", () => {
    const carla = personPlan(plan, "c");
    expect(carla.find((d) => d.date === "2026-11-25")).toMatchObject({ absent: true, shifts: [{ code: "F", station: "Rhein 2" }] });
    expect(monthCode(carla.find((d) => d.date === "2026-11-25")!)).toBe("A (F)");
    expect(monthCode(carla.find((d) => d.date === "2026-11-26")!)).toBe("A");
    expect(monthCode(personPlan(plan, "b").find((d) => d.date === "2026-11-24")!)).toBe("N");
    expect(monthCode(personPlan(plan, "b").find((d) => d.date === "2026-11-25")!)).toBe("");
  });

  it("planned hours count shift length, night across midnight, not while absent", () => {
    expect(plannedHours(plan, "a")).toBe(8.5);
    expect(plannedHours(plan, "b")).toBe(8.8); // 22:30–07:15 = 8 h 45 min
    expect(plannedHours(plan, "c")).toBe(0);
  });

  it("gaps per day", () => {
    expect(gapsPerDay(plan).get("2026-11-25")).toBe(1);
    expect(gapsPerDay(plan).get("2026-11-24")).toBeUndefined();
  });
});

describe("HD-1 commands: return path and messages", () => {
  it("returns only to /heim (no open redirect)", () => {
    expect(safeReturnPath("/heim?ansicht=monat")).toBe("/heim?ansicht=monat");
    expect(safeReturnPath("/heim")).toBe("/heim");
    expect(safeReturnPath("https://evil.example/heim")).toBe("/heim");
    expect(safeReturnPath("//evil.example")).toBe("/heim");
    expect(safeReturnPath("/heimat")).toBe("/heim");
    expect(safeReturnPath("/order")).toBe("/heim");
    expect(safeReturnPath(null)).toBe("/heim");
    expect(withMessage("/heim?ansicht=woche&meldung=old", "assigned")).toBe("/heim?ansicht=woche&meldung=assigned");
  });

  it("words every result code the database returns", () => {
    for (const code of ["rejected", "staff_absent", "staff_overlap", "already_assigned", "staff_inactive", "absence_overlaps",
      "not_simulation", "not_empty", "input_not_valid", "name_exists", "dates_not_valid", "not_found", "failed"]) {
      expect(messageText(code)?.kind, code).toBe("error");
    }
    expect(messageText("assigned")).toEqual({ kind: "ok", text: "Eingeteilt." });
    expect(messageText("whatever")).toBeNull();
  });
});
