"use server";

// J5: create billable facts for final reports without an open hold (idempotent; migration 0022).

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";

export async function generateBillableFacts(input: unknown): Promise<{ ok: true; created: number } | { ok: false; error: string }> {
  const parsed = z.object({ month: z.iso.date() }).safeParse(input);
  if (!parsed.success) return { ok: false, error: "Ungültiger Monat." };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("generate_billable_facts", { p_month: parsed.data.month });
  if (error) {
    logEvent("warn", "command.failed", { op: "generate_billable_facts", ...errorFields(error) });
    return { ok: false, error: "Abrechnungsfakten konnten nicht erzeugt werden." };
  }
  revalidatePath("/team");
  revalidatePath("/operations");
  return { ok: true, created: data ?? 0 };
}
