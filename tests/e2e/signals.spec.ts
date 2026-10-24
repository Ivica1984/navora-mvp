import { expect, test, type Page } from "@playwright/test";

// SIG1 (migration 0060, ADR-074): a P1 safety signal reaches the team without a reload, and one member takes it.
// Synthetic local-only accounts from supabase/seed.sql; both are members of Testteam Nord.
const NURSE = "pflege.test@navora.test";
const ASSISTANT = "assist.test@navora.test";
const PASSWORD = "navora-local-only";
// The poll runs every 30 s (SIG1-3: within 60 s); allow for the server's 15-s throttle and CI latency.
const WITHIN = 75_000;

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(/\/field$/);
}

test("a no-show reaches a colleague's open /field without navigation; one tap takes it, the others see who (SIG1-3, SIG1-4)", async ({ browser }) => {
  test.setTimeout(240_000);
  // A visit four days ahead at 06:15 (no other test uses that day).
  const day = new Date(Date.now() + 4 * 86_400_000).toISOString().slice(0, 10);
  const signal = (page: Page, testId: string) =>
    page.locator(`[data-testid="${testId}"][data-kind="no_show"][data-visit-date="${day}"]`);

  const assistantContext = await browser.newContext();
  const nurseContext = await browser.newContext();
  const assistant = await assistantContext.newPage();
  const nurse = await nurseContext.newPage();

  // The care assistant has her day open; she does not navigate from here on.
  await assistant.setViewportSize({ width: 390, height: 844 });
  await signIn(assistant, ASSISTANT);
  await expect(signal(assistant, "safety-signal")).toHaveCount(0);

  // The nurse plans a visit, sets off and finds nobody home.
  await signIn(nurse, NURSE);
  await nurse.goto("/team");
  const card = nurse.getByRole("article", { name: /Fall Testfall 08/ });
  await card.getByRole("button", { name: "Einsatz planen" }).click();
  const planForm = card.getByRole("form", { name: "Einsatz planen" });
  await planForm.getByLabel("Datum").fill(day);
  await planForm.getByLabel("Von").fill("06:15");
  await planForm.getByLabel("Bis").fill("06:45");
  await planForm.getByLabel("A", { exact: true }).fill("30");
  await planForm.getByRole("button", { name: "Einsatz speichern" }).click();
  await expect(card.getByRole("list", { name: "Geplante Einsätze" })).toContainText("06:15–06:45");

  await nurse.goto(`/field?datum=${day}`);
  const visit = nurse.getByRole("article", { name: /06:15 – 06:45, Testfall 08/ });
  await visit.getByRole("button", { name: "Losfahren" }).click();
  await visit.getByRole("button", { name: "Nicht angetroffen" }).click();
  await visit.locator("textarea[name=note]").fill("Synthetisch: niemand öffnet");
  await visit.getByRole("button", { name: "Nichtantreffen melden" }).click();
  await expect(visit.getByRole("button", { name: "Ergebnis erfassen" })).toBeVisible();

  // SIG1-3: the colleague's open page shows it at the top, with the fixed text and a link to the visit's day.
  const incoming = signal(assistant, "safety-signal");
  await expect(incoming).toHaveCount(1, { timeout: WITHIN });
  await expect(incoming).toContainText("Klientin öffnet nicht");
  await expect(incoming.getByRole("link")).toHaveAttribute("href", `/field?datum=${day}`);
  await expect(incoming).not.toContainText("Testfall");   // no client name in the signal

  // SIG1-4: one tap; it leaves her top list and shows as taken by her.
  await incoming.getByRole("button", { name: "Ich übernehme" }).click();
  await expect(signal(assistant, "safety-signal")).toHaveCount(0);
  await expect(signal(assistant, "safety-signal-taken")).toContainText("von dir übernommen");

  // The nurse's open page (no navigation since the no-show) shows who took it.
  await expect(signal(nurse, "safety-signal-taken")).toContainText("übernommen von", { timeout: WITHIN });
  await expect(signal(nurse, "safety-signal")).toHaveCount(0);

  const overflow = await assistant.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  expect(overflow).toBeLessThanOrEqual(0);

  await assistantContext.close();
  await nurseContext.close();
});
