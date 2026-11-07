import { expect, test, type Page } from "@playwright/test";

// PLAN2 — the care plan generates the next four weeks on /team. Synthetic local-only accounts from supabase/seed.sql.
const NURSE = "pflege.test@navora.test"; // Testteam Nord (case Testfall 08, needs assessment done)
const PASSWORD = "navora-local-only";

async function signIn(page: Page, email: string, landing: RegExp) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(landing);
}

test("a daily rhythm in the care plan plans the next four weeks; the team can stop the series (PLAN2)", async ({ page }) => {
  await signIn(page, NURSE, /\/field$/);
  await page.goto("/team");
  const card = page.getByRole("article", { name: /Fall Testfall 08/ });

  const plan = card.getByRole("region", { name: "Pflegeplan" });
  await plan.getByRole("button", { name: "Leistung hinzufügen" }).click();
  const item = plan.getByRole("form", { name: "Leistung hinzufügen" });
  await item.getByLabel("Leistung", { exact: true }).fill("Morgenpflege E2E");
  await item.getByLabel("Kategorie").selectOption("A");
  await item.getByLabel("Minuten pro Einsatz").fill("30");
  await item.getByLabel("Häufigkeit").fill("täglich");
  await item.getByLabel("Überprüfung am").fill(new Date(Date.now() + 60 * 86_400_000).toISOString().slice(0, 10));
  await item.getByRole("button", { name: "Leistung speichern" }).click();

  const auto = card.getByTestId("auto-plan");
  const row = auto.getByRole("listitem", { name: "Rhythmus Morgenpflege E2E" });
  await expect(row.getByTestId("schedule")).toHaveText("nicht automatisch geplant");
  await row.getByRole("button", { name: "Rhythmus festlegen" }).click();
  const form = row.getByRole("form", { name: "Rhythmus für Morgenpflege E2E" });
  await form.getByLabel("Rhythmus").selectOption("day");
  await form.getByLabel("Von").fill("07:30");
  await form.getByLabel("Bis").fill("08:15");
  await form.getByRole("button", { name: "Rhythmus speichern" }).click();

  await expect(row.getByTestId("schedule")).toHaveText("täglich 07:30–08:15");
  await expect(auto.getByTestId("generated-ahead")).toHaveText("28");
  await expect(card.getByRole("list", { name: "Geplante Einsätze" }).getByTestId("generated-visit").first()).toBeVisible();

  // Stopping the series needs a reason and removes the untouched future visits.
  await auto.getByRole("button", { name: "Serie stoppen" }).click();
  await auto.getByRole("form", { name: "Serie stoppen" }).getByLabel("Grund").fill("Pflegeplan wird überarbeitet");
  await auto.getByRole("form", { name: "Serie stoppen" }).getByRole("button", { name: "Serie stoppen" }).click();
  await expect(auto.getByTestId("auto-plan-state")).toHaveText("aus");
  await expect(card.getByTestId("generated-visit")).toHaveCount(0);
});
