// SIG2 (migration 0062, ADR-076): fixed texts and pure helpers for delivery outside the app.
// Pure module (no "use server", no I/O), unit-tested in tests/unit/push-rules.test.ts.

/**
 * SIG2-8: the one push text, the same for every organisation and message. No visit ID, client name, address, visit
 * time or health data, in the payload or in the URL.
 */
export const PUSH_TEXT = "NAVORA: Ein Sicherheitssignal wartet auf dich.";
/** The link the message opens. `von=push` lets /field record the tap; it carries no ID. */
export const PUSH_URL = "/field?von=push";
/** The payload sent to the device: exactly these two fields. */
export const PUSH_PAYLOAD = JSON.stringify({ text: PUSH_TEXT, url: PUSH_URL });

export const OUTSIDE_LABEL = "Benachrichtigung ausserhalb der App";

export type Vendor = { vendor: string; legal_entity: string; country: string; dpf_read_on: string | null };

const VENDOR_SERVICE: Record<string, string> = {
  google_fcm: "Google-Push (Chrome, Edge auf Android, Samsung Internet)",
  microsoft_wns: "Microsoft-Push (Edge auf Windows)",
};

/**
 * SIG2-1 (DSG Art. 19): the member information shown before the switch. What, when, through whom and where, and how
 * to switch it off. The vendor list comes from the database (only vendors whose DPF entry is recorded).
 */
export function memberInformation(vendors: Vendor[]): string[] {
  const through =
    vendors.length === 0
      ? "Zurzeit ist kein Anbieter freigegeben; du erhältst Signale nur in der App."
      : `Übermittelt über ${vendors
          .map((v) => `${v.legal_entity}, ${v.country} (${VENDOR_SERVICE[v.vendor] ?? v.vendor})`)
          .join(" oder ")}, je nach Browser deines Geräts. Daten in die USA: Anbieter unter dem Swiss-U.S. Data Privacy Framework.`;
  return [
    `Was: eine feste Nachricht «${PUSH_TEXT}» mit einem Link zu NAVORA. Keine Klientendaten, kein Name, keine Adresse, keine Uhrzeit.`,
    "Wann: bei einem P1-Sicherheitssignal, das an dich geht, innerhalb deiner geplanten Arbeitszeit (von deinem ersten bis zu deinem letzten geplanten Einsatz des Tages); als Zuständige des Einsatzes immer, solange du nicht abwesend bist.",
    "Für Operations: jedes P1-Signal, das an Operations geht, zu jeder Zeit.",
    through,
    "Beim Einschalten erhältst du eine Testnachricht. Dein Team sieht nur, ob die Benachrichtigung bei dir aktiv ist.",
    "Ausschalten: hier jederzeit; das Gerät wird sofort gelöscht. In der App erhältst du Signale weiterhin.",
    "Apple-Geräte (Safari) und Firefox: auf diesem Weg nicht verfügbar (D-33); Signale kommen in der App.",
  ];
}

export const NOT_AVAILABLE = "Auf diesem Gerät nicht verfügbar, du erhältst Signale in der App.";

export const ENABLE_MESSAGES: Record<string, string> = {
  ok: "Eingeschaltet. Eine Testnachricht ist unterwegs.",
  duplicate: "Bereits eingeschaltet.",
  not_available: NOT_AVAILABLE,
  unsupported: NOT_AVAILABLE,
  channel_off: "Deine Organisation hat die Benachrichtigung ausserhalb der App nicht eingeschaltet.",
  denied: "Benachrichtigungen sind im Browser blockiert. Du erhältst Signale in der App.",
  rejected: "Konnte nicht gespeichert werden.",
  failed: "Konnte nicht gespeichert werden. Bitte nochmals versuchen.",
  invalid: "Ungültige Eingabe.",
};

export const ADMIN_PUSH_MESSAGES: Record<string, string> = {
  vendors_unverified:
    "Noch kein Anbieter freigegeben: der Eintrag im Swiss-U.S. Data Privacy Framework ist nicht erfasst (SIG2-3).",
  rejected: "Nur die Administration kann das ändern.",
  invalid: "Ungültige Zeiten: Beginn vor Ende, keine Überschneidungen.",
  failed: "Konnte nicht gespeichert werden. Bitte nochmals versuchen.",
  unchanged: "Unverändert.",
};

export const TEAM_STATUS_NOTE =
  "Ausserhalb der App erhalten nur Mitglieder mit aktiver Benachrichtigung ein Signal, innerhalb ihrer geplanten Arbeitszeit. " +
  "Nicht übernommene Signale gehen an Operations; es gibt keine Benachrichtigung an das ganze Team ausserhalb der App.";

export function statusText(active: boolean): string {
  return `${OUTSIDE_LABEL}: ${active ? "aktiv" : "nicht aktiv"}`;
}

export const WEEKDAYS = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"] as const;

export type WatchedPeriod = { weekday: number; starts: string; ends: string };

const TIME = /^([01]\d|2[0-3]):[0-5]\d$|^24:00$/;

/**
 * Parses "07:00-20:00" or "07:00-12:00, 13:00-20:00" for one ISO weekday (1 = Monday). Empty = not watched.
 * Returns null when the text is not valid (the database checks again).
 */
export function parseWatchedDay(weekday: number, text: string): WatchedPeriod[] | null {
  const t = text.trim();
  if (t === "") return [];
  const out: WatchedPeriod[] = [];
  for (const part of t.split(",")) {
    const m = part.trim().match(/^(\d{2}:\d{2})\s*-\s*(\d{2}:\d{2})$/);
    if (!m || !TIME.test(m[1]) || !TIME.test(m[2]) || m[1] === "24:00" || m[1] >= m[2]) return null;
    out.push({ weekday, starts: m[1], ends: m[2] });
  }
  out.sort((a, b) => a.starts.localeCompare(b.starts));
  for (let i = 1; i < out.length; i++) if (out[i].starts < out[i - 1].ends) return null;
  return out;
}

/** The inverse of parseWatchedDay for the form's default value. */
export function formatWatchedDay(periods: Array<{ starts: string; ends: string }>): string {
  return periods
    .map((p) => `${p.starts.slice(0, 5)}-${p.ends.slice(0, 5) === "00:00" ? "24:00" : p.ends.slice(0, 5)}`)
    .join(", ");
}

/**
 * The browser subscription the server accepts: an https endpoint and the two keys. The vendor check is the
 * database's (fail closed); this is shape only.
 */
export function readSubscription(input: unknown): { endpoint: string; p256dh: string; auth: string } | null {
  if (!input || typeof input !== "object") return null;
  const o = input as { endpoint?: unknown; keys?: { p256dh?: unknown; auth?: unknown } };
  if (typeof o.endpoint !== "string" || !o.endpoint.startsWith("https://") || o.endpoint.length > 2048) return null;
  const p256dh = o.keys?.p256dh;
  const auth = o.keys?.auth;
  if (typeof p256dh !== "string" || !/^[A-Za-z0-9_-]{86,88}={0,2}$/.test(p256dh)) return null;
  if (typeof auth !== "string" || !/^[A-Za-z0-9_-]{21,24}={0,2}$/.test(auth)) return null;
  return { endpoint: o.endpoint, p256dh, auth };
}

/** HTTP status of a push service → outcome (RFC 8030): 201/202 accepted; 404/410 the device is gone. */
export function pushOutcome(status: number): { ok: boolean; gone: boolean } {
  return { ok: status >= 200 && status < 300, gone: status === 404 || status === 410 };
}
