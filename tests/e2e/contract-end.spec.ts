import { expect, test, type Page } from "@playwright/test";

// ADM2 part (b) (migration 0092, ADR-115) at phone width. Synthetic local-only accounts of Testorganisation C from
// supabase/seed.sql (its own organisation, so the org-A and org-B fixtures and counts stay as they are):
// - teamc.test signs in. Her recorded contract ends in 14 days (day 14 of ADM2-14): /work shows her the date her access
//   ends (ADM2-14 (a)).
// - vertrag.test is the primary nurse of Testfall C1; her contract ended the day before yesterday, so her access ended at
//   the start of yesterday without a command (ADM2-13, "the day after"): Testteam C sees "Bezugspflege neu bestimmen"
//   on /team (ADM2-15 (b)).
// - bald.test is the deputy nurse of Testfall C1; her contract ends in 10 days: the team's registered nurse sees her in
//   "Austritte in den nächsten 14 Tagen" with the case reference and role, no client name (ADM2-12, ADM2-15 (a)).
// The pinned-clock paths (day 15 / day 14, the boundary at 00:00, DST, restore, OPS1) are in pgTAP 092. Nothing here
// writes data.
const NURSE = "teamc.test@navora.test";
const PASSWORD = "navora-local-only";

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

/** The Zurich calendar day `n` days from today, as "DD.MM.YYYY" (the seed dates its contracts by the same day). */
function zurichDay(n: number): string {
  const today = new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Zurich" }).format(new Date());
  const [y, m, d] = today.split("-").map(Number);
  const t = new Date(Date.UTC(y, m - 1, d + n));
  return `${String(t.getUTCDate()).padStart(2, "0")}.${String(t.getUTCMonth() + 1).padStart(2, "0")}.${t.getUTCFullYear()}`;
}

test("day 14: /work shows her the date her access ends (ADM2-14 a)", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await signIn(page, NURSE);
  await page.goto("/work");
  const notice = page.getByTestId("contract-end-notice");
  await expect(notice).toBeVisible();
  await expect(notice).toContainText(`Dein Vertrag endet am ${zurichDay(14)}.`);
  await expect(notice).toContainText(`Ab ${zurichDay(15)} hast du keinen Zugang mehr zu NAVORA.`);
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(390);
});

test("the day after a contract end the team sees whose responsibility to give again (ADM2-15 b, ADM2-12)", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await signIn(page, NURSE);
  await page.goto("/team");

  // ADM2-15 (b): the open case still names the former colleague as primary nurse.
  const open = page.getByRole("region", { name: "Offene Verantwortung nach Austritt" });
  const item = open.getByTestId("successor-item");
  await expect(item).toHaveCount(1);
  await expect(item).toContainText("Bezugspflege neu bestimmen");
  await expect(item).toContainText("Fall-Ref. 000261 · Testteam C: Pflegekraft Vertragsende (Bezugspflege) hat keinen Zugang mehr");
  await expect(item).toContainText(`seit ${zurichDay(-1)}`);
  await expect(item).not.toContainText("Testfall");
  expect(await open.evaluate((el) => el.scrollWidth - el.clientWidth)).toBeLessThanOrEqual(0);

  // ADM2-12 / ADM2-15 (a): the colleague who leaves in 10 days, with case reference and role only.
  const leavers = page.getByRole("region", { name: "Austritte in den nächsten 14 Tagen" });
  const leaver = leavers.getByTestId("leaver");
  await expect(leaver).toHaveCount(1);
  await expect(leaver).toContainText(`Pflegekraft Bald: Vertragsende ${zurichDay(10)}, Zugang endet am ${zurichDay(11)}`);
  await expect(leaver.getByTestId("leaver-cases")).toHaveText("Fall-Ref. 000261 (Stellvertretung, Testteam C)");
  await expect(leaver.getByTestId("leaver-reports")).toHaveText("Offene Berichte: keine offenen Berichte");
  await expect(leaver).not.toContainText("Testfall");
  // She does not see her own contract end in the team's list.
  await expect(leavers).not.toContainText("Pflegekraft Team C");
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(390);
});
