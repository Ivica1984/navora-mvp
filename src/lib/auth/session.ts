import "server-only";

import { redirect } from "next/navigation";
import { cache } from "react";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { LOGIN_PATH } from "./paths";

/**
 * Data-access guard. Call at the start of every query and command, not only in
 * layouts: layouts and pages render independently, so a layout check alone does
 * not protect a page's data (ADR-017).
 *
 * Uses getUser(), which asks the Auth server, so a revoked session is rejected
 * even while its JWT has not expired yet. Memoised per request with React
 * cache() (TD-23): layout, page queries and commands share one Auth round-trip.
 */
export const requireUser = cache(async function requireUser() {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.auth.getUser();

  if (error || !data.user) {
    redirect(LOGIN_PATH);
  }

  return { user: data.user, supabase };
});

/** For pages that behave differently when a session exists (e.g. /login). */
export async function getOptionalUser() {
  const supabase = await createSupabaseServerClient();
  const { data } = await supabase.auth.getUser();

  return data.user ?? null;
}
