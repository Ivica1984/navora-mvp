import { describe, expect, it } from "vitest";
import { ACCESS_HELP_TEXT, CODE_REFUSED, FROM_INTAKE, NOT_RECORDED, accessHistory, accessLine, looksLikeCode } from "@/features/door/rules";
import { alertFlagLabels, handlerLabel } from "@/features/operations/exceptions";
import { eventStatusText } from "@/features/quality/rules";
import { TAKE_ENDED } from "@/features/signals/rules";

// COND1-1 / COND1-2 display rules (migration 0080, ADR-093). Synthetic values only.

const teamValue = {
  value: "ja",
  note: "Synthetisch: Schlüssel bei der Nachbarin",
  source: "team",
  recorded_at: "2026-10-26T08:10:00Z",
  actor_kind: "team",
  actor_name: "Synthetisch Kollegin",
};

describe("DOOR1-13: one Zugang line", () => {
  it("intake note only → one line «aus der Aufnahme» with the intake date", () => {
    expect(accessLine({ intakeNote: " Synthetisch: Schlüssel im Briefkasten ", intakeOn: "2026-10-16", current: null })).toEqual({
      kind: "intake",
      note: "Synthetisch: Schlüssel im Briefkasten",
      meta: `${FROM_INTAKE} · 16.10.2026`,
    });
  });

  it("intake note plus a later team value → one line with the team value; the intake note only in the history, earliest", () => {
    const line = accessLine({ intakeNote: "Synthetisch: Schlüssel im Briefkasten", intakeOn: "2026-10-16", current: teamValue });
    expect(line.kind).toBe("value");
    if (line.kind !== "value") return;
    expect(line.value).toBe("ja");
    expect(line.note).toBe("Synthetisch: Schlüssel bei der Nachbarin");
    expect(line.meta).toContain("Synthetisch Kollegin");
    expect(line.meta).toContain("Quelle: Team");

    const history = accessHistory([
      { ...teamValue, from_intake: false },
      { value: null, note: "Synthetisch: Schlüssel im Briefkasten", source: "referral", recorded_at: "2026-10-16T09:00:00Z",
        actor_kind: null, actor_name: null, from_intake: true },
    ]);
    expect(history).toHaveLength(2);
    expect(history[0].value).toBe("ja");
    expect(history[1]).toEqual({ value: null, note: "Synthetisch: Schlüssel im Briefkasten", meta: `${FROM_INTAKE} · 16.10.2026 · Quelle: Zuweisung` });
  });

  it("neither → «nicht erfasst»", () => {
    expect(accessLine({ intakeNote: "  ", intakeOn: "2026-10-16", current: null })).toEqual({ kind: "none", text: NOT_RECORDED });
    expect(accessLine({ intakeNote: null, intakeOn: null, current: { ...teamValue, value: null } })).toEqual({ kind: "none", text: NOT_RECORDED });
  });

  it("no history while only the intake note exists (it is the line itself)", () => {
    expect(accessHistory([{ value: null, note: "Synthetisch", source: "referral", recorded_at: "2026-10-16T09:00:00Z",
                            actor_kind: null, actor_name: null, from_intake: true }])).toEqual([]);
  });
});

describe("DOOR1-12: the same code guard for the intake note", () => {
  it.each([["Schlüsselsafe 4711", true], ["Safe 47 11", true], ["4-7-1-1", true], ["Haus 123", false], ["Tür 3, Stock 12", false]])(
    "%s → refused: %s", (note, refused) => {
      expect(looksLikeCode(note)).toBe(refused);
    });
  it("names the refusal in the fixed text", () => {
    expect(CODE_REFUSED).toBe("Bitte keinen Code erfassen");
  });
});

describe("COND1-9 = DOOR1-15: the guard stays; the help text names the phone number", () => {
  it.each([["079 123 45 67", true], ["8004 Zürich", true], ["Schlüssel bei der Tochter, Hintereingang", false]])(
    "%s → refused: %s", (note, refused) => {
      expect(looksLikeCode(note)).toBe(refused);
    });
  it("reads exactly as decided (intake and the DOOR1-4 note, migration 0084)", () => {
    expect(ACCESS_HELP_TEXT).toBe("Ort und wer den Schlüssel hat (ohne Telefonnummer), nie den Code");
  });
});

describe("LEAVE1-C4: no leaver's name on a claim nobody holds", () => {
  it("an OPS1 take of a person whose access ended reads as untaken, with the fixed text", () => {
    expect(handlerLabel({ priority: "P2", since: "2026-10-26T06:00:00Z", taken: false, taken_by_me: false, owner_name: null }))
      .toBe("offen – niemand übernommen");
    expect(alertFlagLabels(["take_access_ended"])).toEqual([TAKE_ENDED]);
    expect(TAKE_ENDED).toBe("Übernahme beendet – Zugang beendet");
  });

  it("a quality event in review whose owner's access ended shows the fixed text, never a name", () => {
    expect(eventStatusText({ status: "in_review", claim_ended: true })).toBe(TAKE_ENDED);
    expect(eventStatusText({ status: "in_review", claim_ended: false })).toBe("in Prüfung");
    expect(eventStatusText({ status: "open", claim_ended: null })).toBe("offen");
  });
});
