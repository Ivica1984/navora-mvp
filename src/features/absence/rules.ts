// ABS1 — pure helpers and labels (ADR-057). No reason is ever asked for or shown.

export const ABSENCE_MESSAGES: Record<string, string> = {
  invalid: "Bitte ein gültiges Datum wählen (Ende nach Beginn).",
  failed: "Konnte nicht gespeichert werden. Bitte erneut versuchen.",
  rejected: "Nur für dich oder ein Mitglied deines Teams möglich.",
  overlaps: "Für diese Zeit ist schon eine Abwesenheit erfasst.",
  in_past: "Diese Zeit liegt schon in der Vergangenheit.",
  not_shorter: "Das neue Ende muss vor dem bisherigen Ende und nach dem Beginn liegen.",
  already_ended: "Diese Abwesenheit ist schon vorbei.",
};

export const TAKE_MESSAGES: Record<string, string> = {
  failed: "Konnte nicht übernommen werden. Bitte erneut versuchen.",
  already_taken: "Bereits übernommen: jemand aus dem Team war schneller.",
  not_qualified: "Diesen Einsatz übernimmt eine Pflegefachperson (Kategorie B oder Bedarfsabklärung).",
  absent: "Du bist zu dieser Zeit als abwesend erfasst.",
  not_open: "Dieser Einsatz ist nicht mehr offen.",
  rejected: "Dieser Einsatz gehört nicht zu deinem Team.",
};

const ZONE = "Europe/Zurich";

/** "Do, 24.10. 00:00" style label in Zurich time; whole days drop the time. */
function formatAt(iso: string, withTime: boolean): string {
  const d = new Date(iso);
  const date = new Intl.DateTimeFormat("de-CH", { timeZone: ZONE, weekday: "short", day: "2-digit", month: "2-digit" }).format(d);
  if (!withTime) return date;
  const time = new Intl.DateTimeFormat("de-CH", { timeZone: ZONE, hour: "2-digit", minute: "2-digit", hour12: false }).format(d);
  return `${date} ${time}`;
}

function isMidnight(iso: string): boolean {
  const t = new Intl.DateTimeFormat("de-CH", { timeZone: ZONE, hour: "2-digit", minute: "2-digit", hour12: false }).format(new Date(iso));
  return t === "00:00" || t === "24:00";
}

/**
 * The absence period as shown to the team: whole days as "Do, 24.10." or "Do, 24.10. – Fr, 25.10.",
 * otherwise with times. ends_at is exclusive, so a whole day ending at 00:00 shows the day before.
 */
export function formatAbsencePeriod(startsAt: string, endsAt: string): string {
  const wholeDays = isMidnight(startsAt) && isMidnight(endsAt);
  if (wholeDays) {
    const lastDay = new Date(new Date(endsAt).getTime() - 60_000).toISOString();
    const from = formatAt(startsAt, false);
    const to = formatAt(lastDay, false);
    return from === to ? from : `${from} – ${to}`;
  }
  return `${formatAt(startsAt, true)} – ${formatAt(endsAt, true)}`;
}

/** Display text for who is absent: herself or the colleague's display name. */
export function absenceMemberLabel(member: string): string {
  return member === "me" ? "Du" : member;
}

/** Label for the colleague the case knows ("kennt die Klientin"), or null when nobody in the team does. */
export function knownByLabel(knownBy: string | null): string | null {
  if (!knownBy) return null;
  return knownBy === "me" ? "Du kennst die Klientin" : `${knownBy} kennt die Klientin`;
}

/** Maps a command's jsonb {result} to a UI outcome. */
export function resultOf(data: unknown): string {
  if (data && typeof data === "object" && "result" in data) return String((data as { result: unknown }).result);
  return "failed";
}
