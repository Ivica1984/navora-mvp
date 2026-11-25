import { execFileSync } from "node:child_process";
import { expect, test, type Page } from "@playwright/test";
import { zurichDay } from "./support/durchgang-time";

// ORDER-F1 (brief docs/agents/briefs/ORDER-F1.md scope (b), criterion T-2). On staging (staging-smoke 45687575702) the
// order list read `public.client_orders()` hit the 8 s statement timeout (57014) and the whole re-render of /order
// threw, so after a successful order the client saw no list. Here the failure is forced deterministically by revoking
// EXECUTE from `authenticated` (42501): the same app code path (PostgREST error), no timing dependence (PERF1 pattern,
// perf1-field-degrade.spec.ts).
// Asserts: /order keeps its heading and its form; one visible line stands where the list would be; the list is never
// shown as empty («Noch kein Auftrag», a count of 0); an order can still be confirmed and is named in the confirmation;
// after the restore the list is back and holds that order (criterion T-1 «sent = shown» is bk-a-order.spec.ts).
// Fixture: local Supabase only (port 54322); the grant is restored in `finally` and again in afterAll (one worker,
// serial run, playwright.config.ts), so no later spec sees the revoked state. Synthetic seed account only; every run
// adds one synthetic order; no assertion counts all orders.
const CLIENT = "kundebs.test@navora.test"; // client of «Testheim Rhein (synthetisch)», org S (supabase/seed.sql)
const PASSWORD = "navora-local-only";
const DB_URL = process.env.E2E_DB_URL ?? "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
const LOCAL_DB = /^postgres(ql)?:\/\/[^@]+@(127\.0\.0\.1|localhost):54322\//;
const NOTICE = "Aufträge konnten nicht geladen werden, bitte neu laden.";

function psql(sql: string): string {
  if (!LOCAL_DB.test(DB_URL)) throw new Error("ORDER-F1 fixture: only the local Supabase database (port 54322)");
  return execFileSync("psql", [DB_URL, "-X", "-q", "-At", "-v", "ON_ERROR_STOP=1", "-c", sql], { encoding: "utf8" }).trim();
}
// Exactly the grant of the canonical file (supabase/schema/functions/public.client_orders.sql).
const breakList = () => psql("revoke execute on function public.client_orders() from authenticated");
const restoreList = () => psql("grant execute on function public.client_orders() to authenticated");

async function signIn(page: Page) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(CLIENT);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(/\/order$/);
}

const deDate = (iso: string) => iso.split("-").reverse().join(".");

test.describe("ORDER-F1: /order when the order list read fails", () => {
  test.afterAll(() => {
    restoreList();
  });

  for (const width of [390, 1440]) {
    test(`at ${width} px only the list shows the failure; the form stays usable and an order is still confirmed`, async ({ page }) => {
      await page.setViewportSize({ width, height: 900 });
      await signIn(page);
      // Control: with the list available it renders and the notice is absent.
      await expect(page.getByTestId("client-orders")).toHaveCount(1);
      await expect(page.getByText(NOTICE)).toHaveCount(0);

      breakList();
      try {
        await page.reload();
        await expect(page.getByRole("heading", { name: "Auftrag erfassen" })).toBeVisible();
        const notice = page.getByTestId("client-orders-failed");
        await expect(notice).toHaveCount(1);
        await expect(notice).toHaveRole("alert");
        await expect(notice).toHaveText(NOTICE);
        // Never a silent «none»: no list, no zero count, no empty-state sentence.
        await expect(page.getByTestId("client-orders")).toHaveCount(0);
        await expect(page.getByText("Noch kein Auftrag bestätigt.")).toHaveCount(0);
        await expect(page.getByRole("heading", { name: "Ihre Aufträge", exact: true })).toBeVisible();
        // The rest of the page stays (invoices are a separate read).
        await expect(page.getByTestId("client-invoices")).toBeVisible();
        expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);

        // The form stays usable: one order is confirmed while the list cannot be read.
        const form = page.getByRole("form", { name: "Auftrag" });
        const day = zurichDay(Date.now(), width === 390 ? 14 : 16);
        await form.getByLabel(/^Datum/).fill(deDate(day));
        await form.getByLabel("Beginn", { exact: true }).fill("08:00");
        await form.getByLabel("Ende", { exact: true }).fill("12:00");
        await form.getByLabel("Einsatzort (Postleitzahl)").selectOption("4102");
        await form.getByRole("radio", { name: "FaGe", exact: true }).check();
        await form.getByRole("checkbox", { name: "Grundpflege", exact: true }).check();
        await form.getByRole("button", { name: "Weiter zur Zusammenfassung" }).click();
        await page.getByTestId("order-summary").getByRole("button", { name: "Bestätigen & Absenden" }).click();
        const done = page.getByTestId("order-done");
        await expect(done).toContainText("Auftrag bestätigt");
        await expect(done).toContainText(deDate(day));
        // After the command's re-render the page still stands, with the notice in the list only.
        await expect(page.getByTestId("client-orders-failed")).toHaveText(NOTICE);
        await expect(page.getByRole("form", { name: "Auftrag" })).toBeVisible();
      } finally {
        restoreList();
      }

      // After the restore the list is back and holds the order confirmed while it failed.
      await page.reload();
      await expect(page.getByTestId("client-orders-failed")).toHaveCount(0);
      const mine = page.getByTestId("client-orders").locator("li", { hasText: `${deDate(zurichDay(Date.now(), width === 390 ? 14 : 16))} 08:00` });
      await expect(mine.first()).toBeVisible();
    });
  }
});
