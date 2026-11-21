// BK-e1b / CGR-242 (c) (`cra` 2026-11-18 04:27; words `uxa` 03:50 in docs/agents/reports/UX_REVIEW.md; PO 04:39):
// the /field card of a visit written from a take that was released before the start. The card stays on her day and
// says in text that it is no longer hers and why; it never reads as a cancellation by the client (CGR-242 (a)).
// The code is care_visits.system_end_reason (migration 0139); the visit is listed only to its named member, so the
// reason (her own absence) reaches nobody else (`lca`).

export const TAKE_ENDED_STATUS = "Nicht mehr deine Schicht";

const TAIL = "Das Angebot geht wieder an alle passenden Teams.";

const REASON: Record<string, string> = {
  take_released_absence: "du hast für diese Zeit eine Abwesenheit erfasst",
  take_released_busy: "du hast zur gleichen Zeit einen anderen Einsatz",
  take_released_left_team: "du bist nicht mehr in diesem Team",
};

/** The reason line, or null when the visit was not ended by a released take. */
export function takeEndedText(code: string | null | undefined): string | null {
  if (!code) return null;
  // HD-2 slice 5: the client took the order back; no offer runs again, so the tail is not said.
  if (code === "order_withdrawn") return "Die Übernahme gilt nicht mehr: der Auftrag wurde zurückgezogen.";
  const reason = REASON[code];
  return reason ? `Die Übernahme gilt nicht mehr: ${reason}. ${TAIL}` : `Die Übernahme gilt nicht mehr. ${TAIL}`;
}
