import { defineConfig, devices } from "@playwright/test";
// Staging smoke only (unmerged probe branch): the real staging app, no local server.
export default defineConfig({
  testDir: ".",
  workers: 1,
  retries: 0,
  timeout: 300_000,
  reporter: [["github"], ["list"]],
  use: { baseURL: "https://navora-staging.onrender.com", navigationTimeout: 120_000, actionTimeout: 30_000, trace: "on" },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
});
