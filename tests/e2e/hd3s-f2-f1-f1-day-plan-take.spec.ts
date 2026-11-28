import { execFileSync } from "node:child_process";
import { expect, test, type Page } from "@playwright/test";
import { zurichDay } from "./support/durchgang-time";

// HD-3s-F2-F1-F1 e2e (brief docs/agents/briefs/HD-3s-F2-F1-F1.md criterion «Unit/e2e 390 und 1440 px»; `cra` CGR-291;
// ADR-230; migration 0191): pflegebs holds a live split take 07:00–11:30 und 16:00–20:00 of «Testheim Rhein» and is the
// primary nurse of a synthetic case of her own small team «Testteam F1F1 <width>» (with kolleginbs). The team asks the
// day-plan proposal for that day: the open 12:00 visit (the pause) is proposed for kolleginbs, not for her; the 20:30
// visit (after block 2) is proposed for her as «Bezugspflegende». Both lines are confirmed as proposed: nothing fails
// with «overlap». Fixed, checkable rule, no AI (the proposal agent is the PLAN3 rule agent). Synthetic local accounts.
// Fixture (local database only): the split order is prepared, sent and taken through the real commands as the home lead
// and as pflegebs (UI of that path: HD-3s-F2 spec); team, memberships, case and the two open visits as the table owner.
// Own team per width, so no other spec's team switch, lines or counts change. Days +11 and +12 (inside the 14-day bound
// of the day plan; no other spec uses them for pflegebs). Shift code GF5 (GF3: take-window spec).
const PASSWORD = "navora-local-only";
const VIEWER = "kolleginbs.test@navora.test";
const LEAD = "00000000-0000-4000-a000-0000000009e8"; // kundebs, lead of «Testheim Rhein»
const NURSE = "00000000-0000-4000-a000-0000000009e6"; // pflegebs
const COLLEAGUE = "00000000-0000-4000-a000-0000000009ec"; // kolleginbs
const BASEL = "00000000-0000-4000-a000-0000000001b9"; // Testteam Basel: the team pflegebs takes the order with
const ORG = "00000000-0000-4000-b000-000000000019";
const INST = "00000000-0000-4000-a000-0000000004c1";
const CODE = "GF5";
const DB_URL = process.env.E2E_DB_URL ?? "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
const LOCAL_DB = /^postgres(ql)?:\/\/[^@]+@(127\.0\.0\.1|localhost):54322\//;

function psql(sql: string): string {
  if (!LOCAL_DB.test(DB_URL)) throw new Error("HD-3s-F2-F1-F1 fixture: only the local Supabase database (port 54322)");
  return execFileSync("psql", [DB_URL, "-X", "-q", "-At", "-v", "ON_ERROR_STOP=1", "-c", sql], { encoding: "utf8" }).trim();
}

/** Runs one command as a user (claims + role authenticated, as PostgREST), returns its jsonb result as text. */
function as(user: string, call: string): string {
  if (!LOCAL_DB.test(DB_URL)) throw new Error("HD-3s-F2-F1-F1 fixture: only the local Supabase database (port 54322)");
  const out = execFileSync("psql", [DB_URL, "-X", "-q", "-At", "-v", "ON_ERROR_STOP=1",
    "-c", `select set_config('request.jwt.claims', json_build_object('sub', '${user}', 'role', 'authenticated')::text, false),
                  set_config('request.jwt.claim.sub', '${user}', false)`,
    "-c", "set role authenticated",
    "-c", `select (${call})::text`], { encoding: "utf8" }).trim().split("\n");
  return out[out.length - 1];
}

const teamOf = (width: number) => `00000000-0000-4000-8191-00000000${String(width).padStart(4, "0")}`;
const caseOf = (width: number) => `00000000-0000-4000-8191-00000001${String(width).padStart(4, "0")}`;

function fixture(day: string, width: number): string {
  // A station of the home: the first one if earlier specs created it, else one of this spec.
  psql(`insert into public.institution_stations (institution_id, name, sort)
        select '${INST}', 'Station F1F1', 99
        where not exists (select 1 from public.institution_stations where institution_id = '${INST}');
        insert into public.institution_shift_types (institution_id, code, label, starts_at, block1_ends_at, block2_starts_at,
          ends_at, shift_class, sort)
        values ('${INST}', '${CODE}', 'Geteilt F1F1', '07:00', '11:30', '16:00', '20:00', 'split', 92)
        on conflict do nothing;
        insert into public.institution_staffing_rules (institution_id, station_id, shift_type_id, required_total,
          required_grade, required_grade_count, example)
        select '${INST}', (select id from public.institution_stations where institution_id = '${INST}' order by sort, name limit 1),
               t.id, 1, 'nurse_hf_fh', 1, true
        from public.institution_shift_types t where t.institution_id = '${INST}' and t.code = '${CODE}'
        on conflict do nothing;`);
  const station = psql(`select id from public.institution_stations where institution_id = '${INST}' order by sort, name limit 1`);
  const shift = psql(`select id from public.institution_shift_types where institution_id = '${INST}' and code = '${CODE}'`);
  const prep = JSON.parse(as(LEAD, `public.institution_prepare_gap_order('${INST}', '${station}', '${shift}', '${day}')`));
  expect(prep.result, `prepare ${JSON.stringify(prep)}`).toBe("ok");
  const sent = JSON.parse(as(LEAD, `public.institution_send_gap_order('${prep.gap_order_id}', '4051', 'nurse_hf_fh', '{C1}',
    '{}', null, gen_random_uuid())`));
  expect(sent.result, `send ${JSON.stringify(sent)}`).toBe("ok");
  const took = JSON.parse(as(NURSE, `public.take_order('${sent.order_id}', '${BASEL}', '${NURSE}', gen_random_uuid())`));
  expect(took.result, `take ${JSON.stringify(took)}`).toBe("ok");
  // Her own small team with the colleague; the case (copy of seed case …208) has her as primary nurse; two open visits.
  psql(`insert into public.teams (organization_id, id, name, region, status, max_distance_km)
        values ('${ORG}', '${teamOf(width)}', 'Testteam F1F1 ${width}', 'Basel-Stadt', 'active', 10) on conflict (id) do nothing;
        insert into public.team_memberships (team_id, user_id, qualification)
        values ('${teamOf(width)}', '${NURSE}', 'registered_nurse'), ('${teamOf(width)}', '${COLLEAGUE}', 'registered_nurse')
        on conflict do nothing;
        insert into public.cases
        select (jsonb_populate_record(k, jsonb_build_object('id', '${caseOf(width)}', 'organization_id', '${ORG}',
          'assigned_team_id', '${teamOf(width)}', 'first_name', 'Testfall', 'last_name', 'F1F1 ${width}', 'auto_planning', false,
          'primary_nurse_id', '${NURSE}', 'deputy_nurse_id', null, 'proposed_primary_nurse_id', null, 'previous_case_id', null,
          'source_partner_request_id', null))).*
        from public.cases k where k.id = '00000000-0000-4000-a000-000000000208'
        on conflict (id) do nothing;
        insert into public.care_visits (organization_id, case_id, team_id, visit_date, time_start, time_end, services_provided,
          billable, status, planned_minutes_a, responsible_user_id)
        values ('${ORG}', '${caseOf(width)}', '${teamOf(width)}', '${day}', '12:00', '12:30', array['Grundpflege'], false, 'planned', 30, null),
               ('${ORG}', '${caseOf(width)}', '${teamOf(width)}', '${day}', '20:30', '21:00', array['Grundpflege'], false, 'planned', 30, null);`);
  return sent.order_id as string;
}
function cleanup() {
  psql(`delete from public.institution_staffing_rules where shift_type_id in
          (select id from public.institution_shift_types where institution_id = '${INST}' and code = '${CODE}')`);
}

async function signIn(page: Page, email: string) {
  await page.context().clearCookies();
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}
async function noSideScroll(page: Page) {
  expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(0);
}

test.describe.configure({ mode: "serial" });
test.afterAll(() => cleanup());

for (const [width, offset] of [[1440, 11], [390, 12]] as const) {
  test(`HD-3s-F2-F1-F1 at ${width} px: the day plan does not propose her in the pause of her split take; what it proposes confirms`, async ({ page }) => {
    test.setTimeout(180_000);
    const day = zurichDay(Date.now(), offset);
    const orderId = fixture(day, width);
    const live = () => psql(`select count(*) from public.order_takes where order_id = '${orderId}' and member_id = '${NURSE}'
                               and released_at is null`);
    const responsible = (from: string) => psql(`select coalesce(responsible_user_id::text, '-') from public.care_visits
                                                  where case_id = '${caseOf(width)}' and to_char(time_start, 'HH24:MI') = '${from}'`);
    expect(live()).toBe("1");
    // Precondition: no visit of hers that day in any team at 12:00 (the pause is busy only because of the take).
    expect(psql(`select count(*) from public.care_visits where responsible_user_id = '${NURSE}' and visit_date = '${day}'
                   and status <> 'cancelled' and time_start < '12:30' and time_end > '12:00'`)).toBe("0");

    // 1. The colleague switches the proposal on for the new team and asks for that day.
    await page.setViewportSize({ width, height: 900 });
    await signIn(page, VIEWER);
    await page.goto(`/team/tagesplan?team=${teamOf(width)}`);
    await expect(page.getByRole("heading", { name: `Testteam F1F1 ${width}` })).toBeVisible();
    await page.getByTestId("day-plan-switch").click();
    await expect(page.getByRole("button", { name: "Tag vorschlagen" })).toBeVisible();
    await page.getByLabel("Tag", { exact: true }).fill(day);
    await page.getByRole("button", { name: "Tag vorschlagen" }).click();
    await page.waitForURL(new RegExp(`datum=${day}`));
    const lines = page.getByTestId("day-plan-line");
    await expect(lines).toHaveCount(2);

    // 2. 12:00 (the pause) is not hers: it is proposed for the colleague with free capacity (negative case).
    const line1200 = lines.filter({ hasText: "12:00" });
    const line2030 = lines.filter({ hasText: "20:30" });
    const memberOf = (line: typeof line1200) => page.getByTestId("day-plan-member").filter({ has: line });
    await expect(memberOf(line1200)).toHaveCount(1);
    await expect(line1200.getByTestId("day-plan-reason")).toHaveText("freie Kapazität");
    // 3. 20:30 (after block 2) is hers as primary nurse (positive case); the two lines sit with different people.
    await expect(line2030.getByTestId("day-plan-reason")).toHaveText("Bezugspflegende");
    const holder = await memberOf(line2030).getByRole("heading").textContent();
    const other = await memberOf(line1200).getByRole("heading").textContent();
    expect(holder).not.toBe(other);
    await expect(memberOf(line2030).getByTestId("day-plan-line").filter({ hasText: "12:00" })).toHaveCount(0);
    await noSideScroll(page);

    // 4. Both lines are confirmed as proposed: no «overlap» refusal; the take stays live.
    await line1200.getByRole("button", { name: "Bestätigen", exact: true }).click();
    await expect(line1200.getByTestId("day-plan-decision")).toHaveText("bestätigt");
    await line2030.getByRole("button", { name: "Bestätigen", exact: true }).click();
    await expect(line2030.getByTestId("day-plan-decision")).toHaveText("bestätigt");
    await expect(page.getByTestId("day-plan-refusal")).toHaveCount(0);
    expect(responsible("12:00")).toBe(COLLEAGUE);
    expect(responsible("20:30")).toBe(NURSE);
    expect(live()).toBe("1");
    await noSideScroll(page);
  });
}
