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

// B1.1-1 (ADR-186 amendment 04:30; uxa UXR-184, UXR-185): counts, confirming step and result line of «Zuordnen».
export type RegionUseCounts = { teams: number; cases: number; referrals: number; open_searches: number };

type Part = { n: number; one: string; many: string; oneDat: string; manyDat: string };

function parts(row: RegionUseCounts): Part[] {
  return [
    { n: row.open_searches, one: "offene Teamsuche", many: "offene Teamsuchen", oneDat: "offenen Teamsuche", manyDat: "offenen Teamsuchen" },
    { n: row.referrals, one: "Anfrage", many: "Anfragen", oneDat: "Anfrage", manyDat: "Anfragen" },
    { n: row.cases, one: "Fall", many: "Fälle", oneDat: "Fall", manyDat: "Fällen" },
    { n: row.teams, one: "Team", many: "Teams", oneDat: "Team", manyDat: "Teams" },
  ].filter((p) => p.n > 0);
}

/** Open searches first, then referrals, cases, teams; zero counts left out; singular and plural. */
export function regionCountLine(row: RegionUseCounts): string {
  const p = parts(row);
  if (p.length === 0) return "Zurzeit von keinem Eintrag verwendet.";
  return p.map((x) => `${x.n} ${x.n === 1 ? x.one : x.many}`).join(" · ");
}

function joinGerman(items: string[]): string {
  if (items.length <= 1) return items.join("");
  return `${items.slice(0, -1).join(", ")} und ${items[items.length - 1]}`;
}

/**
 * The sentence of the confirming step. It claims only what the database does: the text is replaced in every row of
 * the organisation (private.rewrite_region), an open search can then be offered to the new region's teams (eligibility
 * is read at query time, 0017:358-374), and there is no reverse command.
 */
export function mapRegionConfirmSentence(from: string, to: string, row: RegionUseCounts): string {
  const p = parts(row);
  const where = p.length === 0 ? "" : `Bei ${joinGerman(p.map((x) => `${x.n} ${x.n === 1 ? x.oneDat : x.manyDat}`))} `;
  const first = p.length === 0
    ? `«${from}» wird durch «${to}» ersetzt.`
    : `${where}wird «${from}» durch «${to}» ersetzt.`;
  const search = row.open_searches > 0 ? ` Offene Teamsuchen können danach Teams in «${to}» angeboten werden.` : "";
  return `${first}${search} Die Zuordnung lässt sich hier nicht rückgängig machen.`;
}

export function mapRegionDoneText(from: string, to: string): string {
  return `Region zugeordnet: ${from} → ${to}`;
}

export const MAP_REGION_CONFIRM_LABEL = "Zuordnen";
