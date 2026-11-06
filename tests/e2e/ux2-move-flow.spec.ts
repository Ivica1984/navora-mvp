import { expect, test, type Page } from "@playwright/test";
import {
  DAY_CHANGED_RELOAD,
  MOVED_TO_TODAY_STATUS,
  MOVE_TODAY_LINK_LABEL,
  moveLeavesNote,
  zurichMinutesNow,
} from "@/features/field/rules";
import { PLAN_FLAG_LABEL } from "@/features/team/rules";

// UX2 part 5 (ADR-134; brief UX2-18 to UX2-21, `uxa` UXR-36, -37, -40, -41): the /field "Heute machen" flow at
// 390 × 844, synthetic seed account. Display only; `move_visit_to_today` (0093) decides every move.
// One visit of Testfall 08, planned 49 days ahead at 20:05–20:18 (no other spec uses that day or slot), carries all
// four: UX2-18 in the first form; UX2-19 when a second tab moves it to today without a responsible member (planning
// flag "uncovered"); UX2-20 and UX2-21 when the first tab, rendered "yesterday", then confirms (the database answers
// `day_changed` for a visit no longer after today, so the reload fallback). The visit is removed at the end.
const PHONE = { width: 390, height: 844 };
const PASSWORD = "navora-local-only";

function zurichDay(offset = 0): string {
  const [y, m, d] = new Date().toLocaleDateString("sv-SE", { timeZone: "Europe/Zurich" }).split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d + offset)).toISOString().slice(0, 10);
}

function hhmm(minutes: number): string {
  return `${String(Math.floor(minutes / 60)).padStart(2, "0")}:${String(minutes % 60).padStart(2, "0")}`;
}

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

/**
 * Removes this spec's visit wherever it is (planned day or today) through the existing J3 route. Runs in `finally`, so
 * a failed assertion never leaves an uncovered visit on today's /team list for the later specs (CI run 41572248453:
 * the leftover pushed vis1/vis2 slots out of "Geplante Einsätze").
 */
async function removeVisit(page: Page, slots: string[]) {
  await page.goto("/team");
  const upcoming = page.getByRole("article", { name: /Fall Testfall 08/ }).getByRole("list", { name: "Geplante Einsätze" });
  for (const slot of slots) {
    const item = upcoming.getByRole("listitem").filter({ hasText: slot });
    if ((await item.count()) === 0) continue;
    await item.first().getByRole("button", { name: "Entfernen" }).click();
    const remove = item.first().getByRole("form", { name: "Einsatz entfernen" });
    await remove.getByLabel("Grund").fill("Synthetisch: Testeinsatz entfernt");
    await remove.getByRole("button", { name: "Entfernen" }).click();
    await expect(upcoming.getByRole("listitem").filter({ hasText: slot })).toHaveCount(0);
  }
}

test.describe("UX2 move flow at 390 × 844", () => {
  test.use({ viewport: PHONE });

  test("UX2-18 to UX2-21: reserved fact slot, flags describe the moved card, fallback names its link and is read once", async ({ page }) => {
    // The "uncovered" flag needs the moved slot within the next 24 hours and on today's date: 20 minutes ahead,
    // 13 minutes long. Too close to midnight for that, the test cannot build its case (CI runs at any hour).
    const now = zurichMinutesNow();
    test.skip(now > 23 * 60 + 15, "needs a slot 20 minutes ahead that ends before midnight (Europe/Zurich)");
    const startMin = Math.ceil((now + 20) / 5) * 5;
    const start = hhmm(startMin);
    const end = hhmm(startMin + 13);
    const day = zurichDay(49);
    const yesterday = zurichDay(-1);
    await signIn(page, "pflege.test@navora.test");

    await page.goto("/team");
    const caseCard = page.getByRole("article", { name: /Fall Testfall 08/ });
    await caseCard.getByRole("button", { name: "Einsatz planen" }).click();
    const planForm = caseCard.getByRole("form", { name: "Einsatz planen" });
    await planForm.getByLabel("Datum").fill(day);
    await planForm.getByLabel("Von").fill("20:05");
    await planForm.getByLabel("Bis").fill("20:18");
    await planForm.getByLabel("A", { exact: true }).fill("13");
    // Nobody responsible: the move to today then returns the planning flag "uncovered" (UX2-19).
    await planForm.locator("select[name=responsible]").selectOption("");
    await planForm.getByRole("button", { name: "Einsatz speichern" }).click();
    await expect(caseCard.getByRole("list", { name: "Geplante Einsätze" })).toContainText("20:05–20:18");

    try {
      // UX2-18: the VIS1-8 answer is held back for a moment, so the form is measured before and after it arrives.
      let release!: () => void;
      const held = new Promise<void>((resolve) => { release = resolve; });
      await page.route("**/field**", async (route) => {
        if (route.request().method() === "POST" && route.request().headers()["next-action"]) await held;
        await route.continue();
      });
      await page.goto(`/field?datum=${day}`);
      const card = page.getByRole("article", { name: /20:05 – 20:18, Testfall 08/ });
      await card.getByRole("button", { name: "Heute machen" }).click();
      const move = card.getByRole("form", { name: "Einsatz auf heute verschieben" });
      const von = move.getByLabel("Von");
      await expect(von).toBeFocused();
      await expect(move.getByTestId("move-leaves-slot")).toBeVisible();
      await expect(move.getByTestId("move-leaves-note")).toHaveCount(0);
      const before = await von.boundingBox();
      release();
      await expect(move.getByTestId("move-leaves-note")).toHaveText(moveLeavesNote(day, false)!);
      const after = await von.boundingBox();
      expect(before).not.toBeNull();
      expect(after).toEqual(before);
      await expect(von).toBeFocused();
      await page.unroute("**/field**");
      await move.getByLabel("Von").fill("20:05");
      await move.getByLabel("Bis").fill("20:18");
      await move.getByLabel("Grund der Verschiebung").fill("Synthetisch: Seite seit gestern offen");

      // UX2-19: a second tab moves the same visit to today, nobody responsible: "uncovered" is returned and the moved
      // card, which receives focus, is described by the flags list.
      const other = await page.context().newPage();
      await other.goto(`/field?datum=${day}`);
      const otherCard = other.getByRole("article", { name: /20:05 – 20:18, Testfall 08/ });
      await otherCard.getByRole("button", { name: "Heute machen" }).click();
      const otherMove = otherCard.getByRole("form", { name: "Einsatz auf heute verschieben" });
      await otherMove.getByLabel("Von").fill(start);
      await otherMove.getByLabel("Bis").fill(end);
      await otherMove.getByLabel("Grund der Verschiebung").fill("Synthetisch: heute statt später");
      await otherMove.getByRole("button", { name: "Auf heute verschieben" }).click();
      await expect(other.getByTestId("moved-to-today")).toHaveText(MOVED_TO_TODAY_STATUS);
      const flags = other.getByTestId("moved-flags");
      await expect(flags).toContainText(PLAN_FLAG_LABEL.uncovered);
      await expect(flags).toHaveClass(/text-sm/);
      const movedCard = other.getByRole("article", { name: new RegExp(`${start} – ${end}, Testfall 08`) });
      await expect(movedCard).toBeFocused();
      await expect(movedCard).toHaveAccessibleDescription(new RegExp(PLAN_FLAG_LABEL.uncovered.replace(/[()]/g, "\\$&")));
      expect(await other.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(PHONE.width);
      await other.close();

      // UX2-20 / UX2-21: the first tab still shows the form from before; it was rendered "yesterday". The database's day
      // decides (`day_changed`); the visit is no longer after today, so the fallback panel replaces the form.
      const shown = move.locator('input[name="shown"]');
      await shown.evaluate((el, d) => { (el as HTMLInputElement).value = d; }, yesterday);
      await move.getByRole("button", { name: "Auf heute verschieben" }).click();
      const sentence = card.getByTestId("move-day-changed");
      await expect(sentence).toHaveText(DAY_CHANGED_RELOAD);
      await expect(sentence).toBeFocused();
      await expect(sentence).not.toHaveAttribute("role", /.*/);
      await expect(sentence).not.toHaveAttribute("aria-live", /.*/);
      await expect(card.getByRole("link", { name: MOVE_TODAY_LINK_LABEL, exact: true })).toBeVisible();
      expect(DAY_CHANGED_RELOAD).toContain(MOVE_TODAY_LINK_LABEL);
      expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(PHONE.width);
    } finally {
      // Clean up: an uncovered visit today would reach later specs as a signal; removed whatever happened above.
      await page.unroute("**/field**").catch(() => {});
      await removeVisit(page, [`${start}–${end}`, "20:05–20:18"]);
    }
  });
});
