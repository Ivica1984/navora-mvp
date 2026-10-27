import { defineConfig, devices } from "@playwright/test";

// UX1-14 (ADR-103): screenshots of every protected route for the UX/UI Design Architect (`uxa`), uploaded by the CI job
// `ui-screenshots` as the artifact of the same name. Not a visual test: the job fails only on a render error. Images go
// to ui-screenshots/ (git-ignored) and are never committed. Against `next start` + local Supabase with the synthetic seed.
export default defineConfig({
  testDir: "./tests/screenshots",
  fullyParallel: false,
  workers: 1,
  retries: 0,
  forbidOnly: Boolean(process.env.CI),
  reporter: process.env.CI ? [["github"], ["list"]] : "list",
  outputDir: "test-results/screenshots",
  use: {
    baseURL: "http://127.0.0.1:3000",
    trace: "off",
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
  webServer: {
    command: "npm run start -- --hostname 127.0.0.1 --port 3000",
    url: "http://127.0.0.1:3000/login",
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
