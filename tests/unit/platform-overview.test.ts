import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { parsePlatformOverview, platformTotals } from "@/features/platform/rules";
import { homePathFor } from "@/features/orders/rules";

// PLATFORM1 (ADR-213): NAVORA operations sees counts per organisation only (Blueprint V3.2 §2.4, §3.3).
const ROW = {
  organization_id: "00000000-0000-4000-b000-000000000019",
  organization_name: "Testorganisation S",
  simulation: true,
  teams: 1,
  members: 3,
  client_accounts: 1,
  orders_upcoming: 4,
  orders_covered: 2,
  orders_waiting: 1,
  orders_not_covered: 1,
};

describe("parsePlatformOverview", () => {
  it("keeps the count columns", () => {
    expect(parsePlatformOverview([ROW])).toEqual([ROW]);
  });
  it("drops any column outside the count list (no person, address, care content or money reaches the screen)", () => {
    const [row] = parsePlatformOverview([{ ...ROW, address: "x", amount_chf: 100, display_name: "y" }]);
    expect(Object.keys(row).sort()).toEqual(Object.keys(ROW).sort());
  });
  it("drops a malformed row and fails closed on a non-array", () => {
    expect(parsePlatformOverview([{ ...ROW, teams: "1" }])).toEqual([]);
    expect(parsePlatformOverview(null)).toEqual([]);
    expect(parsePlatformOverview({})).toEqual([]);
  });
});

describe("platformTotals", () => {
  it("sums every count over the organisations", () => {
    const t = platformTotals([ROW, { ...ROW, organization_id: "b", teams: 2, orders_not_covered: 3 }]);
    expect(t).toEqual({ organizations: 2, teams: 3, members: 6, client_accounts: 2, orders_upcoming: 8,
      orders_covered: 4, orders_waiting: 2, orders_not_covered: 4 });
  });
  it("is all zero for no rows", () => {
    expect(platformTotals([]).organizations).toBe(0);
  });
});

describe("home path", () => {
  it("NAVORA operations without an organisation role lands on /platform", () => {
    expect(homePathFor([], false, true)).toBe("/platform");
  });
  it("an organisation role wins over the operator flag; a client stays on /order", () => {
    expect(homePathFor(["nurse"], false, true)).toBe("/field");
    expect(homePathFor([], true, false)).toBe("/order");
    expect(homePathFor([], false, false)).toBe("/operations");
  });
});

describe("migration 0151 (read model)", () => {
  const sql = readFileSync("supabase/migrations/20261021000151_platform1_operator_counts.sql", "utf8");
  it("returns no money, address or name-of-person column", () => {
    const returns = /returns table \(([^)]*)\)/i.exec(sql.slice(sql.indexOf("function public.platform_overview")))![1];
    expect(returns).not.toMatch(/amount|chf|price|fee|revenue|address|street|display_name|email|note|text_content/i);
  });
  it("grants nothing to anon and keeps the operator table private", () => {
    expect(sql).toMatch(/revoke all on private\.platform_operators from public, anon, authenticated/);
    expect(sql).toMatch(/revoke all on function public\.platform_overview\(\) from public, anon/);
    expect(sql).not.toMatch(/grant [^;]* on private\.platform_operators/i);
  });
});
