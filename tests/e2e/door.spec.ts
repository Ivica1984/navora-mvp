import { expect, test, type Page } from "@playwright/test";

// DOOR1 part (b) (migration 0073, ADR-086): the access arrangement on the /field card at phone width (DOOR1-4), as the one
// "Zugang" line of DOOR1-13 (migration 0080, ADR-093).
// Synthetic local-only accounts from supabase/seed.sql. Visit 509 (Testteam Nord, 18:00, two days ahead) of case 208:
// field.spec.ts runs it later and filters its HAND1 entries by text, so the values recorded here do not disturb it.
const NURSE = "pflege.test@navora.test"; // org A, registered nurse, Testteam Nord
const PASSWORD = "navora-local-only";

function zurichDay(offset = 0): string {
  const [y, m, d] = new Date().toLocaleDateString("sv-SE", { timeZone: "Europe/Zurich" }).split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d + offset)).toISOString().slice(0, 10);
}
const DAY_AFTER_NEXT = zurichDay(2);

async function signIn(page: Page, email: string, landing: RegExp) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(landing);
}

test("the access arrangement on the card: unbekannt first and distinct, never a code, who/when/source (DOOR1-3, DOOR1-4)", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await signIn(page, NURSE, /\/field$/);
  await page.goto(`/field?datum=${DAY_AFTER_NEXT}`);

  const card = page.getByRole("article", { name: /18:00 – 18:30/ });
  const alert = card.getByTestId("alert-access_arrangement");
  // DOOR1-13 (migration 0080): one "Zugang" line; the intake note is not a second record.
  await expect(alert).toContainText("Zugang");
  await expect(card.getByTestId("door-access")).toHaveCount(0);
  // No value yet and no intake note: "nicht erfasst", never blank.
  await expect(alert.getByTestId("alert-value")).toHaveText("nicht erfasst");

  // The form offers "unbekannt" first and preselected, and shows the help text.
  await alert.getByRole("button", { name: "Ändern" }).click();
  const form = alert.getByRole("form", { name: "Schlüssel- und Zugangsregelung" });
  const radios = form.getByRole("radio");
  await expect(radios.first()).toHaveAttribute("value", "unbekannt");
  await expect(radios.first()).toBeChecked();
  await expect(form).toContainText("Ort und wer den Schlüssel hat, nie den Code");

  // A code is refused.
  await form.getByLabel("ja", { exact: true }).check();
  await form.getByRole("textbox").fill("Synthetisch: Schlüsselsafe 47 11 beim Eingang");
  await form.getByRole("button", { name: "Speichern" }).click();
  await expect(form.getByTestId("command-error")).toHaveText("Bitte keinen Code erfassen");

  // Where and who holds the key, with its source.
  await form.getByRole("textbox").fill("Synthetisch: Schlüssel bei der Nachbarin links, 2. Stock");
  await form.getByLabel("Quelle").selectOption("relative");
  await form.getByRole("button", { name: "Speichern" }).click();
  await expect(alert.getByTestId("alert-value")).toHaveText("ja");
  await expect(alert.getByTestId("alert-note")).toHaveText("Synthetisch: Schlüssel bei der Nachbarin links, 2. Stock");
  await expect(alert.getByTestId("alert-meta")).toContainText("von dir");
  await expect(alert.getByTestId("alert-meta")).toContainText("Quelle: Angehörige");
  await expect(alert.getByTestId("alert-history")).toContainText("Verlauf");

  // A later "unbekannt" wins and is shown distinct from "nein".
  await alert.getByRole("button", { name: "Ändern" }).click();
  await alert.getByRole("form", { name: "Schlüssel- und Zugangsregelung" }).getByRole("button", { name: "Speichern" }).click();
  await expect(alert.getByTestId("alert-value")).toHaveText("unbekannt");
  await expect(alert.getByTestId("alert-value")).toHaveAttribute("data-tone", "unknown");
  await expect(alert.getByTestId("alert-history")).toContainText("Verlauf");

  // Phone width: nothing scrolls sideways.
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  expect(overflow).toBeLessThanOrEqual(0);
});
