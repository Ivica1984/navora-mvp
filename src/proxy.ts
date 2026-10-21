import type { NextRequest } from "next/server";
import { buildContentSecurityPolicy, createNonce } from "@/lib/security/csp";
import { updateSession } from "@/lib/supabase/proxy";

// Next.js 16 "proxy" (formerly middleware):
// 1. per-request CSP nonce (T11) — passed to the render via the request's CSP
//    header, and sent to the browser on the response;
// 2. session refresh + coarse route guard (T8).
export async function proxy(request: NextRequest) {
  const nonce = createNonce();
  const csp = buildContentSecurityPolicy(nonce, {
    dev: process.env.NODE_ENV === "development",
  });

  const response = await updateSession(request, {
    "x-nonce": nonce,
    "content-security-policy": csp,
  });

  response.headers.set("Content-Security-Policy", csp);
  return response;
}

export const config = {
  matcher: [
    // Everything except Next internals and static files.
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)",
  ],
};
