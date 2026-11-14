import "server-only";

import type { createSupabaseServerClient } from "@/lib/supabase/server";
import { homePathFor } from "@/features/orders/rules";
import { homePathForRoles } from "./paths";
import { requireUser } from "./session";
import { errorFields, logEvent } from "@/lib/log";

/** Reads the caller's own organisation roles (RLS: own memberships only) and picks the landing page. */
type ServerClient = Awaited<ReturnType<typeof createSupabaseServerClient>>;

export async function resolveHomePath(supabase: ServerClient): Promise<string> {
  const { data, error } = await supabase.from("organization_memberships").select("role");
  if (error) {
    logEvent("warn", "auth.home_path_failed", errorFields(error));
    return homePathForRoles([]);
  }
  const roles = (data ?? []).map((row) => row.role);
  if (roles.length > 0) return homePathForRoles(roles);
  // BK-a (ADR-192 (6)): a client account member has no organisation role and lands on /order.
  const { data: accounts, error: aError } = await supabase.rpc("my_client_accounts");
  if (aError) {
    logEvent("warn", "auth.client_accounts_failed", errorFields(aError));
    return homePathForRoles([]);
  }
  return homePathFor(roles, (accounts ?? []).length > 0);
}

export async function getHomePath(): Promise<string> {
  const { supabase } = await requireUser();
  return resolveHomePath(supabase);
}
