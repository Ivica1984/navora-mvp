import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

/**
 * D-18 clinical invariant (I1) (`cra` template 2026-11-11 05:26, docs/agents/decisions/D-18.md; Engineering input
 * requested by `po` 2026-11-11 05:39): no planning, proposal, reminder or AI code reads a billing parameter (minimum,
 * unit, rate). The database side is pinned by pgTAP 125 (catalogue of the functions that read `billing_rules` and
 * `tariff_rates`). This is the app side: the modules that plan, propose, remind, run the field day or hold AI code never
 * import the billing module or name a billing table, the billing preview or the billable facts.
 * A new import fails here and must be reviewed against (I1); the list is never narrowed to get green.
 */

/** The app folders that plan, propose, remind, run the field day or hold AI code (src-relative). */
const GUARDED = [
  "features/planning",
  "features/ai",
  "features/field",
  "features/cover",
  "features/absence",
  "features/signals",
  "features/work",
  "features/handover",
  "features/visits",
  "features/qualification",
  "app/(protected)/field",
  "app/(protected)/visits",
  "app/(protected)/work",
];

/** Billing module imports, billing tables and the billing read, as they would appear in app code. */
const BILLING = /@\/features\/billing|@\/components\/billing|\bbilling_preview\b|\bbilling_rules\b|\btariff_rates\b|\bmin_billable_minutes\b|\bbillable_facts\b/;

const SRC = join(process.cwd(), "src");

function files(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) return files(path);
    return /\.(ts|tsx)$/.test(name) ? [path] : [];
  });
}

describe("D-18 (I1): planning, proposal, reminder, field and AI code reads no billing parameter", () => {
  it("every guarded folder exists, so the guard cannot pass by a rename", () => {
    for (const dir of GUARDED) {
      expect(statSync(join(SRC, dir)).isDirectory(), dir).toBe(true);
    }
  });

  it("finds source files to check", () => {
    const count = GUARDED.reduce((n, dir) => n + files(join(SRC, dir)).length, 0);
    expect(count).toBeGreaterThan(20);
  });

  it("no guarded file imports the billing module or names a billing table or the billing preview", () => {
    const offenders = GUARDED.flatMap((dir) => files(join(SRC, dir)))
      .filter((path) => BILLING.test(readFileSync(path, "utf8")))
      .map((path) => path.slice(SRC.length + 1));
    expect(offenders).toEqual([]);
  });

  it("the pattern does catch a billing import (self-check)", () => {
    expect(BILLING.test('import { getBillingPreview } from "@/features/billing/queries";')).toBe(true);
    expect(BILLING.test('supabase.rpc("billing_preview", { p_month })')).toBe(true);
    expect(BILLING.test("select * from public.tariff_rates")).toBe(true);
    expect(BILLING.test('import { planDay } from "@/features/planning/day-plan";')).toBe(false);
  });
});
