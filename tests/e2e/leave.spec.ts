import { expect, test, type Page } from "@playwright/test";

// LEAVE1 part (b) (migrations 0074, 0075, ADR-088): the administrator's open-work list and access end on /admin at phone
// width (LEAVE1-12 (1), LEAVE1-1; since RLS4-C2 the list is read in the access-end step only), and the leaver's screen (LEAVE1-6). Synthetic local-only accounts from
// supabase/seed.sql. The coach account (org A, in no team, no cases) is the leaver here; the access is restored at the
// end (and in afterAll if a step failed), so the specs that run later are unaffected (workers: 1).
const ADMIN = "admin.test@navora.test"; // org A, role admin
const COACH = "coach.test@navora.test"; // org A, role coach
const PASSWORD = "navora-local-only";

async function signIn(page: Page, email: string, landing: RegExp) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(landing);
}

async function signOut(page: Page) {
  await page.context().clearCookies();
}

function coachRow(page: Page) {
  // The row's label is the display name once set (admin.spec renames the coach), so find it by its e-mail.
  return page.getByRole("region", { name: "Mitglieder" }).locator('li[aria-label^="Mitglied "]', { hasText: COACH });
}

async function restoreIfEnded(page: Page) {
  await signIn(page, ADMIN, /\/operations$/);
  await page.goto("/admin");
  const row = coachRow(page);
  const restore = row.getByRole("button", { name: "Zugang wiederherstellen" });
  if (await restore.isVisible()) {
    await restore.click();
    const form = row.getByRole("form", { name: "Zugang wiederherstellen" });
    await form.getByLabel("Grund").selectOption("ended_in_error");
    await form.getByRole("button", { name: "Wiederherstellen" }).click();
    await expect(row.getByRole("button", { name: "Zugang beenden" })).toBeVisible();
  }
  await signOut(page);
}

test.afterAll(async ({ browser }) => {
  const page = await browser.newPage();
  await restoreIfEnded(page);
  await page.close();
});

test("an administrator sees the open work, ends the access, and the leaver sees only the notice (LEAVE1-12, LEAVE1-6)", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await signIn(page, ADMIN, /\/operations$/);
  await page.goto("/admin");

  // RLS4-C2 (1): the member list shows no member's open reports (no standing per-person list on /admin).
  const row = coachRow(page);
  const nurse = page.getByRole("region", { name: "Mitglieder" }).locator('li[aria-label^="Mitglied "]', { hasText: "pflege.test@navora.test" });
  await expect(row.getByRole("button", { name: "Zugang beenden" })).toBeVisible();
  await expect(page.getByRole("region", { name: "Mitglieder" }).getByTestId("open-reports")).toHaveCount(0);
  await expect(page.getByRole("region", { name: "Mitglieder" }).getByText(/Offene Berichte/)).toHaveCount(0);

  // LEAVE1-12 (1) with RLS4-C2: opening her access-end step lists her open reports by kind (counts by kind, never
  // content or a reason), for her only. Cancelling closes the step and the list.
  await nurse.getByRole("button", { name: "Zugang beenden" }).click();
  await expect(nurse.getByRole("form", { name: "Zugang beenden" }).getByTestId("open-reports")).toContainText("Offene Berichte:");
  await expect(page.getByRole("region", { name: "Mitglieder" }).getByTestId("open-reports")).toHaveCount(1);
  await nurse.getByRole("button", { name: "Abbrechen" }).click();
  await expect(page.getByRole("region", { name: "Mitglieder" }).getByTestId("open-reports")).toHaveCount(0);

  // LEAVE1-12 (1): the leaver's step lists her open reports before the end (none for this account). LEAVE1-1: codes only.
  await row.getByRole("button", { name: "Zugang beenden" }).click();
  const form = row.getByRole("form", { name: "Zugang beenden" });
  await expect(form.getByTestId("open-reports")).toContainText("Offene Berichte: keine offenen Berichte");
  await expect(form.getByRole("textbox")).toHaveCount(0);
  await expect(form).toContainText("Ihre offenen Berichte bleiben für das Team sichtbar");
  await form.getByLabel("Grund").selectOption("employment_ended");
  await form.getByRole("button", { name: "Zugang beenden" }).click();
  await expect(row.getByTestId("access-ended-notice")).toHaveText("Zugang beendet. Keine offenen Berichte.");
  await expect(row.getByTestId("access-state")).toContainText("Zugang beendet seit");
  await expect(row.getByTestId("access-state")).toContainText("Anstellung beendet");
  await expect(row.getByRole("button", { name: "Zugang wiederherstellen" })).toBeVisible();
  // /admin keeps its desktop sidebar layout (as push.spec SIG2-C1); the access block itself must not overflow its box.
  const block = row.getByLabel("Zugang", { exact: true });
  expect(await block.evaluate((el) => el.scrollWidth - el.clientWidth)).toBeLessThanOrEqual(0);
  await signOut(page);

  // LEAVE1-6: signed in after the end, she sees one notice on every route; no client data, names or counts.
  await signIn(page, COACH, /\/operations$/);
  for (const path of ["/operations", "/field", "/admin", "/team"]) {
    await page.goto(path);
    const notice = page.getByTestId("access-ended");
    await expect(notice).toHaveText(/Ihr Zugang ist beendet\. Bitte wenden Sie sich an Ihre Organisation\./);
    await expect(page.getByText(/Testfall|Testteam|Klient/)).toHaveCount(0);
  }
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1)).toBe(true);
  await signOut(page);

  // LEAVE1-7: restored, exactly the access she had.
  await restoreIfEnded(page);
  await signIn(page, COACH, /\/operations$/);
  await expect(page.getByTestId("access-ended")).toHaveCount(0);
});
