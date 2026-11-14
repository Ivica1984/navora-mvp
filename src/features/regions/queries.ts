import "server-only";

import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import { intakeOrganization, type Membership } from "@/features/intake/rules";
import type { Database } from "@/lib/supabase/database.types";
import { regionOptions, type RegionOption, type RegionRow } from "./rules";

type Client = Awaited<ReturnType<typeof requireUser>>["supabase"];

type UnmappedRegionRow = Database["public"]["Functions"]["unmapped_regions"]["Returns"][number];
/**
 * B1.1-1b (ADR-187): the generated type marks every returned column as present; `mapped_region_*` is null for a value
 * that is not mapped yet (left join in unmapped_regions), set for a mapped value whose rows still carry the old text.
 */
export type UnmappedRegion = Omit<UnmappedRegionRow, "mapped_region_id" | "mapped_region_name"> & {
  mapped_region_id: string | null;
  mapped_region_name: string | null;
};

/** B1.1-1 (ADR-186): the organisation's region list for a select field. */
export async function getRegionOptions(supabase: Client, organizationId: string): Promise<{
  options: RegionOption[];
  rows: RegionRow[];
}> {
  const { data, error } = await supabase
    .from("regions")
    .select("id, name, sort_order, active")
    .eq("organization_id", organizationId)
    .order("sort_order");
  if (error) {
    logEvent("error", "regions.load_failed", errorFields(error));
    throw new Error("Regionen konnten nicht geladen werden.");
  }
  const rows = (data ?? []) as RegionRow[];
  return { options: regionOptions(rows), rows };
}

/** B1.1-1: «Region nicht zugeordnet» (empty unless the caller is admin or Operations of the organisation). */
export async function getUnmappedRegions(supabase: Client, organizationId: string): Promise<UnmappedRegion[]> {
  const { data, error } = await supabase.rpc("unmapped_regions", { p_organization_id: organizationId });
  if (error) {
    logEvent("error", "regions.unmapped_failed", errorFields(error));
    throw new Error("Nicht zugeordnete Regionen konnten nicht geladen werden.");
  }
  return (data ?? []) as UnmappedRegion[];
}

export type UnmappedRegionPanel = { organizationId: string; rows: UnmappedRegion[]; regions: RegionRow[] };

/** B1.1-1: data for «Region nicht zugeordnet» on /operations; null when the caller has no admin or Operations role. */
export async function getUnmappedRegionPanel(): Promise<UnmappedRegionPanel | null> {
  const { supabase } = await requireUser();
  const { data: memberships, error } = await supabase.from("organization_memberships").select("organization_id, role");
  if (error) {
    logEvent("error", "regions.memberships_failed", errorFields(error));
    throw new Error("Zugriffsrechte konnten nicht geladen werden.");
  }
  const organizationId = intakeOrganization((memberships ?? []) as Membership[]);
  if (!organizationId) return null;
  const [rows, { rows: regions }] = await Promise.all([
    getUnmappedRegions(supabase, organizationId),
    getRegionOptions(supabase, organizationId),
  ]);
  return { organizationId, rows, regions: regions.filter((r) => r.active) };
}
