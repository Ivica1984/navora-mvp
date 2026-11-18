import { expect, test, type Page } from "@playwright/test";
import { zurichDay } from "../e2e/support/durchgang-time";
import { TAKE_HEADING } from "@/features/field/heading";
import { smokeAccounts, smokeDayOffsets, type Role } from "./target";

// ADR-205 — staging smoke (founder decision 2026-11-18 ca. 23:00, «Variante b»). The founder's two click paths of
// `docs/product/FOUNDER_STAGING_UEBERSICHT.md`, in the real staging app, with the three demo accounts (FE-086b):
//   1. client orders a day shift → another team never sees it → the demo nurse of Testteam Basel sees the offer and
//      takes it naming herself → the client reads «Gedeckt» (the CI original is tests/e2e/bk-c2-take-status.spec.ts);
//   2. client orders a 22:00–07:00 night → the nurse takes it → her /field day shows one «Übernommene Schicht» card
//      22:00 – 07:00 (CI original tests/e2e/bk-e1b-take-card.spec.ts at 390 px).
// Only what a person sees is asserted, never a person's name or a count of orders (staging data grow with every run;
// the second Basel nurse of the CI seed does not exist on staging). Each run writes two synthetic orders and two takes
// on staging, on days of its own (smokeDayOffsets); they are synthetic by construction (demo accounts, Testheim Rhein).
// Not here: the colleague and absence paths, BK-e1c after midnight (needs a started visit at night).

const accounts = smokeAccounts(process.env);
const offsets = smokeDayOffsets(Number(process.env.GITHUB_RUN_NUMBER ?? 0));
const deDate = (iso: string) => iso.split("-").reverse().join(".");

async function signIn(page: Page, role: Role) {
  await page.context().clearCookies();
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(accounts[role].email);
  await page.getByLabel("Passwort").fill(accounts[role].password);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

async function order(page: Page, day: string, start: string, end: string) {
  await page.goto("/order");
  const form = page.getByRole("form", { name: "Auftrag" });
  await form.getByLabel(/^Datum/).fill(deDate(day));
  await form.getByLabel("Beginn", { exact: true }).fill(start);
  await form.getByLabel("Ende", { exact: true }).fill(end);
  await form.getByLabel("Einsatzort (Postleitzahl)").selectOption("4051");
  await form.getByRole("radio", { name: "HF", exact: true }).check();
  await form.getByRole("checkbox", { name: "Grundpflege", exact: true }).check();
  await form.getByRole("button", { name: "Weiter zur Zusammenfassung" }).click();
  await page.getByTestId("order-summary").getByRole("button", { name: "Bestätigen & Absenden" }).click();
  await expect(page.getByTestId("order-done")).toContainText("Auftrag bestätigt");
}

async function takeAsHerself(page: Page, when: string) {
  await page.goto("/team");
  const card = page.getByTestId("shift-offer-card").filter({ hasText: when }).last();
  await expect(card.getByTestId("shift-offer-tag")).toHaveText("Neues Angebot");
  await expect(card.getByRole("radio", { name: "Ich (Pflegekraft)" })).toBeChecked();
  await card.getByRole("button", { name: "Übernehmen mit Pflegekraft" }).click();
  const taken = page.getByTestId("shift-offer-card").filter({ hasText: when }).last();
  await expect(taken.getByTestId("shift-offer-tag")).toHaveText("Übernommen");
  await expect(taken.getByTestId("shift-offer-line")).toHaveText(/^Ihr habt diese Schicht übernommen\. Es geht: \S/);
}

test.describe.configure({ mode: "serial" });

test("staging is up and each demo account can sign in", async ({ page }) => {
  // Wakes a sleeping Render instance (navigationTimeout 90 s in the config).
  await page.goto("/login");
  await expect(page.getByRole("button", { name: "Anmelden" })).toBeVisible();
  for (const role of ["kunde", "pflegeBs", "pflegeNord"] as const) {
    await signIn(page, role);
    expect(new URL(page.url()).pathname).not.toMatch(/^\/login/);
  }
});

test("path 1: client orders → another team never sees it → Basel nurse takes it → client reads «Gedeckt»", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 900 });
  const day = zurichDay(Date.now(), offsets.day);
  const when = `${deDate(day)} 07:00`;

  await signIn(page, "kunde");
  await order(page, day, "07:00", "15:30");
  const open = page.getByTestId("client-orders").locator("li", { hasText: when }).last();
  await expect(open.getByTestId("order-cover-state")).toHaveText(/^Noch nicht gedeckt/);

  await signIn(page, "pflegeNord");
  await page.goto("/team");
  await expect(page.getByTestId("shift-offers")).toBeVisible();
  await expect(page.getByTestId("shift-offer-card").filter({ hasText: when })).toHaveCount(0);

  await signIn(page, "pflegeBs");
  await takeAsHerself(page, when);

  await signIn(page, "kunde");
  await page.goto("/order");
  const covered = page.getByTestId("client-orders").locator("li", { hasText: when }).last();
  await expect(covered.getByTestId("order-cover-state")).toHaveText(/^Gedeckt · Person benannt, geprüft für HF$/);
  await expect(covered.getByTestId("order-cover-detail")).toHaveText(/^Team .+ · übernommen um \d\d:\d\d$/);
});

test("path 2: a 22:00–07:00 night taken by the nurse is one «Übernommene Schicht» card on her /field day (390 px)", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  const day = zurichDay(Date.now(), offsets.night);
  const when = `${deDate(day)} 22:00`;

  await signIn(page, "kunde");
  await order(page, day, "22:00", "07:00");

  await signIn(page, "pflegeBs");
  await takeAsHerself(page, when);

  await page.goto(`/field?datum=${day}`);
  const cards = page.getByRole("article", { name: /22:00 – 07:00/ });
  await expect(cards).toHaveCount(1);
  await expect(cards.first().getByRole("heading", { level: 2 })).toHaveText(TAKE_HEADING);
  expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(0);
});
