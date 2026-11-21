import { expect, test } from "@playwright/test";
import { STREET_MISSING } from "@/features/field/place";

// BK-e1 / UXR-190 (#1232, `cra` CGR-212; ADR-202 (1)): a seed visit without a street says «Strasse fehlt» on its
// /field card at 390 px, as text, with no sideways scroll. Read only: changes no seed row.
// Seed (supabase/seed.sql header): every synthetic case carries a postcode and nothing else of an address.
const NURSE = "pflege.test@navora.test"; // org A, nurse, Testteam Nord; visit 501 (08:00, Testfall 08, 4052)
const PASSWORD = "navora-local-only";

function zurichDay(): string {
  return new Date().toLocaleDateString("sv-SE", { timeZone: "Europe/Zurich" });
}

test("BK-e1 UXR-190: a visit card with a postcode and no street shows «Strasse fehlt» at 390 px", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(NURSE);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(/\/field$/);
  await page.goto(`/field?datum=${zurichDay()}`);

  const card = page.getByRole("article", { name: /08:00 – 08:45/ });
  await expect(card).toContainText("Testfall 08");
  const place = card.getByTestId("visit-place");
  await expect(place).toHaveText(`4052 · ${STREET_MISSING}`);
  await expect(place).toContainText("Strasse fehlt");

  expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(0);
});
