import { expect, test, type Page } from "@playwright/test";

// QG1 — quality hold on a visit. Synthetic local-only accounts from supabase/seed.sql.
// No clinical event types exist until D-16; the UI says so instead of offering invented ones.
const NURSE = "pflege.test@navora.test"; // Testteam Nord
const COACH = "coach.test@navora.test"; //  org A, coach
const OPS = "ops.test@navora.test"; //      org A, operations
const PASSWORD = "navora-local-only";
const SEED_DAY = new Date().toISOString().slice(0, 10);

async function signIn(page: Page, email: string, landing: RegExp) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(landing);
}

test("the team sets a quality hold; only coach or admin lift it, with a reason (QG1)", async ({ page }) => {
  await signIn(page, NURSE, /\/field$/);
  await page.goto(`/field?datum=${SEED_DAY}`);
  const quality = page.getByRole("article", { name: /08:00 – 08:45/ }).getByTestId("quality");

  await quality.getByRole("button", { name: "Ereignis melden" }).click();
  await expect(quality.getByTestId("no-types")).toContainText("D-16");
  await quality.getByRole("button", { name: "Schliessen" }).click();

  await quality.getByRole("button", { name: "Qualitäts-Stopp setzen" }).click();
  await quality.getByLabel("Begründung für den Stopp").fill("E2E: Leistung strittig");
  await quality.getByRole("button", { name: "Stopp setzen" }).click();
  await expect(quality.getByTestId("quality-hold")).toBeVisible();
  await expect(quality.getByRole("button", { name: "Qualitäts-Stopp setzen" })).toHaveCount(0);

  // Operations sees the hold but may not lift it (provisional role rule, D-16).
  await page.context().clearCookies();
  await signIn(page, OPS, /\/operations$/);
  const opsHold = page.getByTestId("hold").filter({ hasText: "E2E: Leistung strittig" });
  await opsHold.getByRole("button", { name: "Stopp aufheben" }).click();
  await opsHold.getByLabel("Begründung").fill("Versuch durch Operations");
  await opsHold.getByRole("button", { name: "Aufheben" }).click();
  await expect(opsHold.getByTestId("command-error")).toContainText("Coach oder Admin");

  await page.context().clearCookies();
  await signIn(page, COACH, /\/operations$/);
  const hold = page.getByTestId("hold").filter({ hasText: "E2E: Leistung strittig" });
  await hold.getByRole("button", { name: "Stopp aufheben" }).click();
  await hold.getByLabel("Begründung").fill("Mit Team geklärt, Leistung korrekt");
  await hold.getByRole("button", { name: "Aufheben" }).click();
  await expect(page.getByTestId("hold").filter({ hasText: "E2E: Leistung strittig" })).toHaveCount(0);
});
