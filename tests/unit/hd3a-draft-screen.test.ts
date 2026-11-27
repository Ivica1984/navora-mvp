// HD-3a slice 4 (brief HD.md §5b «Planungslauf: ein Button in Woche und Monat»): the glue between `institution_plan`
// and the solver for «Plan vorschlagen», and the answer of «übernehmen». Synthetic data only; fixed rules, no AI.
import { describe, expect, it } from "vitest";
import { buildDraft, verifyDraft } from "@/features/home-plan/draft";
import {
  PLAN_READ_MAX_DAYS,
  applyOutcome,
  contextRangeFor,
  draftInputFromPlan,
  draftPeriodRange,
  mergePlans,
  planReadChunks,
  readDraftPlan,
  readLimits,
  rowsFormValue,
  sortRows,
  type DraftPlan,
} from "@/features/home-plan/draft-screen";
import { addDays, daysBetween, messageText, parseCount, withDraftCounts, withMessage, type PlanCell } from "@/features/home-plan/rules";

const ST = "00000000-0000-4000-8000-0000000000a1";
const F = "00000000-0000-4000-8000-0000000000b1";
const S = "00000000-0000-4000-8000-0000000000b2";
const P1 = "00000000-0000-4000-8000-0000000000c1";
const P2 = "00000000-0000-4000-8000-0000000000c2";

function cell(date: string, type: string, over: Partial<PlanCell> = {}): PlanCell {
  return {
    date, station_id: ST, shift_type_id: type, required_total: 1, required_grade: null, required_grade_count: 0,
    example: false, assigned: [], present: 0, grade_present: 0, missing: 1, status: "gap", external_covered: 0, order: null,
    ...over,
  };
}

function plan(from: string, to: string, over: Partial<DraftPlan> = {}, inst: Partial<DraftPlan["institution"]> = {}): DraftPlan {
  return {
    institution: {
      id: "00000000-0000-4000-a000-0000000004c1", display_name: "Testheim (synthetisch)", simulation: true, role: "lead",
      min_rest_hours: 11, max_consecutive_days: 6, weekly_target_hours: 42, ...inst,
    },
    from, to,
    stations: [{ id: ST, name: "Rhein 1" }],
    shift_types: [
      { id: F, code: "F", label: "Früh", starts_at: "07:00", ends_at: "15:30", shift_class: "early" },
      { id: S, code: "S", label: "Spät", starts_at: "14:30", ends_at: "23:00", shift_class: "late" },
    ],
    staff: [
      { id: P1, display_name: "Anna Demo", grade: "fage_efz", home_station_id: null, active: true, pensum_pct: 100, shift_model: "any" },
      { id: P2, display_name: "Bea Demo", grade: "fage_efz", home_station_id: null, active: true, pensum_pct: 80, shift_model: "early_only" },
    ],
    absences: [],
    wishes: [],
    cells: daysBetween(from, to).flatMap((d) => [cell(d, F), cell(d, S)]),
    ...over,
  };
}

describe("HD-3a slice 4: periods and plan reads", () => {
  it("the week is Monday to Sunday, the month the calendar month (at most 31 days, the bound of migration 0177)", () => {
    expect(draftPeriodRange("woche", "2030-04-10")).toEqual({ from: "2030-04-08", to: "2030-04-14" });
    expect(draftPeriodRange("monat", "2030-01-17")).toEqual({ from: "2030-01-01", to: "2030-01-31" });
    for (const m of ["2030-01-05", "2030-02-05", "2032-02-05", "2030-04-05", "2030-12-31"]) {
      const r = draftPeriodRange("monat", m);
      expect(daysBetween(r.from, r.to).length).toBeLessThanOrEqual(31);
    }
  });

  it("reads cover the range in pieces of at most 42 days, without gap or overlap", () => {
    for (const [from, to] of [["2030-01-01", "2030-01-01"], ["2030-01-01", "2030-02-11"], ["2029-12-25", "2030-02-11"], ["2030-01-01", "2030-03-31"]]) {
      const chunks = planReadChunks(from, to);
      expect(chunks[0].from).toBe(from);
      expect(chunks[chunks.length - 1].to).toBe(to);
      for (const c of chunks) expect(daysBetween(c.from, c.to).length).toBeLessThanOrEqual(PLAN_READ_MAX_DAYS);
      for (let i = 1; i < chunks.length; i++) expect(chunks[i].from).toBe(addDays(chunks[i - 1].to, 1));
    }
  });

  it("the context of a month is wider than one read, so a month needs two reads", () => {
    const { from, to } = draftPeriodRange("monat", "2030-01-15");
    const ctx = contextRangeFor(plan(from, to), from, to)!;
    expect(ctx.from <= addDays(from, -6)).toBe(true);
    expect(ctx.to >= addDays(to, 6)).toBe(true);
    expect(planReadChunks(ctx.from, ctx.to).length).toBe(2);
  });

  it("merging two reads keeps each cell and each absence once and spans both", () => {
    const a = plan("2030-01-01", "2030-01-10", { absences: [{ id: "x1", staff_id: P1, starts_on: "2030-01-09", ends_on: "2030-01-12" }] });
    const b = plan("2030-01-11", "2030-01-20", { absences: [{ id: "x1", staff_id: P1, starts_on: "2030-01-09", ends_on: "2030-01-12" }] });
    const m = mergePlans([a, b])!;
    expect(m.from).toBe("2030-01-01");
    expect(m.to).toBe("2030-01-20");
    expect(m.cells.length).toBe(40);
    expect(m.absences.length).toBe(1);
    expect(mergePlans([])).toBeNull();
  });
});

describe("HD-3a CGR-284 (b): one read path for the screen and the equivalence test", () => {
  it("reads the period, then the context in pieces of at most 42 days, and merges them", async () => {
    const calls: Array<[string, string]> = [];
    const read = async (a: string, b: string) => {
      calls.push([a, b]);
      return plan(a, b, { cells: [cell(a, F)] });
    };
    const merged = await readDraftPlan(read, "2027-03-01", "2027-03-31");
    expect(calls[0]).toEqual(["2027-03-01", "2027-03-31"]);
    expect(calls.length).toBeGreaterThanOrEqual(3);
    for (const [a, b] of calls.slice(1)) expect(daysBetween(a, b).length).toBeLessThanOrEqual(PLAN_READ_MAX_DAYS);
    expect(merged?.from).toBe(calls[1][0]);
    expect(merged?.to).toBe(calls.at(-1)![1]);
  });
  it("any failed read gives no plan (no draft from part of the plan); missing limits give the period only", async () => {
    let n = 0;
    expect(await readDraftPlan(async (a, b) => (++n === 2 ? null : plan(a, b)), "2027-03-01", "2027-03-31")).toBeNull();
    expect(await readDraftPlan(async () => null, "2027-03-01", "2027-03-31")).toBeNull();
    const calls: string[] = [];
    const noLimits = await readDraftPlan(async (a, b) => (calls.push(a), plan(a, b, {}, { min_rest_hours: null })), "2027-03-01", "2027-03-07");
    expect(calls).toEqual(["2027-03-01"]);
    expect(noLimits?.from).toBe("2027-03-01");
  });
});

describe("HD-3a slice 4: solver input from the plan (fail closed)", () => {
  it("missing rest or days in a row: no draft, never a NAVORA default", () => {
    expect(readLimits(plan("2030-01-07", "2030-01-13", {}, { min_rest_hours: null })).ok).toBe(false);
    expect(draftInputFromPlan(plan("2030-01-07", "2030-01-13", {}, { max_consecutive_days: null }), "2030-01-07", "2030-01-13")).toBeNull();
    expect(contextRangeFor(plan("2030-01-07", "2030-01-13", {}, { min_rest_hours: undefined }), "2030-01-07", "2030-01-13")).toBeNull();
  });

  it("an unknown shift model or class (app and schema out of step): no draft", () => {
    const p1 = plan("2030-01-07", "2030-01-13");
    p1.staff[0] = { ...p1.staff[0], shift_model: "day_only" };
    expect(draftInputFromPlan(p1, "2030-01-07", "2030-01-13")).toBeNull();
    const p2 = plan("2030-01-07", "2030-01-13");
    p2.shift_types[0] = { ...p2.shift_types[0], shift_class: "day" };
    expect(draftInputFromPlan(p2, "2030-01-07", "2030-01-13")).toBeNull();
  });

  it("a missing weekly target reaches the solver as «pensum_reference_missing» (no draft)", () => {
    const input = draftInputFromPlan(plan("2030-01-07", "2030-01-13", {}, { weekly_target_hours: null }), "2030-01-07", "2030-01-13")!;
    expect(input.limits.fullTimeMinutesPerWeek).toBeNull();
    expect(buildDraft(input).result).toBe("pensum_reference_missing");
  });

  it("the read input gives a draft with 0 violations; the early-only person never gets a late shift", () => {
    const p = plan("2030-01-07", "2030-01-13");
    const input = draftInputFromPlan(p, "2030-01-07", "2030-01-13")!;
    expect(input.limits).toEqual({ minRestHours: 11, maxConsecutiveDays: 6, fullTimeMinutesPerWeek: 42 * 60 });
    const r = buildDraft(input);
    if (r.result !== "ok") throw new Error("no draft");
    expect(r.rows.length).toBeGreaterThan(0);
    expect(verifyDraft(input, r.rows)).toEqual([]);
    expect(r.rows.filter((x) => x.staff_id === P2 && x.shift_type_id === S)).toEqual([]);
  });

  it("wishes with an unknown kind or weekday are left out, valid ones are passed on", () => {
    const p = plan("2030-01-07", "2030-01-13", {
      wishes: [
        { staff_id: P1, weekday: 1, kind: "off", shift_type_id: null },
        { staff_id: P1, weekday: 8, kind: "off", shift_type_id: null },
        { staff_id: P1, weekday: 2, kind: "sick", shift_type_id: null },
      ],
    });
    expect(draftInputFromPlan(p, "2030-01-07", "2030-01-13")!.wishes).toEqual([{ staff_id: P1, weekday: 1, kind: "off", shift_type_id: null }]);
  });
});

describe("HD-3a slice 4: T-1 «übernommen = gezeigt»", () => {
  it("the form value carries exactly the shown rows, in the shown order, with the four keys only", () => {
    const p = plan("2030-01-07", "2030-01-13");
    const r = buildDraft(draftInputFromPlan(p, "2030-01-07", "2030-01-13")!);
    if (r.result !== "ok") throw new Error("no draft");
    const shown = sortRows(r.rows, p);
    const sent = JSON.parse(rowsFormValue(shown)) as Array<Record<string, string>>;
    expect(sent).toEqual(shown.map((x) => ({ date: x.date, station_id: x.station_id, shift_type_id: x.shift_type_id, staff_id: x.staff_id })));
    for (const row of sent) expect(Object.keys(row).sort()).toEqual(["date", "shift_type_id", "staff_id", "station_id"]);
    expect(sortRows([...r.rows].reverse(), p)).toEqual(shown);
  });
});

describe("HD-3a slice 4: the answer of «übernehmen»", () => {
  it("ok, partly, already applied, rejected and refused as a whole", () => {
    expect(applyOutcome({ result: "ok", applied: 5, refused: [] })).toEqual({ code: "draft_applied", applied: 5, refused: 0 });
    expect(applyOutcome({ result: "ok", applied: 3, refused: [{ reason: "planning_rule" }, { reason: "cell_full" }] }))
      .toEqual({ code: "draft_applied_partly", applied: 3, refused: 2 });
    expect(applyOutcome({ result: "already_applied", applied: 5, refused: [] }).code).toBe("draft_already_applied");
    expect(applyOutcome({ result: "rejected" }).code).toBe("rejected");
    expect(applyOutcome({ result: "invalid", problems: ["period_too_long"] })).toEqual({ code: "period_too_long", applied: 0, refused: 0 });
    expect(applyOutcome(null).code).toBe("failed");
    expect(applyOutcome({ result: "ok", applied: -1, refused: "x" })).toEqual({ code: "draft_applied", applied: 0, refused: 0 });
  });

  it("the message names the counts; a refused part says the shifts stay open", () => {
    const path = withDraftCounts(withMessage("/heim?ansicht=woche&datum=2030-01-07", "draft_applied_partly"), 3, 2);
    const q = new URL(path, "http://x").searchParams;
    expect(q.get("meldung")).toBe("draft_applied_partly");
    const m = messageText(q.get("meldung") ?? undefined, { applied: parseCount(q.get("uebernommen")), refused: parseCount(q.get("abgelehnt")) });
    expect(m).toEqual({ kind: "ok", text: "Vorschlag teilweise übernommen: 3 Dienste eingeteilt, 2 Vorschläge abgelehnt, weil sich der Plan seither geändert hat. Diese Dienste bleiben offen." });
    expect(messageText("draft_applied", { applied: 1, refused: 0 })?.text).toBe("Vorschlag übernommen: 1 Dienst eingeteilt.");
    expect(messageText("draft_already_applied", { applied: 4, refused: 0 })?.text).toBe("Dieser Vorschlag wurde schon übernommen (4 Dienste). Nichts wurde doppelt eingeteilt.");
    expect(messageText("period_too_long")?.kind).toBe("error");
    expect(messageText("duplicate_row")?.kind).toBe("error");
  });

  it("HD-3a-F1: without weekly target the whole call is refused and the text names the next action", () => {
    expect(applyOutcome({ result: "invalid", problems: ["weekly_target_missing"] }))
      .toEqual({ code: "weekly_target_missing", applied: 0, refused: 0 });
    const m = messageText("weekly_target_missing");
    expect(m?.kind).toBe("error");
    expect(m?.text).toContain("kein Wochensoll eingetragen");
    expect(m?.text).toContain("«Planungsgrenzen»");
    expect(m?.text).toContain("Es wurde nichts übernommen.");
  });

  it("counts from the URL are whole numbers only", () => {
    expect(parseCount("12")).toBe(12);
    expect(parseCount("-1")).toBe(0);
    expect(parseCount("1e3")).toBe(0);
    expect(parseCount(undefined)).toBe(0);
    expect(parseCount("123456")).toBe(0);
  });
});
