import { expect, test, type Page } from "@playwright/test";

// PLAN3 part (b) (ADR-147, migrations 0109/0110). Synthetic local-only accounts from supabase/seed.sql, Testorganisation H
// (an organisation of its own; no org-A to org-F count changes). The administrator has switched `plan3_day_proposal` on;
// Testteam H's own switch is off as by default. teamh.test (registered nurse of Testteam H) works at 390 px.
// Tomorrow, nobody responsible: 08:00, 09:00, 10:00 (Testfall H1, primary nurse "Pflegekraft Bezug H"), 08:15-08:45
// (Testfall H2, no primary nurse, overlaps 08:00), 12:00 (Testfall H2, category B minutes).
const PASSWORD = "navora-local-only";
const BEZUG = "Pflegekraft Bezug H";
const VISIT_0800 = "00000000-0000-4000-a000-0000000005d1";
const VISIT_0815 = "00000000-0000-4000-a000-0000000005d4";
// CGR-75 (5): the day after tomorrow (seed, ADR-158).
const VISIT_D2_0900 = "00000000-0000-4000-a000-0000000005d6";
const VISIT_D2_1100 = "00000000-0000-4000-a000-0000000005d7";
const VISIT_D2_1400 = "00000000-0000-4000-a000-0000000005d9";

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

/** The German weekday of a yyyy-mm-dd date ("Samstag"). */
function weekdayDe(iso: string): string {
  const [y, m, d] = iso.split("-").map(Number);
  return new Intl.DateTimeFormat("de-CH", { timeZone: "UTC", weekday: "long" }).format(new Date(Date.UTC(y, m - 1, d)));
}

function dotted(iso: string): string {
  const [y, m, d] = iso.split("-");
  return `${d}.${m}.${y}`;
}

test.describe.serial("PLAN3 day-plan proposal at 390 px (Testorganisation H)", () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await signIn(page, "teamh.test@navora.test");
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

    // PLAN3-9 (2) (ADR-160, UXR-103): one place decides a day-plan line. With the five-line day plan open,
    // /team/vorschlaege shows one day row and no day-plan line with its own "Bestätigen"; the row opens that day.
    await page.goto("/team/vorschlaege");
    const teamG = page.getByRole("region", { name: "Vorschläge Testteam H" });
    await expect(teamG.getByTestId("day-plan-row")).toHaveCount(1);
    await expect(teamG.getByTestId("day-plan-row")).toHaveText(`Tagesvorschlag ${weekdayDe(tomorrow)}, ${dotted(tomorrow)}: 5 offen`);
    await expect(teamG.getByTestId("day-plan-row")).not.toContainText("Pflegekraft");
    await expect(teamG.getByTestId("suggestion")).toHaveCount(0);
    await expect(teamG.getByRole("button", { name: "Bestätigen" })).toHaveCount(0);
    await expect(teamG.getByTestId("suggestion-tick")).toHaveCount(0);
    await teamG.getByTestId("day-plan-row").click();
    await page.waitForURL(new RegExp(`/team/tagesplan\\?.*datum=${tomorrow}`));
    await expect(lines).toHaveCount(5);

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
    await expect(page.getByTestId("visit-responsible")).toHaveText("noch niemand") /* UX2-29 (ADR-132): an open visit without a member */;

    // The 12:00 line (category B) is changed to the other registered nurse and confirmed: one `corrected` line.
    await page.goto(`/team/tagesplan?datum=${zurichIso(1)}`);
    const line1200 = page.getByTestId("day-plan-line").filter({ hasText: "12:00" });
    await line1200.getByRole("button", { name: "Ändern" }).click();
    const options = await line1200.getByRole("combobox").locator("option:not([disabled])").allTextContents();
    // CGR-139 (ADR-152): every option of the picker reads differently, and the person planning is marked "(du)".
    expect(new Set(options).size).toBe(options.length);
    const target = options.includes(BEZUG) ? BEZUG : "Pflegekraft Team H (du)";
    if (target !== BEZUG) expect(options).toContain("Pflegekraft Team H (du)");
    await line1200.getByRole("combobox").selectOption({ label: target });
    await line1200.getByRole("button", { name: "Geänderte Zuteilung bestätigen" }).click();
    await expect(line1200.getByTestId("day-plan-decision")).toHaveText("geändert und bestätigt");

    // PLAN3-12: one more confirmed line, one less on the link; the refused 08:15 line still waits.
    await page.goto("/team");
    await expect(page.getByTestId("suggestions-link")).toHaveText("Vorschläge (1)");
    await expect(page.getByTestId("suggestions-link")).toHaveAttribute("aria-label", "1 offene Vorschläge");
  });

  // PLAN3-15 (po 2026-11-06 06:30, `aia` AUT-51; ADR-157, migration 0116): after a sick call the team asks again and
  // sees one list. The 08:15 line, refused `overlap` above, is still undecided; a colleague records the care assistant
  // absent tomorrow 08:00-09:00 on /field; a fresh request for tomorrow is not refused, closes the old 08:15 line and
  // writes a new one. The day plan keeps one line per visit (the lines decided above stay), and the proposals link
  // counts one open line, not two.
  test("record an absence, ask again, see one list: the earlier undecided line is replaced (PLAN3-15)", async ({ page }) => {
    const tomorrow = zurichIso(1);
    await page.goto("/field");
    const absence = page.getByTestId("absence");
    await absence.getByTestId("absence-open").click();
    const form = absence.getByRole("form", { name: "Abwesenheit erfassen" });
    await form.locator("select[name=who]").selectOption({ label: "Pflegekraft Assistenz H · Testteam H" });
    await form.locator("input[name=from]").fill(tomorrow);
    await form.locator("input[name=until]").fill(tomorrow);
    await form.locator("input[name=fromTime]").fill("08:00");
    await form.locator("input[name=untilTime]").fill("09:00");
    await form.getByTestId("absence-save").click();
    await expect(form).toHaveCount(0);

    await page.goto("/team/tagesplan");
    await page.getByLabel("Tag", { exact: true }).fill(tomorrow);
    await page.getByRole("button", { name: "Tag vorschlagen" }).click();
    await page.waitForURL(new RegExp(`datum=${tomorrow}`));
    await expect(page.getByTestId("day-plan-error")).toHaveCount(0);

    const lines = page.getByTestId("day-plan-line");
    await expect(lines).toHaveCount(5);
    await expect(lines.filter({ hasText: "08:15" })).toHaveCount(1);
    await expect(lines.filter({ hasText: "08:15" })).not.toContainText("Pflegekraft Assistenz H");
    const bezug = page.getByRole("region", { name: `Einsätze ${BEZUG}` });
    await expect(bezug.getByTestId("day-plan-decision")).toHaveText(["bestätigt", "bestätigt", "bestätigt"]);
    expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(390);

    await page.goto("/team");
    await expect(page.getByTestId("suggestions-link")).toHaveText("Vorschläge (1)");
  });

  // PLAN3-9 (1) (po 2026-11-06 06:30, `cra` CGR-138; ADR-156, migration 0115): a decided line never reads as a covered
  // visit. The 08:15 line, refused `overlap` above and still open, is rejected: it says "abgelehnt" and "Noch offen" and
  // keeps "Einsatz öffnen"; the visit page says "Noch offen". The confirmed lines keep the link and say no "Noch offen".
  test("a rejected line says 'Noch offen' and keeps 'Einsatz öffnen'; confirmed lines keep the link (PLAN3-9 (1))", async ({ page }) => {
    await page.goto(`/team/tagesplan?datum=${zurichIso(1)}`);
    const line0815 = page.getByTestId("day-plan-line").filter({ hasText: "08:15" });
    await line0815.getByRole("button", { name: "Ablehnen" }).click();
    await expect(line0815.getByTestId("day-plan-decision")).toHaveText("abgelehnt");
    await expect(line0815.getByTestId("day-plan-still-open")).toHaveText("Noch offen");
    await expect(line0815.getByRole("button", { name: "Bestätigen", exact: true })).toHaveCount(0);
    const link = line0815.getByRole("link", { name: "Einsatz öffnen" });
    await expect(link).toBeVisible();

    const bezug = page.getByRole("region", { name: `Einsätze ${BEZUG}` });
    await expect(bezug.getByRole("link", { name: "Einsatz öffnen" })).toHaveCount(3);
    await expect(bezug.getByTestId("day-plan-still-open")).toHaveCount(0);
    // Every line of the day keeps the link, open or decided.
    await expect(page.getByRole("link", { name: "Einsatz öffnen" })).toHaveCount(await page.getByTestId("day-plan-line").count());
    expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(390);

    await link.click();
    await page.waitForURL(new RegExp(`/visits/${VISIT_0815}`));
    await expect(page.getByTestId("visit-responsible")).toHaveText("noch niemand") /* UX2-29 (ADR-132): an open visit without a member */;
  });

  // CGR-75 (5) (`cra`, PLAN3 acceptance condition; ADR-158, pgTAP 117 pins the fixture). The day after tomorrow is a
  // day of its own in the seed, so tomorrow's counts above stay: open 09:00 and 11:00 (Testfall H1, primary nurse Bezug
  // H), 09:15-09:45 and 14:00 category B (Testfall H2); both registered nurses already hold a visit at 14:00, the care
  // assistant may not take B minutes. (1) the 14:00 visit is shown as "kein Vorschlag" with its reason, not hidden and
  // not tickable; (2) she ticks 09:00 and 11:00, then changes 09:15 to Bezug H and confirms it; the ticked list is
  // refused for 09:00 with `overlap` on its own line, 11:00 is set, the 09:00 visit stays "Noch offen" and in
  // "Offen im Team".
  test("an unstaffable visit is shown; a ticked line refused 'overlap' at confirm keeps its reason and its visit stays open (CGR-75 (5))", async ({ page }) => {
    const day = zurichIso(2);
    await page.goto("/team/tagesplan");
    await page.getByLabel("Tag", { exact: true }).fill(day);
    await page.getByRole("button", { name: "Tag vorschlagen" }).click();
    await page.waitForURL(new RegExp(`datum=${day}`));
    const lines = page.getByTestId("day-plan-line");
    await expect(lines).toHaveCount(4);

    // (1) "kein Vorschlag" is a line of its own with the limit, under "Ohne Vorschlag"; no tick box.
    const without = page.getByRole("region", { name: "Ohne Vorschlag" });
    const line1400 = without.getByTestId("day-plan-line");
    await expect(line1400).toHaveCount(1);
    await expect(line1400).toContainText("14:00");
    await expect(line1400.getByTestId("day-plan-reason")).toHaveText(
      "kein Vorschlag: die passenden Mitglieder haben zu dieser Zeit schon einen Einsatz",
    );
    await expect(line1400.getByTestId("day-plan-tick")).toHaveCount(0);
    await expect(line1400.getByRole("button", { name: "Als „kein Vorschlag“ bestätigen" })).toBeVisible();

    // (2) tick 09:00 and 11:00 (Bezug H); the 09:15 line is not hers (it overlaps her 09:00).
    const bezug = page.getByRole("region", { name: `Einsätze ${BEZUG}` });
    const line0900 = page.getByTestId("day-plan-line").filter({ hasText: "09:00–" });
    const line1100 = page.getByTestId("day-plan-line").filter({ hasText: "11:00–" });
    await expect(bezug.getByTestId("day-plan-line").filter({ hasText: "09:00–" })).toHaveCount(1);
    await expect(bezug.getByTestId("day-plan-line").filter({ hasText: "11:00–" })).toHaveCount(1);
    await expect(bezug.getByTestId("day-plan-line").filter({ hasText: "09:15–" })).toHaveCount(0);
    await line0900.getByTestId("day-plan-tick").check();
    await line1100.getByTestId("day-plan-tick").check();

    // Before she confirms the list, the 09:15 line is changed to Bezug H and confirmed: Bezug H now holds 09:15-09:45.
    const line0915 = page.getByTestId("day-plan-line").filter({ hasText: "09:15–" });
    await line0915.getByRole("button", { name: "Ändern" }).click();
    await line0915.getByRole("combobox").selectOption({ label: BEZUG });
    await line0915.getByRole("button", { name: "Geänderte Zuteilung bestätigen" }).click();
    await expect(line0915.getByTestId("day-plan-decision")).toHaveText("geändert und bestätigt");
    await expect(page.getByRole("button", { name: "2 Zuteilungen bestätigen" })).toBeVisible();

    await page.getByRole("button", { name: "2 Zuteilungen bestätigen" }).click();
    await expect(page.getByTestId("day-plan-result")).toHaveText("1 Wert bestätigt, 1 nicht übernommen.");
    await expect(line0900.getByTestId("day-plan-refusal")).toHaveText(
      "Nicht übernommen: Diese Person hat zu dieser Zeit schon einen Einsatz.",
    );
    await expect(line0900.getByTestId("day-plan-decision")).toHaveCount(0);
    await expect(line0900.getByRole("button", { name: "Bestätigen", exact: true })).toBeVisible();
    await expect(line1100.getByTestId("day-plan-decision")).toHaveText("bestätigt");
    await expect(line1100.getByTestId("day-plan-refusal")).toHaveCount(0);
    expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(390);

    await page.goto(`/visits/${VISIT_D2_0900}`);
    await expect(page.getByTestId("visit-responsible")).toHaveText("noch niemand") /* UX2-29 (ADR-132): an open visit without a member */;
    await page.goto(`/visits/${VISIT_D2_1100}`);
    await expect(page.getByTestId("visit-responsible")).toHaveText(BEZUG);

    // The refused visit is in the team's uncovered path (ABS1 "Offen im Team"), with the unstaffable 14:00 visit.
    await page.goto("/field");
    const open = page.getByTestId("open-in-team");
    await open.getByTestId("open-in-team-toggle").click();
    await expect(open.getByTestId("open-visit").filter({ hasText: "09:00–09:30" })).toHaveCount(1);
    await expect(open.getByTestId("open-visit").filter({ hasText: "14:00–14:30" })).toHaveCount(1);
  });

  // CGR-75 (5) with PLAN3-9 (1): the "kein Vorschlag" line decided as such sets nobody and never reads as covered.
  test("a 'kein Vorschlag' line decided as such says so, keeps 'Einsatz öffnen' and its visit stays open (CGR-75 (5), PLAN3-9 (1))", async ({ page }) => {
    await page.goto(`/team/tagesplan?datum=${zurichIso(2)}`);
    const line1400 = page.getByRole("region", { name: "Ohne Vorschlag" }).getByTestId("day-plan-line");
    await line1400.getByRole("button", { name: "Als „kein Vorschlag“ bestätigen" }).click();
    await expect(line1400.getByTestId("day-plan-decision")).toHaveText("„kein Vorschlag“, entschieden");
    await expect(line1400.getByTestId("day-plan-still-open")).toHaveText("Noch offen");
    await expect(line1400.getByRole("button", { name: "Als „kein Vorschlag“ bestätigen" })).toHaveCount(0);
    const link = line1400.getByRole("link", { name: "Einsatz öffnen" });
    await expect(link).toBeVisible();
    expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(390);

    await link.click();
    await page.waitForURL(new RegExp(`/visits/${VISIT_D2_1400}`));
    await expect(page.getByTestId("visit-responsible")).toHaveText("noch niemand") /* UX2-29 (ADR-132): an open visit without a member */;
    await page.goto("/field");
    const open = page.getByTestId("open-in-team");
    await open.getByTestId("open-in-team-toggle").click();
    await expect(open.getByTestId("open-visit").filter({ hasText: "14:00–14:30" })).toHaveCount(1);
  });

  // PLAN3-7 (2) (po 2026-11-06 06:30, `aia` AUT-52; ADR-155): the team sees its own numbers under its switch. Only
  // teamh.test has decided lines this month, so the shares are hidden by AIG1-7's three-person rule; the count stays.
  test("the team sees its own day-plan numbers under its switch, no person, no other team (PLAN3-7 (2))", async ({ page }) => {
    await page.goto("/team/tagesplan");
    const line = page.getByTestId("day-plan-measures");
    await expect(line).toHaveText(/^Diesen Monat: \d+ Tagesvorschl(ag|äge) · /);
    await expect(line).not.toContainText("Pflegekraft");
    await page.getByText("Alle Zahlen dieses Monats").click();
    const cells = page.getByTestId("day-plan-measures-cells");
    await expect(cells).toContainText("Unverändert bestätigt");
    await expect(cells).toContainText("Abgelehnt");
    await expect(cells).not.toContainText("Pflegekraft");
    expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(390);
  });

  test("switched off, the team sees no 'Tag vorschlagen' (PLAN3-10)", async ({ page }) => {
    await page.goto("/team/tagesplan");
    await page.getByRole("button", { name: "Tagesvorschlag ausschalten" }).click();
    await expect(page.getByTestId("day-plan-switch-state")).toHaveText("Der Tagesvorschlag ist für euer Team ausgeschaltet.");
    await expect(page.getByRole("button", { name: "Tag vorschlagen" })).toHaveCount(0);
  });
});

test.describe("PLAN3-12: a member of another team sees no count from Testteam H", () => {
  test("pflege.test (Testorganisation A, no open proposal) reads plain 'Vorschläge' at 390 px", async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await signIn(page, "pflege.test@navora.test");
    await page.goto("/team");
    await expect(page.getByTestId("suggestions-link")).toHaveText("Vorschläge");
    await expect(page.getByTestId("suggestions-link")).not.toHaveAttribute("aria-label", /.+/);
  });
});

test.describe("PLAN3-7 (2): a member of another team sees none of Testteam H's numbers", () => {
  test("pflege.test (Testorganisation A) asks for Testteam H by its id and reads none of its numbers at 390 px", async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await signIn(page, "pflege.test@navora.test");
    await page.goto("/team/tagesplan?team=00000000-0000-4000-a000-0000000001a8");
    await expect(page.getByText("Testteam H")).toHaveCount(0);
    const line = page.getByTestId("day-plan-measures");
    if ((await line.count()) > 0) await expect(line).toHaveText("Diesen Monat: noch kein Tagesvorschlag");
  });
});

// UXR-113 (`uxa` 2026-11-06 03:50, #884) within CGR-139 (ADR-154): the /team "Neuer Einsatz" → "Verantwortlich" picker
// sets the responsible member of a new visit, so it names members like the other visit-assigning pickers. Read only:
// the form is opened and closed without saving. Testteam H's three members are named in the seed.
test.describe("UXR-113: the /team new-visit picker names every member (Testteam H, 390 px)", () => {
  test("options carry the display names, the caller ends '(du)', all differ, no bare 'Ich' or 'Teammitglied <n>'", async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await signIn(page, "teamh.test@navora.test");
    await page.goto("/team");
    const card = page.getByRole("article", { name: /Fall Testfall H1/ });
    await card.getByRole("button", { name: /^(Einsatz planen|Abklärungsbesuch planen)$/ }).click();
    const planForm = card.getByRole("form", { name: "Einsatz planen" });
    const options = (await planForm.getByLabel("Verantwortlich").locator("option").allTextContents()).map((o) => o.trim());
    expect(options).toContain("Pflegekraft Team H (du) – Pflegefachperson");
    expect(options).toContain(`${BEZUG} – Pflegefachperson`);
    expect(options).toContain("Pflegekraft Assistenz H – Pflegeassistenz");
    expect(new Set(options).size).toBe(options.length);
    for (const o of options) {
      expect(o.startsWith("Ich –") || o === "Ich").toBe(false);
      expect(o).not.toMatch(/^Teammitglied \d+( –|$)/);
    }
    await planForm.getByRole("button", { name: "Abbrechen" }).click();
    await expect(planForm).toHaveCount(0);
  });
});
