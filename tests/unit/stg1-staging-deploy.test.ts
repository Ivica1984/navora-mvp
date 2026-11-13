import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

/**
 * STG1 (ADR-189; owner 2026-11-11: Supabase project `navora-staging` in Zurich, Free plan, built now as an exception to
 * FE-054): the `staging` job of ci.yml applies the repository's migrations to `navora-staging` only after all four
 * required jobs are green on a push to recovery/main, and only as a dry run on a pull request. Never the seed (it holds
 * sign-in accounts with a password that is public in this repository). Reads the workflow file only.
 */
const CI = readFileSync(join(process.cwd(), ".github/workflows/ci.yml"), "utf8");
const STAGING_REF = "qpmdryxkktbqqkqpsnkj";

/** The text of the `staging:` job (up to the next top-level job or the end). */
function stagingJob(src: string): string {
  const start = src.search(/^ {2}staging:\s*$/m);
  if (start < 0) return "";
  const rest = src.slice(start + 1);
  const next = rest.search(/^ {2}[a-z][\w-]*:\s*$/m);
  return next < 0 ? src.slice(start) : src.slice(start, start + 1 + next);
}

describe("STG1: staging deploy job in ci.yml", () => {
  const job = stagingJob(CI);

  it("exists and needs all four required jobs", () => {
    expect(job).not.toBe("");
    const needs = job.match(/^ {4}needs:\s*\[([^\]]*)\]/m)?.[1].split(",").map((s) => s.trim()).sort();
    expect(needs).toEqual(["app", "db", "e2e", "ui-screenshots"]);
  });

  it("targets only navora-staging (Zurich), never another project", () => {
    expect(job).toContain(`STAGING_PROJECT_REF: ${STAGING_REF}`);
    expect(CI).not.toContain("jwmfxrmougneeceldhsa");
    const refs = [...job.matchAll(/\b[a-z]{20}\b/g)].map((m) => m[0]);
    expect(new Set(refs)).toEqual(new Set([STAGING_REF]));
  });

  it("writes only on a push to recovery/main; a pull request gets a dry run", () => {
    const push = job.match(/- name: Apply migrations to navora-staging[\s\S]*?(?=\n {6}- name:|\n*$)/)?.[0] ?? "";
    expect(push).toMatch(/if: .*github\.event_name == 'push' && github\.ref == 'refs\/heads\/recovery\/main'/);
    expect(push).toMatch(/supabase db push(?! --dry-run)/);
    const plan = job.match(/- name: Dry run against navora-staging[\s\S]*?(?=\n {6}- name:|\n*$)/)?.[0] ?? "";
    expect(plan).toMatch(/if: .*github\.event_name == 'pull_request'/);
    expect(plan).toContain("supabase db push --dry-run");
    expect(job.match(/supabase db push(?! --dry-run)/g)).toHaveLength(1);
  });

  it("never sends the seed (public sign-in passwords) and never resets the database", () => {
    expect(job).not.toMatch(/--include-seed|db reset|seed\.sql/);
  });

  it("keeps secrets out of run lines: only as env values, never echoed", () => {
    const secretLines = job.split("\n").filter((l) => l.includes("secrets."));
    expect(secretLines.length).toBeGreaterThan(0);
    for (const l of secretLines) expect(l, l).toMatch(/^\s+[A-Z_]+: \$\{\{ secrets\.[A-Z_]+ \}\}\s*$/);
    // One secret, the Session pooler connection string; no Supabase account token (first CI run: a scoped account token
    // lacked `api_gateway_keys_read` for `supabase link`; the connection string needs no account-wide permission).
    expect(secretLines.map((l) => l.trim())).toEqual(["STAGING_DB_URL: ${{ secrets.STAGING_DB_URL }}"]);
    expect(job).not.toMatch(/SUPABASE_ACCESS_TOKEN|supabase link/);
    expect(job).not.toMatch(/echo[^\n]*\$\{?STAGING_DB_URL/);
  });

  it("refuses a connection string that does not name navora-staging, before any connection", () => {
    expect(job).toMatch(/\*"postgres\.\$STAGING_PROJECT_REF:"\*/);
    expect(job).toMatch(/does not name the project navora-staging"; exit 1/);
    expect(job.indexOf("does not name the project")).toBeLessThan(job.indexOf("supabase db push"));
  });

  it("does not run for pull requests from forks (no secrets there) and never two at once", () => {
    expect(job).toMatch(/github\.event\.pull_request\.head\.repo\.full_name == github\.repository/);
    expect(job).toMatch(/concurrency:\s*\n\s+group: staging-navora\s*\n\s+cancel-in-progress: false/);
  });
});
