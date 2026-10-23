"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { changeAbsence, recordAbsence, takeOpenVisit } from "@/features/absence/commands";
import type { OpenVisit, TeamAbsence, TeamColleague } from "@/features/absence/queries";
import { absenceMemberLabel, formatAbsencePeriod, knownByLabel } from "@/features/absence/rules";
import { offerMinutes } from "@/features/cover/rules";
import { formatDayLabel, formatTime } from "@/features/field/rules";

/**
 * ABS1 on /field, at the top: "Ich kann nicht arbeiten" in two taps (open, save; defaults: me, today, whole day),
 * for a colleague of the same team too. No reason field and no free text: NAVORA stores no reason for an absence.
 * Shows the team's current and future absences; the absent member and the colleague who recorded it may withdraw
 * or shorten it.
 */
export function AbsenceSection({ today, absences, colleagues }: { today: string; absences: TeamAbsence[]; colleagues: TeamColleague[] }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const mine = absences.filter((a) => a.is_me);
  if (colleagues.length === 0 && absences.length === 0) return null;

  async function run(fn: () => Promise<{ ok: boolean; error?: string }>) {
    setPending(true);
    setError(null);
    const result = await fn();
    setPending(false);
    if (!result.ok) setError(result.error ?? null);
    else setOpen(false);
    router.refresh();
  }

  return (
    <section aria-label="Abwesenheit" data-testid="absence" className="mb-4 grid gap-2 rounded-2xl border-l-4 border-sky-700 bg-sky-50 p-3 text-sm">
      {mine.length > 0 && (
        <p data-testid="my-absence" className="font-semibold text-sky-950">
          Du bist abwesend: {mine.map((a) => formatAbsencePeriod(a.starts_at, a.ends_at)).join(", ")}. Deine Einsätze sind im Team offen.
        </p>
      )}
      {!open ? (
        <button type="button" onClick={() => setOpen(true)} data-testid="absence-open"
          className="min-h-11 rounded-lg bg-sky-800 px-3 font-bold text-white">
          Ich kann nicht arbeiten
        </button>
      ) : (
        <form aria-label="Abwesenheit erfassen" className="grid gap-2" onSubmit={(e) => {
          e.preventDefault();
          const f = new FormData(e.currentTarget);
          const [teamId, userId] = String(f.get("who") ?? "").split("|");
          const me = colleagues.find((c) => c.teamId === teamId && c.userId === userId)?.isMe ?? false;
          const v = (k: string) => (String(f.get(k) ?? "").trim() || null);
          void run(() => recordAbsence({
            teamId, userId: me ? null : userId, from: v("from"), until: v("until"),
            fromTime: v("fromTime"), untilTime: v("untilTime"), idempotencyKey: crypto.randomUUID(),
          }));
        }}>
          <label className="grid gap-1">
            <span className="font-semibold">Wer</span>
            <select name="who" className="min-h-11 rounded-lg border border-stone-300 bg-white px-2" defaultValue={colleagues[0] ? `${colleagues[0].teamId}|${colleagues[0].userId}` : ""}>
              {colleagues.map((c) => (
                <option key={`${c.teamId}|${c.userId}`} value={`${c.teamId}|${c.userId}`}>{c.name} · {c.teamName}</option>
              ))}
            </select>
          </label>
          <div className="grid grid-cols-2 gap-2">
            <label className="grid gap-1"><span>Von</span>
              <input type="date" name="from" defaultValue={today} min={today} className="min-h-11 rounded-lg border border-stone-300 bg-white px-2" /></label>
            <label className="grid gap-1"><span>Bis</span>
              <input type="date" name="until" defaultValue={today} min={today} className="min-h-11 rounded-lg border border-stone-300 bg-white px-2" /></label>
            <label className="grid gap-1"><span>ab Uhrzeit (optional)</span>
              <input type="time" name="fromTime" className="min-h-11 rounded-lg border border-stone-300 bg-white px-2" /></label>
            <label className="grid gap-1"><span>bis Uhrzeit (optional)</span>
              <input type="time" name="untilTime" className="min-h-11 rounded-lg border border-stone-300 bg-white px-2" /></label>
          </div>
          <p className="text-xs text-sky-950/80">Kein Grund nötig. Die Einsätze in dieser Zeit sind sofort im Team offen; Einsätze, die schon laufen, bleiben bei dir.</p>
          <div className="flex gap-2">
            <button type="submit" disabled={pending} data-testid="absence-save" className="min-h-11 flex-1 rounded-lg bg-sky-800 font-bold text-white disabled:opacity-60">
              {pending ? "Wird gespeichert …" : "Speichern"}
            </button>
            <button type="button" onClick={() => setOpen(false)} className="min-h-11 rounded-lg border border-sky-800 px-3 font-semibold">Abbrechen</button>
          </div>
        </form>
      )}
      {error && <p role="alert" data-testid="command-error" className="rounded-lg border border-rose-300 bg-rose-50 p-2 font-semibold text-rose-800">{error}</p>}
      {absences.length > 0 && (
        <ul aria-label="Abwesend im Team" className="grid gap-1">
          {absences.map((a) => (
            <li key={a.absence_id} className="grid gap-1 rounded-xl bg-white p-2">
              <span><strong>{absenceMemberLabel(a.member)}</strong> · {formatAbsencePeriod(a.starts_at, a.ends_at)}{!a.is_me && a.recorded_by_me ? " · von dir erfasst" : ""}{a.is_me && !a.recorded_by_me ? " · von einer Kollegin erfasst" : ""}</span>
              {a.may_change && (
                <form aria-label="Abwesenheit ändern" className="flex flex-wrap gap-2" onSubmit={(e) => {
                  e.preventDefault();
                  const f = new FormData(e.currentTarget);
                  const until = String(f.get("until") ?? "").trim() || null;
                  const untilTime = String(f.get("untilTime") ?? "").trim() || null;
                  void run(() => changeAbsence({ absenceId: a.absence_id, withdraw: false, until, untilTime, idempotencyKey: crypto.randomUUID() }));
                }}>
                  <input type="date" name="until" required min={today} aria-label="Neues Ende" className="min-h-11 rounded-lg border border-stone-300 bg-white px-2" />
                  <input type="time" name="untilTime" aria-label="Neues Ende Uhrzeit (optional)" className="min-h-11 rounded-lg border border-stone-300 bg-white px-2" />
                  <button type="submit" disabled={pending} className="min-h-11 rounded-lg border border-sky-800 px-3 font-semibold">Verkürzen</button>
                  <button type="button" disabled={pending} className="min-h-11 rounded-lg border border-sky-800 px-3 font-semibold"
                    onClick={() => void run(() => changeAbsence({ absenceId: a.absence_id, withdraw: true, until: null, untilTime: null, idempotencyKey: crypto.randomUUID() }))}>
                    Zurückziehen
                  </button>
                </form>
              )}
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

/**
 * ABS1 "Offen im Team": every planned visit of the team with nobody responsible (absence, removal, qualification
 * change, a plan without deputy, planned by hand). One tap to take, first wins. "kennt die Klientin" is a label,
 * not an assignment. A care assistant is not offered category B or needs-assessment visits.
 */
export function OpenVisitsSection({ open }: { open: OpenVisit[] }) {
  const router = useRouter();
  const [pending, setPending] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  if (open.length === 0) return null;

  async function take(visitId: string) {
    setPending(visitId);
    setError(null);
    const result = await takeOpenVisit({ visitId, idempotencyKey: crypto.randomUUID() });
    setPending(null);
    if (!result.ok) setError(result.error);
    router.refresh();
  }

  return (
    <section aria-label="Offen im Team" data-testid="open-in-team" className="mb-4 grid gap-2 rounded-2xl border-l-4 border-orange-600 bg-orange-50 p-3 text-sm">
      <h2 className="font-bold text-orange-950">Offen im Team ({open.length})</h2>
      {error && <p role="alert" data-testid="command-error" className="rounded-lg border border-rose-300 bg-rose-50 p-2 font-semibold text-rose-800">{error}</p>}
      <ul className="grid gap-2" aria-label="Offene Einsätze">
        {open.map((o) => {
          const known = knownByLabel(o.known_by);
          return (
            <li key={o.visit_id} className="grid gap-1 rounded-xl bg-white p-2" data-testid="open-visit">
              <p className="font-semibold">
                {formatDayLabel(o.visit_date)} · {formatTime(o.time_start) ?? "Zeit offen"}{o.time_end ? `–${formatTime(o.time_end)}` : ""}
              </p>
              <p>{o.client_name ?? "Klient:in"} · Team {o.team_name} · {o.services_provided?.join(", ") || "–"} · {offerMinutes(o.planned_minutes_a, o.planned_minutes_b, o.planned_minutes_c)}{o.is_needs_assessment ? " · Bedarfsabklärung" : ""}</p>
              {known && <p className="text-xs font-semibold text-emerald-800">{known}</p>}
              {o.overlaps_my_visit && (
                <p className="text-xs font-semibold text-amber-800">überschneidet sich mit deinem Einsatz {formatTime(o.overlaps_my_visit)}</p>
              )}
              {o.may_take ? (
                <button type="button" disabled={pending !== null} onClick={() => take(o.visit_id)}
                  className="min-h-11 rounded-lg bg-orange-700 font-bold text-white disabled:opacity-60">
                  {pending === o.visit_id ? "Wird gespeichert …" : "Übernehmen"}
                </button>
              ) : (
                <p className="text-xs text-stone-600">Nur für eine Pflegefachperson, oder du bist zu dieser Zeit abwesend.</p>
              )}
            </li>
          );
        })}
      </ul>
    </section>
  );
}
