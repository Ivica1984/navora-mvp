import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { teamPickerOptions } from "@/features/team/member-label";

// UXR-113 (`uxa` 2026-11-06 03:50, high, #884) within CGR-139 / ADR-152 ("every picker that assigns a visit"), ADR-154:
// the /team "Neuer Einsatz" → "Verantwortlich" picker sets the responsible member of a new visit, so it uses the same
// label as the other visit-assigning pickers: the display name; "<Name> (du)" / "Ich (du)" for the caller; otherwise
// "Teammitglied <n> (ohne Namen)" with <n> the /team position (team_cases order, the same as `memberLabel` and the
// handover). The qualification stays as the suffix " – <Qualifikation>". Who may be picked is unchanged.
const root = process.cwd();
const read = (p: string) => readFileSync(join(root, p), "utf8");

const roster = [
  { user_id: "u-a", me: true, name: null, qualification: "registered_nurse" },
  { user_id: "u-b", me: false, name: "Beat Beispiel", qualification: "care_assistant" },
  { user_id: "u-c", me: false, name: null, qualification: "registered_nurse" },
  { user_id: "u-d", me: false, name: "  ", qualification: null },
];

describe("UXR-113 teamPickerOptions", () => {
  it("names a named member, marks the caller '(du)' and numbers the unnamed by their /team position", () => {
    expect(teamPickerOptions(roster)).toEqual([
      { value: "u-a", label: "Ich (du) – Pflegefachperson" },
      { value: "u-b", label: "Beat Beispiel – Pflegeassistenz" },
      { value: "u-c", label: "Teammitglied 3 (ohne Namen) – Pflegefachperson" },
      { value: "u-d", label: "Teammitglied 4 (ohne Namen)" },
    ]);
  });

  it("every option reads differently, also for two unnamed members with the same qualification", () => {
    const two = [
      { user_id: "u-1", me: false, name: null, qualification: "registered_nurse" },
      { user_id: "u-2", me: false, name: null, qualification: "registered_nurse" },
    ];
    const labels = teamPickerOptions(two).map((o) => o.label);
    expect(new Set(labels).size).toBe(labels.length);
  });

  it("a named caller reads '<Name> (du)'", () => {
    expect(teamPickerOptions([{ user_id: "u-a", me: true, name: "Anna Muster", qualification: null }])).toEqual([
      { value: "u-a", label: "Anna Muster (du)" },
    ]);
  });

  it("an unknown qualification code is shown as given, never dropped", () => {
    expect(teamPickerOptions([{ user_id: "u-x", me: false, name: "X", qualification: "other_code" }])[0].label).toBe("X – other_code");
  });

  it("keeps the roster order and the first position of a repeated id (same numbering as memberNumbers)", () => {
    const opts = teamPickerOptions([
      { user_id: "u-a", me: false, name: null },
      { user_id: "u-b", me: false, name: null },
      { user_id: "u-a", me: false, name: null },
    ]);
    expect(opts.map((o) => o.value)).toEqual(["u-a", "u-b"]);
    expect(opts.map((o) => o.label)).toEqual(["Teammitglied 1 (ohne Namen)", "Teammitglied 2 (ohne Namen)"]);
  });

  it("returns no option for an empty roster", () => {
    expect(teamPickerOptions([])).toEqual([]);
  });
});

describe("UXR-113 wiring: the /team new-visit picker no longer hides names", () => {
  const src = read("src/app/(protected)/team/team-client.tsx");
  it("uses teamPickerOptions for the responsible picker", () => {
    expect(src).toContain("teamPickerOptions(members)");
  });
  it("keeps no bare 'Ich' / 'Teammitglied <i + 1>' option", () => {
    expect(src).not.toMatch(/m\.me \? "Ich" : `Teammitglied \$\{i \+ 1\}`/);
  });
});
