import { expect, test, type Page } from "@playwright/test";
import { zurichDay } from "./support/durchgang-time";

// BK-e1c at 390 × 844 (brief docs/agents/briefs/BK.md §PO amendment 2026-11-18 17:39, C1; R3b, CGR-257, UXR-248;
// ADR-203 amendment BK-e1c). Synthetic local-only account from supabase/seed.sql (Testorganisation Nacht):
//   nacht.test  registered nurse of Testteam Nacht; her night visit of yesterday 22:00–07:00 was started at 22:01 and
//               still runs. The server clock cannot be moved in e2e; the predicate of migration 0149 reads only the date,
//               so «yesterday's visit on today's view» is the same case as 03:00 on day 2.
// On day 2 («Heute») the card is the first card, carries the line «Läuft seit gestern 22:00» (copy PROPOSED, `uxa`),
// «Ereignis melden» and «Einsatz abschliessen» on the card itself (CGR-257: a link alone does not count), and
// «Einsatz abschliessen» completes it. After completion it stays on day 2 (PROPOSED, review question 5) with the report
// step on the card. The spec completes the seeded visit, so it runs once per database reset (playwright: retries 0).
const PASSWORD = "navora-local-only";

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

async function noSidewaysScroll(page: Page) {
  expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(0);
}

test("BK-e1c at 390 px: yesterday's running night visit is the first card of «Heute», and «Einsatz abschliessen» completes it there", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  const today = zurichDay(Date.now(), 0);

  await signIn(page, "nacht.test@navora.test");
  await page.goto(`/field?datum=${today}`);
  await expect(page.getByRole("heading", { level: 1, name: "Heute" })).toBeVisible();

  // C1: first card, below any P1 signal (the banner sits above the list), with the carried line.
  const first = page.getByRole("list", { name: "Einsätze" }).getByRole("listitem").first();
  await expect(first).toHaveAttribute("data-testid", "next-visit");
  const card = first.getByRole("article", { name: /22:00 – 07:00/ });
  await expect(card).toHaveCount(1);
  await expect(card.getByTestId("visit-carried")).toHaveText("Läuft seit gestern 22:00");
  await expect(card.getByTestId("visit-status")).toHaveText("Gestartet");

  // CGR-257: both controls on the card itself.
  await expect(card.getByRole("button", { name: "Ereignis melden" })).toBeVisible();
  const complete = card.getByRole("button", { name: "Einsatz abschliessen" });
  await expect(complete).toBeVisible();
  await noSidewaysScroll(page);

  // «Einsatz abschliessen» completes it on day 2.
  await complete.click();
  const after = page.getByRole("article", { name: /22:00 – 07:00/ });
  await expect(after.getByTestId("visit-status")).toHaveText("Abgeschlossen");
  await expect(after.getByRole("button", { name: "Einsatz abschliessen" })).toHaveCount(0);

  // PROPOSED (review question 5): it stays on day 2 after the reload, with the line for a completed carried visit.
  await page.reload();
  const reloaded = page.getByRole("article", { name: /22:00 – 07:00/ });
  await expect(reloaded.getByTestId("visit-status")).toHaveText("Abgeschlossen");
  await expect(reloaded.getByTestId("visit-carried")).toHaveText("Begonnen gestern 22:00");
  await noSidewaysScroll(page);
});
