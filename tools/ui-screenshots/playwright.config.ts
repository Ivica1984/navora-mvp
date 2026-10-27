import { defineConfig } from "@playwright/test";

// Temporary: UI feature inventory screenshots on the synthetic seed. Not part of CI.
export default defineConfig({
  testDir: ".",
  fullyParallel: false,
  workers: 1,
  retries: 0,
  timeout: 120_000,
  reporter: "list",
  use: { baseURL: "http://127.0.0.1:3000" },
  webServer: {
    command: "npm run start -- --hostname 127.0.0.1 --port 3000",
    url: "http://127.0.0.1:3000/login",
    reuseExistingServer: false,
    timeout: 120_000,
  },
});
