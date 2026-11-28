import { expect, test, type Page } from "@playwright/test";
import { zurichDay } from "./support/durchgang-time";
import { addDays, weekStart } from "@/features/home-plan/rules";

// HD-3a slice 4 (brief HD.md §5b «Planungslauf: ein Button in Woche und Monat», T-1 «übernommen = gezeigt»): the home
// lead asks for a plan in the week, sees what is new and what stays a gap with its reason, and takes it over. The
// week then shows exactly the shown persons in those shifts; the month offers the same button. A week thirteen weeks
// ahead of the synthetic example home (no other e2e plans there; the HD specs use weeks 5 to 10). Fixed rules, no AI.
// At 390 × 900 px.
const PASSWORD = "navora-local-only";
const HOME = "kundebs.test@navora.test";
const NURSE = "pflegebs.test@navora.test";

async function signIn(page: Page, email: string) {
  await page.context().clearCookies();
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

test("HD-3a: «Plan vorschlagen» in the week shows new shifts and gaps, «übernehmen» saves exactly the shown rows (390 px)", async ({ page }) => {
  test.setTimeout(150_000);
  await page.setViewportSize({ width: 390, height: 900 });
  const monday = weekStart(addDays(zurichDay(), 91));

  await signIn(page, HOME);
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
  await expect(draft.getByTestId("heim-draft-mark")).toContainText("Optimierung (feste Regeln)");
  await expect(draft.getByTestId("heim-draft-mark")).toContainText("Arbeitszeitgesetz nicht abschliessend geprüft");
  await expect(draft.getByTestId("heim-draft-summary")).toHaveText(/^\d+ Dienste? vorgeschlagen · \d+ (Lücke bleibt|Lücken bleiben) · berechnet in \d+ ms$/);
  expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(0);

  // What is shown is what is sent: read every shown row (day, station, shift, person) before «übernehmen».
  const rows = draft.getByTestId("heim-draft-row");
  const n = await rows.count();
  expect(n).toBeGreaterThan(0);
  const shown: Array<{ date: string; station: string; shift: string; person: string }> = [];
  for (const day of await draft.getByTestId("heim-draft-day").all()) {
    const date = (await day.getAttribute("data-date")) as string;
    for (const r of await day.getByTestId("heim-draft-row").all()) {
      const text = (await r.textContent()) ?? "";
      const person = text.split(" · ").at(-1)!.replace(/\s*\([^)]*\)\s*$/, "").trim();
      shown.push({ date, station: (await r.getAttribute("data-station")) as string, shift: (await r.getAttribute("data-shift")) as string, person });
    }
  }
  expect(shown.length).toBe(n);
  await expect(draft.getByTestId("heim-draft-apply")).toHaveText(`Vorschlag übernehmen (${n} ${n === 1 ? "Dienst" : "Dienste"})`);

  await draft.getByTestId("heim-draft-apply").click();
  await expect(page).toHaveURL(/ansicht=woche/);
  await expect(page.getByTestId("heim-message")).toHaveText(`Vorschlag übernommen: ${n} ${n === 1 ? "Dienst" : "Dienste"} eingeteilt.`);

  // The week shows each shown person in her shown shift (one source: institution_plan).
  const byCell = new Map<string, number>();
  for (const s of shown) byCell.set(`${s.date}|${s.station}|${s.shift}|${s.person}`, 1);
  for (const key of byCell.keys()) {
    const [date, station, shift, person] = key.split("|");
    const c = page.locator(`[data-testid="heim-day"][data-date="${date}"] [data-testid="heim-cell"][data-station="${station}"][data-shift="${shift}"]`);
    await expect(c.getByTestId("heim-assigned").filter({ hasText: person })).toHaveCount(1);
  }

  // Asked again for the same week: nothing new for the filled shifts; what is left are the gaps with a reason.
  await page.getByTestId("heim-draft-start").click();
  await expect(page.getByTestId("heim-draft-summary")).toHaveText(/^0 Dienste vorgeschlagen · /);
  await expect(page.getByTestId("heim-draft-apply")).toHaveCount(0);
  const gaps = page.getByTestId("heim-draft-gap");
  for (const g of await gaps.all()) await expect(g).toHaveText(/^Lücke: .+ · .+ · .+(fehlt|fehlen).*/);

  // The month offers the same button for the whole month.
  await page.goto(`/heim?ansicht=monat&datum=${monday}`);
  await page.getByTestId("heim-draft-start").click();
  await expect(page).toHaveURL(/bereich=monat/);
  await expect(page.getByTestId("heim-draft-summary")).toHaveText(/^\d+ Dienste? vorgeschlagen · /);
  await page.getByTestId("heim-draft-cancel").click();
  await expect(page).toHaveURL(/ansicht=monat/);
});

test("HD-3a permission: a NAVORA team nurse gets no draft of a home", async ({ page }) => {
  await signIn(page, NURSE);
  await page.goto("/heim?ansicht=vorschlag&bereich=woche");
  await expect(page.getByTestId("heim-no-institution")).toBeVisible();
  await expect(page.getByTestId("heim-draft")).toHaveCount(0);
});
