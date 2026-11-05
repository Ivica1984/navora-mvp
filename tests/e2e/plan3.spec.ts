import { expect, test, type Page } from "@playwright/test";

// PLAN3 part (b) (ADR-147, migrations 0109/0110). Synthetic local-only accounts from supabase/seed.sql, Testorganisation G
// (an organisation of its own; no org-A to org-F count changes). The administrator has switched `plan3_day_proposal` on;
// Testteam G's own switch is off as by default. teamg.test (registered nurse of Testteam G) works at 390 px.
// Tomorrow, nobody responsible: 08:00, 09:00, 10:00 (Testfall G1, primary nurse "Pflegekraft Bezug G"), 08:15-08:45
// (Testfall G2, no primary nurse, overlaps 08:00), 12:00 (Testfall G2, category B minutes).
const PASSWORD = "navora-local-only";
const BEZUG = "Pflegekraft Bezug G";
const VISIT_0800 = "00000000-0000-4000-a000-0000000005c1";
const VISIT_0815 = "00000000-0000-4000-a000-0000000005c4";

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

/** Today in Europe/Zurich as yyyy-mm-dd. */
function zurichIso(offsetDays = 0): string {
  const today = new Date().toLocaleDateString("sv-SE", { timeZone: "Europe/Zurich" });
  const d = new Date(`${today}T12:00:00Z`);
  d.setUTCDate(d.getUTCDate() + offsetDays);
  return d.toISOString().slice(0, 10);
}

function dotted(iso: string): string {
  const [y, m, d] = iso.split("-");
  return `${d}.${m}.${y}`;
}

test.describe.serial("PLAN3 day-plan proposal at 390 px (Testorganisation G)", () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await signIn(page, "teamg.test@navora.test");
  });

  test("the team switches the proposal on for itself; the date is shown, no name (PLAN3-10)", async ({ page }) => {
    await page.goto("/team");
    await page.getByRole("link", { name: "Tagesvorschlag" }).click();
    await page.waitForURL(/\/team\/tagesplan/);
    await expect(page.getByTestId("day-plan-switch-state")).toHaveText("Der Tagesvorschlag ist für euer Team ausgeschaltet.");
    await expect(page.getByRole("button", { name: "Tag vorschlagen" })).toHaveCount(0);

    await page.getByTestId("day-plan-switch").click();
    await expect(page.getByTestId("day-plan-switch-state")).toHaveText(`Tagesvorschlag eingeschaltet am ${dotted(zurichIso())}`);
    await expect(page.getByTestId("day-plan-switch-state")).not.toContainText("Pflegekraft");
    await expect(page.getByRole("button", { name: "Tag vorschlagen" })).toBeVisible();
  });

  test("ask; the proposal renders per member with no line ticked; three ticked of the list confirm exactly three (PLAN3-1, -3, -4, -9)", async ({ page }) => {
    const tomorrow = zurichIso(1);
    await page.goto("/team/tagesplan");
    await page.getByLabel("Tag", { exact: true }).fill(tomorrow);
    await page.getByRole("button", { name: "Tag vorschlagen" }).click();
    await page.waitForURL(new RegExp(`datum=${tomorrow}`));

    const lines = page.getByTestId("day-plan-line");
    await expect(lines).toHaveCount(5);

    // PLAN3-12: the entry to the proposals on /team names how many wait (count only, no name).
    const planUrl = page.url();
    await page.goto("/team");
    await expect(page.getByTestId("suggestions-link")).toHaveText("Vorschläge (5)");
    await expect(page.getByTestId("suggestions-link")).toHaveAttribute("aria-label", "5 offene Vorschläge");
    await expect(page.getByTestId("suggestions-link")).not.toContainText("Pflegekraft");
    await page.goto(planUrl);
    await expect(lines).toHaveCount(5);
    const ticks = page.getByTestId("day-plan-tick");
    const checked = () => ticks.evaluateAll((els) => els.filter((e) => (e as HTMLInputElement).checked).length);
    await expect.poll(checked).toBe(0);
    await expect(page.getByRole("button", { name: /alle/i })).toHaveCount(0);

    // PLAN3-3: the primary nurse first, with the stated reason; PLAN3-4: this team's minutes before and after.
    const bezug = page.getByRole("region", { name: `Einsätze ${BEZUG}` });
    await expect(bezug.getByTestId("day-plan-line")).toHaveCount(3);
    await expect(bezug.getByTestId("day-plan-reason")).toHaveText(["Bezugspflegende", "Bezugspflegende", "Bezugspflegende"]);
    await expect(bezug.getByTestId("day-plan-load")).toHaveText("0 → 90 Minuten in eurem Team");
    // The 08:15 visit overlaps 08:00, so it is not proposed to her (PLAN3-2).
    await expect(bezug.getByTestId("day-plan-line").filter({ hasText: "08:15" })).toHaveCount(0);

    // CGR-78 (b): each box ticks its own line only; the button names its count.
    for (const t of ["08:00", "09:00", "10:00"]) {
      await bezug.getByTestId("day-plan-line").filter({ hasText: t }).getByTestId("day-plan-tick").check();
      await expect.poll(checked).toBe(["08:00", "09:00", "10:00"].indexOf(t) + 1);
    }
    await page.getByRole("button", { name: "3 Zuteilungen bestätigen" }).click();
    await expect(page.getByTestId("day-plan-result")).toHaveText("3 Werte bestätigt.");
    await expect(bezug.getByTestId("day-plan-decision")).toHaveText(["bestätigt", "bestätigt", "bestätigt"]);

    await page.goto(`/visits/${VISIT_0800}`);
    await expect(page.getByTestId("visit-responsible")).toHaveText(BEZUG);

    // PLAN3-12: three confirmed of five, two wait.
    await page.goto("/team");
    await expect(page.getByTestId("suggestions-link")).toHaveText("Vorschläge (2)");
  });

  test("a line changed to a member busy at that time is refused 'overlap' and its visit stays open; another change is confirmed (PLAN3-5, PLAN3-14 (2))", async ({ page }) => {
    await page.goto(`/team/tagesplan?datum=${zurichIso(1)}`);
    const line0815 = page.getByTestId("day-plan-line").filter({ hasText: "08:15" });
    await line0815.getByRole("button", { name: "Ändern" }).click();
    await line0815.getByRole("combobox").selectOption({ label: BEZUG });
    await line0815.getByRole("button", { name: "Geänderte Zuteilung bestätigen" }).click();
    await expect(line0815.getByTestId("day-plan-refusal")).toHaveText("Nicht übernommen: Diese Person hat zu dieser Zeit schon einen Einsatz.");
    await expect(line0815.getByRole("button", { name: "Bestätigen", exact: true })).toBeVisible();
    await page.goto(`/visits/${VISIT_0815}`);
    await expect(page.getByTestId("visit-responsible")).toHaveText("Noch offen");

    // The 12:00 line (category B) is changed to the other registered nurse and confirmed: one `corrected` line.
    await page.goto(`/team/tagesplan?datum=${zurichIso(1)}`);
    const line1200 = page.getByTestId("day-plan-line").filter({ hasText: "12:00" });
    await line1200.getByRole("button", { name: "Ändern" }).click();
    const options = await line1200.getByRole("combobox").locator("option:not([disabled])").allTextContents();
    const target = options.includes(BEZUG) ? BEZUG : "Pflegekraft Team G";
    await line1200.getByRole("combobox").selectOption({ label: target });
    await line1200.getByRole("button", { name: "Geänderte Zuteilung bestätigen" }).click();
    await expect(line1200.getByTestId("day-plan-decision")).toHaveText("geändert und bestätigt");

    // PLAN3-12: one more confirmed line, one less on the link; the refused 08:15 line still waits.
    await page.goto("/team");
    await expect(page.getByTestId("suggestions-link")).toHaveText("Vorschläge (1)");
    await expect(page.getByTestId("suggestions-link")).toHaveAttribute("aria-label", "1 offene Vorschläge");
  });

  test("switched off, the team sees no 'Tag vorschlagen' (PLAN3-10)", async ({ page }) => {
    await page.goto("/team/tagesplan");
    await page.getByRole("button", { name: "Tagesvorschlag ausschalten" }).click();
    await expect(page.getByTestId("day-plan-switch-state")).toHaveText("Der Tagesvorschlag ist für euer Team ausgeschaltet.");
    await expect(page.getByRole("button", { name: "Tag vorschlagen" })).toHaveCount(0);
  });
});

test.describe("PLAN3-12: a member of another team sees no count from Testteam G", () => {
  test("pflege.test (Testorganisation A, no open proposal) reads plain 'Vorschläge' at 390 px", async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await signIn(page, "pflege.test@navora.test");
    await page.goto("/team");
    await expect(page.getByTestId("suggestions-link")).toHaveText("Vorschläge");
    await expect(page.getByTestId("suggestions-link")).not.toHaveAttribute("aria-label", /.+/);
  });
});
