import { describe, expect, it } from "vitest";
import { NAV_ITEMS, PAGE_LABEL, admits, menuItemsFor, navItemsFor, type NavAccess } from "@/lib/auth/nav";
import { EMPTY_ORDER_FORM, orderFieldsFrom, type OrderFormState } from "@/features/orders/rules";

// BK amendment 2026-11-14 00:39 (1)(a), (1)(b) (brief docs/agents/briefs/BK.md). Written before the code (red first).
//
// UXR-198: the client's menu has a destination for /order; a team member without a client account does not see it.
// UXR-199: after «Bestätigen & Absenden» the form starts empty, so pressing on through it again cannot build a second
// complete order from the same input (the database preview then names every missing field and blocks the confirm).

const hrefs = (access: NavAccess) => menuItemsFor(access).map((i) => i.href);

describe("UXR-198: /order in the client's menu", () => {
  it("has one item for /order, labelled with the page's own heading", () => {
    const items = NAV_ITEMS.filter((i) => i.href === "/order");
    expect(items).toHaveLength(1);
    expect(items[0].label).toBe(PAGE_LABEL.order);
    expect(PAGE_LABEL.order).toBe("Auftrag erfassen");
    expect(items[0].check).toEqual({ kind: "client_account" });
  });

  it("a client-only user (no organisation role) sees «Auftrag erfassen» and «Meine Einstellungen»", () => {
    expect(hrefs({ roles: [], inTeam: false, clientAccount: true })).toEqual(["/order", "/settings"]);
  });

  it("a team member without a client account does not see /order, whatever her role", () => {
    for (const roles of [["nurse"], ["coach"], ["operations"], ["admin"]]) {
      expect(hrefs({ roles, inTeam: true }), roles.join()).not.toContain("/order");
      expect(hrefs({ roles, inTeam: true, clientAccount: false }), roles.join()).not.toContain("/order");
    }
  });

  it("fails closed: an unknown or failed client-account read admits no /order", () => {
    expect(admits({ kind: "client_account" }, { roles: [], inTeam: false })).toBe(false);
    expect(navItemsFor({ roles: [], inTeam: false })).toEqual([]);
  });
});

const FULL: OrderFormState = {
  dateWords: "22.11.2026",
  picked: null,
  startTime: "22:00",
  endTime: "07:00",
  postcode: "4102",
  grade: "fage_efz",
  tags: ["vital_signs", "wound_care"],
  required: ["wound_care", "not_selected"],
  radius: "7,5",
};

describe("UXR-199: one press, one order", () => {
  it("the form state after a confirmed order is empty", () => {
    expect(EMPTY_ORDER_FORM).toEqual({
      dateWords: "", picked: null, startTime: "", endTime: "", postcode: "", grade: "", tags: [], required: [], radius: "",
    });
  });

  it("an empty form builds no field of an order: every required field is missing, nothing defaulted", () => {
    expect(orderFieldsFrom(EMPTY_ORDER_FORM, "acc-1", "2026-11-18")).toEqual({
      clientAccountId: "acc-1",
      startDate: null,
      startTime: null,
      endTime: null,
      postcode: null,
      grade: null,
      activityTags: [],
      requiredTags: [],
      radiusKm: null,
    });
  });

  it("a filled form builds the fields as before (required only among the chosen tags, comma radius)", () => {
    expect(orderFieldsFrom(FULL, "acc-1", "2026-11-18")).toEqual({
      clientAccountId: "acc-1",
      startDate: "2026-11-22",
      startTime: "22:00",
      endTime: "07:00",
      postcode: "4102",
      grade: "fage_efz",
      activityTags: ["vital_signs", "wound_care"],
      requiredTags: ["wound_care"],
      radiusKm: 7.5,
    });
  });

  it("an ambiguous date word gives a date only with a picked candidate (AUT-120 unchanged)", () => {
    const sunday = { ...FULL, dateWords: "Sonntag" };
    expect(orderFieldsFrom(sunday, "acc-1", "2026-11-15").startDate).toBeNull();
    expect(orderFieldsFrom({ ...sunday, picked: "2026-11-22" }, "acc-1", "2026-11-15").startDate).toBe("2026-11-22");
    expect(orderFieldsFrom({ ...sunday, picked: "2026-11-29" }, "acc-1", "2026-11-15").startDate).toBeNull();
  });
});
