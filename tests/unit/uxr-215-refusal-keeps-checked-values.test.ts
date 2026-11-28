import { describe, expect, it } from "vitest";
import { orderProblemsAfterChange } from "@/features/orders/rules";

// UXR-215 (`uxa` 2026-11-14 15:51, UX_REVIEW.md; DESIGN_SYSTEM.md §5 «A refusal keeps the values it was checked
// against», PROPOSED). Written before the code (red first: `orderProblemsAfterChange` does not exist on BK-b2 head
// 1dde2d8). `level_activity_conflict` sits at the activities field but names the level, so changing the level must
// drop it as well; the next «Weiter» checks everything again (nothing is sent before the summary).

describe("UXR-215: a changed value drops every problem that names it", () => {
  const shown = ["missing_start_time", "level_activity_conflict", "tag_unknown"];

  it("changing the level drops the level-against-activity refusal, and only the level's own other problems", () => {
    expect(orderProblemsAfterChange(shown, "grade")).toEqual(["missing_start_time", "tag_unknown"]);
    expect(orderProblemsAfterChange(["missing_grade", "level_activity_conflict"], "grade")).toEqual([]);
  });

  it("changing the activities drops all activity problems, the refusal included", () => {
    expect(orderProblemsAfterChange(shown, "tags")).toEqual(["missing_start_time"]);
  });

  it("changing an unrelated field keeps the refusal", () => {
    expect(orderProblemsAfterChange(shown, "startTime")).toEqual(["level_activity_conflict", "tag_unknown"]);
    expect(orderProblemsAfterChange(shown, "radius")).toEqual(shown);
  });

  it("keeps form-level problems and unknown codes (never dropped by a field change)", () => {
    expect(orderProblemsAfterChange(["not_client", "some_future_code", "level_activity_conflict"], "grade")).toEqual([
      "not_client",
      "some_future_code",
    ]);
  });

  it("no field (a key without a field) changes nothing", () => {
    expect(orderProblemsAfterChange(shown, undefined)).toEqual(shown);
  });
});
