import { describe, expect, it } from "vitest";
import { DAY_CHANGED_RELOAD, MOVED_TO_TODAY_STATUS, afterDayChanged, dayChangedNote } from "@/features/field/rules";

// VIS1-10 (ADR-116; PO brief VIS1-10 as amended 03:10 and 04:10; `cra` CGR-91). Display rules only: the database
// (`move_visit_to_today`, migration 0093, pgTAP 093) decides what today is.

describe("VIS1-10: the sentence after day_changed", () => {
  it("names the weekday and the date in the PO's wording (UXR-39)", () => {
    expect(dayChangedNote("2026-10-29")).toBe(
      "Inzwischen ist Donnerstag, 29.10.2026. Die Zeiten sind neu gesetzt. Prüfe sie und bestätige noch einmal.",
    );
    // The day after the autumn clock change: a calendar date, no time zone involved.
    expect(dayChangedNote("2026-10-26")).toBe(
      "Inzwischen ist Montag, 26.10.2026. Die Zeiten sind neu gesetzt. Prüfe sie und bestätige noch einmal.",
    );
  });

  it("is never the success line and carries no internal code (UX1-11)", () => {
    const text = dayChangedNote("2026-10-29");
    expect(text).not.toContain(MOVED_TO_TODAY_STATUS);
    expect(text).not.toMatch(/day_changed|_/);
    expect(DAY_CHANGED_RELOAD).not.toMatch(/day_changed|_/);
  });
});

describe("VIS1-10: what the confirmation does after day_changed", () => {
  it("offers the confirmation again with the database's today while the visit is still after it", () => {
    expect(afterDayChanged("2026-10-29", "2026-11-03")).toEqual({ kind: "confirm_again", today: "2026-10-29" });
  });

  it("falls back to the reload sentence when the visit is no longer after the new today", () => {
    expect(afterDayChanged("2026-10-29", "2026-10-29")).toEqual({ kind: "reload" });
    expect(afterDayChanged("2026-10-29", "2026-10-28")).toEqual({ kind: "reload" });
  });

  it("falls back to the reload sentence when an answer is missing or malformed (never a guessed date)", () => {
    expect(afterDayChanged("", "2026-11-03")).toEqual({ kind: "reload" });
    expect(afterDayChanged(undefined, "2026-11-03")).toEqual({ kind: "reload" });
    expect(afterDayChanged("2026-02-30", "2026-03-03")).toEqual({ kind: "reload" });
    expect(afterDayChanged("2026-10-29", null)).toEqual({ kind: "reload" });
  });
});
