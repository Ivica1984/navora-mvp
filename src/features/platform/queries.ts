import "server-only";

// PLATFORM1 (ADR-213): data for /platform. One definer read model that returns rows only to NAVORA operations.
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import { parsePlatformOverview, type PlatformOrgRow } from "./rules";

export type PlatformPage = { operator: boolean; rows: PlatformOrgRow[] };

export async function getPlatformPage(): Promise<PlatformPage> {
  const { supabase } = await requireUser();
  const { data: operator, error: opError } = await supabase.rpc("am_platform_operator");
  if (opError) {
    logEvent("warn", "platform.operator_failed", errorFields(opError));
    return { operator: false, rows: [] };
  }
  if (operator !== true) return { operator: false, rows: [] };
  const { data, error } = await supabase.rpc("platform_overview");
  if (error) {
    logEvent("warn", "platform.overview_failed", errorFields(error));
    return { operator: true, rows: [] };
  }
  return { operator: true, rows: parsePlatformOverview(data) };
}
