import "server-only";

import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { getSupabaseEnv } from "./env";

/**
 * Supabase client bound to the signed-in user's session cookies.
 * Every query runs with the user's JWT, so RLS sees `authenticated` + `auth.uid()`,
 * never the anon role (closes SR-02). Use only in Server Components, Server Actions
 * and Route Handlers — the import of "server-only" enforces this at build time.
 */
export async function createSupabaseServerClient() {
  const cookieStore = await cookies();
  const { url, key } = getSupabaseEnv();

  return createServerClient(url, key, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          for (const { name, value, options } of cookiesToSet) {
            cookieStore.set(name, value, options);
          }
        } catch {
          // Called from a Server Component, where cookies are read-only.
          // The proxy (src/proxy.ts) refreshes the session on every request.
        }
      },
    },
  });
}
