import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import {
  QUALIFICATION_LAPSED_MESSAGE,
  QUALIFICATION_NOT_ALLOWED_MESSAGE,
  qualificationRefusal,
  toCommandResult,
} from "@/lib/commands/result";

/**
 * QUAL1 part 2 slice 2 (ADR-165, `uxa` UXR-132 / #944). Migration 0121 refuses, in a simulation organisation, a write
 * that makes a member responsible for or covering a visit she may not perform (42501 `qualification_not_allowed`) and a
 * start she may no longer perform (42501 `qualification_lapsed`). Before this slice every command showed its generic
 * "konnte nicht gespeichert werden" (or, in the AIG1 confirm, an unrelated cause), so a team could not tell a refusal
 * by the qualification check from a technical failure. Wording PROPOSED, `cra` to confirm.
 */
const M = { rejected: "abgelehnt", failed: "fehlgeschlagen" };
const notAllowed = {
  code: "42501",
  message: "qualification_not_allowed",
  details: "QUAL1-10: B3:nicht_geeignet:evidence_missing",
};
const lapsed = { code: "42501", message: "qualification_lapsed", details: "QUAL1-17: B3:ungeklaert:delegation_expired" };

describe("qualificationRefusal (QUAL1-10, QUAL1-17)", () => {
  it("names a refusal by the qualification check, and only that", () => {
    expect(qualificationRefusal(notAllowed)).toBe(QUALIFICATION_NOT_ALLOWED_MESSAGE);
    expect(qualificationRefusal(lapsed)).toBe(QUALIFICATION_LAPSED_MESSAGE);
    // Another 42501 (RLS, ADM2-6 `qualification_missing`, a prohibited AI target) is not this refusal.
    expect(qualificationRefusal({ code: "42501", message: "permission denied for table care_visits" })).toBeNull();
    expect(qualificationRefusal({ code: "42501", message: "qualification_missing" })).toBeNull();
    expect(qualificationRefusal({ code: "42501" })).toBeNull();
    // The message alone is not enough: the database raises it with 42501 only.
    expect(qualificationRefusal({ code: "P0001", message: "qualification_not_allowed" })).toBeNull();
    expect(qualificationRefusal(null)).toBeNull();
    expect(qualificationRefusal(undefined)).toBeNull();
  });

  it("shows no code, no rule state, no verdict word and no person reason (UXR-133, CGR-152)", () => {
    for (const text of [QUALIFICATION_NOT_ALLOWED_MESSAGE, QUALIFICATION_LAPSED_MESSAGE]) {
      expect(text).not.toMatch(/\b[ABCN]\d{1,2}[HI]?\b|PROPOSED|QUAL1|CR-\d|geeignet|ungeklärt|42501|\?\)/);
      expect(text).not.toMatch(/evidence|delegation_|membership/);
      expect(text.length).toBeLessThanOrEqual(260);
    }
    // The database detail (which may name the member's evidence) never reaches the text.
    expect(qualificationRefusal(notAllowed)).not.toContain("evidence_missing");
    expect(qualificationRefusal(lapsed)).not.toContain("delegation_expired");
  });

  it("tells the team what to do next", () => {
    expect(QUALIFICATION_NOT_ALLOWED_MESSAGE).toContain("Nicht gespeichert");
    expect(QUALIFICATION_NOT_ALLOWED_MESSAGE).toMatch(/andere Person|offen/);
    expect(QUALIFICATION_LAPSED_MESSAGE).toContain("Nicht begonnen");
    expect(QUALIFICATION_LAPSED_MESSAGE).toContain("im Team");
  });

  it("toCommandResult maps both before the generic failure (visit start, depart, resume)", () => {
    expect(toCommandResult(null, notAllowed, M)).toEqual({ ok: false, error: QUALIFICATION_NOT_ALLOWED_MESSAGE });
    expect(toCommandResult(null, lapsed, M)).toEqual({ ok: false, error: QUALIFICATION_LAPSED_MESSAGE });
    expect(toCommandResult(null, { code: "42501", message: "permission denied" }, M)).toEqual({
      ok: false,
      error: "fehlgeschlagen",
    });
  });
});

/**
 * Every command whose database function can meet the 0121 backstop or the start check maps the refusal before its
 * generic error branch. A source check, because the commands are Server Actions that need a request context.
 */
const COMMANDS: { file: string; ops: string[] }[] = [
  { file: "src/lib/commands/result.ts", ops: ["toCommandResult"] },
  { file: "src/features/team/commands.ts", ops: ["planResult"] },
  { file: "src/features/absence/commands.ts", ops: ["takeOpenVisit"] },
  { file: "src/features/cover/commands.ts", ops: ["acceptCover"] },
  { file: "src/features/ai/commands.ts", ops: ["confirmSuggestion", "confirmSuggestions"] },
];

/** The body of `function <name>(` up to the next top-level `function` or `export`. */
function body(src: string, name: string): string {
  const at = src.search(new RegExp(`function ${name}\\(`));
  expect(at, `${name} not found`).toBeGreaterThanOrEqual(0);
  const rest = src.slice(at + 1);
  const end = rest.search(/\n(export |function |async function )/);
  return end < 0 ? rest : rest.slice(0, end);
}

describe("every assignment and start command maps the QUAL1 refusal (UXR-132)", () => {
  for (const { file, ops } of COMMANDS) {
    const src = readFileSync(file, "utf8");
    for (const op of ops) {
      it(`${file} ${op}`, () => {
        // From the error branch on (a schema refusal before the call is not a database answer).
        const whole = body(src, op);
        const branch = whole.indexOf("if (error)");
        expect(branch, `${op} has no error branch`).toBeGreaterThanOrEqual(0);
        const b = whole.slice(branch);
        const mapped = b.indexOf("qualificationRefusal(error)");
        expect(mapped, `${op} does not call qualificationRefusal(error)`).toBeGreaterThanOrEqual(0);
        // Before any generic error answer in the error branch.
        const generic = b.search(/error\.code === "42501"|error\.code === "22023"|MESSAGES\.failed|messages\.failed|nicht gespeichert werden/);
        expect(generic, `${op} has no generic error branch`).toBeGreaterThanOrEqual(0);
        expect(mapped).toBeLessThan(generic);
      });
    }
  }
});
