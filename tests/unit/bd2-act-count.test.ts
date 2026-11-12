import { describe, expect, it } from "vitest";
import { ActLog } from "../e2e/support/act-count";

// AUT-88 (brief BD): the BD-2 run counts the human acts per step and tags acts that exist only for the test.
// A measured baseline, never a limit: these tests check the counting and the table, not any number of acts.
describe("ActLog (AUT-88 act count)", () => {
  it("counts acts by kind under the current step, in step order", () => {
    const log = new ActLog();
    log.step("1 Anfrage");
    log.act("sign-in");
    log.act("input");
    log.act("input");
    log.act("submit");
    log.step("9 Abrechnung");
    log.act("tap");
    expect(log.rows()).toEqual([
      { step: "1 Anfrage", tap: 0, input: 2, submit: 1, "sign-in": 1, total: 4, testOnly: 0 },
      { step: "9 Abrechnung", tap: 1, input: 0, submit: 0, "sign-in": 0, total: 1, testOnly: 0 },
    ]);
  });

  it("counts test-only acts in the total and separately in the test-only column", () => {
    const log = new ActLog();
    log.step("5 Einsatz");
    log.act("tap");
    log.act("input", { testOnly: true });
    log.act("submit", { testOnly: true });
    const [row] = log.rows();
    expect(row).toMatchObject({ total: 3, testOnly: 2, tap: 1, input: 1, submit: 1 });
  });

  it("returns to an earlier step name without creating a second row", () => {
    const log = new ActLog();
    log.step("A");
    log.act("tap");
    log.step("B");
    log.act("tap");
    log.step("A");
    log.act("tap");
    expect(log.rows().map((r) => [r.step, r.total])).toEqual([["A", 2], ["B", 1]]);
  });

  it("refuses an act before any step, so no act goes uncounted", () => {
    const log = new ActLog();
    expect(() => log.act("tap")).toThrow(/step/);
  });

  it("can pause counting (helper actions that are no human act) and resume", () => {
    const log = new ActLog();
    log.step("A");
    log.pause();
    log.act("input");
    log.resume();
    log.act("tap");
    expect(log.rows()[0].total).toBe(1);
  });

  it("writes a markdown table with a total row and states it is a baseline, not a limit", () => {
    const log = new ActLog();
    log.step("1 Anfrage");
    log.act("input");
    log.act("submit");
    log.step("5 Einsatz");
    log.act("tap", { testOnly: true });
    const md = log.markdown();
    expect(md).toContain("| Schritt | Tippen | Eingaben | Absenden | Anmelden | Total | davon test-only |");
    expect(md).toContain("| 1 Anfrage | 0 | 1 | 1 | 0 | 2 | 0 |");
    expect(md).toContain("| 5 Einsatz | 1 | 0 | 0 | 0 | 1 | 1 |");
    expect(md).toContain("| **Total** | 1 | 1 | 1 | 0 | 3 | 1 |");
    expect(md).toMatch(/Basislinie, kein Grenzwert/);
  });
});
