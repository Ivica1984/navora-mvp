import { execFileSync } from "node:child_process";
import { expect, test, type Page } from "@playwright/test";
import { zurichDay } from "./support/durchgang-time";
import { addDays, weekStart } from "@/features/home-plan/rules";

// HD-3s-F2 e2e (brief docs/agents/briefs/HD-3s-F2.md criterion «e2e 390 und 1440 px»; ADR-229; migrations 0183, 0184):
// the home lead orders the gap of a split shift (07:00–11:30 und 16:00–20:00) as ONE external order → the team's offer
// card names both blocks → pflegebs takes it for herself → her /field day shows two cards, each naming its block and
// both blocks → the home's week reads «Gedeckt» for that cell. Negative: a nurse sees no order button on /heim (the
// database refuses every other role, pgTAP 183 §1). Fixed, checkable rules, no AI. Synthetic local accounts only.
// Fixture (local database only): a split shift type «GF2» with minimum staffing 1 HF on the first station; its rule is
// removed in afterAll so later specs plan without it (the type and the sent orders stay in this CI database only).
// Weeks 20 and 21 ahead, Thursday: no other spec uses them (hd2 6–11, hd3a 5–13, hd3s 17, bk 4–5).
const PASSWORD = "navora-local-only";
const HOME = "kundebs.test@navora.test";
const NURSE = "pflegebs.test@navora.test";
const INST = "00000000-0000-4000-a000-0000000004c1";
const CODE = "GF2";
const DB_URL = process.env.E2E_DB_URL ?? "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
const LOCAL_DB = /^postgres(ql)?:\/\/[^@]+@(127\.0\.0\.1|localhost):54322\//;
const BOTH = "07:00 – 11:30 und 16:00 – 20:00";
const deDate = (iso: string) => iso.split("-").reverse().join(".");

function psql(sql: string): string {
  if (!LOCAL_DB.test(DB_URL)) throw new Error("HD-3s-F2 fixture: only the local Supabase database (port 54322)");
  return execFileSync("psql", [DB_URL, "-X", "-q", "-At", "-v", "ON_ERROR_STOP=1", "-c", sql], { encoding: "utf8" }).trim();
}
function fixture(): string {
  psql(`insert into public.institution_shift_types (institution_id, code, label, starts_at, block1_ends_at, block2_starts_at,
          ends_at, shift_class, sort)
        values ('${INST}', '${CODE}', 'Geteilt F2', '07:00', '11:30', '16:00', '20:00', 'split', 90)
        on conflict do nothing;
        insert into public.institution_staffing_rules (institution_id, station_id, shift_type_id, required_total,
          required_grade, required_grade_count, example)
        select '${INST}', (select id from public.institution_stations where institution_id = '${INST}' order by sort, name limit 1),
               t.id, 1, 'nurse_hf_fh', 1, true
        from public.institution_shift_types t where t.institution_id = '${INST}' and t.code = '${CODE}'
        on conflict do nothing;`);
  // The rule's station: the week shows a split cell on every station, only this one has the minimum staffing.
  return psql(`select name from public.institution_stations where institution_id = '${INST}' order by sort, name limit 1`);
}
function cleanup() {
  psql(`delete from public.institution_staffing_rules where shift_type_id in
          (select id from public.institution_shift_types where institution_id = '${INST}' and code = '${CODE}')`);
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
const splitCell = (page: Page, date: string, station: string) =>
  page.locator(`[data-testid="heim-day"][data-date="${date}"] [data-testid="heim-cell"][data-station="${station}"][data-shift="${CODE}"]`);

test.describe.configure({ mode: "serial" });
test.afterAll(() => cleanup());

for (const [width, days] of [[1440, 140], [390, 147]] as const) {
  test(`HD-3s-F2 at ${width} px: split gap → one order with both blocks → team sees both → nurse takes → /field two cards`, async ({ page }) => {
    test.setTimeout(240_000);
    const thu = addDays(weekStart(addDays(zurichDay(), days)), 3);
    const week = `/heim?ansicht=woche&datum=${thu}`;

    // 1. The home lead prepares the split gap: the review names both blocks; she checks and sends it.
    await page.setViewportSize({ width, height: 900 });
    await signIn(page, HOME);
    await ensureExample(page);
    const station = fixture();  // after the example: the rule needs the home's first station
    await page.goto(week);
    const cell = splitCell(page, thu, station);
    await expect(cell).toHaveAttribute("data-status", "gap");
    await expect(cell.getByTestId("heim-split-no-order")).toHaveCount(0);
    await cell.getByTestId("heim-prepare-order").click();
    await expect(page.getByTestId("heim-message")).toHaveText("Auftrag vorbereitet, noch nicht gesendet. Bitte prüfen und senden.");
    const review = page.getByTestId("heim-order-review");
    await expect(review.getByTestId("heim-order-review-shift")).toContainText("07:00–11:30 und 16:00–20:00");
    await review.getByTestId("heim-order-postcode").selectOption("4051");
    const tags = review.getByTestId("heim-order-tag");
    for (let i = 0; i < await tags.count(); i++) await tags.nth(i).uncheck();
    await review.locator('[data-testid="heim-order-tag"][value="C1"]').check();
    await review.getByTestId("heim-order-check").click();
    // UXR-269: «Senden» only on the checked screen (redirect with geprueft=1); with the tags prefilled by an earlier
    // order a summary is already shown before «Prüfen» (e2e 140278327659: «Geändert nach dem Prüfen»).
    await page.waitForURL(/[?&]geprueft=1/);
    await expect(review.getByTestId("heim-order-prefill-hint")).toHaveCount(0);
    await expect(review.getByTestId("heim-order-send-summary")).toHaveText(/Tätigkeiten: C1 · [^,]*$/);
    await expect(review.getByTestId("heim-order-send-summary")).toContainText("07:00–11:30 und 16:00–20:00");
    await expect(review.getByTestId("heim-order-sentence")).toContainText(`${BOTH} (8 Std. 30 Min.)`);
    await noSideScroll(page);
    await review.getByTestId("heim-order-send").click();
    await expect(page.getByTestId("heim-message")).toHaveText("Auftrag gesendet: Angebot an alle passenden Teams gleichzeitig.");
    await page.goto(week);
    await expect(cell.getByTestId("heim-cell-order")).toHaveAttribute("data-code", "A");

    // 2. Negative: a nurse sees no order button on the home's plan (every other role is refused in the database).
    await signIn(page, NURSE);
    await page.goto(week);
    await expect(page.getByTestId("heim-prepare-order")).toHaveCount(0);

    // 3. The team's offer card names both blocks; she takes the whole order for herself.
    await page.goto("/team");
    const when = `${deDate(thu)} 07:00`;
    const offer = page.getByTestId("shift-offer-card").filter({ hasText: when }).last();
    await expect(offer.getByTestId("shift-offer-tag")).toHaveText("Neues Angebot");
    await expect(offer.getByTestId("shift-offer-sentence")).toContainText(`${BOTH} (8 Std. 30 Min.)`);
    await expect(offer.getByRole("radio", { name: "Ich (Pflegekraft)" })).toBeChecked();
    await offer.getByRole("button", { name: "Übernehmen mit Pflegekraft" }).click();
    const taken = page.getByTestId("shift-offer-card").filter({ hasText: when }).last();
    await expect(taken.getByTestId("shift-offer-tag")).toHaveText("Übernommen");
    await noSideScroll(page);

    // 4. Her /field day: two cards (one per block), each names its block and both blocks; never a card over the pause.
    await page.goto(`/field?datum=${thu}`);
    const block1 = page.getByRole("article", { name: /07:00 – 11:30/ });
    const block2 = page.getByRole("article", { name: /16:00 – 20:00/ });
    await expect(block1).toHaveCount(1);
    await expect(block2).toHaveCount(1);
    await expect(block1.getByTestId("take-blocks")).toHaveText(`Teil 1 von 2 · Geteilter Dienst ${BOTH}`);
    await expect(block2.getByTestId("take-blocks")).toHaveText(`Teil 2 von 2 · Geteilter Dienst ${BOTH}`);
    await expect(page.getByRole("article", { name: /07:00 – 20:00/ })).toHaveCount(0);
    await noSideScroll(page);

    // 5. The home's week reads «Gedeckt» for the split cell (one source, as for a one-block order).
    await signIn(page, HOME);
    await page.setViewportSize({ width, height: 900 });
    await page.goto(week);
    await expect(cell.getByTestId("heim-cell-order")).toHaveAttribute("data-code", "G");
    await noSideScroll(page);
  });
}
