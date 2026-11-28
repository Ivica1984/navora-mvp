import { execFileSync } from "node:child_process";
import { expect, test, type Page } from "@playwright/test";
import { zurichDay } from "./support/durchgang-time";
import { addDays, weekStart } from "@/features/home-plan/rules";

// HD-3a-F1 (brief docs/agents/briefs/HD-3a-F1.md, migrations 0186-0188): «übernehmen» checks Pensum and Wochensoll in
// the database, fail closed, and names what is missing.
// - positive (1440 px): proposal → «übernehmen» → the week shows the shown persons in their shifts (institution_plan);
//   the 390 px positive path is hd3a-draft-screen.spec.ts;
// - T-2 Pensum (390 and 1440 px): after the draft is shown, somebody empties the Pensum of one shown person; «übernehmen»
//   saves the other rows, refuses hers, and the screen names her with a link to her Pensum field; none of her rows is
//   saved (T-1: what the screen says = what the database holds);
// - T-2 Wochensoll (390 px): the home's Wochensoll is emptied after the draft is shown; nothing is saved and the screen
//   says what to enter.
// Weeks 15, 19, 22 and 26 ahead of the synthetic example home, each used by no other spec (draft-screen uses week 13,
// HD-3s T-1 week 17, the HD-3s-F2 specs weeks 20, 21, 23, 24). The change «by somebody else» is a direct write to the
// local test database (port 54322 only), restored in afterAll; the assignments this spec saved are deleted there too,
// so no later spec plans a week that is already filled (ci 46089198925, e2e 140805869586: week 17 was shared).
// Fixed rules, no AI.
const PASSWORD = "navora-local-only";
const HOME = "kundebs.test@navora.test";
const INST = "00000000-0000-4000-a000-0000000004c1";
const DB_URL = process.env.E2E_DB_URL ?? "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
const LOCAL_DB = /^postgres(ql)?:\/\/[^@]+@(127\.0\.0\.1|localhost):54322\//;

function psql(sql: string): string {
  if (!LOCAL_DB.test(DB_URL)) throw new Error("HD-3a-F1 fixture: only the local Supabase database (port 54322)");
  return execFileSync("psql", [DB_URL, "-X", "-q", "-At", "-v", "ON_ERROR_STOP=1", "-c", sql], { encoding: "utf8" }).trim();
}
const q = (s: string) => `'${s.replaceAll("'", "''")}'`;

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

type Shown = { date: string; station: string; shift: string; person: string };
/** Opens the week draft for `monday` and reads every shown row (day, station, shift code, person). */
async function openDraft(page: Page, monday: string): Promise<Shown[]> {
  await page.goto("/heim");
  await expect(page.getByRole("heading", { name: "Dienstplanung" })).toBeVisible();
  if (await page.getByTestId("heim-empty").isVisible()) {
    await page.getByTestId("heim-load-example").click();
    await expect(page.getByTestId("heim-message")).toHaveText("Beispieldaten geladen (synthetisch).");
  }
  await page.goto(`/heim?ansicht=woche&datum=${monday}`);
  await page.getByTestId("heim-draft-start").click();
  await expect(page).toHaveURL(/ansicht=vorschlag/);
  const draft = page.getByTestId("heim-draft");
  await expect(draft.getByTestId("heim-draft-summary")).toBeVisible();
  const shown: Shown[] = [];
  for (const day of await draft.getByTestId("heim-draft-day").all()) {
    const date = (await day.getAttribute("data-date")) as string;
    for (const r of await day.getByTestId("heim-draft-row").all()) {
      const text = (await r.textContent()) ?? "";
      const person = text.split(" · ").at(-1)!.replace(/\s*\([^)]*\)\s*$/, "").trim();
      shown.push({ date, station: (await r.getAttribute("data-station")) as string, shift: (await r.getAttribute("data-shift")) as string, person });
    }
  }
  expect(shown.length).toBeGreaterThan(0);
  return shown;
}
/** Assignments of the home in the week starting `monday` (the database, not the screen). */
function savedInWeek(monday: string, person?: string): number {
  return Number(psql(`select count(*) from public.institution_assignments a join public.institution_staff s on s.id = a.staff_id
    where s.institution_id = '${INST}' and a.work_date between '${monday}' and '${addDays(monday, 6)}'
    ${person ? `and s.display_name = ${q(person)}` : ""}`));
}

test.describe.configure({ mode: "serial" });

const WEEKS = { positive1440: 105, pensum390: 182, pensum1440: 133, target390: 154 } as const;
const usedMondays = new Set<string>();
let origWeekly: string | null = null;
const origPensum = new Map<string, string>();

test.afterAll(() => {
  // The rows this spec saved (positive and T-2 Pensum) leave the test database with the spec.
  // The Mondays recorded by the tests themselves (a run across midnight must not recompute other weeks).
  for (const monday of usedMondays) {
    psql(`delete from public.institution_assignments a using public.institution_staff s
          where s.id = a.staff_id and s.institution_id = '${INST}' and a.work_date between '${monday}' and '${addDays(monday, 6)}'`);
  }
  for (const [id, pensum] of origPensum) {
    psql(`set session_replication_role = replica; update public.institution_staff set pensum_pct = ${pensum || "null"} where id = '${id}'`);
  }
  if (origWeekly !== null) {
    psql(`set session_replication_role = replica; update public.institutions set weekly_target_hours = ${origWeekly || "null"} where id = '${INST}'`);
  }
});

test("HD-3a-F1 positive: proposal → «übernehmen» → the week shows the plan from institution_plan (1440 px)", async ({ page }) => {
  test.setTimeout(150_000);
  await page.setViewportSize({ width: 1440, height: 900 });
  const monday = weekStart(addDays(zurichDay(), WEEKS.positive1440));
  usedMondays.add(monday);
  await signIn(page, HOME);
  const shown = await openDraft(page, monday);
  const n = shown.length;
  await page.getByTestId("heim-draft-apply").click();
  await expect(page).toHaveURL(/ansicht=woche/);
  await expect(page.getByTestId("heim-message")).toHaveText(`Vorschlag übernommen: ${n} ${n === 1 ? "Dienst" : "Dienste"} eingeteilt.`);
  await expect(page.getByTestId("heim-apply-no-pensum")).toHaveCount(0);
  for (const s of shown) {
    const c = page.locator(`[data-testid="heim-day"][data-date="${s.date}"] [data-testid="heim-cell"][data-station="${s.station}"][data-shift="${s.shift}"]`);
    await expect(c.getByTestId("heim-assigned").filter({ hasText: s.person })).toHaveCount(1);
  }
  expect(savedInWeek(monday)).toBe(n);
  await noSideScroll(page);
});

for (const [width, key] of [[390, "pensum390"], [1440, "pensum1440"]] as const) {
  test(`HD-3a-F1 T-2: a Pensum emptied after the draft was shown is refused with her name and the next step (${width} px)`, async ({ page }) => {
    test.setTimeout(150_000);
    await page.setViewportSize({ width, height: 900 });
    const monday = weekStart(addDays(zurichDay(), WEEKS[key]));
    usedMondays.add(monday);
    await signIn(page, HOME);
    const shown = await openDraft(page, monday);
    const victim = shown[0].person;
    const hers = shown.filter((s) => s.person === victim).length;
    const others = shown.length - hers;
    expect(savedInWeek(monday, victim)).toBe(0);

    // Somebody else empties her Pensum after this draft was shown (the screen still offers her rows).
    const [id, pensum] = psql(`select concat_ws('|', id, pensum_pct) from public.institution_staff
                               where institution_id = '${INST}' and display_name = ${q(victim)}`).split("|");
    if (!origPensum.has(id)) origPensum.set(id, pensum);
    psql(`set session_replication_role = replica; update public.institution_staff set pensum_pct = null where id = '${id}'`);

    await page.getByTestId("heim-draft-apply").click();
    await expect(page).toHaveURL(/ansicht=woche/);
    await expect(page.getByTestId("heim-message")).toContainText(
      `Vorschlag teilweise übernommen: ${others} ${others === 1 ? "Dienst" : "Dienste"} eingeteilt`);
    const line = page.getByTestId("heim-apply-no-pensum-line").filter({ hasText: victim });
    await expect(line).toHaveText(new RegExp(
      `^${victim}: ${hers} ${hers === 1 ? "Dienst" : "Dienste"} nicht übernommen, weil kein Pensum eingetragen ist\\. `
      + "Bitte bei der Person das Pensum eintragen und neu vorschlagen\\."));
    // T-1: the screen says what the database holds: none of her rows, all of the others.
    expect(savedInWeek(monday, victim)).toBe(0);
    expect(savedInWeek(monday)).toBe(others);
    await noSideScroll(page);

    // The next step: the link opens her Pensum field.
    await line.getByRole("link", { name: `Pensum von ${victim} eintragen` }).click();
    await expect(page).toHaveURL(/ansicht=personal.*#heim-staff-planning$/);
    await expect(page.getByTestId("heim-staff-planning-now")).toHaveText(/^Pensum nicht eingetragen/);
  });
}

test("HD-3a-F1 T-2: a Wochensoll emptied after the draft was shown refuses the whole take-over (390 px)", async ({ page }) => {
  test.setTimeout(150_000);
  await page.setViewportSize({ width: 390, height: 900 });
  const monday = weekStart(addDays(zurichDay(), WEEKS.target390));
  usedMondays.add(monday);
  await signIn(page, HOME);
  await openDraft(page, monday);
  if (origWeekly === null) origWeekly = psql(`select coalesce(weekly_target_hours::text, '') from public.institutions where id = '${INST}'`);
  psql(`set session_replication_role = replica; update public.institutions set weekly_target_hours = null where id = '${INST}'`);

  await page.getByTestId("heim-draft-apply").click();
  await expect(page.getByTestId("heim-message")).toHaveText(
    "Nicht übernommen: Für dieses Heim ist kein Wochensoll eingetragen; ohne Wochensoll lässt sich die Stundengrenze nicht prüfen. "
    + "Bitte unter «Planungsgrenzen» das Wochensoll eintragen und neu vorschlagen. Es wurde nichts übernommen.");
  expect(savedInWeek(monday)).toBe(0);
  await noSideScroll(page);
  psql(`set session_replication_role = replica; update public.institutions set weekly_target_hours = ${origWeekly || "null"} where id = '${INST}'`);
});
