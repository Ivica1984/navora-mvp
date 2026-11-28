// AUT-88 (brief BD, `aia`): the BD-2 run counts the human acts per step (taps, inputs, form submits, sign-ins) and tags
// each act that exists only for the test (e.g. the F3 «Testlauf» correction) as test-only. It is the first measured
// baseline for value order 5 (less administration). It is NOT a target and is never asserted as a limit.
// Pure module (no Playwright import), unit-tested in tests/unit/bd2-act-count.test.ts.

export type ActKind = "tap" | "input" | "submit" | "sign-in";

export type ActRow = {
  step: string;
  tap: number;
  input: number;
  submit: number;
  "sign-in": number;
  total: number;
  testOnly: number;
};

const KINDS: ActKind[] = ["tap", "input", "submit", "sign-in"];

export class ActLog {
  private readonly byStep = new Map<string, ActRow>();
  private current: ActRow | null = null;
  private paused = 0;

  step(name: string): void {
    let row = this.byStep.get(name);
    if (!row) {
      row = { step: name, tap: 0, input: 0, submit: 0, "sign-in": 0, total: 0, testOnly: 0 };
      this.byStep.set(name, row);
    }
    this.current = row;
  }

  /** Helper actions that are no human act (e.g. the fields inside one counted sign-in). */
  pause(): void {
    this.paused += 1;
  }

  resume(): void {
    if (this.paused > 0) this.paused -= 1;
  }

  act(kind: ActKind, options: { testOnly?: boolean } = {}): void {
    if (this.paused > 0) return;
    if (!this.current) throw new Error("ActLog: an act was recorded before any step was named");
    this.current[kind] += 1;
    this.current.total += 1;
    if (options.testOnly) this.current.testOnly += 1;
  }

  rows(): ActRow[] {
    return [...this.byStep.values()].map((r) => ({ ...r }));
  }

  markdown(): string {
    const rows = this.rows();
    const sum: ActRow = { step: "**Total**", tap: 0, input: 0, submit: 0, "sign-in": 0, total: 0, testOnly: 0 };
    for (const r of rows) {
      for (const k of KINDS) sum[k] += r[k];
      sum.total += r.total;
      sum.testOnly += r.testOnly;
    }
    const line = (r: ActRow) => `| ${r.step} | ${r.tap} | ${r.input} | ${r.submit} | ${r["sign-in"]} | ${r.total} | ${r.testOnly} |`;
    return [
      "AUT-88: menschliche Handlungen pro Schritt im BD-2-Durchgang (gemessene Basislinie, kein Grenzwert).",
      "",
      "| Schritt | Tippen | Eingaben | Absenden | Anmelden | Total | davon test-only |",
      "|---|---|---|---|---|---|---|",
      ...rows.map(line),
      line(sum),
    ].join("\n");
  }
}
