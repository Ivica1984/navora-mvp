"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { closeCase, pauseCase, reopenCase, resumeCase } from "@/features/lifecycle/commands";
import { CLOSE_REASONS, PAUSE_REASONS, REASON_LABEL, reasonError } from "@/features/lifecycle/rules";
import type { CaseLifecycle } from "@/features/lifecycle/queries";

/** C1 on the /team case card: pause, resume, close (with reasons). Closed cases are listed separately for reopening. */
export default function CaseLifecycleControls({ item }: { item: CaseLifecycle }) {
  const router = useRouter();
  const [mode, setMode] = useState<"idle" | "pause" | "close">("idle");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function run(call: () => Promise<{ ok: boolean; error?: string }>) {
    setPending(true);
    setError(null);
    const result = await call();
    setPending(false);
    if (!result.ok) return setError(result.error ?? "Konnte nicht gespeichert werden.");
    setMode("idle");
    router.refresh();
  }

  const field = "min-h-11 rounded-lg border border-stone-300 bg-white px-2";
  return (
    <section aria-label="Fallstatus" data-testid="case-lifecycle" className="mt-3 grid gap-2 text-sm">
      {item.lifecycle === "paused" && (
        <p className="rounded-lg bg-amber-50 p-2 font-semibold text-amber-900" data-testid="case-paused">
          Pausiert: {REASON_LABEL[item.last_reason ?? ""] ?? item.last_reason}
          {item.expected_end ? ` bis voraussichtlich ${item.expected_end}` : ""} · {item.suspended_visits} Einsätze ausgesetzt
        </p>
      )}
      {error && <p role="alert" data-testid="command-error" className="rounded-lg border border-rose-300 bg-rose-50 p-2 font-semibold text-rose-800">{error}</p>}
      {mode === "idle" && (
        <div className="flex flex-wrap gap-2">
          {item.lifecycle === "active" && (
            <button type="button" onClick={() => setMode("pause")} className="min-h-11 rounded-lg border border-stone-400 bg-white px-3 font-semibold">Pausieren</button>
          )}
          {item.lifecycle === "paused" && (
            <button type="button" disabled={pending} onClick={() => run(() => resumeCase({ caseId: item.case_id, idempotencyKey: crypto.randomUUID() }))}
              className="min-h-11 rounded-lg bg-emerald-800 px-3 font-bold text-white disabled:opacity-60">Fortsetzen</button>
          )}
          <button type="button" onClick={() => setMode("close")} className="min-h-11 rounded-lg border border-stone-400 bg-white px-3 font-semibold">Fall abschliessen</button>
        </div>
      )}
      {mode !== "idle" && (
        <form
          aria-label={mode === "pause" ? "Fall pausieren" : "Fall abschliessen"}
          action={(f) => {
            const code = String(f.get("code") ?? "");
            const note = String(f.get("note") ?? "");
            const allowed = mode === "pause" ? PAUSE_REASONS : CLOSE_REASONS;
            const problem = reasonError(code, note, allowed);
            if (problem) return setError(problem);
            const end = String(f.get("end") ?? "");
            run(() => mode === "pause"
              ? pauseCase({ caseId: item.case_id, reasonCode: code, note, expectedEnd: end || null, idempotencyKey: crypto.randomUUID() })
              : closeCase({ caseId: item.case_id, reasonCode: code, note, idempotencyKey: crypto.randomUUID() }));
          }}
          className="grid gap-2"
        >
          <label className="grid gap-1 text-xs font-semibold">
            Grund
            <select name="code" required defaultValue="" className={field}>
              <option value="" disabled>– bitte wählen –</option>
              {(mode === "pause" ? PAUSE_REASONS : CLOSE_REASONS).map((r) => <option key={r} value={r}>{REASON_LABEL[r] ?? r}</option>)}
            </select>
          </label>
          {mode === "pause" && (
            <label className="grid gap-1 text-xs font-semibold">
              Voraussichtliches Ende (optional)
              <input name="end" type="date" className={field} />
            </label>
          )}
          <label className="grid gap-1 text-xs font-semibold">
            Notiz (bei «Anderer Grund» nötig)
            <input name="note" maxLength={500} className={field} />
          </label>
          {mode === "close" && (
            <p className="text-xs text-stone-600">Alle künftigen geplanten Einsätze werden abgesagt; Berichte, Qualitätsereignisse und Abrechnungsfakten bleiben unverändert.</p>
          )}
          <div className="grid grid-cols-2 gap-2">
            <button type="submit" disabled={pending} className="min-h-11 rounded-lg bg-emerald-800 font-bold text-white disabled:opacity-60">
              {pending ? "Wird gespeichert …" : mode === "pause" ? "Pausieren" : "Abschliessen"}
            </button>
            <button type="button" onClick={() => setMode("idle")} className="min-h-11 rounded-lg border border-stone-300 font-semibold">Abbrechen</button>
          </div>
        </form>
      )}
    </section>
  );
}

/** Closed cases of the team, each reopenable with a reason (the J1 readiness check runs again before planning). */
export function ClosedCases({ items }: { items: CaseLifecycle[] }) {
  if (items.length === 0) return null;
  return (
    <section aria-label="Abgeschlossene Fälle" className="mt-6 grid gap-2">
      <h2 className="text-sm font-bold uppercase tracking-wide text-emerald-900/60">Abgeschlossene Fälle</h2>
      <ul className="grid gap-2">
        {items.map((c) => <li key={c.case_id}><ClosedCase item={c} /></li>)}
      </ul>
    </section>
  );
}

function ClosedCase({ item }: { item: CaseLifecycle }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);
  return (
    <article aria-label={`Abgeschlossen ${item.client_name ?? ""}`} className="rounded-xl bg-white p-3 text-sm shadow-sm">
      <p className="font-semibold">{item.client_name ?? "Klient:in"} · {item.team_name}</p>
      <p className="text-xs text-stone-600">Abgeschlossen: {REASON_LABEL[item.last_reason ?? ""] ?? item.last_reason}</p>
      {error && <p role="alert" className="font-semibold text-rose-800">{error}</p>}
      {!open ? (
        <button type="button" onClick={() => setOpen(true)} className="mt-1 min-h-11 px-1 font-semibold underline underline-offset-4">Wiedereröffnen</button>
      ) : (
        <form action={async (f) => {
          setPending(true);
          const result = await reopenCase({ caseId: item.case_id, reason: String(f.get("reason") ?? ""), idempotencyKey: crypto.randomUUID() });
          setPending(false);
          if (!result.ok) return setError(result.error);
          router.refresh();
        }} className="mt-1 grid gap-2">
          <label className="grid gap-1 text-xs font-semibold">
            Begründung
            <input name="reason" required minLength={3} maxLength={500} className="min-h-11 rounded-lg border border-stone-300 bg-white px-2" />
          </label>
          <button type="submit" disabled={pending} className="min-h-11 rounded-lg bg-emerald-800 font-bold text-white disabled:opacity-60">Wiedereröffnen</button>
        </form>
      )}
    </article>
  );
}
