// ADR-208 (founder decision 2026-11-19, live session: the measurement «muss zwingend eingeführt werden»; mode chosen by
// the founder: «Sperrklinke»). Pure module (no Playwright import), unit-tested in tests/unit/handgrip-budget.test.ts.
//
// A handgrip is one human act on the BK path after the person is signed in on her landing page: one tap (button, link,
// radio, checkbox, menu), one field filled or chosen, one submit. Sign-in, reading and waiting are not handgrips
// (definition in ADR-208 (2); the PO may sharpen it, `eng` never widens it to make a number smaller).
//
// The ratchet: the committed baseline (tests/e2e/handgrip-baseline.json) is the limit per role.
//   measured > baseline → fail «over_baseline» (a step got more work; only the PO may raise the baseline);
//   measured < baseline → fail «lower_baseline» (lower the file in the same PR, so the limit only ever goes down);
//   measured = baseline → «held». The gap to the Blueprint target is reported on every run and never asserted away.

export const HANDGRIP_ROLES = ["auftraggeber", "team", "pflege_nach_schicht"] as const;
export type HandgripRole = (typeof HANDGRIP_ROLES)[number];

/** Blueprint V3.2 §6.3: «höchstens einer beim Auftraggeber, einer im Team, drei bei der Pflegekraft nach der Schicht». */
export const HANDGRIP_TARGET: Readonly<Record<HandgripRole, number>> = Object.freeze({
  auftraggeber: 1,
  team: 1,
  pflege_nach_schicht: 3,
});

const ROLE_LABEL: Record<HandgripRole, string> = {
  auftraggeber: "Auftraggeber",
  team: "Team",
  pflege_nach_schicht: "Pflegekraft nach der Schicht",
};

export type HandgripOutcome = "held" | "over_baseline" | "lower_baseline";

export type HandgripVerdict = {
  role: HandgripRole;
  measured: number;
  baseline: number;
  target: number;
  gap: number;
  outcome: HandgripOutcome;
  message?: string;
};

function wholeCount(value: unknown, what: string): number {
  if (typeof value !== "number" || !Number.isInteger(value) || value < 0) {
    throw new Error(`handgrip ratchet: ${what} must be a whole number of 0 or more, got ${String(value)}`);
  }
  return value;
}

export function judgeHandgrips(role: HandgripRole, measured: number, baseline: number): HandgripVerdict {
  const m = wholeCount(measured, `measured count of ${role}`);
  const b = wholeCount(baseline, `baseline of ${role}`);
  const target = HANDGRIP_TARGET[role];
  const verdict: HandgripVerdict = { role, measured: m, baseline: b, target, gap: Math.max(0, m - target), outcome: "held" };
  if (m > b) {
    verdict.outcome = "over_baseline";
    verdict.message =
      `${ROLE_LABEL[role]}: ${m} Handgriffe, ${m - b} mehr Handgriffe als die Basislinie (${b}). ` +
      "Mehr Arbeit für Menschen ist ein Rückschritt; die Basislinie hebt nur der PO an (ADR-208).";
  } else if (m < b) {
    verdict.outcome = "lower_baseline";
    verdict.message =
      `${ROLE_LABEL[role]}: ${m} statt ${b} Handgriffe, eine Verbesserung. Bitte die Basislinie in ` +
      `tests/e2e/handgrip-baseline.json im selben PR auf ${m} senken (Sperrklinke, ADR-208).`;
  }
  return verdict;
}

/** The committed baseline: an object of known roles to whole numbers. Anything else is a broken file. */
export function parseBaseline(raw: unknown): Partial<Record<HandgripRole, number>> {
  if (raw === null || typeof raw !== "object" || Array.isArray(raw)) {
    throw new Error("handgrip ratchet: the baseline must be an object of role → count");
  }
  const out: Partial<Record<HandgripRole, number>> = {};
  for (const [key, value] of Object.entries(raw as Record<string, unknown>)) {
    if (key.startsWith("_")) continue; // comment keys such as «_note»
    if (!(HANDGRIP_ROLES as readonly string[]).includes(key)) {
      throw new Error(`handgrip ratchet: unknown role «${key}» in the baseline`);
    }
    out[key as HandgripRole] = wholeCount(value, `baseline of ${key}`);
  }
  return out;
}

const OUTCOME_LABEL: Record<HandgripOutcome, string> = {
  held: "gehalten",
  over_baseline: "ÜBER der Basislinie",
  lower_baseline: "besser, Basislinie senken",
};

export function handgripReport(verdicts: ReadonlyArray<HandgripVerdict>): string {
  return [
    "ADR-208: Handgriffe je Auftrag auf dem BK-Pfad (Sperrklinke; Ziel aus Blueprint V3.2 §6.3).",
    "",
    "| Rolle | gemessen | Grenze (Basislinie) | Ziel | Lücke zum Ziel | Ergebnis |",
    "|---|---|---|---|---|---|",
    ...verdicts.map(
      (v) => `| ${ROLE_LABEL[v.role]} | ${v.measured} | ${v.baseline} | ${v.target} | ${v.gap} | ${OUTCOME_LABEL[v.outcome]} |`,
    ),
  ].join("\n");
}
