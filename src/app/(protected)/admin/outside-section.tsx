"use client";

import { useState, useTransition } from "react";
import { setOutsidePush, setWatchedHours } from "@/features/push/commands";
import type { AdminPush } from "@/features/push/queries";
import { ADMIN_PUSH_MESSAGES, NO_WATCHED_HOURS, OUTSIDE_LABEL, WATCHED_HOURS_HELP, WEEKDAYS, formatWatchedDay, parseWatchedDay, type WatchedPeriod } from "@/features/push/rules";

const field = "min-h-10 rounded-lg border border-stone-300 bg-white px-2 text-sm";
const secondary = "min-h-10 rounded-lg border border-stone-400 bg-white px-3 text-sm font-semibold disabled:opacity-60";

// SIG2-3: the channel (off by default; only with a recorded DPF entry). SIG2-6: watched hours per weekday.
export default function OutsideDelivery({ organizationId, push }: { organizationId: string; push: AdminPush }) {
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const released = push.vendors.filter((v) => v.dpf_swiss_status === "active" && v.dpf_read_on);

  const run = (call: () => Promise<{ ok: boolean; error?: string }>) => start(async () => {
    setError(null);
    setNotice(null);
    const r = await call();
    if (r.ok) setNotice("Gespeichert.");
    else setError(r.error ?? ADMIN_PUSH_MESSAGES.failed);
  });

  return (
    <section aria-label={OUTSIDE_LABEL} className="grid gap-3 rounded-2xl border border-stone-200 bg-white p-5">
      <h3 className="text-lg font-bold">{OUTSIDE_LABEL} und überwachte Zeiten</h3>
      <p className="text-xs text-stone-600">
        Eine feste Nachricht ohne Klientendaten an Mitglieder, die eingeschaltet haben (Web-Push über Google oder Microsoft).
        Bis zur Freigabe durch die Clinical Owner bleibt die Bedingung SIG1-8 bestehen: jemand beobachtet die Signale in jeder geplanten Stunde.
      </p>
      <ul className="grid gap-1 text-sm" aria-label="Anbieter">
        {push.vendors.map((v) => (
          <li key={v.vendor} data-testid="push-vendor">
            {v.legal_entity}, {v.country}: {v.dpf_swiss_status === "active" && v.dpf_read_on
              ? `Swiss-U.S. DPF aktiv (gelesen am ${v.dpf_read_on})`
              : "DPF-Eintrag nicht erfasst – nicht freigegeben"}
          </li>
        ))}
      </ul>
      <div className="flex flex-wrap items-center gap-2 text-sm">
        <span data-testid="push-channel" className="font-semibold">{push.enabled ? "Eingeschaltet" : "Ausgeschaltet"}</span>
        <button type="button" className={secondary} disabled={pending || (!push.enabled && released.length === 0)}
          onClick={() => run(() => setOutsidePush({ organizationId, enabled: !push.enabled, idempotencyKey: crypto.randomUUID() }))}>
          {push.enabled ? "Ausschalten" : "Einschalten"}
        </button>
        {!push.enabled && released.length === 0 && <span className="text-xs text-stone-600">{ADMIN_PUSH_MESSAGES.vendors_unverified}</span>}
      </div>

      <form className="grid gap-2 text-sm" aria-label="Überwachte Zeiten" onSubmit={(e) => {
        e.preventDefault();
        const f = new FormData(e.currentTarget);
        const hours: WatchedPeriod[] = [];
        for (let d = 1; d <= 7; d++) {
          const parsed = parseWatchedDay(d, String(f.get(`day${d}`) ?? ""));
          if (parsed === null) return setError(`${WEEKDAYS[d - 1]}: ${ADMIN_PUSH_MESSAGES.invalid}`);
          hours.push(...parsed);
        }
        run(() => setWatchedHours({ organizationId, hours, idempotencyKey: crypto.randomUUID() }));
      }}>
        <p className="text-xs text-stone-600">{WATCHED_HOURS_HELP}</p>
        {push.hours.length === 0 && <p data-testid="no-watched-hours" className="rounded-lg border border-amber-300 bg-amber-50 p-2 text-sm">{NO_WATCHED_HOURS}</p>}
        <div className="grid grid-cols-[3rem_1fr] items-center gap-2">
          {WEEKDAYS.map((label, i) => (
            <label key={label} className="contents">
              <span className="font-semibold">{label}</span>
              <input name={`day${i + 1}`} aria-label={`Überwachte Zeiten ${label}`} className={field}
                defaultValue={formatWatchedDay(push.hours.filter((h) => h.weekday === i + 1))} placeholder="07:00-20:00" />
            </label>
          ))}
        </div>
        <button type="submit" className={`${secondary} justify-self-start`} disabled={pending}>Zeiten speichern</button>
      </form>
      {error && <p role="alert" data-testid="command-error" className="font-semibold text-rose-800">{error}</p>}
      {notice && <p role="status" className="text-sm text-emerald-900">{notice}</p>}
    </section>
  );
}
