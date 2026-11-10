import { readdirSync, readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { overlapAfterSave, type OverlapFact } from "@/features/visits/overlap-rules";

/**
 * B0-3 part 3 (PRODUCT_BLOCKS.md §4, "Doppelbesuch, 30.10."), ADR-171. The recorded red result is the VIS2 e2e
 * (`tests/e2e/vis2.spec.ts`), run 40976503255, job 123805734721, PR head `64db2cd` (feat/vis2-same-client-overlap,
 * 2026-10-30 00:56 Europe/Zurich): `overlap-after-save` not found. pgTAP 098 has no red result in any failed `db` job
 * log from 2026-10-29 to 2026-11-10 (ADR-171 facts).
 *
 * Cause (IDENTIFIED from the code and the log): the "Heute machen" and planning forms read the client's overlap 250 ms
 * after the times change (`useOverlapNote`). The card's after-save notice appears only when the form had NOT shown the
 * overlap (`overlapAfterSave(shown, server)`). The old spec filled the times and clicked save at once, so whether the
 * notice appeared depended on whether the debounced read landed before the click: a race between the test and a timer.
 * 7279b53 (before #707 merged) made the spec wait for the read (`data-read="yes"`) and add the overlap in a second tab.
 *
 * This guard keeps that: (1) the mechanism, so the dependence is visible; (2) a static check that every save click in
 * a spec using the overlap note comes after a `data-read="yes"` wait for the last time change; (3) the checker flags
 * the old spec shape. It reads files only; no product function, rule or assertion changes.
 */
const E2E = "tests/e2e";
const read = (p: string) => readFileSync(p, "utf8");

const SAVE_CLICK = /getByRole\("button", \{ name: "(Auf heute verschieben|Einsatz speichern)" \}\)\.click\(\)/;
const TIME_FILL = /getByLabel\("(Von|Bis|Datum)"\)\.fill\(/;
const READ_WAIT = /toHaveAttribute\("data-read", "yes"\)/;

/**
 * Lines (1-based) of save clicks that follow a change of the slot (date, start, end) with no `data-read="yes"` wait in
 * between. Line-based and conservative: a branch that waits counts for the code after it.
 */
function unreadSaves(src: string): number[] {
  const out: number[] = [];
  let pending = false;
  src.split("\n").forEach((line, i) => {
    if (TIME_FILL.test(line)) pending = true;
    if (READ_WAIT.test(line)) pending = false;
    if (SAVE_CLICK.test(line) && pending) out.push(i + 1);
  });
  return out;
}

/** The VIS2-5 (2) block of `tests/e2e/vis2.spec.ts` at 7adbdf74 (first CI run red on 64db2cd), verbatim. */
const OLD_SHAPE = `
    await move.getByLabel("Von").fill(slots.free.start);
    await move.getByLabel("Bis").fill(slots.free.end);
    await expect(note).toHaveText("");

    // VIS2-5 (2): saved onto the overlap before the form re-read it: the move completes and the notice states it.
    await move.getByLabel("Grund der Verschiebung").fill("Synthetisch: heute erledigen");
    await move.getByLabel("Von").fill(slots.target.start);
    await move.getByLabel("Bis").fill(slots.target.end);
    await move.getByRole("button", { name: "Auf heute verschieben" }).click();
    await expect(page.getByTestId("moved-to-today")).toBeVisible();
    await expect(page.getByTestId("overlap-after-save")).toHaveText(overlapNote(today, todayVisit, today) ?? "");
`;

const specsUsingOverlapNote = () =>
  readdirSync(E2E)
    .filter((f) => f.endsWith(".spec.ts"))
    .filter((f) => /overlap-note|overlap-after-save/.test(read(`${E2E}/${f}`)));

describe("B0-3 part 3: VIS2 overlap read before save (Doppelbesuch, 30.10.)", () => {
  const fact: OverlapFact = { overlap: true, timeStart: "09:00", timeEnd: "09:30" };

  it("mechanism: the after-save notice depends on whether the form had shown the overlap (the raced value)", () => {
    expect(overlapAfterSave(false, fact)).toEqual(fact);
    expect(overlapAfterSave(true, fact)).toBeNull();
  });

  it("the overlap note exposes when its answer for the current times has arrived (data-read)", () => {
    const src = read("src/components/visits/OverlapNote.tsx");
    expect(src).toMatch(/data-read=\{answered \? "yes" : "no"\}/);
    expect(src).toMatch(/const answered = enabled && fact !== null && fact\.key === key;/);
  });

  it("the checker flags the old spec shape (save clicked right after the times changed)", () => {
    expect(unreadSaves(OLD_SHAPE)).toEqual([10]);
    expect(unreadSaves(OLD_SHAPE.replace('.fill(slots.target.end);\n', '.fill(slots.target.end);\n    await expect(note).toHaveAttribute("data-read", "yes");\n'))).toEqual([]);
  });

  it("vis2.spec.ts is among the specs checked", () => {
    expect(specsUsingOverlapNote()).toContain("vis2.spec.ts");
  });

  it.each(specsUsingOverlapNote())("%s: every save waits for the overlap read of the last time change", (file) => {
    expect(unreadSaves(read(`${E2E}/${file}`)), `save clicks without a data-read wait in ${file}`).toEqual([]);
  });

  it("vis2.spec.ts states the server re-check with a visit added meanwhile, not by out-running the read", () => {
    const src = read(`${E2E}/vis2.spec.ts`);
    expect(src).not.toMatch(/before the form re-read/);
    expect(src).toMatch(/page\.context\(\)\.newPage\(\)/);
  });
});
