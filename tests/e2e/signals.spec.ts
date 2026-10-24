import { expect, test, type Page } from "@playwright/test";

// SIG1 (migration 0060, ADR-074): a P1 safety signal reaches an open page without a reload, and one tap takes it.
// Synthetic local-only accounts from supabase/seed.sql. The recipient is pflege.test (Testteam Nord): by the time this
// file runs, field.spec.ts has recorded assist.test absent from yesterday (ABS1-C6), and an absent member receives no
// delivery (ADR-074; asserted in pgTAP 062). Two browser contexts of the same nurse: one page stays open on /field and
// never navigates; the other records the no-show.
const NURSE = "pflege.test@navora.test";
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

test("a no-show reaches an open /field without navigation; one tap takes it, the other open page shows it taken (SIG1-3, SIG1-4)", async ({ browser }) => {
  test.setTimeout(240_000);
  // A visit four days ahead at 06:15 (no other test uses that day).
  const day = new Date(Date.now() + 4 * 86_400_000).toISOString().slice(0, 10);
  const signal = (page: Page, testId: string) =>
    page.locator(`[data-testid="${testId}"][data-kind="no_show"][data-visit-date="${day}"]`);

  const watchContext = await browser.newContext();
  const actContext = await browser.newContext();
  const watch = await watchContext.newPage();
  const act = await actContext.newPage();

  // Her day is open on the phone; this page does not navigate from here on.
  await watch.setViewportSize({ width: 390, height: 844 });
  await signIn(watch, NURSE);
  await expect(signal(watch, "safety-signal")).toHaveCount(0);

  // In the other session she plans a visit, sets off and finds nobody home.
  await signIn(act, NURSE);
  await act.goto("/team");
  const card = act.getByRole("article", { name: /Fall Testfall 08/ });
  await card.getByRole("button", { name: "Einsatz planen" }).click();
  const planForm = card.getByRole("form", { name: "Einsatz planen" });
  await planForm.getByLabel("Datum").fill(day);
  await planForm.getByLabel("Von").fill("06:15");
  await planForm.getByLabel("Bis").fill("06:45");
  await planForm.getByLabel("A", { exact: true }).fill("30");
  await planForm.getByRole("button", { name: "Einsatz speichern" }).click();
  await expect(card.getByRole("list", { name: "Geplante Einsätze" })).toContainText("06:15–06:45");

  await act.goto(`/field?datum=${day}`);
  const visit = act.getByRole("article", { name: /06:15 – 06:45, Testfall 08/ });
  await visit.getByRole("button", { name: "Losfahren" }).click();
  await visit.getByRole("button", { name: "Nicht angetroffen" }).click();
  await visit.locator("textarea[name=note]").fill("Synthetisch: niemand öffnet");
  await visit.getByRole("button", { name: "Nichtantreffen melden" }).click();
  await expect(visit.getByRole("button", { name: "Ergebnis erfassen" })).toBeVisible();

  // SIG1-3: the open page shows it at the top, with the fixed text and a link to the visit's day.
  const incoming = signal(watch, "safety-signal");
  await expect(incoming).toHaveCount(1, { timeout: WITHIN });
  await expect(incoming).toContainText("Klientin öffnet nicht");
  await expect(incoming.getByRole("link")).toHaveAttribute("href", `/field?datum=${day}`);
  await expect(incoming).not.toContainText("Testfall");   // no client name in the signal

  // SIG1-4: one tap; it leaves the top list and shows as taken.
  await incoming.getByRole("button", { name: "Ich übernehme" }).click();
  await expect(signal(watch, "safety-signal")).toHaveCount(0);
  await expect(signal(watch, "safety-signal-taken")).toContainText("von dir übernommen");

  // The other open page (no navigation since the no-show) follows on its next poll.
  await expect(signal(act, "safety-signal-taken")).toContainText("übernommen", { timeout: WITHIN });
  await expect(signal(act, "safety-signal")).toHaveCount(0);

  const overflow = await watch.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  expect(overflow).toBeLessThanOrEqual(0);

  await watchContext.close();
  await actContext.close();
});
