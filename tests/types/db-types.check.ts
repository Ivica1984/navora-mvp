// Compile-time checks for the generated schema types (T14). Never executed —
// `npm run typecheck` (tsc) covers this file. Each @ts-expect-error must
// trigger; if the client silently degraded to `any`, tsc would report the
// directive as unused and fail the build.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/lib/supabase/database.types";
import type { CaseSummaryRow } from "@/features/cases/types";

declare const db: SupabaseClient<Database>;

export async function typeChecks() {
  // A real column set is assignable to the view type.
  const ok = await db.from("cases").select("id, created_at, name, first_name, last_name, region, ort, status, urgency, bedarf, care_needs, assigned_team, assigned_team_id");
  const rows: CaseSummaryRow[] = ok.data ?? [];

  // An unknown column is a compile error.
  const bad = await db.from("cases").select("id, does_not_exist");
  // @ts-expect-error -- selecting a non-existent column must not type-check
  const badRows: { id: string; does_not_exist: string }[] = bad.data ?? [];

  // An unknown table is a compile error.
  // @ts-expect-error -- table does not exist
  await db.from("not_a_table").select("id");

  // RPC arguments are checked.
  // @ts-expect-error -- p_idempotency_key is required
  await db.rpc("start_visit", { p_visit_id: "00000000-0000-4000-a000-000000000501" });

  // RPC result is a string code.
  const res = await db.rpc("start_visit", { p_visit_id: "x", p_idempotency_key: "y" });
  const code: string | null = res.data;

  return { rows, badRows, code };
}
