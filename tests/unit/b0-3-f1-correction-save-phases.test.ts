import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

/**
 * B0-3 part 5 (PRODUCT_BLOCKS.md §4, "F1 Gegenzeichnung, 30.10."), ADR-173. The one recorded red result is
 * `tests/e2e/field.spec.ts` "a care assistant signs what she sees; … countersigns the corrected version (F6R)" on
 * `recovery/main` @ `54f1706` (push run 41010933538, job 123916409154, 2026-10-30 06:56 Europe/Zurich), at the
 * departure correction: after "Korrektur speichern" the row was expected to read "korrigiert" within 5 s. The call
 * log shows the form still open (12 polls: "Richtige Uhrzeit … Korrektur speichern Abbrechen"), then closed with the
 * old row ("Losgefahren 06:56 Korrigieren", 2 polls). No `command.failed` was logged for that test, so the command
 * did not error; a refusal keeps the form open, so it closed on `ok` or `duplicate`. Not seen again in any failed or
 * re-attempted run since (ADR-173 facts). The Playwright trace expired (7-day retention), so the step that took the
 * time (the command, the revalidated render, or the refresh) is UNKNOWN; the cause is OPEN and not reproduced.
 *
 * This change does not claim a fix. It splits the single 5 s wait into the save's own outcome (the form closes, which
 * happens only on `ok`) and the refreshed row, each with its own message, so a recurrence names its phase. It reads the spec only;
 * no product code, rule or assertion is weakened.
 */
const SPEC = "tests/e2e/field.spec.ts";
const SAVE = 'getByRole("button", { name: "Korrektur speichern" }).click()';

/** Lines (1-based) of every "Korrektur speichern" click and the statements that follow it, up to the next click. */
function saves(src: string): { line: number; after: string[] }[] {
  const lines = src.split("\n");
  const out: { line: number; after: string[] }[] = [];
  lines.forEach((l, i) => {
    if (!l.includes(SAVE)) return;
    const after: string[] = [];
    for (let j = i + 1; j < lines.length && after.length < 6; j++) {
      const t = lines[j].trim();
      if (!t || t.startsWith("//")) continue;
      after.push(t);
    }
    out.push({ line: i + 1, after });
  });
  return out;
}

/** A save that is meant to succeed: the next assertion is not the refusal's `command-error`. */
const meantToSucceed = (s: { after: string[] }) => !/getByTestId\("command-error"\)\)\.toContainText/.test(s.after[0] ?? "");

/** Problems in one successful save: the row's "korrigiert" is asserted before the save's own outcome. */
function phaseProblems(s: { line: number; after: string[] }): string[] {
  const korr = s.after.findIndex((t) => /toContainText\("korrigiert"\)/.test(t));
  if (korr < 0) return [`${s.line}: no "korrigiert" assertion after the save`];
  const closed = s.after.findIndex((t) => /getByLabel\("Richtige Uhrzeit"\)(?:,\s*"[^"]*")?\)\.toHaveCount\(0\)/.test(t));
  const problems: string[] = [];
  // The form's field, not the button: the button's label also changes while the save is pending.
  if (closed < 0 || closed > korr) problems.push(`${s.line}: the form's close is not awaited before "korrigiert"`);
  if (!/expect\([^,]+,\s*"B0-3/.test(s.after[korr])) problems.push(`${s.line}: the "korrigiert" assertion names no phase`);
  return problems;
}

describe("B0-3 part 5: an F1 time correction waits for the save's outcome before the refreshed row (ADR-173)", () => {
  it("field.spec has the three corrections: one refused, two meant to succeed", () => {
    const all = saves(readFileSync(SPEC, "utf8"));
    expect(all).toHaveLength(3);
    expect(all.filter(meantToSucceed)).toHaveLength(2);
  });

  it("every successful correction asserts the form closed, then the row, with a phase message", () => {
    const problems = saves(readFileSync(SPEC, "utf8")).filter(meantToSucceed).flatMap(phaseProblems);
    expect(problems).toEqual([]);
  });

  it("the checker flags the shape of the 30.10. failure (verbatim) and accepts the split form", () => {
    const old = [
      `    await departed.${SAVE};`,
      '    await expect(departed).toContainText("korrigiert");',
    ].join("\n");
    const fixed = [
      `    await departed.${SAVE};`,
      '    await expect(departed.getByLabel("Richtige Uhrzeit"), "B0-3 part 5: the save returns ok").toHaveCount(0);',
            '    await expect(departed, "B0-3 part 5: the refreshed row").toContainText("korrigiert");',
    ].join("\n");
    expect(saves(old).flatMap(phaseProblems).length).toBeGreaterThan(0);
    expect(saves(fixed).flatMap(phaseProblems)).toEqual([]);
  });

  it("the refused correction still asserts its refusal text (unchanged)", () => {
    const refused = saves(readFileSync(SPEC, "utf8")).filter((s) => !meantToSucceed(s));
    expect(refused).toHaveLength(1);
    expect(refused[0].after[0]).toContain('toContainText("Reihenfolge")');
  });
});
