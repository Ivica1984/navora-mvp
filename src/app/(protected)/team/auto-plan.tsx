"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { planFromCarePlan, setAutoPlanning, setCarePlanSchedule } from "@/features/planning/commands";
import type { PlanStatus } from "@/features/planning/queries";
import { BLOCKED_LABEL, WEEKDAYS, describeSchedule, scheduleError, type Schedule } from "@/features/planning/rules";

export type ScheduledItem = Schedule & { id: string; service: string; category: string; minutes: number };

const field = "min-h-11 rounded-lg border border-stone-300 bg-white px-2";

/**
 * PLAN2 on the /team case card: the care plan generates the next four weeks; the team sets the rhythm
 * per service, plans now, or switches the series off. Team changes to single visits are never overwritten.
 */
export default function AutoPlan({ caseId, status, items }: { caseId: string; status: PlanStatus | null; items: ScheduledItem[] }) {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notes, setNotes] = useState<string[]>([]);
  const [toggling, setToggling] = useState(false);
  const [editing, setEditing] = useState<string | null>(null);
  const on = status?.auto_planning ?? true;

  async function run(call: () => Promise<{ ok: boolean; error?: string; notes?: string[] }>, after?: () => void) {
    setPending(true);
    setError(null);
    const result = await call();
    setPending(false);
    if (!result.ok) return setError(result.error ?? "Konnte nicht gespeichert werden.");
    setNotes(result.notes ?? []);
    after?.();
    router.refresh();
  }

  return (
    <section aria-label="Automatische Planung" data-testid="auto-plan" className="mt-3 grid gap-2 rounded-xl border border-emerald-900/10 p-3 text-sm">
      <p className="font-semibold">
        Automatische Planung: <span data-testid="auto-plan-state">{on ? "an" : "aus"}</span>
        {status && on && <> · <span data-testid="generated-ahead">{status.generated_ahead}</span> Einsätze in den nächsten 4 Wochen</>}
      </p>
      {status?.blocked_reason && <p className="rounded-lg bg-amber-50 p-2 text-amber-900" data-testid="plan-blocked">{BLOCKED_LABEL[status.blocked_reason] ?? status.blocked_reason}</p>}
      {status && status.order_flagged > 0 && (
        <p className="rounded-lg bg-rose-50 p-2 font-semibold text-rose-900" data-testid="plan-order-flagged">
          {status.order_flagged} geplante{status.order_flagged === 1 ? "r Einsatz enthält" : " Einsätze enthalten"} B-Leistungen nach dem Ende der ärztlichen Verordnung.
        </p>
      )}

      <ul className="grid gap-1" aria-label="Rhythmus je Leistung">
        {items.map((item) => (
          <li key={item.id} aria-label={`Rhythmus ${item.service}`}>
            <span className="font-semibold">{item.service}</span> ({item.category}, {item.minutes} min):{" "}
            <span data-testid="schedule">{describeSchedule(item) ?? "nicht automatisch geplant"}</span>{" "}
            {editing !== item.id && (
              <button type="button" className="underline" onClick={() => setEditing(item.id)}>Rhythmus festlegen</button>
            )}
            {editing === item.id && (
              <ScheduleForm item={item} pending={pending}
                onCancel={() => setEditing(null)}
                onSubmit={(input) => run(() => setCarePlanSchedule({ ...input, itemId: item.id, idempotencyKey: crypto.randomUUID() }), () => setEditing(null))}
                onLocalError={setError} />
            )}
          </li>
        ))}
      </ul>

      {error && <p role="alert" data-testid="command-error" className="rounded-lg border border-rose-300 bg-rose-50 p-2 font-semibold text-rose-800">{error}</p>}
      {notes.length > 0 && (
        <ul className="list-disc pl-5 text-xs text-emerald-900/80" aria-label="Hinweise zur Planung">
          {notes.map((n) => <li key={n}>{n}</li>)}
        </ul>
      )}

      {!toggling ? (
        <div className="flex flex-wrap gap-2">
          {on && (
            <button type="button" disabled={pending} className="min-h-11 rounded-lg bg-emerald-800 px-3 font-bold text-white disabled:opacity-60"
              onClick={() => run(() => planFromCarePlan({ caseId, idempotencyKey: crypto.randomUUID() }))}>
              Jetzt planen
            </button>
          )}
          <button type="button" className="min-h-11 rounded-lg border border-stone-400 px-3 font-semibold" onClick={() => setToggling(true)}>
            {on ? "Serie stoppen" : "Serie fortsetzen"}
          </button>
        </div>
      ) : (
        <form aria-label={on ? "Serie stoppen" : "Serie fortsetzen"} className="grid gap-2" onSubmit={(e) => {
          e.preventDefault();
          const reason = String(new FormData(e.currentTarget).get("reason") ?? "").trim();
          if (reason.length < 3) return setError("Bitte einen Grund angeben.");
          run(() => setAutoPlanning({ caseId, enabled: !on, reason, idempotencyKey: crypto.randomUUID() }), () => setToggling(false));
        }}>
          <label className="grid gap-1 text-xs font-semibold">
            Grund
            <input name="reason" required minLength={3} maxLength={300} className={field} />
          </label>
          {on && <p className="text-xs text-stone-600">Künftige, vom Team nicht veränderte Einsätze der Serie werden entfernt.</p>}
          <div className="grid grid-cols-2 gap-2">
            <button type="submit" disabled={pending} className="min-h-11 rounded-lg bg-emerald-800 font-bold text-white disabled:opacity-60">
              {on ? "Serie stoppen" : "Serie fortsetzen"}
            </button>
            <button type="button" onClick={() => setToggling(false)} className="min-h-11 rounded-lg border border-stone-300 font-semibold">Abbrechen</button>
          </div>
        </form>
      )}
    </section>
  );
}

type ScheduleInput = { period: "day" | "week" | null; times: number | null; weekdays: number[] | null; windowStart: string | null; windowEnd: string | null };

function ScheduleForm({ item, pending, onSubmit, onCancel, onLocalError }: {
  item: ScheduledItem; pending: boolean; onSubmit: (input: ScheduleInput) => void; onCancel: () => void; onLocalError: (e: string | null) => void;
}) {
  const [period, setPeriod] = useState<string>(item.freq_period ?? "week");
  return (
    <form aria-label={`Rhythmus für ${item.service}`} className="mt-1 grid gap-2 rounded-lg bg-stone-50 p-2" onSubmit={(e) => {
      e.preventDefault();
      const f = new FormData(e.currentTarget);
      const times = period === "day" ? 1 : Number(f.get("times") ?? 0);
      const weekdays = period === "day" ? [] : f.getAll("weekday").map(Number);
      const start = String(f.get("start") ?? "");
      const end = String(f.get("end") ?? "");
      const problem = scheduleError(period, times, weekdays, start, end);
      if (problem) return onLocalError(problem);
      onLocalError(null);
      onSubmit({ period: period as "day" | "week", times, weekdays: weekdays.length ? weekdays : null, windowStart: start, windowEnd: end });
    }}>
      <label className="grid gap-1 text-xs font-semibold">
        Rhythmus
        <select name="period" value={period} onChange={(e) => setPeriod(e.target.value)} className={field}>
          <option value="day">täglich</option>
          <option value="week">pro Woche</option>
        </select>
      </label>
      {period === "week" && (
        <>
          <label className="grid gap-1 text-xs font-semibold">
            Mal pro Woche
            <input name="times" type="number" min={1} max={7} required defaultValue={item.freq_times ?? 1} className={field} />
          </label>
          <fieldset className="flex flex-wrap gap-2 text-xs">
            <legend className="font-semibold">Wochentage (optional, sonst gleichmässig verteilt)</legend>
            {WEEKDAYS.map((d) => (
              <label key={d.iso} className="flex items-center gap-1">
                <input type="checkbox" name="weekday" value={d.iso} defaultChecked={item.freq_weekdays?.includes(d.iso) ?? false} /> {d.short}
              </label>
            ))}
          </fieldset>
        </>
      )}
      <div className="grid grid-cols-2 gap-2">
        <label className="grid gap-1 text-xs font-semibold">Von<input name="start" type="time" required defaultValue={item.window_start?.slice(0, 5) ?? ""} className={field} /></label>
        <label className="grid gap-1 text-xs font-semibold">Bis<input name="end" type="time" required defaultValue={item.window_end?.slice(0, 5) ?? ""} className={field} /></label>
      </div>
      <div className="flex flex-wrap gap-2">
        <button type="submit" disabled={pending} className="min-h-11 rounded-lg bg-emerald-800 px-3 font-bold text-white disabled:opacity-60">Rhythmus speichern</button>
        {item.freq_period && (
          <button type="button" disabled={pending} className="min-h-11 rounded-lg border border-stone-400 px-3 font-semibold"
            onClick={() => onSubmit({ period: null, times: null, weekdays: null, windowStart: null, windowEnd: null })}>
            Nicht mehr automatisch planen
          </button>
        )}
        <button type="button" onClick={onCancel} className="min-h-11 rounded-lg border border-stone-300 px-3 font-semibold">Abbrechen</button>
      </div>
    </form>
  );
}
