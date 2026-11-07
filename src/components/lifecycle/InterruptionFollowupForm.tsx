"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { recordInterruptionFollowup } from "@/features/lifecycle/commands";
import { FOLLOWUP_DECISIONS, FOLLOWUP_NOTICE, REASON_LABEL, reasonError } from "@/features/lifecycle/rules";

/**
 * CSR1 / CGR-25: the one decision that ends the signal of a visit ended as not completed. Used on /field, /team and
 * /operations (team members and coordination roles; the database checks who may). PROVISIONAL until D-31.
 */
export default function InterruptionFollowupForm({ visitId, label = "Entscheid erfassen" }: { visitId: string; label?: string }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit(form: FormData) {
    const decision = String(form.get("decision") ?? "");
    const note = String(form.get("note") ?? "");
    const problem = reasonError(decision, note, FOLLOWUP_DECISIONS);
    if (problem) return setError(problem);
    setPending(true);
    setError(null);
    const result = await recordInterruptionFollowup({ visitId, decision, note, idempotencyKey: crypto.randomUUID() });
    setPending(false);
    if (!result.ok) return setError(result.error ?? "Konnte nicht gespeichert werden.");
    setOpen(false);
    router.refresh();
  }

  if (!open) {
    return (
      <button type="button" onClick={() => setOpen(true)} className="min-h-11 rounded-lg bg-amber-800 px-3 font-bold text-white">
        {label}
      </button>
    );
  }
  return (
    <form action={submit} aria-label="Entscheid zur noch fälligen Pflege" className="grid gap-2 text-sm">
      <p className="text-xs text-amber-900">{FOLLOWUP_NOTICE}</p>
      <label className="grid gap-1">
        <span className="text-xs font-semibold">Wie geht es mit der noch fälligen Pflege weiter?</span>
        <select name="decision" required defaultValue="" className="min-h-11 rounded-lg border border-stone-300 bg-white px-2">
          <option value="" disabled>– bitte wählen –</option>
          {FOLLOWUP_DECISIONS.map((d) => <option key={d} value={d}>{REASON_LABEL[d] ?? d}</option>)}
        </select>
      </label>
      <label className="grid gap-1">
        <span className="text-xs font-semibold">Notiz (bei «Anderer Grund» nötig)</span>
        <textarea name="note" maxLength={1000} rows={2} className="rounded-lg border border-stone-300 bg-white p-2" />
      </label>
      {error && (
        <p role="alert" data-testid="command-error" className="rounded-lg border border-rose-300 bg-rose-50 p-2 font-semibold text-rose-800">{error}</p>
      )}
      <div className="grid grid-cols-2 gap-2">
        <button type="submit" disabled={pending} className="min-h-11 rounded-lg bg-emerald-800 font-bold text-white disabled:opacity-60">
          {pending ? "Wird gespeichert …" : "Entscheid speichern"}
        </button>
        <button type="button" onClick={() => { setOpen(false); setError(null); }} className="min-h-11 rounded-lg border border-stone-300 font-semibold">
          Abbrechen
        </button>
      </div>
    </form>
  );
}
