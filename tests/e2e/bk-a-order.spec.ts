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
    // UXR-200 (BK amendment 00:39 (1)(c)): the form stays; the list at its top has the focus, each problem is also
    // named at its field (aria-invalid, aria-describedby), and the summary does not open, so nothing can be confirmed.
    const problems = form.getByTestId("order-problems");
    await expect(problems).toBeVisible();
    await expect(problems).toBeFocused();
    await expect(summary).toHaveCount(0);
    const dateField = form.getByLabel(/^Datum/);
    await expect(dateField).toHaveAttribute("aria-invalid", "true");
    await expect(dateField).toHaveAttribute("aria-describedby", /order-field-date-problem/);
    await expect(form.getByTestId("order-field-date-problem")).toHaveText("Bitte das Datum angeben.");
    const postcodeField = form.getByLabel("Einsatzort (Postleitzahl)");
    await expect(postcodeField).toHaveAttribute("aria-invalid", "true");
    await problems.getByRole("link", { name: "Bitte die Postleitzahl des Einsatzorts wählen." }).click();
    await expect(postcodeField).toBeFocused();
    // A field the client changes drops its own problem line; the others stay until the next check.
    await postcodeField.selectOption("4102");
    await expect(form.getByTestId("order-field-postcode-problem")).toHaveCount(0);
    await expect(postcodeField).not.toHaveAttribute("aria-invalid", "true");
    await expect(form.getByTestId("order-field-date-problem")).toBeVisible();
    await page.reload();
    await expect(orders).toHaveCount(before + 1);

    // UXR-198 (BK amendment 00:39 (1)(b)): the client's menu has a destination for /order.
    if (width >= 768) {
      await expect(page.getByTestId("main-menu").getByRole("link", { name: "Auftrag erfassen" })).toHaveAttribute("aria-current", "page");
    } else {
      // UXR-204 (BK amendment 04:39 (2)): on the phone «Auftrag erfassen» is her tab, current on /order; not under Mehr.
      const tabBar = page.getByTestId("tab-bar");
      await expect(tabBar.getByRole("link", { name: "Auftrag erfassen" })).toHaveAttribute("href", "/order");
      await expect(tabBar.getByRole("link", { name: "Auftrag erfassen" })).toHaveAttribute("aria-current", "page");
      await page.getByTestId("tab-more-button").click();
      await expect(page.getByTestId("tab-more").getByRole("link", { name: "Auftrag erfassen" })).toHaveCount(0);
      await expect(page.getByTestId("tab-more").getByRole("link", { name: "Meine Einstellungen" })).toBeVisible();
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

test("«Datum nicht erkannt» appears only after leaving the date field, not while typing (UXR-201)", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 900 });
  await signIn(page, CLIENT, /\/order$/);
  const form = page.getByRole("form", { name: "Auftrag" });
  const dateField = form.getByLabel(/^Datum/);
  await dateField.pressSequentially("Son");
  await expect(form.getByTestId("order-date-unknown")).toHaveCount(0);
  await expect(dateField).not.toHaveAttribute("aria-invalid", "true");
  await dateField.press("Tab");
  await expect(form.getByTestId("order-date-unknown")).toBeVisible();
  await expect(dateField).toHaveAttribute("aria-describedby", /order-date-unknown/);
  // Typing again hides it until the field is left again; a recognised word never shows it.
  await dateField.fill("Sonntag");
  await expect(form.getByTestId("order-date-unknown")).toHaveCount(0);
  await dateField.press("Tab");
  await expect(form.getByTestId("order-date-unknown")).toHaveCount(0);
});

// BK-b1 / CGR-217 (PO amendment 2026-11-14 01:39 (4)): the same order a second time is named as information, in a
// neutral style (no alert role), and stays confirmable. Own day (+14) and time, so no other test meets it.
test("the same order a second time shows the information line and stays confirmable (CGR-217)", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 900 });
  await signIn(page, CLIENT, /\/order$/);
  const form = page.getByRole("form", { name: "Auftrag" });
  const day = zurichDay(Date.now(), 14);
  const fillOrder = async () => {
    await form.getByLabel(/^Datum/).fill(deDate(day));
    await form.getByLabel("Beginn", { exact: true }).fill("06:10");
    await form.getByLabel("Ende", { exact: true }).fill("10:20");
    await form.getByLabel("Einsatzort (Postleitzahl)").selectOption("4123");
    await form.getByRole("radio", { name: "AGS", exact: true }).check();
    await form.getByRole("checkbox", { name: "Vitalzeichen, Gewicht", exact: true }).check();
    await form.getByRole("button", { name: "Weiter zur Zusammenfassung" }).click();
  };
  await fillOrder();
  const summary = page.getByTestId("order-summary");
  await summary.getByRole("button", { name: "Bestätigen & Absenden" }).click();
  await expect(page.getByTestId("order-done")).toContainText("Auftrag bestätigt");

  await fillOrder();
  const info = summary.getByTestId("order-info");
  await expect(info).toHaveText(
    new RegExp(`^Hinweis: Für dieses Konto ist bereits ein Auftrag mit gleichem Beginn, Ende, Stufe und Ort bestätigt \\(Schichtauftrag · AGS · \\S\\S ${deDate(day).replace(/\./g, "\\.")} 06:10 .* 4123 Allschwil\\)\\. Ein zweiter Auftrag bedeutet zwei Pflegekräfte für diese Zeit\\. Wenn das so gemeint ist, bestätigen Sie ihn\\.$`),
  );
  await expect(info).not.toHaveAttribute("role", "alert");
  await expect(summary.getByRole("alert")).toHaveCount(0);
  await expect(summary.getByRole("button", { name: "Bestätigen & Absenden" })).toBeEnabled();
});
