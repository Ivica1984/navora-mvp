import { expect, test, type Page } from "@playwright/test";

// ADM1 — pilot administration on /admin. Synthetic local-only accounts from supabase/seed.sql.
const ADMIN = "admin.test@navora.test"; // org A, role admin
const NURSE = "pflege.test@navora.test";
const PASSWORD = "navora-local-only";

async function signIn(page: Page, email: string, landing: RegExp) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(landing);
}

test("an administrator names a member, invites a person and creates a team (ADM1)", async ({ page }) => {
  await signIn(page, ADMIN, /\/operations$/);
  await page.goto("/admin");

  const members = page.getByRole("region", { name: "Mitglieder" });
  await expect(members).toContainText("pflege.test@navora.test");

  const coach = members.getByRole("listitem", { name: /coach\.test@navora\.test/ });
  await coach.getByRole("button", { name: "Name" }).click();
  await coach.getByRole("form", { name: "Name ändern" }).getByLabel("Anzeigename").fill("Carla Coach");
  await coach.getByRole("form", { name: "Name ändern" }).getByRole("button", { name: "Speichern" }).click();
  await expect(members.getByRole("listitem", { name: "Mitglied Carla Coach" }).getByTestId("member-name")).toHaveText("Carla Coach");

  const invitations = page.getByRole("region", { name: "Einladungen" });
  const invite = invitations.getByRole("form", { name: "Person einladen" });
  await invite.getByLabel("E-Mail").fill("e2e.neu@navora.test");
  await invite.getByLabel("Anzeigename").fill("Erika Neu");
  await invite.getByRole("button", { name: "Einladen" }).click();
  await expect(invitations.getByRole("list", { name: "Offene Einladungen" })).toContainText("e2e.neu@navora.test");

  const teams = page.getByRole("region", { name: "Teams" });
  const create = teams.getByRole("form", { name: "Team erstellen" });
  await create.getByLabel("Teamname").fill("E2E Team Ost");
  await create.getByLabel("Region").fill("Ost");
  await create.getByRole("button", { name: "Team erstellen" }).click();
  await expect(teams.getByRole("listitem", { name: "Team E2E Team Ost" }).getByTestId("team-status")).toHaveText("aktiv");

  // A team with open cases is not deactivated: the database refuses and the reason is shown.
  const nord = teams.getByRole("listitem", { name: "Team Testteam Nord" });
  await nord.getByRole("button", { name: "Deaktivieren" }).click();
  await nord.getByRole("form", { name: "Team deaktivieren" }).getByLabel("Begründung").fill("Test");
  await nord.getByRole("form", { name: "Team deaktivieren" }).getByRole("button", { name: "Deaktivieren" }).click();
  await expect(nord.getByTestId("command-error")).toContainText("offene Fälle");
});

test("exception thresholds change only within the safe range and show who changed them (ADM1)", async ({ page }) => {
  await signIn(page, ADMIN, /\/operations$/);
  await page.goto("/admin");
  const rule = page.getByRole("region", { name: "Ausnahmeregeln" })
    .getByRole("listitem", { name: "Regel Ärztliche Verordnung läuft ab oder ist abgelaufen" });

  await rule.getByLabel(/Schwelle/).fill("20");
  await rule.getByRole("button", { name: "Speichern" }).click();
  await expect(rule.getByTestId("command-error")).toContainText("0 und 14");

  await rule.getByLabel(/Schwelle/).fill("10");
  await rule.getByRole("button", { name: "Speichern" }).click();
  await expect(rule.getByTestId("rule-changed")).toContainText("geändert");

  await rule.getByRole("button", { name: /wiederherstellen/ }).click();
  await expect(rule.getByTestId("rule-changed")).toHaveText("Standard");
});

test("a nurse cannot use the administration (ADM1)", async ({ page }) => {
  await signIn(page, NURSE, /\/field$/);
  await page.goto("/admin");
  await expect(page.getByTestId("admin-denied")).toBeVisible();
  await expect(page.getByRole("region", { name: "Mitglieder" })).toHaveCount(0);
});
