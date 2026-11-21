import { expect, test, type Locator, type Page } from "@playwright/test";
import { zurichDay } from "./support/durchgang-time";
import { addDays, weekStart } from "@/features/home-plan/rules";

// HD-2 e2e (brief docs/agents/briefs/HD.md §3, §3a, §6 (2); migration 0162): a gap of the home becomes a prepared
// external order with one tap, is checked and sent through the one order path, and its state comes back into week,
// month and /order (one source). A sent gap cannot be ordered twice; a discarded draft leaves the gap. Never «Gedeckt»
// without a confirmed person. Synthetic local-only account `kundebs.test` (lead of «Testheim Rhein», client member).
// Weeks six and seven ahead, Thursday: no example rows and no collision with hd1-home-plan.spec.ts (weeks 3–5, Wed).
const PASSWORD = "navora-local-only";
const HOME = "kundebs.test@navora.test";

async function signIn(page: Page, email: string) {
  await page.context().clearCookies();
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

async function noSidewaysScroll(page: Page) {
  expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(0);
}

function cell(page: Page, date: string, station: string, shift: string): Locator {
  return page.locator(`[data-testid="heim-day"][data-date="${date}"] [data-testid="heim-cell"][data-station="${station}"][data-shift="${shift}"]`);
}

async function ensureExample(page: Page) {
  await page.goto("/heim");
  await expect(page.getByRole("heading", { name: "Dienstplanung" })).toBeVisible();
  if (await page.getByTestId("heim-empty").isVisible()) {
    await page.getByTestId("heim-load-example").click();
    await expect(page.getByTestId("heim-message")).toHaveText("Beispieldaten geladen (synthetisch).");
  }
}

for (const width of [1440, 390]) {
  test(`HD-2 at ${width} px: gap → prepared order → sent → status back in week, month and /order; no double order`, async ({ page }) => {
    test.setTimeout(120_000);
    await page.setViewportSize({ width, height: 900 });
    const thu = addDays(weekStart(addDays(zurichDay(), width === 1440 ? 42 : 49)), 3);

    await signIn(page, HOME);
    await ensureExample(page);
    await page.goto(`/heim?ansicht=woche&datum=${thu}`);
    const early = cell(page, thu, "Rhein 2", "F");
    await expect(early).toHaveAttribute("data-status", "gap");
    await expect(early.getByTestId("heim-cell-status")).toHaveText("0 von 3 · Lücke: 3 fehlt, 1 HF fehlt");

    // One tap from the gap to the review screen (E).
    await early.getByTestId("heim-prepare-order").click();
    await expect(page.getByTestId("heim-message")).toHaveText("Auftrag vorbereitet, noch nicht gesendet. Bitte prüfen und senden.");
    const review = page.getByTestId("heim-order-review");
    await expect(review.getByTestId("heim-order-review-shift")).toContainText("Rhein 2 · Früh 07:00–15:30");
    await expect(review.getByTestId("heim-order-review-grade")).toHaveText("HF (fehlt in diesem Dienst)");
    await noSidewaysScroll(page);

    // The week already shows the draft; it does not fill the gap.
    await page.goto(`/heim?ansicht=woche&datum=${thu}`);
    await expect(early.getByTestId("heim-cell-order")).toHaveAttribute("data-code", "E");
    await expect(early.getByTestId("heim-cell-order-headline")).toHaveText("Externer Auftrag: Auftrag vorbereitet, nicht gesendet");
    await expect(early).toHaveAttribute("data-status", "gap");
    await expect(early.getByTestId("heim-prepare-order")).toHaveCount(0);

    // Check and send: postcode of the home and one activity; the preview reads the order sentence.
    await early.getByTestId("heim-order-review-link").click();
    const postcode = review.getByTestId("heim-order-postcode");
    if ((await postcode.inputValue()) === "") await postcode.selectOption("4102");
    await review.locator('[data-testid="heim-order-tag"][value="A1"]').check();
    await review.getByTestId("heim-order-check").click();
    await expect(review.getByTestId("heim-order-sentence")).toContainText("Schichtauftrag · HF · ");
    await review.getByTestId("heim-order-send").click();
    await expect(page.getByTestId("heim-message")).toHaveText("Auftrag gesendet: Angebot an alle passenden Teams gleichzeitig.");

    // Status back (A or K, depending on which synthetic teams can take it); never «Gedeckt», still a gap.
    await page.goto(`/heim?ansicht=woche&datum=${thu}`);
    const order = early.getByTestId("heim-cell-order");
    await expect(order).toHaveAttribute("data-code", /^[AK]$/);
    const code = await order.getAttribute("data-code");
    const orderId = await order.getAttribute("data-order-id");
    expect(orderId).toMatch(/^[0-9a-f-]{36}$/);
    await expect(early.getByTestId("heim-cell-order-headline")).toHaveText(
      code === "A" ? "Externer Auftrag: Angebot versandt · noch nicht gedeckt" : "Externer Auftrag: Nicht gedeckt");
    await expect(early).toHaveAttribute("data-status", "gap");
    await expect(early.getByTestId("heim-prepare-order")).toHaveCount(0);  // double-order lock
    await noSidewaysScroll(page);

    // The month reads the same letter for the day.
    await page.goto(`/heim?ansicht=monat&datum=${thu}`);
    await expect(page.locator(`[data-testid="heim-month-orders"][data-date="${thu}"]`)).toContainText(code!);
    await noSidewaysScroll(page);

    // /order («Externe Aufträge» of the client account) reads the same state from the same source.
    await page.goto("/order");
    // This very order, by its id from the home's cell (other specs order HF at 07:00 on the same calendar day).
    const item = page.getByTestId("client-orders").locator(`li[data-order-id="${orderId}"]`);
    await expect(item).toHaveCount(1);
    await expect(item.getByTestId("order-cover-state")).toHaveText(code === "A" ? /^Noch nicht gedeckt · Beginn / : /^Nicht gedeckt · Beginn /);
  });
}

test("HD-2: a discarded draft leaves the gap and can be prepared again", async ({ page }) => {
  test.setTimeout(90_000);
  await page.setViewportSize({ width: 1440, height: 900 });
  const thu = addDays(weekStart(addDays(zurichDay(), 56)), 3);
  await signIn(page, HOME);
  await ensureExample(page);
  await page.goto(`/heim?ansicht=woche&datum=${thu}`);
  const late = cell(page, thu, "Rhein 2", "S");
  await expect(late).toHaveAttribute("data-status", "gap");
  await late.getByTestId("heim-prepare-order").click();
  await page.getByTestId("heim-order-discard").click();
  await expect(page.getByTestId("heim-message")).toHaveText("Entwurf verworfen. Die Lücke bleibt.");
  await page.goto(`/heim?ansicht=woche&datum=${thu}`);
  await expect(late.getByTestId("heim-cell-order")).toHaveCount(0);
  await expect(late).toHaveAttribute("data-status", "gap");
  await expect(late.getByTestId("heim-prepare-order")).toHaveCount(1);
});

// HD-2 slice 5 (migration 0163): «Auftrag zurückziehen» on a sent order (A or K) ends the offer; the cell is a gap
// without an order and can be ordered again; /order reads «Zurückgezogen». Week nine ahead, Thursday (own day).
test("HD-2 at 390 px: a sent order is withdrawn; the gap stays and can be ordered again", async ({ page }) => {
  test.setTimeout(120_000);
  await page.setViewportSize({ width: 390, height: 900 });
  const thu = addDays(weekStart(addDays(zurichDay(), 63)), 3);
  await signIn(page, HOME);
  await ensureExample(page);
  await page.goto(`/heim?ansicht=woche&datum=${thu}`);
  const early = cell(page, thu, "Rhein 2", "F");
  await expect(early).toHaveAttribute("data-status", "gap");
  await early.getByTestId("heim-prepare-order").click();
  const review = page.getByTestId("heim-order-review");
  const postcode = review.getByTestId("heim-order-postcode");
  if ((await postcode.inputValue()) === "") await postcode.selectOption("4102");
  await review.locator('[data-testid="heim-order-tag"][value="A1"]').check();
  await review.getByTestId("heim-order-check").click();
  await review.getByTestId("heim-order-send").click();
  await expect(page.getByTestId("heim-message")).toHaveText("Auftrag gesendet: Angebot an alle passenden Teams gleichzeitig.");

  await page.goto(`/heim?ansicht=woche&datum=${thu}`);
  const order = early.getByTestId("heim-cell-order");
  await expect(order).toHaveAttribute("data-code", /^[AK]$/);
  const orderId = await order.getAttribute("data-order-id");
  expect(orderId).toMatch(/^[0-9a-f-]{36}$/);
  await order.getByTestId("heim-order-withdraw").click();
  await expect(page.getByTestId("heim-message")).toHaveText("Auftrag zurückgezogen. Kein Team erhält das Angebot mehr; die Lücke bleibt.");
  await page.goto(`/heim?ansicht=woche&datum=${thu}`);
  await expect(early.getByTestId("heim-cell-order")).toHaveCount(0);
  await expect(early).toHaveAttribute("data-status", "gap");
  await expect(early.getByTestId("heim-prepare-order")).toHaveCount(1);
  await noSidewaysScroll(page);

  await page.goto("/order");
  const item = page.getByTestId("client-orders").locator(`li[data-order-id="${orderId}"]`);
  await expect(item.getByTestId("order-cover-state")).toHaveText(/^Zurückgezogen · Beginn /);
  await expect(item).not.toContainText("läuft wieder");
});

// HD-2 slice 6: the register path of brief HD.md §6 (2) in one browser run, fixed rules only (no AI). The home sends a
// gap (Grundpflege C1 only, so Testteam Basel can take it; prefilled tags of earlier orders of the station are cleared);
// pflegebs takes it for Testteam Basel naming kolleginbs → the home reads T (still a gap, no withdrawal); kolleginbs
// confirms → G in week and month and «Gedeckt» on /order, the HF counts; kolleginbs records an absence over that day on
// /field → the take is released (CGR-223 (c), new round with the releasing team) → N with the next action in week and
// month, «Nicht mehr gedeckt» on /order, nowhere «Gedeckt»; /team (pflegebs) and /field (kolleginbs) say the same.
// Week eleven ahead, Thursday: weekStart(70)+3 is never in a week used above (weeks 6–9) or by the bk specs (30–37).
const deDate = (iso: string) => iso.split("-").reverse().join(".");
const NOT_COVERED_WORD = /(^|[:·]\s*)Gedeckt/;

test("HD-2 register path: gap → order → team takes (T) → person confirms (G) → her absence → N everywhere, never «Gedeckt»", async ({ page }) => {
  test.setTimeout(240_000);
  await page.setViewportSize({ width: 1440, height: 900 });
  const thu = addDays(weekStart(addDays(zurichDay(), 70)), 3);
  const fri = addDays(thu, 1);
  const when = `${deDate(thu)} 07:00`;
  const week = `/heim?ansicht=woche&datum=${thu}`;

  // 1. The home prepares and sends the gap of Rhein 2, early shift.
  await signIn(page, HOME);
  await ensureExample(page);
  await page.goto(week);
  const early = cell(page, thu, "Rhein 2", "F");
  await expect(early).toHaveAttribute("data-status", "gap");
  await early.getByTestId("heim-prepare-order").click();
  const review = page.getByTestId("heim-order-review");
  await expect(review.getByTestId("heim-order-review-grade")).toHaveText("HF (fehlt in diesem Dienst)");
  await review.getByTestId("heim-order-postcode").selectOption("4051");
  const tags = review.getByTestId("heim-order-tag");
  for (let i = 0; i < await tags.count(); i++) await tags.nth(i).uncheck();
  await review.locator('[data-testid="heim-order-tag"][value="C1"]').check();
  await review.getByTestId("heim-order-check").click();
  await review.getByTestId("heim-order-send").click();
  await expect(page.getByTestId("heim-message")).toHaveText("Auftrag gesendet: Angebot an alle passenden Teams gleichzeitig.");
  await page.goto(week);
  const order = early.getByTestId("heim-cell-order");
  await expect(order).toHaveAttribute("data-code", "A");
  const orderId = await order.getAttribute("data-order-id");
  expect(orderId).toMatch(/^[0-9a-f-]{36}$/);

  // 2. pflegebs takes it for Testteam Basel and names her colleague (BK-c2): a take awaiting confirmation.
  await signIn(page, "pflegebs.test@navora.test");
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/team");
  const offer = page.getByTestId("shift-offer-card").filter({ hasText: when }).last();
  await expect(offer.getByTestId("shift-offer-tag")).toHaveText("Neues Angebot");
  await offer.getByRole("radio", { name: "Kollegin B." }).check();
  await offer.getByRole("button", { name: "Übernehmen mit Kollegin B." }).click();
  await expect(page.getByTestId("shift-offer-card").filter({ hasText: when }).last().getByTestId("shift-offer-line").first())
    .toHaveText("Es geht: Kollegin B. · Bestätigung ausstehend");
  await noSidewaysScroll(page);

  // 3. The home reads T: the team took it, the person has not confirmed; still a gap, no withdrawal offered.
  await signIn(page, HOME);
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto(week);
  await expect(order).toHaveAttribute("data-code", "T");
  await expect(early.getByTestId("heim-cell-order-headline")).toHaveText("Externer Auftrag: Team hat übernommen · Person bestätigt noch");
  await expect(early).toHaveAttribute("data-status", "gap");
  await expect(early.getByTestId("heim-order-withdraw")).toHaveCount(0);
  await expect(early).not.toContainText(NOT_COVERED_WORD);

  // 4. kolleginbs confirms on /team.
  await signIn(page, "kolleginbs.test@navora.test");
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/team");
  const named = page.getByTestId("shift-offer-card").filter({ hasText: when }).last();
  await expect(named.getByTestId("shift-offer-tag")).toHaveText("Für dich eingeteilt");
  await named.getByRole("button", { name: "Bestätigen" }).click();
  await expect(page.getByTestId("shift-offer-card").filter({ hasText: when }).last().getByTestId("shift-offer-line"))
    .toHaveText(["Du bist für diese Schicht eingeteilt."]);

  // 5. G in week and month; the HF is no longer missing; /order reads «Gedeckt»; no withdrawal of a confirmed person.
  await signIn(page, HOME);
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto(week);
  await expect(order).toHaveAttribute("data-code", "G");
  await expect(early.getByTestId("heim-cell-order-headline")).toHaveText("Externer Auftrag: Gedeckt · Person bestätigt, geprüft für HF");
  await expect(early.getByTestId("heim-cell-status")).toHaveText("0 + 1 extern von 3 · Lücke: 2 fehlt");
  await expect(early.getByTestId("heim-order-withdraw")).toHaveCount(0);
  await page.goto(`/heim?ansicht=monat&datum=${thu}`);
  await expect(page.locator(`[data-testid="heim-month-orders"][data-date="${thu}"]`)).toContainText("G");
  await page.goto("/order");
  const item = page.getByTestId("client-orders").locator(`li[data-order-id="${orderId}"]`);
  await expect(item.getByTestId("order-cover-state")).toHaveText("Gedeckt · Person benannt, geprüft für HF");

  // 6. kolleginbs records an absence over that day on /field (the way back on her card); her take card ends.
  await signIn(page, "kolleginbs.test@navora.test");
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto(`/field?datum=${thu}`);
  const take = page.getByRole("article", { name: /07:00 – 15:30/ });
  await expect(take).toHaveCount(1);
  const absence = page.getByTestId("absence");
  await absence.getByTestId("absence-open").click();
  const absenceForm = absence.getByRole("form", { name: "Abwesenheit erfassen" });
  await absenceForm.getByLabel("Von", { exact: true }).fill(thu);
  await absenceForm.getByLabel("Bis", { exact: true }).fill(fri);
  await absenceForm.getByTestId("absence-save").click();
  await expect(absenceForm).toHaveCount(0);
  await page.goto(`/field?datum=${thu}`);
  const ended = page.getByRole("article", { name: /07:00 – 15:30/ });
  await expect(ended.getByTestId("take-ended")).toHaveText(
    "Die Übernahme gilt nicht mehr: du hast für diese Zeit eine Abwesenheit erfasst. Das Angebot geht wieder an alle passenden Teams.",
  );
  await noSidewaysScroll(page);

  // 7. /team (pflegebs): the same fact, the order is offered again with the release named; no «Übernommen».
  await signIn(page, "pflegebs.test@navora.test");
  await page.goto("/team");
  const again = page.getByTestId("shift-offer-card").filter({ hasText: when }).last();
  await expect(again.getByTestId("shift-offer-tag")).toHaveText("Neues Angebot");
  await expect(again.getByTestId("shift-offer-release")).toHaveText("Nicht mehr gedeckt: Kollegin B. erfüllt die Bedingungen für diese Schicht nicht mehr.");
  await expect(again).not.toContainText("Es geht: Kollegin B.");
  await noSidewaysScroll(page);

  // 8. The home: N with the next action in week and month, the HF is missing again; /order «Nicht mehr gedeckt».
  await signIn(page, HOME);
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto(week);
  await expect(order).toHaveAttribute("data-code", "N");
  await expect(early.getByTestId("heim-cell-order-headline")).toHaveText("Externer Auftrag: Nicht mehr gedeckt · Angebot läuft wieder");
  await expect(early.getByTestId("heim-cell-order-next")).toHaveText("Nächste Handlung: eine zulässige eigene Person einteilen oder den Auftrag zurückziehen.");
  await expect(early.getByTestId("heim-cell-status")).toHaveText("0 von 3 · Lücke: 3 fehlt, 1 HF fehlt");
  await expect(early).toHaveAttribute("data-status", "gap");
  await expect(early.getByTestId("heim-order-withdraw")).toHaveCount(1);
  await expect(early).not.toContainText(NOT_COVERED_WORD);
  await page.goto(`/heim?ansicht=monat&datum=${thu}`);
  await expect(page.locator(`[data-testid="heim-month-orders"][data-date="${thu}"]`)).toContainText("N");
  await page.goto("/order");
  await expect(item.getByTestId("order-cover-state")).toHaveText(/^Nicht mehr gedeckt · /);
  await expect(item).not.toContainText(NOT_COVERED_WORD);
});

// UXR-269 (#1656): «Senden» sends exactly what the boxes show. A box changed after «Prüfen» sends nothing and asks to
// check again; the line next to «Senden» names every activity that is sent, and the same activities are ticked. On the
// next order of the station the prefill hint is shown before any tap, also when the preview already ran. Fixed rules,
// no AI. Weeks twelve (1440) and thirteen (390) ahead, Thursday and Friday: no day used above (weeks 6–11) or by the
// hd1 (weeks 3–5) and bk specs (30–37 days).
const summaryCodes = (s: string) => [...s.matchAll(/(?:Tätigkeiten: |, )([A-Z][A-Z0-9]{0,5}) · /g)].map((m) => m[1]).sort();
async function tickedCodes(review: Locator): Promise<string[]> {
  return (await review.locator('[data-testid="heim-order-tag"]:checked').evaluateAll(
    (els) => els.map((e) => (e as HTMLInputElement).value))).sort();
}

for (const [width, height, days] of [[1440, 900, 77], [390, 844, 84]] as const) {
  test(`UXR-269 at ${width} px: a box changed after «Prüfen» is not sent; the summary names what is sent; prefill hint`, async ({ page }) => {
    test.setTimeout(150_000);
    await page.setViewportSize({ width, height });
    const thu = addDays(weekStart(addDays(zurichDay(), days)), 3);
    const fri = addDays(thu, 1);
    await signIn(page, HOME);
    await ensureExample(page);
    await page.goto(`/heim?ansicht=woche&datum=${thu}`);
    const early = cell(page, thu, "Rhein 2", "F");
    await expect(early).toHaveAttribute("data-status", "gap");
    await early.getByTestId("heim-prepare-order").click();
    const review = page.getByTestId("heim-order-review");
    const postcode = review.getByTestId("heim-order-postcode");
    if ((await postcode.inputValue()) === "") await postcode.selectOption("4102");
    const tags = review.getByTestId("heim-order-tag");
    for (let i = 0; i < await tags.count(); i++) await tags.nth(i).uncheck();
    await review.locator('[data-testid="heim-order-tag"][value="A1"]').check();
    await review.getByTestId("heim-order-check").click();
    const summary = review.getByTestId("heim-order-send-summary");
    await expect(summary).toContainText("Wird gesendet: HF · ");
    expect(summaryCodes(await summary.innerText())).toEqual(["A1"]);
    // After a «Prüfen» the prefill hint is gone (the lead has checked).
    await expect(review.getByTestId("heim-order-prefill-hint")).toHaveCount(0);

    // Change the activities after «Prüfen» and tap «Senden» without checking again: nothing is sent.
    await review.locator('[data-testid="heim-order-tag"][value="A1"]').uncheck();
    await review.locator('[data-testid="heim-order-tag"][value="C1"]').check();
    await review.getByTestId("heim-order-send").click();
    await expect(page.getByTestId("heim-message")).toHaveText(
      "Geändert nach dem Prüfen: Es wurde nichts gesendet. Bitte die Angaben unten erneut prüfen.");
    // The screen now checks what was shown: C1 ticked, A1 not, and the summary names exactly the ticked boxes.
    expect(await tickedCodes(review)).toEqual(["C1"]);
    expect(summaryCodes(await review.getByTestId("heim-order-send-summary").innerText())).toEqual(["C1"]);
    await noSidewaysScroll(page);

    // The week still reads the draft (E): no order went to any team.
    await page.goto(`/heim?ansicht=woche&datum=${thu}`);
    await expect(early.getByTestId("heim-cell-order")).toHaveAttribute("data-code", "E");

    // Check C1 and send: the order goes out with what the screen shows.
    await early.getByTestId("heim-order-review-link").click();
    if ((await postcode.inputValue()) === "") await postcode.selectOption("4102");
    for (let i = 0; i < await tags.count(); i++) await tags.nth(i).uncheck();
    await review.locator('[data-testid="heim-order-tag"][value="C1"]').check();
    await review.getByTestId("heim-order-check").click();
    expect(summaryCodes(await review.getByTestId("heim-order-send-summary").innerText())).toEqual(await tickedCodes(review));
    await review.getByTestId("heim-order-send").click();
    await expect(page.getByTestId("heim-message")).toHaveText("Auftrag gesendet: Angebot an alle passenden Teams gleichzeitig.");
    await page.goto(`/heim?ansicht=woche&datum=${thu}`);
    await expect(early.getByTestId("heim-cell-order")).toHaveAttribute("data-code", /^[AK]$/);

    // Next order of the station (postcode now stored): the prefill hint is shown before any tap, even if the preview
    // already ran; if «Senden» is offered at once, its summary names exactly the ticked (prefilled) boxes.
    await page.goto(`/heim?ansicht=woche&datum=${fri}`);
    const next = cell(page, fri, "Rhein 2", "F");
    await expect(next).toHaveAttribute("data-status", "gap");
    await next.getByTestId("heim-prepare-order").click();
    await expect(review.getByTestId("heim-order-prefill-hint")).toHaveText("Vorbelegt wie beim letzten Auftrag dieser Station; bitte prüfen.");
    expect((await tickedCodes(review)).length).toBeGreaterThan(0);
    if (await review.getByTestId("heim-order-send-summary").count()) {
      expect(summaryCodes(await review.getByTestId("heim-order-send-summary").innerText())).toEqual(await tickedCodes(review));
    }
    await noSidewaysScroll(page);
    await review.getByTestId("heim-order-discard").click();
    await expect(page.getByTestId("heim-message")).toHaveText("Entwurf verworfen. Die Lücke bleibt.");
  });
}
