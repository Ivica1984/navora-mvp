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

// HD-2: the reference lists for the review screen (the same lists /order reads) and the preview through the one
// order path (`institution_preview_gap_order` → `preview_client_order`). Writes nothing.
export type OrderChoices = {
  postcodes: Array<{ postcode: string; place_name: string; region_name: string }>;
  activities: Array<{ code: string; label_de: string }>;
};

export async function getOrderChoices(): Promise<OrderChoices> {
  const { supabase } = await requireUser();
  const [postcodes, activities] = await Promise.all([
    supabase.from("postcodes").select("postcode, place_name, region_name").order("postcode"),
    supabase.from("qual_activities").select("code, label_de").order("sort"),
  ]);
  if (postcodes.error || activities.error) {
    logEvent("warn", "query.failed", { op: "order_choices", ...errorFields((postcodes.error ?? activities.error)!) });
    return { postcodes: [], activities: [] };
  }
  return { postcodes: (postcodes.data ?? []) as OrderChoices["postcodes"], activities: (activities.data ?? []) as OrderChoices["activities"] };
}

export type GapPreview = { result: string; problems?: string[]; preview?: { problems?: string[]; sentence?: string | null; conflict_activities?: string[]; info?: string[] } };

export async function previewGapOrder(args: {
  gap: string; postcode: string | null; grade: string | null; tags: string[]; req: string[];
}): Promise<GapPreview | null> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("institution_preview_gap_order" as never, {
    p_gap_order_id: args.gap, p_postcode: args.postcode, p_grade: args.grade, p_activity_tags: args.tags,
    p_required_tags: args.req, p_radius_km: null,
  } as never);
  if (error) {
    logEvent("warn", "query.failed", { op: "institution_preview_gap_order", ...errorFields(error) });
    return null;
  }
  return (data ?? null) as GapPreview | null;
}
