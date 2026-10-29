import { expect, test, type Page } from "@playwright/test";
import {
  MOVED_TO_TODAY_STATUS,
  dayChangedNote,
  formatShortDate,
  prefillMoveTimes,
  zurichMinutesNow,
} from "@/features/field/rules";

// VIS1-10 (ADR-116, `cra` CGR-91; brief VIS1-10 as amended 03:10 and 04:10): "Heute machen" from a page left open across
// 00:00 does not move the visit to yesterday. The database refuses (`day_changed`, pgTAP 093 at a pinned 00:05), the
// confirmation stays open with the new date as a fact (focus on it), the times re-derived for the new now, the reason
// kept; a second confirm stores the shown date. Phone 390 × 844, synthetic seed account.
// The e2e job keeps the real server and database clock (ADR-081, ADR-113). The browser clock is pinned at 23:58 the
// evening before when the form opens and moved to the real now before the confirm; the page's date from before
// midnight is the form's `shown` field, set to yesterday (what a page rendered yesterday sends).
// The visit is planned 47 days ahead at 21:15 (no other spec uses that day or slot); the second confirm uses 22:40 so
// this visit never shares its times with a prefill-based visit of vis1.spec on today's list.
const PHONE = { width: 390, height: 844 };
const PASSWORD = "navora-local-only";

function zurichDay(offset = 0): string {
  const [y, m, d] = new Date().toLocaleDateString("sv-SE", { timeZone: "Europe/Zurich" }).split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d + offset)).toISOString().slice(0, 10);
}

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

/** 23:58 Zurich on the evening before `now` (minutes and seconds since Zurich midnight taken off, then two minutes). */
function eveningBefore(now: Date): Date {
  const seconds = Number(new Intl.DateTimeFormat("en-GB", { timeZone: "Europe/Zurich", second: "2-digit" }).format(now));
  const sinceMidnightMs = (zurichMinutesNow(now) * 60 + seconds) * 1000 + now.getMilliseconds();
  return new Date(now.getTime() - sinceMidnightMs - 2 * 60 * 1000);
}

test.describe("VIS1-10 at 390 × 844", () => {
  test.use({ viewport: PHONE });

  test("VIS1-10: a move confirmed after midnight is refused, shown again with the new date, and lands on today", async ({ page }) => {
    const day = zurichDay(47);
    const today = zurichDay(0);
    const yesterday = zurichDay(-1);
    const reason = "Synthetisch: Seite seit gestern Abend offen";
    await signIn(page, "pflege.test@navora.test");

    await page.goto("/team");
    const caseCard = page.getByRole("article", { name: /Fall Testfall 08/ });
    await caseCard.getByRole("button", { name: "Einsatz planen" }).click();
    const planForm = caseCard.getByRole("form", { name: "Einsatz planen" });
    await planForm.getByLabel("Datum").fill(day);
    await planForm.getByLabel("Von").fill("21:15");
    await planForm.getByLabel("Bis").fill("21:45");
    await planForm.getByLabel("A", { exact: true }).fill("30");
    await planForm.getByRole("button", { name: "Einsatz speichern" }).click();
    await expect(caseCard.getByRole("list", { name: "Geplante Einsätze" })).toContainText("21:15–21:45");

    // Yesterday evening, 23:58: she opens "Heute machen". No prefill across midnight (VIS1-3c), so she types a slot.
    const evening = eveningBefore(new Date());
    await page.clock.setFixedTime(evening);
    await page.goto(`/field?datum=${day}`);
    const card = page.getByRole("article", { name: /21:15 – 21:45, Testfall 08/ });
    await card.getByRole("button", { name: "Heute machen" }).click();
    const move = card.getByRole("form", { name: "Einsatz auf heute verschieben" });
    const atEvening = prefillMoveTimes(zurichMinutesNow(evening), "21:15", "21:45");
    await expect(move.getByLabel("Von")).toHaveValue(atEvening.start);
    await expect(move.getByLabel("Bis")).toHaveValue(atEvening.end);
    await move.getByLabel("Von").fill("23:00");
    await move.getByLabel("Bis").fill("23:30");
    await move.getByLabel("Grund der Verschiebung").fill(reason);
    // The page was rendered yesterday: the date it shows as "Heute" is yesterday's. Set last, after the typing: every
    // re-render writes the field's default again (React sets a hidden input's value from defaultValue on update).
    const shown = move.locator('input[name="shown"]');
    await shown.evaluate((el, d) => { (el as HTMLInputElement).value = d; }, yesterday);
    await expect(shown).toHaveValue(yesterday);

    // Midnight passes; she confirms. The database's day decides: refused, nothing stored.
    const now = new Date();
    await page.clock.setFixedTime(now);
    const expected = prefillMoveTimes(zurichMinutesNow(now), "21:15", "21:45");
    await move.getByRole("button", { name: "Auf heute verschieben" }).click();
    const note = move.getByTestId("move-day-changed");
    await expect(note).toHaveText(dayChangedNote(today));
    await expect(note).toHaveAttribute("data-tone", "info");
    await expect(note).toHaveAttribute("tabindex", "-1");
    await expect(note).toBeFocused();
    expect(await page.evaluate(() => document.activeElement?.getAttribute("data-testid"))).toBe("move-day-changed");
    // The form stays open: the new date, the times re-derived for the new now, the reason kept, confirm label unchanged.
    await expect(move.getByTestId("move-to-today-date")).toHaveText(formatShortDate(today));
    await expect(move.getByLabel("Von")).toHaveValue(expected.start);
    await expect(move.getByLabel("Bis")).toHaveValue(expected.end);
    await expect(move.getByLabel("Grund der Verschiebung")).toHaveValue(reason);
    await expect(move.getByRole("button", { name: "Auf heute verschieben" })).toBeEnabled();
    await expect(page.getByTestId("moved-to-today")).toHaveCount(0);
    await expect(page.getByText(MOVED_TO_TODAY_STATUS, { exact: true })).toHaveCount(0);
    await expect(page.getByTestId("move-to-today-error")).toHaveCount(0);

    // Second confirm: stored on the shown date (today), and /field shows today with the moved card.
    await move.getByLabel("Von").fill("22:40");
    await move.getByLabel("Bis").fill("23:10");
    await move.getByRole("button", { name: "Auf heute verschieben" }).click();
    await expect(page.getByTestId("moved-to-today")).toHaveText(MOVED_TO_TODAY_STATUS);
    const moved = page.getByRole("article", { name: "22:40 – 23:10, Testfall 08" });
    await expect(moved).toHaveCount(1);
    await expect(page.getByTestId("future-day-note")).toHaveCount(0);

    // Nothing was moved to yesterday, and the visit left its planned day.
    await page.goto(`/field?datum=${yesterday}`);
    await expect(page.getByRole("article", { name: /22:40 – 23:10, Testfall 08|23:00 – 23:30, Testfall 08/ })).toHaveCount(0);
    await page.goto(`/field?datum=${day}`);
    await expect(page.getByRole("article", { name: /Testfall 08/ })).toHaveCount(0);

    const width = await page.evaluate(() => document.documentElement.scrollWidth);
    expect(width).toBeLessThanOrEqual(PHONE.width);
  });
});
