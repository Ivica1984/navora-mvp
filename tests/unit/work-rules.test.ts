import { describe, expect, it } from "vitest";
import {
  NOTICE_PARAGRAPHS, NOTICE_VERSION, unexportedText, buildCsv, buildPayload, elapsedMinutes, endInstant, openQuestions,
  proposalSegments, visitCorrectionHref, visitSegmentChanged, zurichInstant, zurichLocalWithOffset, VISIT_TIME_HINT,
  type DayDraft, type MonthExport,
} from "@/features/work/rules";

// WORK1 (migration 0079, ADR-092): pure rules of the working-day proposal, confirmation payload and CSV export.

describe("Zurich local time ↔ instant (same rule as the database, DST1)", () => {
  it("summer and winter offsets", () => {
    expect(zurichInstant("2026-10-22", "07:00")).toBe("2026-10-22T07:00:00+02:00");
    expect(zurichInstant("2026-12-01", "07:00")).toBe("2026-12-01T07:00:00+01:00");
  });
  it("the repeated autumn hour reads as the earlier instant; the spring gap in standard time", () => {
    expect(zurichInstant("2026-10-25", "02:30")).toBe("2026-10-25T02:30:00+02:00");
    expect(zurichInstant("2026-03-29", "02:30")).toBe("2026-03-29T02:30:00+01:00");
  });
  it("refuses malformed input", () => {
    expect(zurichInstant("2026-10-22", "7:00")).toBeNull();
    expect(zurichInstant("22.10.2026", "07:00")).toBeNull();
  });
  it("an end before the start lies on the next day (night shift)", () => {
    expect(endInstant("2026-10-22", "22:00", "06:00")).toBe("2026-10-23T06:00:00+02:00");
  });
  it("local time with UTC offset, on both sides of the clock change (WORK1-4)", () => {
    expect(zurichLocalWithOffset("2026-10-25T00:30:00Z")).toBe("2026-10-25T02:30:00+02:00");
    expect(zurichLocalWithOffset("2026-10-25T01:30:00Z")).toBe("2026-10-25T02:30:00+01:00");
  });
  it("elapsed minutes are real minutes, also across the repeated hour (WORK1-3)", () => {
    expect(elapsedMinutes("2026-10-25T02:30:00+02:00", "2026-10-25T02:30:00+01:00")).toBe(60);
  });
});

describe("the day is never complete by default (WORK1-2)", () => {
  const base = { dayStart: "06:45", dayEnd: "16:00", breaks: "none" as const, outside: "none" as const };
  it("both questions and start and end must be answered", () => {
    expect(openQuestions(base)).toEqual([]);
    expect(openQuestions({ ...base, breaks: null })).toEqual(["breaks"]);
    expect(openQuestions({ ...base, outside: [] })).toEqual(["outside_work"]);
    expect(openQuestions({ ...base, dayStart: "", dayEnd: "" })).toEqual(["day_start", "day_end"]);
  });
  it("an unanswered question stays absent from the payload, so the database refuses it (questions_open)", () => {
    const p = buildPayload({ date: "2026-10-22", ...base, breaks: null, segments: [] });
    expect(p).not.toHaveProperty("breaks");
    expect(p.outside_work).toBe("none");
  });
  it("'keine' is an explicit answer and lists become instants with offset", () => {
    const p = buildPayload({
      date: "2026-10-22", ...base, segments: [],
      breaks: [{ start: "12:00", end: "12:30" }],
      outside: [{ kind: "administration", start: "16:30", end: "17:00" }],
    });
    expect(p.breaks).toEqual([{ start: "2026-10-22T12:00:00+02:00", end: "2026-10-22T12:30:00+02:00" }]);
    expect(p.outside_work).toEqual([{ kind: "administration", start: "2026-10-22T16:30:00+02:00", end: "2026-10-22T17:00:00+02:00" }]);
    expect(p.day_start).toBe("2026-10-22T06:45:00+02:00");
  });
  it("the report sign time is a point, never a segment to confirm; open ends stay open", () => {
    expect(proposalSegments([
      { seq: 1, visit_no: 1, kind: "care", starts_at: "2026-10-22T05:15:00Z", ends_at: null },
      { seq: 2, visit_no: null, kind: "report_signed", starts_at: "2026-10-22T06:00:00Z", ends_at: "2026-10-22T06:00:00Z" },
    ])).toEqual([{ kind: "care", start: "2026-10-22T05:15:00Z", end: null, origin: { start: "2026-10-22T05:15:00Z", end: null, corrected: false } }]);
  });
});

describe("CSV export (WORK1-4)", () => {
  const e: MonthExport = {
    month: "2026-10",
    unconfirmed: ["2026-10-23"],
    days: [{
      date: "2026-10-25", version: 2, confirmed_at: "2026-10-26T11:00:00Z",
      day_start: "2026-10-25T00:00:00Z", day_end: "2026-10-25T02:30:00Z", breaks_answer: "none", outside_answer: "listed",
      paid_minutes: 150,
      entries: [
        { kind: "care", start: "2026-10-25T00:30:00Z", end: "2026-10-25T01:30:00Z", minutes: 60 },
        { kind: "administration", start: "2026-10-25T02:00:00Z", end: "2026-10-25T02:30:00Z", minutes: 30 },
      ],
    }],
  };
  const csv = buildCsv(e);
  const lines = csv.trimEnd().split("\r\n");
  it("lists unconfirmed days by date in the header, never filled", () => {
    expect(lines[1]).toBe("# nicht bestätigt: 2026-10-23");
    expect(csv).not.toContain("2026-10-23;");
  });
  it("has the columns date, kind, start, end (local with offset), minutes, version, confirmed at", () => {
    expect(lines[2]).toBe("datum;art;beginn;ende;minuten;fassung;bestaetigt_am");
    expect(lines).toContain("2026-10-25;Pflege im Einsatz;2026-10-25T02:30:00+02:00;2026-10-25T02:30:00+01:00;60;2;2026-10-26T12:00:00+01:00");
    expect(lines).toContain("2026-10-25;Arbeitstag;2026-10-25T02:00:00+02:00;2026-10-25T03:30:00+01:00;150;2;2026-10-26T12:00:00+01:00");
    expect(lines).toContain("2026-10-25;Pause (30 Min. oder mehr): keine;;;;2;2026-10-26T12:00:00+01:00");
  });
  it("carries no note, client, case or visit identifier", () => {
    expect(csv).not.toMatch(/note|notiz|visit|case|klient/i);
  });
});

describe("information text (WORK1-8)", () => {
  it("names both uses: team coordination and her own proposal", () => {
    const text = NOTICE_PARAGRAPHS.join(" ");
    expect(text).toContain("damit ihr die Pflege koordinieren könnt");
    expect(text).toContain("siehst nur du");
    expect(NOTICE_VERSION).toBe("work1-notice-v3");
  });

  // WORK1-C2 (migration 0083): the four statements of v2 (D-23 item 15, lca gaps b, c, d); paragraph 5 stays.
  it("v2 names who else sees status times and corrections (gap b)", () => {
    const text = NOTICE_PARAGRAPHS.join(" ");
    expect(text).toContain("Personen, die dein Team vertreten (Stellvertretung), sehen diese Statuszeiten");
    expect(text).toContain("sehen die Mitglieder deines Teams den Grund der Korrektur und wer korrigiert hat");
  });

  it("v2 names the log instead of 'nobody else, the administration included' (gap c)", () => {
    const text = NOTICE_PARAGRAPHS.join(" ");
    expect(text).toContain("NAVORA protokolliert deine Bestätigungen und Exporte");
    expect(text).toContain("Datum, Fassung und Korrekturgrund");
    expect(text).toContain("Monat und Anzahl Tage, nie Uhrzeiten oder Notizen");
    expect(text).toContain("nur für einen angegebenen Prüfzweck gelesen");
    expect(text).not.toMatch(/Niemand sonst/);
    expect(text).toContain("wie viele bestätigte Tage du noch nicht exportiert hast");
  });

  it("v2 says why the team ratio exists and when it is shown (gap d); no labour-law check stays", () => {
    const text = NOTICE_PARAGRAPHS.join(" ");
    expect(text).toContain("wie viel der bestätigten bezahlten Arbeitszeit auf direkte Pflege entfällt");
    expect(text).toContain("Planung im Team und der Auswertung des Pilotbetriebs");
    expect(text).toContain("erst ab drei Personen und fünf bestätigten Arbeitstagen");
    expect(NOTICE_PARAGRAPHS).toContain("NAVORA prüft keine Pausen-, Ruhe- oder Höchstarbeitszeiten.");
  });
});

// COND1-5b (migration 0085): v3 keeps every statement of v2 (the tests above) and adds five (PO 17:15, lca 16:42).
describe("information text v3 (COND1-5b)", () => {
  const text = NOTICE_PARAGRAPHS.join(" ");
  it("(i) names who reads the log: the administration of her organisation, only for a stated audit purpose", () => {
    expect(text).toContain("Dieses Protokoll liest die Administration deiner Organisation");
    expect(text).toContain("nur für einen angegebenen Prüfzweck gelesen");
  });
  it("(ii) the next sentence begins with the fixed phrase", () => {
    expect(text).toMatch(/Prüfzweck gelesen\. Ausserhalb einer solchen Prüfung sieht die Administration nur, wie viele bestätigte Tage/);
  });
  it("(iii) the covering member also sees reason and author of a correction", () => {
    expect(text).toContain("Auch wer dein Team vertritt (Vertretung), sieht den Grund und wer korrigiert hat.");
  });
  it("(iv) coordination roles outside the team see that a time was corrected, old and new value and when, not the reason", () => {
    expect(text).toContain("Koordinationsrollen ausserhalb deines Teams sehen nur, dass eine Einsatzzeit korrigiert wurde");
    expect(text).toContain("(alter und neuer Wert, Zeitpunkt der Korrektur), nicht den Grund");
  });
  it("(v) no export after her access ends; days not exported by then stay unexported", () => {
    expect(text).toContain("Nach dem Ende deines Zugangs kannst du nicht mehr exportieren");
    expect(text).toContain("bleiben unexportiert");
  });
  it("keeps the COND1-5a purpose sentence as written", () => {
    expect(text).toContain("damit sie dich vor dem Ende deines Zugangs an den Export erinnern kann");
  });
});

// WORK1-C3 (d) (migration 0083): her own count on /work, with a prompt to export.
describe("unexported days on /work (WORK1-C3 d)", () => {
  it("prompts her to export when days are open, and stays quiet otherwise", () => {
    expect(unexportedText(1)).toBe("1 bestätigter Tag ist noch nicht exportiert. Exportiere seinen Monat und gib die Datei deiner Arbeitgeberin.");
    expect(unexportedText(3)).toMatch(/^3 bestätigte Tage sind noch nicht exportiert\./);
    expect(unexportedText(0)).toBe("Alle bestätigten Tage sind exportiert.");
    expect(unexportedText(null)).toBeNull();
    expect(unexportedText(-1)).toBeNull();
  });
});

// WORK1-C4 (migration 0081, ADR-094): one time per visit event.
describe("visit segments and the visit's time correction (WORK1-C4)", () => {
  const rows = [
    { seq: 1, visit_no: 1, kind: "travel", starts_at: "2026-10-22T06:00:00Z", ends_at: "2026-10-22T06:20:00Z", corrected: true },
    { seq: 2, visit_no: 1, kind: "care", starts_at: "2026-10-22T06:20:00Z", ends_at: "2026-10-22T07:00:00Z", corrected: false },
  ];
  const draft = (): DayDraft => ({
    date: "2026-10-22", dayStart: "", dayEnd: "", segments: proposalSegments(rows), breaks: null, outside: null,
  });
  it("a segment from a corrected event carries the mark from the proposal", () => {
    expect(proposalSegments(rows).map((s) => s.origin?.corrected)).toEqual([true, false]);
  });
  it("editing a visit segment shows the hint and the link to the visit's time correction", () => {
    const d = draft();
    const edited = { ...d.segments[1], end: zurichInstant("2026-10-22", "09:10") };
    expect(visitSegmentChanged(edited)).toBe(true);
    expect(VISIT_TIME_HINT).toBe("Die Zeit im Einsatz bleibt unverändert. Korrigieren Sie sie im Einsatz, damit Bericht und Abrechnung stimmen.");
    expect(visitCorrectionHref(edited.origin, d.date)).toBe("/field?datum=2026-10-22&zeit=2026-10-22T06%3A20%3A00.000Z#einsatz-korrektur");
  });
  it("editing the day start does not (no visit segment changed); the same instant written differently is no change", () => {
    const d = { ...draft(), dayStart: "06:45" };
    expect(d.segments.some(visitSegmentChanged)).toBe(false);
    expect(visitSegmentChanged({ ...d.segments[0], start: "2026-10-22T08:00:00+02:00" })).toBe(false);
  });
  it("the link uses the Zurich date of the segment (a segment just before midnight belongs to that day)", () => {
    expect(visitCorrectionHref({ start: "2026-10-22T21:55:00Z", end: "2026-10-22T22:20:00Z", corrected: true }, "2026-10-22"))
      .toBe("/field?datum=2026-10-22&zeit=2026-10-22T21%3A55%3A00.000Z#einsatz-korrektur");
    expect(visitCorrectionHref(undefined, "2026-10-22")).toBe("/field?datum=2026-10-22");
  });
  it("the confirm payload carries no origin and no mark (her confirmation is stored as she entered it)", () => {
    const p = buildPayload({ ...draft(), dayStart: "07:30", dayEnd: "16:00", breaks: "none", outside: "none" });
    expect(p.segments).toEqual([
      { kind: "travel", start: "2026-10-22T06:00:00Z", end: "2026-10-22T06:20:00Z" },
      { kind: "care", start: "2026-10-22T06:20:00Z", end: "2026-10-22T07:00:00Z" },
    ]);
  });
});
