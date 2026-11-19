import { describe, expect, it } from "vitest";

import {
  assistAllowed,
  assistFromDraft,
  composeSummary,
  decideLine,
  decideSegment,
  factsFromSnapshot,
  openCount,
  signGate,
  signWaitText,
  withLedgerGuard,
} from "@/features/field/report-assist";
import * as assistModule from "@/features/field/report-assist";
import { checkDraft } from "@/lib/ai/report-draft/control";
import { ruleProvider } from "@/lib/ai/report-draft/rule-provider";
import { segmentInput } from "@/lib/ai/report-draft/segment";
import type { Provider } from "@/lib/ai/report-draft/contract";

/**
 * BK-e2a part 2 (ADR-207): the carer's decisions on a report draft in /field.
 * `uxa` variant named by `cra` (CGR-213 (b), BK brief PO 03:26): nothing typed is dropped without a decision,
 * every line is decided one by one (no accept-all), and signing waits while anything is still open.
 * Synthetic text only.
 */

function draft(text: string, out?: { lines: { text: string; sources: string[] }[]; unplaced?: string[] }) {
  const segments = segmentInput(text);
  const input = { segments, facts: [{ id: "f1", text: "Einsatz 07:02–07:48" }] };
  const checked = checkDraft(input, { lines: out?.lines ?? [], unplaced: out?.unplaced ?? [] });
  return assistFromDraft({ ok: true, origin: "rule", label: ruleProvider.label, segments, ...checked });
}

describe("report assist: decisions", () => {
  it("starts with every line and every unplaced segment open", () => {
    const a = draft("Klientin wach. Trinkt wenig.", { lines: [{ text: "Klientin wach.", sources: ["s1"] }] });
    expect(a.lines).toHaveLength(1);
    expect(a.unplaced.map((u) => u.id)).toEqual(["s2"]);
    expect(a.unplaced[0].text).toBe("Trinkt wenig.");
    expect(openCount(a)).toBe(2);
  });

  it("decides one line at a time; there is no accept-all", () => {
    const a = draft("Eins. Zwei.", { lines: [{ text: "Eins.", sources: ["s1"] }, { text: "Zwei.", sources: ["s2"] }] });
    const b = decideLine(a, 0, "taken");
    expect(b.lines.map((l) => l.decision)).toEqual(["taken", "open"]);
    expect(openCount(b)).toBe(1);
    // the module offers no bulk decision
    expect(Object.keys(assistModule).filter((k) => /(accept|take|decide|apply)all/i.test(k))).toEqual([]);
  });

  it("an unplaced segment is inserted or deliberately left out, never dropped silently", () => {
    const a = draft("Sturzgefahr beim Aufstehen. Wetter schön.");
    expect(a.unplaced).toHaveLength(2);
    const b = decideSegment(decideSegment(a, "s1", "inserted"), "s2", "omitted");
    expect(openCount(b)).toBe(0);
    expect(composeSummary("", b)).toBe("Sturzgefahr beim Aufstehen.");
  });

  it("shared test: 40 segments end up 40 placed or listed, none lost", () => {
    const text = Array.from({ length: 40 }, (_, i) => `Satz ${i + 1}.`).join(" ");
    const lines = Array.from({ length: 25 }, (_, i) => ({ text: `Satz ${i + 1}.`, sources: [`s${i + 1}`] }));
    const a = draft(text, { lines });
    const cited = new Set(a.lines.flatMap((l) => l.sources));
    const listed = new Set(a.unplaced.map((u) => u.id));
    for (let i = 1; i <= 40; i++) expect(cited.has(`s${i}`) || listed.has(`s${i}`)).toBe(true);
    expect(a.unplaced).toHaveLength(15);
  });

  it("composes only taken lines and inserted segments, appended to the existing summary", () => {
    const a = draft("A. B. C.", { lines: [{ text: "A.", sources: ["s1"] }, { text: "B.", sources: ["s2"] }] });
    let b = decideLine(a, 0, "taken");
    b = decideLine(b, 1, "dropped");
    b = decideSegment(b, "s3", "inserted");
    expect(composeSummary("Vorher.", b)).toBe("Vorher.\nA.\nC.");
    expect(composeSummary("", b)).toBe("A.\nC.");
  });

  it("a decision can be changed while the draft is open", () => {
    const a = draft("A.", { lines: [{ text: "A.", sources: ["s1"] }] });
    const b = decideLine(decideLine(a, 0, "taken"), 0, "open");
    expect(openCount(b)).toBe(1);
  });

  it("an index or id that does not exist changes nothing", () => {
    const a = draft("A.");
    expect(decideLine(a, 5, "taken")).toEqual(a);
    expect(decideSegment(a, "s9", "inserted")).toEqual(a);
  });

  it("keeps the origin label of the provider (a rule substitute is never called AI)", () => {
    const a = draft("A.");
    expect(a.origin).toBe("rule");
    expect(a.label).toBe("regelbasiert, keine KI · synthetische Daten");
    expect(a.label).not.toMatch(/\bKI-Entwurf\b/);
  });
});

describe("report assist: facts from the stored report snapshot", () => {
  it("sends times and services only, never names, observations or the address", () => {
    const facts = factsFromSnapshot({
      planned: { start: "07:00", end: "07:45" },
      services: ["Grundpflege", "Medikamente richten"],
      events: [
        { type: "started", at: "2026-11-19T06:02:00Z" },
        { type: "completed", at: "2026-11-19T06:48:00Z" },
      ],
      observations: [{ content: "Synthetische Beobachtung", recorded_at: "2026-11-19T06:30:00Z" }],
      client_name: "Synthetische Person",
    });
    expect(facts).toEqual([
      { id: "f1", text: "Einsatz 07:02–07:48" },
      { id: "f2", text: "Leistungen: Grundpflege, Medikamente richten" },
    ]);
    expect(JSON.stringify(facts)).not.toMatch(/Synthetische/);
  });

  it("an empty or unknown snapshot gives no facts", () => {
    expect(factsFromSnapshot(null)).toEqual([]);
    expect(factsFromSnapshot({ services: [] })).toEqual([]);
  });
});

describe("report assist: no model call without the AI ledger (AUT-138, ADR-207 (3))", () => {
  const model: Provider = { kind: "model", label: "KI-Vorschlag", propose: async () => ({ lines: [], unplaced: [] }) };

  it("falls back to the rule substitute, with the reason, while the ledger is not built", () => {
    const r = withLedgerGuard({ provider: model }, false);
    expect(r.provider).toBe(ruleProvider);
    expect(r.modelBlocked).toBe("ledger_missing");
  });

  it("keeps the model once the ledger exists", () => {
    expect(withLedgerGuard({ provider: model }, true).provider).toBe(model);
  });

  it("leaves the rule substitute and «off» unchanged", () => {
    expect(withLedgerGuard({ provider: ruleProvider }, false)).toEqual({ provider: ruleProvider });
    expect(withLedgerGuard({ provider: null }, false)).toEqual({ provider: null });
  });
});

describe("report assist: who may ask for a draft", () => {
  const base = { status: "draft", i_am_performer: true, performer_access_ended: false };
  it("only the performer on an open draft", () => {
    expect(assistAllowed(base)).toBe(true);
    expect(assistAllowed(null)).toBe(false);
    expect(assistAllowed({ ...base, i_am_performer: false })).toBe(false);
    expect(assistAllowed({ ...base, status: "signed" })).toBe(false);
    expect(assistAllowed({ ...base, performer_access_ended: true })).toBe(false);
  });
});

describe("report assist: signing waits until the decided draft is placed (UXR-251)", () => {
  it("is clear when no draft is shown", () => {
    expect(signGate(null)).toEqual({ kind: "clear" });
    expect(signWaitText(signGate(null))).toBeNull();
  });

  it("waits while lines or sentences are still open, naming the number", () => {
    const a = draft("Klientin wach. Trinkt wenig.", { lines: [{ text: "Klientin wach.", sources: ["s1"] }] });
    expect(signGate(a)).toEqual({ kind: "open", open: 2 });
    expect(signWaitText(signGate(a))).toBe("Noch 2 Punkte im Entwurf offen. Bitte zuerst entscheiden oder den Entwurf verwerfen.");
    const one = decideLine(a, 0, "taken");
    expect(signWaitText(signGate(one))).toBe("Noch 1 Punkt im Entwurf offen. Bitte zuerst entscheiden oder den Entwurf verwerfen.");
  });

  it("still waits once everything is decided but the draft is not yet placed in the summary", () => {
    let a = draft("Klientin wach. Trinkt wenig.", { lines: [{ text: "Klientin wach.", sources: ["s1"] }] });
    a = decideSegment(decideLine(a, 0, "taken"), "s2", "inserted");
    expect(openCount(a)).toBe(0);
    expect(signGate(a)).toEqual({ kind: "unplaced" });
    expect(signWaitText(signGate(a))).toBe(
      "Entwurf noch nicht in die Zusammenfassung übernommen. Bitte übernehmen oder den Entwurf verwerfen.",
    );
  });

  it("also waits when every line was dropped and every sentence left out (the draft still needs an explicit end)", () => {
    let a = draft("Klientin wach. Trinkt wenig.", { lines: [{ text: "Klientin wach.", sources: ["s1"] }] });
    a = decideSegment(decideLine(a, 0, "dropped"), "s2", "omitted");
    expect(signGate(a)).toEqual({ kind: "unplaced" });
  });
});
