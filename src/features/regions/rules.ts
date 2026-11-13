// B1.1-1 (Δ1, ADR-186): the region is chosen from the organisation's list, never typed. The database trigger
// `private.region_from_list` is the guard; these helpers only shape the form and the texts.

export type RegionRow = { id: string; name: string; sort_order: number; active: boolean };
export type RegionOption = { value: string; label: string };

/** Active list entries in list order. */
export function regionOptions(rows: readonly RegionRow[]): RegionOption[] {
  return rows
    .filter((r) => r.active)
    .slice()
    .sort((a, b) => a.sort_order - b.sort_order)
    .map((r) => ({ value: r.name, label: r.name }));
}

/** Exact membership: a near miss is refused, never corrected silently. */
export function isListedRegion(value: string, list: readonly string[]): boolean {
  return list.includes(value);
}

/**
 * Team edit form: the list, plus the team's current region when it is a legacy value (kept unchanged; the database
 * accepts an unchanged region and refuses a change to anything outside the list).
 */
export function teamRegionOptions(options: readonly RegionOption[], current: string | null): RegionOption[] {
  if (!current || options.some((o) => o.value === current)) return [...options];
  return [...options, { value: current, label: `${current} (${LEGACY_REGION_SUFFIX})` }];
}

export const LEGACY_REGION_SUFFIX = "bisheriger Wert, nicht zugeordnet";

export const REGION_NOT_IN_LIST_MESSAGE = "Bitte eine Region aus der Liste wählen.";
export const UNMAPPED_REGIONS_HEADING = "Region nicht zugeordnet";
export const UNMAPPED_REGIONS_INTRO =
  "Diese Regionsangaben stehen nicht auf der Regionsliste. Bitte jeder Angabe eine Region zuordnen; bis dahin gilt sie unverändert für die Teamsuche.";

const MAP_RESULT_TEXT: Record<string, string> = {
  ok: "Region zugeordnet.",
  duplicate: "Diese Zuordnung wurde bereits gespeichert.",
  already_mapped: "Dieser Wert ist bereits einer Region zugeordnet.",
  not_found: "Wert oder Region nicht gefunden. Bitte die Seite neu laden.",
  rejected: "Keine Berechtigung für die Zuordnung.",
};

export function mapRegionResultText(result: string): string {
  return MAP_RESULT_TEXT[result] ?? "Die Zuordnung konnte nicht gespeichert werden.";
}
