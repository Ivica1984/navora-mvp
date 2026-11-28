// BK-e1b / CGR-248, UXR-241 (#1428) and UXR-240 (PO 2026-11-18 06:39 (2), (3); `cra` 06:27; ADR-203 (13)): which
// actions the «Mehr» menu of a /field card offers. A visit written from a take offers no «Einsatz absagen»: the
// database refuses it (`cancel_visit` → `take_visit`, migration 0141), and the card says what to do instead. A take
// card whose take has ended offers no action at all. Every other visit is unchanged (UX1-8, ADR-104).

export type MoreItem = "cancel" | "hold";

/** Words confirmed by `cra` 06:27 for the simulation only. */
export const TAKE_CANNOT_GO_LINE =
  "Kannst du nicht? Melde dich sofort bei deinem Team. Die Schicht bleibt bei dir, bis sie geklärt ist.";

const BEFORE_START = new Set(["planned", "on_the_way"]);

export function fieldMoreItems(v: { status: string; fromTake: boolean; takeEnded: boolean; holdOpen: boolean }): MoreItem[] {
  if (v.fromTake && v.takeEnded) return [];
  const items: MoreItem[] = [];
  if (!v.fromTake && BEFORE_START.has(v.status)) items.push("cancel");
  if (!v.holdOpen) items.push("hold");
  return items;
}

export function showTakeCannotGoLine(v: { status: string; fromTake: boolean; takeEnded: boolean }): boolean {
  return v.fromTake && !v.takeEnded && BEFORE_START.has(v.status);
}
