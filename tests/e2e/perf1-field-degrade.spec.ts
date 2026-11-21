import { execFileSync } from "node:child_process";
import { expect, test, type Page } from "@playwright/test";

// PERF1 (brief docs/agents/briefs/PERF1.md scope (2), PO amendment 2026-11-21 20:39 (1), (2); CGR-272). Started as the
// red reproduction probe (`probe/perf1-field-degrade-red`, red on recovery/main b8824049): when `public.team_visit_alerts`
// failed, the whole /field page failed, because getTeamVisitAlerts() threw. On staging the failure was the 8 s statement
// timeout (57014); here it is forced deterministically by revoking EXECUTE from `authenticated` (42501): same code path
// in the app (PostgREST error), no timing dependence.
// Asserts: /field keeps its day view and /team its page; one visible notice line stands where the list would be (on
// /field above the visit cards); no hint list is shown as empty without it; each failed load is counted per team and
// day (private.aux_list_failures); after the restore the notice is gone.
// Fixture: local Supabase only (port 54322); the grant is restored in `finally` and again in afterAll (one worker,
// serial run, playwright.config.ts), so no later spec sees the revoked state. Synthetic seed accounts only; no row of
// any other spec is changed (the counter table is read by no other spec).
const NURSE = "pflege.test@navora.test"; // org A, nurse, Testteam Nord (supabase/seed.sql)
const PASSWORD = "navora-local-only";
const DB_URL = process.env.E2E_DB_URL ?? "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
const LOCAL_DB = /^postgres(ql)?:\/\/[^@]+@(127\.0\.0\.1|localhost):54322\//;
// Working wording from the PERF1 brief (2); final wording at the `uxa` gate, content check by `cra`.
const NOTICE = "Hinweise zu Einsätzen konnten nicht geladen werden";

function psql(sql: string): string {
  if (!LOCAL_DB.test(DB_URL)) throw new Error("PERF1 probe fixture: only the local Supabase database (port 54322)");
  return execFileSync("psql", [DB_URL, "-X", "-q", "-At", "-v", "ON_ERROR_STOP=1", "-c", sql], { encoding: "utf8" }).trim();
}
// Exactly the grant of the migrations (0045 … 0080: revoke from public, anon; grant execute to authenticated).
const breakAlerts = () => psql("revoke execute on function public.team_visit_alerts() from authenticated");
const restoreAlerts = () => psql("grant execute on function public.team_visit_alerts() to authenticated");

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(/\/field$/);
}

const TEAM_NORD = "00000000-0000-4000-a000-000000000101"; // Testteam Nord (supabase/seed.sql)
const failuresToday = () =>
  Number(psql(`select coalesce(sum(failures), 0) from private.aux_list_failures
               where team_id = '${TEAM_NORD}' and list_key = 'team_visit_alerts' and day = (private.at_zurich(private.now()))::date`));

test.describe("PERF1: /field and /team when the visit hint list fails", () => {
  test.afterAll(() => {
    restoreAlerts();
  });

  for (const width of [390, 1440]) {
    test(`/field at ${width} px: the day view stays and one visible notice above the cards replaces the hint list`, async ({ page }) => {
      await page.setViewportSize({ width, height: 900 });
      await signIn(page, NURSE);
      // Control: with the list available the day view renders and the notice is absent.
      await expect(page.getByRole("navigation", { name: "Tag wechseln" })).toBeVisible();
      await expect(page.getByText(NOTICE)).toHaveCount(0);

      const before = failuresToday();
      breakAlerts();
      try {
        await page.reload();
        await expect(page.getByRole("navigation", { name: "Tag wechseln" })).toBeVisible();
        const notice = page.getByTestId("visit-alerts-unavailable");
        await expect(notice).toHaveCount(1);
        await expect(notice).toHaveText(NOTICE + ".");
        await expect(notice).toHaveAttribute("role", "status");
        // Where the list would be and above the visit cards (CGR-272).
        const cards = page.getByRole("list", { name: "Einsätze" });
        if (await cards.count()) {
          const [n, c] = await Promise.all([notice.boundingBox(), cards.boundingBox()]);
          expect(n && c && n.y < c.y).toBe(true);
        }
        // Never a silent omission: no follow-up list rendered as if empty; the notice on every render while it fails.
        await expect(page.getByTestId("followup-queue")).toHaveCount(0);
        await page.reload();
        await expect(page.getByTestId("visit-alerts-unavailable")).toHaveCount(1);
        // Each failed load is counted for her team and the Zurich day (team level, never per person).
        expect(failuresToday()).toBeGreaterThanOrEqual(before + 2);
      } finally {
        restoreAlerts();
      }

      await page.reload();
      await expect(page.getByRole("navigation", { name: "Tag wechseln" })).toBeVisible();
      await expect(page.getByText(NOTICE)).toHaveCount(0);
    });
  }

  // T-1 «sent = shown» and T-2 «one interrupted or double step» (FE-111; brief acceptance criteria 3-5). Own fixture
  // in Testorganisation S, which no spec after this file reads (checked: plan3 … work use no org-S account), so no count
  // of another spec changes: one case and one planned needs-assessment visit of Testteam Basel today at 23:47, the
  // seeded registered nurse responsible. Written as the table owner like supabase/seed.sql; new ids on every run, so a
  // local re-run never finds an earlier run's state. visit_events stay append-only: nothing is deleted afterwards.
  test("T-1/T-2: while the hint list fails, a double tap on «Losfahren» moves the card once to «Unterwegs», as stored (390 px)", async ({ page }) => {
    const ORG_S = "00000000-0000-4000-b000-000000000019";
    const TEAM_S = "00000000-0000-4000-a000-0000000001b9"; // Testteam Basel
    const NURSE_S = "00000000-0000-4000-a000-0000000009e6"; // pflegebs.test, registered nurse HF (seed, ADR-180)
    const caseId = psql(`insert into public.cases (organization_id, created_at, name, first_name, last_name, region, plz,
        status, urgency, bedarf, care_needs, next_step, assigned_team, assigned_team_id)
      values ('${ORG_S}', private.now() - interval '1 day', 'Testfall PERF1', 'Testfall', 'PERF1', 'Basel-Stadt', '4051',
        'laufend', 'mittel', 'Grundpflege', array['Grundpflege'], 'Bedarfsabklärung', 'Testteam Basel', '${TEAM_S}')
      returning id`);
    const visitId = psql(`insert into public.care_visits (organization_id, created_at, case_id, team_id, visit_date, time_start,
        time_end, services_provided, billable, status, planned_minutes_a, responsible_user_id, is_needs_assessment)
      values ('${ORG_S}', private.now() - interval '1 day', '${caseId}', '${TEAM_S}', (private.now() at time zone 'Europe/Zurich')::date,
        '23:47', '23:58', array['Grundpflege'], false, 'planned', 11, '${NURSE_S}', true)
      returning id`);
    const stored = () => psql(`select status from public.care_visits where id = '${visitId}'`);
    const departures = () => Number(psql(`select count(*) from public.visit_events where visit_id = '${visitId}' and to_status = 'on_the_way'`));

    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto("/login");
    await page.getByLabel("E-Mail").fill("pflegebs.test@navora.test");
    await page.getByLabel("Passwort").fill(PASSWORD);
    await page.getByRole("button", { name: "Anmelden" }).click();
    await page.waitForURL(/\/field$/);

    breakAlerts();
    try {
      await page.reload();
      // Interrupted step: the hint list fails, the notice stands, the card and its command stay.
      await expect(page.getByTestId("visit-alerts-unavailable")).toHaveText(NOTICE + ".");
      const card = page.getByRole("article", { name: /23:47 – 23:58/ });
      await expect(card.getByTestId("visit-status")).toHaveText("Geplant");
      // Double step: two taps in quick succession on the same button.
      await card.getByRole("button", { name: "Losfahren" }).dblclick();
      await expect(card.getByTestId("visit-status")).toHaveText("Unterwegs");
      await expect(card.getByRole("button", { name: "Einsatz starten" })).toBeEnabled();
      await expect(card.getByTestId("command-error")).toHaveCount(0);
      // T-1: what the card shows is what the server stored, also after a fresh load; exactly one state change.
      expect(stored()).toBe("on_the_way");
      expect(departures()).toBe(1);
      await page.reload();
      await expect(page.getByTestId("visit-alerts-unavailable")).toHaveCount(1);
      await expect(page.getByRole("article", { name: /23:47 – 23:58/ }).getByTestId("visit-status")).toHaveText("Unterwegs");
    } finally {
      restoreAlerts();
    }
    expect(departures()).toBe(1);
  });

  test("/team: the team view stays and the notice stands in place of «Einsätze mit Handlungsbedarf»", async ({ page }) => {
    await signIn(page, NURSE);
    await page.goto("/team");
    await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
    await expect(page.getByText(NOTICE)).toHaveCount(0);
    breakAlerts();
    try {
      await page.reload();
      await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
      await expect(page.getByTestId("visit-alerts-unavailable")).toHaveText(NOTICE + ".");
      await expect(page.getByTestId("visit-alerts")).toHaveCount(0);
    } finally {
      restoreAlerts();
    }
    await page.reload();
    await expect(page.getByText(NOTICE)).toHaveCount(0);
  });
});
