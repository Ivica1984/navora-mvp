import "server-only";

import type { createSupabaseServerClient } from "@/lib/supabase/server";
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
  return homePathForRoles((data ?? []).map((row) => row.role));
}

export async function getHomePath(): Promise<string> {
  const { supabase } = await requireUser();
  return resolveHomePath(supabase);
}
