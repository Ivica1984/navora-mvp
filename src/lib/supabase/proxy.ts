import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { isPublicPath, LOGIN_PATH } from "@/lib/auth/paths";
import { getSupabaseEnv } from "./env";

/**
 * Runs on every matched request (src/proxy.ts):
 * 1. refreshes the Supabase session and writes rotated cookies to the response;
 * 2. redirects requests without a valid session to /login.
 *
 * This is the coarse outer guard. It is not the only one: the (protected) layout
 * and every query/command call requireUser() again (ADR-017).
 */
export async function updateSession(
  request: NextRequest,
  extraRequestHeaders: Record<string, string> = {}
) {
  // Forwards the (possibly refreshed) cookies AND extra headers such as the
  // per-request CSP nonce (T11) to the page render.
  const next = () => {
    const headers = new Headers(request.headers);
    for (const [name, value] of Object.entries(extraRequestHeaders)) {
      headers.set(name, value);
    }
    return NextResponse.next({ request: { headers } });
  };

  let response = next();
  const { url, key } = getSupabaseEnv();

  const supabase = createServerClient(url, key, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet, headers?: Record<string, string>) {
        for (const { name, value } of cookiesToSet) {
          request.cookies.set(name, value);
        }
        response = next();
        for (const { name, value, options } of cookiesToSet) {
          response.cookies.set(name, value, options);
        }
        // Cache headers supplied by @supabase/ssr so responses carrying a
        // refreshed session are never cached by a CDN.
        for (const [header, headerValue] of Object.entries(headers ?? {})) {
          response.headers.set(header, headerValue);
        }
      },
    },
  });

  // Do not run code between createServerClient and this call: it validates the
  // JWT and triggers the token refresh. Never use getSession() for authorization.
  const { data } = await supabase.auth.getClaims();
  const isAuthenticated = Boolean(data?.claims?.sub);

  if (!isAuthenticated && !isPublicPath(request.nextUrl.pathname)) {
    const loginUrl = request.nextUrl.clone();
    loginUrl.pathname = LOGIN_PATH;
    loginUrl.search = "";

    const redirect = NextResponse.redirect(loginUrl);
    for (const cookie of response.cookies.getAll()) {
      redirect.cookies.set(cookie);
    }
    return redirect;
  }

  return response;
}
