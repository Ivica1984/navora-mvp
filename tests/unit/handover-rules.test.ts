import { describe, expect, it } from "vitest";
import { authorLabel, emptyText, entryLines, groupSinceLast, ruleText, sourceText, type SinceLastRow } from "@/features/handover/rules";

// HAND1: labels only; the database selects, scopes and orders the entries (migration 0033, pgTAP 033).
describe("handover rules (HAND1)", () => {
  const row = (over: Partial<SinceLastRow>): SinceLastRow => ({
    visit_id: "v1", rule: "since_own_visit", since_date: "2026-10-17", lookback: 3, kind: null, entry_id: null, at: null,
    source_visit_date: null, source_visit_start: null, author: null, detail: null, ...over,
  });

  it("groups rows per visit, keeps the database order and an empty block for a card without entries", () => {
    const grouped = groupSinceLast([
      row({ kind: "observation", entry_id: "a", at: "2026-10-18T07:00:00Z", author: "member:2", detail: { content: "x" } }),
      row({ kind: "case_pause", entry_id: "b", at: "2026-10-19T07:00:00Z", author: "me", detail: {} }),
      row({ visit_id: "v2", rule: "no_visits", since_date: null }),
    ]);
    expect(grouped.get("v1")?.entries.map((e) => e.id)).toEqual(["a", "b"]);
    expect(grouped.get("v2")).toEqual({ rule: "no_visits", sinceDate: null, lookback: 3, entries: [] });
  });

  it("says which rule applied and what an empty section means", () => {
    expect(ruleText("since_own_visit", "2026-10-17", 3)).toBe("Seit deinem letzten Einsatz am 17.10.2026");
    expect(ruleText("last_visits", "2026-10-10", 3)).toContain("die letzten 3 abgeschlossenen Einsätze (ab 10.10.2026)");
    expect(ruleText("no_visits", null, 3)).toContain("noch keinen abgeschlossenen Einsatz");
    expect(emptyText("since_own_visit", "2026-10-17")).toBe("Nichts Neues seit deinem letzten Einsatz am 17.10.2026.");
  });

  it("labels authors as members until ADM1 names exist; no ids", () => {
    expect(authorLabel("me")).toBe("Ich");
    expect(authorLabel("member:3")).toBe("Teammitglied 3");
    expect(authorLabel("system")).toBe("Automatisch");
    expect(authorLabel("outside")).toBe("Person ausserhalb des Teams");
  });

  it("shows free text exactly as recorded", () => {
    const text = "Klientin müde, trinkt wenig.\nBitte Trinkmenge beobachten.";
    expect(entryLines("observation", { content: text, for_handover: true, edited: false })).toEqual([text, "für die Übergabe markiert"]);
    expect(entryLines("care_plan_retired", { service: "Kompressionsstrümpfe", category: "B", reason: "Synthetisch: ärztlich beendet" }))
      .toEqual(["Kompressionsstrümpfe · Kategorie B", "Begründung: Synthetisch: ärztlich beendet"]);
    expect(entryLines("quality_event", { title: "Synthetisch: Sturz", severity: "medium", status: "open" }))
      .toEqual(["Synthetisch: Sturz", "Schwere: mittel · Status jetzt: offen"]);
  });

  it("turns recorded codes into labels, old → new", () => {
    expect(entryLines("primary_nurse", { primary_old: "me", primary_new: "member:2", reason: "Ferien" }))
      .toEqual(["Bezugspflege: Ich → Teammitglied 2", "Begründung: Ferien"]);
    expect(entryLines("medical_order", { status: { old: "requested", new: "present" } })).toEqual(["Status: angefragt → liegt vor"]);
    expect(entryLines("case_pause", { reason_code: "hospital_stay", note: null, expected_end: "2026-10-30" }))
      .toEqual(["Spitalaufenthalt", "voraussichtlich bis 30.10.2026"]);
    expect(entryLines("visit_moved", { before: { date: "2026-10-20", start: "08:00:00" }, after: { date: "2026-10-21", start: "09:00:00" }, reason: "Arzttermin" }))
      .toEqual(["20.10.2026 08:00 → 21.10.2026 09:00", "Begründung: Arzttermin"]);
    expect(entryLines("care_plan_schedule", { service: "Grundpflege", changed: { freq_period: { old: null, new: "day" } } }))
      .toEqual(["Grundpflege", "Rhythmus: – → täglich"]);
    expect(entryLines("visit_interrupted", { reason_code: "client_transferred", note: "Ins Spital gebracht" }))
      .toEqual(["Klient:in verlegt bzw. ins Spital gebracht", "Ins Spital gebracht"]);
    expect(entryLines("care_plan_schedule", { service: "Grundpflege", changed: {} }))
      .toEqual(["Grundpflege", "Werte vor der Protokollierung nicht erfasst"]);
  });

  it("names the visit an entry comes from", () => {
    expect(sourceText("2026-10-18", "08:00:00")).toBe("Einsatz vom 18.10.2026 08:00");
    expect(sourceText(null, null)).toBeNull();
  });
});
