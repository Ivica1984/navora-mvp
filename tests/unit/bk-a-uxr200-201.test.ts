import { describe, expect, it } from "vitest";
import {
  ORDER_FORM_FIELDS,
  ORDER_PROBLEM_CODES,
  dateUnknownShown,
  orderFieldControlId,
  orderFieldProblemId,
  orderProblemField,
  orderProblemsByField,
  orderStepAfterPreview,
  resolveOrderDate,
} from "@/features/orders/rules";

// BK amendment 2026-11-14 00:39 (1)(c), (1)(d) (brief docs/agents/briefs/BK.md; ADR-194 addendum 03:15).
// Written before the code (red first: none of the imported helpers existed on #1246 head c1eeaa4).
//
// UXR-200: a problem returned by the database preview is shown at its field (aria-invalid, aria-describedby), and the
// form stays: the summary opens only with zero problems (DESIGN_SYSTEM §2, PROPOSED by `uxa` 23:48).
// UXR-201: «Datum nicht erkannt» is shown (and announced) only after the client left the date field, never while typing.

describe("UXR-200: every problem has a field (or is a form-level problem)", () => {
  it("each preview code except not_client belongs to exactly one form field", () => {
    for (const code of ORDER_PROBLEM_CODES) {
      const field = orderProblemField(code);
      if (code === "not_client") expect(field, code).toBeNull();
      else expect(ORDER_FORM_FIELDS, code).toContain(field);
    }
  });

  it("maps the codes to the field the client has to change", () => {
    expect(orderProblemField("missing_start_date")).toBe("date");
    expect(orderProblemField("starts_in_past")).toBe("date");
    expect(orderProblemField("missing_start_time")).toBe("startTime");
    expect(orderProblemField("missing_end_time")).toBe("endTime");
    expect(orderProblemField("end_equals_start")).toBe("endTime");
    expect(orderProblemField("missing_postcode")).toBe("postcode");
    expect(orderProblemField("postcode_not_in_list")).toBe("postcode");
    expect(orderProblemField("postcode_outside_regions")).toBe("postcode");
    expect(orderProblemField("missing_grade")).toBe("grade");
    expect(orderProblemField("grade_unknown")).toBe("grade");
    expect(orderProblemField("missing_activity_tags")).toBe("tags");
    expect(orderProblemField("tag_unknown")).toBe("tags");
    expect(orderProblemField("required_tag_not_in_tags")).toBe("tags");
    expect(orderProblemField("radius_not_positive")).toBe("radius");
  });

  it("an unknown code is a form-level problem, never dropped", () => {
    expect(orderProblemField("something_new")).toBeNull();
    const grouped = orderProblemsByField(["something_new", "missing_postcode"]);
    expect(grouped.form).toEqual(["something_new"]);
    expect(grouped.byField.postcode).toEqual(["missing_postcode"]);
  });

  it("groups the codes per field in the order the database returned them", () => {
    const grouped = orderProblemsByField(["missing_start_date", "missing_end_time", "end_equals_start", "not_client"]);
    expect(grouped.byField.date).toEqual(["missing_start_date"]);
    expect(grouped.byField.endTime).toEqual(["missing_end_time", "end_equals_start"]);
    expect(grouped.byField.postcode).toBeUndefined();
    expect(grouped.form).toEqual(["not_client"]);
  });

  it("gives each field a stable control id and problem id, all distinct", () => {
    const ids = ORDER_FORM_FIELDS.flatMap((f) => [orderFieldControlId(f), orderFieldProblemId(f)]);
    expect(new Set(ids).size).toBe(ids.length);
    expect(orderFieldControlId("postcode")).toBe("order-field-postcode");
    expect(orderFieldProblemId("postcode")).toBe("order-field-postcode-problem");
  });

  it("opens the summary only when the preview found no problem", () => {
    expect(orderStepAfterPreview([])).toBe("summary");
    expect(orderStepAfterPreview(["missing_grade"])).toBe("form");
    expect(orderStepAfterPreview(["not_client"])).toBe("form");
  });
});

describe("UXR-201: «Datum nicht erkannt» only after leaving the field", () => {
  const today = "2026-11-18";

  it("is not shown while typing a weekday letter by letter", () => {
    for (const partial of ["S", "So", "Son", "Sonnt"]) {
      expect(resolveOrderDate(partial, today).kind, partial).toBe("unknown");
      expect(dateUnknownShown(resolveOrderDate(partial, today), false), partial).toBe(false);
    }
  });

  it("is shown once the client left the field with words that admit no date", () => {
    expect(dateUnknownShown(resolveOrderDate("Son", today), true)).toBe(true);
    expect(dateUnknownShown(resolveOrderDate("31.02.2026", today), true)).toBe(true);
  });

  it("is never shown for a recognised, ambiguous or empty entry", () => {
    expect(dateUnknownShown(resolveOrderDate("Sonntag", today), true)).toBe(false);
    expect(dateUnknownShown(resolveOrderDate("Mittwoch", today), true)).toBe(false);
    expect(dateUnknownShown(resolveOrderDate("", today), true)).toBe(false);
  });
});
