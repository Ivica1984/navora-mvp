import { describe, expect, it } from "vitest";
import {
  SIGNAL_POLL_MS,
  SIGNAL_TEXT,
  reasonText,
  signalHref,
  signalText,
  signalWhen,
  splitSignals,
  takeOutcome,
  takenText,
  TAKE_ENDED,
  OPERATIONS_APP_ONLY,
  OPERATIONS_FOLLOWS,
  operationsFollows,
  OUTSIDE_WATCHED_EMPTY,
  OUTSIDE_WATCHED_NOTE,
  outsideWatchedLine,
} from "@/features/signals/rules";

// SIG1 (migration 0060, ADR-074): fixed texts and the split between open and taken signals.
describe("safety signals (SIG1)", () => {
  it("has the brief's fixed text for each delivered kind (SIG1-3)", () => {
    expect(SIGNAL_TEXT).toEqual({
      visit_overdue: "Einsatz überfällig",
      visit_stuck: "Einsatz hängt",
      visit_uncovered: "Einsatz ohne Zuständige",
      visit_interrupted: "Einsatz abgebrochen",
      no_show: "Klientin öffnet nicht",
    });
    expect(signalText("unknown")).toBe("Sicherheitssignal");
  });

  it("polls often enough to show a new P1 within 60 seconds", () => {
    expect(SIGNAL_POLL_MS).toBeLessThanOrEqual(45_000);
  });

  it("names the visit's day, start and team, and links to that day; never the client", () => {
    const row = { visit_date: "2026-10-24", time_start: "07:00:00", team_name: "Testteam Nord" };
    expect(signalWhen(row)).toBe("24.10. 07:00 · Testteam Nord");
    expect(signalWhen({ ...row, time_start: null })).toBe("24.10. · Testteam Nord");
    expect(signalHref(row)).toBe("/field?datum=2026-10-24");
  });

  it("keeps untaken signals at the top and moves taken ones out (SIG1-4)", () => {
    const rows = [
      { id: 1, taken_by_me: false, taken_by_name: null },
      { id: 2, taken_by_me: false, taken_by_name: "Pflege Test" },
      { id: 3, taken_by_me: true, taken_by_name: "Assistenz Test" },
    ];
    const { open, taken } = splitSignals(rows);
    expect(open.map((r) => r.id)).toEqual([1]);
    expect(taken.map((r) => r.id)).toEqual([2, 3]);
    expect(takenText(rows[1])).toBe("übernommen von Pflege Test");
    expect(takenText(rows[2])).toBe("von dir übernommen");
  });

  it("keeps a no-show taken only by a care assistant at the top for the others (SIG1-C1)", () => {
    const rows = [
      { id: 1, taken_by_me: false, taken_by_name: "Assistenz Test", taken_by_qualification: "care_assistant", taken_awaits_rn: true, watched_now: true },
      { id: 2, taken_by_me: true, taken_by_name: "Assistenz Test", taken_by_qualification: "care_assistant", taken_awaits_rn: true, watched_now: true },
      { id: 3, taken_by_me: false, taken_by_name: "Pflege Test", taken_by_qualification: "registered_nurse", taken_awaits_rn: false },
    ];
    const { open, taken } = splitSignals(rows);
    expect(open.map((r) => r.id)).toEqual([1]);
    expect(taken.map((r) => r.id)).toEqual([2, 3]);
    expect(takenText(rows[0])).toBe("übernommen von Assistenz Test (Pflegehilfe), Meldung an Operations folgt");
    expect(takenText(rows[1])).toBe("von dir übernommen (Pflegehilfe), Meldung an Operations folgt");
    expect(takenText(rows[2])).toBe("übernommen von Pflege Test");
  });

  // LEAVE1-14 (CGR-62, migration 0078): a take by a person whose access has ended stops nothing and reads as untaken.
  it("keeps a signal whose taker's access ended at the top with the fixed text (LEAVE1-14)", () => {
    const rows = [
      { id: 1, taken_by_me: false, taken_by_name: null, taken_by_qualification: null, taken_awaits_rn: false, taker_access_ended: true },
      { id: 2, taken_by_me: false, taken_by_name: "Pflege Test", taken_by_qualification: "registered_nurse", taken_awaits_rn: false, taker_access_ended: false },
      { id: 3, taken_by_me: false, taken_by_name: "Leaver Test", taken_by_qualification: "registered_nurse", taken_awaits_rn: false, taker_access_ended: true },
    ];
    const { open, taken } = splitSignals(rows);
    expect(open.map((r) => r.id)).toEqual([1, 3]);
    expect(taken.map((r) => r.id)).toEqual([2]);
    expect(TAKE_ENDED).toBe("Übernahme beendet – Zugang beendet");
    expect(takenText(rows[0])).toBe(TAKE_ENDED);
    expect(takenText(rows[2])).toBe(TAKE_ENDED);
    expect(takenText(rows[1])).toBe("übernommen von Pflege Test");
  });

  // SIG2-C1 (1) (CGR-48, migration 0068): outside every watched period the step to Operations stays in the app.
  it("says that Operations is informed in the app only while no watched period runs (SIG2-C1 (1))", () => {
    const ca = { taken_by_me: false, taken_by_name: "Assistenz Test", taken_by_qualification: "care_assistant", taken_awaits_rn: true };
    expect(OPERATIONS_FOLLOWS).toBe("Meldung an Operations folgt");
    expect(OPERATIONS_APP_ONLY).toBe("Operations nur in der App: ausserhalb der besetzten Zeit");
    expect(takenText({ ...ca, watched_now: true })).toBe("übernommen von Assistenz Test (Pflegehilfe), Meldung an Operations folgt");
    expect(takenText({ ...ca, watched_now: false }))
      .toBe("übernommen von Assistenz Test (Pflegehilfe), Operations nur in der App: ausserhalb der besetzten Zeit");
    expect(takenText({ ...ca, taken_by_me: true, watched_now: false }))
      .toBe("von dir übernommen (Pflegehilfe), Operations nur in der App: ausserhalb der besetzten Zeit");
    // A reader row without the flag never promises the message to Operations.
    expect(takenText({ ...ca, watched_now: null })).toContain(OPERATIONS_APP_ONLY);
    expect(takenText(ca)).toContain(OPERATIONS_APP_ONLY);
    // A take that stops the step shows no Operations text at any hour.
    expect(takenText({ ...ca, taken_by_qualification: "registered_nurse", taken_awaits_rn: false, watched_now: false }))
      .toBe("übernommen von Assistenz Test");
  });

  // FUP1-2 (CGR-58, migration 0071): the text follows the Operations delivery, or the instant the step is due.
  it("follows operations_outside_app, not the reading instant, when the reader carries it (FUP1-2)", () => {
    const ca = { taken_by_me: false, taken_by_name: "Assistenz Test", taken_by_qualification: "care_assistant", taken_awaits_rn: true };
    // Taken at 19:55 inside the watched period, the step due after it ends: app only although watched_now is true.
    expect(takenText({ ...ca, watched_now: true, operations_outside_app: false }))
      .toBe("übernommen von Assistenz Test (Pflegehilfe), Operations nur in der App: ausserhalb der besetzten Zeit");
    // The Operations delivery was already sent outside the app: the message follows, also when read after the period.
    expect(takenText({ ...ca, watched_now: false, operations_outside_app: true }))
      .toBe("übernommen von Assistenz Test (Pflegehilfe), Meldung an Operations folgt");
    expect(takenText({ ...ca, taken_by_me: true, watched_now: true, operations_outside_app: false })).toContain(OPERATIONS_APP_ONLY);
    // A null flag never promises the message, whatever watched_now says.
    expect(takenText({ ...ca, watched_now: true, operations_outside_app: null })).toContain(OPERATIONS_APP_ONLY);
    expect(operationsFollows({ watched_now: true, operations_outside_app: null })).toBe(false);
    expect(operationsFollows({ watched_now: true })).toBe(true);
    expect(operationsFollows({})).toBe(false);
    // A take that stops the step shows no Operations text.
    expect(takenText({ ...ca, taken_by_qualification: "registered_nurse", taken_awaits_rn: false, operations_outside_app: true }))
      .toBe("übernommen von Assistenz Test");
  });

  // SIG2-C1 (2): the list of planned visits outside the watched hours (date, times, team; no client data).
  it("formats a planned visit outside the watched hours with weekday, date, times and team (SIG2-C1 (2))", () => {
    expect(outsideWatchedLine({ visit_date: "2026-10-26", time_start: "21:00:00", time_end: "21:30:00", team_name: "Testteam Nord" }))
      .toBe("Mo 26.10. 21:00–21:30 · Testteam Nord");
    expect(outsideWatchedLine({ visit_date: "2026-11-01", time_start: "06:50:00", time_end: null, team_name: "Testteam Nord" }))
      .toBe("So 01.11. 06:50 · Testteam Nord");
    expect(outsideWatchedLine({ visit_date: "2026-11-03", time_start: null, time_end: null, team_name: "Testteam Nord" }))
      .toBe("Di 03.11. ohne Zeit · Testteam Nord");
    expect(OUTSIDE_WATCHED_EMPTY).toContain("nächsten 7 Tagen");
    expect(OUTSIDE_WATCHED_NOTE).toContain("SIG1-8");
  });

  it("says why Operations received it", () => {
    expect(reasonText("team")).toBeNull();
    expect(reasonText("responsible")).toBeNull();
    expect(reasonText("operations_fallback")).toContain("niemand im Team im Dienst");
    expect(reasonText("untaken")).toContain("nicht rechtzeitig übernommen");
    // SIG2-5: Operations at once because nobody was reachable outside the app
    expect(reasonText("untaken", true)).toBe("an Operations: kein Empfänger ausserhalb der App");
    expect(reasonText("team", true)).toBeNull();
  });

  it("reads the command outcome", () => {
    expect(takeOutcome({ result: "ok" })).toEqual({ result: "ok", reason: undefined });
    expect(takeOutcome({ result: "rejected", reason: "not_recipient" })).toEqual({ result: "rejected", reason: "not_recipient" });
    expect(takeOutcome(null)).toEqual({ result: "failed" });
  });
});

describe("SIG2-11: evaluator health (0064)", () => {
  it("warns only for organisations whose scheduled evaluator is not running", async () => {
    const { evaluatorDown, evaluatorDownText, EVALUATOR_DOWN } = await import("@/features/signals/rules");
    const rows = [
      { organization_id: "a", last_run_at: "2026-10-24T19:00:00Z", running: false },
      { organization_id: "b", last_run_at: "2026-10-24T19:20:00Z", running: true },
      { organization_id: "c", last_run_at: null, running: false },
    ];
    expect(evaluatorDown(rows).map((r) => r.organization_id)).toEqual(["a", "c"]);
    expect(evaluatorDownText(rows[0])).toBe(`${EVALUATOR_DOWN}: letzter geplanter Lauf 24.10.26, 21:00.`);
    expect(evaluatorDownText(rows[2])).toBe(`${EVALUATOR_DOWN}: kein geplanter Lauf erfasst.`);
    expect(EVALUATOR_DOWN).toBe("Signalprüfung läuft nicht");
  });
});
