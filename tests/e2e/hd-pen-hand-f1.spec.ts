import { execFileSync } from "node:child_process";
import { expect, test, type Locator, type Page } from "@playwright/test";
import { zurichDay } from "./support/durchgang-time";
import { addDays, weekStart } from "@/features/home-plan/rules";

// HD-PEN-HAND-F1 (brief docs/agents/briefs/HD-PEN-HAND-F1.md; UXR-315 to UXR-318), at 390 and 1440 px. No new rule:
// the database decides `hours_unknown` (pgTAP 188); this spec pins what the lead sees and where the links lead.
// - UXR-318: the box says first «Noch nicht eingeteilt.»; no working-time sentence for the hours gap alone; «Pensum
//   eintragen» keeps the pending assignment (`warnung`); after the save the box offers «Jetzt einteilen» (no
//   confirmation sent) and the database saves the shift without an override. Steps from the warning to the entered
//   value: 2 (link, save).
// - UXR-317: the rule line is «Stunden nicht prüfbar» only; the stored-shift mark has one colon.
// - UXR-315 / UXR-316: the count line names «in dieser Woche» and links to the Pensum field of the first affected
//   person; without affected shifts there is no line (this week is used by no other spec).
// Weeks 238 and 245 days ahead (other /heim specs: weeks at most 217 days ahead, months 120, 280 and 315 days ahead).
// The persons and their shifts are deleted from the local test database (port 54322 only) in afterAll. Synthetic data
// only. Fixed rule, no AI.
const PASSWORD = "navora-local-only";
const HOME = "kundebs.test@navora.test";
const INST = "00000000-0000-4000-a000-0000000004c1";
const DB_URL = process.env.E2E_DB_URL ?? "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
const LOCAL_DB = /^postgres(ql)?:\/\/[^@]+@(127\.0\.0\.1|localhost):54322\//;

function psql(sql: string): string {
  if (!LOCAL_DB.test(DB_URL)) throw new Error("HD-PEN-HAND-F1 fixture: only the local Supabase database (port 54322)");
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
  const r = await page.evaluate(() => {
    const over = [...document.querySelectorAll("body *")]
      .map((e) => ({ e, right: e.getBoundingClientRect().right }))
      .filter((x) => x.right > window.innerWidth)
      .slice(0, 8)
      .map((x) => `${x.e.tagName.toLowerCase()}[${x.e.getAttribute("data-testid") ?? x.e.className.toString().slice(0, 60)}] right=${x.right}`);
    return { d: document.documentElement.scrollWidth - window.innerWidth, over };
  });
  expect(r.d, r.over.join(" | ")).toBeLessThanOrEqual(0);
}
function cell(page: Page, date: string, station: string, shift: string): Locator {
  return page.locator(`[data-testid="heim-day"][data-date="${date}"] [data-testid="heim-cell"][data-station="${station}"][data-shift="${shift}"]`);
}

test.describe.configure({ mode: "serial" });

const DAYS = { 390: 238, 1440: 245 } as const;
const people: string[] = [];

test.afterAll(() => {
  for (const id of people) {
    psql(`delete from public.institution_assignments where staff_id = '${id}'`);
    psql(`delete from public.institution_monthly_targets where staff_id = '${id}'`);
    psql(`delete from public.institution_staff where id = '${id}'`);
  }
});

for (const width of [390, 1440] as const) {
  test(`HD-PEN-HAND-F1: range, cause and consequence of «Stunden nicht prüfbar» (${width} px)`, async ({ page }) => {
    test.setTimeout(180_000);
    await page.setViewportSize({ width, height: 900 });
    const wed = addDays(weekStart(addDays(zurichDay(), DAYS[width])), 2);
    await signIn(page, HOME);
    await page.goto("/heim");
    await expect(page.getByRole("heading", { name: "Dienstplanung" })).toBeVisible();
    if (await page.getByTestId("heim-empty").isVisible()) {
      await page.getByTestId("heim-load-example").click();
      await expect(page.getByTestId("heim-message")).toHaveText("Beispieldaten geladen (synthetisch).");
    }
    // Two synthetic persons without Pensum and without Monatssoll (as a newly added person is); the home has a Wochensoll.
    const mk = (n: string) => {
      const id = psql(`insert into public.institution_staff (institution_id, display_name, grade)
                       values ('${INST}', '${n}', 'fage_efz') returning id`).split("\n")[0];
      people.push(id);
      return id;
    };
    const ada = `PenF1 Ada ${width} (synthetisch)`;
    const ben = `PenF1 Ben ${width} (synthetisch)`;
    const adaId = mk(ada);
    const benId = mk(ben);
    const saved = (id: string) => psql(`select count(*) from public.institution_assignments where staff_id = '${id}'`);

    await page.goto(`/heim?ansicht=woche&datum=${wed}`);
    // UXR-315 negative: nothing affected in this week → no count line.
    await expect(page.getByTestId("heim-hours-unknown-count")).toHaveCount(0);
    const thu = addDays(wed, 1);
    const early = (d = wed) => cell(page, d, "Rhein 1", "F");
    const assign = async (n: string, d = wed) => {
      await early(d).getByTestId("heim-assign-select").selectOption({ label: `${n} (FaGe)` });
      await early(d).getByTestId("heim-assign").click();
    };

    // UXR-318 / UXR-317: the box.
    await assign(ada);
    const box = page.getByTestId("heim-rule-warning");
    await expect(box.getByTestId("heim-rule-warning-state")).toHaveText("Noch nicht eingeteilt.");
    await expect(box.locator("p").first()).toHaveText("Noch nicht eingeteilt.");
    await expect(box.getByTestId("heim-rule-warning-rules")).toHaveText("Stunden nicht prüfbar");
    await expect(box.getByTestId("heim-rule-hours-unknown")).toContainText("kein Monatssoll und kein Pensum eingetragen");
    await expect(box.getByTestId("heim-rule-worktime")).toHaveCount(0);
    await expect(box.getByTestId("heim-rule-next-return")).toBeVisible();
    expect(saved(adaId)).toBe("0");
    await noSideScroll(page);

    // Step 1: the link keeps the pending assignment; the box stays above the person's Pensum form.
    await box.getByTestId("heim-rule-next-pensum").click();
    await expect(page).toHaveURL(/ansicht=personal/);
    await expect(page).toHaveURL(/warnung=/);
    await expect(page.getByTestId("heim-rule-warning").getByTestId("heim-rule-warning-state")).toHaveText("Noch nicht eingeteilt.");
    // Step 2: enter the Pensum.
    const form = page.getByTestId("heim-staff-planning-form");
    await form.getByTestId("heim-staff-pensum-value").check();
    await form.getByTestId("heim-staff-pensum").fill("80");
    await form.getByTestId("heim-staff-planning-save").click();
    await expect(page.getByTestId("heim-message")).toHaveText("Pensum und Schichtmodell gespeichert.");
    const back = page.getByTestId("heim-rule-warning");
    await expect(back.getByTestId("heim-rule-warning-state")).toHaveText("Noch nicht eingeteilt.");
    await expect(back.getByTestId("heim-rule-returned")).toBeVisible();
    // After a return the box never offers the confirmation (a stale rule list is not confirmed).
    await expect(back.getByTestId("heim-rule-confirm")).toHaveCount(0);
    expect(saved(adaId)).toBe("0");
    await noSideScroll(page);

    // «Jetzt einteilen»: the database checks again; the gap is closed → saved without override, no warning on the shift.
    await back.getByTestId("heim-rule-assign-again").click();
    await expect(page.getByTestId("heim-message")).toHaveText("Eingeteilt.");
    await expect(page.getByTestId("heim-rule-warning")).toHaveCount(0);
    await expect(page).toHaveURL(/ansicht=woche/);
    await expect(early().getByTestId("heim-assigned").filter({ hasText: ada })).toHaveCount(1);
    expect(psql(`select coalesce(array_to_string(override_rules, ','), '') from public.institution_assignments where staff_id = '${adaId}'`)).toBe("");
    await expect(page.getByTestId("heim-hours-unknown-count")).toHaveCount(0);

    // UXR-315 / UXR-316 / UXR-317: a confirmed shift without hours check is counted for this week and links to its cause.
    await assign(ben, thu);
    await page.getByTestId("heim-rule-confirm").click();
    await expect(page.getByTestId("heim-message")).toHaveText("Eingeteilt, mit bestätigter Regelwarnung. Die Warnung bleibt auf dem Dienst sichtbar.");
    await expect(early(thu).getByTestId("heim-assigned").filter({ hasText: ben }).getByTestId("heim-assigned-warning"))
      .toHaveText("Regel: Stunden nicht prüfbar (von Hand bestätigt)");
    const line = page.getByTestId("heim-hours-unknown-count");
    await expect(line.getByTestId("heim-hours-unknown-text")).toHaveText("1 Dienst ohne Stundenprüfung in dieser Woche (davon 1 von Hand bestätigt)");
    await expect(line.getByTestId("heim-hours-unknown-weekly")).toHaveCount(0);
    await expect(line.getByTestId("heim-hours-unknown-note")).toHaveCount(0);
    const link = line.getByTestId("heim-hours-unknown-first");
    await expect(link).toHaveText(`Pensum von ${ben} eintragen`);
    await noSideScroll(page);
    await link.click();
    await expect(page).toHaveURL(new RegExp(`person=${benId}`));
    await expect(page).toHaveURL(/#heim-staff-planning$/);
    await expect(page.getByTestId("heim-staff-planning-form")).toBeVisible();
    await expect(page.getByTestId("heim-staff-planning-now")).toContainText("Pensum nicht eingetragen");
  });
}
