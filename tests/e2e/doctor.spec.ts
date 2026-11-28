import { expect, test, type Page } from "@playwright/test";

// ORD0 (migration 0061, ADR-075): the team records in one step that the doctor was informed, and the task closes.
// Synthetic local-only accounts from supabase/seed.sql: pflege.test is in Testteam Nord, which runs Testfall 08 (needs
// assessment done, no medical order). Planning an A visit without an order opens the task (CGR-36). The database rules
// (dates, who may record, replay) are pgTAP 063.
const NURSE = "pflege.test@navora.test";
const PASSWORD = "navora-local-only";

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(/\/field$/);
}

test("an A visit without an order opens 'Hausärztin/Hausarzt informieren'; one step records it and closes the task, at phone width (ORD0-1 to ORD0-3)", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await signIn(page, NURSE);
  await page.goto("/team");
  const card = page.getByRole("article", { name: /Fall Testfall 08/ });

  // A visit nine days ahead at 05:30 (no other test uses that slot).
  const day = new Date(Date.now() + 9 * 86_400_000).toISOString().slice(0, 10);
  await card.getByRole("button", { name: "Einsatz planen" }).click();
  const planForm = card.getByRole("form", { name: "Einsatz planen" });
  await planForm.getByLabel("Datum").fill(day);
  await planForm.getByLabel("Von").fill("05:30");
  await planForm.getByLabel("Bis").fill("06:00");
  await planForm.getByLabel("A", { exact: true }).fill("30");
  await planForm.getByRole("button", { name: "Einsatz speichern" }).click();
  await expect(card.getByRole("list", { name: "Geplante Einsätze" })).toContainText("05:30–06:00");

  // CGR-36: the task is open and offers the one-step action.
  const task = card.getByTestId("inform-gp-task");
  await expect(task).toContainText("Hausärztin/Hausarzt informieren (A/C ohne Verordnung)");
  await task.getByRole("button", { name: "Informiert – erfassen" }).click();
  const form = task.getByRole("form", { name: "Hausärztin/Hausarzt informiert" });
  const today = await form.getByLabel("Informiert am").inputValue();
  expect(today).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  await form.getByLabel("Telefon").check();
  await form.getByRole("button", { name: "Informiert speichern" }).click();

  // ORD0-2/3: the task is gone; the card shows the recorded fact with date and channel.
  await expect(card.getByTestId("inform-gp-task")).toHaveCount(0);
  const [y, m, d] = today.split("-");
  await expect(card.getByTestId("gp-informed")).toHaveText(`Hausärztin/Hausarzt informiert am ${d}.${m}.${y} (Telefon)`);

  // ORD0-2: the next plan refresh (every /team load) does not bring the task back (ADR-075, Q12).
  await page.reload();
  await expect(card.getByTestId("inform-gp-task")).toHaveCount(0);

  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  expect(overflow).toBeLessThanOrEqual(0);
});
