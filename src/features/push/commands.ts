"use server";

// SIG2 (migration 0062, ADR-076): switch delivery outside the app on and off (member), the channel and the watched
// hours (administrator). The database decides everything again (vendor allowlist, channel, roles, audit, idempotency).

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import type { CommandResult } from "@/lib/commands/result";
import { errorFields, logEvent } from "@/lib/log";
import { dispatchPending } from "./dispatch";
import { ADMIN_PUSH_MESSAGES, ENABLE_MESSAGES, readSubscription } from "./rules";

const key = z.uuid();

/** SIG2-1/SIG2-2: store this device's subscription; on success the test message is sent at once. */
export async function enableOutsideDelivery(input: unknown): Promise<{ ok: boolean; code: string; message: string }> {
  const p = z.object({ subscription: z.unknown(), idempotencyKey: key }).safeParse(input);
  const sub = p.success ? readSubscription(p.data.subscription) : null;
  if (!p.success || !sub) return { ok: false, code: "invalid", message: ENABLE_MESSAGES.invalid };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("register_push_subscription", {
    p_endpoint: sub.endpoint, p_p256dh: sub.p256dh, p_auth: sub.auth, p_idempotency_key: p.data.idempotencyKey,
  });
  if (error) {
    logEvent("warn", "command.failed", { op: "register_push_subscription", ...errorFields(error) });
    return { ok: false, code: "failed", message: ENABLE_MESSAGES.failed };
  }
  const code = String((data as { result?: unknown } | null)?.result ?? "failed");
  if (code === "ok") {
    // The test message (SIG2-2): sent now when the sender is configured; otherwise by the next scheduled round.
    await dispatchPending(20).catch(() => logEvent("error", "push.dispatch_failed", { code: "exception" }));
    revalidatePath("/settings");
    revalidatePath("/team");
  }
  return { ok: code === "ok" || code === "duplicate", code, message: ENABLE_MESSAGES[code] ?? ENABLE_MESSAGES.failed };
}

/** SIG2-1: switching off deletes the subscription (this device, or every device of hers when endpoint is null). */
export async function disableOutsideDelivery(input: unknown): Promise<CommandResult> {
  const p = z.object({ endpoint: z.string().startsWith("https://").max(2048).nullable(), idempotencyKey: key }).safeParse(input);
  if (!p.success) return { ok: false, error: ENABLE_MESSAGES.invalid };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("unregister_push_subscription", {
    p_endpoint: p.data.endpoint as string, p_idempotency_key: p.data.idempotencyKey,
  });
  if (error) {
    logEvent("warn", "command.failed", { op: "unregister_push_subscription", ...errorFields(error) });
    return { ok: false, error: ENABLE_MESSAGES.failed };
  }
  revalidatePath("/settings");
  revalidatePath("/team");
  return data === "rejected" ? { ok: false, error: ENABLE_MESSAGES.rejected } : { ok: true };
}

function adminResult(op: string, data: unknown, error: { code?: string } | null): CommandResult {
  if (error) {
    logEvent("warn", "command.failed", { op, ...errorFields(error) });
    return { ok: false, error: ADMIN_PUSH_MESSAGES.failed };
  }
  if (data === "ok" || data === "duplicate" || data === "unchanged") {
    revalidatePath("/admin");
    revalidatePath("/settings");
    return { ok: true };
  }
  return { ok: false, error: ADMIN_PUSH_MESSAGES[String(data)] ?? ADMIN_PUSH_MESSAGES.failed };
}

/** SIG2-3: the channel per organisation (administrator only). */
export async function setOutsidePush(input: unknown): Promise<CommandResult> {
  const p = z.object({ organizationId: z.uuid(), enabled: z.boolean(), idempotencyKey: key }).safeParse(input);
  if (!p.success) return { ok: false, error: ADMIN_PUSH_MESSAGES.invalid };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("set_outside_push", {
    p_organization_id: p.data.organizationId, p_enabled: p.data.enabled, p_idempotency_key: p.data.idempotencyKey,
  });
  return adminResult("set_outside_push", data, error);
}

const period = z.object({ weekday: z.number().int().min(1).max(7), starts: z.string().regex(/^\d{2}:\d{2}$/), ends: z.string().regex(/^\d{2}:\d{2}$/) });

/** SIG2-6: the watched hours of the whole week (administrator only). */
export async function setWatchedHours(input: unknown): Promise<CommandResult> {
  const p = z.object({ organizationId: z.uuid(), hours: z.array(period).max(28), idempotencyKey: key }).safeParse(input);
  if (!p.success) return { ok: false, error: ADMIN_PUSH_MESSAGES.invalid };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("set_watched_hours", {
    p_organization_id: p.data.organizationId, p_hours: p.data.hours, p_idempotency_key: p.data.idempotencyKey,
  });
  return adminResult("set_watched_hours", data, error);
}
