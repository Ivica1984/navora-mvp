"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { handleException } from "@/features/operations/commands";
import { CLOSES_WITH_CAUSE, PRIORITY_LABEL, canClose, countByPriority, formatAge, handlerLabel, parseComments } from "@/features/operations/exceptions";
import type { OperationsException } from "@/features/operations/types";

const PRIORITY_CLASS: Record<string, string> = {
  P1: "border-rose-600 bg-rose-50",
  P2: "border-amber-500 bg-amber-50",
  P3: "border-stone-400 bg-stone-50",
};

/**
 * OPS1: one list of open exceptions, derived from state and sorted by urgency.
 * Operations takes over, comments and closes (with a reason); it never assigns or edits cases here.
 * Safety exceptions (P1 or escalating to P1) have no close: they end when their cause is resolved (CSR1 / CGR-06).
 */
export default function ExceptionCenter({ exceptions }: { exceptions: OperationsException[] }) {
  const counts = countByPriority(exceptions);
  return (
    <section aria-label="Ausnahmen" className="grid gap-3 rounded-xl border border-stone-200 bg-white p-4 shadow-sm">
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <div>
          <h2 className="text-xl font-bold">Ausnahmen</h2>
          <p className="text-sm text-stone-500">Aus dem aktuellen Stand abgeleitet. Teams entscheiden selbst; Operations greift nur bei Ausnahmen ein.</p>
        </div>
        <p className="text-sm font-semibold" data-testid="exception-counts">
          P1 {counts.P1} · P2 {counts.P2} · P3 {counts.P3}
        </p>
      </div>
      {exceptions.length === 0 ? (
        <p className="rounded-lg border border-dashed border-stone-300 p-4 text-center text-stone-500">Keine offenen Ausnahmen.</p>
      ) : (
        <ol className="grid gap-2" aria-label="Offene Ausnahmen">
          {exceptions.map((e) => (
            <li key={e.exception_key}>
              <ExceptionCard exception={e} />
            </li>
          ))}
        </ol>
      )}
    </section>
  );
}

function ExceptionCard({ exception: e }: { exception: OperationsException }) {
  const router = useRouter();
  const [mode, setMode] = useState<"idle" | "comment" | "close">("idle");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const comments = parseComments(e.comments);

  async function send(kind: "take" | "comment" | "close", text: string) {
    setPending(true);
    setError(null);
    const result = await handleException({ key: e.exception_key, kind, text, idempotencyKey: crypto.randomUUID() });
    setPending(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setMode("idle");
    router.refresh();
  }

  return (
    <article
      aria-label={`Ausnahme ${e.label}`}
      data-testid="exception"
      className={`grid gap-1 rounded-lg border-l-8 p-3 text-sm ${PRIORITY_CLASS[e.priority] ?? PRIORITY_CLASS.P3}`}
    >
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <p className="font-bold">
          <span className="mr-2 rounded bg-white px-1.5 py-0.5 text-xs">{e.priority} · {PRIORITY_LABEL[e.priority] ?? ""}</span>
          {e.label}
        </p>
        <p className="text-xs text-stone-600">{formatAge(e.since)}</p>
      </div>
      <p>
        {[e.case_label, e.region, e.team_name].filter(Boolean).join(" · ") || "ohne Fallbezug"}
        {e.detail ? ` — ${e.detail}` : ""}
      </p>
      <p className="text-xs text-stone-600">Nächster Schritt: {e.next_step}</p>
      <p className="text-xs font-semibold" data-testid="exception-handler">{handlerLabel(e)}</p>
      {!canClose(e) && (
        <p className="text-xs text-stone-700" data-testid="exception-closes-with-cause">{CLOSES_WITH_CAUSE}</p>
      )}
      {comments.length > 0 && (
        <ul className="grid gap-0.5 text-xs" aria-label="Notizen">
          {comments.map((c, i) => (
            <li key={i}>
              {c.text} <span className="text-stone-500">({c.mine ? "du" : "Operations"})</span>
            </li>
          ))}
        </ul>
      )}
      {error && (
        <p role="alert" data-testid="command-error" className="rounded border border-rose-300 bg-white p-2 font-semibold text-rose-800">
          {error}
        </p>
      )}
      {mode === "idle" ? (
        <div className="mt-1 flex flex-wrap gap-2">
          {!e.taken && (
            <button type="button" disabled={pending} onClick={() => send("take", "")}
              className="min-h-10 rounded-lg bg-emerald-800 px-3 font-bold text-white disabled:opacity-60">
              Übernehmen
            </button>
          )}
          <button type="button" onClick={() => setMode("comment")} className="min-h-10 rounded-lg border border-stone-400 bg-white px-3 font-semibold">
            Notiz
          </button>
          {canClose(e) && (
            <button type="button" onClick={() => setMode("close")} className="min-h-10 rounded-lg border border-stone-400 bg-white px-3 font-semibold">
              Schliessen
            </button>
          )}
        </div>
      ) : (
        <form
          action={(form) => send(mode, String(form.get("text") ?? ""))}
          className="mt-1 grid gap-2"
        >
          <label className="grid gap-1">
            <span className="text-xs font-semibold">{mode === "close" ? "Begründung (nötig)" : "Notiz"}</span>
            <textarea name="text" required minLength={3} maxLength={1000} rows={2} className="rounded border border-stone-300 bg-white p-2" />
          </label>
          <div className="flex gap-2">
            <button type="submit" disabled={pending} className="min-h-10 rounded-lg bg-emerald-800 px-3 font-bold text-white disabled:opacity-60">
              {pending ? "Wird gespeichert …" : mode === "close" ? "Ausnahme schliessen" : "Notiz speichern"}
            </button>
            <button type="button" onClick={() => setMode("idle")} className="min-h-10 rounded-lg border border-stone-300 bg-white px-3 font-semibold">
              Abbrechen
            </button>
          </div>
        </form>
      )}
    </article>
  );
}
