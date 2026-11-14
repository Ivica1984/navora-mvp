import { expect, test, type Page } from "@playwright/test";
import { zurichDay } from "./support/durchgang-time";

// BK-a (brief docs/agents/briefs/BK.md; ADR-194): the client's order, form → summary → «Bestätigen & Absenden».
// Synthetic local-only account `kundebs.test` (supabase/seed.sql, client of «Testheim Rhein (synthetisch)», org S).
// The date is ten (390 px) or twelve (1440 px) Zurich days ahead (the e2e database runs on the real clock); no clock
// change falls in that window in November.
// Every run adds one synthetic order; no assertion counts orders.
const CLIENT = "kundebs.test@navora.test";
const PASSWORD = "navora-local-only";

async function signIn(page: Page, email: string, landing: RegExp) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(landing);
}

const deDate = (iso: string) => iso.split("-").reverse().join(".");

for (const width of [390, 1440]) {
  test(`at ${width} px a client lands on /order, sees the summary and confirms a night order as one order`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 });
    await signIn(page, CLIENT, /\/order$/);
    await expect(page.getByRole("heading", { name: "Auftrag erfassen" })).toBeVisible();

    const form = page.getByRole("form", { name: "Auftrag" });
    // One day per width (UXR-199 counts the orders of that day and time).
    const day = zurichDay(Date.now(), width === 390 ? 10 : 12);
    await form.getByLabel(/^Datum/).fill(deDate(day));
    await expect(form.getByTestId("order-date")).toContainText(deDate(day));
    await form.getByLabel("Beginn", { exact: true }).fill("22:00");
    await form.getByLabel("Ende", { exact: true }).fill("07:00");
    await form.getByLabel("Einsatzort (Postleitzahl)").selectOption("4102");
    await form.getByRole("radio", { name: "FaGe", exact: true }).check();
    await form.getByRole("checkbox", { name: "Vitalzeichen, Gewicht", exact: true }).check();
    await form.getByRole("button", { name: "Weiter zur Zusammenfassung" }).click();

    const summary = page.getByTestId("order-summary");
    await expect(summary).toBeVisible();
    const sentence = summary.getByTestId("order-sentence");
    // UXR-196: form labels, German dates, one order across midnight (9 h), no code.
    await expect(sentence).toHaveText(
      new RegExp(`^Schichtauftrag · FaGe · \\S\\S ${deDate(day).replace(/\./g, "\\.")} 22:00 – \\S\\S \\d\\d\\.\\d\\d\\.\\d{4} 07:00 \\(9 Std\\.\\) · 4102 Binningen$`),
    );
    await expect(sentence).not.toContainText("_");
    // UXR-197: the client's own label, the empty radius in words, confirm enabled.
    await expect(summary.getByTestId("order-label")).toHaveText("Nacht · aus Ihrem Dienstplan");
    await expect(summary.getByTestId("order-radius")).toHaveText("Distanz: keine Vorgabe");
    const confirm = summary.getByRole("button", { name: "Bestätigen & Absenden" });
    await expect(confirm).toBeEnabled();
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);

    const orders = page.getByTestId("client-orders").locator("li", { hasText: `${deDate(day)} 22:00` });
    const before = await orders.count();
    await confirm.click();
    const done = page.getByTestId("order-done");
    await expect(done).toContainText("Auftrag bestätigt");
    await expect(page.getByTestId("client-orders")).toContainText(deDate(day) + " 22:00");
    await expect(page.getByTestId("order-cover-state").first()).toHaveText("Stand: noch nicht gedeckt");

    // UXR-199 (BK amendment 00:39 (1)(a)): the form is cleared, focus is on the confirmation naming the order, and
    // pressing on again without new input cannot send a second order (the summary names the missing fields).
    await expect(done).toBeFocused();
    await expect(done).toContainText(deDate(day));
    await expect(form.getByLabel(/^Datum/)).toHaveValue("");
    await expect(form.getByLabel("Beginn", { exact: true })).toHaveValue("");
    await expect(form.getByLabel("Einsatzort (Postleitzahl)")).toHaveValue("");
    await form.getByRole("button", { name: "Weiter zur Zusammenfassung" }).click();
    await expect(summary.getByRole("alert")).toBeVisible();
    await expect(summary.getByRole("button", { name: "Bestätigen & Absenden" })).toBeDisabled();
    await page.reload();
    await expect(orders).toHaveCount(before + 1);

    // UXR-198 (BK amendment 00:39 (1)(b)): the client's menu has a destination for /order.
    if (width >= 768) {
      await expect(page.getByTestId("main-menu").getByRole("link", { name: "Auftrag erfassen" })).toHaveAttribute("aria-current", "page");
    } else {
      await page.getByTestId("tab-more-button").click();
      await expect(page.getByTestId("tab-more").getByRole("link", { name: "Auftrag erfassen" })).toHaveAttribute("href", "/order");
    }
  });
}

test("a time that matches no plan entry shows no label line and stays confirmable (PO 18:40 (2)(c))", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 900 });
  await signIn(page, CLIENT, /\/order$/);
  const form = page.getByRole("form", { name: "Auftrag" });
  await form.getByLabel(/^Datum/).fill(deDate(zurichDay(Date.now(), 11)));
  await form.getByLabel("Beginn", { exact: true }).fill("09:10");
  await form.getByLabel("Ende", { exact: true }).fill("13:20");
  await form.getByLabel("Einsatzort (Postleitzahl)").selectOption("4051");
  await form.getByRole("radio", { name: "AGS", exact: true }).check();
  await form.getByRole("checkbox", { name: "Vitalzeichen, Gewicht", exact: true }).check();
  await form.getByRole("button", { name: "Weiter zur Zusammenfassung" }).click();
  const summary = page.getByTestId("order-summary");
  await expect(summary.getByTestId("order-sentence")).toContainText("(4 Std. 10 Min.)");
  await expect(summary.getByTestId("order-label")).toHaveCount(0);
  await expect(summary).not.toContainText("keine Bezeichnung");
  await expect(summary.getByRole("button", { name: "Bestätigen & Absenden" })).toBeEnabled();
  // Nothing was written by the summary: «Ändern» returns to the form.
  await summary.getByRole("button", { name: "Ändern" }).click();
  await expect(form).toBeVisible();
});
