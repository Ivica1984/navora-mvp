// RET1 — returning client: pure labels (ADR-048). The database decides what may be linked and who is offered what
// (migration 0034); this module only formats.

import { REASON_LABEL } from "@/features/lifecycle/rules";
import { urgencyWithSource } from "@/features/intake/rules";

export type LinkableCaseView = {
  case_id: string;
  client_name: string | null;
  lifecycle: string;
  team_name: string | null;
  since: string | null;
  reason_code: string | null;
};

function date(iso: string | null): string {
  if (!iso) return "";
  return new Intl.DateTimeFormat("de-CH", { timeZone: "Europe/Zurich", day: "2-digit", month: "2-digit", year: "numeric" }).format(new Date(iso));
}

/** "Testfall 08 · pausiert seit 19.10.2026 (Spitalaufenthalt) · Testteam Nord" */
export function linkableLabel(c: LinkableCaseView): string {
  const state = c.lifecycle === "paused" ? "pausiert" : "abgeschlossen";
  const reason = c.reason_code ? ` (${REASON_LABEL[c.reason_code] ?? c.reason_code})` : "";
  const since = c.since ? ` seit ${date(c.since)}` : "";
  return [c.client_name ?? "Fall ohne Namen", `${state}${since}${reason}`, c.team_name ?? "ohne Team"].join(" · ");
}

/** What linking does, said before the intake role confirms. */
export function linkEffect(lifecycle: string): string {
  return lifecycle === "paused"
    ? "Der pausierte Fall wird fortgesetzt: gleiches Team, gleiche Bezugspflege, keine neue Teamsuche."
    : "Ein neuer Fall entsteht mit Verweis auf den früheren. Das frühere Team erhält die Anfrage zuerst (Vorrang innerhalb der Antwortfrist).";
}

/** Non-blocking task after a resumed pause (brief wording). */
export function reviewTaskLabel(pauseReason: string | null): string {
  const reason = pauseReason ? REASON_LABEL[pauseReason] ?? pauseReason : "der Pause";
  return `Situation nach ${reason} verändert: entscheiden, ob der Pflegeplan überprüft wird`;
}

/** Offer badge for the previous team only. */
export function returningOfferText(until: string | null): string {
  const time = until
    ? new Intl.DateTimeFormat("de-CH", { timeZone: "Europe/Zurich", day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit", hourCycle: "h23" }).format(new Date(until))
    : null;
  return `Rückkehrende Klient:in: euer Team hat sie betreut.${time ? ` Vorrang für euer Team bis ${time}.` : ""}`;
}

/**
 * COND2-4 (migration 0088, ADR-102): what the team reads about a returning referral while it handles the return.
 * The database returns the source and the referrer's date only while the review task is open; otherwise null.
 * Shown only: no order, filter, deadline or signal reads them (as IPA1-8).
 */
export type ReturnReferralFacts = { urgencyLine: string; referrerStart: string | null };

export function returnReferralFacts(c: {
  urgency: string | null;
  return_urgency_source: string | null;
  return_referrer_requested_start: string | null;
}): ReturnReferralFacts | null {
  if (!c.return_urgency_source) return null;
  return {
    urgencyLine: urgencyWithSource(c.urgency ?? "nicht erfasst", c.return_urgency_source),
    referrerStart: c.return_referrer_requested_start,
  };
}
