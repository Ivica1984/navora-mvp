import { describe, expect, it } from "vitest";
import {
  CANCEL_CONSEQUENCE,
  HOLD_CONSEQUENCE,
  earliestTakeableToday,
  orderFieldVisits,
  pickNextVisit,
} from "@/features/field/rules";
import { HOLD_MEANING } from "@/features/quality/rules";
import { NOTICE_DRAFT_HINT, NOTICE_HEADINGS, NOTICE_LEAD, NOTICE_PARAGRAPHS, NOTICE_VERSION } from "@/features/work/rules";

// UX1 part (c) (ADR-104): the /field order, the "Offen im Team" header row, the "Mehr" consequence lines, and the
// UX1-21 lead line and headings of the WORK1 notice. Synthetic rows only.

type V = { visit_id: string; status: string | null; time_start: string | null; responsible_me: boolean | null; suspended: boolean | null };
const v = (id: string, status: string | null, time: string | null, mine = false, suspended = false): V => ({
  visit_id: id, status, time_start: time, responsible_me: mine, suspended,
});

describe("UX1-6: the next visit", () => {
  it("picks her own earliest planned visit before the team's", () => {
    const visits = [v("a", "planned", "07:00:00"), v("b", "planned", "09:00:00", true), v("c", "planned", "08:00:00", true)];
    expect(pickNextVisit(visits)?.visit_id).toBe("c");
  });

  it("prefers a running visit (on the way, started, paused) of hers over an earlier planned one", () => {
    expect(pickNextVisit([v("a", "planned", "07:00:00", true), v("b", "started", "08:00:00", true)])?.visit_id).toBe("b");
    expect(pickNextVisit([v("a", "planned", "07:00:00", true), v("b", "on_the_way", "08:00:00", true)])?.visit_id).toBe("b");
    expect(pickNextVisit([v("a", "planned", "07:00:00", true), v("b", "paused", "08:00:00", true)])?.visit_id).toBe("b");
  });

  it("falls back to the team's open visits when none is hers", () => {
    expect(pickNextVisit([v("a", "planned", "10:00:00"), v("b", "planned", "08:00:00")])?.visit_id).toBe("b");
  });

  it("never picks a finished or suspended visit; a visit without time comes last", () => {
    const done = ["completed", "cancelled", "no_show", "interrupted", null].map((s, i) => v(`d${i}`, s, "07:00:00", true));
    expect(pickNextVisit(done)).toBeNull();
    expect(pickNextVisit([v("s", "planned", "07:00:00", true, true)])).toBeNull();
    expect(pickNextVisit([v("x", "planned", null, true), v("y", "planned", "12:00:00", true)])?.visit_id).toBe("y");
    expect(pickNextVisit([])).toBeNull();
  });

  it("keeps every visit: the next one first, the others in the order the database returned", () => {
    const visits = [v("a", "completed", "07:00:00", true), v("b", "planned", "09:00:00", true), v("c", "planned", "08:00:00")];
    const { next, rest } = orderFieldVisits(visits);
    expect(next?.visit_id).toBe("b");
    expect(rest.map((r) => r.visit_id)).toEqual(["a", "c"]);
    const none = orderFieldVisits([v("a", "completed", "07:00:00")]);
    expect(none.next).toBeNull();
    expect(none.rest.map((r) => r.visit_id)).toEqual(["a"]);
  });
});

describe("UX1-6a: the collapsed 'Offen im Team' header", () => {
  const today = "2026-10-27";
  const o = (id: string, date: string, time: string | null, may: boolean) => ({ visit_id: id, visit_date: date, time_start: time, may_take: may });

  it("shows the earliest visit of today she may take", () => {
    const open = [o("a", today, "14:00:00", true), o("b", today, "09:00:00", false), o("c", today, "11:00:00", true), o("d", "2026-10-28", "07:00:00", true)];
    expect(earliestTakeableToday(open, today)?.visit_id).toBe("c");
  });

  it("shows nothing when no visit of today may be taken by her", () => {
    expect(earliestTakeableToday([o("b", today, "09:00:00", false), o("d", "2026-10-28", "07:00:00", true)], today)).toBeNull();
    expect(earliestTakeableToday([], today)).toBeNull();
  });
});

describe("UX1-8: the consequence of the second step", () => {
  it("is one sentence each, and the hold's fixed meaning (CGR-13) is unchanged", () => {
    for (const text of [CANCEL_CONSEQUENCE, HOLD_CONSEQUENCE]) {
      expect(text.trim().length).toBeGreaterThan(10);
      expect(text.match(/[.!?]/g)).toHaveLength(1);
      expect(text.endsWith(".")).toBe(true);
    }
    expect(HOLD_CONSEQUENCE).toContain("nicht abgerechnet");
    expect(HOLD_MEANING).toBe("Gesperrt ist nur die Abrechnung; ob und wie gepflegt wird, regelt die Sperre nicht.");
  });

  it("does not claim the cancellation releases the visit to the team (cancel_visit sets it cancelled)", () => {
    expect(CANCEL_CONSEQUENCE).toContain("abgesagt");
    expect(CANCEL_CONSEQUENCE).not.toMatch(/Team|offen|frei/);
  });
});

describe("UX1-21: lead line and headings of the WORK1 notice (lca 2026-10-27 11:41)", () => {
  it("are the lca wording, word for word, one heading per paragraph in paragraph order", () => {
    expect(NOTICE_LEAD).toBe(
      "Bitte lies diese Information und tippe dann auf «Gelesen und verstanden». Danach siehst du deinen Arbeitstag. Ändert sich die Information, zeigen wir sie dir noch einmal.",
    );
    expect(NOTICE_HEADINGS).toEqual([
      "Wer deine Einsatzzeiten sieht",
      "Was nur du siehst",
      "Was NAVORA protokolliert und was die Administration sieht",
      "Was du tust (auch vor dem Ende deines Zugangs)",
      "Der Anteil für das ganze Team",
      "Was NAVORA nicht prüft",
    ]);
    expect(NOTICE_HEADINGS).toHaveLength(NOTICE_PARAGRAPHS.length);
  });

  it("leave the version, the paragraphs' count and the draft hint unchanged (PO decision: no version bump)", () => {
    expect(NOTICE_VERSION).toBe("work1-notice-v3");
    expect(NOTICE_PARAGRAPHS).toHaveLength(6);
    expect(NOTICE_PARAGRAPHS[5]).toBe("NAVORA prüft keine Pausen-, Ruhe- oder Höchstarbeitszeiten.");
    expect(NOTICE_DRAFT_HINT).toBe("Entwurf für die Arbeitgeberin (Testbetrieb mit synthetischen Daten).");
  });
});
