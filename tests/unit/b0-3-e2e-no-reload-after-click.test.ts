import { readdirSync, readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

/**
 * B0-3 (PRODUCT_BLOCKS.md §4), issue #979, ADR-169. `ux2-gates.spec.ts` "UX2-23: removing a contract end …" failed on
 * `recovery/main` @ `3eea970` (run 41038213616) and @ `be2af00` (run 42374741556), each time at line 129: after
 * `page.reload()` the line `contract-end-line` did not exist. The step before was `click()` on "Speichern", which
 * starts a server action (a POST to /admin); the next statement reloaded the page at once. A reload while that POST
 * is still in flight aborts it, so on a slow runner the contract end was never recorded and the reloaded page showed
 * none. The cause is the test's order, not the product: the save is a single command that either reaches the
 * database or not, and the page shows its result (notice or error) only after it returns.
 *
 * This guard keeps every e2e spec from navigating (reload, goto) straight after a click: between the two there must
 * be an awaited assertion on the click's result. It reads the spec files only; no product code, rule or assertion
 * changes.
 */
const DIR = "tests/e2e";

/** Statements of a spec, one per `await …;` line group, with `//` comments removed. */
function statements(src: string): { line: number; text: string }[] {
  const out: { line: number; text: string }[] = [];
  let buf = "";
  let start = 0;
  src.split("\n").forEach((raw, i) => {
    const at = raw.indexOf("//");
    const line = (at >= 0 && !raw.slice(0, at).includes('"') && !raw.slice(0, at).includes("`") ? raw.slice(0, at) : raw).trim();
    if (!line) return;
    if (!buf) start = i + 1;
    buf += (buf ? " " : "") + line;
    if (/[;{}]$/.test(line)) {
      out.push({ line: start, text: buf });
      buf = "";
    }
  });
  return out;
}

const CLICK = /\.(click|press|check|uncheck|selectOption)\(/;
const NAVIGATE = /^await page\.(reload|goto)\(/;

function clickThenNavigate(src: string): number[] {
  const s = statements(src);
  const hits: number[] = [];
  for (let i = 1; i < s.length; i++) {
    if (NAVIGATE.test(s[i].text) && s[i - 1].text.startsWith("await ") && CLICK.test(s[i - 1].text)) hits.push(s[i].line);
  }
  return hits;
}

describe("B0-3 (#979): no e2e spec navigates away straight after a click", () => {
  it("detects the pattern that lost the contract end (self-test)", () => {
    const bad = [
      'await form.getByRole("button", { name: "Speichern" }).click();',
      "await page.reload();",
    ].join("\n");
    expect(clickThenNavigate(bad)).toEqual([2]);
    const good = [
      'await form.getByRole("button", { name: "Speichern" }).click();',
      'await expect(notice).toHaveText(/^Vertragsende gespeichert\\./);',
      "await page.reload();",
    ].join("\n");
    expect(clickThenNavigate(good)).toEqual([]);
  });

  const specs = readdirSync(DIR).filter((f) => f.endsWith(".ts"));
  it("reads the e2e specs", () => expect(specs.length).toBeGreaterThan(5));
  for (const f of specs) {
    it(`${f}: every reload or goto after a click waits for the click's result first`, () => {
      expect(clickThenNavigate(readFileSync(`${DIR}/${f}`, "utf8"))).toEqual([]);
    });
  }

  it("UX2-23 waits for the saved contract end before it reloads, under a delayed save", () => {
    const src = readFileSync(`${DIR}/ux2-gates.spec.ts`, "utf8");
    const save = src.indexOf('getByRole("button", { name: "Speichern" }).click()');
    expect(save).toBeGreaterThan(0);
    const after = src.slice(save);
    const reload = after.indexOf("await page.reload()");
    const saved = after.indexOf("Vertragsende gespeichert");
    expect(saved).toBeGreaterThan(0);
    expect(saved).toBeLessThan(reload);
    // The reproduction stays in the test: the save's POST is held back, so a missing wait fails every time.
    expect(src).toContain("holdServerActions");
  });
});
