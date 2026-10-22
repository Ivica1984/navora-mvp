import { expect, test, type Page } from "@playwright/test";

// J5 — billing preview: an estimate, never an invoice. Synthetic local-only accounts.
const NURSE = "pflege.test@navora.test";
const OPS = "ops.test@navora.test";
const PASSWORD = "navora-local-only";

async function signIn(page: Page, email: string, landing: RegExp) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(landing);
}

test("the team sees a labelled estimate and can create billing facts (J5)", async ({ page }) => {
  await signIn(page, NURSE, /\/field$/);
  await page.goto("/team");
  const preview = page.getByRole("region", { name: "Abrechnungsvorschau" });
  await expect(preview.getByTestId("estimate-label")).toContainText("Schätzung – keine Rechnung");
  await expect(preview.getByTestId("billing-team").filter({ hasText: "Testteam Nord" })).toBeVisible();
  await expect(preview).toContainText("Restfinanzierung: nicht hinterlegt");
  await preview.getByRole("button", { name: "Abrechnungsfakten erzeugen" }).click();
  await expect(preview.getByRole("status")).toContainText("neue Abrechnungsfakten erfasst");
  await expect(page.getByText(/Rechnung (erstellen|senden)/)).toHaveCount(0);
});

test("Operations sees the preview for the organisation (J5)", async ({ page }) => {
  await signIn(page, OPS, /\/operations$/);
  await expect(page.getByRole("region", { name: "Abrechnungsvorschau" }).getByTestId("estimate-label")).toBeVisible();
});
