import "server-only";

// HD-1 / HD-2: data for /heim. The home reads only through its own functions (`my_institutions`, `institution_plan`);
// both check the membership in the database. No NAVORA team, case or member data.
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import type { InstitutionRole, Plan } from "./rules";

export type MyInstitution = { id: string; display_name: string; kind: string; role: InstitutionRole; simulation: boolean };

export async function getMyInstitutions(): Promise<MyInstitution[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("my_institutions" as never);
  if (error) {
    logEvent("warn", "query.failed", { op: "my_institutions", ...errorFields(error) });
    return [];
  }
  return (data ?? []) as unknown as MyInstitution[];
}

export async function getPlan(institutionId: string, from: string, to: string): Promise<Plan | null> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("institution_plan" as never, { p_institution_id: institutionId, p_from: from, p_to: to } as never);
  if (error) {
    logEvent("warn", "query.failed", { op: "institution_plan", ...errorFields(error) });
    return null;
  }
  const r = (data ?? {}) as unknown as { result?: string } & Plan;
  return r.result === "ok" ? r : null;
}
