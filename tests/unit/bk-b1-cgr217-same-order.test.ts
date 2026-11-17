import { describe, expect, it } from "vitest";
import { ORDER_INFO_CODES, orderInfoText } from "@/features/orders/rules";

// BK-b1 (PO amendment 2026-11-14 01:39 (4), 09:39 (2)): CGR-217. Written before the code (red first).
// The preview returns `info` (never a problem) when the same client account already holds a confirmed order with the
// same start, end, level and postcode; the summary names it in `uxa`'s words (UX_REVIEW 03:47, PROPOSED) and the
// confirm stays enabled. `cra` 05:26: «zwei Pflegekräfte» is true only while one order means one person.

describe("CGR-217: the same order twice is an information item", () => {
  it("knows exactly the one info code of the database preview", () => {
    expect(ORDER_INFO_CODES).toEqual(["same_order_already_confirmed"]);
  });

  it("words the item with the sentence of the order already confirmed", () => {
    expect(orderInfoText("same_order_already_confirmed", "Schichtauftrag · FaGe · So 22.11.2026 22:00 – Mo 23.11.2026 07:00 (9 Std.) · 4102 Binningen")).toBe(
      "Hinweis: Für dieses Konto ist bereits ein Auftrag mit gleichem Beginn, Ende, Stufe und Ort bestätigt " +
        "(Schichtauftrag · FaGe · So 22.11.2026 22:00 – Mo 23.11.2026 07:00 (9 Std.) · 4102 Binningen). " +
        "Ein zweiter Auftrag bedeutet zwei Pflegekräfte für diese Zeit. Wenn das so gemeint ist, bestätigen Sie ihn.",
    );
  });

  it("drops the bracket when the earlier sentence is missing, never invents one", () => {
    expect(orderInfoText("same_order_already_confirmed", null)).toBe(
      "Hinweis: Für dieses Konto ist bereits ein Auftrag mit gleichem Beginn, Ende, Stufe und Ort bestätigt. " +
        "Ein zweiter Auftrag bedeutet zwei Pflegekräfte für diese Zeit. Wenn das so gemeint ist, bestätigen Sie ihn.",
    );
  });

  it("shows nothing for an unknown code (an information item is never guessed)", () => {
    expect(orderInfoText("something_else", "x")).toBeNull();
  });
});
