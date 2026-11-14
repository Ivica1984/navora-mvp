"use server";

// B1.1-1 (ADR-186): Operations maps a legacy region value to a list entry by hand. The database checks the role
// (admin or Operations of the organisation), writes the audit row and rewrites the region text of the rows.
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import type { CommandResult } from "@/lib/commands/result";
import { errorFields, logEvent } from "@/lib/log";
import { mapRegionResultText } from "./rules";

const schema = z.object({
  organizationId: z.uuid(),
  legacyValue: z.string().min(1).max(200),
  regionId: z.uuid(),
  idempotencyKey: z.uuid(),
});

export async function mapLegacyRegion(input: unknown): Promise<CommandResult> {
  const p = schema.safeParse(input);
  if (!p.success) return { ok: false, error: "Bitte eine Region aus der Liste wählen." };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("map_legacy_region", {
    p_organization_id: p.data.organizationId,
    p_legacy_value: p.data.legacyValue,
    p_region_id: p.data.regionId,
    p_idempotency_key: p.data.idempotencyKey,
  });
  if (error) {
    logEvent("warn", "command.failed", { op: "map_legacy_region", ...errorFields(error) });
    return { ok: false, error: "Speichern fehlgeschlagen." };
  }
  if (data === "ok" || data === "duplicate") {
    revalidatePath("/operations");
    revalidatePath("/intake");
    revalidatePath("/admin");
    return { ok: true };
  }
  return { ok: false, error: mapRegionResultText(String(data)) };
}
