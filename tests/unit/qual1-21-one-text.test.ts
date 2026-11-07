import { readFileSync, readdirSync } from "node:fs";
import { describe, expect, it } from "vitest";
import {
  QUAL_NO_PROPOSAL_TEXT,
  QUAL_REASON_CODES,
  QUAL_PROVISIONAL_HEADER,
  QUAL_PROVISIONAL_WORDING,
  qualReasonText,
  qualRefusalText,
  type QualSubject,
} from "@/features/qualification/refusals";
import {
  QUALIFICATION_LAPSED_MESSAGE,
  QUALIFICATION_NOT_ALLOWED_MESSAGE,
  qualificationRefusal,
  toCommandResult,
} from "@/lib/commands/result";
import { REFUSAL_TEXT, refusalText } from "@/features/ai/labels";
import { DAY_PLAN_NOT_FOUND } from "@/features/planning/day-plan-labels";
import { SIMULATION_BANNER } from "@/features/qualification/labels";

/**
 * QUAL1-21 (brief docs/agents/briefs/QUAL1.md, PO 2026-11-07 04:45; `uxa` UXR-129 to -133; ADR-166). Written before the
 * module. One reason, one text, on every path; only the subject changes ("<Name>" / "dich"); no verdict on a person
 * while the rules are PROPOSED; no register, matrix or rule code in user text. Words PROPOSED (`uxa`), `cra` to confirm.
 */

const SELF: QualSubject = { kind: "self" };
const MARA: QualSubject = { kind: "member", name: "Mara Muster" };
const CHOSEN: QualSubject = { kind: "chosen" };

/** QUAL1-21 (3), (4): the words no QUAL1 user text may carry. */
const BANNED = /darf|[Dd]iese Person|konnte nicht|\bgeeignet\b|nicht geeignet|PROPOSED|\b[A-C][0-9]+[A-Z]?\b|\bN1\b|CR-\d|K-\d|QUAL1|42501|\?\)|erneut|nochmals/;

describe("QUAL1-21 (1): one text per reason, only the subject changes", () => {
  it("knows every QUAL1 refusal and proposal reason once", () => {
    expect([...QUAL_REASON_CODES]).toEqual([
      "qualification_not_allowed",
      "qualification_lapsed",
      "needs_rn",
      "evidence_missing",
      "rule_unresolved",
      "delegation_missing",
      "not_member",
      "not_qualified",
    ]);
    expect(new Set(QUAL_REASON_CODES).size).toBe(QUAL_REASON_CODES.length);
  });

  for (const reason of QUAL_REASON_CODES) {
    it(`${reason}: the subject is the only difference`, () => {
      const self = qualReasonText(reason, SELF);
      const mara = qualReasonText(reason, MARA);
      const chosen = qualReasonText(reason, CHOSEN);
      expect(self).toMatch(/[Ff]ür dich\b/);
      expect(mara).toBe(self.replace(/([Ff]ür) dich/, "$1 Mara Muster"));
      expect(chosen).toBe(self.replace(/([Ff]ür) dich/, "$1 die gewählte Person"));
      for (const t of [self, mara, chosen]) {
        expect(t).not.toMatch(BANNED);
        expect(t.length).toBeLessThanOrEqual(200);
      }
    });
  }

  it("an unknown reason fails closed: it claims nothing about the person", () => {
    const t = qualReasonText("something_new" as never, MARA);
    expect(t).not.toMatch(BANNED);
    expect(t).toContain("Mara Muster");
    expect(t).toContain("nicht erfasst");
  });

  it("a name is shown as given, never as code; an empty name falls back to the neutral subject", () => {
    expect(qualReasonText("evidence_missing", { kind: "member", name: "  " })).toBe(qualReasonText("evidence_missing", CHOSEN));
  });
});

describe("QUAL1-21 (2), (5): the two database refusals, per context", () => {
  it("assignment paths (save) and visit start keep the slice 2 texts, now built by the one function", () => {
    expect(QUALIFICATION_NOT_ALLOWED_MESSAGE).toBe(qualRefusalText("qualification_not_allowed", CHOSEN, "save"));
    expect(QUALIFICATION_LAPSED_MESSAGE).toBe(qualRefusalText("qualification_lapsed", SELF, "start"));
  });

  it("start: only what is decided (nothing written, the visit stays planned); no invented confirming role", () => {
    const t = qualRefusalText("qualification_lapsed", SELF, "start");
    expect(t.startsWith("Nicht begonnen: ")).toBe(true);
    expect(t).toContain("bleibt geplant");
    expect(t).not.toMatch(/Administration|Pflegeleitung|Fachverantwortung|Clinical Owner|bestätigt von/);
  });

  it("take and cover name her own refusal (subject: dich), not the chosen person", () => {
    const t = qualificationRefusal({ code: "42501", message: "qualification_not_allowed" }, { subject: SELF, context: "take" });
    expect(t).toBe(qualRefusalText("qualification_not_allowed", SELF, "take"));
    expect(t).toContain("Nicht übernommen: Für dich");
    expect(t).not.toContain("gewählte Person");
  });

  it("every context starts with what happened and never states a verdict", () => {
    for (const reason of QUAL_REASON_CODES) {
      for (const ctx of ["save", "start", "take", "confirm"] as const) {
        const t = qualRefusalText(reason, MARA, ctx);
        expect(t).toMatch(/^Nicht (gespeichert|begonnen|übernommen): /);
        expect(t).toContain(qualReasonText(reason, MARA));
        expect(t).not.toMatch(BANNED);
        expect(t.length).toBeLessThanOrEqual(260);
      }
    }
  });

  it("toCommandResult and qualificationRefusal return the shared text for both codes", () => {
    const M = { rejected: "abgelehnt", failed: "fehlgeschlagen" };
    expect(toCommandResult(null, { code: "42501", message: "qualification_not_allowed" }, M)).toEqual({
      ok: false,
      error: qualRefusalText("qualification_not_allowed", CHOSEN, "save"),
    });
    expect(toCommandResult(null, { code: "42501", message: "qualification_lapsed" }, M)).toEqual({
      ok: false,
      error: qualRefusalText("qualification_lapsed", SELF, "start"),
    });
    // The lapsed refusal is always her own start, whatever subject a caller passes.
    expect(qualificationRefusal({ code: "42501", message: "qualification_lapsed" }, { subject: MARA, context: "take" })).toBe(
      QUALIFICATION_LAPSED_MESSAGE,
    );
  });
});

describe("QUAL1-21 (1): the other paths call the one function", () => {
  it("AIG1 confirm: the J3 refusal for a ticked member names no verdict and no 'Diese Person'", () => {
    expect(REFUSAL_TEXT.not_qualified).toBe(qualRefusalText("not_qualified", CHOSEN, "confirm"));
    expect(refusalText("not_qualified")).not.toMatch(BANNED);
  });

  it("day plan: the RN rule's 'no proposal' line is the shared one", () => {
    expect(DAY_PLAN_NOT_FOUND.needs_rn).toBe(QUAL_NO_PROPOSAL_TEXT.needs_rn);
    expect(QUAL_NO_PROPOSAL_TEXT.needs_rn).not.toMatch(BANNED);
  });

  it("QUAL1-21 (4): one provisional wording; the banner uses it and no code", () => {
    expect(QUAL_PROVISIONAL_WORDING).toBe("vorläufige Regel");
    expect(QUAL_PROVISIONAL_HEADER).toBe("Regel vorläufig, nicht fachlich freigegeben");
    expect(SIMULATION_BANNER).toBe(`Simulation · synthetische Daten · ${QUAL_PROVISIONAL_HEADER}`);
    expect(SIMULATION_BANNER).not.toMatch(BANNED);
  });
});

/** The body of `function <name>(` up to the next top-level `function` or `export` (same helper as qual1-command-refusals). */
function body(src: string, name: string): string {
  const at = src.search(new RegExp(`function ${name}\\(`));
  expect(at, `${name} not found`).toBeGreaterThanOrEqual(0);
  const rest = src.slice(at + 1);
  const end = rest.search(/\n(export |function |async function )/);
  return end < 0 ? rest : rest.slice(0, end);
}

describe("QUAL1-21 (2): the remaining commands map the refusal before their generic branch", () => {
  const COMMANDS: { file: string; ops: string[] }[] = [
    { file: "src/features/planning/day-plan-commands.ts", ops: ["proposeDayPlan"] },
    // PLAN2 series (set_care_plan_schedule, plan_from_care_plan): since 0122 the series leaves a visit open instead of
    // raising, so this is defence in depth for a race; it must still never read "konnte nicht".
    { file: "src/features/planning/commands.ts", ops: ["fromJson"] },
  ];
  for (const { file, ops } of COMMANDS) {
    const src = readFileSync(file, "utf8");
    for (const op of ops) {
      it(`${file} ${op}`, () => {
        const b = body(src, op).slice(body(src, op).indexOf("if (error)"));
        const mapped = b.indexOf("qualificationRefusal(error");
        expect(mapped, `${op} does not call qualificationRefusal`).toBeGreaterThanOrEqual(0);
        const generic = b.search(/error\.code === "42501"|error\.code === "22023"|MESSAGES\.failed/);
        expect(generic).toBeGreaterThanOrEqual(0);
        expect(mapped).toBeLessThan(generic);
      });
    }
  }

  it("take and cover pass her as the subject", () => {
    expect(readFileSync("src/features/absence/commands.ts", "utf8")).toMatch(/qualificationRefusal\(error, \{ subject: \{ kind: "self" \}, context: "take" \}\)/);
    expect(readFileSync("src/features/cover/commands.ts", "utf8")).toMatch(/qualificationRefusal\(error, \{ subject: \{ kind: "self" \}, context: "take" \}\)/);
  });
});

/** The string literals of a TypeScript source, comments removed (a coarse scanner, enough for these modules). */
function literals(src: string): string[] {
  const noComments = src.replace(/\/\*[\s\S]*?\*\//g, "").replace(/(^|[^:])\/\/.*$/gm, "$1");
  return [...noComments.matchAll(/"((?:[^"\\\n]|\\.)*)"|`((?:[^`\\]|\\.)*)`/g)].map((m) => m[1] ?? m[2] ?? "");
}

describe("QUAL1-21 (3), (4): no user text in src/features/qualification carries a code, PROPOSED or a verdict", () => {
  // Internal result codes (QUAL_RESULTS, CR-183 codes, requirement keys) are identifiers, not user text.
  const INTERNAL = new Set([
    "allowed_own", "allowed_delegated", "not_allowed", "unresolved", "evidence_missing", "evidence_expired",
    "evidence_contradictory", "delegation_missing", "delegation_expired", "delegation_review_needed",
    "geeignet", "geeignet mit Delegation", "nicht geeignet", "ungeklärt",
  ]);
  for (const file of readdirSync("src/features/qualification").filter((f) => f.endsWith(".ts"))) {
    it(file, () => {
      for (const s of literals(readFileSync(`src/features/qualification/${file}`, "utf8"))) {
        if (INTERNAL.has(s) || /^[a-z0-9_:?-]*$/.test(s)) continue;
        expect(s, `${file}: "${s}"`).not.toMatch(/PROPOSED|\b[A-C][0-9]+[A-Z]?\b|darf|[Dd]iese Person|konnte nicht/);
      }
    });
  }
});
