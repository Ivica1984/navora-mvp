// BK-b1s (PO amendment 2026-11-14 10:39 (3), AUT-117 (c); ADR-195 addendum 11:10): pure rules of the team's reach
// screen «Unser Einsatzgebiet». No Next or Supabase imports, unit-tested (tests/unit/bk-b1s-team-reach.test.ts).
// The database (`set_team_reach`, migration 0130) decides every check; this module only words its codes.
// Words: PROPOSED by `eng` for `uxa` (the help line from D-44 `lca`); `uxa` owns them and may change them.

/** Under the team's page; the team's own screen (team autonomy, value 4). */
export const REACH_PATH = "/team/einsatzgebiet";

/** Codes of `set_team_reach` (migration 0130), in the order the command checks them. */
export const REACH_PROBLEM_CODES = ["missing_service_postcode", "postcode_not_in_list", "max_distance_not_positive"] as const;
export type ReachProblemCode = (typeof REACH_PROBLEM_CODES)[number];

const PROBLEM_TEXT: Record<ReachProblemCode, string> = {
  missing_service_postcode: "Bitte mindestens eine PLZ wählen.",
  postcode_not_in_list: "Diese PLZ ist nicht in der Liste.",
  max_distance_not_positive: "Bitte eine Distanz grösser als 0 km eingeben.",
};
const PROBLEM_FIELD: Record<ReachProblemCode, "postcodes" | "distance"> = {
  missing_service_postcode: "postcodes",
  postcode_not_in_list: "postcodes",
  max_distance_not_positive: "distance",
};
const UNKNOWN_TEXT = "Nicht gespeichert. Bitte die Angaben prüfen.";

function isCode(code: string): code is ReachProblemCode {
  return (REACH_PROBLEM_CODES as ReadonlyArray<string>).includes(code);
}

export function reachProblemText(code: string): string {
  return isCode(code) ? PROBLEM_TEXT[code] : UNKNOWN_TEXT;
}

/** BK-b1s (b): each refusal at its own field; an unknown code at the postcode field (never dropped). */
export function reachProblemsByField(codes: ReadonlyArray<string>): { postcodes: string[]; distance: string[] } {
  const out = { postcodes: [] as string[], distance: [] as string[] };
  for (const code of codes) out[isCode(code) ? PROBLEM_FIELD[code] : "postcodes"].push(reachProblemText(code));
  return out;
}

/** BK-b1s (d): BK-2n rows are written once at confirmation (AUT-117 (b)); a reach change never rewrites them. */
export const REACH_NEW_ORDERS_ONLY_TEXT =
  "Eine Änderung gilt für neue Aufträge. Aufträge, die schon geprüft wurden, bleiben, wie sie sind.";

/** D-44 (`lca`, proposed wording): the start of the distance is the team's area, never a home address (P-5). */
export const REACH_HELP_TEXT = "PLZ, von der aus euer Team Aufträge annimmt. Nicht eure Wohnadresse.";

/** «10», «7,5», «7.5»; anything else is null and the database refuses it at the field. */
export function parseDistanceKm(raw: string): number | null {
  const s = raw.trim();
  if (!/^-?\d+([.,]\d+)?$/.test(s)) return null;
  return Number(s.replace(",", "."));
}

export function parsePostcodes(raw: ReadonlyArray<string>): string[] {
  return [...new Set(raw.map((p) => p.trim()).filter((p) => p !== ""))].sort();
}
