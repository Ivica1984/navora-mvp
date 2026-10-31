"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { pollSignals, takeSignal } from "@/features/signals/commands";
import { SIGNAL_POLL_MS, reasonText, signalHref, signalText, signalWhen, splitSignals, takenText, type SignalRow } from "@/features/signals/rules";

// SIG1-3 / SIG1-4: P1 safety signals of the signed-in person at the top of /field, /team and OPS1, refreshed every
// 30 s without a reload. "Ich übernehme" records who takes it; the signal stays open until its cause ends (CR-041).
// UX1-22 (ADR-109): `onRows` reports the rows on screen, so a list below that points up to a signal card ("Steht oben
// als Sicherheitssignal") follows the cards as they are polled, never a card that is gone.
export default function SignalBanner({ initial, onRows }: { initial: SignalRow[]; onRows?: (rows: SignalRow[]) => void }) {
  const [rows, setRows] = useState<SignalRow[]>(initial);
  const [pending, setPending] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  // A server refresh (router.refresh after a command) brings new initial rows (derived during render, not in an effect).
  const [seen, setSeen] = useState(initial);
  if (initial !== seen) {
    setSeen(initial);
    setRows(initial);
  }

  useEffect(() => {
    let alive = true;
    const tick = async () => {
      const r = await pollSignals().catch(() => ({ ok: false as const }));
      if (alive && r.ok) setRows(r.rows);
    };
    const id = setInterval(tick, SIGNAL_POLL_MS);
    return () => {
      alive = false;
      clearInterval(id);
    };
  }, []);

  useEffect(() => {
    onRows?.(rows);
  }, [rows, onRows]);

  async function take(signalId: string) {
    setPending(signalId);
    setError(null);
    const r = await takeSignal({ signalId, idempotencyKey: crypto.randomUUID() });
    setPending(null);
    if (!r.ok) {
      setError(r.error);
      return;
    }
    const next = await pollSignals().catch(() => ({ ok: false as const }));
    if (next.ok) setRows(next.rows);
  }

  const { open, taken } = splitSignals(rows);
  if (open.length === 0 && taken.length === 0) return <div data-testid="safety-signals-empty" hidden />;

  return (
    <section aria-label="Sicherheitssignale" aria-live="polite" data-testid="safety-signals" className="mb-4 grid gap-2 text-sm">
      {open.length > 0 && (
        <ol aria-label="Offene Sicherheitssignale" className="grid gap-2">
          {open.map((s) => (
            <li key={s.signal_id} data-testid="safety-signal" data-kind={s.signal_kind} data-visit-date={s.visit_date}
                className="rounded-xl border-l-4 border-rose-700 bg-rose-50 p-3">
              <p className="font-bold text-rose-900">{signalText(s.signal_kind)}</p>
              <p className="text-rose-900/80">
                <Link href={signalHref(s)} className="underline">{signalWhen(s)}</Link>
                {reasonText(s.reason, Boolean(s.outside_none)) ? ` · ${reasonText(s.reason, Boolean(s.outside_none))}` : ""}
              </p>
              {/* SIG1-C1: taken by a care assistant; the step to Operations still follows until a registered nurse takes it.
                  LEAVE1-14: taken by a person whose access has ended; it stops nothing. */}
              {(s.taken_awaits_rn || s.taker_access_ended) && (
                <p data-testid="safety-signal-taken-by" className="font-semibold text-rose-900">{takenText(s)}</p>
              )}
              <button type="button" disabled={pending === s.signal_id} onClick={() => take(s.signal_id)}
                      className="mt-2 min-h-11 rounded-lg bg-rose-800 px-4 font-bold text-white disabled:opacity-60">
                Ich übernehme
              </button>
            </li>
          ))}
        </ol>
      )}
      {taken.length > 0 && (
        <ul aria-label="Übernommene Sicherheitssignale" className="grid gap-1">
          {taken.map((s) => (
            <li key={s.signal_id} data-testid="safety-signal-taken" data-kind={s.signal_kind} data-visit-date={s.visit_date}
                className="rounded-lg bg-stone-100 p-2">
              <span className="font-semibold">{signalText(s.signal_kind)}</span>
              {" · "}
              <Link href={signalHref(s)} className="underline">{signalWhen(s)}</Link>
              {" · "}
              <span data-testid="safety-signal-taken-by">{takenText(s)}</span>
            </li>
          ))}
        </ul>
      )}
      {error && <p role="alert" data-testid="command-error" className="rounded-lg border border-rose-300 bg-rose-50 p-2 font-semibold text-rose-800">{error}</p>}
    </section>
  );
}
