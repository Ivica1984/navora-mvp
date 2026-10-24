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

  it("says why Operations received it", () => {
    expect(reasonText("team")).toBeNull();
    expect(reasonText("responsible")).toBeNull();
    expect(reasonText("operations_fallback")).toContain("niemand im Team im Dienst");
    expect(reasonText("untaken")).toContain("nicht rechtzeitig übernommen");
  });

  it("reads the command outcome", () => {
    expect(takeOutcome({ result: "ok" })).toEqual({ result: "ok", reason: undefined });
    expect(takeOutcome({ result: "rejected", reason: "not_recipient" })).toEqual({ result: "rejected", reason: "not_recipient" });
    expect(takeOutcome(null)).toEqual({ result: "failed" });
  });
});
