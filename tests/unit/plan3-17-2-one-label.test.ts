import { describe, expect, it } from "vitest";
import { pickerMemberLabel, responsibleMemberLabel, MEMBER_WITHOUT_NUMBER_TEXT } from "@/features/team/member-label";
import { memberLabel } from "@/features/team/rules";

/**
 * PLAN3-17 (2) (`uxa` UXR-114, PO 2026-11-06 06:30, ADR-159): one person, one label. `memberLabel` on /team delegates
 * to `pickerMemberLabel` and keeps its own "nicht bestimmt" / "nicht mehr im Team" cases and the qualification suffix;
 * the `/visits/<id>` responsible line uses the same function. Synthetic members only.
 */
const roster = [
  { user_id: "a", me: true, qualification: "registered_nurse", name: null },
  { user_id: "b", me: false, qualification: "care_assistant", name: null },
  { user_id: "c", me: false, qualification: null, name: "Ben Beispiel" },
  { user_id: "d", me: false, qualification: "registered_nurse", name: null },
];

const namePart = (label: string) => label.split(" – ")[0];

describe("PLAN3-17 (2): memberLabel and pickerMemberLabel name a person alike", () => {
  it("returns the same name part for every member of the roster", () => {
    roster.forEach((m, i) => {
      const picker = pickerMemberLabel({ name: m.name, me: m.me, no: i + 1 });
      expect(namePart(memberLabel(roster, m.user_id))).toBe(picker);
    });
  });

  it("marks the caller '(du)', numbers an unnamed member as the handover does, and uses a name as it is", () => {
    expect(memberLabel(roster, "a")).toBe("Ich (du) – Pflegefachperson");
    expect(memberLabel(roster, "b")).toBe("Teammitglied 2 (ohne Namen) – Pflegeassistenz");
    expect(memberLabel(roster, "c")).toBe("Ben Beispiel");
    expect(memberLabel(roster, "d")).toBe("Teammitglied 4 (ohne Namen) – Pflegefachperson");
  });

  it("keeps its own cases for no member and a member no longer in the team", () => {
    expect(memberLabel(roster, null)).toBe("nicht bestimmt");
    expect(memberLabel(roster, undefined)).toBe("nicht bestimmt");
    expect(memberLabel(roster, "x")).toBe("nicht mehr im Team");
  });

  it("gives two unnamed members two labels", () => {
    expect(memberLabel(roster, "b")).not.toBe(memberLabel(roster, "d"));
  });

  it("numbers by first place when an id repeats, as memberNumbers does", () => {
    const repeated = [roster[1], roster[1], roster[3]];
    expect(memberLabel(repeated, "d")).toBe("Teammitglied 2 (ohne Namen) – Pflegefachperson");
  });
});

describe("PLAN3-17 (2): the /visits/<id> responsible line", () => {
  it("is null when nobody is responsible (the page shows 'Noch offen')", () => {
    expect(responsibleMemberLabel(null, null, roster)).toBeNull();
  });

  it("uses the picker label of a member of the caller's team", () => {
    expect(responsibleMemberLabel("a", null, roster)).toBe("Ich (du)");
    expect(responsibleMemberLabel("a", "Anna Muster", roster)).toBe("Anna Muster (du)");
    expect(responsibleMemberLabel("b", null, roster)).toBe("Teammitglied 2 (ohne Namen)");
    expect(responsibleMemberLabel("c", null, roster)).toBe("Ben Beispiel");
  });

  it("matches memberLabel's name part for the same member", () => {
    for (const m of roster) expect(responsibleMemberLabel(m.user_id, null, roster)).toBe(namePart(memberLabel(roster, m.user_id)));
  });

  it("without the team roster (a coordinator) shows the name, or no number rather than a guessed one", () => {
    expect(responsibleMemberLabel("b", "Pflegekraft Bezug F", null)).toBe("Pflegekraft Bezug F");
    expect(responsibleMemberLabel("b", null, null)).toBe(MEMBER_WITHOUT_NUMBER_TEXT);
    expect(responsibleMemberLabel("z", null, roster)).toBe(MEMBER_WITHOUT_NUMBER_TEXT);
    expect(responsibleMemberLabel("z", "  ", [])).toBe(MEMBER_WITHOUT_NUMBER_TEXT);
  });
});
