// ORD0 (migration 0061, ADR-075): "Hausärztin/Hausarzt informiert" — pure helpers and labels. No Next or Supabase imports.
// The database decides (public.record_gp_informed); these helpers only label and pre-check the form.

/** The fixed channel codes (ORD0-1). No free text. */
export const GP_CHANNELS = ["elektronisch", "brief", "telefon", "persoenlich"] as const;
export type GpChannel = (typeof GP_CHANNELS)[number];

export const GP_CHANNEL_LABEL: Record<GpChannel, string> = {
  elektronisch: "Elektronisch",
  brief: "Brief",
  telefon: "Telefon",
  persoenlich: "Persönlich",
};

export function isGpChannel(v: unknown): v is GpChannel {
  return typeof v === "string" && (GP_CHANNELS as readonly string[]).includes(v);
}

export type GpNotice = { case_id: string; informed_on: string; channel: string; recorded_at: string };

/** "12.10.2026" from "2026-10-12". */
function formatDay(date: string): string {
  const [y, m, d] = date.slice(0, 10).split("-");
  return `${d}.${m}.${y}`;
}

function channelLabel(channel: string): string {
  return isGpChannel(channel) ? GP_CHANNEL_LABEL[channel] : channel;
}

/** ORD0-3: the line on the case card. */
export function gpInformedText(notice: Pick<GpNotice, "informed_on" | "channel">): string {
  return `Hausärztin/Hausarzt informiert am ${formatDay(notice.informed_on)} (${channelLabel(notice.channel)})`;
}

/** ORD0-3 (HAND1): one line for the handover entry. */
export function gpInformedEntryLine(detail: Record<string, unknown>): string | null {
  const on = typeof detail.informed_on === "string" ? detail.informed_on : null;
  const channel = typeof detail.channel === "string" ? detail.channel : null;
  if (!on || !channel) return null;
  return `am ${formatDay(on)} (${channelLabel(channel)})`;
}

/** The newest record per case (the list comes newest first, or in any order). */
export function latestNoticeByCase(notices: GpNotice[]): Map<string, GpNotice> {
  const byCase = new Map<string, GpNotice>();
  for (const n of notices) {
    const seen = byCase.get(n.case_id);
    if (!seen || Date.parse(n.recorded_at) > Date.parse(seen.recorded_at)) byCase.set(n.case_id, n);
  }
  return byCase;
}

/** Form pre-check (the server decides): an ISO day, not after today (Europe/Zurich, passed in). */
export function informedOnProblem(date: string, today: string): "missing" | "future" | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return "missing";
  return date > today ? "future" : null;
}

/** Messages for the command results (German UI). */
export const GP_MESSAGES: Record<string, string> = {
  invalid: "Bitte Datum und Kanal wählen.",
  future: "Das Datum darf nicht in der Zukunft liegen.",
  before_case: "Das Datum liegt vor der Erfassung des Falls.",
  not_team: "Nicht gespeichert: Du gehörst nicht zum zuständigen Team.",
  case_closed: "Nicht gespeichert: Der Fall ist abgeschlossen.",
  no_open_task: "Bereits erledigt.",
  failed: "Konnte nicht gespeichert werden.",
};
