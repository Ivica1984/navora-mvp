import { execFileSync } from "node:child_process";
import { expect, type Page } from "@playwright/test";

/**
 * B1.1-1c (founder decision FE-073): the seed names list regions only (Basel-Stadt, Basel-Landschaft); it writes no
 * legacy region value. A spec that needs «Region nicht zugeordnet» or «Zuordnen» writes its own legacy value with
 * `addLegacyTeamOrgA` and removes it with `removeLegacyTeamOrgA` (brief B1.1 §PO 11:25 point 2).
 *
 * The fixture is written as the table owner on the local Supabase database (synthetic seed only, never a hosted
 * project): the region trigger registers a non-listed value written that way as an unmapped legacy value of the
 * organisation and keeps the text (migration 0127 section 3), as the backfill did for the seed before B1.1-1c.
 * Specs run one at a time (`workers: 1`), so a fixture is never seen by another spec.
 */
const ORG_A = "00000000-0000-4000-b000-000000000011";
const DB_URL = process.env.E2E_DB_URL ?? "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
const LOCAL_DB = /^postgres(ql)?:\/\/[^@]+@(127\.0\.0\.1|localhost):54322\//;

function psql(sql: string): string {
  if (!LOCAL_DB.test(DB_URL)) throw new Error("legacy-region fixture: only the local Supabase database (port 54322)");
  return execFileSync("psql", [DB_URL, "-X", "-q", "-At", "-v", "ON_ERROR_STOP=1", "-c", sql], { encoding: "utf8" }).trim();
}

function literal(v: string): string {
  if (!/^[\p{L}\p{N} .-]+$/u.test(v)) throw new Error(`legacy-region fixture: unexpected text ${JSON.stringify(v)}`);
  return `'${v}'`;
}

/** One building team of org A on a legacy region text (no open slots, so no team search can reach it). */
export function addLegacyTeamOrgA(team: string, legacyValue: string): void {
  removeLegacyTeamOrgA(team, legacyValue);
  psql(`insert into public.teams (organization_id, name, region, care_focus, status, open_slots, utilization)
        values ('${ORG_A}', ${literal(team)}, ${literal(legacyValue)}, 'Ambulante Pflege', 'building', 0, 0)`);
  const registered = psql(`select count(*) from public.region_legacy_values
        where organization_id = '${ORG_A}' and legacy_value = ${literal(legacyValue)} and region_id is null`);
  expect(registered, `«${legacyValue}» is an unmapped legacy value of org A`).toBe("1");
}

/** Removes the fixture team, its legacy row and the audit rows of a mapping of that value. Idempotent. */
export function removeLegacyTeamOrgA(team: string, legacyValue: string): void {
  // Audit rows are append-only for every application path; the fixture cleanup removes its own rows as the table
  // owner with triggers off, like scripts/db-concurrency/region-map-race.sh does. The fixture team has no other rows.
  psql(`set session_replication_role = replica;
        delete from public.audit_events
          where entity_id in (select id from public.teams where organization_id = '${ORG_A}' and name = ${literal(team)})
             or (organization_id = '${ORG_A}' and table_name = 'region_legacy_values'
                 and changed ->> 'from' = ${literal(legacyValue)});
        delete from public.teams where organization_id = '${ORG_A}' and name = ${literal(team)};
        delete from public.region_legacy_values where organization_id = '${ORG_A}' and legacy_value = ${literal(legacyValue)};
        set session_replication_role = origin;`);
}

/**
 * Operations of org A maps `legacyValue` to `listRegion` under «Region nicht zugeordnet» on /operations, through the
 * confirming step (ADR-186 amendment 04:30, uxa UXR-184), as before B1.1-1c with the seed's «Bern West».
 * The caller is signed in as Operations of org A.
 */
export async function mapLegacyRegionOrgA(page: Page, legacyValue: string, listRegion: string): Promise<void> {
  await page.goto("/operations");
  const form = page.getByRole("form", { name: `Region zuordnen: ${legacyValue}` });
  await expect(form).toBeVisible();
  // B1.1-1b UXR-187 (ADR-187): the live region exists, empty, before the act.
  await expect(page.getByTestId("region-mapped")).toHaveCount(1);
  await form.getByLabel("Region aus der Liste").selectOption({ label: listRegion });
  await form.getByRole("button", { name: "Zuordnen" }).click();
  await form.getByTestId("region-map-confirm").getByRole("button", { name: "Zuordnen" }).click();
  await expect(page.getByTestId("region-mapped")).toContainText(`Region zugeordnet: ${legacyValue} → ${listRegion}`);
  await expect(form).toHaveCount(0);
  // UXR-187: the row with the focused button is gone; focus is on the section heading, not on the live region.
  await expect(page.getByRole("heading", { name: /^Region nicht zugeordnet/ })).toBeFocused();
}

/** The region of a new org-A referral that reaches Testteam Nord (seed region since B1.1-1c). */
export const ORG_A_TEAM_REGION = "Basel-Stadt";
