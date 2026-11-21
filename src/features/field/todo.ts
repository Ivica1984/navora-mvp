// UX1-27 (`cra` CGR-80, ADR-106): the "Zu erledigen" row on /field links to the open-decision section with that
// section's own heading, so the words "Nicht abgeschlossen" (why a decision is open, CGR-25) stay in the link.
// UX1-30 (`uxa` UXR-20, `cra` 05:30, ADR-107): every link in the row and the `h2` of the section it jumps to take their
// name from one constant per section, followed by the count. tests/unit/ux1-todo.test.ts checks link = heading.
export const FOLLOWUP_HEADING = "Nicht abgeschlossen: Entscheid offen";
export const RETURNED_HEADING = "Zurückgegeben";
export const COUNTERSIGN_HEADING = "Zur Gegenzeichnung";

/**
 * UX1-30 condition (2): the instruction that used to follow "Zurückgegeben:" in the heading, word for word. It is
 * rendered in sentence case as the first line of the returned-reports section (condition (1)); see
 * `returnedInstructionLine`.
 */
export const RETURNED_INSTRUCTION = "bitte korrigieren und neu unterschreiben";

/** The instruction as the section's first line: sentence case only, no other change. */
export const returnedInstructionLine = () => RETURNED_INSTRUCTION.charAt(0).toUpperCase() + RETURNED_INSTRUCTION.slice(1);

const withCount = (heading: string, count: number) => `${heading} (${count})`;

/** The heading and link text with the count, e.g. "Nicht abgeschlossen: Entscheid offen (2)". */
export const followupLabel = (count: number) => withCount(FOLLOWUP_HEADING, count);
/** "Zurückgegeben (n)": link text and section heading. */
export const returnedLabel = (count: number) => withCount(RETURNED_HEADING, count);
/** "Zur Gegenzeichnung (n)": link text and section heading. */
export const countersignLabel = (count: number) => withCount(COUNTERSIGN_HEADING, count);

// BD / UXR-155 (`uxa` 03:52, PO 04:39, ADR-179): a referral offered to her team shows up where she starts. One neutral
// link in the "Zu erledigen" row, named like the offers heading on /team and followed by the count; it leads to that
// section, where the team decides. No client name, no request title, no urgency colour (the urgency stays on the card).
export const TEAM_OFFERS_HEADING = "Anfragen an dein Team";
/** The id of the offers heading on /team. */
export const TEAM_OFFERS_ANCHOR = "anfragen";
/** "Anfragen an dein Team (n)": link text on /field. */
export const teamOffersLabel = (count: number) => withCount(TEAM_OFFERS_HEADING, count);
/** The offers section on /team. */
export const teamOffersHref = () => `/team#${TEAM_OFFERS_ANCHOR}`;
/** The offers /team lists as open ("Offene Anfragen"): those her team has not declined, one per request and team. */
export const openTeamOfferCount = (offers: ReadonlyArray<{ my_team_declined: boolean | null }>) =>
  offers.filter((o) => !o.my_team_declined).length;
