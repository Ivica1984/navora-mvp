import { defineConfig, devices } from "@playwright/test";
import { stagingTarget } from "./tests/staging-smoke/target";

// ADR-205: the founder's click paths against the real staging app (navora-staging), started by hand
// (.github/workflows/staging-smoke.yml). No web server, no local Supabase, no seed: it only uses the browser, with the
// demo accounts' passwords from repository secrets. No trace, no video, no HTML report and no artifact, because a
// trace would record the typed password; failures are read from the log and its screenshots are not uploaded.
export default defineConfig({
  testDir: "./tests/staging-smoke",
  fullyParallel: false,
  workers: 1,
  retries: 0,
  forbidOnly: Boolean(process.env.CI),
  reporter: process.env.CI ? [["github"], ["list"]] : "list",
  outputDir: "test-results/staging-smoke",
  timeout: 180_000,
  expect: { timeout: 20_000 },
  use: {
    baseURL: stagingTarget(process.env),
    trace: "off",
    video: "off",
    screenshot: "off",
    navigationTimeout: 90_000, // a Render instance that slept wakes in up to about a minute
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
});
