import { expect, test, type Page } from "@playwright/test";
import { zurichDay } from "./support/durchgang-time";

// BK-c2 acceptance path «a take naming a colleague» (brief docs/agents/briefs/BK.md §PO amendment 2026-11-17 11:39 (1),
// (2); CGR-230 «Bestätigen», UXR-222 / CGR-234 «Ich kann nicht», UXR-223 client words; ADR-200 addendum 12:15).
// Synthetic local-only accounts from supabase/seed.sql (Testorganisation S, simulation):
//   kundebs.test    client of «Testheim Rhein (synthetisch)»: orders one HF shift and reads its status;
//   pflegebs.test   registered nurse of Testteam Basel: takes it for the team and names her colleague;
//   kolleginbs.test registered nurse of Testteam Basel (seed addition, PO 11:39 (2)): the named person;
//   pflege.test     member of Testteam Nord (org A): never sees either card.
// Case 1: the colleague sees «Für dich eingeteilt» first and confirms; the client reads «Noch nicht gedeckt» until then
// and «Gedeckt» after. Case 2: she presses «Ich kann nicht»; the order is offered again and the client reads
// «Nicht mehr gedeckt». Each case and width uses its own Zurich day 32 to 35 days ahead (no other spec orders on those
// days), so both nurses are free (step 3); no assertion counts orders. Screenshots of the cards at 390 and 1440 px are
// attached to the Playwright report (CI artefact `playwright-report`) for `uxa` (PO 2026-11-16 21:39 (5)).
const PASSWORD = "navora-local-only";
const FORBIDDEN = /exklusiv|Kaskade|bis \d{1,2}:\d{2} (übernehmen|annehmen)|zuerst|Vermittlung|Provision|von \d+ Teams?/i;

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

async function signOut(page: Page) {
  await page.context().clearCookies();
}

const deDate = (iso: string) => iso.split("-").reverse().join(".");

async function snap(page: Page, name: string) {
  await test.info().attach(name, { body: await page.screenshot({ fullPage: true }), contentType: "image/png" });
}

/** The client orders one HF day shift on `day` and reads «Noch nicht gedeckt»; returns the card's text key. */
async function orderShift(page: Page, day: string): Promise<string> {
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
  await form.getByRole("button", { name: "Weiter zur Zusammenfassung" }).click();
  await page.getByTestId("order-summary").getByRole("button", { name: "Bestätigen & Absenden" }).click();
  await expect(page.getByTestId("order-done")).toContainText("Auftrag bestätigt");
  const card = page.getByTestId("client-orders").locator("li", { hasText: when }).last();
  await expect(card.getByTestId("order-cover-state")).toHaveText(/^Noch nicht gedeckt · Beginn \S\S \d\d\.\d\d\., 07:00$/);
  await signOut(page);
  return when;
}

/** pflegebs takes the order for Testteam Basel and names her colleague (not herself). */
async function takeNamingColleague(page: Page, when: string, width: number, tag: string) {
  await signIn(page, "pflegebs.test@navora.test");
  await page.goto("/team");
  const card = page.getByTestId("shift-offer-card").filter({ hasText: when }).last();
  await expect(card.getByTestId("shift-offer-tag")).toHaveText("Neues Angebot");
  await expect(card.getByRole("radio", { name: "Ich (Pflegekraft)" })).toBeChecked();
  await card.getByRole("radio", { name: "Kollegin B." }).check();
  await card.getByRole("button", { name: "Übernehmen mit Kollegin B." }).click();
  const taken = page.getByTestId("shift-offer-card").filter({ hasText: when }).last();
  await expect(taken.getByTestId("shift-offer-tag")).toHaveText("Übernommen");
  const lines = taken.getByTestId("shift-offer-line");
  await expect(lines.nth(0)).toHaveText("Es geht: Kollegin B. · Bestätigung ausstehend");
  await expect(lines.nth(1)).toHaveText(/^Übernommen von Pflegekraft B\. um \d\d:\d\d\.$/);
  await expect(lines.nth(2)).toHaveText(/^Bestätigt Kollegin nicht bis \S\S \d\d\.\d\d\., \d\d:\d\d, gilt die Übernahme nicht mehr\.$/);
  // Nobody acts for the named person: the taker has no button on this card.
  await expect(taken.getByRole("button")).toHaveCount(0);
  await expect(taken).not.toContainText(FORBIDDEN);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  await snap(page, `bk-c2-${tag}-taker-pending-${width}.png`);
  await signOut(page);
}

async function otherTeamNeverSees(page: Page, when: string) {
  await signIn(page, "pflege.test@navora.test");
  await page.goto("/team");
  await expect(page.getByTestId("shift-offers")).toBeVisible();
  await expect(page.getByTestId("shift-offer-card").filter({ hasText: when })).toHaveCount(0);
  await signOut(page);
}

async function clientReads(page: Page, when: string, state: string | RegExp, detail: string | RegExp) {
  await signIn(page, "kundebs.test@navora.test");
  await page.goto("/order");
  const card = page.getByTestId("client-orders").locator("li", { hasText: when }).last();
  await expect(card.getByTestId("order-cover-state")).toHaveText(state);
  await expect(card.getByTestId("order-cover-detail")).toHaveText(detail);
  await expect(card).not.toContainText(FORBIDDEN);
  await signOut(page);
}

/** kolleginbs opens /team: a card waiting for her is listed first; hers carries the two actions. */
async function namedCard(page: Page, when: string) {
  await signIn(page, "kolleginbs.test@navora.test");
  await page.goto("/team");
  await expect(page.getByTestId("shift-offer-card").first().getByTestId("shift-offer-tag")).toHaveText("Für dich eingeteilt");
  const card = page.getByTestId("shift-offer-card").filter({ hasText: when }).last();
  await expect(card.getByTestId("shift-offer-tag")).toHaveText("Für dich eingeteilt");
  const lines = card.getByTestId("shift-offer-line");
  await expect(lines.nth(0)).toHaveText("Pflegekraft B. hat diese Schicht für euer Team übernommen und dich eingeteilt.");
  await expect(lines.nth(1)).toHaveText(/^Bitte bis \S\S \d\d\.\d\d\., \d\d:\d\d bestätigen\.$/);
  await expect(card.getByRole("button")).toHaveText(["Bestätigen", "Ich kann nicht"]);
  await expect(card).not.toContainText(FORBIDDEN);
  await expect(card.getByRole("timer")).toHaveCount(0);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  return card;
}

for (const width of [390, 1440]) {
  test(`at ${width} px a take naming a colleague: she sees «Für dich eingeteilt» first and confirms; the client reads «Gedeckt» only then; another team never sees it`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 });
    const when = await orderShift(page, zurichDay(Date.now(), width === 390 ? 32 : 33));
    await takeNamingColleague(page, when, width, "confirm");

    // UXR-223: before her confirmation the client still reads «Noch nicht gedeckt».
    await clientReads(page, when, /^Noch nicht gedeckt · Beginn /, "Ein Team hat übernommen; die eingeteilte Person bestätigt noch.");
    await otherTeamNeverSees(page, when);

    const card = await namedCard(page, when);
    await snap(page, `bk-c2-confirm-named-${width}.png`);
    await card.getByRole("button", { name: "Bestätigen" }).click();
    const done = page.getByTestId("shift-offer-card").filter({ hasText: when }).last();
    await expect(done.getByTestId("shift-offer-tag")).toHaveText("Für dich eingeteilt");
    await expect(done.getByTestId("shift-offer-line")).toHaveText("Du bist für diese Schicht eingeteilt.");
    await expect(done.getByRole("button")).toHaveCount(0);
    await signOut(page);

    // The taker's team view shows the confirmation as a fact.
    await signIn(page, "pflegebs.test@navora.test");
    await page.goto("/team");
    const seen = page.getByTestId("shift-offer-card").filter({ hasText: when }).last();
    await expect(seen.getByTestId("shift-offer-line")).toHaveText(/^Es geht: Kollegin B\. · bestätigt um \d\d:\d\d$/);
    await signOut(page);

    await clientReads(page, when, "Gedeckt · Person benannt, geprüft für HF", /^Team Testteam Basel · übernommen um \d\d:\d\d$/);
    await otherTeamNeverSees(page, when);
  });

  test(`at ${width} px the named colleague presses «Ich kann nicht»: the order is offered again and the client reads «Nicht mehr gedeckt»`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 });
    const when = await orderShift(page, zurichDay(Date.now(), width === 390 ? 34 : 35));
    await takeNamingColleague(page, when, width, "cannot");
    await otherTeamNeverSees(page, when);

    const card = await namedCard(page, when);
    await card.getByRole("button", { name: "Ich kann nicht" }).click();
    // Her card no longer asks her to act; the release is stated without a reason about her.
    const after = page.getByTestId("shift-offer-card").filter({ hasText: when }).last();
    await expect(after.getByTestId("shift-offer-release")).toHaveText("Nicht mehr übernommen: Kollegin B. kann diese Schicht nicht übernehmen.");
    await expect(after.getByRole("button", { name: "Bestätigen" })).toHaveCount(0);
    await expect(after.getByRole("button", { name: "Ich kann nicht" })).toHaveCount(0);
    await snap(page, `bk-c2-cannot-named-${width}.png`);
    await signOut(page);

    // CGR-234 (d): the team reads the release and the order is offered to it again (new round).
    await signIn(page, "pflegebs.test@navora.test");
    await page.goto("/team");
    const again = page.getByTestId("shift-offer-card").filter({ hasText: when }).last();
    await expect(again.getByTestId("shift-offer-tag")).toHaveText("Neues Angebot");
    await expect(again.getByTestId("shift-offer-release")).toHaveText("Nicht mehr übernommen: Kollegin B. kann diese Schicht nicht übernehmen.");
    await expect(again.getByTestId("shift-offer-broadcast")).toHaveText("Alle passenden Teams sehen dieses Angebot.");
    await expect(again.getByRole("radio", { name: "Ich (Pflegekraft)" })).toBeChecked();
    await expect(again).not.toContainText(FORBIDDEN);
    await snap(page, `bk-c2-cannot-team-${width}.png`);
    await signOut(page);

    await clientReads(page, when, /^Nicht mehr gedeckt · Beginn /, "Die eingeteilte Person kann nicht. Das Angebot geht wieder an alle passenden Teams.");
    await otherTeamNeverSees(page, when);
  });
}
