// Q1 (a), ADR-220: which app commit and which database migration this build expects. Pure, unit-tested.
// The commit comes from Render at run time (RENDER_GIT_COMMIT); the migration level is fixed at build time from the
// highest file in supabase/migrations (next.config.ts sets NAVORA_MIGRATION). No database read, no secret.

export type AppVersion = { commit: string | null; migration: string | null };

const SHA = /^[0-9a-f]{7,40}$/;
const MIGRATION = /^\d{14}$/;

export function appVersion(env: Record<string, string | undefined>): AppVersion {
  const commit = env.RENDER_GIT_COMMIT?.trim().toLowerCase() ?? "";
  const migration = env.NAVORA_MIGRATION?.trim() ?? "";
  return { commit: SHA.test(commit) ? commit : null, migration: MIGRATION.test(migration) ? migration : null };
}

/**
 * The version of this running build. Next.js inlines a `next.config.ts` `env` value only where the code names it
 * literally (`process.env.NAVORA_MIGRATION`); passing the `process.env` object reads the run-time environment, where
 * Render sets no NAVORA_MIGRATION, so the migration level was empty on staging (staging-version red on c8339c8).
 */
export function runningVersion(): AppVersion {
  return appVersion({ RENDER_GIT_COMMIT: process.env.RENDER_GIT_COMMIT, NAVORA_MIGRATION: process.env.NAVORA_MIGRATION });
}

/** Highest migration version from the file names in supabase/migrations («20261021000152_name.sql» → «20261021000152»). */
export function highestMigration(files: readonly string[]): string | null {
  const versions = files.map((f) => /^(\d{14})_.+\.sql$/.exec(f)?.[1]).filter((v): v is string => !!v);
  return versions.length > 0 ? versions.sort().at(-1)! : null;
}

/** The footer line: «Version 5fcf223 · Datenbank 0152». */
export function versionLine(v: AppVersion): string {
  const commit = v.commit ? v.commit.slice(0, 7) : "lokal";
  const db = v.migration ? v.migration.slice(-4) : "unbekannt";
  return `Version ${commit} · Datenbank ${db}`;
}
