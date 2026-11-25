import { execFileSync } from "node:child_process";
import { expect, test, type Page } from "@playwright/test";

// HD-3a FE-128 (founder 2026-11-25 «Die Eingabe gehört noch ins HD-3a.»; brief HD.md §5b, PO amendment 10:39): the home
// enters its planning inputs on /heim. At 390 × 900 px, one test per form plus the role negatives:
// - home limits (lead): a wrong value is refused with a visible text and nothing is written (T-2); a saved value is
//   shown as the database holds it (T-1, read back from `institution_plan`, checked against the table); «nicht
//   eingetragen» makes the draft say «Kein Vorschlag» with a link to exactly these fields; a value changed by somebody
//   else in between is not overwritten (R-6-2 option (a));
// - shift class (lead): the answer names the count the database returned;
// - Pensum and shift model (lead, planner): «nicht eingetragen» takes the person out of the draft and the draft names
//   her with a link to her field;
// - negatives: a planner sees no limit or class form, a viewer and a team nurse see no form at all.
// The test restores every value and the lead role in `finally` (local database only). Fixed rules, no AI.
const PASSWORD = "navora-local-only";
const HOME = "kundebs.test@navora.test";
const NURSE = "pflegebs.test@navora.test";
const INST = "00000000-0000-4000-a000-0000000004c1";
const LEAD_USER = "00000000-0000-4000-a000-0000000009e8";
const DB_URL = process.env.E2E_DB_URL ?? "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
const LOCAL_DB = /^postgres(ql)?:\/\/[^@]+@(127\.0\.0\.1|localhost):54322\//;

function psql(sql: string): string {
  if (!LOCAL_DB.test(DB_URL)) throw new Error("HD-3a planning-input fixture: only the local Supabase database (port 54322)");
  return execFileSync("psql", [DB_URL, "-X", "-q", "-At", "-v", "ON_ERROR_STOP=1", "-c", sql], { encoding: "utf8" }).trim();
}
const limits = () => psql(`select concat_ws('|', min_rest_hours, max_consecutive_days, weekly_target_hours) from public.institutions where id = '${INST}'`);
const setRole = (role: string) => psql(`update public.institution_members set role = '${role}' where institution_id = '${INST}' and user_id = '${LEAD_USER}'`);

async function signIn(page: Page, email: string) {
  await page.context().clearCookies();
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}
async function noSideScroll(page: Page) {
  expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(0);
}
/**
 * Holds every server-action POST (`Next-Action` header) on /heim for `ms` before it reaches the server; returns the undo.
 * #1729 post-merge (ci 45656780068, e2e job 139355475736): the banner of the previous save is still on screen while the
 * next save is in flight, so a wait for the same banner text passed before the write. The hold makes that window
 * deterministic instead of depending on runner speed.
 */
async function holdServerActions(page: Page, ms: number): Promise<() => Promise<void>> {
  const pattern = "**/heim**";
  await page.route(pattern, async (route) => {
    const req = route.request();
    if (req.method() === "POST" && req.headers()["next-action"]) await new Promise((r) => setTimeout(r, ms));
    try {
      await route.continue();
    } catch {
      // The page went away while the request was held: nothing reaches the server.
    }
  });
  return () => page.unroute(pattern);
}
/** Clicks a save button and waits for that save's own server-action response (the write is done before it returns). */
async function saveAndWait(page: Page, button: ReturnType<Page["getByTestId"]>) {
  const answered = page.waitForResponse((r) => r.request().method() === "POST" && !!r.request().headers()["next-action"]);
  await button.click();
  await answered;
}
async function ensureExample(page: Page) {
  await page.goto("/heim");
  await expect(page.getByRole("heading", { name: "Dienstplanung" })).toBeVisible();
  if (await page.getByTestId("heim-empty").isVisible()) {
    await page.getByTestId("heim-load-example").click();
    await expect(page.getByTestId("heim-message")).toHaveText("Beispieldaten geladen (synthetisch).");
  }
}

test.describe.configure({ mode: "serial" });

let saved: { limits: string; classes: string; staff: string } | null = null;
test.beforeEach(async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 900 });
});
test.afterAll(() => {
  setRole("lead");
  if (!saved) return;
  const [rest, days, weekly] = saved.limits.split("|");
  psql(`update public.institutions set min_rest_hours = ${rest || "null"}, max_consecutive_days = ${days || "null"},
        weekly_target_hours = ${weekly || "null"} where id = '${INST}'`);
  for (const row of saved.classes.split("\n").filter(Boolean)) {
    const [id, cls] = row.split("|");
    psql(`update public.institution_shift_types set shift_class = ${cls ? `'${cls}'` : "null"} where id = '${id}'`);
  }
  for (const row of saved.staff.split("\n").filter(Boolean)) {
    const [id, pensum, model] = row.split("|");
    psql(`update public.institution_staff set pensum_pct = ${pensum || "null"}, shift_model = '${model}' where id = '${id}'`);
  }
});

test("HD-3a FE-128: the lead enters the home limits; a wrong value is refused, «nicht eingetragen» stops the draft (390 px)", async ({ page }) => {
  test.setTimeout(120_000);
  await signIn(page, HOME);
  await ensureExample(page);
  saved = {
    limits: limits(),
    classes: psql(`select concat_ws('|', id, coalesce(shift_class, '')) from public.institution_shift_types where institution_id = '${INST}' order by id`),
    staff: psql(`select concat_ws('|', id, coalesce(pensum_pct::text, ''), shift_model) from public.institution_staff where institution_id = '${INST}' order by id`),
  };

  await page.goto("/heim?ansicht=einstellungen");
  const f = page.getByTestId("heim-limits-form");
  await expect(f.getByTestId("heim-limits-mark")).toContainText("Arbeitszeitgesetz nicht abschliessend geprüft");
  await noSideScroll(page);

  // T-2: 11,5 h rest is refused with a visible text; nothing is written.
  const before = limits();
  await f.getByTestId("heim-limits-rest").fill("11,5");
  await f.getByTestId("heim-limits-days").fill("6");
  await f.getByTestId("heim-limits-weekly").fill("42");
  await f.getByTestId("heim-limits-save").click();
  await expect(page.getByTestId("heim-message")).toHaveText(/^Ruhezeit: bitte ganze Stunden eingeben/);
  expect(limits()).toBe(before);

  // T-2: out of range is refused by the database, with its own text.
  await f.getByTestId("heim-limits-rest").fill("12");
  await f.getByTestId("heim-limits-days").fill("5");
  await f.getByTestId("heim-limits-weekly-value").check();
  await f.getByTestId("heim-limits-weekly").fill("90");
  await f.getByTestId("heim-limits-save").click();
  await expect(page.getByTestId("heim-message")).toHaveText("Wochensoll 1 bis 80 Stunden. Nichts wurde gespeichert.");
  expect(limits()).toBe(before);

  // T-1: the saved values are shown as the database holds them (decimal comma accepted).
  await f.getByTestId("heim-limits-rest").fill("12");
  await f.getByTestId("heim-limits-days").fill("5");
  await f.getByTestId("heim-limits-weekly-value").check();
  await f.getByTestId("heim-limits-weekly").fill("42,5");
  await f.getByTestId("heim-limits-save").click();
  await expect(page.getByTestId("heim-message")).toHaveText("Planungsgrenzen des Heims gespeichert.");
  expect(limits()).toBe("12|5|42.5");
  await expect(page.getByTestId("heim-limits-now")).toHaveText("Jetzt: Ruhezeit 12 h · Arbeitstage in Folge 5 · Wochensoll 42,5 h");

  // R-6-2: somebody else changes the rest time after this page was shown; the form does not overwrite it.
  psql(`update public.institutions set min_rest_hours = 13 where id = '${INST}'`);
  await f.getByTestId("heim-limits-rest").fill("11");
  await f.getByTestId("heim-limits-save").click();
  await expect(page.getByTestId("heim-message")).toHaveText(/^Diese Werte wurden inzwischen geändert\. Nichts wurde gespeichert\./);
  expect(limits()).toBe("13|5|42.5");
  await expect(page.getByTestId("heim-limits-now")).toContainText("Ruhezeit 13 h");

  // «nicht eingetragen» is an explicit choice; with a typed number next to it, it is refused.
  await f.getByTestId("heim-limits-weekly-none").check();
  await f.getByTestId("heim-limits-save").click();
  await expect(page.getByTestId("heim-message")).toHaveText(/^Wochensoll: «nicht eingetragen» gewählt und eine Zahl eingegeben/);
  await f.getByTestId("heim-limits-weekly").fill("");
  await f.getByTestId("heim-limits-weekly-none").check();
  await f.getByTestId("heim-limits-save").click();
  await expect(page.getByTestId("heim-message")).toHaveText("Planungsgrenzen des Heims gespeichert.");
  expect(limits()).toBe("13|5");
  await expect(page.getByTestId("heim-limits-now")).toContainText("Wochensoll nicht eingetragen");

  // «Kein Vorschlag» points at exactly these fields.
  await page.goto("/heim?ansicht=vorschlag&bereich=woche");
  await expect(page.getByTestId("heim-draft-none")).toContainText("Wochensoll");
  await page.getByTestId("heim-draft-limits-link").click();
  await expect(page).toHaveURL(/ansicht=einstellungen.*#heim-limits$/);
  await expect(page.getByTestId("heim-limits-form")).toBeVisible();
  await noSideScroll(page);
});

test("HD-3a FE-128: the lead sets a shift class; the answer names the count from the database (390 px)", async ({ page }) => {
  test.setTimeout(90_000);
  await signIn(page, HOME);
  await page.goto("/heim?ansicht=einstellungen");
  const [id, code] = psql(`select concat_ws('|', id, code) from public.institution_shift_types where institution_id = '${INST}'
                            order by code limit 1`).split("|");
  const type = page.locator(`[data-testid="heim-shift-type"][data-code="${code}"]`);
  await type.getByTestId("heim-shift-class").selectOption("none");
  await type.getByTestId("heim-shift-class-save").click();
  await expect(page.getByTestId("heim-message")).toHaveText(/^Schichtklasse gespeichert\. (Keine eingeteilte Person ist betroffen\.|\d+ Einteilungen? pass)/);
  expect(psql(`select coalesce(shift_class, 'NULL') from public.institution_shift_types where id = '${id}'`)).toBe("NULL");
  await expect(type.getByTestId("heim-shift-class-now")).toHaveText("Klasse: keine Klasse");
  await noSideScroll(page);
});

test("HD-3a FE-128: Pensum «nicht eingetragen» takes a person out of the draft; the draft links to her field (390 px)", async ({ page }) => {
  test.setTimeout(120_000);
  await signIn(page, HOME);
  // The draft needs the home limits; set them again through the form.
  await page.goto("/heim?ansicht=einstellungen");
  const f = page.getByTestId("heim-limits-form");
  await f.getByTestId("heim-limits-rest").fill("11");
  await f.getByTestId("heim-limits-days").fill("6");
  await f.getByTestId("heim-limits-weekly-value").check();
  await f.getByTestId("heim-limits-weekly").fill("42");
  await f.getByTestId("heim-limits-save").click();
  await expect(page.getByTestId("heim-message")).toHaveText("Planungsgrenzen des Heims gespeichert.");

  await page.goto("/heim?ansicht=personal");
  const [staffId, name] = psql(`select concat_ws('|', id, display_name) from public.institution_staff
                                 where institution_id = '${INST}' and active order by display_name limit 1`).split("|");
  await page.getByTestId("heim-staff-link").filter({ hasText: name }).click();
  const form = page.getByTestId("heim-staff-planning-form");
  await expect(form).toBeVisible();
  await noSideScroll(page);

  // T-2: 80,5 % is refused; nothing is written.
  const was = psql(`select concat_ws('|', pensum_pct, shift_model) from public.institution_staff where id = '${staffId}'`);
  await form.getByTestId("heim-staff-pensum-value").check();
  await form.getByTestId("heim-staff-pensum").fill("80,5");
  await form.getByTestId("heim-staff-planning-save").click();
  await expect(page.getByTestId("heim-message")).toHaveText(/^Pensum: bitte ganze Prozent eingeben/);
  expect(psql(`select concat_ws('|', pensum_pct, shift_model) from public.institution_staff where id = '${staffId}'`)).toBe(was);

  // T-1: 60 % and «kein Nachtdienst» are shown as saved.
  await form.getByTestId("heim-staff-pensum-value").check();
  await form.getByTestId("heim-staff-pensum").fill("60");
  await form.getByTestId("heim-staff-model").selectOption("no_night");
  await form.getByTestId("heim-staff-planning-save").click();
  await expect(page.getByTestId("heim-message")).toHaveText("Pensum und Schichtmodell gespeichert.");
  expect(psql(`select concat_ws('|', pensum_pct, shift_model) from public.institution_staff where id = '${staffId}'`)).toBe("60|no_night");
  await expect(page.getByTestId("heim-staff-planning-now")).toHaveText("Pensum 60 % · Schichtmodell kein Nachtdienst");

  // «nicht eingetragen»: the person is listed «ohne Pensum» and the draft names her with a link to her field.
  // The previous save left the same banner on screen; the held POST keeps this save in flight for 1.5 s, and the test
  // waits for this save's own answer before it reads the banner and the database.
  await form.getByTestId("heim-staff-pensum").fill("");
  await form.getByTestId("heim-staff-pensum-none").check();
  const release = await holdServerActions(page, 1500);
  await saveAndWait(page, form.getByTestId("heim-staff-planning-save"));
  await expect(page.getByTestId("heim-message")).toHaveText("Pensum und Schichtmodell gespeichert.");
  expect(psql(`select coalesce(pensum_pct::text, 'NULL') from public.institution_staff where id = '${staffId}'`)).toBe("NULL");
  await release();
  await expect(page.getByTestId("heim-staff-list").locator("li", { hasText: name }).getByTestId("heim-staff-no-pensum")).toBeVisible();

  await page.goto("/heim?ansicht=vorschlag&bereich=woche");
  const missing = page.getByTestId("heim-draft-no-pensum");
  await expect(missing).toBeVisible();
  await expect(page.getByTestId("heim-draft-row").filter({ hasText: name })).toHaveCount(0);
  await missing.getByTestId("heim-draft-no-pensum-link").filter({ hasText: name }).click();
  await expect(page).toHaveURL(/ansicht=personal.*#heim-staff-planning$/);
  await expect(page.getByTestId("heim-staff-planning-now")).toHaveText(/^Pensum nicht eingetragen/);
});

test("HD-3a FE-128 negatives: a planner gets no limit or class form, a viewer and a team nurse get no form (390 px)", async ({ page }) => {
  test.setTimeout(120_000);
  try {
    setRole("planner");
    await signIn(page, HOME);
    await page.goto("/heim?ansicht=einstellungen");
    await expect(page.getByRole("navigation", { name: "Ansicht" }).getByRole("link", { name: "Einstellungen" })).toHaveCount(0);
    await expect(page.getByTestId("heim-limits-form")).toHaveCount(0);
    await expect(page.getByTestId("heim-shift-class-form")).toHaveCount(0);
    await page.goto("/heim?ansicht=personal");
    await page.getByTestId("heim-staff-link").first().click();
    await expect(page.getByTestId("heim-staff-planning-form")).toBeVisible();
    await noSideScroll(page);

    setRole("viewer");
    await signIn(page, HOME);
    await page.goto("/heim?ansicht=einstellungen");
    await expect(page.getByTestId("heim-limits-form")).toHaveCount(0);
    await expect(page.getByTestId("heim-shift-class-form")).toHaveCount(0);
    await page.goto("/heim?ansicht=personal");
    await page.getByTestId("heim-staff-link").first().click();
    await expect(page.getByTestId("heim-staff-planning-now")).toBeVisible();
    await expect(page.getByTestId("heim-staff-planning-form")).toHaveCount(0);
  } finally {
    setRole("lead");
  }

  await signIn(page, NURSE);
  await page.goto("/heim");
  await expect(page.getByTestId("heim-no-institution")).toBeVisible();
  await expect(page.getByTestId("heim-limits-form")).toHaveCount(0);
  await expect(page.getByTestId("heim-staff-planning-form")).toHaveCount(0);
});
