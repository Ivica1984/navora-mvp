import { expect, test, type Locator, type Page } from "@playwright/test";
import { zurichDay } from "./support/durchgang-time";
import { addDays, weekStart } from "@/features/home-plan/rules";

// HD-3a slice 2c (FE-123 Q3, brief HD.md §5b PO amendment 19:39): a hand assignment against a planning rule is a
// warning, not a block. The synthetic example's «Felix Demo» has the shift model `early_only`; putting him on a late
// shift names the rule, saves nothing, can be cancelled, and once confirmed is saved with the warning visible in the
// week, the month («S!») and his own plan. Absence and double booking stay blocked (pgTAP 173). A week six weeks
// ahead (no example rows, no other e2e uses it); everything is removed again. At 390 × 900 px.
const PASSWORD = "navora-local-only";
const HOME = "kundebs.test@navora.test";

async function signIn(page: Page, email: string) {
  await page.context().clearCookies();
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

function cell(page: Page, date: string, station: string, shift: string): Locator {
  return page.locator(`[data-testid="heim-day"][data-date="${date}"] [data-testid="heim-cell"][data-station="${station}"][data-shift="${shift}"]`);
}

test("HD-3a: a hand assignment against the shift model warns, can be cancelled, and once confirmed keeps the warning (390 px)", async ({ page }) => {
  test.setTimeout(120_000);
  await page.setViewportSize({ width: 390, height: 900 });
  const wed = addDays(weekStart(addDays(zurichDay(), 42)), 2);

  await signIn(page, HOME);
  await page.goto("/heim");
  await expect(page.getByRole("heading", { name: "Dienstplanung" })).toBeVisible();
  if (await page.getByTestId("heim-empty").isVisible()) {
    await page.getByTestId("heim-load-example").click();
    await expect(page.getByTestId("heim-message")).toHaveText("Beispieldaten geladen (synthetisch).");
  }

  await page.goto(`/heim?ansicht=woche&datum=${wed}`);
  const late = () => cell(page, wed, "Rhein 1", "S");
  await late().getByTestId("heim-assign-select").selectOption({ label: "Felix Demo (FaGe)" });
  await late().getByTestId("heim-assign").click();
  const warning = page.getByTestId("heim-rule-warning");
  await expect(page.getByTestId("heim-message")).toHaveText(/^Nicht eingeteilt: Diese Einteilung verletzt eine Planungsregel/);
  await expect(warning).toContainText("Felix Demo");
  await expect(warning.getByTestId("heim-rule-warning-rules")).toHaveText("Schichtmodell der Person passt nicht zu dieser Dienstart");
  await expect(late().getByTestId("heim-assigned").filter({ hasText: "Felix Demo" })).toHaveCount(0);
  expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(0);

  // Cancel: nothing saved, the warning is gone.
  await warning.getByTestId("heim-rule-cancel").click();
  await expect(page.getByTestId("heim-rule-warning")).toHaveCount(0);
  await expect(late().getByTestId("heim-assigned").filter({ hasText: "Felix Demo" })).toHaveCount(0);

  // Again, and confirm: saved, the warning stays on the shift.
  await late().getByTestId("heim-assign-select").selectOption({ label: "Felix Demo (FaGe)" });
  await late().getByTestId("heim-assign").click();
  await page.getByTestId("heim-rule-confirm").click();
  await expect(page.getByTestId("heim-message")).toHaveText("Eingeteilt, mit bestätigter Regelwarnung. Die Warnung bleibt auf dem Dienst sichtbar.");
  await expect(page.getByTestId("heim-rule-warning")).toHaveCount(0);
  const felix = late().getByTestId("heim-assigned").filter({ hasText: "Felix Demo" });
  await expect(felix.getByTestId("heim-assigned-warning")).toHaveText(
    "Regel: Schichtmodell der Person passt nicht zu dieser Dienstart (von Hand bestätigt)",
  );

  // The month and his own plan read the same state.
  await page.goto(`/heim?ansicht=monat&datum=${wed}`);
  const row = page.getByTestId("heim-month-row").filter({ hasText: "Felix Demo" });
  await expect(row.locator("td").nth(Number(wed.slice(8)) - 1)).toHaveText("S!");
  await page.goto(`/heim?ansicht=personal&datum=${wed}`);
  await page.getByTestId("heim-staff-link").filter({ hasText: "Felix Demo" }).click();
  await expect(page.locator(`[data-testid="heim-person-day"][data-date="${wed}"]`).getByTestId("heim-person-warning"))
    .toHaveText("Regel: Schichtmodell der Person passt nicht zu dieser Dienstart (von Hand bestätigt)");

  // Clean up.
  await page.goto(`/heim?ansicht=woche&datum=${wed}`);
  await late().getByTestId("heim-assigned").filter({ hasText: "Felix Demo" }).getByRole("button", { name: "Felix Demo entfernen" }).click();
  await expect(page.getByTestId("heim-message")).toHaveText("Aus dem Dienst entfernt.");
});
