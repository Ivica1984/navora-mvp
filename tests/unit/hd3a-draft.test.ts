// HD-3a slice 2 (ADR-224 rev. 2, brief HD.md §5b acceptance): the rule-based draft. Synthetic data only.
// Contract tests: no pair < 11 h rest, nobody over Pensum, `no_night` never at night, an absence never planned over,
// determinism, an unsolvable month gives gaps with reasons and 0 violations, runtime for 60 persons and a month.
import { describe, expect, it } from "vitest";
import {
  buildDraft,
  draftContextRange,
  gapReasonText,
  fullTimeMinutes,
  modelAllows,
  shiftSpan,
  verifyDraft,
  SHIFT_CLASSES,
  SHIFT_MODELS,
  DRAFT_MARK,
  WORKING_TIME_LAW_MARK,
  type DraftInput,
  type DraftRow,
  type DraftShiftType,
  type DraftStaff,
  type DraftWish,
  type ShiftModel,
  isoWeekday,
  unmetWishReasonText,
} from "@/features/home-plan/draft";
import { addDays, gradeLabel, type Absence, type AssignedPerson, type PlanCell } from "@/features/home-plan/rules";

const HF = "nurse_hf_fh";
const FAGE = "fage_efz";
const AGS = "ags_eba";
const TYPES: DraftShiftType[] = [
  { id: "t1-early", code: "F", label: "Früh", starts_at: "07:00", ends_at: "15:30", shift_class: "early" },
  { id: "t2-late", code: "S", label: "Spät", starts_at: "14:30", ends_at: "23:00", shift_class: "late" },
  { id: "t3-night", code: "N", label: "Nacht", starts_at: "22:45", ends_at: "07:15", shift_class: "night" },
];
const LIMITS = { minRestHours: 11, maxConsecutiveDays: 6, fullTimeMinutesPerWeek: 42 * 60 };

function rng(seed: number) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function person(id: string, grade: string, over: Partial<DraftStaff> = {}): DraftStaff {
  return { id, display_name: id, grade, home_station_id: null, active: true, pensum_pct: 100, shift_model: "any", ...over };
}

type Fixture = {
  from: string;
  to: string;
  stations: string[];
  types?: DraftShiftType[];
  staff: DraftStaff[];
  absences?: Absence[];
  rule?: { total: number; grade: string | null; gradeCount: number } | null;
  existing?: Array<{ date: string; station: string; type: string; staff: string }>;
  limits?: Partial<DraftInput["limits"]>;
  wishes?: DraftWish[];
};

function input(f: Fixture): DraftInput {
  const types = f.types ?? TYPES;
  const limits = { ...LIMITS, ...f.limits };
  const ctx = draftContextRange(f.from, f.to, limits);
  const absences = f.absences ?? [];
  const staff = new Map(f.staff.map((s) => [s.id, s]));
  const cells: PlanCell[] = [];
  const rule = f.rule === undefined ? { total: 2, grade: HF, gradeCount: 1 } : f.rule;
  let n = 0;
  for (let d = ctx.from; d <= ctx.to; d = addDays(d, 1)) {
    for (const st of f.stations) {
      for (const t of types) {
        const assigned: AssignedPerson[] = (f.existing ?? [])
          .filter((e) => e.date === d && e.station === st && e.type === t.id)
          .map((e) => {
            const p = staff.get(e.staff)!;
            const ab = absences.some((a) => a.staff_id === p.id && a.starts_on <= d && a.ends_on >= d);
            return { assignment_id: `a${n++}`, staff_id: p.id, display_name: p.id, grade: p.grade, absent: ab, inactive: !p.active };
          });
        const counted = assigned.filter((a) => !a.absent && !a.inactive);
        const present = counted.length;
        const gradePresent = counted.filter((a) => a.grade === rule?.grade).length;
        const status = !rule ? "no_rule" : present >= rule.total && gradePresent >= rule.gradeCount ? "ok" : "gap";
        cells.push({
          date: d,
          station_id: st,
          shift_type_id: t.id,
          required_total: rule ? rule.total : null,
          required_grade: rule ? rule.grade : null,
          required_grade_count: rule ? rule.gradeCount : 0,
          example: true,
          assigned,
          present,
          grade_present: gradePresent,
          missing: rule ? Math.max(rule.total - present, 0) : 0,
          status,
          external_covered: 0,
          order: null,
        });
      }
    }
  }
  return { from: f.from, to: f.to, shiftTypes: types, staff: f.staff, absences, cells, limits, wishes: f.wishes };
}

function ok(i: DraftInput) {
  const r = buildDraft(i);
  if (r.result !== "ok") throw new Error(r.result);
  return r;
}

function randomFixture(seed: number, persons = 20, days = 14, stations = 2): Fixture {
  const r = rng(seed);
  const grades = [HF, FAGE, AGS];
  const models: ShiftModel[] = ["any", "any", "any", "early_only", "late_only", "night_only", "no_night"];
  const from = "2026-12-01";
  const to = addDays(from, days - 1);
  const staff: DraftStaff[] = [];
  for (let i = 0; i < persons; i++) {
    staff.push(
      person(`p${String(i).padStart(2, "0")}`, grades[Math.floor(r() * 3)], {
        pensum_pct: r() < 0.08 ? null : [40, 50, 60, 80, 90, 100][Math.floor(r() * 6)],
        shift_model: models[Math.floor(r() * models.length)],
        active: r() > 0.05,
      }),
    );
  }
  const absences: Absence[] = [];
  for (const s of staff) {
    if (r() < 0.3) {
      const start = addDays(from, Math.floor(r() * days) - 2);
      absences.push({ id: `ab-${s.id}`, staff_id: s.id, starts_on: start, ends_on: addDays(start, Math.floor(r() * 5)) });
    }
  }
  const st = Array.from({ length: stations }, (_, i) => `st${i}`);
  // Existing assignments, also before and inside the period (some may break a rule: they are the home's, Q3).
  const existing: Fixture["existing"] = [];
  for (let k = 0; k < persons; k++) {
    const date = addDays(from, Math.floor(r() * (days + 6)) - 6);
    existing.push({ date, station: st[Math.floor(r() * stations)], type: TYPES[Math.floor(r() * 3)].id, staff: staff[k].id });
  }
  return { from, to, stations: st, staff, absences, existing };
}

describe("HD-3a draft: marks and fail closed", () => {
  it("pins the two screen marks", () => {
    expect(DRAFT_MARK).toBe("Optimierung (feste Regeln)");
    expect(WORKING_TIME_LAW_MARK).toBe("Arbeitszeitgesetz nicht abschliessend geprüft");
  });
  it("reads the home's weekly target hours as the full-time reference, fail closed when missing (Q1, FE-123)", () => {
    expect(fullTimeMinutes(42)).toBe(2520);
    expect(fullTimeMinutes(41.5)).toBe(2490);
    expect(fullTimeMinutes(null)).toBeNull();
    expect(fullTimeMinutes(undefined)).toBeNull();
    expect(fullTimeMinutes(0)).toBeNull();
    expect(fullTimeMinutes(-5)).toBeNull();
    expect(fullTimeMinutes(Number.NaN)).toBeNull();
  });

  it("HD-3a-F1 parity (AUT-241): a fresh draft holds no row «übernehmen» refuses for Pensum or Wochensoll", () => {
    // The database refuses a row `pensum_missing` (person without Pensum) and the whole call `weekly_target_missing`
    // (migration 0186). The draft reads the same two inputs: on unchanged inputs a fresh proposal has 0 such refusals.
    const staff = [person("a", HF), person("b", FAGE, { pensum_pct: null }), person("c", AGS), person("d", HF, { pensum_pct: null })];
    const r = buildDraft(input({ from: "2026-12-01", to: "2026-12-28", stations: ["st0", "st1"], staff }));
    expect(r.result).toBe("ok");
    if (r.result !== "ok") return;
    expect(r.rows.length).toBeGreaterThan(0);
    const noPensum = new Set(staff.filter((s) => s.pensum_pct === null).map((s) => s.id));
    expect(r.rows.filter((row) => noPensum.has(row.staff_id))).toEqual([]);
    expect(buildDraft(input({ from: "2026-12-01", to: "2026-12-07", stations: ["st0"], staff, limits: { fullTimeMinutesPerWeek: null } })))
      .toEqual({ result: "pensum_reference_missing" });
  });

  it("refuses to draft without the full-time reference (Q1)", () => {
    const i = input({ from: "2026-12-01", to: "2026-12-07", stations: ["st0"], staff: [person("a", HF)], limits: { fullTimeMinutesPerWeek: null } });
    expect(buildDraft(i)).toEqual({ result: "pensum_reference_missing" });
  });
});

describe("HD-3a draft: hard rules", () => {
  it("never plans a pair with less than 11 h rest, also across the period start", () => {
    // `a` worked the late shift the evening before the period (ends 23:00); the early shift at 07:00 is 8 h later.
    const i = input({
      from: "2026-12-02",
      to: "2026-12-02",
      stations: ["st0"],
      types: [TYPES[0], TYPES[1]],
      rule: { total: 1, grade: null, gradeCount: 0 },
      staff: [person("a", HF), person("b", HF)],
      existing: [{ date: "2026-12-01", station: "st0", type: TYPES[1].id, staff: "a" }],
    });
    const r = ok(i);
    // Early 2.12.: only `b` (a has 8 h rest). Late 2.12.: only `a` (b's early shift overlaps; a has 15.5 h rest).
    expect(r.rows).toEqual([
      { date: "2026-12-02", station_id: "st0", shift_type_id: TYPES[0].id, staff_id: "b" },
      { date: "2026-12-02", station_id: "st0", shift_type_id: TYPES[1].id, staff_id: "a" },
    ]);
    expect(verifyDraft(i, r.rows)).toEqual([]);
    // A forced row with 8 h rest is caught by the independent check.
    expect(verifyDraft(i, [{ ...r.rows[0], staff_id: "a" }]).map((v) => v.rule)).toContain("rest");
  });

  it("never plans anyone over the Pensum of an ISO week", () => {
    // 50 % of 42 h = 21 h = 1260 min per week; an early shift is 510 min, so at most 2 per week.
    const i = input({
      from: "2026-11-30",
      to: "2026-12-13",
      stations: ["st0"],
      types: [TYPES[0]],
      rule: { total: 1, grade: null, gradeCount: 0 },
      staff: [person("a", FAGE, { pensum_pct: 50 })],
    });
    const r = ok(i);
    expect(r.rows).toHaveLength(4);
    expect(verifyDraft(i, r.rows)).toEqual([]);
    expect(r.gaps.filter((g) => g.kind === "unfilled")).toHaveLength(10);
    expect(r.gaps.every((g) => g.blocked.pensum_full === 1)).toBe(true);
  });

  it("never places `no_night` on a night shift, nor a restricted model on an unclassified type", () => {
    const unclassified: DraftShiftType = { id: "t9-x", code: "X", label: "Zwischendienst", starts_at: "10:00", ends_at: "18:00", shift_class: null };
    const i = input({
      from: "2026-12-01",
      to: "2026-12-07",
      stations: ["st0"],
      types: [TYPES[2], unclassified],
      rule: { total: 1, grade: null, gradeCount: 0 },
      staff: [person("n", AGS, { shift_model: "no_night" }), person("d", AGS, { shift_model: "early_only" })],
    });
    const r = ok(i);
    expect(r.rows).toEqual([]);
    expect(r.gaps.every((g) => g.blocked.shift_model === 2)).toBe(true);
    const anyone = { ...i, staff: [...i.staff, person("z", AGS)] };
    const r2 = ok(anyone);
    expect(r2.rows.length).toBeGreaterThan(0);
    expect(r2.rows.every((x) => x.staff_id === "z")).toBe(true);
    expect(verifyDraft(anyone, r2.rows)).toEqual([]);
  });

  it("never places `early_only` on a late or night shift, and fills its early shifts (FE-123)", () => {
    const i = input({
      from: "2026-12-01",
      to: "2026-12-03",
      stations: ["st0"],
      rule: { total: 1, grade: null, gradeCount: 0 },
      staff: [person("e", AGS, { shift_model: "early_only" })],
    });
    const r = ok(i);
    expect(verifyDraft(i, r.rows)).toEqual([]);
    expect(r.rows.length).toBeGreaterThan(0);
    expect(r.rows.every((x) => x.shift_type_id === "t1-early")).toBe(true);
    const lateOrNight = r.gaps.filter((g) => g.shift_type_id !== "t1-early");
    expect(lateOrNight.length).toBe(6);
    expect(lateOrNight.every((g) => g.blocked.shift_model === 1)).toBe(true);
  });

  it("has no day class and no `day_only` model any more (FE-123 forward migration)", () => {
    // HD-3s (brief HD-3s.md scope 1): `split` is the class of a shift with two blocks; still no day class.
    expect([...SHIFT_CLASSES]).toEqual(["early", "late", "night", "split"]);
    expect(SHIFT_CLASSES as ReadonlyArray<string>).not.toContain("day");
    expect([...SHIFT_MODELS]).toEqual(["any", "early_only", "late_only", "night_only", "no_night"]);
    expect(modelAllows("early_only", "early")).toBe(true);
    expect(modelAllows("early_only", "late")).toBe(false);
    expect(modelAllows("early_only", "night")).toBe(false);
    expect(modelAllows("no_night", "night")).toBe(false);
    expect(modelAllows("no_night", "late")).toBe(true);
    for (const m of SHIFT_MODELS) if (m !== "any") expect(modelAllows(m, null)).toBe(false);
    expect(modelAllows("any", null)).toBe(true);
  });

  it("never plans over an absence, also not the night into an absence day", () => {
    const i = input({
      from: "2026-12-01",
      to: "2026-12-03",
      stations: ["st0"],
      types: [TYPES[2]],
      rule: { total: 1, grade: null, gradeCount: 0 },
      staff: [person("a", HF)],
      absences: [{ id: "x", staff_id: "a", starts_on: "2026-12-02", ends_on: "2026-12-02" }],
    });
    const r = ok(i);
    // Night of 1.12. ends on 2.12. (absence) and the night of 2.12. starts on it: only 3.12. is free.
    expect(r.rows.map((x) => x.date)).toEqual(["2026-12-03"]);
    expect(verifyDraft(i, r.rows)).toEqual([]);
    expect(verifyDraft(i, [{ ...r.rows[0], date: "2026-12-01" }]).map((v) => v.rule)).toContain("absent");
  });

  it("stops after 6 working days in a row", () => {
    const i = input({
      from: "2026-12-01",
      to: "2026-12-14",
      stations: ["st0"],
      types: [TYPES[0]],
      rule: { total: 1, grade: null, gradeCount: 0 },
      staff: [person("a", FAGE)],
      limits: { fullTimeMinutesPerWeek: 7 * 24 * 60 },
    });
    const r = ok(i);
    expect(verifyDraft(i, r.rows)).toEqual([]);
    const dates = new Set(r.rows.map((x) => x.date));
    let run = 0;
    let longest = 0;
    for (let d = i.from; d <= i.to; d = addDays(d, 1)) {
      run = dates.has(d) ? run + 1 : 0;
      longest = Math.max(longest, run);
    }
    expect(longest).toBe(6);
    expect(r.gaps.some((g) => g.blocked.consecutive === 1)).toBe(true);
  });

  it("keeps existing assignments and never fills an inactive person", () => {
    const i = input({
      from: "2026-12-01",
      to: "2026-12-01",
      stations: ["st0"],
      types: [TYPES[0]],
      staff: [person("hf", HF), person("off", FAGE, { active: false }), person("f", FAGE)],
      existing: [{ date: "2026-12-01", station: "st0", type: TYPES[0].id, staff: "hf" }],
    });
    const r = ok(i);
    expect(r.rows).toEqual([{ date: "2026-12-01", station_id: "st0", shift_type_id: TYPES[0].id, staff_id: "f" }]);
    expect(r.predicted).toEqual([{ date: "2026-12-01", station_id: "st0", shift_type_id: TYPES[0].id, status: "ok" }]);
  });

  it("leaves a cell with an active external order to that order", () => {
    const i = input({ from: "2026-12-01", to: "2026-12-01", stations: ["st0"], types: [TYPES[0]], staff: [person("a", HF), person("b", FAGE)] });
    i.cells = i.cells.map((c) =>
      c.date === "2026-12-01"
        ? { ...c, order: { gap_order_id: "g", state: "sent", order_id: "o", grade: HF, grade_fixed: true, starts_at: null, cover_state: "open", cover_detail: null, latest_cover_at: null } }
        : c,
    );
    const r = ok(i);
    expect(r.rows).toEqual([]);
    expect(r.gaps).toMatchObject([{ kind: "external_order" }]);
  });
});

describe("HD-3a draft: unsolvable month", () => {
  it("gives gaps with reasons from plan data and 0 violations", () => {
    // One HF for a month, every shift needs one HF: most cells cannot be covered.
    const i = input({
      from: "2026-12-01",
      to: "2026-12-31",
      stations: ["st0"],
      staff: [person("hf", HF), person("f1", FAGE), person("f2", FAGE), person("f3", FAGE)],
      absences: [{ id: "x", staff_id: "hf", starts_on: "2026-12-20", ends_on: "2026-12-27" }],
    });
    const r = ok(i);
    expect(verifyDraft(i, r.rows)).toEqual([]);
    const gaps = r.gaps.filter((g) => g.kind === "unfilled");
    expect(gaps.length).toBeGreaterThan(60);
    for (const g of gaps) {
      expect(Object.values(g.blocked).reduce((a, b) => a + b, 0)).toBe(g.pool_active);
      if (g.missing_grade === 0) {
        expect(gapReasonText(g, gradeLabel)).toMatch(/^\d (Person fehlt|Personen fehlen) – \d aktiv: /);
        continue;
      }
      expect(gapReasonText(g, gradeLabel)).toMatch(/^1 × HF fehlt – 1 aktiv: 1 (abwesend|bereits im Dienst|Ruhezeit zu kurz|zu viele Tage in Folge|Pensum ausgeschöpft)$/);
    }
    expect(gaps.some((g) => g.blocked.absent === 1)).toBe(true);
    // No cell the solver calls ok is short of the rule (no gap shown as «besetzt»).
    const gapIds = new Set(gaps.map((g) => `${g.date}|${g.shift_type_id}`));
    for (const p of r.predicted) expect(p.status === "gap").toBe(gapIds.has(`${p.date}|${p.shift_type_id}`));
  });

  it("words a gap without any person of the grade", () => {
    expect(
      gapReasonText(
        { date: "2026-12-01", station_id: "s", shift_type_id: "t", kind: "unfilled", missing_total: 1, missing_grade: 1, grade: HF, pool_active: 0, blocked: { pensum_missing: 0, shift_model: 0, absent: 0, busy: 0, rest: 0, consecutive: 0, pensum_full: 0, month_target_full: 0 } },
        gradeLabel,
      ),
    ).toBe("1 × HF fehlt – keine aktive Person mit HF");
  });
});

describe("HD-3a draft: properties on random synthetic homes", () => {
  it.each(Array.from({ length: 40 }, (_, k) => k + 1))("seed %i: 0 violations, every gap explained, prediction matches", (seed) => {
    const i = input(randomFixture(seed));
    const r = ok(i);
    expect(verifyDraft(i, r.rows)).toEqual([]);
    for (const g of r.gaps.filter((x) => x.kind === "unfilled")) {
      expect(Object.values(g.blocked).reduce((a, b) => a + b, 0)).toBe(g.pool_active);
    }
    // Recompute the cell rule from the rows, independently of the solver's own counters.
    const staff = new Map(i.staff.map((s) => [s.id, s]));
    for (const p of r.predicted) {
      const c = i.cells.find((x) => x.date === p.date && x.station_id === p.station_id && x.shift_type_id === p.shift_type_id)!;
      const added = r.rows.filter((x) => x.date === p.date && x.station_id === p.station_id && x.shift_type_id === p.shift_type_id);
      const present = c.present + added.length;
      const grade = c.grade_present + added.filter((x) => staff.get(x.staff_id)!.grade === c.required_grade).length;
      expect(p.status).toBe(present >= c.required_total! && grade >= c.required_grade_count ? "ok" : "gap");
    }
  });

  it("is deterministic and independent of input order", () => {
    const f = randomFixture(7);
    const a = buildDraft(input(f));
    const b = buildDraft(input(f));
    const r = rng(99);
    const shuffle = <T,>(xs: T[]) => xs.map((x) => [r(), x] as const).sort((p, q) => p[0] - q[0]).map((p) => p[1]);
    const shuffled = input(f);
    const c = buildDraft({ ...shuffled, staff: shuffle([...shuffled.staff]), cells: shuffle([...shuffled.cells]), absences: shuffle([...shuffled.absences]) });
    expect(b).toEqual(a);
    expect(c).toEqual(a);
  });
});

describe("HD-3a draft: time and runtime", () => {
  it("counts the real length of a night shift across the end of summer time", () => {
    const s = shiftSpan("2026-10-24", "22:45", "07:15");
    expect((s.end - s.start) / 60_000).toBe(510 + 60);
    const w = shiftSpan("2026-12-01", "22:45", "07:15");
    expect((w.end - w.start) / 60_000).toBe(510);
  });

  it("drafts a month for 60 persons, 3 stations x 3 shift types under the 2 s target", () => {
    const f = randomFixture(2026, 60, 31, 3);
    const i = input(f);
    const t0 = performance.now();
    const r = ok(i);
    const ms = performance.now() - t0;
    console.info(`HD-3a draft runtime: ${ms.toFixed(0)} ms, ${r.rows.length} rows, ${r.gaps.length} gaps`);
    expect(ms).toBeLessThan(2000);
    expect(verifyDraft(i, r.rows as DraftRow[])).toEqual([]);
  });
});

// HD-3a slice 2d (FE-125, rule catalogue W-1, W-2, §4): wishes are an order among permitted persons only.
describe("HD-3a draft: wishes per person", () => {
  const MON = "2026-12-07";
  const one = { total: 1, grade: null, gradeCount: 0 };
  const earlyOnly = [TYPES[0]];
  const work = (staff: string, weekday: number, type = "t1-early"): DraftWish => ({ staff_id: staff, weekday, kind: "work", shift_type_id: type });
  const off = (staff: string, weekday: number): DraftWish => ({ staff_id: staff, weekday, kind: "off", shift_type_id: null });

  it("reads ISO weekdays (1 = Monday, 7 = Sunday)", () => {
    expect(isoWeekday("2026-12-07")).toBe(1);
    expect(isoWeekday("2026-12-01")).toBe(2);
    expect(isoWeekday("2026-03-29")).toBe(7);
  });

  it("meets a satisfiable work wish: the wishing person gets the shift instead of the default pick", () => {
    const base: Fixture = { from: MON, to: MON, stations: ["st"], types: earlyOnly, rule: one, staff: [person("a", FAGE), person("b", FAGE)] };
    expect(ok(input(base)).rows.map((r) => r.staff_id)).toEqual(["a"]);
    const r = ok(input({ ...base, wishes: [work("b", 1)] }));
    expect(r.rows.map((x) => x.staff_id)).toEqual(["b"]);
    expect(r.wishes).toEqual({ total: 1, met: 1, unmet: [] });
  });

  it("meets an off wish: somebody else is planned that day", () => {
    const r = ok(input({ from: MON, to: MON, stations: ["st"], types: earlyOnly, rule: one, staff: [person("a", FAGE), person("b", FAGE)], wishes: [off("a", 1)] }));
    expect(r.rows.map((x) => x.staff_id)).toEqual(["b"]);
    expect(r.wishes).toEqual({ total: 1, met: 1, unmet: [] });
  });

  it("minimum staffing wins over an off wish: the person is planned and the wish is listed with its reason", () => {
    const i = input({ from: MON, to: MON, stations: ["st"], types: earlyOnly, rule: { total: 2, grade: null, gradeCount: 0 },
      staff: [person("a", FAGE), person("b", FAGE)], wishes: [off("a", 1)] });
    const r = ok(i);
    expect(r.rows.map((x) => x.staff_id)).toEqual(["a", "b"]);
    expect(r.gaps).toEqual([]);
    expect(r.wishes.unmet).toEqual([{ staff_id: "a", date: MON, kind: "off", shift_type_id: null, reason: "needed_for_staffing" }]);
    expect(unmetWishReasonText(r.wishes.unmet[0])).toBe("für die Mindestbesetzung gebraucht");
    expect(verifyDraft(i, r.rows)).toEqual([]);
  });

  it("never makes a person permitted: a night_only wish for the early shift stays unmet with the rule as reason", () => {
    const i = input({ from: MON, to: MON, stations: ["st"], types: earlyOnly, rule: one,
      staff: [person("a", FAGE), person("b", FAGE, { shift_model: "night_only" })], wishes: [work("b", 1)] });
    const r = ok(i);
    expect(r.rows.map((x) => x.staff_id)).toEqual(["a"]);
    expect(r.wishes.unmet).toEqual([{ staff_id: "b", date: MON, kind: "work", shift_type_id: "t1-early", reason: "shift_model" }]);
    expect(unmetWishReasonText(r.wishes.unmet[0])).toBe("Schichtmodell passt nicht");
  });

  it("lists an unsatisfiable wish with its reason: absence, a full shift, an existing assignment on the day off", () => {
    const r = ok(input({ from: MON, to: addDays(MON, 1), stations: ["st"], types: earlyOnly, rule: one,
      staff: [person("a", FAGE), person("b", FAGE), person("c", FAGE)],
      absences: [{ id: "ab", staff_id: "a", starts_on: MON, ends_on: MON }],
      existing: [{ date: MON, station: "st", type: "t1-early", staff: "c" }, { date: addDays(MON, 1), station: "st", type: "t1-early", staff: "c" }],
      wishes: [work("a", 1), work("b", 2), off("c", 2)] }));
    expect(r.rows).toEqual([]);
    expect(r.wishes.total).toBe(3);
    expect(r.wishes.unmet.map((w) => `${w.staff_id}:${w.reason}`)).toEqual(["a:absent", "b:no_open_place", "c:existing_assignment"]);
  });

  it("a wish on another weekday or outside the period does not count", () => {
    const r = ok(input({ from: MON, to: MON, stations: ["st"], types: earlyOnly, rule: one, staff: [person("a", FAGE)], wishes: [work("a", 3), off("a", 5)] }));
    expect(r.wishes).toEqual({ total: 0, met: 0, unmet: [] });
  });

  it.each(Array.from({ length: 20 }, (_, k) => k + 1))("seed %i: with random wishes 0 violations and every wish accounted", (seed) => {
    const f = randomFixture(seed);
    const r0 = rng(seed + 1000);
    const wishes: DraftWish[] = [];
    for (const s of f.staff) {
      for (let wd = 1; wd <= 7; wd++) {
        const x = r0();
        if (x < 0.15) wishes.push(off(s.id, wd));
        else if (x < 0.4) wishes.push(work(s.id, wd, TYPES[Math.floor(r0() * 3)].id));
      }
    }
    const i = input({ ...f, wishes });
    const r = ok(i);
    expect(verifyDraft(i, r.rows)).toEqual([]);
    expect(r.wishes.met + r.wishes.unmet.length).toBe(r.wishes.total);
    // Shuffled wishes give the same draft (determinism).
    const shuffled = [...wishes].map((w) => [r0(), w] as const).sort((p, q) => p[0] - q[0]).map((p) => p[1]);
    expect(buildDraft({ ...i, wishes: shuffled })).toEqual(r);
  });
});

