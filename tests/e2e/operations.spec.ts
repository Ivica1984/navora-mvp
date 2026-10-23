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

test("Operations takes over and comments a derived exception; a safety exception and an uncovered visit have no close (OPS1, CGR-06, CGR-22)", async ({ page }) => {
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

  // CSR1 / CGR-06: a safety exception has no close; it ends only when its cause is resolved (the event is closed).
  await expect(serious.getByRole("button", { name: "Schliessen" })).toHaveCount(0);
  await expect(serious.getByTestId("exception-closes-with-cause")).toContainText("schliesst automatisch");
  await page.reload();
  await expect(center.getByTestId("exception").filter({ hasText: "Testereignis hoch" })).toHaveCount(1);

  // CSR1 / CGR-22 (0044, provisional until D-28): an uncovered visit is not closed by hand either; it ends when someone
  // is responsible, the visit starts or is cancelled. Whether the seed's uncovered visits are listed depends on the time
  // of day and on other tests, so every listed one is checked (the database refusal itself is in pgTAP 044).
  const uncovered = center.getByTestId("exception").filter({ hasText: "Einsatz ohne Verantwortliche" });
  for (const card of await uncovered.all()) {
    await expect(card.getByRole("button", { name: "Schliessen" })).toHaveCount(0);
    await expect(card.getByTestId("exception-closes-with-cause")).toContainText("jemand zuständig");
  }

  // No dispatch from OPS1: no matching start, no case editing.
  await expect(center.getByRole("button", { name: /Team zuweisen|Matching starten|Fall bearbeiten/ })).toHaveCount(0);
});

test("a nurse sees no Operations exceptions", async ({ page }) => {
  await signIn(page, NURSE, /\/field$/);
  await page.goto("/operations");
  await expect(page.getByTestId("exception")).toHaveCount(0);
});
