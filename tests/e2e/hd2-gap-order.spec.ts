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
