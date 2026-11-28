import { execFileSync } from "node:child_process";
import { expect, test, type Page } from "@playwright/test";
import { zurichDay } from "./support/durchgang-time";
import { addDays, monthEnd, monthStart } from "@/features/home-plan/rules";
import { minutesAsHours } from "@/features/home-plan/planning-inputs";

// HD-3a-F3 (brief docs/agents/briefs/HD-3a-F3.md, founder FE-135 option A, migration 0189): the monthly target.
// - T-2 (390 and 1440 px): a negative value is refused with a visible text and nothing is stored;
// - positive (390 and 1440 px): the lead enters a monthly target for one example person → «Plan vorschlagen» for that
//   month → «übernehmen» → the person's panel shows Soll, geplant and Rest from institution_plan, and they match the
//   database (T-1: planned working minutes of the month; the planner kept the target as its condition).
// Months 280 and 315 days ahead of the synthetic example home (whole calendar months; every other /heim spec uses a
// week at most 26 weeks ahead or the month 120 days ahead). The assignments and targets this spec saved are deleted
// from the local test database (port 54322 only) in afterAll. Fixed rules, no AI.
const PASSWORD = "navora-local-only";
const HOME = "kundebs.test@navora.test";
const INST = "00000000-0000-4000-a000-0000000004c1";
const DB_URL = process.env.E2E_DB_URL ?? "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
const LOCAL_DB = /^postgres(ql)?:\/\/[^@]+@(127\.0\.0\.1|localhost):54322\//;

function psql(sql: string): string {
  if (!LOCAL_DB.test(DB_URL)) throw new Error("HD-3a-F3 fixture: only the local Supabase database (port 54322)");
  return execFileSync("psql", [DB_URL, "-X", "-q", "-At", "-v", "ON_ERROR_STOP=1", "-c", sql], { encoding: "utf8" }).trim();
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
/** Working minutes of the person's stored assignments in the month (the database's own count, as R-m reads it). */
function plannedMinutes(staffId: string, month: string): number {
  return Number(psql(`select coalesce(sum(private.institution_shift_minutes(a.work_date, t.starts_at, t.ends_at,
      t.block1_ends_at, t.block2_starts_at)), 0)::int from public.institution_assignments a
      join public.institution_shift_types t on t.id = a.shift_type_id
      where a.staff_id = '${staffId}' and a.work_date between '${month}' and '${monthEnd(month)}'`));
}

test.describe.configure({ mode: "serial" });

const MONTHS = { 390: 280, 1440: 315 } as const;
const usedMonths = new Set<string>();

test.afterAll(() => {
  for (const month of usedMonths) {
    psql(`delete from public.institution_assignments a using public.institution_staff s
          where s.id = a.staff_id and s.institution_id = '${INST}' and a.work_date between '${month}' and '${monthEnd(month)}'`);
    psql(`delete from public.institution_monthly_targets where institution_id = '${INST}' and period_month = '${month}'`);
  }
});

for (const width of [390, 1440] as const) {
  test(`HD-3a-F3: monthly target refused when negative, entered, kept by the month proposal (${width} px)`, async ({ page }) => {
    test.setTimeout(180_000);
    await page.setViewportSize({ width, height: 900 });
    const month = monthStart(addDays(zurichDay(), MONTHS[width]));
    usedMonths.add(month);
    await signIn(page, HOME);
    await ensureExample(page);
    // One active example person with a Pensum (planned by the draft today).
    const [id, name] = psql(`select concat_ws('|', id, display_name) from public.institution_staff
                             where institution_id = '${INST}' and active and pensum_pct is not null
                             order by display_name, id limit 1`).split("|");
    expect(plannedMinutes(id, month)).toBe(0);

    await page.goto(`/heim?ansicht=personal&datum=${month}&person=${id}`);
    const box = page.getByTestId("heim-person-month-target-box");
    await expect(box).toBeVisible();
    await expect(box.getByTestId("heim-month-target-none")).toContainText("kein Monatssoll: Wochenbudget gilt");

    // T-2: a negative value is refused with a visible text; nothing is stored.
    await box.getByTestId("heim-month-target-value").check();
    await box.getByTestId("heim-month-target-input").fill("-5");
    await box.getByTestId("heim-month-target-save").click();
    await expect(page.getByTestId("heim-message")).toContainText("Monatssoll: bitte Stunden eingeben");
    expect(psql(`select count(*) from public.institution_monthly_targets where staff_id = '${id}' and period_month = '${month}'`)).toBe("0");

    // Positive: 40 h for this month.
    await box.getByTestId("heim-month-target-value").check();
    await box.getByTestId("heim-month-target-input").fill("40");
    await box.getByTestId("heim-month-target-save").click();
    await expect(page.getByTestId("heim-message")).toHaveText("Monatssoll gespeichert. Für diesen Monat gilt es statt des Wochenbudgets.");
    expect(psql(`select target_minutes from public.institution_monthly_targets where staff_id = '${id}' and period_month = '${month}'`)).toBe("2400");
    await expect(page.getByTestId("heim-person-month-target-box").getByTestId("heim-month-target-numbers"))
      .toHaveText("Soll 40 h · geplant 0 h · Rest 40 h");
    // Founder requirement 2: 40 h deviates from Pensum × Wochensoll (no threshold set): a visible warning, value kept.
    await expect(page.getByTestId("heim-person-month-target-box").getByTestId("heim-month-target-deviates"))
      .toContainText("Das eingetragene Monatssoll gilt; nichts wurde geändert.");
    await noSideScroll(page);

    // The month proposal keeps the target; «übernehmen» saves; the panel reads the result back.
    await page.goto(`/heim?ansicht=monat&datum=${month}`);
    await page.getByTestId("heim-draft-start").click();
    await expect(page).toHaveURL(/ansicht=vorschlag/);
    await expect(page.getByTestId("heim-draft-summary")).toBeVisible();
    await page.getByTestId("heim-draft-apply").click();
    await expect(page.getByTestId("heim-message")).toHaveText(/^Vorschlag (teilweise )?übernommen/);
    const planned = plannedMinutes(id, month);
    expect(planned).toBeGreaterThan(0);
    expect(planned).toBeLessThanOrEqual(2400);
    await page.goto(`/heim?ansicht=personal&datum=${month}&person=${id}`);
    await expect(page.getByTestId("heim-person-month-target-box").getByTestId("heim-month-target-numbers"))
      .toHaveText(`Soll 40 h · geplant ${minutesAsHours(planned)} · Rest ${minutesAsHours(2400 - planned)}`);
    // The month view lists the same numbers for her.
    await page.goto(`/heim?ansicht=monat&datum=${month}`);
    const row = page.getByTestId("heim-month-target-row").filter({ hasText: name });
    await expect(row.getByTestId("heim-month-target-remaining")).toHaveText(`Rest ${minutesAsHours(2400 - planned)}`);
    await noSideScroll(page);
  });
}
