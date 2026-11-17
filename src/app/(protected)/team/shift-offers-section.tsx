"use client";

// BK-c2 (ADR-200; brief BK.md 04:39 (4), 05:39 (3), 08:39 (2), (4), 09:39 (2) (d)): the shift-order offers of the
// caller's teams. Every state comes from the database; the card only shows it and sends one command. No countdown, no
// other team, no reason about a person (BK5_OFFER_TEMPLATE.md §2, §3). Synthetic data only (Phase A).
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import type { TeamShiftOffer } from "@/features/orders/team-queries";
import {
  ACK_FINAL_LINE,
  CANNOT_STEP,
  DECLINE_STEP,
  offerPlaceLine,
  TAKE_FOOTER,
  type ConfirmStep as ConfirmStepWords,
} from "@/features/orders/offer-rules";
import {
  acknowledgeShiftTake,
  declineShiftOrder,
  releaseNamedShiftTake,
  takeShiftOrder,
  type OfferCommandResult,
} from "@/features/orders/team-commands";

export default function ShiftOffersSection({ offers }: { offers: TeamShiftOffer[] }) {
  const [notice, setNotice] = useState<string | null>(null);
  return (
    <section aria-labelledby="shift-offers-heading" className="grid gap-3" data-testid="shift-offers">
      <h2 id="shift-offers-heading" className="text-lg font-bold">Schichtangebote</h2>
      {notice && (
        <div role="status" data-testid="shift-offer-notice" className="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-stone-300 bg-white p-3 text-sm">
          <span>{notice}</span>
          <button type="button" onClick={() => setNotice(null)} className="min-h-11 rounded-lg px-3 font-semibold underline underline-offset-4">
            Schliessen
          </button>
        </div>
      )}
      {offers.length === 0 && <p className="rounded-2xl border border-dashed border-emerald-900/20 bg-white/70 p-4 text-sm">Zurzeit kein Schichtangebot für deine Teams.</p>}
      <ul className="grid gap-3" aria-label="Schichtangebote">
        {offers.map((o) => (
          <li key={`${o.row.order_id}-${o.row.team_id}`}>
            <ShiftOfferCard offer={o} onNotice={setNotice} />
          </li>
        ))}
      </ul>
    </section>
  );
}

/**
 * UXR-224 (PO 12:39 (1); #1361): the inline confirm step. The first tap only opens it (nothing is written); focus moves
 * to the consequence sentence; «Zurück» restores the card; the step's action sends the command.
 */
function ConfirmStep({ words, busy, onConfirm, onBack }: { words: ConfirmStepWords; busy: boolean; onConfirm: () => void; onBack: () => void }) {
  const sentence = useRef<HTMLParagraphElement>(null);
  useEffect(() => {
    sentence.current?.focus();
  }, []);
  return (
    <div data-testid="shift-offer-step" className="grid gap-2 rounded-xl border border-stone-300 bg-stone-50 p-3">
      <p ref={sentence} tabIndex={-1} data-testid="shift-offer-step-sentence" className="font-semibold outline-none focus-visible:ring-2 focus-visible:ring-emerald-900">
        {words.sentence}
      </p>
      <div className="flex flex-wrap gap-2">
        <button
          type="button"
          disabled={busy}
          aria-busy={busy}
          onClick={onConfirm}
          className="min-h-11 rounded-lg bg-emerald-900 px-4 font-semibold text-white disabled:opacity-60"
        >
          {words.action}
        </button>
        <button
          type="button"
          disabled={busy}
          onClick={onBack}
          className="min-h-11 rounded-lg border border-emerald-900 px-4 font-semibold text-emerald-900 disabled:opacity-60"
        >
          {words.back}
        </button>
      </div>
    </div>
  );
}

function ShiftOfferCard({ offer, onNotice }: { offer: TeamShiftOffer; onNotice: (text: string) => void }) {
  const router = useRouter();
  const { row, view } = offer;
  const [pending, setPending] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [chosen, setChosen] = useState<string | null>(view.kind === "offer" ? view.preselected : null);
  const [step, setStep] = useState<"cannot" | "decline" | null>(null);

  async function run(op: string, call: () => Promise<OfferCommandResult>) {
    setPending(op);
    setError(null);
    const r = await call();
    setPending(null);
    setStep(null);
    if (r.status) onNotice(r.status);
    if (!r.ok && r.error) setError(r.error);
    router.refresh();
  }

  const facts = (
    <>
      <p className="break-words font-semibold" data-testid="shift-offer-sentence">{row.sentence}</p>
      {view.kind === "offer" && <p className="text-sm text-secondary">{offerPlaceLine(row)}</p>}
    </>
  );

  if (view.kind === "released") {
    return (
      <article aria-label="Schichtangebot" data-testid="shift-offer-card" className="grid gap-2 rounded-2xl bg-white p-4 shadow-sm">
        {facts}
        <p data-testid="shift-offer-release">{view.line}</p>
      </article>
    );
  }

  if (view.kind === "taken") {
    return (
      <article aria-label="Schichtangebot" data-testid="shift-offer-card" className="grid gap-2 rounded-2xl bg-white p-4 shadow-sm">
        <span data-testid="shift-offer-tag" className="w-fit rounded-full bg-emerald-50 px-3 py-1 text-xs font-bold text-emerald-900">{view.tag}</span>
        {view.mine && view.actions ? (
          <>
            <p data-testid="shift-offer-line">{view.lines[0]}</p>
            {facts}
            {view.lines.slice(1).map((l) => <p key={l} data-testid="shift-offer-line">{l}</p>)}
          </>
        ) : (
          <>
            {facts}
            {view.lines.map((l) => <p key={l} data-testid="shift-offer-line">{l}</p>)}
          </>
        )}
        {view.wayBack && !view.actions && (
          <p data-testid="shift-offer-way-back" className="text-sm text-secondary">{view.wayBack}</p>
        )}
        {view.wayBack && !view.actions && (
          <Link href="/field" className="flex min-h-11 w-fit items-center rounded-lg px-2 text-sm font-semibold text-emerald-900 underline underline-offset-4">
            Abwesenheit erfassen
          </Link>
        )}
        {error && <p role="alert" data-testid="shift-offer-error" className="rounded-lg border border-rose-300 bg-rose-50 p-3 text-sm font-semibold text-rose-800">{error}</p>}
        {view.actions && step === "cannot" && (
          <ConfirmStep
            words={CANNOT_STEP}
            busy={pending !== null}
            onConfirm={() => run("cannot", () => releaseNamedShiftTake({ orderId: row.order_id, idempotencyKey: crypto.randomUUID() }))}
            onBack={() => setStep(null)}
          />
        )}
        {view.actions && step === null && (
          <>
            <div className="flex flex-wrap gap-2">
              <button
                type="button"
                disabled={pending !== null}
                aria-busy={pending === "ack"}
                onClick={() => run("ack", () => acknowledgeShiftTake({ orderId: row.order_id, idempotencyKey: crypto.randomUUID() }))}
                className="min-h-11 rounded-lg bg-emerald-900 px-4 font-semibold text-white disabled:opacity-60"
              >
                Bestätigen
              </button>
              <button
                type="button"
                disabled={pending !== null}
                onClick={() => setStep("cannot")}
                className="min-h-11 rounded-lg border border-emerald-900 px-4 font-semibold text-emerald-900 disabled:opacity-60"
              >
                Ich kann nicht
              </button>
            </div>
            <p data-testid="shift-offer-ack-note" className="text-sm text-secondary">{ACK_FINAL_LINE}</p>
            {view.wayBack && <p data-testid="shift-offer-way-back" className="text-sm text-secondary">{view.wayBack}</p>}
          </>
        )}
      </article>
    );
  }

  const chosenLabel = view.candidates.find((c) => c.userId === chosen)?.label;
  const primary = chosen && chosenLabel ? `Übernehmen mit ${chosenLabel.replace(/^Ich \((.*)\)$/, "$1")}` : view.chooseLabel;
  const groupId = `who-${row.order_id}-${row.team_id}`;
  return (
    <article aria-label="Schichtangebot" data-testid="shift-offer-card" className="grid gap-2 rounded-2xl bg-white p-4 shadow-sm">
      <span data-testid="shift-offer-tag" className="w-fit rounded-full bg-emerald-50 px-3 py-1 text-xs font-bold text-emerald-900">{view.tag}</span>
      {view.releaseLine && <p data-testid="shift-offer-release">{view.releaseLine}</p>}
      {facts}
      <p data-testid="shift-offer-broadcast">{view.broadcast}</p>
      <fieldset className="grid gap-1" aria-describedby={view.callerNotFree ? `${groupId}-self` : undefined}>
        <legend className="font-semibold">Wählt, wer geht</legend>
        {view.callerNotFree && <p id={`${groupId}-self`} data-testid="shift-offer-self-not-free" className="text-sm">{view.callerNotFree}</p>}
        {view.nobodyLine && <p data-testid="shift-offer-nobody" className="text-sm">{view.nobodyLine}</p>}
        {view.candidates.map((c) => (
          <label key={c.userId} className="flex min-h-11 items-center gap-2">
            <input type="radio" name={groupId} value={c.userId} checked={chosen === c.userId} onChange={() => setChosen(c.userId)} />
            {c.label}
          </label>
        ))}
      </fieldset>
      {error && <p role="alert" data-testid="shift-offer-error" className="rounded-lg border border-rose-300 bg-rose-50 p-3 text-sm font-semibold text-rose-800">{error}</p>}
      {step === "decline" ? (
        <ConfirmStep
          words={DECLINE_STEP}
          busy={pending !== null}
          onConfirm={() => run("decline", () => declineShiftOrder({ orderId: row.order_id, teamId: row.team_id, idempotencyKey: crypto.randomUUID() }))}
          onBack={() => setStep(null)}
        />
      ) : (
        <div className="flex flex-wrap gap-2">
          {view.chooseLabel !== null && (
            <button
              type="button"
              disabled={pending !== null || !chosen}
              aria-busy={pending === "take"}
              onClick={() =>
                chosen && run("take", () => takeShiftOrder({ orderId: row.order_id, teamId: row.team_id, memberId: chosen, idempotencyKey: crypto.randomUUID() }))
              }
              className="min-h-11 rounded-lg bg-emerald-900 px-4 font-semibold text-white disabled:opacity-60"
            >
              {primary}
            </button>
          )}
          <button
            type="button"
            disabled={pending !== null}
            onClick={() => setStep("decline")}
            className="min-h-11 rounded-lg border border-emerald-900 px-4 font-semibold text-emerald-900 disabled:opacity-60"
          >
            Ablehnen
          </button>
        </div>
      )}
      <p className="text-xs text-secondary">{TAKE_FOOTER}</p>
    </article>
  );
}
