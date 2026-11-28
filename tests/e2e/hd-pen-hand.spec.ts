import { execFileSync } from "node:child_process";
import { expect, test, type Locator, type Page } from "@playwright/test";
import { zurichDay } from "./support/durchgang-time";
import { addDays, weekStart } from "@/features/home-plan/rules";

// HD-PEN-HAND (brief docs/agents/briefs/HD-PEN-HAND.md, PO decision ENG-PH1; ADR-232; migration 0190): «Stunden nicht
// prüfbar» on the hand path, at 390 and 1440 px.
// - The lead assigns a synthetic person without Pensum and without Monatssoll by hand → the warning names «Stunden nicht
//   prüfbar», the reason and the next action (Pensum / Monatssoll links); nothing is saved.
// - «Abbrechen» → nothing saved (database). Again and «Trotzdem einteilen» → saved with override_rules {hours_unknown};
//   the shift shows «(von Hand bestätigt)» and the count line «… ohne Stundenprüfung» names the person.
// - UXR-309: on her Monatssoll form «kein Monatssoll» is pre-selected; a typed number selects «Wert»; the first save is
//   accepted (no refused «bitte wählen»).
// Weeks 210 and 217 days ahead (no other /heim spec uses them: weeks at most 26 weeks ahead, months 120, 280 and 315
// days ahead). The person, her shifts and her target are deleted from the local test database (port 54322 only) in
// afterAll. Synthetic data only. Fixed rule, no AI.
const PASSWORD = "navora-local-only";
const HOME = "kundebs.test@navora.test";
const INST = "00000000-0000-4000-a000-0000000004c1";
const DB_URL = process.env.E2E_DB_URL ?? "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
const LOCAL_DB = /^postgres(ql)?:\/\/[^@]+@(127\.0\.0\.1|localhost):54322\//;

function psql(sql: string): string {
  if (!LOCAL_DB.test(DB_URL)) throw new Error("HD-PEN-HAND fixture: only the local Supabase database (port 54322)");
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
  // The same check as the other /heim specs; on failure the message names the elements whose right edge passes the
  // viewport (evidence for the fix, the assertion is unchanged).
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

const DAYS = { 390: 210, 1440: 217 } as const;
const people: string[] = [];

test.afterAll(() => {
  for (const id of people) {
    psql(`delete from public.institution_assignments where staff_id = '${id}'`);
    psql(`delete from public.institution_monthly_targets where staff_id = '${id}'`);
    psql(`delete from public.institution_staff where id = '${id}'`);
  }
});

for (const width of [390, 1440] as const) {
  test(`HD-PEN-HAND: «Stunden nicht prüfbar» warns, cancels, confirms and is counted; UXR-309 (${width} px)`, async ({ page }) => {
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
    // A synthetic person without Pensum and without Monatssoll (as a newly added person is).
    const name = `PenHand ${width} (synthetisch)`;
    const id = psql(`insert into public.institution_staff (institution_id, display_name, grade)
                     values ('${INST}', '${name}', 'fage_efz') returning id`).split("\n")[0];
    people.push(id);
    const saved = () => psql(`select count(*) from public.institution_assignments where staff_id = '${id}'`);

    await page.goto(`/heim?ansicht=woche&datum=${wed}`);
    const early = () => cell(page, wed, "Rhein 1", "F");
    const assign = async () => {
      await early().getByTestId("heim-assign-select").selectOption({ label: `${name} (FaGe)` });
      await early().getByTestId("heim-assign").click();
    };
    await assign();
    const warning = page.getByTestId("heim-rule-warning");
    await expect(warning).toContainText(name);
    await expect(warning.getByTestId("heim-rule-warning-rules")).toContainText("Stunden nicht prüfbar");
    await expect(warning.getByTestId("heim-rule-hours-unknown")).toContainText("kein Monatssoll und kein Pensum");
    await expect(warning.getByTestId("heim-rule-next-pensum")).toHaveText("Pensum eintragen");
    await expect(warning.getByTestId("heim-rule-next-month_target")).toContainText("Monatssoll");
    expect(saved()).toBe("0");
    await noSideScroll(page);

    // «Abbrechen»: nothing saved.
    await warning.getByTestId("heim-rule-cancel").click();
    await expect(page.getByTestId("heim-rule-warning")).toHaveCount(0);
    await expect(early().getByTestId("heim-assigned").filter({ hasText: name })).toHaveCount(0);
    expect(saved()).toBe("0");

    // Again, «Trotzdem einteilen»: saved, confirmed, visible on the shift and in the count line.
    await assign();
    await page.getByTestId("heim-rule-confirm").click();
    await expect(page.getByTestId("heim-message")).toHaveText("Eingeteilt, mit bestätigter Regelwarnung. Die Warnung bleibt auf dem Dienst sichtbar.");
    await expect(early().getByTestId("heim-assigned").filter({ hasText: name }).getByTestId("heim-assigned-warning"))
      .toHaveText(/^Regel: Stunden nicht prüfbar.*\(von Hand bestätigt\)$/);
    expect(psql(`select array_to_string(override_rules, ',') from public.institution_assignments where staff_id = '${id}'`)).toBe("hours_unknown");
    await expect(page.getByTestId("heim-hours-unknown-count")).toContainText("ohne Stundenprüfung");
    await noSideScroll(page);

    // UXR-309: «kein Monatssoll» pre-selected; a typed number selects «Wert»; the first save is accepted.
    await page.goto(`/heim?ansicht=personal&datum=${wed}&person=${id}`);
    const box = page.getByTestId("heim-person-month-target-box");
    await expect(box.getByTestId("heim-month-target-none-choice")).toBeChecked();
    await box.getByTestId("heim-month-target-input").fill("40");
    await expect(box.getByTestId("heim-month-target-value")).toBeChecked();
    await box.getByTestId("heim-month-target-save").click();
    await expect(page.getByTestId("heim-message")).toHaveText("Monatssoll gespeichert. Für diesen Monat gilt es statt des Wochenbudgets.");
    expect(psql(`select target_minutes from public.institution_monthly_targets where staff_id = '${id}'`)).toBe("2400");
    await noSideScroll(page);
  });
}
