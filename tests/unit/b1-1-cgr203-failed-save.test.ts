import { beforeEach, describe, expect, it, vi } from "vitest";

/**
 * CGR-203 (ADR-188; brief B1.1 §PO 09:40 point 2): when «Fall eröffnen» and «Zuordnen» of the same legacy region
 * deadlock, PostgreSQL rolls one of them back whole with SQLSTATE 40P01 (shown in two real sessions by
 * scripts/db-concurrency/region-map-convert-race.sh). The user must see a failed save, never a success, and no page is
 * revalidated as if something had been saved. Synthetic ids only; the fake client returns the database error.
 */

const DEADLOCK = { code: "40P01", message: "deadlock detected" };
const revalidated: string[] = [];
let rpcError: { code: string; message: string } | null = DEADLOCK;

const fakeClient = {
  rpc() {
    return Promise.resolve({ data: null, error: rpcError });
  },
};

vi.mock("server-only", () => ({}));
vi.mock("next/cache", () => ({ revalidatePath: (p: string) => revalidated.push(p) }));
vi.mock("@/lib/auth/session", () => ({ requireUser: async () => ({ supabase: fakeClient }) }));
vi.mock("@/lib/log", () => ({ logEvent: () => undefined, errorFields: () => ({}) }));

const ID = (n: number) => `b2030000-0000-4000-8000-0000000000${String(n).padStart(2, "0")}`;

describe("CGR-203: a deadlock (40P01) is shown as a failed save", () => {
  beforeEach(() => {
    revalidated.length = 0;
    rpcError = DEADLOCK;
  });

  it("«Fall eröffnen» (convert_partner_request) returns «Speichern fehlgeschlagen.» and revalidates nothing", async () => {
    const { convertPartnerRequest } = await import("@/features/intake/commands");
    const res = await convertPartnerRequest({
      requestId: ID(1),
      firstName: "Klient",
      lastName: "Wettlauf",
      consentConfirmed: true,
      facts: {},
      idempotencyKey: ID(2),
    });
    expect(res).toEqual({ ok: false, error: "Speichern fehlgeschlagen." });
    expect(revalidated).toEqual([]);
  });

  it("«Zuordnen» (map_legacy_region) returns «Speichern fehlgeschlagen.» and revalidates nothing", async () => {
    const { mapLegacyRegion } = await import("@/features/regions/commands");
    const res = await mapLegacyRegion({
      organizationId: ID(3),
      legacyValue: "Wettlauf B203",
      regionId: ID(4),
      idempotencyKey: ID(5),
    });
    expect(res).toEqual({ ok: false, error: "Speichern fehlgeschlagen." });
    expect(revalidated).toEqual([]);
  });
});
