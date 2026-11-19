import { expect, test } from "@playwright/test";

// DEMO1 (ADR-212): the one-click demo sign-in is offered only on the staging project (or a local stack with
// NAVORA_DEMO_LOGIN=1). CI runs a local stack without the flag, so the picker must not exist here (fail closed).
// The positive path (staging host → picker) is covered by tests/unit/demo-login.test.ts.
test("login page offers no demo sign-in without staging or the explicit flag", async ({ page }) => {
  await page.goto("/login");
  await expect(page.getByRole("heading", { name: "Bei NAVORA anmelden" })).toBeVisible();
  await expect(page.getByTestId("demo-picker")).toHaveCount(0);
  await expect(page.getByRole("button", { name: /Als Heim/ })).toHaveCount(0);
});
