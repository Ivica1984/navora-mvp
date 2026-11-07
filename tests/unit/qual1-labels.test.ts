import { describe, expect, it } from "vitest";
import {
  QUAL_RESULTS,
  allowsResponsibility,
  qualLabel,
  qualReason,
  SIMULATION_BANNER,
  type QualCheckRow,
} from "@/features/qualification/labels";

// QUAL1 part 1 (brief docs/agents/briefs/QUAL1.md, ADR-163, migration 0120): the words for `private.qual_check`.
// Written before the module. Labels are CR-183's four; reasons use the brief's S1-S8 and matrix v0.2 §7 wording.

function row(over: Partial<QualCheckRow>): QualCheckRow {
  return {
    activity_code: "B3",
    result: "allowed_own",
    label: "geeignet",
    reason: "cell:E",
    matrix_version: "QAM-0.2",
    rule_status: "PROPOSED",
    delegation_until: null,
    ...over,
  };
}

describe("QUAL1 result labels (CR-183)", () => {
  it("knows every result the database returns, once", () => {
    expect(QUAL_RESULTS).toEqual([
      "allowed_own",
      "allowed_delegated",
      "not_allowed",
      "unresolved",
      "evidence_missing",
      "evidence_expired",
      "evidence_contradictory",
      "delegation_missing",
      "delegation_expired",
      "delegation_review_needed",
    ]);
  });

  it("uses exactly the four CR-183 labels", () => {
    expect(new Set(QUAL_RESULTS.map(qualLabel))).toEqual(
      new Set(["geeignet", "geeignet mit Delegation", "nicht geeignet", "ungeklärt"]),
    );
    expect(qualLabel("allowed_own")).toBe("geeignet");
    expect(qualLabel("allowed_delegated")).toBe("geeignet mit Delegation");
    expect(qualLabel("not_allowed")).toBe("nicht geeignet");
  });

  it("only the first two allow responsibility; ungeklärt is never suitable", () => {
    const allowed = QUAL_RESULTS.filter(allowsResponsibility);
    expect(allowed).toEqual(["allowed_own", "allowed_delegated"]);
    for (const r of QUAL_RESULTS.filter((x) => qualLabel(x) === "ungeklärt")) expect(allowsResponsibility(r)).toBe(false);
  });

  it("an unknown result reads ungeklärt and allows nothing (fail closed)", () => {
    expect(qualLabel("something_new" as never)).toBe("ungeklärt");
    expect(allowsResponsibility("something_new" as never)).toBe(false);
  });
});

describe("QUAL1 reasons (brief S1-S8, matrix §7)", () => {
  it("S2: a self-confirmed grade reads Nachweis fehlt: Ausbildung", () => {
    expect(qualReason(row({ result: "evidence_missing", reason: "grade:self_confirmed" }))).toBe("Nachweis fehlt: Ausbildung");
    expect(qualReason(row({ result: "evidence_missing", reason: "grade:missing" }))).toBe("Nachweis fehlt: Ausbildung");
  });

  it("S3a / S3b: missing and expired delegation name the activity and the date", () => {
    expect(qualReason(row({ result: "delegation_missing", reason: "no_delegation" }))).toBe("Delegation fehlt (B3)");
    expect(
      qualReason(row({ activity_code: "B7", result: "delegation_expired", reason: "delegation_ended", delegation_until: "2026-11-06" })),
    ).toBe("Delegation B7 abgelaufen am 06.11.2026");
  });

  it("S4: an open cell names the question and PROPOSED", () => {
    expect(qualReason(row({ activity_code: "B4I", result: "unresolved", reason: "cell:?:K-2" }))).toBe(
      "Regel ungeklärt (B4I, PROPOSED ?, K-2)",
    );
    expect(qualReason(row({ activity_code: "B13", result: "unresolved", reason: "cell:?" }))).toBe(
      "Regel ungeklärt (B13, PROPOSED ?)",
    );
  });

  it("names the other refusals without any client datum", () => {
    expect(qualReason(row({ result: "not_allowed", reason: "cell:-" }))).toBe("B3 nicht im Kompetenzbereich");
    expect(qualReason(row({ result: "evidence_expired", reason: "grade:expired" }))).toBe("Voraussetzung abgelaufen: Ausbildung");
    expect(qualReason(row({ result: "evidence_expired", reason: "practice_licence:expired" }))).toBe(
      "Voraussetzung abgelaufen: Berufsausübungsbewilligung",
    );
    expect(qualReason(row({ result: "evidence_contradictory", reason: "grade:contradictory" }))).toBe("Nachweise widersprüchlich");
    expect(qualReason(row({ result: "delegation_review_needed", reason: "delegator_or_supervisor_lapsed" }))).toBe(
      "Delegation B3: Überprüfung nötig",
    );
  });

  it("S1: an allowed delegation says until when", () => {
    expect(qualReason(row({ result: "allowed_delegated", reason: "delegation", delegation_until: "2026-12-07" }))).toBe(
      "Delegation gültig bis 07.12.2026",
    );
    expect(qualReason(row({ result: "allowed_own", reason: "cell:E" }))).toBe("eigener Kompetenzbereich");
  });

  it("QUAL1-14: the simulation banner says synthetic and PROPOSED", () => {
    expect(SIMULATION_BANNER).toBe("Simulation · synthetische Daten · Regeln PROPOSED");
  });
});
