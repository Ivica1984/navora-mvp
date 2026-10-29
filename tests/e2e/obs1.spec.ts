import { expect, test, type Page } from "@playwright/test";
import { QUALIFICATION_NOT_RECORDED_TEXT } from "@/features/field/authorship";

// OBS1 (migration 0095, ADR-118, `cra` CGR-93, `lca` 13:57) at phone width. Synthetic local-only accounts of
// Testorganisation C from supabase/seed.sql:
// - teamc.test ("Pflegekraft Team C", registered nurse) performed today's 07:00 visit of Testfall C1 and wrote one
//   observation; she signs in, drafts and signs the report.
// - notiz.test ("Neues Teammitglied C") wrote one observation on that visit before her qualification was recorded, so it
//   carries the OBS1-1 marker; she never signs in.
// The pinned-clock and permission paths (marker fixed at write time, no read widened, old snapshots unchanged) are in
// pgTAP 095. This test writes one signature, on that visit's seeded draft only.
const NURSE = "teamc.test@navora.test";
const PASSWORD = "navora-local-only";

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

function zurichDay(offset = 0): string {
  const [y, m, d] = new Date().toLocaleDateString("sv-SE", { timeZone: "Europe/Zurich" }).split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d + offset)).toISOString().slice(0, 10);
}

test("every observation names its author; the one written without a recorded qualification carries the marker, also before signing (OBS1-4)", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await signIn(page, NURSE);
  await page.goto(`/field?datum=${zurichDay()}`);

  const card = page.getByRole("article", { name: /07:00 – 07:30/ });
  const observations = card.getByRole("region", { name: "Beobachtungen" });

  // The colleague's observation: her name and the marker, in `info` tone (no red), the text unchanged.
  const theirs = observations.getByRole("listitem").filter({ hasText: "trinkt wenig" });
  await expect(theirs.getByTestId("observation-author")).toHaveText("Neues Teammitglied C");
  await expect(theirs.getByTestId("observation-qualification-marker")).toHaveText(QUALIFICATION_NOT_RECORDED_TEXT);
  await expect(theirs.getByTestId("observation-qualification-marker")).not.toHaveClass(/rose|red/);
  await expect(theirs).toContainText("Synthetisch: Klientin am Morgen müde, trinkt wenig");

  // Her own observation: "von dir", no marker.
  const mine = observations.getByRole("listitem").filter({ hasText: "Fersen intakt" });
  await expect(mine.getByTestId("observation-author")).toHaveText("von dir");
  await expect(mine.getByTestId("observation-qualification-marker")).toHaveCount(0);

  // The draft completion opened (F7): the facts she checks before signing name both authors and carry the marker on one.
  const report = card.getByTestId("visit-report");
  await expect(report.getByTestId("report-status")).toHaveText("Entwurf");
  const facts = report.getByTestId("report-facts");
  const factTheirs = facts.getByTestId("report-observation").filter({ hasText: "trinkt wenig" });
  const factMine = facts.getByTestId("report-observation").filter({ hasText: "Fersen intakt" });
  await expect(factTheirs.getByTestId("report-observation-author")).toHaveText("von Neues Teammitglied C");
  await expect(factTheirs.getByTestId("report-observation-marker")).toHaveText(QUALIFICATION_NOT_RECORDED_TEXT);
  await expect(factMine.getByTestId("report-observation-author")).toHaveText("von Pflegekraft Team C");
  await expect(factMine.getByTestId("report-observation-marker")).toHaveCount(0);
  await expect(report.getByRole("button", { name: "Bericht unterschreiben" })).toBeVisible();

  // She signs exactly this version (the stored snapshot keeps both facts: pgTAP 095).
  await report.getByRole("button", { name: "Bericht unterschreiben" }).click();
  await expect(report.getByTestId("report-status")).toHaveText("Bericht abgeschlossen");

  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(390);
});
