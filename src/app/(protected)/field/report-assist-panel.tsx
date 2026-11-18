"use client";

import { useState } from "react";
import {
  composeSummary,
  decideLine,
  decideSegment,
  openCount,
  type ReportAssist,
} from "@/features/field/report-assist";
import { proposeReportDraft } from "@/features/field/report-draft-command";

/**
 * BK-e2a part 2 (ADR-207): «Entwurf aus Notizen» on the carer's open report.
 * She types her own words; the draft proposes lines with their source and lists every sentence it did not use
 * («Nicht übernommen»). Each line and each sentence is decided on its own; there is no accept-all.
 * The decided text goes into the summary field; signing waits while anything is still open (CGR-213 (b), `uxa` variant).
 */
export default function ReportAssistPanel({
  visitId,
  day,
  summary,
  onSummary,
  onOpenCount,
}: {
  visitId: string;
  day: string;
  summary: string;
  onSummary: (text: string) => void;
  onOpenCount: (n: number) => void;
}) {
  const [notes, setNotes] = useState("");
  const [assist, setAssist] = useState<ReportAssist | null>(null);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function update(next: ReportAssist | null) {
    setAssist(next);
    onOpenCount(next ? openCount(next) : 0);
  }

  async function propose() {
    setPending(true);
    setError(null);
    const result = await proposeReportDraft({ visitId, day, text: notes });
    setPending(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    update(result.assist);
  }

  function apply() {
    if (!assist || openCount(assist) > 0) return;
    onSummary(composeSummary(summary, assist));
    update(null);
    setNotes("");
  }

  const open = assist ? openCount(assist) : 0;
  const openUnplaced = assist ? assist.unplaced.filter((u) => u.decision === "open").length : 0;

  return (
    <details className="grid gap-2 rounded-lg border border-stone-300 bg-white p-2" data-testid="report-assist">
      <summary className="min-h-11 cursor-pointer content-center font-semibold">Entwurf aus Notizen</summary>

      {!assist && (
        <div className="grid gap-2">
          <label className="grid gap-1">
            <span className="text-xs font-semibold">Deine Notizen (eigene Worte, auch per Tastatur-Diktat)</span>
            <textarea
              data-testid="report-assist-notes"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              maxLength={8000}
              rows={4}
              className="rounded-lg border border-stone-300 bg-white p-2"
            />
          </label>
          <button
            type="button"
            data-testid="report-assist-propose"
            disabled={pending || notes.trim().length === 0}
            onClick={propose}
            className="min-h-11 rounded-lg border border-emerald-800 font-semibold text-emerald-900 disabled:opacity-60"
          >
            {pending ? "Wird erstellt …" : "Entwurf vorschlagen"}
          </button>
        </div>
      )}

      {error && (
        <p role="alert" data-testid="report-assist-error" className="rounded-lg border border-rose-300 bg-rose-50 p-2 text-xs font-semibold text-rose-800">
          {error}
        </p>
      )}

      {assist && (
        <div className="grid gap-2">
          <p data-testid="report-assist-origin" className="text-xs text-secondary">
            Herkunft: {assist.label}. Nur ein Vorschlag: du entscheidest jede Zeile.
          </p>

          {assist.lines.length > 0 && (
            <ul className="grid gap-2" aria-label="Vorgeschlagene Zeilen">
              {assist.lines.map((line, i) => (
                <li key={i} data-testid="report-assist-line" data-decision={line.decision} className="grid gap-1 rounded-lg border border-stone-200 p-2">
                  <p className="whitespace-pre-wrap">{line.text}</p>
                  <p className="text-xs text-secondary" data-testid="report-assist-source">
                    Quelle: {line.sources.map((id) => (assist.sourceText[id] ? `«${assist.sourceText[id]}»` : "erfasste Daten")).join(", ")}
                  </p>
                  {line.decision === "open" ? (
                    <div className="grid grid-cols-2 gap-2">
                      <button type="button" onClick={() => update(decideLine(assist, i, "taken"))} className="min-h-11 rounded-lg bg-emerald-800 font-semibold text-white">
                        Übernehmen
                      </button>
                      <button type="button" onClick={() => update(decideLine(assist, i, "dropped"))} className="min-h-11 rounded-lg border border-stone-300 font-semibold">
                        Verwerfen
                      </button>
                    </div>
                  ) : (
                    <button type="button" onClick={() => update(decideLine(assist, i, "open"))} className="min-h-11 text-left text-xs font-semibold underline underline-offset-4">
                      {line.decision === "taken" ? "Übernommen" : "Verworfen"} · ändern
                    </button>
                  )}
                </li>
              ))}
            </ul>
          )}

          {assist.unplaced.length > 0 && (
            <section aria-label="Nicht übernommen" data-testid="report-assist-unplaced" className="grid gap-2 rounded-lg border border-amber-400 bg-amber-50 p-2">
              <h4 className="text-xs font-bold">Nicht übernommen ({openUnplaced})</h4>
              <ul className="grid gap-2">
                {assist.unplaced.map((u) => (
                  <li key={u.id} data-testid="report-assist-segment" data-decision={u.decision} className="grid gap-1">
                    <p className="whitespace-pre-wrap">{u.text}</p>
                    {u.decision === "open" ? (
                      <div className="grid grid-cols-2 gap-2">
                        <button type="button" onClick={() => update(decideSegment(assist, u.id, "inserted"))} className="min-h-11 rounded-lg bg-emerald-800 font-semibold text-white">
                          Einfügen
                        </button>
                        <button type="button" onClick={() => update(decideSegment(assist, u.id, "omitted"))} className="min-h-11 rounded-lg border border-stone-300 bg-white font-semibold">
                          Bewusst weglassen
                        </button>
                      </div>
                    ) : (
                      <button type="button" onClick={() => update(decideSegment(assist, u.id, "open"))} className="min-h-11 text-left text-xs font-semibold underline underline-offset-4">
                        {u.decision === "inserted" ? "Eingefügt" : "Bewusst weggelassen"} · ändern
                      </button>
                    )}
                  </li>
                ))}
              </ul>
            </section>
          )}

          <button
            type="button"
            data-testid="report-assist-apply"
            disabled={open > 0}
            onClick={apply}
            className="min-h-11 rounded-lg bg-emerald-800 font-bold text-white disabled:opacity-60"
          >
            {open > 0 ? `Noch ${open} offen` : "In die Zusammenfassung übernehmen"}
          </button>
          <button type="button" onClick={() => update(null)} className="min-h-11 rounded-lg border border-stone-300 font-semibold">
            Entwurf verwerfen
          </button>
        </div>
      )}
    </details>
  );
}
