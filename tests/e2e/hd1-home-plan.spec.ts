import { expect, test, type Locator, type Page } from "@playwright/test";
import { zurichDay } from "./support/durchgang-time";
import { addDays, weekStart } from "@/features/home-plan/rules";

// HD-1 / HD-2 e2e (founder 2026-11-20: «das Pflegeheim muss die Wochenplanung, die Monatsplanung und den Plan für die
// Mitarbeiter machen können»). Synthetic local-only accounts from supabase/seed.sql:
//   kundebs.test  lead of the home tenant «Testheim Rhein (synthetisch)» (migration 0159 / seed);
//   pflegebs.test a NAVORA team nurse: no home, never sees the home's staff.
// The home loads the synthetic example (current week), then plans a week three weeks ahead (no example rows there):
// assign → status words → absence → gap → month grid «A (F)» → absence removed → «besetzt». Only what a person sees is
// asserted. At 390 × 844 and at 1440 px.
const PASSWORD = "navora-local-only";
const HOME = "kundebs.test@navora.test";
const NURSE = "pflegebs.test@navora.test";

async function signIn(page: Page, email: string) {
  await page.context().clearCookies();
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

async function noSidewaysScroll(page: Page) {
  expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(0);
}

function cell(page: Page, date: string, station: string, shift: string): Locator {
  return page.locator(`[data-testid="heim-day"][data-date="${date}"] [data-testid="heim-cell"][data-station="${station}"][data-shift="${shift}"]`);
}

async function ensureExample(page: Page) {
  await page.goto("/heim");
  await expect(page.getByRole("heading", { name: "Dienstplanung" })).toBeVisible();
  if (await page.getByTestId("heim-empty").isVisible()) {
    await page.getByTestId("heim-load-example").click();
    await expect(page.getByTestId("heim-message")).toHaveText("Beispieldaten geladen (synthetisch).");
  }
  await expect(page.locator('[data-testid="heim-day"]')).toHaveCount(7);
}

async function assign(page: Page, c: Locator, label: string) {
  await c.getByTestId("heim-assign-select").selectOption({ label });
  await c.getByTestId("heim-assign").click();
  await expect(page.getByTestId("heim-message")).toHaveText("Eingeteilt.");
}

for (const width of [390, 1440]) {
  test(`HD-1 at ${width} px: the home plans its week, records an absence, sees the gap in week and month, removes it`, async ({ page }) => {
    test.setTimeout(120_000);
    await page.setViewportSize({ width, height: 900 });
    // One week per viewport, three and four weeks ahead: no example rows, no collision between the two runs.
    const monday = weekStart(addDays(zurichDay(), width === 390 ? 21 : 28));
    const wed = addDays(monday, 2);

    await signIn(page, HOME);
    await ensureExample(page);
    await noSidewaysScroll(page);

    await page.goto(`/heim?ansicht=woche&datum=${wed}`);
    const c = cell(page, wed, "Rhein 2", "F");
    await expect(c).toHaveAttribute("data-status", "gap");
    await expect(c.getByTestId("heim-cell-status")).toHaveText("0 von 3 · Lücke: 3 fehlt, 1 HF fehlt");
    await assign(page, c, "Anna Muster (HF)");
    await assign(page, cell(page, wed, "Rhein 2", "F"), "Ben Beispiel (FaGe)");
    await expect(cell(page, wed, "Rhein 2", "F").getByTestId("heim-cell-status")).toHaveText("2 von 3 · Lücke: 1 fehlt");
    await assign(page, cell(page, wed, "Rhein 2", "F"), "Carla Test (FaGe)");
    await expect(cell(page, wed, "Rhein 2", "F")).toHaveAttribute("data-status", "ok");
    await expect(cell(page, wed, "Rhein 2", "F").getByTestId("heim-cell-status")).toHaveText("3 von 3 · besetzt");
    // Carla is in Früh that day: the Spät list of the same day does not offer her (the database would refuse the overlap).
    await expect(cell(page, wed, "Rhein 2", "S").getByTestId("heim-assign-select").locator("option", { hasText: "Carla Test" })).toHaveCount(0);
    await noSidewaysScroll(page);

    // The plan of one staff member: record an absence (no reason asked).
    await page.goto(`/heim?ansicht=personal&datum=${wed}`);
    await page.getByTestId("heim-staff-link").filter({ hasText: "Carla Test" }).click();
    await expect(page.getByTestId("heim-person")).toContainText("Carla Test");
    await expect(page.locator(`[data-testid="heim-person-day"][data-date="${wed}"]`)).toContainText("Früh 07:00–15:30 · Rhein 2");
    const absence = page.getByTestId("heim-absence-form");
    await absence.getByLabel("Abwesend von").fill(wed);
    await absence.getByLabel("bis").fill(wed);
    await absence.getByRole("button", { name: "Abwesenheit erfassen" }).click();
    await expect(page.getByTestId("heim-message")).toHaveText("Abwesenheit erfasst. Betroffene Dienste zeigen jetzt die Lücke.");
    await expect(page.locator(`[data-testid="heim-person-day"][data-date="${wed}"]`)).toContainText("abwesend");
    await noSidewaysScroll(page);

    // The week shows the gap and the person as absent.
    await page.goto(`/heim?ansicht=woche&datum=${wed}`);
    await expect(cell(page, wed, "Rhein 2", "F")).toHaveAttribute("data-status", "gap");
    await expect(cell(page, wed, "Rhein 2", "F").getByTestId("heim-cell-status")).toHaveText("2 von 3 · Lücke: 1 fehlt");
    await expect(cell(page, wed, "Rhein 2", "F").getByTestId("heim-assigned").filter({ hasText: "Carla Test" })).toContainText("abwesend");

    // The month grid: Carla «A (F)» that day, and the gap count of the day is at least one.
    await page.goto(`/heim?ansicht=monat&datum=${wed}`);
    const row = page.getByTestId("heim-month-row").filter({ hasText: "Carla Test" });
    const col = Number(wed.slice(8)); // first column is the name
    await expect(row.locator("td").nth(col - 1)).toHaveText("A (F)");
    await expect(page.locator(`[data-testid="heim-month-gaps"][data-date="${wed}"]`)).not.toHaveText("0");
    await noSidewaysScroll(page);

    // Remove the absence: the cell is staffed again.
    await page.goto(`/heim?ansicht=personal&datum=${wed}`);
    await page.getByTestId("heim-staff-link").filter({ hasText: "Carla Test" }).click();
    await page.getByTestId("heim-absences").locator("li").filter({ hasText: "Abwesend" }).first().getByRole("button", { name: "entfernen" }).click();
    await expect(page.getByTestId("heim-message")).toHaveText("Abwesenheit entfernt.");
    await page.goto(`/heim?ansicht=woche&datum=${wed}`);
    await expect(cell(page, wed, "Rhein 2", "F")).toHaveAttribute("data-status", "ok");
  });
}

// HD-1 residual list R1 (PO 2026-11-20 20:05, patient safety): a person set «nicht mehr aktiv» never counts as present.
// Week and month read the same cells: the week cell turns into the gap and names her «nicht mehr aktiv», the month keeps
// her row while she is still assigned and shows the shift in brackets. Her own person (added here) keeps the shared
// example persons untouched for the parallel runs; five weeks ahead, no collision with the runs above.
test("HD-1 R1: an inactive person never counts as present, in the week and in the month", async ({ page }) => {
  test.setTimeout(120_000);
  await page.setViewportSize({ width: 1440, height: 900 });
  const wed = addDays(weekStart(addDays(zurichDay(), 35)), 2);
  const name = `R1 Probe ${Date.now() % 100000}`;

  await signIn(page, HOME);
  await ensureExample(page);
  await page.goto(`/heim?ansicht=personal&datum=${wed}`);
  const add = page.getByTestId("heim-add-staff");
  await add.getByLabel("Name (synthetisch)").fill(name);
  await add.getByLabel("Stufe").selectOption({ label: "HF" });
  await add.getByRole("button", { name: "Hinzufügen" }).click();
  await expect(page.getByTestId("heim-message")).toHaveText("Person hinzugefügt.");
  // HD-PEN-HAND (0190): without Pensum (and Monatssoll) a hand assignment first warns «Stunden nicht prüfbar». This spec
  // is about inactive persons, so the new person gets a Pensum first and the assignment stays a plain one.
  await page.getByTestId("heim-staff-link").filter({ hasText: name }).click();
  await page.getByTestId("heim-staff-pensum-value").check();
  await page.getByTestId("heim-staff-pensum").fill("100");
  await page.getByTestId("heim-staff-planning-save").click();
  await expect(page.getByTestId("heim-message")).toHaveText("Pensum und Schichtmodell gespeichert.");

  await page.goto(`/heim?ansicht=woche&datum=${wed}`);
  await expect(cell(page, wed, "Rhein 2", "F").getByTestId("heim-cell-status")).toHaveText("0 von 3 · Lücke: 3 fehlt, 1 HF fehlt");
  await assign(page, cell(page, wed, "Rhein 2", "F"), `${name} (HF)`);
  await expect(cell(page, wed, "Rhein 2", "F").getByTestId("heim-cell-status")).toHaveText("1 von 3 · Lücke: 2 fehlt");

  await page.goto(`/heim?ansicht=personal&datum=${wed}`);
  await page.getByTestId("heim-staff-link").filter({ hasText: name }).click();
  await page.getByRole("button", { name: "Nicht mehr aktiv" }).click();
  await expect(page.getByTestId("heim-message")).toHaveText("Gespeichert.");

  // Week: the gap is back, the HF is missing again, she is still listed and named «nicht mehr aktiv».
  await page.goto(`/heim?ansicht=woche&datum=${wed}`);
  const c = cell(page, wed, "Rhein 2", "F");
  await expect(c).toHaveAttribute("data-status", "gap");
  await expect(c.getByTestId("heim-cell-status")).toHaveText("0 von 3 · Lücke: 3 fehlt, 1 HF fehlt");
  await expect(c.getByTestId("heim-assigned").filter({ hasText: name }).getByTestId("heim-assigned-inactive")).toHaveText("nicht mehr aktiv");

  // Month: her row stays while she is assigned, the shift is in brackets, the day counts a gap.
  await page.goto(`/heim?ansicht=monat&datum=${wed}`);
  const row = page.getByTestId("heim-month-row").filter({ hasText: name });
  await expect(row).toContainText("nicht mehr aktiv");
  await expect(row.locator("td").nth(Number(wed.slice(8)) - 1)).toHaveText("(F)");
  await expect(page.locator(`[data-testid="heim-month-gaps"][data-date="${wed}"]`)).not.toHaveText("0");
});

test("HD-1 permission: a NAVORA team nurse has no «Dienstplanung» and /heim shows no home data", async ({ page }) => {
  await signIn(page, NURSE);
  await expect(page.getByRole("link", { name: "Dienstplanung" })).toHaveCount(0);
  await page.goto("/heim");
  await expect(page.getByTestId("heim-no-institution")).toBeVisible();
  await expect(page.getByText("Anna Muster")).toHaveCount(0);
});

test("HD-1 navigation: the home lead reaches «Dienstplanung» from the menu", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await signIn(page, HOME);
  await page.getByRole("link", { name: "Dienstplanung" }).first().click();
  await expect(page).toHaveURL(/\/heim/);
  await expect(page.getByTestId("heim-name")).toContainText("Testheim Rhein (synthetisch)");
});
