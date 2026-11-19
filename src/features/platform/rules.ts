// PLATFORM1 (ADR-213): the NAVORA operator cockpit, counts only (Blueprint V3.2 §2.4 «NAVORA-Betrieb»: counts and
// exceptions, never care content or addresses; §3.3: no care revenue of a team). Pure module, unit-tested
// (tests/unit/platform-overview.test.ts).

export type PlatformOrgRow = {
  organization_id: string;
  organization_name: string;
  simulation: boolean;
  teams: number;
  members: number;
  client_accounts: number;
  orders_upcoming: number;
  orders_covered: number;
  orders_waiting: number;
  orders_not_covered: number;
};

const COUNT_KEYS = [
  "teams", "members", "client_accounts", "orders_upcoming", "orders_covered", "orders_waiting", "orders_not_covered",
] as const;

type CountKey = (typeof COUNT_KEYS)[number];

/** Keeps only the known columns of well-formed rows; anything else is dropped (fail closed). */
export function parsePlatformOverview(data: unknown): PlatformOrgRow[] {
  if (!Array.isArray(data)) return [];
  const out: PlatformOrgRow[] = [];
  for (const raw of data) {
    if (!raw || typeof raw !== "object") continue;
    const r = raw as Record<string, unknown>;
    if (typeof r.organization_id !== "string" || typeof r.organization_name !== "string") continue;
    if (typeof r.simulation !== "boolean") continue;
    if (!COUNT_KEYS.every((k) => typeof r[k] === "number" && Number.isInteger(r[k]) && (r[k] as number) >= 0)) continue;
    const row = {
      organization_id: r.organization_id,
      organization_name: r.organization_name,
      simulation: r.simulation,
    } as PlatformOrgRow;
    for (const k of COUNT_KEYS) row[k] = r[k] as number;
    out.push(row);
  }
  return out;
}

export type PlatformTotals = { organizations: number } & Record<CountKey, number>;

export function platformTotals(rows: ReadonlyArray<PlatformOrgRow>): PlatformTotals {
  const t = { organizations: rows.length } as PlatformTotals;
  for (const k of COUNT_KEYS) t[k] = rows.reduce((sum, r) => sum + r[k], 0);
  return t;
}
