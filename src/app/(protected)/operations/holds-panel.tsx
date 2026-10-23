"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { liftQualityHold } from "@/features/quality/commands";
import type { OpenHold } from "@/features/quality/queries";
import { HOLD_MEANING } from "@/features/quality/rules";

/** QG1: open quality holds, labelled "Abrechnungssperre" (CSR1 / CGR-13). Coach or admin lift them with a reason (provisional role rule, D-16). */
export default function HoldsPanel({ holds }: { holds: OpenHold[] }) {
  return (
    <section aria-label="Abrechnungssperren" className="grid gap-2 rounded-xl border border-stone-200 bg-white p-4 shadow-sm">
      <h2 className="text-lg font-bold">Abrechnungssperren</h2>
      <p className="text-sm text-stone-500">{HOLD_MEANING} Aufheben: Coach oder Admin, mit Begründung.</p>
      {holds.length === 0 ? (
        <p className="text-sm text-stone-500">Keine offenen Abrechnungssperren.</p>
      ) : (
        <ul className="grid gap-2">
          {holds.map((h) => (
            <li key={h.id}>
              <HoldRow hold={h} />
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

function HoldRow({ hold }: { hold: OpenHold }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function lift(form: FormData) {
    setPending(true);
    setError(null);
    const result = await liftQualityHold({ holdId: hold.id, reason: String(form.get("reason") ?? ""), idempotencyKey: crypto.randomUUID() });
    setPending(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    router.refresh();
  }

  return (
    <article aria-label={`Abrechnungssperre ${hold.reason}`} data-testid="hold" className="rounded-lg border-l-8 border-rose-500 bg-rose-50 p-2 text-sm">
      <p className="font-semibold">{hold.reason}</p>
      <p className="text-xs text-stone-600">gesetzt {new Date(hold.set_at).toLocaleString("de-CH", { timeZone: "Europe/Zurich" })}</p>
      {error && <p role="alert" data-testid="command-error" className="mt-1 font-semibold text-rose-800">{error}</p>}
      {!open ? (
        <button type="button" onClick={() => setOpen(true)} className="mt-1 min-h-10 rounded-lg border border-stone-400 bg-white px-3 font-semibold">
          Sperre aufheben
        </button>
      ) : (
        <form action={lift} className="mt-1 grid gap-1">
          <label className="grid gap-1">
            <span className="text-xs font-semibold">Begründung</span>
            <textarea name="reason" required minLength={3} maxLength={500} rows={2} className="rounded border border-stone-300 bg-white p-2" />
          </label>
          <div className="flex gap-2">
            <button type="submit" disabled={pending} className="min-h-10 rounded-lg bg-emerald-800 px-3 font-bold text-white disabled:opacity-60">
              {pending ? "Wird gespeichert …" : "Aufheben"}
            </button>
            <button type="button" onClick={() => setOpen(false)} className="min-h-10 rounded-lg border border-stone-300 bg-white px-3 font-semibold">
              Abbrechen
            </button>
          </div>
        </form>
      )}
    </article>
  );
}
