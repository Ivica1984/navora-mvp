import "server-only";

// SIG2 (ADR-076): the sender. Claims due messages from the database, sends each to the push service, reports the
// result. The only module that uses the service-role key, and only for the two sender functions
// (push_dispatch_claim / push_dispatch_report are executable by service_role and nobody else, pgTAP 064).
//
// Configuration (server environment only; none of it is ever sent to the browser except the public VAPID key):
//   SUPABASE_SERVICE_ROLE_KEY  · VAPID_PUBLIC_KEY · VAPID_PRIVATE_KEY · VAPID_SUBJECT (mailto: or https: contact)
//   PUSH_TRANSPORT=test        → no network: every endpoint accepts, except one containing "/syn-fail" (CI, e2e).
// Missing configuration → nothing is sent; pending rows then fail after 2 minutes in the database and the signal goes
// to Operations at once (fail closed, SIG2-5).

import { createClient } from "@supabase/supabase-js";
import type { Database } from "@/lib/supabase/database.types";
import { errorFields, logEvent } from "@/lib/log";
import { PUSH_PAYLOAD, pushOutcome } from "./rules";
import { buildPushRequest, vapidKeyObject } from "./webpush";

type Claimed = Database["public"]["Functions"]["push_dispatch_claim"]["Returns"][number];

export type DispatchSummary = { skipped?: "not_configured"; claimed: number; sent: number; failed: number };

function config() {
  const url = process.env.SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const publicKey = process.env.VAPID_PUBLIC_KEY;
  const privateKey = process.env.VAPID_PRIVATE_KEY;
  const subject = process.env.VAPID_SUBJECT;
  const test = process.env.PUSH_TRANSPORT === "test";
  if (!url || !serviceKey || (!test && (!publicKey || !privateKey || !subject))) return null;
  return { url, serviceKey, test, vapid: test ? null : { publicKey: publicKey!, privateKey: vapidKeyObject(publicKey!, privateKey!), subject: subject! } };
}

/** The public VAPID key for the browser's subscribe call (not a secret). Null when outside delivery is not configured. */
export function vapidPublicKey(): string | null {
  return process.env.VAPID_PUBLIC_KEY ?? null;
}

async function sendOne(row: Claimed, cfg: NonNullable<ReturnType<typeof config>>): Promise<{ ok: boolean; gone: boolean }> {
  if (!row.endpoint || !row.p256dh || !row.auth_secret) return { ok: false, gone: false };
  if (cfg.test) return { ok: !row.endpoint.includes("/syn-fail"), gone: false };
  try {
    const req = buildPushRequest({ endpoint: row.endpoint, p256dh: row.p256dh, auth: row.auth_secret }, PUSH_PAYLOAD, cfg.vapid!);
    const res = await fetch(req.url, { method: "POST", headers: req.headers, body: new Uint8Array(req.body), signal: AbortSignal.timeout(10_000) });
    const out = pushOutcome(res.status);
    if (!out.ok) logEvent("warn", "push.send_failed", { status: res.status });
    return out;
  } catch {
    logEvent("warn", "push.send_failed", { code: "network" });
    return { ok: false, gone: false };
  }
}

/** One dispatch round. Safe to run concurrently: the database hands each item out once (skip locked). */
export async function dispatchPending(limit = 100): Promise<DispatchSummary> {
  const cfg = config();
  if (!cfg) return { skipped: "not_configured", claimed: 0, sent: 0, failed: 0 };
  const db = createClient<Database>(cfg.url, cfg.serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data, error } = await db.rpc("push_dispatch_claim", { p_limit: limit });
  if (error) {
    logEvent("error", "push.claim_failed", errorFields(error));
    return { claimed: 0, sent: 0, failed: 0 };
  }
  // One item (a delivery row or a test message) may have several devices.
  const items = new Map<string, { kind: string; refId: string; rows: Claimed[] }>();
  for (const row of data ?? []) {
    const key = `${row.kind}:${row.ref_id}`;
    const item = items.get(key) ?? { kind: row.kind, refId: row.ref_id, rows: [] };
    item.rows.push(row);
    items.set(key, item);
  }
  let sent = 0;
  let failed = 0;
  for (const item of items.values()) {
    const results = [];
    for (const row of item.rows) {
      if (!row.subscription_id) continue;   // the recipient has no active device any more
      const out = await sendOne(row, cfg);
      results.push({ subscription_id: row.subscription_id, ok: out.ok, gone: out.gone });
    }
    const rep = await db.rpc("push_dispatch_report", { p_kind: item.kind, p_ref_id: item.refId, p_results: results });
    if (rep.error) logEvent("error", "push.report_failed", errorFields(rep.error));
    else if (rep.data === "sent") sent++;
    else failed++;
  }
  if (items.size > 0) logEvent("info", "push.dispatched", { count: items.size });
  return { claimed: items.size, sent, failed };
}

/** Fire-and-forget after a page poll: outside delivery also leaves while any page is open (the scheduler is primary). */
export function kickDispatch(): void {
  if (!config()) return;
  void dispatchPending().catch(() => logEvent("error", "push.dispatch_failed", { code: "exception" }));
}
