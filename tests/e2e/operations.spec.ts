import { expect, test, type Page } from "@playwright/test";

// OPS1 — Operations exception center. Synthetic local-only accounts from supabase/seed.sql.
// Seed: quality event 701 "Testereignis hoch" (severity high, open for 6 h) → P1 exception.
const OPS = "ops.test@navora.test";
const NURSE = "pflege.test@navora.test";
const PASSWORD = "navora-local-only";

async function signIn(page: Page, email: string, landing: RegExp) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(landing);
}

test("Operations takes over, comments and closes a derived exception with a reason (OPS1)", async ({ page }) => {
  await signIn(page, OPS, /\/operations$/);
  const center = page.getByRole("region", { name: "Ausnahmen" });
  await expect(center).toBeVisible();

  const serious = center.getByTestId("exception").filter({ hasText: "Testereignis hoch" });
  await expect(serious).toContainText("P1");
  await expect(serious).toContainText("Schweres Qualitätsereignis offen");
  await expect(serious.getByTestId("exception-handler")).toHaveText("offen – niemand übernommen");

  await serious.getByRole("button", { name: "Übernehmen" }).click();
  await expect(serious.getByTestId("exception-handler")).toHaveText("von dir übernommen");

  await serious.getByRole("button", { name: "Notiz" }).click();
  await serious.getByLabel("Notiz").fill("Teamleitung angerufen, Rückruf heute");
  await serious.getByRole("button", { name: "Notiz speichern" }).click();
  await expect(serious.getByRole("list", { name: "Notizen" })).toContainText("Rückruf heute");

  // Closing needs a reason (the browser refuses an empty one; the server refuses short ones).
  await serious.getByRole("button", { name: "Schliessen" }).click();
  await serious.getByLabel("Begründung (nötig)").fill("Mit Team geklärt, Massnahme eingeleitet");
  await serious.getByRole("button", { name: "Ausnahme schliessen" }).click();
  await expect(center.getByTestId("exception").filter({ hasText: "Testereignis hoch" })).toHaveCount(0);

  // No dispatch from OPS1: no matching start, no case editing.
  await expect(center.getByRole("button", { name: /Team zuweisen|Matching starten|Fall bearbeiten/ })).toHaveCount(0);
});

test("a nurse sees no Operations exceptions", async ({ page }) => {
  await signIn(page, NURSE, /\/field$/);
  await page.goto("/operations");
  await expect(page.getByTestId("exception")).toHaveCount(0);
});
