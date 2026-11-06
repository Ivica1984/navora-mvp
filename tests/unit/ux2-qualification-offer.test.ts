import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { QUALIFICATIONS } from "@/features/admin/rules";
import {
  MISSING_QUALIFICATION_HEADING, QUALIFICATION_OFFER_TITLE, QUALIFICATION_REASON_LABEL, findRecordedMember,
  membersWithoutQualification, qualificationOfferOptions, validQualificationReason,
} from "@/features/admission/rules";

// UX2-26 (ADR-136, `aia` AUT-21, `uxa` 16:10 layout): after "Vertrag erfasst" the same admission card offers the
// EXISTING set_member_qualification. These helpers only read the existing membership fact (admin_members); the
// database decides every rule. Written before the component.

const member = (user_id: string, email: string, display_name: string, teams: unknown) =>
  ({ user_id, email, display_name, teams });

describe("UX2-26 qualification in the same sitting as the contract", () => {
  it("lists every team membership without a qualification, one entry per member and team (the existing fact)", () => {
    const rows = membersWithoutQualification([
      member("u1", "a@x.test", "Anna", [{ team_id: "t1", team: "Nord", qualification: null }, { team_id: "t2", team: "Süd", qualification: "registered_nurse" }]),
      member("u2", "b@x.test", "", [{ team_id: "t2", team: "Süd", qualification: null }]),
      member("u3", "c@x.test", "Cleo", [{ team_id: "t1", team: "Nord", qualification: "care_assistant" }]),
      member("u4", "d@x.test", "Dora", "not-an-array"),
    ]);
    expect(rows).toEqual([
      { userId: "u1", email: "a@x.test", displayName: "Anna", teamId: "t1", team: "Nord" },
      { userId: "u2", email: "b@x.test", displayName: "", teamId: "t2", team: "Süd" },
    ]);
  });

  it("finds the member just recorded by the e-mail typed and the proposal's team (case and spaces ignored)", () => {
    const rows = membersWithoutQualification([
      member("u1", "Neu@X.test", "Neu", [{ team_id: "t1", team: "Nord", qualification: null }]),
      member("u2", "neu@x.test", "Neu", [{ team_id: "t9", team: "Andere", qualification: null }]),
    ]);
    expect(findRecordedMember(rows, "  neu@x.TEST ", "t1")?.userId).toBe("u1");
    expect(findRecordedMember(rows, "neu@x.test", "t2")).toBeNull();
    expect(findRecordedMember(rows, "", "t1")).toBeNull();
  });

  it("offers every qualification in a fixed order: the claimed one is neither first nor marked", () => {
    // The helper takes no claim at all, so the claim cannot reorder it.
    expect(qualificationOfferOptions.length).toBe(0);
    expect(qualificationOfferOptions()).toEqual(["registered_nurse", "care_assistant"]);
    // Exactly the values the existing command accepts (no new qualification).
    expect([...qualificationOfferOptions()].sort()).toEqual([...QUALIFICATIONS].sort());
  });

  it("keeps the reason rule of set_member_qualification (3-300 characters)", () => {
    expect(validQualificationReason("ab")).toBe(false);
    expect(validQualificationReason("  ab  ")).toBe(false);
    expect(validQualificationReason("abc")).toBe(true);
    expect(validQualificationReason("x".repeat(300))).toBe(true);
    expect(validQualificationReason("x".repeat(301))).toBe(false);
  });

  it("uses the uxa 16:10 words", () => {
    expect(QUALIFICATION_OFFER_TITLE).toBe("Qualifikation festlegen");
    expect(QUALIFICATION_REASON_LABEL).toBe("Begründung (3–300 Zeichen)");
    expect(MISSING_QUALIFICATION_HEADING).toBe("Vertrag erfasst, Qualifikation fehlt");
  });
});

describe("UX2-26 admission card (source checks)", () => {
  const src = readFileSync(join(process.cwd(), "src/app/(protected)/admin/admission-section.tsx"), "utf8");

  it("drops the sentence that sent her to the member entry", () => {
    expect(src).not.toContain("Die Qualifikation setzt die Administration wie bisher beim Mitglied");
  });

  it("calls the existing set_member_qualification action (same command, same audit row as the member entry)", () => {
    expect(src).toMatch(/import \{[^}]*\bsetMemberQualification\b[^}]*\} from "@\/features\/admin\/commands"/);
    expect(src).not.toMatch(/supabase\.rpc|from "@\/lib\/supabase/);
  });

  it("never preselects a qualification and has no accept-all", () => {
    expect(src).not.toMatch(/defaultChecked|checked=\{true\}|\bchecked\b\s*(=|\s)/);
    expect(src).not.toMatch(/alle (übernehmen|bestätigen)|Alle festlegen/i);
  });

  it("offers \"Später\", which runs no command", () => {
    expect(src).toContain(">Später<");
  });
});
