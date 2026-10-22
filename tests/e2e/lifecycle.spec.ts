import { expect, test, type Page } from "@playwright/test";

// C1 — case lifecycle on /team. Synthetic local-only accounts from supabase/seed.sql.
const NURSE = "pflege.test@navora.test"; // Testteam Nord (case Testfall 08)
const PASSWORD = "navora-local-only";

async function signIn(page: Page, email: string, landing: RegExp) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(landing);
}

test("the team pauses a case with a reason and resumes it (C1)", async ({ page }) => {
  await signIn(page, NURSE, /\/field$/);
  await page.goto("/team");
  const card = page.getByRole("article", { name: /Fall Testfall 08/ });
  const lifecycle = card.getByTestId("case-lifecycle");

  await lifecycle.getByRole("button", { name: "Pausieren" }).click();
  const form = lifecycle.getByRole("form", { name: "Fall pausieren" });
  await expect(form.locator("select[name=code]")).toHaveAttribute("required", "");   // a reason is required
  await form.locator("select[name=code]").selectOption("hospital_stay");
  await form.getByRole("button", { name: "Pausieren" }).click();
  await expect(lifecycle.getByTestId("case-paused")).toContainText("Spitalaufenthalt");

  await lifecycle.getByRole("button", { name: "Fortsetzen" }).click();
  await expect(lifecycle.getByTestId("case-paused")).toHaveCount(0);
  await expect(lifecycle.getByRole("button", { name: "Pausieren" })).toBeVisible();
});
