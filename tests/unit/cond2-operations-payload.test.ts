import { beforeEach, describe, expect, it, vi } from "vitest";

/**
 * COND2-3 (= IPA1-C1, ADR-101): the /operations dashboard neither reads nor serialises care_visits.
 * The page shows no visit list since IPA1 (ADR-099); the visit rows carried the nurse's name.
 * The test runs getOperationsDashboard against a recording fake client (synthetic rows only).
 */

const tablesRead: string[] = [];
const rpcsCalled: string[] = [];

function result(data: unknown) {
  return { data, error: null };
}

function fakeSelect(table: string) {
  const rows: Record<string, unknown[]> = {
    cases: [{ id: "case-synthetic-1" }],
    teams: [{ id: "team-synthetic-1", name: "Team Test" }],
    care_visits: [{ id: "visit-synthetic-1", team_member_name: "Synthetische Pflegende" }],
  };
  return {
    select: () => ({
      order: () => Promise.resolve(result(rows[table] ?? [])),
    }),
  };
}

const fakeClient = {
  from(table: string) {
    tablesRead.push(table);
    return fakeSelect(table);
  },
  rpc(name: string) {
    rpcsCalled.push(name);
    return Promise.resolve(result(name === "operations_exceptions" ? [{ exception_type: "visit_uncovered" }] : null));
  },
};

vi.mock("server-only", () => ({}));
vi.mock("@/lib/auth/session", () => ({
  requireUser: async () => ({ supabase: fakeClient }),
}));
vi.mock("@/lib/log", () => ({
  logEvent: () => undefined,
  errorFields: () => ({}),
}));

describe("COND2-3 /operations payload", () => {
  beforeEach(() => {
    tablesRead.length = 0;
    rpcsCalled.length = 0;
  });

  it("has no visits key and does not read care_visits", async () => {
    const { getOperationsDashboard } = await import("@/features/operations/queries");
    const dashboard = await getOperationsDashboard();

    expect(Object.keys(dashboard).sort()).toEqual(["cases", "exceptions", "teams"]);
    expect(dashboard).not.toHaveProperty("visits");
    expect(tablesRead).not.toContain("care_visits");
    expect(JSON.stringify(dashboard)).not.toContain("Synthetische Pflegende");
  });

  it("keeps the OPS1 exception read and its sync unchanged", async () => {
    const { getOperationsDashboard } = await import("@/features/operations/queries");
    const dashboard = await getOperationsDashboard();

    expect(rpcsCalled).toEqual(["sync_exceptions", "operations_exceptions"]);
    expect(dashboard.exceptions).toEqual([{ exception_type: "visit_uncovered" }]);
    expect(tablesRead.sort()).toEqual(["cases", "teams"]);
  });
});
