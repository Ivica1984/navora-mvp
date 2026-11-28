import { execFileSync } from "node:child_process";
import { expect, test, type Page } from "@playwright/test";

// S-1 (founder order 2026-11-22; PR #1671 comments 7071385024, 7071578135; LEARNINGS 2026-11-21 «Eine Hinweisliste darf
// die ganze Seite der Pflegekraft nicht mitreissen»). Reproduction, red on recovery/main 5bf6d7de: when
// `public.my_signals` failed, getMySignals() returned [] and SignalBanner rendered only the hidden «no signal» marker,
// so /field, /team and /operations looked exactly like «no open P1 safety signal». A failed 30 s poll left the banner
// unmarked.
// The failure is forced deterministically by revoking EXECUTE from `authenticated` (42501): the same app code path as
// the 8 s statement timeout on staging (a PostgREST error), with no timing dependence.
// Asserts: the page stays usable; one visible `role=alert` line stands where the signals are; the empty marker is
// absent; «Erneut laden» clears the line once the read works again; a poll that fails after a good read marks the
// banner as not current.
// Fixture: local Supabase only (port 54322). The grant is restored in `finally` and again in afterAll (one worker,
// serial run, playwright.config.ts), so no later spec sees the revoked state. Synthetic seed accounts only; no row is
// written.
const NURSE = "pflege.test@navora.test"; // org A, nurse, Testteam Nord (supabase/seed.sql)
const OPS = "ops.test@navora.test"; // org A, operations (supabase/seed.sql)
const PASSWORD = "navora-local-only";
const DB_URL = process.env.E2E_DB_URL ?? "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
const LOCAL_DB = /^postgres(ql)?:\/\/[^@]+@(127\.0\.0\.1|localhost):54322\//;
// Working wording (src/features/signals/banner-state.ts); final wording at the `uxa` gate, content check by `cra`.
const UNAVAILABLE = "Sicherheitssignale konnten nicht geladen werden.";
const STALE = "Sicherheitssignale konnten nicht aktualisiert werden.";

function psql(sql: string): string {
  if (!LOCAL_DB.test(DB_URL)) throw new Error("S-1 fixture: only the local Supabase database (port 54322)");
  return execFileSync("psql", [DB_URL, "-X", "-q", "-At", "-v", "ON_ERROR_STOP=1", "-c", sql], { encoding: "utf8" }).trim();
}
// Exactly the grant of the migrations (0060, 0080: revoke from public, anon; grant execute to authenticated).
const breakSignals = () => psql("revoke execute on function public.my_signals() from authenticated");
const restoreSignals = () => psql("grant execute on function public.my_signals() to authenticated");

async function signIn(page: Page, email: string, landing: RegExp) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(landing);
}

const alertLine = (page: Page) => page.getByTestId("safety-signals-unavailable");

test.describe("S-1: the P1 safety signals are never silently empty", () => {
  test.afterAll(() => {
    restoreSignals();
  });

  for (const width of [390, 1440]) {
    test(`/field at ${width} px: a failed read shows one visible alert line, not «no signal»; «Erneut laden» clears it`, async ({ page }) => {
      await page.setViewportSize({ width, height: 900 });
      await signIn(page, NURSE, /\/field$/);
      // Control: with the read working there is no alert line.
      await expect(page.getByRole("navigation", { name: "Tag wechseln" })).toBeVisible();
      await expect(alertLine(page)).toHaveCount(0);

      breakSignals();
      try {
        await page.reload();
        // The page stays usable (fail-visible, not fail-hard).
        await expect(page.getByRole("navigation", { name: "Tag wechseln" })).toBeVisible();
        const line = alertLine(page);
        await expect(line).toBeVisible();
        await expect(line).toHaveAttribute("role", "alert");
        await expect(line).toHaveAttribute("data-status", "unavailable");
        await expect(line).toContainText(UNAVAILABLE);
        await expect(page.getByTestId("safety-signals-empty")).toHaveCount(0);
        // The line stands above the day's content: inside the signal section, the first block of <main>.
        await expect(page.getByTestId("safety-signals")).toContainText(UNAVAILABLE);
        if (width === 390) {
          const box = await line.boundingBox();
          expect(box, "alert line has a box").not.toBeNull();
          expect(box!.x).toBeGreaterThanOrEqual(0);
          expect(box!.x + box!.width).toBeLessThanOrEqual(390);
        }
        // Still failing: «Erneut laden» keeps the line.
        await line.getByRole("button", { name: "Erneut laden" }).click();
        await expect(line).toContainText(UNAVAILABLE);
      } finally {
        restoreSignals();
      }
      // Recovery without a reload.
      await alertLine(page).getByRole("button", { name: "Erneut laden" }).click();
      await expect(alertLine(page)).toHaveCount(0);
    });
  }

  test("/team and /operations: a failed read shows the alert line, the page stays", async ({ page }) => {
    await signIn(page, NURSE, /\/field$/);
    breakSignals();
    try {
      await page.goto("/team");
      await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
      await expect(alertLine(page)).toBeVisible();
      await expect(alertLine(page)).toContainText(UNAVAILABLE);
      await expect(page.getByTestId("safety-signals-empty")).toHaveCount(0);
    } finally {
      restoreSignals();
    }
    await page.getByRole("button", { name: "Abmelden" }).click();
    await page.waitForURL(/\/login$/);

    await signIn(page, OPS, /\/operations$/);
    breakSignals();
    try {
      await page.reload();
      await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
      await expect(alertLine(page)).toBeVisible();
      await expect(alertLine(page)).toContainText(UNAVAILABLE);
      await expect(page.getByTestId("safety-signals-empty")).toHaveCount(0);
    } finally {
      restoreSignals();
    }
  });

  test("/field: a poll that fails after a good read marks the banner as not current (stale), with the time", async ({ page }) => {
    test.setTimeout(120_000);
    await signIn(page, NURSE, /\/field$/);
    await expect(page.getByRole("navigation", { name: "Tag wechseln" })).toBeVisible();
    await expect(alertLine(page)).toHaveCount(0);
    breakSignals();
    try {
      // The banner polls every 30 s (SIGNAL_POLL_MS); the next poll fails. No reload.
      const line = alertLine(page);
      await expect(line).toBeVisible({ timeout: 45_000 });
      await expect(line).toHaveAttribute("data-status", "stale");
      await expect(line).toContainText(STALE);
      await expect(line).toContainText(/Stand \d{2}:\d{2}\./);
      await expect(page.getByTestId("safety-signals-empty")).toHaveCount(0);
    } finally {
      restoreSignals();
    }
    await alertLine(page).getByRole("button", { name: "Erneut laden" }).click();
    await expect(alertLine(page)).toHaveCount(0);
  });
});
