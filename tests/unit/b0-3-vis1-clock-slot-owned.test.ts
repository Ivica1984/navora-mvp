import { readdirSync, readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { prefillMoveTimes } from "@/features/field/rules";

/**
 * B0-3 part 4 (PRODUCT_BLOCKS.md §4, "VIS1 Feldaktionen, 30.10."), ADR-172. The recorded red results are the VIS1 e2e
 * `tests/e2e/vis1.spec.ts` "VIS1-4 / VIS1-3a / VIS1-3b": 16 failed e2e jobs from 2026-10-28 23:39 to 2026-10-30 20:44
 * Europe/Zurich, 12 of them on `recovery/main` heads (603effc, 808f10c, b1011f2, 1500cb3, 439e556, 440af82, 40d6958). None since #781 merged (`7388674`, 2026-10-30 23:24): 117 green push runs on `recovery/main` to `169dde2`,
 * 19 of them started 18:00–23:00 Zurich (ADR-172 facts).
 *
 * Cause (IDENTIFIED in ADR-127, CGR-96, issue #693; reproduced in the database by pgTAP 102): "Heute machen" prefills
 * the next full five minutes after the real clock (`prefillMoveTimes`, VIS1-3c), and earlier specs plan other
 * Testfall 08 visits today at fixed slots (ux1.spec 20:45–21:15, vis1-10.spec 22:40–23:10, lifecycle.spec 16:00 to
 * 20:00). In an evening run the moved visit lands on such a slot, so an exact count of "the cards (or list items)
 * named by that slot" sees two different visits. Deterministic by the hour of the run, so it looked like a flake.
 * #764 (`/field`: count before + 1, the moved card is the focused one) and #781 (`/team`: the item carrying this
 * run's unique move reason) fixed both locations.
 *
 * This guard keeps that: (1) the mechanism, at the clock times of real failures; (2) a static check that no e2e spec
 * asserts an exact count on a locator named by a clock-derived slot unless the locator is owned (focus or a per-run
 * unique value); (3) the checker flags both old shapes. It reads files only; no product function, rule or assertion
 * changes.
 */
const E2E = "tests/e2e";
const read = (p: string) => readFileSync(p, "utf8");

const CLOCK_SEED = /\bprefillMoveTimes\(/;
const RUN_UNIQUE = /Date\.now\(\)|randomUUID\(/;
const OWNED = /locator\(":focus"\)/;
const EXACT_COUNT = /toHaveCount\(\s*\d+\s*\)/;
const DECL = /^\s*(?:const|let)\s+([A-Za-z_$][\w$]*)\s*=\s*([\s\S]*)$/;

// An identifier, not a word inside a test id or text ("moved" is not in "moved-to-today").
const mentions = (text: string, names: Set<string>) =>
  [...names].some((n) => new RegExp(`(?<![\\w$.-])${n.replace(/\$/g, "\\$")}(?![\\w$-])`).test(text));

/**
 * Statements (1-based line of their start) that assert an exact count on a locator derived from the clock-dependent
 * prefill. Names are tainted by assignment from `prefillMoveTimes(` and by any assignment whose right side mentions
 * a tainted name; an assignment that also anchors on focus or mentions a per-run unique name is owned, not tainted.
 * Statement-based (split on `;`), so a locator built over several lines counts as one statement. Conservative: a
 * name reused in another test of the same file stays tainted.
 */
export function clockSlotExactCounts(src: string): number[] {
  const tainted = new Set<string>();
  const unique = new Set<string>();
  const out: number[] = [];
  let line = 1;
  // Line comments are removed first (newlines kept), so a ";" inside a comment does not split a statement.
  for (const stmt of src.replace(/(^|\s)\/\/.*$/gm, "$1").split(";")) {
    const startLine = line + (stmt.match(/^\s*/)?.[0].split("\n").length ?? 1) - 1;
    line += stmt.split("\n").length - 1;
    const code = stmt;
    const decl = code.match(DECL);
    if (decl) {
      const [, name, rhs] = decl;
      if (RUN_UNIQUE.test(rhs)) unique.add(name);
      const owned = OWNED.test(rhs) || mentions(rhs, unique);
      if (!owned && (CLOCK_SEED.test(rhs) || mentions(rhs, tainted))) tainted.add(name);
      else tainted.delete(name);
      continue;
    }
    if (EXACT_COUNT.test(code) && mentions(code, tainted) && !OWNED.test(code) && !mentions(code, unique)) out.push(startLine);
  }
  return out;
}

/** `tests/e2e/vis1.spec.ts` at `eae9a14^1` (before #764): the `/field` slot asserted as exactly one card, verbatim. */
const OLD_FIELD_SHAPE = `
    const expected = prefillMoveTimes(zurichMinutesNow(pinned), "22:00", "22:30");
    const times = expected.start ? expected : { start: "23:00", end: "23:30" };
    const slot = \`\${times.start} – \${times.end}, Testfall 08\`;
    const moved = page.getByRole("article", { name: slot });
    await expect(moved).toHaveCount(1);
`;

/** `tests/e2e/vis1.spec.ts` at `7388674^1` (before #781): the `/team` item located by day and times, verbatim. */
const OLD_TEAM_SHAPE = `
    const reason = "Synthetisch: Klientin bittet um heute";
    const expected = prefillMoveTimes(zurichMinutesNow(pinned), "22:00", "22:30");
    const times = expected.start ? expected : { start: "23:00", end: "23:30" };
    const upcoming = page.getByRole("article", { name: /Fall Testfall 08/ }).getByRole("list", { name: "Geplante Einsätze" });
    const movedItem = upcoming.getByRole("listitem")
      .filter({ hasText: formatDayLabel(zurichDay()) })
      .filter({ hasText: \`\${times.start}–\${times.end}\` });
    await expect(movedItem).toHaveCount(1);
`;

const specs = () => readdirSync(E2E).filter((f) => f.endsWith(".spec.ts"));

describe("B0-3 part 4: VIS1 e2e owns its clock-dependent slot (Feldaktionen, 30.10.)", () => {
  it("mechanism: in an evening run the prefill lands on a fixed slot another spec planned for today", () => {
    // At 20:41 and 22:36 Zurich the moved 30-minute card lands on ux1.spec's 20:45–21:15 and vis1-10.spec's 22:40–23:10.
    expect(prefillMoveTimes(20 * 60 + 41, "22:00", "22:30")).toEqual({ start: "20:45", end: "21:15" });
    expect(prefillMoveTimes(22 * 60 + 36, "22:00", "22:30")).toEqual({ start: "22:40", end: "23:10" });
    // After 23:25 there is no prefill (VIS1-3c), so the spec types its own slot.
    expect(prefillMoveTimes(23 * 60 + 30, "22:00", "22:30")).toEqual({ start: "", end: "" });
  });

  it("the checker flags both old shapes and accepts the owned ones", () => {
    expect(clockSlotExactCounts(OLD_FIELD_SHAPE)).toEqual([6]);
    expect(clockSlotExactCounts(OLD_TEAM_SHAPE)).toEqual([9]);
    const fieldFixed = OLD_FIELD_SHAPE.replace('{ name: slot });', '{ name: slot }).and(page.locator(":focus"));');
    expect(clockSlotExactCounts(fieldFixed)).toEqual([]);
    const teamFixed = OLD_TEAM_SHAPE
      .replace('"Synthetisch: Klientin bittet um heute";', "`Synthetisch: Klientin bittet um heute (Lauf ${Date.now().toString(36)})`;")
      .replace(/\.filter\(\{ hasText: formatDayLabel[\s\S]*?\}\);/, ".filter({ hasText: `Verschoben von dir: ${reason}` });");
    expect(clockSlotExactCounts(teamFixed)).toEqual([]);
    // A count relative to what was in the slot before is not an exact count.
    expect(clockSlotExactCounts(`${OLD_FIELD_SHAPE.split("    await")[0]}    await expect(page.getByRole("article", { name: slot })).toHaveCount(before + 1);\n`)).toEqual([]);
  });

  it("no e2e spec asserts an exact count on a locator named by the clock-dependent prefill", () => {
    const found = specs().flatMap((f) => clockSlotExactCounts(read(`${E2E}/${f}`)).map((l) => `${f}:${l}`));
    expect(found).toEqual([]);
  });

  it("vis1.spec keeps the CGR-96 ownership: unique move reason, count before + 1, the moved card by focus", () => {
    const src = read(`${E2E}/vis1.spec.ts`);
    expect(src).toMatch(/const reason = `Synthetisch: Klientin bittet um heute \(Lauf \$\{Date\.now\(\)\.toString\(36\)\}\)`;/);
    expect(src).toMatch(/const before = await page\.getByRole\("article", \{ name: slot \}\)\.count\(\);/);
    expect(src).toMatch(/toHaveCount\(before \+ 1\)/);
    expect(src).toMatch(/const moved = page\.getByRole\("article", \{ name: slot \}\)\.and\(page\.locator\(":focus"\)\);/);
    expect(src).toMatch(/filter\(\{ hasText: `Verschoben von dir: \$\{reason\}` \}\)/);
  });

  it("the database reproduction stays: one move into an occupied slot adds no visit (pgTAP 102)", () => {
    const sql = read("supabase/tests/database/102_cgr96_one_move_one_visit.test.sql");
    expect(sql).toMatch(/move_visit_to_today/);
    expect(sql).toMatch(/plan\(\s*13\s*\)/);
  });
});
