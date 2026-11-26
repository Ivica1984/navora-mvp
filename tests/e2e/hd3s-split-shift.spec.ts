import { execFileSync } from "node:child_process";
import { expect, test, type Page } from "@playwright/test";
import { zurichDay } from "./support/durchgang-time";
import { addDays, weekStart } from "@/features/home-plan/rules";

// HD-3s «geteilter Dienst» (brief docs/agents/briefs/HD-3s.md): the home lead enters a shift type with two blocks on
// /heim, sees the daily target hint (S5, never a block), and a wrong block shape is refused with the database's reason
// in words; then «Plan vorschlagen» plans the split shift and «übernehmen» saves exactly the shown rows (T-1); the
// week shows one working day with two times. At 390 × 900 and 1440 × 900 px. A week seventeen weeks ahead of the
// synthetic example home (the HD-3a specs use weeks 5 to 13). The split type, its rule and its assignments are removed
// in `finally` (local database only). Fixed rules, no AI.
const PASSWORD = "navora-local-only";
const HOME = "kundebs.test@navora.test";
const INST = "00000000-0000-4000-a000-0000000004c1";
const CODE = "GE2E";
const DB_URL = process.env.E2E_DB_URL ?? "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
const LOCAL_DB = /^postgres(ql)?:\/\/[^@]+@(127\.0\.0\.1|localhost):54322\//;

function psql(sql: string): string {
  if (!LOCAL_DB.test(DB_URL)) throw new Error("HD-3s fixture: only the local Supabase database (port 54322)");
  return execFileSync("psql", [DB_URL, "-X", "-q", "-At", "-v", "ON_ERROR_STOP=1", "-c", sql], { encoding: "utf8" }).trim();
}
const typeRow = (code: string) =>
  psql(`select concat_ws('|', to_char(starts_at, 'HH24:MI'), to_char(block1_ends_at, 'HH24:MI'), to_char(block2_starts_at, 'HH24:MI'),
          to_char(ends_at, 'HH24:MI'), shift_class) from public.institution_shift_types where institution_id = '${INST}' and code = '${code}'`);
function cleanup() {
  psql(`delete from public.institution_assignments where shift_type_id in
          (select id from public.institution_shift_types where institution_id = '${INST}' and code in ('${CODE}', 'GBAD'));
        delete from public.institution_shift_types where institution_id = '${INST}' and code in ('${CODE}', 'GBAD');
        update public.institutions set work_days_per_week = 5 where id = '${INST}';`);
}

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
async function ensureExample(page: Page) {
  await page.goto("/heim");
  await expect(page.getByRole("heading", { name: "Dienstplanung" })).toBeVisible();
  if (await page.getByTestId("heim-empty").isVisible()) {
    await page.getByTestId("heim-load-example").click();
    await expect(page.getByTestId("heim-message")).toHaveText("Beispieldaten geladen (synthetisch).");
  }
}
async function fillSplit(page: Page, code: string, b1s: string, b1e: string, b2s: string, b2e: string) {
  const f = page.getByTestId("heim-split-form");
  await f.getByTestId("heim-split-code").fill(code);
  await f.getByTestId("heim-split-label").fill(`Geteilt ${code}`);
  await f.getByTestId("heim-split-b1-starts").fill(b1s);
  await f.getByTestId("heim-split-b1-ends").fill(b1e);
  await f.getByTestId("heim-split-b2-starts").fill(b2s);
  await f.getByTestId("heim-split-b2-ends").fill(b2e);
  await f.getByTestId("heim-split-save").click();
}

test.describe.configure({ mode: "serial" });
test.afterAll(() => cleanup());

for (const width of [390, 1440]) {
  test(`HD-3s: the lead enters a split shift, sees the daily target hint; a wrong shape is refused (${width} px)`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 });
    cleanup();
    await signIn(page, HOME);
    await ensureExample(page);
    await page.goto("/heim?ansicht=einstellungen");
    await expect(page.getByTestId("heim-split-form")).toBeVisible();
    await noSideScroll(page);

    // Wrong shape: block 2 starts inside block 1 => the database's reason in words, nothing stored.
    await fillSplit(page, "GBAD", "07:00", "11:30", "10:00", "20:00");
    await expect(page.getByTestId("heim-message")).toHaveText(
      "Geteilter Dienst: Block 2 muss nach dem Ende von Block 1 beginnen. Nichts wurde gespeichert.",
    );
    expect(typeRow("GBAD")).toBe("");

    await fillSplit(page, CODE, "07:00", "11:30", "16:00", "20:00");
    await expect(page.getByTestId("heim-message")).toHaveText("Geteilter Dienst gespeichert: ein Arbeitstag mit zwei Blöcken.");
    expect(typeRow(CODE)).toBe("07:00|11:30|16:00|20:00|split");
    const item = page.locator(`[data-testid="heim-shift-type"][data-code="${CODE}"]`);
    await expect(item.getByTestId("heim-shift-times")).toHaveText("07:00–11:30 und 16:00–20:00");
    await expect(item.getByTestId("heim-shift-class-now")).toHaveText("Klasse: Geteilt");
    await expect(item.getByTestId("heim-shift-class-form")).toHaveCount(0);
    // S5: weekly target of the example home ÷ 5 working days; the hint never blocks.
    const weekly = Number(psql(`select coalesce(weekly_target_hours, 0) from public.institutions where id = '${INST}'`));
    if (weekly > 0) await expect(item.getByTestId("heim-split-hint")).toContainText("Hinweis, keine Sperre.");
    else await expect(item.getByTestId("heim-split-hint")).toHaveText("Kein Wochensoll eingetragen: kein Hinweis zum Soll pro Tag.");

    // «Arbeitstage pro Woche»: 4 days change the daily target (read back from the database).
    await page.getByTestId("heim-workdays").fill("4");
    await page.getByTestId("heim-workdays-save").click();
    await expect(page.getByTestId("heim-message")).toHaveText("Arbeitstage pro Woche gespeichert.");
    expect(psql(`select work_days_per_week from public.institutions where id = '${INST}'`)).toBe("4");
    await expect(page.getByTestId("heim-workdays-now")).toContainText("Jetzt: 4 Arbeitstage.");
    await page.getByTestId("heim-workdays").fill("8");
    await page.getByTestId("heim-workdays-save").click();
    await expect(page.getByTestId("heim-message")).toHaveText("Arbeitstage pro Woche: 1 bis 7. Nichts wurde gespeichert.");
    expect(psql(`select work_days_per_week from public.institutions where id = '${INST}'`)).toBe("4");
    await noSideScroll(page);
  });
}

test("HD-3s T-1: «Plan vorschlagen» plans the split shift, «übernehmen» saves the shown rows; the week shows two times (390 px)", async ({ page }) => {
  test.setTimeout(150_000);
  await page.setViewportSize({ width: 390, height: 900 });
  const monday = weekStart(addDays(zurichDay(), 119));
  cleanup();
  await signIn(page, HOME);
  await ensureExample(page);
  await page.goto("/heim?ansicht=einstellungen");
  await fillSplit(page, CODE, "07:00", "11:30", "16:00", "20:00");
  await expect(page.getByTestId("heim-message")).toHaveText("Geteilter Dienst gespeichert: ein Arbeitstag mit zwei Blöcken.");
  // Minimum staffing of the split shift: 1 person on the first station (the home's value, synthetic).
  psql(`insert into public.institution_staffing_rules (institution_id, station_id, shift_type_id, required_total, example)
        select '${INST}', (select id from public.institution_stations where institution_id = '${INST}' order by sort, name limit 1),
               id, 1, true from public.institution_shift_types where institution_id = '${INST}' and code = '${CODE}'`);

  await page.goto(`/heim?ansicht=woche&datum=${monday}`);
  await page.getByTestId("heim-draft-start").click();
  await expect(page).toHaveURL(/ansicht=vorschlag/);
  const draft = page.getByTestId("heim-draft");
  // Wait for the rendered draft itself (its summary line) before counting rows: the URL changes first.
  await expect(draft.getByTestId("heim-draft-summary")).toHaveText(/^\d+ Dienste? vorgeschlagen · /);
  const splitRows = draft.locator(`[data-testid="heim-draft-row"][data-shift="${CODE}"]`);
  const splitGaps = await draft.locator(`[data-testid="heim-draft-gap"][data-shift="${CODE}"]`).allTextContents();
  expect(await splitRows.count(), `no split row proposed; split gaps: ${splitGaps.join(" | ") || "none"}`).toBeGreaterThan(0);
  await expect(splitRows.first()).toContainText("07:00–11:30 und 16:00–20:00");
  const shown: Array<{ date: string; station: string; person: string }> = [];
  for (const day of await draft.getByTestId("heim-draft-day").all()) {
    const date = (await day.getAttribute("data-date")) as string;
    for (const r of await day.locator(`[data-testid="heim-draft-row"][data-shift="${CODE}"]`).all()) {
      const text = (await r.textContent()) ?? "";
      shown.push({ date, station: (await r.getAttribute("data-station")) as string, person: text.split(" · ").at(-1)!.replace(/\s*\([^)]*\)\s*$/, "").trim() });
    }
  }
  const n = await draft.getByTestId("heim-draft-row").count();
  await draft.getByTestId("heim-draft-apply").click();
  await expect(page).toHaveURL(/ansicht=woche/);
  await expect(page.getByTestId("heim-message")).toHaveText(`Vorschlag übernommen: ${n} ${n === 1 ? "Dienst" : "Dienste"} eingeteilt.`);
  for (const s of shown) {
    const c = page.locator(`[data-testid="heim-day"][data-date="${s.date}"] [data-testid="heim-cell"][data-station="${s.station}"][data-shift="${CODE}"]`);
    await expect(c.getByTestId("heim-cell-times")).toContainText("07:00–11:30 und 16:00–20:00");
    await expect(c.getByTestId("heim-assigned").filter({ hasText: s.person })).toHaveCount(1);
  }
  // Every saved split row went through the database's rules: no person has the split shift twice on one day.
  expect(psql(`select count(*) from (select staff_id, work_date from public.institution_assignments a
                join public.institution_shift_types t on t.id = a.shift_type_id
                where t.institution_id = '${INST}' and t.code = '${CODE}' group by 1, 2 having count(*) > 1) x`)).toBe("0");
  await noSideScroll(page);
});
