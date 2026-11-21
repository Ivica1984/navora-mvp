import { describe, expect, it } from "vitest";
import {
  canMoveToToday,
  fieldActions,
  fieldActionsOn,
  formatShortDate,
  futureDayNote,
  isAfterToday,
} from "@/features/field/rules";
import { NOT_TODAY_MESSAGE, STARTED_BEFORE_DATE_MESSAGE, toCommandResult } from "@/lib/commands/result";
import { LIFECYCLE_MESSAGES } from "@/features/lifecycle/rules";

// VIS1 (ADR-111, `cra` CGR-87): field actions happen on the visit's day.
const TODAY = "2026-10-28";

describe("VIS1 field rules", () => {
  it("a visit dated after today shows no field action, in every status", () => {
    for (const status of ["planned", "on_the_way", "started", "paused"]) {
      expect(fieldActionsOn(status, "2026-10-29", TODAY)).toEqual([]);
      expect(fieldActionsOn(status, "2026-11-04", TODAY)).toEqual([]);
    }
  });

  it("today and earlier days keep the unchanged actions (VIS1-6)", () => {
    for (const status of ["planned", "on_the_way", "started", "paused", "completed", null]) {
      expect(fieldActionsOn(status, TODAY, TODAY)).toEqual(fieldActions(status));
      expect(fieldActionsOn(status, "2026-10-27", TODAY)).toEqual(fieldActions(status));
    }
    expect(fieldActionsOn("planned", TODAY, TODAY)).toEqual(["depart", "start"]);
  });

  it("compares calendar dates, with no tolerance before the date", () => {
    expect(isAfterToday("2026-10-29", TODAY)).toBe(true);
    expect(isAfterToday(TODAY, TODAY)).toBe(false);
    expect(isAfterToday("2026-10-27", TODAY)).toBe(false);
    expect(isAfterToday("2027-01-01", "2026-12-31")).toBe(true);
    expect(isAfterToday(null, TODAY)).toBe(false);
  });

  it("offers the move to today only on a planned, not suspended visit dated after today (VIS1-3b)", () => {
    expect(canMoveToToday("planned", false, "2026-10-29", TODAY)).toBe(true);
    expect(canMoveToToday("planned", null, "2026-10-29", TODAY)).toBe(true);
    expect(canMoveToToday("planned", true, "2026-10-29", TODAY)).toBe(false);
    expect(canMoveToToday("on_the_way", false, "2026-10-29", TODAY)).toBe(false);
    expect(canMoveToToday("planned", false, TODAY, TODAY)).toBe(false);
    expect(canMoveToToday("planned", false, "2026-10-27", TODAY)).toBe(false);
  });

  it("says once why and what to do, in the wording of the brief (VIS1-3)", () => {
    expect(formatShortDate("2026-11-04")).toBe("04.11.2026");
    expect(futureDayNote("2026-11-04")).toBe(
      "Der Einsatz ist für den 04.11.2026 geplant. Wenn du ihn heute machst, verschiebe ihn zuerst auf heute.",
    );
  });
});

describe("VIS1 command outcomes (migration 0089)", () => {
  const M = { rejected: "abgelehnt", failed: "fehlgeschlagen" };

  it("maps not_today and started_before_date to their own German sentences, never to success", () => {
    expect(toCommandResult("not_today", null, M)).toEqual({ ok: false, error: NOT_TODAY_MESSAGE });
    expect(toCommandResult("started_before_date", null, M)).toEqual({ ok: false, error: STARTED_BEFORE_DATE_MESSAGE });
    expect(LIFECYCLE_MESSAGES.not_today).toBe(NOT_TODAY_MESSAGE);
  });

  it("shows no internal code to the nurse (UX1-11)", () => {
    for (const text of [NOT_TODAY_MESSAGE, STARTED_BEFORE_DATE_MESSAGE, futureDayNote("2026-11-04")]) {
      expect(text).not.toMatch(/not_today|started_before_date|VIS1|CGR/);
    }
  });
});
