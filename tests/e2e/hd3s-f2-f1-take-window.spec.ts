import { execFileSync } from "node:child_process";
import { expect, test, type Page } from "@playwright/test";
import { zurichDay } from "./support/durchgang-time";
import { addDays, weekStart } from "@/features/home-plan/rules";
import { workDateLabel } from "@/features/team/take-window";

// HD-3s-F2-F1 e2e (brief docs/agents/briefs/HD-3s-F2-F1.md criterion «e2e 390 und 1440 px»; `cra` CGR-289; ADR-230;
// migration 0185): pflegebs holds a live split take 07:00–11:30 und 16:00–20:00 of «Testheim Rhein». Her colleague in
// Testteam Basel plans a hand visit for her at 12:00–13:00 (the pause): the form already reads her as busy, the save is
// rejected with the take named (date, both blocks, the home), nothing is saved and the take stays live. Negative: the
// same visit at 20:00–20:30 (after block 2) is saved. Fixed, checkable rules, no AI. Synthetic local accounts only.
// Fixture (local database only): the split order is prepared, sent and taken through the real commands as the home lead
// and as pflegebs (the UI of that path is the HD-3s-F2 spec); a synthetic case «Testfall F1 <width>» in Testteam Basel
// (copy of seed case …208; an RFC 4122 variant id, the app validates ids with z.uuid()). Weeks 23 and 24 ahead, Thursday: no other spec uses them (hd3s-f2 20–21, hd3s 17).
const PASSWORD = "navora-local-only";
const PLANNER = "kolleginbs.test@navora.test";
const LEAD = "00000000-0000-4000-a000-0000000009e8"; // kundebs, lead of «Testheim Rhein»
const NURSE = "00000000-0000-4000-a000-0000000009e6"; // pflegebs, Testteam Basel
const TEAM = "00000000-0000-4000-a000-0000000001b9";
const ORG = "00000000-0000-4000-b000-000000000019";
const INST = "00000000-0000-4000-a000-0000000004c1";
const CODE = "GF3";
const DB_URL = process.env.E2E_DB_URL ?? "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
const LOCAL_DB = /^postgres(ql)?:\/\/[^@]+@(127\.0\.0\.1|localhost):54322\//;
const BOTH = "07:00 – 11:30 und 16:00 – 20:00";

function psql(sql: string): string {
  if (!LOCAL_DB.test(DB_URL)) throw new Error("HD-3s-F2-F1 fixture: only the local Supabase database (port 54322)");
  return execFileSync("psql", [DB_URL, "-X", "-q", "-At", "-v", "ON_ERROR_STOP=1", "-c", sql], { encoding: "utf8" }).trim();
}

/** Runs one command as a user (claims + role authenticated, as PostgREST), returns its jsonb result as text. */
function as(user: string, call: string): string {
  if (!LOCAL_DB.test(DB_URL)) throw new Error("HD-3s-F2-F1 fixture: only the local Supabase database (port 54322)");
  const out = execFileSync("psql", [DB_URL, "-X", "-q", "-At", "-v", "ON_ERROR_STOP=1",
    "-c", `select set_config('request.jwt.claims', json_build_object('sub', '${user}', 'role', 'authenticated')::text, false),
                  set_config('request.jwt.claim.sub', '${user}', false)`,
    "-c", "set role authenticated",
    "-c", `select (${call})::text`], { encoding: "utf8" }).trim().split("\n");
  return out[out.length - 1];
}

function splitTake(day: string, width: number): string {
  psql(`insert into public.institution_shift_types (institution_id, code, label, starts_at, block1_ends_at, block2_starts_at,
          ends_at, shift_class, sort)
        values ('${INST}', '${CODE}', 'Geteilt F1', '07:00', '11:30', '16:00', '20:00', 'split', 91)
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
  const took = JSON.parse(as(NURSE, `public.take_order('${sent.order_id}', '${TEAM}', '${NURSE}', gen_random_uuid())`));
  expect(took.result, `take ${JSON.stringify(took)}`).toBe("ok");
  // The case the colleague plans for (needs assessment done, no automatic plan), one per width.
  const caseId = `00000000-0000-4000-8185-00000000${String(width).padStart(4, "0")}`;
  psql(`insert into public.cases
        select (jsonb_populate_record(k, jsonb_build_object('id', '${caseId}', 'organization_id', '${ORG}',
          'assigned_team_id', '${TEAM}', 'first_name', 'Testfall', 'last_name', 'F1 ${width}', 'auto_planning', false,
          'primary_nurse_id', null, 'deputy_nurse_id', null, 'proposed_primary_nurse_id', null, 'previous_case_id', null,
          'source_partner_request_id', null))).*
        from public.cases k where k.id = '00000000-0000-4000-a000-000000000208'
        on conflict (id) do nothing`);
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

for (const [width, days] of [[1440, 161], [390, 168]] as const) {
  test(`HD-3s-F2-F1 at ${width} px: a hand visit in the pause of her split take is rejected with the take named; after block 2 it saves`, async ({ page }) => {
    test.setTimeout(180_000);
    const thu = addDays(weekStart(addDays(zurichDay(), days)), 3);
    const orderId = splitTake(thu, width);
    const live = () => psql(`select count(*) from public.order_takes where order_id = '${orderId}' and member_id = '${NURSE}'
                               and released_at is null`);
    const visitsOfCase = () => psql(`select count(*) from public.care_visits
                                       where case_id = '00000000-0000-4000-8185-00000000${String(width).padStart(4, "0")}'`);
    expect(live()).toBe("1");

    // 1. The colleague opens the case and plans 12:00–13:00 for pflegebs: the form reads her as busy (CGR-289 (b)).
    await page.setViewportSize({ width, height: 900 });
    await signIn(page, PLANNER);
    await page.goto("/team");
    const card = page.getByRole("article", { name: new RegExp(`Fall Testfall F1 ${width}`) });
    await card.getByRole("button", { name: "Einsatz planen" }).click();
    const form = card.getByRole("form", { name: "Einsatz planen" });
    await form.getByLabel("Datum").fill(thu);
    await form.getByLabel("Von").fill("12:00");
    await form.getByLabel("Bis").fill("13:00");
    await form.getByLabel("A", { exact: true }).fill("30");
    await form.getByLabel("Verantwortlich").selectOption(NURSE);
    const note = form.getByTestId("member-overlap-note");
    await expect(note).toHaveAttribute("data-read", "yes");
    await expect(note).toContainText("hat zu dieser Zeit schon einen Einsatz");

    // 2. The save is rejected with the take named (PO decision CGR-289 (c)); nothing is saved; the take stays live.
    await form.getByRole("button", { name: "Einsatz speichern" }).click();
    const reason = form.getByTestId("command-error");
    await expect(reason).toContainText(
      `Nicht gespeichert: Die verantwortliche Person hat am ${workDateLabel(thu)} eine laufende geteilte Übernahme für Testheim Rhein (synthetisch): ${BOTH}.`,
    );
    await expect(reason).toContainText("Die Pause zwischen den Blöcken gilt als belegt.");
    await noSideScroll(page);
    expect(visitsOfCase()).toBe("0");
    expect(live()).toBe("1");
    // The rejection keeps what she entered (no form reset): she changes only the time.
    await expect(form.getByLabel("Datum")).toHaveValue(thu);
    await expect(form.getByLabel("Verantwortlich")).toHaveValue(NURSE);
    await expect(form.getByLabel("A", { exact: true })).toHaveValue("30");

    // 3. Negative: after block 2 (20:00–20:30) the same visit is saved and listed; the take is still live.
    await form.getByLabel("Von").fill("20:00");
    await form.getByLabel("Bis").fill("20:30");
    await expect(note).toHaveAttribute("data-read", "yes");
    await expect(note).not.toContainText("hat zu dieser Zeit schon einen Einsatz");
    await form.getByRole("button", { name: "Einsatz speichern" }).click();
    await expect(card.getByRole("list", { name: "Geplante Einsätze" })).toContainText("20:00–20:30");
    expect(visitsOfCase()).toBe("1");
    expect(live()).toBe("1");
    await noSideScroll(page);
  });
}
