import { expect, test, type Locator, type Page } from "@playwright/test";
import baselineFile from "./handgrip-baseline.json";
import { zurichDay } from "./support/durchgang-time";
import { handgripReport, judgeHandgrips, parseBaseline, type HandgripRole } from "./support/handgrip-budget";
import { PAGE_LABEL } from "@/lib/auth/nav";

// ADR-208 (founder decision 2026-11-19, live session: «Wir messen weder die KI noch unsere eigenen Ziele, zum Beispiel
// Handgriffe pro Auftrag oder Zeit bis «Gedeckt»» … «muss zwingend eingeführt werden»; mode «Sperrklinke»).
// The BK path at 390 px (the phone is the main device), synthetic local-only accounts from supabase/seed.sql
// (Testorganisation S, simulation), the same path as bk-c2-take-status.spec.ts:
//   kundebs.test  client of «Testheim Rhein (synthetisch)»: orders one HF day shift and reads «Gedeckt»;
//   pflegebs.test registered nurse of Testteam Basel (HF): takes it naming herself.
// M1 handgrips per order: every human act after the person's landing page is counted through tap/fill/choose/tick
// below (ADR-208 (2)); sign-in, reading and waiting are not counted. The ratchet in support/handgrip-budget.ts fails the
// run when a role needs more handgrips than tests/e2e/handgrip-baseline.json, and also when it needs fewer, until the
// baseline is lowered in the same PR. The Blueprint §6.3 target and the gap are reported on every run.
// M2 time to «Gedeckt»: two system times (not the human waiting time, which the stored confirmed_at → taken_at gives,
// ADR-208 (4), PLANNED): confirm → the client's card shows the offer; take → the team's card and the client read
// «Übernommen» / «Gedeckt». Measured and reported, not asserted (no limit before a baseline over `ci-repeat`).
// Own Zurich day 40 ahead (other BK specs use 10–14 and 30–37), so pflegebs is free; one synthetic order per run.
const PASSWORD = "navora-local-only";
const baseline = parseBaseline(baselineFile);
const counts: Record<HandgripRole, number> = { auftraggeber: 0, team: 0, pflege_nach_schicht: 0 };
let role: HandgripRole | null = null;

function count() {
  if (!role) throw new Error("ADR-208: a handgrip was made before a role was named");
  counts[role] += 1;
}
async function tap(target: Locator) {
  count();
  await target.click();
}
async function fill(target: Locator, value: string) {
  count();
  await target.fill(value);
}
async function choose(target: Locator, value: string) {
  count();
  await target.selectOption(value);
}
async function tick(target: Locator) {
  count();
  await target.check();
}

/** Not a handgrip: the sign-in is the door, not work on the order (ADR-208 (2)). */
async function signIn(page: Page, email: string) {
  role = null;
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

const deDate = (iso: string) => iso.split("-").reverse().join(".");

test("ADR-208 at 390 px: handgrips per order on the BK path are held by the ratchet; the time to «Gedeckt» is measured", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  const day = zurichDay(Date.now(), 40);
  const when = `${deDate(day)} 07:00`;

  // 1. Auftraggeber: from her landing page /order to the confirmed order.
  await signIn(page, "kundebs.test@navora.test");
  await expect(page).toHaveURL(/\/order$/);
  role = "auftraggeber";
  const form = page.getByRole("form", { name: "Auftrag" });
  await fill(form.getByLabel(/^Datum/), deDate(day));
  await fill(form.getByLabel("Beginn", { exact: true }), "07:00");
  await fill(form.getByLabel("Ende", { exact: true }), "15:30");
  await choose(form.getByLabel("Einsatzort (Postleitzahl)"), "4051");
  await tick(form.getByRole("radio", { name: "HF", exact: true }));
  await tick(form.getByRole("checkbox", { name: "Grundpflege", exact: true }));
  await tap(form.getByRole("button", { name: "Weiter zur Zusammenfassung" }));
  const confirmedAt = Date.now();
  await tap(page.getByTestId("order-summary").getByRole("button", { name: "Bestätigen & Absenden" }));
  const clientCard = page.getByTestId("client-orders").locator("li", { hasText: when }).last();
  await expect(clientCard.getByTestId("order-cover-state")).toHaveText(/^Noch nicht gedeckt/);
  const offerMs = Date.now() - confirmedAt;
  await page.context().clearCookies();

  // 2. Team: from her landing page to the take (she is the only HF member; she is pre-selected).
  await signIn(page, "pflegebs.test@navora.test");
  await expect(page).toHaveURL(/\/field$/);
  role = "team";
  await tap(page.getByRole("link", { name: PAGE_LABEL.team, exact: true }));
  const offer = page.getByTestId("shift-offer-card").filter({ hasText: when }).last();
  await expect(offer.getByRole("radio", { name: "Ich (Pflegekraft)" })).toBeChecked();
  const takenAt = Date.now();
  await tap(offer.getByRole("button", { name: "Übernehmen mit Pflegekraft" }));
  await expect(page.getByTestId("shift-offer-card").filter({ hasText: when }).last().getByTestId("shift-offer-tag")).toHaveText("Übernommen");
  const takeMs = Date.now() - takenAt;
  await page.context().clearCookies();

  // 3. Auftraggeber reads «Gedeckt» on her landing page: reading is no handgrip, so her count does not change.
  await signIn(page, "kundebs.test@navora.test");
  const covered = page.getByTestId("client-orders").locator("li", { hasText: when }).last();
  await expect(covered.getByTestId("order-cover-state")).toHaveText(/^Gedeckt/);
  role = null;

  // Report first (attached and logged), then the ratchet per measured role.
  const measured = (Object.keys(baseline) as HandgripRole[]).map((r) => judgeHandgrips(r, counts[r], baseline[r]!));
  const report = [
    handgripReport(measured),
    "",
    "ADR-208 M2: Systemzeit bis «Gedeckt» (gemessen, kein Grenzwert; nicht die Wartezeit auf ein Team):",
    `- Bestätigen → Angebot auf der Karte der Auftraggeberin: ${offerMs} ms`,
    `- Übernehmen → «Übernommen» auf der Karte des Teams: ${takeMs} ms`,
  ].join("\n");
  console.log(report);
  await test.info().attach("adr-208-handgrips.md", { body: report, contentType: "text/markdown" });
  for (const verdict of measured) {
    expect.soft(verdict.outcome, verdict.message).toBe("held");
  }
});
