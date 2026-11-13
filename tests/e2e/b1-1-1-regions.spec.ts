import { expect, test, type Page } from "@playwright/test";
import { addLegacyTeamOrgA, mapLegacyRegionOrgA, removeLegacyTeamOrgA } from "./support/regions";

// B1.1-1 (Δ1, ADR-186): the region is chosen from the list; legacy values are listed for Operations as «Region nicht
// zugeordnet». Synthetic local-only accounts (supabase/seed.sql). B1.1-1c (FE-073): the seed has no legacy value any
// more, so this file writes its own: «Basel Pilot» (one team, never mapped here; was the org A seed value before
// B1.1-1c) and «Altregion E2E» (mapped by the last test; before B1.1-1c intake.spec and journey.spec mapped the seed's
// «Bern West» through support/regions.ts). Both are removed after the file (workers: 1).
const PILOT = { team: "Testteam Altregion Pilot", value: "Basel Pilot" };
const MAPPED = { team: "Testteam Altregion Zuordnen", value: "Altregion E2E" };

test.beforeAll(() => {
  addLegacyTeamOrgA(PILOT.team, PILOT.value);
  addLegacyTeamOrgA(MAPPED.team, MAPPED.value);
});
test.afterAll(() => {
  removeLegacyTeamOrgA(PILOT.team, PILOT.value);
  removeLegacyTeamOrgA(MAPPED.team, MAPPED.value);
});
const OPS = "ops.test@navora.test"; //     org A, operations
const COACH = "coach.test@navora.test"; // org A, coach
const PASSWORD = "navora-local-only";

async function signIn(page: Page, email: string, landing: RegExp) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(landing);
}

for (const width of [390, 1440]) {
  test(`at ${width} px the intake region is a list and Operations sees «Region nicht zugeordnet»`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 });
    await signIn(page, OPS, /\/operations$/);

    await page.goto("/intake");
    const region = page.getByRole("form", { name: "Neue Anfrage" }).getByLabel("Region");
    await expect(region).toHaveJSProperty("tagName", "SELECT");
    await expect(region.locator("option:not([disabled])")).toHaveText(["Basel-Stadt", "Basel-Landschaft"]);

    await page.goto("/operations");
    const section = page.getByRole("region", { name: "Region nicht zugeordnet" });
    await expect(section).toBeVisible();
    const pilot = section.getByRole("form", { name: "Region zuordnen: Basel Pilot" });
    await expect(pilot).toBeVisible();
    // UXR-185: the count line of the fixture's one «Basel Pilot» team (no zero counts, singular/plural).
    const counts = pilot.getByTestId("region-counts");
    await expect(counts).toHaveText(/\d+ Teams?$/);
    await expect(counts).not.toHaveText(/(^|\s)0 /);
    await expect(pilot.getByLabel("Region aus der Liste").locator("option:not([disabled])")).toHaveText(["Basel-Stadt", "Basel-Landschaft"]);
    expect(await section.evaluate((el) => el.scrollWidth - el.clientWidth)).toBeLessThanOrEqual(0);

    // uxa UXR-184 (ADR-186 amendment 04:30): «Zuordnen» opens a confirming step; «Abbrechen» changes nothing.
    await pilot.getByLabel("Region aus der Liste").selectOption({ label: "Basel-Landschaft" });
    await pilot.getByRole("button", { name: "Zuordnen" }).click();
    const step = pilot.getByTestId("region-map-confirm");
    await expect(step).toBeVisible();
    await expect(step.getByTestId("region-map-confirm-sentence")).toContainText("«Basel Pilot» durch «Basel-Landschaft» ersetzt");
    await expect(step.getByTestId("region-map-confirm-sentence")).toContainText("nicht rückgängig");
    expect(await section.evaluate((el) => el.scrollWidth - el.clientWidth)).toBeLessThanOrEqual(0);
    await step.getByRole("button", { name: "Abbrechen" }).click();
    await expect(step).toHaveCount(0);
    await page.reload();
    await expect(section.getByRole("form", { name: "Region zuordnen: Basel Pilot" })).toBeVisible();
    // B1.1-1b UXR-187 (ADR-187): the status container is mounted before any mapping and stays empty after «Abbrechen»
    // (was: toHaveCount(0), when the container was mounted together with its text).
    await expect(page.getByTestId("region-mapped")).toHaveCount(1);
    await expect(page.getByTestId("region-mapped")).toBeEmpty();
  });
}

test("a coach does not see «Region nicht zugeordnet»", async ({ page }) => {
  await signIn(page, COACH, /\/(operations|coach|team)/);
  await page.goto("/operations");
  await expect(page.getByRole("region", { name: "Region nicht zugeordnet" })).toHaveCount(0);
});

test("Operations maps a legacy value through the confirming step and it leaves «Region nicht zugeordnet»", async ({ page }) => {
  // B1.1-1c: this coverage moved here from support/regions.ts `mapSeedRegionOrgA` (seed «Bern West», called by
  // intake.spec and journey.spec before B1.1-1c); the assertions are the same, on the fixture value.
  await signIn(page, OPS, /\/operations$/);
  await mapLegacyRegionOrgA(page, MAPPED.value, "Basel-Stadt");
  await page.reload();
  const section = page.getByRole("region", { name: "Region nicht zugeordnet" });
  await expect(section.getByRole("form", { name: `Region zuordnen: ${MAPPED.value}` })).toHaveCount(0);
  await expect(section.getByRole("form", { name: `Region zuordnen: ${PILOT.value}` })).toBeVisible();
});
