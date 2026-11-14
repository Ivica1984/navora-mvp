import { mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, relative, sep } from "node:path";
import { afterAll, describe, expect, it } from "vitest";

/**
 * D-18 clinical invariant (I1) (`cra` template 2026-11-11 05:26, docs/agents/decisions/D-18.md; Engineering input
 * requested by `po` 2026-11-11 05:39): no planning, proposal, reminder or AI code reads a billing parameter (minimum,
 * unit, rate). The database side is pinned by pgTAP 125 (catalogue of the functions that read `billing_rules` and
 * `tariff_rates`). This is the app side.
 *
 * Deny by default (AUT-87, `aia` 2026-11-11 08:20; PO ask on #1064 08:39): every `.ts`/`.tsx` file under `src` is
 * guarded except the named billing readers below. A new file that imports the billing module or names a billing table,
 * the billing preview or the billable facts fails here, in whatever folder it is added, and must be reviewed against
 * (I1) by `cra` before it is added to the list. The list is never extended to get green without that review.
 */

/** The billing readers as of 2026-11-11 (src-relative, `/` separators). Each must exist and must still match. */
const BILLING_READERS = [
  "features/billing/queries.ts",
  "components/billing/billing-preview.tsx",
  "features/analytics/hypotheses.ts",
  "app/(protected)/analytics/page.tsx",
  "app/(protected)/operations/page.tsx",
  "app/(protected)/operations/operations-client.tsx",
  "app/(protected)/team/page.tsx",
  "app/(protected)/team/team-client.tsx",
  "lib/supabase/database.types.ts",
];

/**
 * Billing module imports (alias or relative path into a `billing` folder), billing tables and the billing read, as they
 * would appear in app code.
 */
const BILLING =
  /@\/features\/billing|@\/components\/billing|["'][^"'\n]*\/billing(?:\/[^"'\n]*)?["']|\bbilling_preview\b|\bbilling_rules\b|\btariff_rates\b|\bmin_billable_minutes\b|\bbillable_facts\b/;

const SRC = join(process.cwd(), "src");

function files(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) return files(path);
    return /\.(ts|tsx)$/.test(name) ? [path] : [];
  });
}

const rel = (root: string, path: string) => relative(root, path).split(sep).join("/");

/** Every `.ts`/`.tsx` file under `root` that reads billing and is not on `allowed` (root-relative paths). */
function billingOffenders(root: string, allowed: readonly string[]): string[] {
  const allow = new Set(allowed);
  return files(root)
    .map((path) => rel(root, path))
    .filter((path) => !allow.has(path))
    .filter((path) => BILLING.test(readFileSync(join(root, path), "utf8")))
    .sort();
}

describe("D-18 (I1): no code outside the named billing readers reads a billing parameter (deny by default)", () => {
  it("scans the whole src tree", () => {
    expect(files(SRC).length).toBeGreaterThan(150);
  });

  it("no file outside the named billing readers imports billing or names a billing table or the billing preview", () => {
    expect(billingOffenders(SRC, BILLING_READERS)).toEqual([]);
  });

  it("every named billing reader exists and still reads billing, so the list holds no stale entry", () => {
    for (const path of BILLING_READERS) {
      const full = join(SRC, path);
      expect(statSync(full).isFile(), path).toBe(true);
      expect(BILLING.test(readFileSync(full, "utf8")), path).toBe(true);
    }
  });

  it("the planning, proposal, field and AI folders are not on the list", () => {
    const planning = [
      "features/planning/",
      "features/ai/",
      "features/field/",
      "features/assessment/",
      "features/cases/",
      "features/team/",
      "app/(protected)/team/tagesplan/",
      "app/(protected)/team/vorschlaege/",
      "app/(protected)/team/auto-plan.tsx",
      "app/(protected)/field/",
    ];
    for (const path of BILLING_READERS) {
      for (const prefix of planning) expect(path.startsWith(prefix), `${path} under ${prefix}`).toBe(false);
    }
  });

  it("the pattern catches a billing import and leaves a planning import alone (self-check)", () => {
    expect(BILLING.test('import { getBillingPreview } from "@/features/billing/queries";')).toBe(true);
    expect(BILLING.test('import { getBillingPreview } from "../billing/queries";')).toBe(true);
    expect(BILLING.test('import { BillingPreview } from "../../components/billing";')).toBe(true);
    expect(BILLING.test('supabase.rpc("billing_preview", { p_month })')).toBe(true);
    expect(BILLING.test("select * from public.tariff_rates")).toBe(true);
    expect(BILLING.test('import { planDay } from "@/features/planning/day-plan";')).toBe(false);
    expect(BILLING.test('import { billingLabel } from "@/lib/labels";')).toBe(false);
  });

  describe("fixture: a new, unlisted folder that imports billing fails the guard", () => {
    const root = mkdtempSync(join(tmpdir(), "d18-i1-"));
    const write = (path: string, body: string) => {
      mkdirSync(dirname(join(root, path)), { recursive: true });
      writeFileSync(join(root, path), body);
    };
    write("features/billing/queries.ts", 'export const read = () => supabase.rpc("billing_preview");\n');
    write("features/planning/day-plan.ts", 'import { x } from "@/features/planning/rules";\nexport const plan = x;\n');
    write(
      "features/new-proposer/propose.ts",
      'import { getBillingPreview } from "@/features/billing/queries";\nexport const propose = getBillingPreview;\n',
    );
    write("features/new-reminder/remind.tsx", 'import { read } from "../billing/queries";\nexport default read;\n');
    afterAll(() => rmSync(root, { recursive: true, force: true }));

    it("flags exactly the two new readers and passes the listed one", () => {
      expect(billingOffenders(root, ["features/billing/queries.ts"])).toEqual([
        "features/new-proposer/propose.ts",
        "features/new-reminder/remind.tsx",
      ]);
    });

    it("an empty list flags the billing module itself (nothing passes by default)", () => {
      expect(billingOffenders(root, [])).toContain("features/billing/queries.ts");
    });
  });
});
