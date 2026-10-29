import { expect, test, type Page } from "@playwright/test";
import { overlapNote, sameSlotInfo } from "@/features/visits/overlap-rules";

// VIS2 (ADR-121; brief VIS2 with VIS2-5; `cra` CGR-97; `uxa` wording): a second visit of the same client at an
// overlapping time is a fact before saving (planning form and "Heute machen"), re-read as the times change, never a
// refusal; a save the form had not re-read states the server's check after it; two such cards have different names.
// Phone 390 × 844, synthetic seed account. This spec owns its slots (CGR-96): day +53 at 19:07–19:37 (no other spec
// plans that day), and today's slots chosen at its start where Testfall 08 has no visit (`todaySlots`).
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

const hhmm = (m: number) => `${String(Math.floor(m / 60)).padStart(2, "0")}:${String(m % 60).padStart(2, "0")}`;

/**
 * Today's slots for this spec, chosen from what is on today's /field for Testfall 08 when it starts (the suite runs
 * serially, workers: 1): an existing visit [s, s+30), the move target [s+5, s+35) and a free slot of 30 minutes, none
 * overlapping another Testfall 08 visit of today. Minutes off the 5-minute grid. Owns its slots (CGR-96).
 */
async function todaySlots(page: Page) {
  await page.goto("/field");
  const labels = await page.getByRole("article", { name: /Testfall 08/ }).evaluateAll((els) =>
    els.map((el) => el.getAttribute("aria-label") ?? ""));
  const busy = labels.flatMap((l) => {
    const m = /(\d{2}):(\d{2})(?: – (\d{2}):(\d{2}))?/.exec(l);
    if (!m) return [[0, 1440]];
    const a = Number(m[1]) * 60 + Number(m[2]);
    const b = m[3] ? Number(m[3]) * 60 + Number(m[4]) : 1440;
    return [[a, b > a ? b : 1440]];
  });
  const free = (a: number, b: number) => busy.every(([x, y]) => b <= x || a >= y);
  // Later today first (a past planned visit would raise an overdue signal for the specs after this one), then earlier.
  const [h, min] = new Date().toLocaleTimeString("en-GB", { timeZone: "Europe/Zurich", hour12: false }).split(":").map(Number);
  const now = h * 60 + min;
  const all = Array.from({ length: 23 }, (_, i) => i * 60 + 7);
  const starts = [...all.filter((m) => m >= now + 10), ...all.filter((m) => m < now + 10)];
  const s = starts.find((m) => free(m, m + 35));
  const f = starts.find((m) => free(m, m + 30) && (m + 30 <= (s ?? 0) || m >= (s ?? 0) + 35));
  if (s === undefined || f === undefined) throw new Error("no free Testfall 08 slot today");
  return {
    existing: { start: hhmm(s), end: hhmm(s + 30) },
    target: { start: hhmm(s + 5), end: hhmm(s + 35) },
    free: { start: hhmm(f), end: hhmm(f + 30) },
  };
}

async function plan(page: Page, day: string, start: string, end: string, expectNote: string | null) {
  const caseCard = page.getByRole("article", { name: /Fall Testfall 08/ });
  await caseCard.getByRole("button", { name: "Einsatz planen" }).click();
  const form = caseCard.getByRole("form", { name: "Einsatz planen" });
  await form.getByLabel("Datum").fill(day);
  await form.getByLabel("Von").fill(start);
  await form.getByLabel("Bis").fill(end);
  await form.getByLabel("A", { exact: true }).fill("30");
  const note = form.getByTestId("overlap-note");
  if (expectNote) {
    // VIS2-1: one `info` sentence before saving; no extra field, nothing to confirm in addition.
    await expect(note).toHaveText(expectNote);
    await expect(note).toHaveAttribute("data-tone", "info");
  } else {
    await expect(note).toHaveText("");
  }
  await form.getByRole("button", { name: "Einsatz speichern" }).click();
  // The form closes only on a saved plan (a refusal keeps it open with the error).
  await expect(caseCard.getByRole("form", { name: "Einsatz planen" })).toHaveCount(0);
}

test.describe("VIS2 at 390 × 844", () => {
  test.use({ viewport: PHONE });

  test("VIS2: overlap shown before saving, saved anyway, cards told apart, and the move onto a visit completes", async ({ page }) => {
    const day = zurichDay(53);
    const today = zurichDay(0);
    const futureVisit = { overlap: true, timeStart: "19:07", timeEnd: "19:37" };
    await signIn(page, "pflege.test@navora.test");
    const slots = await todaySlots(page);
    const todayVisit = { overlap: true, timeStart: slots.existing.start, timeEnd: slots.existing.end };
    await page.goto("/team");

    // Planning: the first visit has no overlap; the second, same slot, shows the fact and is saved (never refused).
    await plan(page, day, "19:07", "19:37", null);
    await plan(page, day, "19:07", "19:37", overlapNote(day, futureVisit, today));
    await expect(page.getByRole("article", { name: /Fall Testfall 08/ }).getByRole("list", { name: "Geplante Einsätze" }))
      .toContainText("19:07–19:37");
    // Today's visit the move will land on.
    await plan(page, today, slots.existing.start, slots.existing.end, null);

    // VIS2-3: the two same-slot cards have different accessible names and a visible line each.
    await page.goto(`/field?datum=${day}`);
    const cards = page.getByRole("article", { name: /19:07 – 19:37, Testfall 08/ });
    await expect(cards).toHaveCount(2);
    const names = await cards.evaluateAll((els) => els.map((el) => el.getAttribute("aria-label")));
    expect(new Set(names).size).toBe(2);
    await expect(cards.nth(0).getByTestId("same-slot-line")).toHaveText(sameSlotInfo({ index: 1, total: 2 }, "du"));
    await expect(cards.nth(1).getByTestId("same-slot-line")).toHaveText(sameSlotInfo({ index: 2, total: 2 }, "du"));
    await expect(cards.nth(0).getByTestId("same-slot-line")).toHaveAttribute("data-tone", "info");

    // VIS2-5 (1): "Heute machen" on a free slot shows nothing; onto today's visit the sentence appears; back, it goes.
    await cards.nth(0).getByRole("button", { name: "Heute machen" }).click();
    const move = page.getByRole("form", { name: "Einsatz auf heute verschieben" });
    const note = move.getByTestId("overlap-note");
    await move.getByLabel("Von").fill(slots.free.start);
    await move.getByLabel("Bis").fill(slots.free.end);
    await expect(note).toHaveText("");
    await move.getByLabel("Von").fill(slots.target.start);
    await move.getByLabel("Bis").fill(slots.target.end);
    await expect(note).toHaveText(overlapNote(today, todayVisit, today) ?? "");
    await expect(note).toHaveAttribute("data-tone", "info");
    await expect(note).toHaveAttribute("role", "status");
    await expect(move.getByRole("button", { name: "Auf heute verschieben" })).toHaveAttribute("aria-describedby", /overlap-today-/);
    await move.getByLabel("Von").fill(slots.free.start);
    await move.getByLabel("Bis").fill(slots.free.end);
    await expect(note).toHaveText("");

    // VIS2-5 (2): saved onto the overlap before the form re-read it: the move completes and the notice states it.
    await move.getByLabel("Grund der Verschiebung").fill("Synthetisch: heute erledigen");
    await move.getByLabel("Von").fill(slots.target.start);
    await move.getByLabel("Bis").fill(slots.target.end);
    await move.getByRole("button", { name: "Auf heute verschieben" }).click();
    await expect(page.getByTestId("moved-to-today")).toBeVisible();
    await expect(page.getByTestId("overlap-after-save")).toHaveText(overlapNote(today, todayVisit, today) ?? "");
    await expect(page.getByRole("article", { name: `${slots.target.start} – ${slots.target.end}, Testfall 08` })).toHaveCount(1);
    await expect(page.getByRole("article", { name: `${slots.existing.start} – ${slots.existing.end}, Testfall 08` })).toHaveCount(1);

    const width = await page.evaluate(() => document.documentElement.scrollWidth);
    expect(width).toBeLessThanOrEqual(PHONE.width);
  });
});
