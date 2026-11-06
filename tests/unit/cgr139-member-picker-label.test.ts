import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { MEMBER_WITHOUT_NUMBER_TEXT, memberNumbers, pickerMemberLabel } from "@/features/team/member-label";
import { groupDayPlan, type DayPlanLine, type DayPlanLoadRow } from "@/features/planning/day-plan-view";

// CGR-139 (`cra` 2026-11-06 01:30, PS-124) / `uxa` UXR-102 (#884), ADR-152: every picker that sets the responsible
// member of a visit and every member heading next to it tells two members without a display name apart. Label form
// confirmed by `cra`: the display name; "<Name> (du)" for the caller ("Ich (du)" without a name); otherwise
// "Teammitglied <n> (ohne Namen)" with the same <n> as the handover (`private.member_code`) and /team
// (`memberLabel`): the member's position in the team ordered by user id. Who may be picked is unchanged.
const root = process.cwd();
const read = (p: string) => readFileSync(join(root, p), "utf8");

describe("CGR-139 pickerMemberLabel", () => {
  it("two unnamed members get two different labels", () => {
    const a = pickerMemberLabel({ name: null, me: false, no: 2 });
    const b = pickerMemberLabel({ name: null, me: false, no: 3 });
    expect(a).toBe("Teammitglied 2 (ohne Namen)");
    expect(b).toBe("Teammitglied 3 (ohne Namen)");
    expect(a).not.toBe(b);
  });

  it("the caller ends with '(du)', named or not", () => {
    expect(pickerMemberLabel({ name: "Anna Muster", me: true, no: 1 })).toBe("Anna Muster (du)");
    expect(pickerMemberLabel({ name: null, me: true, no: 1 })).toBe("Ich (du)");
    expect(pickerMemberLabel({ name: "   ", me: true, no: 4 })).toBe("Ich (du)");
  });

  it("a named member's label is unchanged (trimmed name only)", () => {
    expect(pickerMemberLabel({ name: "Beat Beispiel", me: false, no: 5 })).toBe("Beat Beispiel");
    expect(pickerMemberLabel({ name: "  Beat Beispiel ", me: false, no: null })).toBe("Beat Beispiel");
  });

  it("an empty name counts as no name", () => {
    expect(pickerMemberLabel({ name: "", me: false, no: 2 })).toBe("Teammitglied 2 (ohne Namen)");
  });

  it("without a known position it never invents a number", () => {
    expect(pickerMemberLabel({ name: null, me: false, no: null })).toBe(MEMBER_WITHOUT_NUMBER_TEXT);
    expect(pickerMemberLabel({ name: null, me: false })).toBe(MEMBER_WITHOUT_NUMBER_TEXT);
    expect(pickerMemberLabel({ name: null, me: false, no: 0 })).toBe(MEMBER_WITHOUT_NUMBER_TEXT);
    expect(pickerMemberLabel({ name: null, me: false, no: Number.NaN })).toBe(MEMBER_WITHOUT_NUMBER_TEXT);
    expect(MEMBER_WITHOUT_NUMBER_TEXT).toBe("Teammitglied (ohne Namen)");
  });
});

describe("CGR-139 memberNumbers", () => {
  it("numbers the roster in the order given (team_cases: every membership ordered by user id), from 1", () => {
    const n = memberNumbers([{ user_id: "u-a" }, { user_id: "u-b" }, { user_id: "u-c" }]);
    expect(n.get("u-a")).toBe(1);
    expect(n.get("u-b")).toBe(2);
    expect(n.get("u-c")).toBe(3);
    expect(n.get("u-x")).toBeUndefined();
  });

  it("keeps the first position of a repeated id (the same team listed by several cases)", () => {
    const n = memberNumbers([{ user_id: "u-a" }, { user_id: "u-b" }, { user_id: "u-a" }, { user_id: "u-c" }]);
    expect([...n.entries()]).toEqual([
      ["u-a", 1],
      ["u-b", 2],
      ["u-c", 3],
    ]);
  });

  it("returns an empty map for an empty roster", () => {
    expect(memberNumbers([]).size).toBe(0);
  });
});

describe("CGR-139 day-plan member blocks carry the number and the caller mark", () => {
  const load = [
    { member_id: "u-c", member_name: null, minutes_now: 0, minutes_with_proposal: 30, other_team_visits: false },
    { member_id: "u-b", member_name: null, minutes_now: 0, minutes_with_proposal: 0, other_team_visits: false },
    { member_id: "u-a", member_name: null, minutes_now: 0, minutes_with_proposal: 0, other_team_visits: false },
  ] as unknown as DayPlanLoadRow[];
  const roster = [
    { user_id: "u-a", me: true },
    { user_id: "u-b", me: false },
    { user_id: "u-c", me: false },
  ];

  it("each member gets her team position and 'me' from the roster; labels differ", () => {
    const g = groupDayPlan([] as DayPlanLine[], load, roster);
    expect(g.members.map((m) => [m.member_id, m.no, m.me])).toEqual([
      ["u-c", 3, false],
      ["u-b", 2, false],
      ["u-a", 1, true],
    ]);
    const labels = g.members.map((m) => pickerMemberLabel(m));
    expect(labels).toEqual(["Teammitglied 3 (ohne Namen)", "Teammitglied 2 (ohne Namen)", "Ich (du)"]);
    expect(new Set(labels).size).toBe(labels.length);
  });

  it("without a roster nobody gets a number and nobody is marked as the caller", () => {
    const g = groupDayPlan([] as DayPlanLine[], load);
    expect(g.members.every((m) => m.no === null && m.me === false)).toBe(true);
  });
});

describe("CGR-139 wiring: no picker or member heading keeps the bare 'Teammitglied' fallback", () => {
  const files = [
    "src/app/(protected)/team/tagesplan/day-plan-client.tsx",
    "src/app/(protected)/team/vorschlaege/suggestions-client.tsx",
    "src/app/(protected)/visits/[visitId]/lookback-actions.tsx",
  ];
  for (const f of files) {
    it(`${f} labels members with pickerMemberLabel`, () => {
      const src = read(f);
      expect(src).toContain("pickerMemberLabel(");
      expect(src).not.toMatch(/name \?\? "Teammitglied"/);
    });
  }

  it("the /team new-visit 'Verantwortlich' picker uses the same label, numbered as /team (UXR-113)", () => {
    const src = read("src/app/(protected)/team/team-client.tsx");
    expect(src).toContain("pickerMemberLabel({ name: m.name, me: m.me, no: i + 1 })");
    expect(src).not.toContain('{m.me ? "Ich" : `Teammitglied ${i + 1}`}');
  });

  it("the confirm screen's members carry their team position from team_cases", () => {
    const q = read("src/features/ai/queries.ts");
    expect(q).toMatch(/no: number \| null/);
    expect(q).toContain("memberNumbers(");
  });

  it("the day-plan teams carry the team_cases roster", () => {
    const q = read("src/features/planning/day-plan-queries.ts");
    expect(q).toContain("roster");
    expect(read("src/app/(protected)/team/tagesplan/day-plan-client.tsx")).toMatch(/groupDayPlan\(lines, load, team\.roster\)/);
  });
});
