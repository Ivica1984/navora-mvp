import { timingSafeEqual } from "node:crypto";
import { dispatchPending } from "@/features/push/dispatch";
import { logEvent } from "@/lib/log";

// SIG2 (ADR-076): the scheduler's entry point. A job outside the app calls it every minute with
// `Authorization: Bearer <PUSH_DISPATCH_SECRET>` (production: owner, D-2). No session; nothing user-specific in or out.
export const dynamic = "force-dynamic";

function authorised(header: string | null): boolean {
  const secret = process.env.PUSH_DISPATCH_SECRET;
  if (!secret || secret.length < 32 || !header?.startsWith("Bearer ")) return false;
  const given = Buffer.from(header.slice(7));
  const want = Buffer.from(secret);
  return given.length === want.length && timingSafeEqual(given, want);
}

export async function POST(request: Request): Promise<Response> {
  if (!authorised(request.headers.get("authorization"))) {
    logEvent("warn", "push.dispatch_unauthorised", { status: 401 });
    return new Response(null, { status: 401 });
  }
  const summary = await dispatchPending();
  return Response.json(summary, { headers: { "Cache-Control": "no-store" } });
}
