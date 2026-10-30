import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { OPEN_VISITS_UNQUALIFIED_TEXT, actionsForMember, splitOpenVisits, teamsWithoutQualification } from "@/features/field/qualification";
import { ADMISSION_OFF_CONSEQUENCE, ADMISSION_ON_CONSEQUENCE, CONFIRM_CANCEL_LABEL, CONTRACT_END_REMOVE_CONSEQUENCE } from "@/features/admin/confirm-texts";
import { QUALIFICATION_MISSING_MESSAGE } from "@/lib/commands/result";

// UX2-22 / UX2-23 (ADR-124). The e2e (tests/e2e/ux2-gates.spec.ts) proves the screens; these pin the rules and texts.

describe("UX2-22: no field action she cannot perform", () => {
  it("names the teams where her own row has no qualification, once each", () => {
    expect(teamsWithoutQualification([
      { team_id: "b", qualification: null },
      { team_id: "a", qualification: "registered_nurse" },
      { team_id: "b", qualification: null },
      { team_id: "c", qualification: null },
    ])).toEqual(["b", "c"]);
    expect(teamsWithoutQualification([{ team_id: "a", qualification: "care_assistant" }])).toEqual([]);
    expect(teamsWithoutQualification([])).toEqual([]);
  });

  it("hides depart, start, resume and completion on a visit of such a team (hide, cra 13:40); pause stays", () => {
    expect(actionsForMember(["depart", "start"], "t1", ["t1"])).toEqual([]);
    expect(actionsForMember(["start"], "t1", ["t1"])).toEqual([]);
    expect(actionsForMember(["complete", "pause"], "t1", ["t1"])).toEqual(["pause"]);
    expect(actionsForMember(["resume"], "t1", ["t1"])).toEqual([]);
  });

  it("leaves every other card as built (qualified team, or a visit of another team, e.g. covered)", () => {
    expect(actionsForMember(["depart", "start"], "t2", ["t1"])).toEqual(["depart", "start"]);
    expect(actionsForMember(["complete", "pause"], "t2", [])).toEqual(["complete", "pause"]);
    expect(actionsForMember(["depart", "start"], null, ["t1"])).toEqual(["depart", "start"]);
  });

  it("withholds open visits of such a team; the rest of 'Offen im Team' stays as built", () => {
    const open = [{ visit_id: "1", team_id: "t1" }, { visit_id: "2", team_id: "t2" }];
    expect(splitOpenVisits(open, ["t1"])).toEqual({ shown: [{ visit_id: "2", team_id: "t2" }], withheld: 1 });
    expect(splitOpenVisits(open, ["t1", "t2"])).toEqual({ shown: [], withheld: 2 });
    expect(splitOpenVisits(open, [])).toEqual({ shown: open, withheld: 0 });
  });

  it("keeps the ADM2-16 sentence and the uxa line word for word", () => {
    expect(QUALIFICATION_MISSING_MESSAGE).toBe(
      "Deine Qualifikation ist noch nicht erfasst. Einsätze führst du durch, sobald die Administration sie eingetragen hat."
    );
    expect(OPEN_VISITS_UNQUALIFIED_TEXT).toBe("Offene Einsätze übernehmen Teammitglieder mit erfasster Qualifikation.");
  });
});

describe("UX2-23: a switch with organisation-wide or privacy consequences asks once", () => {
  it("pins each sentence (uxa 16:10, po 16:24)", () => {
    expect(ADMISSION_ON_CONSEQUENCE).toBe(
      "Danach nehmen die Teams neue Kolleginnen selbst auf. Die Administration erfasst nur noch den Vertrag."
    );
    // The optional second off-sentence is not shown: open and admitted proposals still lapse while off (ADR-124).
    expect(ADMISSION_OFF_CONSEQUENCE).toBe("Danach nimmt nur die Administration neue Mitglieder auf.");
    expect(ADMISSION_OFF_CONSEQUENCE).not.toContain("ruhen");
    expect(CONTRACT_END_REMOVE_CONSEQUENCE).toBe("Der Zugang endet dann nicht mehr automatisch.");
    expect(CONFIRM_CANCEL_LABEL).toBe("Abbrechen");
  });

  it("carries no internal code", () => {
    for (const s of [ADMISSION_ON_CONSEQUENCE, ADMISSION_OFF_CONSEQUENCE, CONTRACT_END_REMOVE_CONSEQUENCE]) {
      expect(s).not.toMatch(/[A-Z]{2,}\d|_|ADM|UX/);
    }
  });

  it("runs each command only from the confirming step (first tap opens the step)", () => {
    const admission = readFileSync("src/app/(protected)/admin/admission-section.tsx", "utf8");
    const calls = admission.split("setTeamAdmission({").length - 1;
    expect(calls).toBe(1);
    expect(admission).toMatch(/onConfirm=\{\(\) => run\(\s*\(\) => setTeamAdmission\(/);

    const contract = readFileSync("src/app/(protected)/admin/contract-end-section.tsx", "utf8");
    expect(contract.split("save(null)").length - 1).toBe(1);
    expect(contract).toContain("onConfirm={() => save(null)}");
    expect(contract).toContain('onClick={() => setMode("confirm-remove")}>Vertragsende entfernen</button>');
  });
});
