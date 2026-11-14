import { expect, test, type Page } from "@playwright/test";

// AN1 — pilot impact dashboard. Synthetic local-only accounts from supabase/seed.sql.
const OPS = "ops.test@navora.test"; // coordinator: organisation and all teams
const NURSE = "pflege.test@navora.test"; // Testteam Nord only
const PASSWORD = "navora-local-only";

async function signIn(page: Page, email: string, landing: RegExp) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(landing);
}

test("Operations sees the organisation and every team, with definitions and sources (AN1)", async ({ page }) => {
  await signIn(page, OPS, /\/operations$/);
  await page.goto("/analytics");
  const org = page.getByRole("region", { name: "Ganze Organisation" });
  await expect(org).toBeVisible();
  await expect(org).toContainText("Quelle:");
  await expect(org.locator('[data-kpi="p1_median_close_hours"]')).toContainText("Noch nicht messbar");
  // AN1 change: the measured figure is named honestly, without the 60 % / 75 % reference line.
  await expect(org.locator('[data-kpi="care_share_in_visits"]')).toContainText("Pflegeanteil im Einsatz");
  await expect(org).not.toContainText("Buurtzorg 60");
  // WORK1-6 (0079): the North Star is shown per team from confirmed working days; the organisation row is a note.
  await expect(org.locator('[data-kpi="direct_care_share"]')).toContainText("Nur pro Team ausgewiesen");
  await expect(org.getByTestId("period-open_p1_exceptions")).toHaveText("Stand jetzt");
  await expect(page.getByRole("region", { name: "Team Testteam Nord" })).toBeVisible();
});

test("a nurse sees only her own team, never organisation figures (AN1)", async ({ page }) => {
  await signIn(page, NURSE, /\/field$/);
  await page.goto("/analytics");
  await expect(page.getByRole("region", { name: "Ganze Organisation" })).toHaveCount(0);
  await expect(page.getByRole("region", { name: /^Team / })).toHaveCount(1);
});

// AN2 part 2 — "Pilot-Hypothesen" at phone width (the team page links here as "Kennzahlen", UX1-13).
test("Pilot-Hypothesen render at 390 px with base and period on every row, no horizontal overflow (AN2)", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await signIn(page, OPS, /\/operations$/);
  await page.goto("/analytics");
  const section = page.getByRole("region", { name: "Pilot-Hypothesen" });
  await expect(section).toBeVisible();
  const org = section.getByRole("group", { name: "Hypothesen: Ganze Organisation" });
  await expect(org).toBeVisible();
  // AN2 parts 2 and 3: the twelve hypotheses of the brief.
  await expect(org.locator("[data-hypothesis]")).toHaveCount(12);
  const rows = section.locator("li[data-measure]");
  const n = await rows.count();
  expect(n).toBeGreaterThan(0);
  for (let i = 0; i < n; i++) {
    await expect(rows.nth(i).getByTestId("hyp-base")).toContainText("Basis");
    await expect(rows.nth(i).getByTestId("hyp-period")).not.toBeEmpty();
  }
  // AN2-M7: the minimum-duration reason has its own row in every scope.
  await expect(org.locator('li[data-measure="not_billable_reason"][data-detail="below_minimum"]')).toContainText("unter der Mindestdauer");
  // AN2-M8a: moves before the CGR-35 mark was captured have their own row, never "nicht abwesend".
  await expect(org.locator('li[data-measure="absence_past_visit_end"][data-detail="moved_before_capture"]')).toContainText("vor Erfassung (nicht gezählt)");
  await expect(org.locator('li[data-measure="absence_past_visit_end"]')).toHaveCount(7);
  // Values or "zu wenig Personen" (the seed's teams are small; pgTAP 059 proves the values and the suppression).
  await expect(org.locator('li[data-measure="coordinator_ends"]').getByTestId("hyp-value")).toHaveText(/^(zu wenig Personen|\d+)/);
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
  expect(overflow).toBeLessThanOrEqual(0);
});

test("a nurse sees Pilot-Hypothesen of her own team only (AN2)", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await signIn(page, NURSE, /\/field$/);
  await page.goto("/analytics");
  const section = page.getByRole("region", { name: "Pilot-Hypothesen" });
  await expect(section.getByRole("group", { name: "Hypothesen: Ganze Organisation" })).toHaveCount(0);
  await expect(section.getByRole("group", { name: /^Hypothesen: Team / })).toHaveCount(1);
  await expect(section.getByRole("group", { name: "Hypothesen: Team Testteam Nord" })).toBeVisible();
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
  expect(overflow).toBeLessThanOrEqual(0);
});

// AN3 — "Wo die Nicht-Pflegezeit hingeht" at 390 px and 1440 px (AN3-7). The seed's teams are small, so values are
// shown, "zu wenig Daten" or hidden ("zu wenig Personen"); pgTAP 109 proves the exact medians and the suppression.
const AN3_STEPS = [
  "direct_care_share", "travel_share_in_visits", "report_final_minutes", "countersign_latency_hours", "report_returned_share",
  "time_correction_share", "referral_to_case_ready_hours", "inform_gp_done_hours", "inform_gp_open_at_month_end",
  "inform_gp_open_age_days", "proposal_decided_hours", "proposals_corrected", "proposals_rejected", "proposals_expired_undecided",
];
for (const width of [390, 1440]) {
  test(`AN3 step spans at ${width} px: every figure with base and period, no target, no overflow`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 });
    await signIn(page, OPS, /\/operations$/);
    await page.goto("/analytics");
    const section = page.getByRole("region", { name: "Wo die Nicht-Pflegezeit hingeht" });
    await expect(section).toBeVisible();
    const org = section.getByRole("group", { name: "Schritte: Ganze Organisation" });
    await expect(org).toBeVisible();
    await expect(org.locator("li[data-step]")).toHaveCount(AN3_STEPS.length);
    for (const key of AN3_STEPS) {
      const row = org.locator(`li[data-step="${key}"]`);
      await expect(row.getByTestId("step-base")).toContainText("Basis");
      await expect(row.getByTestId("step-period")).not.toBeEmpty();
      await expect(row.getByTestId("step-value")).toHaveText(/^(–|\d)/);
    }
    // AN3-2: travel is labelled as travel within visits only.
    await expect(org.locator('li[data-step="travel_share_in_visits"]')).toContainText("Rückweg");
    // AN3-5: no target word anywhere in the block.
    await expect(section).not.toContainText(/\b(Ziel|Soll|besser|zu langsam)\b/);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
    expect(overflow).toBeLessThanOrEqual(0);
  });
}

test("a nurse sees the step spans of her own team only (AN3-3)", async ({ page }) => {
  await signIn(page, NURSE, /\/field$/);
  await page.goto("/analytics");
  const section = page.getByRole("region", { name: "Wo die Nicht-Pflegezeit hingeht" });
  await expect(section.getByRole("group", { name: "Schritte: Ganze Organisation" })).toHaveCount(0);
  await expect(section.getByRole("group", { name: /^Schritte: Team / })).toHaveCount(1);
});
