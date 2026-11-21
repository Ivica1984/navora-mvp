import "server-only";

// SIG2 (migration 0062): reads for /settings, /team and /admin. A failure never blocks the page.

import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import { vapidPublicKey } from "./dispatch";
import type { Vendor, WatchedPeriod } from "./rules";

export type MyPushState = {
  channelOn: boolean;
  active: boolean;
  devices: Array<{ vendor: string; created_at: string; last_result: string | null; last_sent_at: string | null }>;
  vendors: Vendor[];
  vapidPublicKey: string | null;
};

export async function getMyPushState(): Promise<MyPushState> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("my_push_state");
  if (error) logEvent("error", "push.state_failed", errorFields(error));
  const d = (data ?? {}) as { channel_on?: boolean; active?: boolean; devices?: MyPushState["devices"]; vendors?: Vendor[] };
  return {
    channelOn: Boolean(d.channel_on),
    active: Boolean(d.active),
    devices: Array.isArray(d.devices) ? d.devices : [],
    vendors: Array.isArray(d.vendors) ? d.vendors : [],
    vapidPublicKey: vapidPublicKey(),
  };
}

export type TeamPushRow = { team_id: string; team_name: string; user_id: string; member_name: string; active: boolean };

/** SIG2-2: per member of the caller's teams, active / not active. */
export async function getTeamPushStatus(): Promise<TeamPushRow[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("team_push_status");
  if (error) {
    logEvent("error", "push.team_status_failed", errorFields(error));
    return [];
  }
  return (data ?? []) as TeamPushRow[];
}

export type AdminPush = { enabled: boolean; vendors: Array<Vendor & { dpf_swiss_status: string | null }>; hours: WatchedPeriod[] };

/** SIG2-3/SIG2-6: the channel, the vendors as recorded, the watched hours. Read under RLS (members of the organisation). */
export async function getAdminPush(organizationId: string): Promise<AdminPush> {
  const { supabase } = await requireUser();
  const [settings, vendors, hours] = await Promise.all([
    supabase.from("organization_push_settings").select("enabled").eq("organization_id", organizationId).maybeSingle(),
    supabase.from("push_vendors").select("vendor, legal_entity, country, dpf_swiss_status, dpf_read_on").order("vendor"),
    supabase.from("organization_watched_hours").select("weekday, starts, ends").eq("organization_id", organizationId)
      .order("weekday").order("starts"),
  ]);
  for (const [name, r] of Object.entries({ settings, vendors, hours })) {
    if (r.error) logEvent("error", `push.admin_${name}_failed`, errorFields(r.error));
  }
  return {
    enabled: Boolean(settings.data?.enabled),
    vendors: (vendors.data ?? []) as AdminPush["vendors"],
    hours: ((hours.data ?? []) as WatchedPeriod[]).map((h) => ({ weekday: h.weekday, starts: h.starts.slice(0, 5), ends: h.ends.slice(0, 5) })),
  };
}

/** SIG2-8: /field opened from the message (`?von=push`): record the tap. Never claims display. */
export async function recordPushTap(): Promise<void> {
  const { supabase } = await requireUser();
  const { error } = await supabase.rpc("record_push_tap");
  if (error) logEvent("warn", "push.tap_failed", errorFields(error));
}
