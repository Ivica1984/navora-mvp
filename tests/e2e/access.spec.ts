import { expect, test, type Page } from "@playwright/test";

// F0 (criteria 3c/3d): team-scoped clinical read, seen through the UI.
// Seed visits by service: "Grundpflege" = Testteam Nord (the nurse's team, case 208), "Medikamentengabe" = Testteam
// West (case 209), "Wundversorgung" = Testteam Mitte (case 210). Before RLS4-6 the test told the teams apart by the
// legacy free-text team_member_name, which /visits no longer reads (ADR-122).
const COACH = "coach.test@navora.test";
const NURSE = "pflege.test@navora.test";
const TEAM_C = "teamc.test@navora.test";
const PASSWORD = "navora-local-only";

async function signIn(page: Page, email: string, landing: RegExp) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(landing);
}

test("a nurse sees only her own team's visits; a coach sees the organisation (F0)", async ({ page }) => {
  await signIn(page, NURSE, /\/field$/);
  await page.goto("/visits");
  await expect(page.getByText("Grundpflege", { exact: true }).first()).toBeVisible();
  await expect(page.getByText("Medikamentengabe", { exact: true })).toHaveCount(0);
  await expect(page.getByText("Wundversorgung", { exact: true })).toHaveCount(0);

  await page.goto("/operations");
  await page.getByRole("button", { name: "Abmelden" }).click();
  await page.waitForURL(/\/login$/);

  await signIn(page, COACH, /\/operations$/);
  await page.goto("/visits");
  await expect(page.getByText("Medikamentengabe", { exact: true }).first()).toBeVisible();
  await expect(page.getByText("Wundversorgung", { exact: true }).first()).toBeVisible();
});

// RLS4-6 (ADR-122): /visits names the visit's responsible member from responsible_user_id ("Noch offen" without one).
// Seed: Testteam C's visit today 07:00 (responsible: teamc.test, "Pflegekraft Team C"); Testteam Mitte's completed
// visit yesterday 14:00 (case 210, "Wundversorgung", nobody responsible), read by the coach.
test("/visits shows the responsible member's name, or Noch offen (RLS4-6)", async ({ page }) => {
  await signIn(page, TEAM_C, /^(?!.*\/login).*$/);
  await page.goto("/visits");
  await expect(
    page.getByRole("button").filter({ hasText: /07:00(:00)? – 07:30/ }).filter({ hasText: "Pflegekraft: Pflegekraft Team C" }).first()
  ).toBeVisible();

  await page.context().clearCookies();
  await signIn(page, COACH, /\/operations$/);
  await page.goto("/visits");
  await expect(
    page.getByRole("button").filter({ hasText: /14:00(:00)? – 14:45/ }).filter({ hasText: "Wundversorgung" }).filter({ hasText: "Pflegekraft: Noch offen" }).first()
  ).toBeVisible();
});
