// BK-e1b / UXR-239 (`uxa` 04:48; PO 05:39; `cra` accepts it for the simulation; ADR-203 (11)): the heading of a /field
// visit card. A visit written from a take has no case, so «Klient:in ohne Namen» would read as missing data on every
// take card; the heading names the kind instead. Which client identifier the named member may see after «gedeckt» is
// UNKNOWN (`lca`, CGR-243, proposed BK-e3), so a take card shows none.

export const TAKE_HEADING = "Übernommene Schicht";
export const CLIENT_WITHOUT_NAME = "Klient:in ohne Namen";

export function visitHeading(clientName: string | null | undefined, fromTake: boolean | null | undefined): string {
  if (fromTake) return TAKE_HEADING;
  return clientName ?? CLIENT_WITHOUT_NAME;
}

// HD-3s-F2 (brief scope 3; ADR-229 (3)): a two-block take writes one visit per block; each /field card names its block
// and BOTH blocks, never only one. `blocks` comes from public.field_visits (take_blocks, migration 0184). Fail closed: a
// missing or partial value shows no line rather than half a day.
export function takeBlocksLine(block: number | null | undefined, blocks: string | null | undefined): string | null {
  if ((block !== 1 && block !== 2) || !blocks) return null;
  return `Teil ${block} von 2 · Geteilter Dienst ${blocks}`;
}
