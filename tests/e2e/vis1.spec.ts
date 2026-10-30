import { expect, test, type Page } from "@playwright/test";
import {
  MOVED_TO_TODAY_STATUS,
  RELEASED_ON_MOVE,
  formatDayLabel,
  formatShortDate,
  futureDayNote,
  moveLeavesNote,
  prefillMoveTimes,
  zurichMinutesNow,
} from "@/features/field/rules";

// VIS1 (ADR-111, `cra` CGR-87): field actions happen on the visit's day. Phone 390 × 844, synthetic seed accounts.
// VIS1-4:  on a day after today no "Einsatz starten" is shown; the VIS1-3 sentence is shown once, styled `info`, and no
//          card of that day has a filled button (VIS1-3a).
// VIS1-3b: "Heute machen" opens one confirmation with today's date, prefilled times and an empty required reason;
//          cancel leaves the visit unchanged; confirm moves it to today (existing J3 move, `moved` row), not started.
// Follow-up (ADR-112): VIS1-3c the prefill is the next full 5 minutes after the (pinned) browser clock plus the card's
//          duration; VIS1-3e focus into the form, back on cancel, onto the moved card after success, and the
//          count-aware day line; VIS1-8 the fact about the date the visit leaves; VIS1-3d the release notice on /field.
// The visit is planned here, 45 days ahead at 22:00 (no other test uses that day).
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

test.describe("VIS1 at 390 × 844", () => {
  test.use({ viewport: PHONE });

  test("VIS1-4 / VIS1-3a / VIS1-3b: a future visit offers only the move to today, which never starts it", async ({ page }) => {
    // 45 days ahead: beyond the PLAN2 window and every other spec's day (doctor.spec plans Testfall 08 nine days ahead),
    // so this client has no other visit that day (VIS1-8 "kein Einsatz").
    const day = zurichDay(45);
    const today = zurichDay(0);
    const reason = "Synthetisch: Klientin bittet um heute";
    // VIS1-3c: the browser clock is pinned for the test (real now, so the server's day and the database agree).
    const pinned = new Date();
    await page.clock.setFixedTime(pinned);
    const expected = prefillMoveTimes(zurichMinutesNow(pinned), "22:00", "22:30");
    await signIn(page, "pflege.test@navora.test");

    await page.goto("/team");
    const caseCard = page.getByRole("article", { name: /Fall Testfall 08/ });
    await caseCard.getByRole("button", { name: "Einsatz planen" }).click();
    const planForm = caseCard.getByRole("form", { name: "Einsatz planen" });
    await planForm.getByLabel("Datum").fill(day);
    await planForm.getByLabel("Von").fill("22:00");
    await planForm.getByLabel("Bis").fill("22:30");
    await planForm.getByLabel("A", { exact: true }).fill("30");
    await planForm.getByRole("button", { name: "Einsatz speichern" }).click();
    await expect(caseCard.getByRole("list", { name: "Geplante Einsätze" })).toContainText("22:00–22:30");

    // VIS1-4: no field action on a day after today; the sentence once, `info`.
    await page.goto(`/field?datum=${day}`);
    const card = page.getByRole("article", { name: /22:00 – 22:30, Testfall 08/ });
    await expect(card).toHaveCount(1);
    const list = page.getByRole("list", { name: "Einsätze" });
    await expect(list.getByRole("button", { name: "Einsatz starten" })).toHaveCount(0);
    await expect(list.getByRole("button", { name: "Losfahren" })).toHaveCount(0);
    const note = page.getByTestId("future-day-note");
    await expect(note).toHaveCount(1);
    await expect(note).toHaveText(futureDayNote(day, await list.getByRole("article").count()));
    await expect(note).toHaveAttribute("data-tone", "info");
    await expect(page.getByText(await note.innerText(), { exact: true })).toHaveCount(1);
    // VIS1-3a: no card of that day has a filled button; the move is an outline action.
    const filled = await list.getByRole("article").evaluateAll((cards) =>
      cards.flatMap((c) =>
        (Array.from(c.querySelectorAll("button")) as HTMLButtonElement[])
          .filter((b) => b.offsetParent !== null)
          .filter((b) => {
            const bg = getComputedStyle(b).backgroundColor;
            return bg !== "rgba(0, 0, 0, 0)" && bg !== "transparent" && bg !== "rgb(255, 255, 255)";
          })
          .map((b) => (b.textContent ?? "").trim()),
      ),
    );
    expect(filled, `filled buttons on ${day}: ${filled.join(", ")}`).toEqual([]);
    await expect(card.getByRole("button", { name: "Heute machen" })).toBeVisible();

    // VIS1-3b / VIS1-3c: one confirmation, today and the prefilled times, the reason empty and required; cancel changes
    // nothing. VIS1-3e (1): focus moves to "Von" on open and back to "Heute machen" on cancel.
    await card.getByRole("button", { name: "Heute machen" }).click();
    const move = card.getByRole("form", { name: "Einsatz auf heute verschieben" });
    await expect(move.getByTestId("move-to-today-date")).toHaveText(formatShortDate(today));
    await expect(move.getByLabel("Von")).toBeFocused();
    expect(await page.evaluate(() => (document.activeElement as HTMLInputElement | null)?.name)).toBe("start");
    await expect(move.getByLabel("Von")).toHaveValue(expected.start);
    await expect(move.getByLabel("Bis")).toHaveValue(expected.end);
    await expect(move.getByLabel("Von")).toHaveAttribute("required", "");
    await expect(move.getByLabel("Bis")).toHaveAttribute("required", "");
    // VIS1-8: the client has no other visit on that day (this test owns the day, 45 days ahead).
    await expect(move.getByTestId("move-leaves-note")).toHaveText(moveLeavesNote(day, false)!);
    await expect(move.getByTestId("move-leaves-note")).toHaveAttribute("data-tone", "info");
    const reasonField = move.getByLabel("Grund der Verschiebung");
    await expect(reasonField).toHaveValue("");
    await expect(reasonField).toHaveAttribute("required", "");
    await move.getByRole("button", { name: "Abbrechen" }).click();
    await expect(move).toHaveCount(0);
    await expect(card.getByRole("button", { name: "Heute machen" })).toBeFocused();
    expect(await page.evaluate(() => document.activeElement?.textContent?.trim())).toBe("Heute machen");
    await page.reload();
    await expect(page.getByRole("article", { name: /22:00 – 22:30, Testfall 08/ })).toHaveCount(1);

    // After 23:25 Zurich the prefill is empty (no visit across midnight, VIS1-3c); then she types a 30-minute slot of
    // today herself (the card's planned minutes must fit the window).
    const times = expected.start ? expected : { start: "23:00", end: "23:30" };
    const slot = `${times.start} – ${times.end}, Testfall 08`;
    // CGR-96 (#693, ADR-127): the prefill follows the clock, and earlier specs plan other Testfall 08 visits today at
    // fixed slots (ux1.spec 20:45–21:15, vis1-10.spec 22:40–23:10, lifecycle.spec 16:00 to 20:00, …). In an evening run
    // the moved visit can land on such a slot, so the slot then holds two cards of two different visits (pgTAP 102: one
    // move never adds a visit). Count the cards already in the slot before the move; the move adds exactly one, and the
    // moved card is the one that receives focus (VIS1-3e).
    await page.goto("/field");
    const before = await page.getByRole("article", { name: slot }).count();
    test.info().annotations.push({ type: "CGR-96", description: `slot ${slot}: ${before} other card(s) of today before the move` });
    await page.goto(`/field?datum=${day}`);

    // Confirm with a typed reason: she is on today's view, the visit planned there, "Einsatz starten" its own tap.
    await page.getByRole("article", { name: /22:00 – 22:30, Testfall 08/ }).getByRole("button", { name: "Heute machen" }).click();
    const confirm = page.getByRole("form", { name: "Einsatz auf heute verschieben" });
    if (!expected.start) {
      await confirm.getByLabel("Von").fill(times.start);
      await confirm.getByLabel("Bis").fill(times.end);
    }
    await confirm.getByLabel("Grund der Verschiebung").fill(reason);
    await confirm.getByRole("button", { name: "Auf heute verschieben" }).click();
    // VIS1-3g: the notice is shown once; the address does not keep the move's parameters.
    await expect(page.getByTestId("moved-to-today")).toBeVisible();
    await expect(page).not.toHaveURL(/verschoben=/);
    await expect(page.getByRole("article", { name: slot })).toHaveCount(before + 1);
    const moved = page.getByRole("article", { name: slot }).and(page.locator(":focus"));
    await expect(moved).toHaveCount(1);
    // VIS1-3e (1): one status line, and focus on the moved card.
    await expect(page.getByTestId("moved-to-today")).toHaveCount(1);
    await expect(page.getByTestId("moved-to-today")).toHaveText(MOVED_TO_TODAY_STATUS);
    await expect(page.getByTestId("moved-to-today")).toHaveAttribute("role", "status");
    await expect(moved).toBeFocused();
    // VIS1-3f: a move without `released` adds no accessible description.
    await expect(moved).not.toHaveAttribute("aria-describedby", /.+/);
    await expect(moved.getByTestId("visit-status")).toHaveText("Geplant");
    await expect(moved.getByRole("button", { name: "Einsatz starten" })).toBeVisible();
    await expect(moved.getByRole("region", { name: "Erfasste Zeit" })).toHaveCount(0);   // no start recorded
    await expect(page.getByTestId("future-day-note")).toHaveCount(0);

    await page.goto(`/field?datum=${day}`);
    await expect(page.getByRole("article", { name: /Testfall 08/ })).toHaveCount(0);

    // The move is on record with its reason (J3 `moved` row; its audit row is asserted in pgTAP 089).
    await page.goto("/team");
    const upcoming = page.getByRole("article", { name: /Fall Testfall 08/ }).getByRole("list", { name: "Geplante Einsätze" });
    // Issue #650: the prefilled times depend on the hour of the run, so another planned Testfall 08 visit can share them;
    // the moved visit is the one of today with these times.
    const movedItem = upcoming.getByRole("listitem")
      .filter({ hasText: formatDayLabel(zurichDay()) })
      .filter({ hasText: `${times.start}–${times.end}` });
    await expect(movedItem).toHaveCount(1);
    await expect(movedItem).toContainText(`Verschoben von dir: ${reason}`);

    const width = await page.evaluate(() => document.documentElement.scrollWidth);
    expect(width).toBeLessThanOrEqual(PHONE.width);
  });

  // VIS1-8 and VIS1-3e (2): a client with two visits on the day: "noch ein Einsatz"; the day line counts the cards.
  test("VIS1-8 / VIS1-3e: a second visit that day is stated, and the day line is count-aware", async ({ page }) => {
    const day = zurichDay(10);
    await signIn(page, "pflege.test@navora.test");
    await page.goto("/team");
    const caseCard = page.getByRole("article", { name: /Fall Testfall 08/ });
    for (const [from, to] of [["21:00", "21:30"], ["22:00", "22:30"]]) {
      await caseCard.getByRole("button", { name: "Einsatz planen" }).click();
      const planForm = caseCard.getByRole("form", { name: "Einsatz planen" });
      await planForm.getByLabel("Datum").fill(day);
      await planForm.getByLabel("Von").fill(from);
      await planForm.getByLabel("Bis").fill(to);
      await planForm.getByLabel("A", { exact: true }).fill("30");
      await planForm.getByRole("button", { name: "Einsatz speichern" }).click();
      await expect(caseCard.getByRole("list", { name: "Geplante Einsätze" })).toContainText(`${from}–${to}`);
    }

    await page.goto(`/field?datum=${day}`);
    const list = page.getByRole("list", { name: "Einsätze" });
    const count = await list.getByRole("article").count();
    expect(count).toBeGreaterThanOrEqual(2);
    await expect(page.getByTestId("future-day-note")).toHaveText(futureDayNote(day, count));
    await expect(page.getByTestId("future-day-note")).toContainText("Diese Einsätze sind");

    const card = page.getByRole("article", { name: /21:00 – 21:30, Testfall 08/ });
    await card.getByRole("button", { name: "Heute machen" }).click();
    const move = card.getByRole("form", { name: "Einsatz auf heute verschieben" });
    await expect(move.getByTestId("move-leaves-note")).toHaveText(moveLeavesNote(day, true)!);
    await move.getByRole("button", { name: "Abbrechen" }).click();
    await expect(page.getByRole("article", { name: /21:00 – 21:30, Testfall 08/ })).toHaveCount(1);
  });

  // VIS1-3d: a move whose responsible member is absent at the new time is released, and /field says so with the /team
  // text. The responsible member is assist.test, recorded absent from yesterday through today by field.spec "ABS1-C6"
  // (that file runs before this one: one worker, files in name order).
  test("VIS1-3d: the release of a moved visit is shown on /field", async ({ page }) => {
    const day = zurichDay(11);
    await signIn(page, "pflege.test@navora.test");
    await page.goto("/team");
    const caseCard = page.getByRole("article", { name: /Fall Testfall 08/ });
    await caseCard.getByRole("button", { name: "Einsatz planen" }).click();
    const planForm = caseCard.getByRole("form", { name: "Einsatz planen" });
    await planForm.getByLabel("Datum").fill(day);
    await planForm.getByLabel("Von").fill("23:30");
    await planForm.getByLabel("Bis").fill("23:45");
    await planForm.getByLabel("A", { exact: true }).fill("15");
    await planForm.locator("select[name=responsible]").selectOption("00000000-0000-4000-a000-000000000906");
    await planForm.getByRole("button", { name: "Einsatz speichern" }).click();
    await expect(caseCard.getByRole("list", { name: "Geplante Einsätze" })).toContainText("23:30–23:45");

    await page.goto(`/field?datum=${day}`);
    const card = page.getByRole("article", { name: /23:30 – 23:45, Testfall 08/ });
    await card.getByRole("button", { name: "Heute machen" }).click();
    const move = card.getByRole("form", { name: "Einsatz auf heute verschieben" });
    // Fixed late slot, so the test does not depend on the hour it runs (the prefill is asserted in the first test).
    await move.getByLabel("Von").fill("23:30");
    await move.getByLabel("Bis").fill("23:45");
    await move.getByLabel("Grund der Verschiebung").fill("Synthetisch: heute statt später");
    await move.getByRole("button", { name: "Auf heute verschieben" }).click();
    const notice = page.getByTestId("moved-released");
    await expect(notice).toHaveText(RELEASED_ON_MOVE);
    await expect(notice).toHaveAttribute("role", "status");
    await expect(notice).toHaveAttribute("data-tone", "attention");
    const movedCard = page.getByRole("article", { name: /23:30 – 23:45, Testfall 08/ });
    await expect(movedCard).toHaveCount(1);
    // VIS1-3f (UXR-34): the element that receives focus (VIS1-3e: the moved card) is described by the release notice.
    await expect(movedCard).toBeFocused();
    await expect(movedCard).toHaveAccessibleDescription(/Der Einsatz ist jetzt offen im Team\./);

    const width = await page.evaluate(() => document.documentElement.scrollWidth);
    expect(width).toBeLessThanOrEqual(PHONE.width);

    // VIS1-3g (UXR-35): the notice belongs to the move; the address does not carry it, so a reload no longer shows it.
    await expect(page).not.toHaveURL(/verschoben=|offen=/);
    await page.reload();
    await expect(page.getByRole("article", { name: /23:30 – 23:45, Testfall 08/ })).toHaveCount(1);
    await expect(page.getByTestId("moved-released")).toHaveCount(0);
    await expect(page.getByTestId("moved-to-today")).toHaveCount(0);

    // Clean up: the released visit would stay open in the team today (uncovered, possibly overdue) and reach the later
    // specs' screens as a signal; the team removes it with a reason (existing J3 route).
    await page.goto("/team");
    const upcoming = page.getByRole("article", { name: /Fall Testfall 08/ }).getByRole("list", { name: "Geplante Einsätze" });
    const item = upcoming.getByRole("listitem").filter({ hasText: "23:30–23:45" });
    await item.getByRole("button", { name: "Entfernen" }).click();
    const remove = item.getByRole("form", { name: "Einsatz entfernen" });
    await remove.getByLabel("Grund").fill("Synthetisch: Testeinsatz entfernt");
    await remove.getByRole("button", { name: "Entfernen" }).click();
    await expect(upcoming.getByRole("listitem").filter({ hasText: "23:30–23:45" })).toHaveCount(0);
  });
});
