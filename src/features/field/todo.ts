// UX1-27 (`cra` CGR-80, ADR-106): the "Zu erledigen" row on /field links to the open-decision section with that
// section's own heading, so the words "Nicht abgeschlossen" (why a decision is open, CGR-25) stay in the link. One
// constant for the link, the section's aria-label and its heading; tests/unit/ux1-todo.test.ts checks all three use it.
export const FOLLOWUP_HEADING = "Nicht abgeschlossen: Entscheid offen";

/** The heading and link text with the count, e.g. "Nicht abgeschlossen: Entscheid offen (2)". */
export const followupLabel = (count: number) => `${FOLLOWUP_HEADING} (${count})`;
