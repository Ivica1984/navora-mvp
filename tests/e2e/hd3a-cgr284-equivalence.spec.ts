import { expect, test } from "@playwright/test";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { zurichDay } from "./support/durchgang-time";
import { verifyDraft, type DraftShiftType } from "@/features/home-plan/draft";
import {
  applyOutcome,
  draftInputFromPlan,
  readDraftPlan,
  rowsFormValue,
  sortRows,
  timedDraft,
  type DraftPlan,
} from "@/features/home-plan/draft-screen";
import { addDays, cellKey, monthEnd, monthStart } from "@/features/home-plan/rules";

// HD-3a CGR-284 (b) (brief HD.md §5b; PO choice (A) 2026-11-25 14:39; review R-9-1 on #1729): «nach der Übernahme stimmt
// für jede Zelle der vom Solver vorhergesagte Zustand mit `institution_plan` überein», on a 60-person month.
//
// One chain, no copy of any rule: the home is built only through its own commands (as its lead, RLS and LEAVE1 in
// force); the plan is read through `readDraftPlan` (the same path as the screen), mapped by `draftInputFromPlan`, solved
// by `buildDraft` and sent as the form sends it (`rowsFormValue(sortRows(...))`) to `institution_apply_draft`. Then
// `institution_plan` is read again and every cell of the month is compared with the solver's `predicted` state. A
// change to the SQL cell rule, the mapping, the solver or the apply path breaks this test.
//
// Synthetic only: «Testheim Sechzig (synthetisch)» (seed, empty) and its lead heim60.test; the values below are made up
// by a seeded generator, not taken from any person or home. No browser: the screen of this flow is covered by
// hd3a-draft-screen.spec.ts. Fixed, checkable rules, no AI model.
const PASSWORD = "navora-local-only";
const LEAD = "heim60.test@navora.test";
const HOME = "00000000-0000-4000-a000-0000000004c2";
const PERSONS = 60;

async function asLead(): Promise<SupabaseClient> {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_ANON_KEY;
  if (!url || !key) throw new Error("SUPABASE_URL and SUPABASE_ANON_KEY of the local stack are needed for CGR-284 (b)");
  const db = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  const { error } = await db.auth.signInWithPassword({ email: LEAD, password: PASSWORD });
  if (error) throw new Error(`sign-in of ${LEAD} failed: ${error.message}`);
  return db;
}

/** A small seeded generator (mulberry32): the same home on every run, no clock and no Math.random. */
function prng(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

async function call(db: SupabaseClient, fn: string, args: Record<string, unknown>): Promise<Record<string, unknown>> {
  const { data, error } = await db.rpc(fn, args);
  if (error) throw new Error(`${fn}: ${error.message}`);
  const r = (data ?? {}) as Record<string, unknown>;
  if (r.result !== "ok") throw new Error(`${fn}: ${JSON.stringify(r)}`);
  return r;
}

async function readPlan(db: SupabaseClient, from: string, to: string): Promise<DraftPlan | null> {
  const { data, error } = await db.rpc("institution_plan", { p_institution_id: HOME, p_from: from, p_to: to });
  if (error || !data) return null;
  return data as DraftPlan;
}

/** Builds the 60-person home once per database through the home's own commands. */
async function buildHome(db: SupabaseClient, from: string, to: string): Promise<void> {
  const rnd = prng(284);
  const pickOf = <T,>(xs: ReadonlyArray<T>): T => xs[Math.floor(rnd() * xs.length)];

  // HD-3a-F1 R-6-2 (b) (0188): the commands take the values shown before the change; here the home's current ones.
  const shown = (await readPlan(db, from, from))?.institution;
  if (!shown) throw new Error("institution_plan: no home");
  await call(db, "institution_set_planning_limits", {
    p_institution_id: HOME, p_min_rest_hours: 11, p_max_consecutive_days: 6, p_weekly_target_hours: 42,
    p_expected: { min_rest_hours: shown.min_rest_hours, max_consecutive_days: shown.max_consecutive_days,
      weekly_target_hours: shown.weekly_target_hours ?? null },
  });
  const stations: string[] = [];
  for (const name of ["Station A", "Station B", "Station C"]) {
    stations.push((await call(db, "institution_add_station", { p_institution_id: HOME, p_name: name })).station_id as string);
  }
  const types: Array<{ id: string; total: number }> = [];
  for (const [code, label, starts, ends, cls, total] of [
    ["F", "Früh", "07:00", "15:30", "early", 3],
    ["S", "Spät", "14:30", "23:00", "late", 3],
    ["N", "Nacht", "22:00", "07:00", "night", 2],
  ] as const) {
    const id = (await call(db, "institution_set_shift_type", {
      p_institution_id: HOME, p_code: code, p_label: label, p_starts_at: starts, p_ends_at: ends,
    })).shift_type_id as string;
    await call(db, "institution_set_shift_class", { p_shift_type_id: id, p_shift_class: cls, p_expected: { shift_class: null } });
    types.push({ id, total });
  }
  for (const s of stations) {
    for (const t of types) {
      await call(db, "institution_set_staffing_rule", {
        p_institution_id: HOME, p_station_id: s, p_shift_type_id: t.id, p_required_total: t.total,
        p_required_grade: "nurse_hf_fh", p_required_grade_count: 1,
      });
    }
  }
  const grades = ["nurse_hf_fh", "fage_efz", "ags_eba"] as const;
  const days: string[] = [];
  for (let d = from; d <= to; d = addDays(d, 1)) days.push(d);
  for (let i = 0; i < PERSONS; i++) {
    const grade = i < 16 ? grades[0] : i < 40 ? grades[1] : grades[2];
    const staffId = (await call(db, "institution_add_staff", {
      p_institution_id: HOME, p_display_name: `Person ${String(i + 1).padStart(2, "0")} (synthetisch)`,
      p_grade: grade, p_home_station_id: stations[i % stations.length],
    })).staff_id as string;
    // The last person stays «nicht eingetragen» (R-b: never planned); the rest get a made-up Pensum and model.
    const pensum = i === PERSONS - 1 ? null : pickOf([40, 50, 60, 80, 80, 90, 100, 100]);
    const model = rnd() < 0.6 ? "any" : pickOf(["early_only", "late_only", "night_only", "no_night"]);
    await call(db, "institution_set_staff_planning", {
      p_staff_id: staffId, p_pensum_pct: pensum, p_shift_model: model, p_expected: { pensum_pct: null, shift_model: "any" },
    });
    if (rnd() < 0.2) {
      const start = pickOf(days);
      const end = addDays(start, Math.floor(rnd() * 5));
      await call(db, "institution_record_absence", {
        p_institution_id: HOME, p_staff_id: staffId, p_starts_on: start, p_ends_on: end,
        p_kind: pickOf(["vacation", "training", "compensation", "absent"]),
      });
    }
    if (rnd() < 0.25) {
      const work = 1 + Math.floor(rnd() * 7);
      const off = ((work + 2) % 7) + 1;
      await call(db, "institution_set_staff_wishes", {
        p_staff_id: staffId,
        p_wishes: [
          { weekday: work, kind: "work", shift_type_id: pickOf(types).id },
          { weekday: off, kind: "off", shift_type_id: null },
        ],
      });
    }
  }
}

test("HD-3a CGR-284 (b): after «übernehmen», every cell of a 60-person month is in the state the solver predicted", async () => {
  test.setTimeout(240_000);
  const db = await asLead();
  // A month far ahead (no other spec plans in this home); whole month, at most 31 days (0177 `period_too_long`).
  const from = monthStart(addDays(zurichDay(), 120));
  const to = monthEnd(from);

  const before = await readPlan(db, from, to);
  expect(before, "the lead reads her home").not.toBeNull();
  const fresh = before!.staff.length === 0;
  if (fresh) await buildHome(db, from, to);

  // 1. Read and solve exactly as the screen does.
  const plan = await readDraftPlan((a, b) => readPlan(db, a, b), from, to);
  expect(plan).not.toBeNull();
  expect(plan!.staff.length).toBe(PERSONS);
  const input = draftInputFromPlan(plan!, from, to);
  expect(input, "the home's limits are entered, so a draft exists").not.toBeNull();
  const { result, ms } = timedDraft(input!);
  expect(result.result).toBe("ok");
  if (result.result !== "ok") return;
  expect(verifyDraft(input!, result.rows), "the draft breaks no hard rule").toEqual([]);
  const withoutPensum = plan!.staff.filter((s) => s.pensum_pct == null).map((s) => s.id);
  expect(withoutPensum.length).toBe(1);
  expect(result.rows.some((r) => withoutPensum.includes(r.staff_id)), "a person without Pensum is never planned").toBe(false);
  if (fresh) {
    expect(result.rows.length).toBeGreaterThan(100);
    expect(result.predicted.some((c) => c.status === "gap"), "the made-up month has gaps").toBe(true);
    expect(result.predicted.some((c) => c.status === "ok")).toBe(true);
  }
  const types = new Map((plan!.shift_types as DraftShiftType[]).map((t) => [t.id, t]));
  const ruled = plan!.cells.filter((c) => c.date >= from && c.date <= to && c.required_total !== null && types.has(c.shift_type_id));
  expect(result.predicted.length, "one prediction per ruled cell of the month").toBe(ruled.length);

  // 2. «übernehmen»: the form value, as the screen sends it; the database decides every row.
  const rows = JSON.parse(rowsFormValue(sortRows(result.rows, plan!)));
  const { data: applied, error } = await db.rpc("institution_apply_draft", {
    p_institution_id: HOME, p_apply_id: crypto.randomUUID(), p_rows: rows,
  });
  expect(error, error?.message).toBeNull();
  const outcome = applyOutcome(applied);
  expect((applied as { refused?: unknown[] }).refused ?? [], "no row is refused").toEqual([]);
  expect(outcome).toEqual({ code: "draft_applied", applied: rows.length, refused: 0 });

  // 3. Every cell of the month: the database state equals the prediction (CGR-284 (b)).
  const after = await readPlan(db, from, to);
  expect(after).not.toBeNull();
  const state = new Map(after!.cells.map((c) => [cellKey(c.date, c.station_id, c.shift_type_id), c]));
  const differences: string[] = [];
  for (const p of result.predicted) {
    const c = state.get(cellKey(p.date, p.station_id, p.shift_type_id));
    if (!c || c.status !== p.status) differences.push(`${p.date} ${p.station_id} ${p.shift_type_id}: predicted ${p.status}, database ${c?.status ?? "none"}`);
  }
  expect(differences).toEqual([]);
  // Each gap the solver names is a gap in the database, with the same number of missing persons (CGR-284 (c)).
  for (const g of result.gaps.filter((x) => x.kind === "unfilled")) {
    const c = state.get(cellKey(g.date, g.station_id, g.shift_type_id))!;
    expect(c.status).toBe("gap");
    expect(c.missing, `${g.date} missing persons`).toBe(g.missing_total);
  }
  // Every saved row is in the plan, in its cell.
  const placed = new Set(after!.cells.flatMap((c) => c.assigned.map((a) => `${cellKey(c.date, c.station_id, c.shift_type_id)}|${a.staff_id}`)));
  for (const r of rows) expect(placed.has(`${cellKey(r.date, r.station_id, r.shift_type_id)}|${r.staff_id}`)).toBe(true);

  // §5a M2 (CI-runner time, labelled as such; not a gate): solver time for the 60-person month.
  test.info().annotations.push({ type: "M2 solver ms (CI runner)", description: String(ms) });
  console.log(`CGR-284 (b): ${rows.length} rows applied, ${result.predicted.length} cells compared, ${result.gaps.length} gaps, solver ${ms} ms (CI runner)`);
});
