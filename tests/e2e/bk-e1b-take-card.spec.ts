import { expect, test, type Page } from "@playwright/test";
import { zurichDay } from "./support/durchgang-time";
import { TAKE_HEADING } from "@/features/field/heading";
import { TAKE_STREET_NOT_SENT } from "@/features/field/place";
import { TAKE_ENDED_STATUS } from "@/features/field/take-end";
import { TAKE_CANNOT_GO_LINE } from "@/features/field/more-actions";

// BK-e1b take card on /field at 390 × 844 (brief docs/agents/briefs/BK.md §PO amendments 2026-11-18 05:39 … 14:39
// «take-card Playwright at 390 px»; closes UXR-237, UXR-238, UXR-239, UXR-240, UXR-241 in a browser; ADR-203 (11), (13),
// (21)). Synthetic local-only accounts from supabase/seed.sql (Testorganisation S, simulation):
//   kundebs.test  client of «Testheim Rhein (synthetisch)»: orders one night shift 22:00–07:00 (criterion 4);
//   pflegebs.test registered nurse of Testteam Basel: takes it naming herself (self-named = «gedeckt», visit written).
// Live card: heading «Übernommene Schicht» (UXR-239), one card 22:00 – 07:00 (criterion 4), place line with the
// simulation limit (UXR-237), the «Kannst du nicht?» line (UXR-241 / CGR-248), no «Einsatz absagen», no «Heute machen»
// (CGR-249). Ended card: her absence before the start releases the take; the card stays on her day with
// «Nicht mehr deine Schicht» and the reason in text (UXR-238 / CGR-242 (c)) and offers no action (UXR-240).
// Day 36 ahead (bk-c2 specs use 30–35), so pflegebs is free at the take (step 3); no assertion counts orders.
const PASSWORD = "navora-local-only";

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

const deDate = (iso: string) => iso.split("-").reverse().join(".");

async function noSidewaysScroll(page: Page) {
  expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(0);
}

test("BK-e1b at 390 px: a self-named night take is one «Übernommene Schicht» card on her day; after her absence it stays, ended, with no action", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  const day = zurichDay(Date.now(), 36);
  const next = zurichDay(Date.now(), 37);
  const when = `${deDate(day)} 22:00`;

  // 1. The client orders one HF night shift (22:00–07:00 is one order, BK-1c).
  await signIn(page, "kundebs.test@navora.test");
  await page.goto("/order");
  const form = page.getByRole("form", { name: "Auftrag" });
  await form.getByLabel(/^Datum/).fill(deDate(day));
  await form.getByLabel("Beginn", { exact: true }).fill("22:00");
  await form.getByLabel("Ende", { exact: true }).fill("07:00");
  await form.getByLabel("Einsatzort (Postleitzahl)").selectOption("4051");
  await form.getByRole("radio", { name: "HF", exact: true }).check();
  await form.getByRole("checkbox", { name: "Grundpflege", exact: true }).check();
  await form.getByRole("button", { name: "Weiter zur Zusammenfassung" }).click();
  await page.getByTestId("order-summary").getByRole("button", { name: "Bestätigen & Absenden" }).click();
  await expect(page.getByTestId("order-done")).toContainText("Auftrag bestätigt");
  await page.context().clearCookies();

  // 2. pflegebs takes it naming herself.
  await signIn(page, "pflegebs.test@navora.test");
  await page.goto("/team");
  const offer = page.getByTestId("shift-offer-card").filter({ hasText: when }).last();
  await expect(offer.getByRole("radio", { name: "Ich (Pflegekraft)" })).toBeChecked();
  await offer.getByRole("button", { name: "Übernehmen mit Pflegekraft" }).click();
  await expect(page.getByTestId("shift-offer-card").filter({ hasText: when }).last().getByTestId("shift-offer-tag")).toHaveText("Übernommen");

  // 3. Her day: one card from 22:00 to 07:00 (criterion 4), named by its kind, with the simulation's place line.
  await page.goto(`/field?datum=${day}`);
  const cards = page.getByRole("article", { name: /22:00 – 07:00/ });
  await expect(cards).toHaveCount(1);
  const card = cards.first();
  await expect(card.getByRole("heading", { level: 2 })).toHaveText(TAKE_HEADING);
  await expect(card).not.toContainText("ohne Namen");
  await expect(card.getByTestId("visit-place")).toHaveText(`4051 Basel · ${TAKE_STREET_NOT_SENT}`);
  await expect(card.getByTestId("take-cannot-go")).toHaveText(TAKE_CANNOT_GO_LINE);
  await expect(card.getByTestId("take-ended")).toHaveCount(0);
  await expect(card.getByRole("button", { name: "Heute machen" })).toHaveCount(0);
  const more = card.getByTestId("visit-more");
  if (await more.count()) {
    await more.click();
    await expect(card.getByRole("group", { name: "Weitere Aktionen" })).toBeVisible();
  }
  await expect(card.getByRole("button", { name: "Einsatz absagen" })).toHaveCount(0);
  await noSidewaysScroll(page);

  // 4. Before the start she records an absence over that night: the take is released (CGR-250), the card stays.
  const absence = page.getByTestId("absence");
  await absence.getByTestId("absence-open").click();
  const absenceForm = absence.getByRole("form", { name: "Abwesenheit erfassen" });
  await absenceForm.getByLabel("Von", { exact: true }).fill(day);
  await absenceForm.getByLabel("Bis", { exact: true }).fill(next);
  await absenceForm.getByTestId("absence-save").click();
  await expect(absenceForm).toHaveCount(0);

  await page.goto(`/field?datum=${day}`);
  const ended = page.getByRole("article", { name: /22:00 – 07:00/ });
  await expect(ended).toHaveCount(1);
  await expect(ended.getByRole("heading", { level: 2 })).toHaveText(TAKE_HEADING);
  await expect(ended.getByTestId("visit-status")).toHaveText(TAKE_ENDED_STATUS);
  await expect(ended.getByTestId("take-ended")).toHaveText(
    "Die Übernahme gilt nicht mehr: du hast für diese Zeit eine Abwesenheit erfasst. Das Angebot geht wieder an alle passenden Teams.",
  );
  await expect(ended).not.toContainText(/abgesagt/i);
  await expect(ended.getByTestId("take-cannot-go")).toHaveCount(0);
  await expect(ended.getByTestId("visit-more")).toHaveCount(0);
  await expect(ended.getByRole("button")).toHaveCount(0);
  await noSidewaysScroll(page);
  await page.context().clearCookies();

  // 5. The client no longer reads «Gedeckt» for that night (CGR-242).
  await signIn(page, "kundebs.test@navora.test");
  await page.goto("/order");
  const clientCard = page.getByTestId("client-orders").locator("li", { hasText: when }).last();
  await expect(clientCard.getByTestId("order-cover-state")).not.toHaveText(/^Gedeckt/);
});
