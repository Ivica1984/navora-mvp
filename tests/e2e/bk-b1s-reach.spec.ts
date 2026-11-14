import { expect, test, type Page } from "@playwright/test";

// BK-b1s (PO amendment 2026-11-14 10:39 (3), AUT-117 (c); ADR-195 addendum 11:10): the team's own reach screen
// «Unser Einsatzgebiet» at phone width. Synthetic local-only accounts from supabase/seed.sql:
//   pflege.test (nurse, member of Testteam Nord, org A) changes her team's reach;
//   teamc.test (member of Testteam C, org C) sees only her own team, never Testteam Nord;
//   fremd.test (admin of org B, member of no team) sees no team form.
// The former member (LEAVE1, access ended) is covered at the database by pgTAP 137 section 4 (reader empty, command
// refused with `access_ended`, reach unchanged); ending a seeded member's access here would change what the other specs see.
// Robust to a re-run on the same database: the test sets every field before it reads.
const PASSWORD = "navora-local-only";

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

test.describe("BK-b1s: Unser Einsatzgebiet", () => {
  test.use({ viewport: { width: 390, height: 844 } });

  test("(a), (b), (d): a member changes her own team's reach; each refusal shows at its field", async ({ page }) => {
    await signIn(page, "pflege.test@navora.test");
    await page.goto("/team");
    await page.getByTestId("reach-link").click();
    await page.waitForURL(/\/team\/einsatzgebiet$/);
    await expect(page.getByRole("heading", { level: 1, name: "Unser Einsatzgebiet" })).toBeVisible();
    const form = page.getByRole("region", { name: "Einsatzgebiet Testteam Nord" });
    await expect(form).toBeVisible();
    await expect(page.getByTestId("reach-form")).toHaveCount(1);
    // (d) a change applies to new orders only.
    await expect(form.getByTestId("reach-new-orders-only")).toHaveText(
      "Eine Änderung gilt für neue Aufträge. Aufträge, die schon geprüft wurden, bleiben, wie sie sind.",
    );

    // (b) nothing ticked, no distance: both refusals, each at its own field; nothing saved.
    for (const box of await form.getByRole("checkbox").all()) await box.uncheck();
    await form.getByLabel("Höchstdistanz in km").fill("");
    await form.getByRole("button", { name: "Einsatzgebiet speichern" }).click();
    await expect(form.getByTestId("reach-postcodes-error-text")).toHaveText("Bitte mindestens eine PLZ wählen.");
    await expect(form.getByTestId("reach-distance-error-text")).toHaveText("Bitte eine Distanz grösser als 0 km eingeben.");
    await expect(form.getByTestId("reach-saved")).toHaveCount(0);

    // (b) a postcode, distance 0: only the distance refusal.
    await form.getByRole("checkbox", { name: "4051 Basel" }).check();
    await form.getByLabel("Höchstdistanz in km").fill("0");
    await form.getByRole("button", { name: "Einsatzgebiet speichern" }).click();
    await expect(form.getByTestId("reach-distance-error-text")).toHaveText("Bitte eine Distanz grösser als 0 km eingeben.");
    await expect(form.getByTestId("reach-postcodes-error-text")).toHaveCount(0);

    // (a) two postcodes, 8,5 km: saved through set_team_reach.
    await form.getByRole("checkbox", { name: "4057 Basel" }).check();
    await form.getByLabel("Höchstdistanz in km").fill("8,5");
    await form.getByRole("button", { name: "Einsatzgebiet speichern" }).click();
    await expect(form.getByTestId("reach-saved")).toBeVisible();
    await expect(form.getByTestId("reach-distance-error")).toHaveCount(0);

    // Read back from the database after the save returned.
    await page.goto("/team/einsatzgebiet");
    const again = page.getByRole("region", { name: "Einsatzgebiet Testteam Nord" });
    await expect(again.getByRole("checkbox", { name: "4051 Basel" })).toBeChecked();
    await expect(again.getByRole("checkbox", { name: "4057 Basel" })).toBeChecked();
    await expect(again.getByRole("checkbox", { name: "4410 Liestal" })).not.toBeChecked();
    await expect(again.getByLabel("Höchstdistanz in km")).toHaveValue("8.5");
    await expect(again.getByTestId("reach-changed-at")).toHaveText(/^Zuletzt geändert am \d{2}\.\d{2}\.\d{4}\.$/);
  });

  test("(c): a member of another team never sees Testteam Nord", async ({ page }) => {
    await signIn(page, "teamc.test@navora.test");
    await page.goto("/team/einsatzgebiet");
    await expect(page.getByRole("region", { name: "Einsatzgebiet Testteam C" })).toBeVisible();
    await expect(page.getByRole("region", { name: "Einsatzgebiet Testteam Nord" })).toHaveCount(0);
    await expect(page.getByTestId("reach-form")).toHaveCount(1);
  });

  test("(c): a person in no team sees no team form", async ({ page }) => {
    await signIn(page, "fremd.test@navora.test");
    await page.goto("/team/einsatzgebiet");
    await expect(page.getByTestId("reach-empty")).toBeVisible();
    await expect(page.getByTestId("reach-form")).toHaveCount(0);
  });
});
