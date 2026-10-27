"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { recordQualityEvent, setQualityEventStatus, setQualityHold } from "@/features/quality/commands";
import { HOLD_MEANING, NO_TYPES_NOTICE, SEVERITIES, SEVERITY_LABEL, canTakeOver, eventStatusText, isSerious } from "@/features/quality/rules";
import type { FieldQuality, QualityEventType } from "@/features/quality/queries";
import { HOLD_CONSEQUENCE } from "@/features/field/rules";

/**
 * QG1 on the /field card: events and holds of this visit, report an event (clinically approved
 * types only, D-16), and set a quality hold with a reason. Lifting a hold is for coach/admin.
 * CSR1 / CGR-13: the hold is labelled "Abrechnungssperre" (billing hold), so nobody reads it as a stop of care.
 */
export default function QualitySection({
  visitId,
  items,
  types,
  holdRequested = false,
  onHoldClosed,
}: {
  visitId: string;
  items: FieldQuality[];
  types: QualityEventType[];
  /** UX1-8 (ADR-104): "Abrechnungssperre setzen" was chosen in the card's "Mehr" menu (second tap). */
  holdRequested?: boolean;
  onHoldClosed?: () => void;
}) {
  const router = useRouter();
  const [mode, setMode] = useState<"idle" | "event" | "hold">("idle");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const events = items.filter((i) => i.kind === "event");
  const openHold = items.find((i) => i.kind === "hold" && i.status === "open");

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
    onHoldClosed?.();
    router.refresh();
  }
  const showHold = (mode === "hold" || (holdRequested && mode === "idle")) && !openHold;
  const closeHold = () => { setMode("idle"); onHoldClosed?.(); };

  return (
    <section aria-label="Qualität" data-testid="quality" className="mt-3 grid gap-2 rounded-xl border border-stone-200 p-3 text-sm">
      <div className="flex items-center justify-between gap-2">
        <h3 className="font-bold">Qualität</h3>
        {openHold && (
          <span data-testid="quality-hold" className="rounded-full bg-rose-100 px-3 py-1 text-xs font-bold text-rose-900">
            Abrechnungssperre
          </span>
        )}
      </div>
      {openHold && (
        // CSR1 / CGR-13 (until D-16): a hold blocks billing only; it is never shown as a stop of care.
        <p className="text-xs text-rose-900" data-testid="quality-hold-meaning">
          Abrechnungssperre: {openHold.label} · {HOLD_MEANING} Aufheben: Coach oder Admin.
        </p>
      )}

      {events.length > 0 && (
        <ul className="grid gap-1" aria-label="Qualitätsereignisse">
          {events.map((e) => (
            <li key={e.id}>
              <EventRow event={e} onRun={run} pending={pending} />
            </li>
          ))}
        </ul>
      )}

      {error && (
        <p role="alert" data-testid="command-error" className="rounded-lg border border-rose-300 bg-rose-50 p-2 font-semibold text-rose-800">
          {error}
        </p>
      )}

      {/* UX1-9 (PO decision): "Ereignis melden" stays one tap, an outline button on the card (QG1). UX1-8: the hold is set
          from the card's "Mehr" menu (two taps, consequence stated first); command, audit and refusals unchanged. */}
      {mode === "idle" && !showHold && (
        <div className="grid grid-cols-2 gap-2">
          <button type="button" onClick={() => setMode("event")} className="min-h-11 rounded-lg border-2 border-emerald-800 bg-white font-semibold">
            Ereignis melden
          </button>
        </div>
      )}

      {mode === "event" &&
        (types.length === 0 ? (
          <div className="grid gap-2">
            <p data-testid="no-types" className="rounded-lg bg-amber-50 p-2 text-amber-900">{NO_TYPES_NOTICE}</p>
            <button type="button" onClick={() => setMode("idle")} className="min-h-11 rounded-lg border border-stone-300 font-semibold">
              Schliessen
            </button>
          </div>
        ) : (
          <form
            action={(form) =>
              run(() =>
                recordQualityEvent({
                  visitId,
                  typeCode: String(form.get("type") ?? ""),
                  severity: String(form.get("severity") ?? ""),
                  note: String(form.get("note") ?? ""),
                  idempotencyKey: crypto.randomUUID(),
                }),
              )
            }
            className="grid gap-2"
          >
            <label className="grid gap-1">
              <span className="text-xs font-semibold">Ereignis</span>
              <select name="type" required className="min-h-11 rounded-lg border border-stone-300 bg-white px-2">
                {types.map((t) => (
                  <option key={t.code} value={t.code}>{t.label}</option>
                ))}
              </select>
            </label>
            <label className="grid gap-1">
              <span className="text-xs font-semibold">Schweregrad</span>
              <select name="severity" required defaultValue="medium" className="min-h-11 rounded-lg border border-stone-300 bg-white px-2">
                {SEVERITIES.map((s) => (
                  <option key={s} value={s}>{SEVERITY_LABEL[s]}</option>
                ))}
              </select>
            </label>
            <label className="grid gap-1">
              <span className="text-xs font-semibold">Notiz (optional)</span>
              <textarea name="note" maxLength={2000} rows={2} className="rounded-lg border border-stone-300 bg-white p-2" />
            </label>
            <FormButtons pending={pending} label="Ereignis speichern" onCancel={() => setMode("idle")} />
          </form>
        ))}

      {showHold && (
        <form
          aria-label="Abrechnungssperre setzen"
          ref={scrollNear}
          action={(form) =>
            run(() => setQualityHold({ visitId, reason: String(form.get("reason") ?? ""), idempotencyKey: crypto.randomUUID() }))
          }
          className="grid gap-2"
        >
          <p data-testid="more-consequence" className="font-semibold">{HOLD_CONSEQUENCE}</p>
          <label className="grid gap-1">
            <span className="text-xs font-semibold">Begründung für die Abrechnungssperre</span>
            <textarea name="reason" required minLength={3} maxLength={500} rows={2} className="rounded-lg border border-stone-300 bg-white p-2" />
          </label>
          <FormButtons pending={pending} label="Sperre setzen" onCancel={closeHold} />
          <p className="text-xs text-emerald-900/60">{HOLD_MEANING} Aufheben: Coach oder Admin, mit Begründung.</p>
        </form>
      )}
    </section>
  );
}

/** UX1-8: the form opened from "Mehr" may sit above the menu; bring it into view once (stable ref callback). */
function scrollNear(el: HTMLElement | null) {
  el?.scrollIntoView({ block: "nearest" });
}

function EventRow({
  event,
  onRun,
  pending,
}: {
  event: FieldQuality;
  onRun: (call: () => Promise<{ ok: boolean; error?: string }>) => void;
  pending: boolean;
}) {
  const [closing, setClosing] = useState(false);
  return (
    <div data-testid="quality-event" className={`rounded-lg p-2 ${isSerious(event.severity) ? "bg-rose-50" : "bg-stone-50"}`}>
      <p>
        <span className="font-semibold">{event.label}</span> · {SEVERITY_LABEL[event.severity as keyof typeof SEVERITY_LABEL] ?? event.severity} ·{" "}
        <span data-testid="event-status">{eventStatusText(event)}</span>
        {event.own ? " · von dir" : event.person_name ? ` · von ${event.person_name}` : ""}
      </p>
      {event.status !== "closed" && !closing && (
        <div className="mt-1 flex gap-2">
          {event.status === "open" && (
            <button type="button" disabled={pending} className="min-h-10 px-2 font-semibold underline underline-offset-4"
              onClick={() => onRun(() => setQualityEventStatus({ eventId: event.id, status: "in_review", note: "", idempotencyKey: crypto.randomUUID() }))}>
              In Prüfung nehmen
            </button>
          )}
          {canTakeOver(event) && (
            <button type="button" disabled={pending} data-testid="event-take-over" className="min-h-10 px-2 font-semibold underline underline-offset-4"
              onClick={() => onRun(() => setQualityEventStatus({ eventId: event.id, status: "in_review", note: "", idempotencyKey: crypto.randomUUID() }))}>
              Übernehmen
            </button>
          )}
          <button type="button" onClick={() => setClosing(true)} className="min-h-10 px-2 font-semibold underline underline-offset-4">
            Abschliessen
          </button>
        </div>
      )}
      {closing && (
        <form
          action={(form) =>
            onRun(() =>
              setQualityEventStatus({ eventId: event.id, status: "closed", note: String(form.get("note") ?? ""), idempotencyKey: crypto.randomUUID() }),
            )
          }
          className="mt-1 grid gap-1"
        >
          <label className="grid gap-1">
            <span className="text-xs font-semibold">Abschlussnotiz</span>
            <textarea name="note" required minLength={3} maxLength={1000} rows={2} className="rounded-lg border border-stone-300 bg-white p-2" />
          </label>
          <FormButtons pending={pending} label="Ereignis abschliessen" onCancel={() => setClosing(false)} />
        </form>
      )}
    </div>
  );
}

function FormButtons({ pending, label, onCancel }: { pending: boolean; label: string; onCancel: () => void }) {
  return (
    <div className="grid grid-cols-2 gap-2">
      <button type="submit" disabled={pending} className="min-h-11 rounded-lg bg-emerald-800 font-bold text-white disabled:opacity-60">
        {pending ? "Wird gespeichert …" : label}
      </button>
      <button type="button" onClick={onCancel} className="min-h-11 rounded-lg border border-stone-300 font-semibold">
        Abbrechen
      </button>
    </div>
  );
}
