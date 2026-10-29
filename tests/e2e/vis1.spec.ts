import { expect, test, type Page } from "@playwright/test";
import { formatShortDate, futureDayNote } from "@/features/field/rules";

// VIS1 (ADR-111, `cra` CGR-87): field actions happen on the visit's day. Phone 390 × 844, synthetic seed accounts.
// VIS1-4:  on a day after today no "Einsatz starten" is shown; the VIS1-3 sentence is shown once, styled `info`, and no
//          card of that day has a filled button (VIS1-3a).
// VIS1-3b: "Heute machen" opens one confirmation with today's date and the card's times, an empty required reason;
//          cancel leaves the visit unchanged; confirm moves it to today (existing J3 move, `moved` row), not started.
// The visit is planned here, nine days ahead at 22:00 (no other test uses that day or, on today, that slot).
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
    const day = zurichDay(9);
    const today = zurichDay(0);
    const reason = "Synthetisch: Klientin bittet um heute";
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
    await expect(note).toHaveText(futureDayNote(day));
    await expect(note).toHaveAttribute("data-tone", "info");
    await expect(page.getByText(futureDayNote(day), { exact: true })).toHaveCount(1);
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

    // VIS1-3b: one confirmation, today and the card's times prefilled, the reason empty and required; cancel changes nothing.
    await card.getByRole("button", { name: "Heute machen" }).click();
    const move = card.getByRole("form", { name: "Einsatz auf heute verschieben" });
    await expect(move.getByTestId("move-to-today-date")).toHaveText(formatShortDate(today));
    await expect(move.getByLabel("Von")).toHaveValue("22:00");
    await expect(move.getByLabel("Bis")).toHaveValue("22:30");
    const reasonField = move.getByLabel("Grund der Verschiebung");
    await expect(reasonField).toHaveValue("");
    await expect(reasonField).toHaveAttribute("required", "");
    await move.getByRole("button", { name: "Abbrechen" }).click();
    await expect(move).toHaveCount(0);
    await page.reload();
    await expect(page.getByRole("article", { name: /22:00 – 22:30, Testfall 08/ })).toHaveCount(1);

    // Confirm with a typed reason: she is on today's view, the visit planned there, "Einsatz starten" its own tap.
    await page.getByRole("article", { name: /22:00 – 22:30, Testfall 08/ }).getByRole("button", { name: "Heute machen" }).click();
    const confirm = page.getByRole("form", { name: "Einsatz auf heute verschieben" });
    await confirm.getByLabel("Grund der Verschiebung").fill(reason);
    await confirm.getByRole("button", { name: "Auf heute verschieben" }).click();
    await page.waitForURL(/\/field$/);
    const moved = page.getByRole("article", { name: /22:00 – 22:30, Testfall 08/ });
    await expect(moved).toHaveCount(1);
    await expect(moved.getByTestId("visit-status")).toHaveText("Geplant");
    await expect(moved.getByRole("button", { name: "Einsatz starten" })).toBeVisible();
    await expect(moved.getByRole("region", { name: "Erfasste Zeit" })).toHaveCount(0);   // no start recorded
    await expect(page.getByTestId("future-day-note")).toHaveCount(0);

    await page.goto(`/field?datum=${day}`);
    await expect(page.getByRole("article", { name: /22:00 – 22:30, Testfall 08/ })).toHaveCount(0);

    // The move is on record with its reason (J3 `moved` row; its audit row is asserted in pgTAP 089).
    await page.goto("/team");
    const upcoming = page.getByRole("article", { name: /Fall Testfall 08/ }).getByRole("list", { name: "Geplante Einsätze" });
    await expect(upcoming.getByRole("listitem").filter({ hasText: "22:00–22:30" })).toContainText(`Verschoben von dir: ${reason}`);

    const width = await page.evaluate(() => document.documentElement.scrollWidth);
    expect(width).toBeLessThanOrEqual(PHONE.width);
  });
});
