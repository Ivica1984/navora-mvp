import { expect, test, type Page } from "@playwright/test";
import { zurichDay } from "./support/durchgang-time";

// BK-c2 screens (brief docs/agents/briefs/BK.md 04:39 (3), (4); 08:39 (3), (4); ADR-200; BK5_OFFER_TEMPLATE.md §2–§5,
// UX_REVIEW.md 07:52). Synthetic local-only accounts from supabase/seed.sql (Testorganisation S, simulation):
//   kundebs.test  client of «Testheim Rhein (synthetisch)»: orders one HF shift and reads its status;
//   pflegebs.test registered nurse of Testteam Basel, the only member with the HF grade: takes it naming herself;
//   assistbs.test care assistant of Testteam Basel: sees the team's take, has no action;
//   kolleginbs.test second registered nurse of Testteam Basel (seed addition, PO 11:39 (2)): listed, not chosen here;
//   pflege.test   member of Testteam Nord (org A): never sees the card.
// The take that names a colleague (CGR-230 «Bestätigen», UXR-222 «Ich kann nicht») is tests/e2e/bk-c2-colleague-take.spec.ts.
// Each width uses its own Zurich day 30/31 days ahead (no clock change in that window in November/December), so
// pflegebs is free (step 3) and every run adds one synthetic order per width; no assertion counts orders.
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

for (const width of [390, 1440]) {
  test(`at ${width} px a team member takes a shift naming herself; her team sees it, another team never; the client reads «Gedeckt» only then`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 });
    const day = zurichDay(Date.now(), width === 390 ? 30 : 31);
    const when = `${deDate(day)} 07:00`;

    // 1. The client orders one HF day shift.
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
    const clientCard = page.getByTestId("client-orders").locator("li", { hasText: when }).last();
    await expect(clientCard.getByTestId("order-cover-state")).toHaveText(/^Noch nicht gedeckt · Beginn \S\S \d\d\.\d\d\., 07:00$/);
    await expect(clientCard.getByTestId("order-cover-detail")).toHaveText("Angebot an alle passenden Teams gleichzeitig.");
    await expect(clientCard).not.toContainText(FORBIDDEN);
    await signOut(page);

    // 2. Another team never sees it (BK-5n, template §2).
    await signIn(page, "pflege.test@navora.test");
    await page.goto("/team");
    await expect(page.getByTestId("shift-offers")).toBeVisible();
    await expect(page.getByTestId("shift-offer-card").filter({ hasText: when })).toHaveCount(0);
    await signOut(page);

    // 3. The member with the grade sees the offer: neutral broadcast line, herself first and pre-selected.
    await signIn(page, "pflegebs.test@navora.test");
    await page.goto("/team");
    const card = page.getByTestId("shift-offer-card").filter({ hasText: when }).last();
    await expect(card.getByTestId("shift-offer-tag")).toHaveText("Neues Angebot");
    await expect(card.getByTestId("shift-offer-broadcast")).toHaveText("Alle passenden Teams sehen dieses Angebot.");
    await expect(card.getByRole("radio", { name: "Ich (Pflegekraft)" })).toBeChecked();
    // AUT-132: the eligible colleague is listed after her; the care assistant (no HF grade) is not listed; no step or
    // reason of anybody is shown. (Changed from one radio to two with the seed addition of PO 11:39 (2); the negative
    // for the member who does not pass is now asserted by name.)
    await expect(card.getByRole("radio")).toHaveCount(2);
    await expect(card.getByRole("radio", { name: "Kollegin B." })).not.toBeChecked();
    await expect(card.getByRole("radio", { name: "Pflegekraft A." })).toHaveCount(0);
    await expect(card).not.toContainText(FORBIDDEN);
    await expect(card.getByRole("timer")).toHaveCount(0);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
    await card.getByRole("button", { name: "Übernehmen mit Pflegekraft" }).click();

    // 4. UXR-221: the card stays with «Übernommen» and the going person; no primary action (no un-take in BK-c).
    const taken = page.getByTestId("shift-offer-card").filter({ hasText: when }).last();
    await expect(taken.getByTestId("shift-offer-tag")).toHaveText("Übernommen");
    await expect(taken.getByTestId("shift-offer-line")).toHaveText("Ihr habt diese Schicht übernommen. Es geht: Pflegekraft B.");
    await expect(taken.getByRole("button")).toHaveCount(0);
    // CGR-235 (a): a self-named take counts as acknowledged; the going person sees her way back, nobody else does.
    await expect(taken.getByTestId("shift-offer-way-back")).toHaveText("Kannst du doch nicht, erfasse eine Abwesenheit; die Schicht wird sofort neu angeboten.");
    await signOut(page);

    // 5. A colleague of the same team sees the team's take and the going person, with no action.
    await signIn(page, "assistbs.test@navora.test");
    await page.goto("/team");
    const seen = page.getByTestId("shift-offer-card").filter({ hasText: when }).last();
    await expect(seen.getByTestId("shift-offer-tag")).toHaveText("Übernommen");
    await expect(seen.getByTestId("shift-offer-line")).toHaveText("Ihr habt diese Schicht übernommen. Es geht: Pflegekraft B.");
    await expect(seen.getByRole("button")).toHaveCount(0);
    await expect(seen.getByTestId("shift-offer-way-back")).toHaveCount(0);
    await signOut(page);

    // 6. The client now reads «Gedeckt» with the ordered level (CGR-226 (a)), the team and the time of the take.
    await signIn(page, "kundebs.test@navora.test");
    await page.goto("/order");
    const covered = page.getByTestId("client-orders").locator("li", { hasText: when }).last();
    await expect(covered.getByTestId("order-cover-state")).toHaveText("Gedeckt · Person benannt, geprüft für HF");
    await expect(covered.getByTestId("order-cover-detail")).toHaveText(/^Team Testteam Basel · übernommen um \d\d:\d\d$/);
    await expect(covered).not.toContainText(FORBIDDEN);
  });
}
