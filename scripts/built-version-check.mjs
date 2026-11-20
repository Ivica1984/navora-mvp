#!/usr/bin/env node
// Q1 (a) fix (ADR-220 addendum): reads GET /api/version from the BUILT app (`next start`) and checks that it serves
// the highest migration in supabase/migrations. Unit tests pass plain objects and cannot see whether Next.js inlined
// NAVORA_MIGRATION into the build; this check can (staging-version was red on c8339c8 with «migration unknown»).
// Needs `npm run build` first. Reads nothing but the local app; no secret, no database.
import { spawn } from "node:child_process";
import { readdirSync } from "node:fs";

const port = process.env.VERSION_CHECK_PORT ?? "3199";
const files = readdirSync("supabase/migrations");
const want = files.map((f) => /^(\d{14})_.+\.sql$/.exec(f)?.[1]).filter(Boolean).sort().at(-1);
if (!want) {
  console.error("built-version-check: no migration file found");
  process.exit(1);
}

// No RENDER_GIT_COMMIT and no NAVORA_MIGRATION in the run-time environment, as on Render for the migration level.
const env = { ...process.env, RENDER_GIT_COMMIT: "0000000", NAVORA_MIGRATION: "" };
const server = spawn("npx", ["next", "start", "--hostname", "127.0.0.1", "--port", port], { env, stdio: "ignore", detached: true });
const stop = () => {
  try {
    process.kill(-server.pid, "SIGTERM"); // npx and the next-server child
  } catch {
    // already gone
  }
};

let body = null;
for (let i = 0; i < 60 && body === null; i++) {
  await new Promise((r) => setTimeout(r, 1000));
  try {
    const res = await fetch(`http://127.0.0.1:${port}/api/version`);
    if (res.ok) body = await res.json();
  } catch {
    // not up yet
  }
}
stop();

if (body === null) {
  console.error("built-version-check: the built app did not answer /api/version within 60 s");
  process.exit(1);
}
console.log(`built-version-check: /api/version = ${JSON.stringify(body)}, expected migration ${want}`);
if (body.migration !== want) {
  console.error(`built-version-check: the build serves migration ${body.migration}, expected ${want}`);
  process.exit(1);
}
if (body.commit !== "0000000") {
  console.error(`built-version-check: the commit must come from RENDER_GIT_COMMIT at run time, got ${body.commit}`);
  process.exit(1);
}
console.log("built-version-check: ok");
