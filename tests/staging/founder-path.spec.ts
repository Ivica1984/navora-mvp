import { expect, test, type Page } from "@playwright/test";
import { zurichDay } from "../e2e/support/durchgang-time";

// Staging smoke (founder 2026-11-18): the built path on the REAL staging app (Render + navora-staging), synthetic seed
// accounts only. Client orders → another team never sees it → the matching team member sees the offer and takes it
// naming herself → a colleague sees the take → the client reads «Gedeckt». Screenshots at every step (test evidence,
// not a product substitute). One order per run, on a day 40 days ahead plus the run attempt, so repeated runs do not
// collide on the nurse's availability. Unmerged probe branch (README rule 12).
const PASSWORD = process.env.STAGING_TEST_PASSWORD ?? "";
const deDate = (iso: string) => iso.split("-").reverse().join(".");

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}
const out = async (page: Page, name: string) => page.screenshot({ path: `staging-shots/${name}.png`, fullPage: true });

test("founder path on staging at 390 px", async ({ page }) => {
  test.skip(PASSWORD === "", "no test password");
  await page.setViewportSize({ width: 390, height: 900 });
  const day = zurichDay(Date.now(), 40 + Number(process.env.SMOKE_OFFSET ?? 0));
  const when = `${deDate(day)} 07:00`;

  await signIn(page, "kundebs.test@navora.test");
  await page.goto("/order");
  const form = page.getByRole("form", { name: "Auftrag" });
  await form.getByLabel(/^Datum/).fill(deDate(day));
  await form.getByLabel("Beginn", { exact: true }).fill("07:00");
  await form.getByLabel("Ende", { exact: true }).fill("15:30");
  await form.getByLabel("Einsatzort (Postleitzahl)").selectOption("4051");
  await form.getByRole("radio", { name: "HF", exact: true }).check();
  await form.getByRole("checkbox", { name: "Grundpflege", exact: true }).check();
  await out(page, "1-client-form");
  await form.getByRole("button", { name: "Weiter zur Zusammenfassung" }).click();
  await page.getByTestId("order-summary").getByRole("button", { name: "Bestätigen & Absenden" }).click();
  await expect(page.getByTestId("order-done")).toContainText("Auftrag bestätigt");
  const clientCard = page.getByTestId("client-orders").locator("li", { hasText: when }).last();
  await expect(clientCard.getByTestId("order-cover-state")).toHaveText(/^Noch nicht gedeckt/);
  await out(page, "2-client-open");
  await page.context().clearCookies();

  await signIn(page, "pflege.test@navora.test");
  await page.goto("/team");
  await expect(page.getByTestId("shift-offers")).toBeVisible();
  await expect(page.getByTestId("shift-offer-card").filter({ hasText: when })).toHaveCount(0);
  await out(page, "3-other-team-none");
  await page.context().clearCookies();

  await signIn(page, "pflegebs.test@navora.test");
  await page.goto("/team");
  const card = page.getByTestId("shift-offer-card").filter({ hasText: when }).last();
  await expect(card.getByTestId("shift-offer-tag")).toHaveText("Neues Angebot");
  await expect(card.getByRole("radio", { name: "Ich (Pflegekraft)" })).toBeChecked();
  await out(page, "4-nurse-offer");
  await card.getByRole("button", { name: "Übernehmen mit Pflegekraft" }).click();
  const taken = page.getByTestId("shift-offer-card").filter({ hasText: when }).last();
  await expect(taken.getByTestId("shift-offer-tag")).toHaveText("Übernommen");
  await out(page, "5-nurse-taken");
  await page.context().clearCookies();

  await signIn(page, "assistbs.test@navora.test");
  await page.goto("/team");
  await expect(page.getByTestId("shift-offer-card").filter({ hasText: when }).last().getByTestId("shift-offer-tag")).toHaveText("Übernommen");
  await out(page, "6-colleague-sees-take");
  await page.context().clearCookies();

  await signIn(page, "kundebs.test@navora.test");
  await page.goto("/order");
  const covered = page.getByTestId("client-orders").locator("li", { hasText: when }).last();
  await expect(covered.getByTestId("order-cover-state")).toHaveText(/^Gedeckt/);
  await out(page, "7-client-covered");
});
