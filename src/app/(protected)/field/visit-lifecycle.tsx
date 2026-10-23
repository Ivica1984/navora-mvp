"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { cancelVisit, endVisitNotCompleted, recordNoShow, recordNoShowOutcome } from "@/features/lifecycle/commands";
import {
  CANCEL_REASONS, INTERRUPT_NOTICE, INTERRUPT_REASONS, NO_SHOW_NOTICE, NO_SHOW_OUTCOMES, REASON_LABEL, canEndNotCompleted, followupOf, reasonError,
} from "@/features/lifecycle/rules";
import type { VisitStatusNote } from "@/features/lifecycle/queries";
import InterruptionFollowupForm from "@/components/lifecycle/InterruptionFollowupForm";

/**
 * C1 on the /field card: cancel before start, record a no-show after arrival, and its outcome.
 * CSR1 / CGR-20: end a started or paused visit as not completed, with a reason, so "complete" is never the only way out.
 * CSR1 / CGR-25: until someone records the follow-up decision, the card says so and offers it.
 */
export default function VisitLifecycle({ visitId, status, notes }: { visitId: string; status: string | null; notes: VisitStatusNote[] }) {
  const router = useRouter();
  const [mode, setMode] = useState<"idle" | "cancel" | "no_show" | "outcome" | "interrupt">("idle");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const cancelled = notes.find((n) => n.kind === "cancelled");
  const noShow = notes.find((n) => n.kind === "no_show");
  const outcome = notes.find((n) => n.kind === "no_show_outcome");
  const interrupted = notes.find((n) => n.kind === "interrupted");
  const followup = followupOf(notes);

  async function run(call: () => Promise<{ ok: boolean; error?: string }>) {
    setPending(true);
    setError(null);
    const result = await call();
    setPending(false);
    if (!result.ok) {
      setError(result.error ?? "Konnte nicht gespeichert werden.");
      return;
    }
    setMode("idle");
    router.refresh();
  }

  const canCancel = status === "planned" || status === "on_the_way";
  const canNoShow = status === "on_the_way";
  const needsOutcome = status === "no_show" && !outcome;
  const canInterrupt = canEndNotCompleted(status);
  if (!canCancel && !canInterrupt && !cancelled && !noShow && !interrupted) return null;

  return (
    <section aria-label="Absage und Nichtantreffen" data-testid="visit-lifecycle" className="mt-3 grid gap-2 text-sm">
      {cancelled && (
        <p className="rounded-lg bg-stone-100 p-2" data-testid="cancel-reason">
          Abgesagt: {REASON_LABEL[cancelled.reason_code ?? ""] ?? cancelled.reason_code}{cancelled.note ? ` – ${cancelled.note}` : ""}
        </p>
      )}
      {noShow && (
        <div className="rounded-lg border-l-4 border-rose-600 bg-rose-50 p-2" data-testid="no-show">
          <p className="font-bold text-rose-900">Klient:in nicht angetroffen</p>
          <p>{noShow.note}</p>
          {outcome ? (
            <p data-testid="no-show-outcome">Ergebnis: {REASON_LABEL[outcome.reason_code ?? ""] ?? outcome.reason_code} – {outcome.note}</p>
          ) : (
            <p className="text-xs text-rose-900">Offen bei Operations (P1), bis das Ergebnis erfasst ist. {NO_SHOW_NOTICE}</p>
          )}
        </div>
      )}
      {interrupted && (
        <p className="rounded-lg border-l-4 border-amber-600 bg-amber-50 p-2" data-testid="interrupt-reason">
          <span className="font-bold">Nicht abgeschlossen · {REASON_LABEL[interrupted.reason_code ?? ""] ?? interrupted.reason_code}</span>
          {interrupted.note ? ` – ${interrupted.note}` : ""}
        </p>
      )}
      {interrupted && status === "interrupted" && (followup ? (
        <p className="rounded-lg bg-stone-100 p-2" data-testid="interrupt-followup">
          Entscheid: {REASON_LABEL[followup.reason_code ?? ""] ?? followup.reason_code}{followup.note ? ` – ${followup.note}` : ""}
        </p>
      ) : (
        <div className="grid gap-2 rounded-lg border border-amber-300 bg-white p-2" data-testid="interrupt-followup-open">
          <p className="text-xs font-semibold text-amber-900">
            Entscheid offen: Wie geht es mit der noch fälligen Pflege weiter? Bis dahin bleibt der Einsatz im Team und bei Operations sichtbar.
          </p>
          <InterruptionFollowupForm visitId={visitId} />
        </div>
      ))}
      {error && (
        <p role="alert" data-testid="command-error" className="rounded-lg border border-rose-300 bg-rose-50 p-2 font-semibold text-rose-800">{error}</p>
      )}
      {mode === "idle" && (canCancel || needsOutcome || canInterrupt) && (
        <div className="flex flex-wrap gap-2">
          {canCancel && (
            <button type="button" onClick={() => setMode("cancel")} className="min-h-11 rounded-lg border border-stone-400 bg-white px-3 font-semibold">
              Einsatz absagen
            </button>
          )}
          {canNoShow && (
            <button type="button" onClick={() => setMode("no_show")} className="min-h-11 rounded-lg border border-rose-500 bg-white px-3 font-semibold text-rose-900">
              Nicht angetroffen
            </button>
          )}
          {canInterrupt && (
            <button type="button" onClick={() => setMode("interrupt")} className="min-h-11 rounded-lg border border-amber-600 bg-white px-3 font-semibold text-amber-900">
              Nicht abgeschlossen beenden
            </button>
          )}
          {needsOutcome && (
            <button type="button" onClick={() => setMode("outcome")} className="min-h-11 rounded-lg bg-rose-800 px-3 font-bold text-white">
              Ergebnis erfassen
            </button>
          )}
        </div>
      )}
      {mode === "cancel" && (
        <ReasonForm
          title="Grund der Absage" reasons={CANCEL_REASONS} pending={pending} submitLabel="Absage speichern" onCancel={() => setMode("idle")}
          onSubmit={(code, note) => {
            const problem = reasonError(code, note, CANCEL_REASONS);
            if (problem) return setError(problem);
            run(() => cancelVisit({ visitId, reasonCode: code, note, idempotencyKey: crypto.randomUUID() }));
          }}
        />
      )}
      {mode === "interrupt" && (
        <div role="form" aria-label="Einsatz nicht abgeschlossen beenden" className="grid gap-2">
          <p className="text-xs text-amber-900">{INTERRUPT_NOTICE}</p>
          <ReasonForm
            title="Warum endet der Einsatz?" reasons={INTERRUPT_REASONS} pending={pending} submitLabel="Nicht abgeschlossen speichern"
            onCancel={() => setMode("idle")}
            onSubmit={(code, note) => {
              const problem = reasonError(code, note, INTERRUPT_REASONS);
              if (problem) return setError(problem);
              run(() => endVisitNotCompleted({ visitId, reasonCode: code, note, idempotencyKey: crypto.randomUUID() }));
            }}
          />
        </div>
      )}
      {mode === "no_show" && (
        <form action={(f) => run(() => recordNoShow({ visitId, note: String(f.get("note") ?? ""), idempotencyKey: crypto.randomUUID() }))} className="grid gap-2">
          <label className="grid gap-1">
            <span className="text-xs font-semibold">Was ist passiert? (nötig)</span>
            <textarea name="note" required minLength={3} maxLength={1000} rows={2} className="rounded-lg border border-stone-300 bg-white p-2" />
          </label>
          <p className="text-xs text-rose-900">{NO_SHOW_NOTICE}</p>
          <Buttons pending={pending} label="Nichtantreffen melden" onCancel={() => setMode("idle")} />
        </form>
      )}
      {mode === "outcome" && (
        <ReasonForm
          title="Ergebnis" reasons={NO_SHOW_OUTCOMES} pending={pending} submitLabel="Ergebnis speichern" noteRequired onCancel={() => setMode("idle")}
          onSubmit={(code, note) => {
            if (note.trim().length < 3) return setError("Bitte das Ergebnis kurz beschreiben (mind. 3 Zeichen).");
            run(() => recordNoShowOutcome({ visitId, outcome: code, note, idempotencyKey: crypto.randomUUID() }));
          }}
        />
      )}
    </section>
  );
}

function ReasonForm({ title, reasons, pending, submitLabel, onSubmit, onCancel, noteRequired = false }: {
  title: string; reasons: readonly string[]; pending: boolean; submitLabel: string; noteRequired?: boolean;
  onSubmit: (code: string, note: string) => void; onCancel: () => void;
}) {
  return (
    <form action={(f) => onSubmit(String(f.get("code") ?? ""), String(f.get("note") ?? ""))} className="grid gap-2">
      <label className="grid gap-1">
        <span className="text-xs font-semibold">{title}</span>
        <select name="code" required defaultValue="" className="min-h-11 rounded-lg border border-stone-300 bg-white px-2">
          <option value="" disabled>– bitte wählen –</option>
          {reasons.map((r) => <option key={r} value={r}>{REASON_LABEL[r] ?? r}</option>)}
        </select>
      </label>
      <label className="grid gap-1">
        <span className="text-xs font-semibold">Notiz {noteRequired ? "(nötig)" : "(bei «Anderer Grund» nötig)"}</span>
        <textarea name="note" maxLength={1000} rows={2} className="rounded-lg border border-stone-300 bg-white p-2" />
      </label>
      <Buttons pending={pending} label={submitLabel} onCancel={onCancel} />
    </form>
  );
}

function Buttons({ pending, label, onCancel }: { pending: boolean; label: string; onCancel: () => void }) {
  return (
    <div className="grid grid-cols-2 gap-2">
      <button type="submit" disabled={pending} className="min-h-11 rounded-lg bg-emerald-800 font-bold text-white disabled:opacity-60">
        {pending ? "Wird gespeichert …" : label}
      </button>
      <button type="button" onClick={onCancel} className="min-h-11 rounded-lg border border-stone-300 font-semibold">Abbrechen</button>
    </div>
  );
}
