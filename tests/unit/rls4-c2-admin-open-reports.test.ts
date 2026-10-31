import { readFileSync } from "node:fs";
import { beforeEach, describe, expect, it, vi } from "vitest";

/**
 * RLS4-C2 (po 2026-10-30 07:20, `lca` 06:41 D-23; ADR-122 addendum): /admin no longer loads `member_open_reports` for
 * every member on page load. Her open reports are read for one member when the administrator opens the access-end step
 * (`readMemberOpenReports`), as COND1-5a does for her unexported-days count. Recording fake client, synthetic rows only.
 */

const rpcCalls: { name: string; args: unknown }[] = [];
let rpcError: { code: string; message: string } | null = null;

const ORG = "00000000-0000-4000-b000-0000000000aa";
const MEMBER_A = "00000000-0000-4000-a000-0000000000a1";
const MEMBER_B = "00000000-0000-4000-a000-0000000000a2";

function rowsFor(table: string): unknown[] {
  if (table === "organization_memberships") return [{ organization_id: ORG, role: "admin" }];
  return [];
}

/** A chainable query: every builder method returns the chain, awaiting it yields the table's rows. */
function chain(table: string) {
  const result = { data: rowsFor(table), error: null };
  const c: Record<string, unknown> = {};
  for (const m of ["select", "eq", "is", "order", "limit"]) c[m] = () => c;
  c.then = (resolve: (v: unknown) => unknown) => resolve(result);
  return c;
}

function rpcResult(name: string): unknown {
  if (name === "admin_members") {
    return [
      { user_id: MEMBER_A, email: "a@navora.test", display_name: "Synthetisch A", role: "nurse", teams: [] },
      { user_id: MEMBER_B, email: "b@navora.test", display_name: "Synthetisch B", role: "nurse", teams: [] },
    ];
  }
  if (name === "member_open_reports") return [{ kind: "unsigned", visit_date: "2026-10-29", team_name: "Testteam", extra: "x" }];
  return [];
}

const fakeClient = {
  from: (table: string) => chain(table),
  rpc(name: string, args: unknown) {
    rpcCalls.push({ name, args });
    if (rpcError && name === "member_open_reports") return Promise.resolve({ data: null, error: rpcError });
    return Promise.resolve({ data: rpcResult(name), error: null });
  },
};

vi.mock("server-only", () => ({}));
vi.mock("next/cache", () => ({ revalidatePath: () => undefined }));
vi.mock("@/lib/auth/session", () => ({ requireUser: async () => ({ supabase: fakeClient }) }));
vi.mock("@/lib/log", () => ({ logEvent: () => undefined, errorFields: () => ({}) }));

beforeEach(() => {
  rpcCalls.length = 0;
  rpcError = null;
});

describe("RLS4-C2 (1): loading /admin reads no member's open reports", () => {
  it("getAdminData issues no member_open_reports call for any member", async () => {
    const { getAdminData } = await import("@/features/admin/queries");
    const data = await getAdminData();
    expect(data?.members.map((m) => m.user_id)).toEqual([MEMBER_A, MEMBER_B]);
    expect(rpcCalls.map((c) => c.name)).not.toContain("member_open_reports");
  });

  it("the admin data carries no per-member open-report list", async () => {
    const { getAdminData } = await import("@/features/admin/queries");
    const data = await getAdminData();
    expect(data).not.toBeNull();
    expect(Object.keys(data ?? {})).not.toContain("openReports");
    expect(JSON.stringify(data)).not.toContain("unsigned");
  });
});

describe("RLS4-C2 (1): the access-end step reads one member's open reports", () => {
  it("readMemberOpenReports calls member_open_reports once, for that member only, and returns kind, date and team", async () => {
    const { readMemberOpenReports } = await import("@/features/admin/commands");
    const rows = await readMemberOpenReports({ userId: MEMBER_B });
    expect(rpcCalls).toEqual([{ name: "member_open_reports", args: { p_user_id: MEMBER_B } }]);
    expect(rows).toEqual([{ kind: "unsigned", visit_date: "2026-10-29", team_name: "Testteam" }]);
  });

  it("an invalid id reads nothing; a database error returns null (shown as not loaded, never as none)", async () => {
    const { readMemberOpenReports } = await import("@/features/admin/commands");
    expect(await readMemberOpenReports({ userId: "not-a-uuid" })).toBeNull();
    expect(rpcCalls).toEqual([]);
    rpcError = { code: "42501", message: "synthetic" };
    expect(await readMemberOpenReports({ userId: MEMBER_A })).toBeNull();
  });
});

describe("RLS4-C2 (1), (4): where the read happens and what the code says", () => {
  const client = readFileSync("src/app/(protected)/admin/admin-client.tsx", "utf8");
  const queries = readFileSync("src/features/admin/queries.ts", "utf8");

  it("the /admin client reads open reports only in the end step (openEnd) and no longer from the page data", () => {
    expect(client).not.toMatch(/data\.openReports/);
    const calls = client.split("readMemberOpenReports(").length - 1;
    expect(calls).toBe(1);
    const openEnd = client.slice(client.indexOf("const openEnd = () => {"), client.indexOf("};", client.indexOf("const openEnd = () => {")));
    expect(openEnd).toContain('setMode("end")');
    expect(openEnd).toContain("readMemberOpenReports(");
  });

  it("the end step waits for the list before the end can be confirmed", () => {
    expect(client).toContain('disabled={pending || (mode === "end" && open === "loading")}');
  });

  it("the old comment that did not match the code is gone, and queries.ts does not call member_open_reports", () => {
    expect(queries).not.toContain("listed before an access end");
    expect(queries).not.toContain('rpc("member_open_reports"');
  });
});
