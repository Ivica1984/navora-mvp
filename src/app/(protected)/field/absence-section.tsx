"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { changeAbsence, recordAbsence, takeOpenVisit } from "@/features/absence/commands";
import type { OpenVisit, TeamAbsence, TeamColleague } from "@/features/absence/queries";
import { absenceMemberLabel, earliestAbsenceStart, formatAbsencePeriod, knownByLabel, pastPlannedNotice } from "@/features/absence/rules";
import { offerMinutes } from "@/features/cover/rules";
import { earliestTakeableToday, formatDayLabel, formatTime } from "@/features/field/rules";

function useAbsenceRun() {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  async function run<R extends { ok: boolean; error?: string }>(fn: () => Promise<R>): Promise<R> {
    setPending(true);
    setError(null);
    const result = await fn();
    setPending(false);
    if (!result.ok) setError(result.error ?? null);
    router.refresh();
    return result;
  }
  return { pending, error, run };
}

/**
 * ABS1 on /field: "Ich kann nicht arbeiten" in two taps (open, save; defaults: me, today, whole day), for a colleague of
 * the same team too. No reason field and no free text: NAVORA stores no reason for an absence.
 * ABS1-C6 (PO 2026-10-23 21:17): the start may be today or yesterday ("krank seit gestern"), no earlier. When the new
 * absence covers planned visits before today (`past_planned`, CGR-32), the confirmation names their number and links
 * to /team, where the team decides; they are not released.
 * UX1-6a (ADR-104): a compact outline control in the /field header (first viewport, two taps from the top); the form
 * opens over the page, so the next visit stays first on the page.
 */
export function AbsenceControl({ today, colleagues }: { today: string; colleagues: TeamColleague[] }) {
  const [open, setOpen] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const { pending, error, run } = useAbsenceRun();
  const earliest = earliestAbsenceStart(today);
  if (colleagues.length === 0) return null;
  const close = () => { setOpen(false); setNotice(null); };

  return (
    <div data-testid="absence">
      <button type="button" onClick={() => { setNotice(null); setOpen(true); }} data-testid="absence-open"
        className="min-h-11 shrink-0 rounded-lg border border-white/80 px-3 text-sm font-semibold text-white">
        Ich kann nicht arbeiten
      </button>
      {open && (
        <div role="dialog" aria-modal="true" aria-label="Abwesenheit" className="fixed inset-0 z-40 overflow-y-auto bg-black/50 p-4">
          <div className="mx-auto mt-16 grid max-w-xl gap-2 rounded-2xl border-l-4 border-sky-700 bg-sky-50 p-3 text-sm text-stone-900">
            {notice === null ? (
              <form aria-label="Abwesenheit erfassen" className="grid gap-2" onSubmit={(e) => {
                e.preventDefault();
                const f = new FormData(e.currentTarget);
                const [teamId, userId] = String(f.get("who") ?? "").split("|");
                const me = colleagues.find((c) => c.teamId === teamId && c.userId === userId)?.isMe ?? false;
                const v = (k: string) => (String(f.get(k) ?? "").trim() || null);
                void run(() => recordAbsence({
                  teamId, userId: me ? null : userId, from: v("from"), until: v("until"),
                  fromTime: v("fromTime"), untilTime: v("untilTime"), idempotencyKey: crypto.randomUUID(),
                })).then((r) => {
                  if (!r.ok) return;
                  const text = pastPlannedNotice(r.pastPlanned);
                  if (text) setNotice(text);
                  else close();
                });
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
                    <input type="date" name="from" defaultValue={today} min={earliest} className="min-h-11 rounded-lg border border-stone-300 bg-white px-2" /></label>
                  <label className="grid gap-1"><span>Bis</span>
                    <input type="date" name="until" defaultValue={today} min={today} className="min-h-11 rounded-lg border border-stone-300 bg-white px-2" /></label>
                  <label className="grid gap-1"><span>ab Uhrzeit (optional)</span>
                    <input type="time" name="fromTime" className="min-h-11 rounded-lg border border-stone-300 bg-white px-2" /></label>
                  <label className="grid gap-1"><span>bis Uhrzeit (optional)</span>
                    <input type="time" name="untilTime" className="min-h-11 rounded-lg border border-stone-300 bg-white px-2" /></label>
                </div>
                <p className="text-xs text-sky-950/80">Kein Grund nötig. Gilt für alle Teams der Person. Die Einsätze in dieser Zeit sind sofort im jeweiligen Team offen; Einsätze, die schon laufen, bleiben, wo sie sind.</p>
                <div className="flex gap-2">
                  <button type="submit" disabled={pending} data-testid="absence-save" className="min-h-11 flex-1 rounded-lg bg-sky-800 font-bold text-white disabled:opacity-60">
                    {pending ? "Wird gespeichert …" : "Speichern"}
                  </button>
                  <button type="button" onClick={close} className="min-h-11 rounded-lg border border-sky-800 px-3 font-semibold">Abbrechen</button>
                </div>
              </form>
            ) : (
              <>
                <p role="status" data-testid="absence-past-planned" className="rounded-lg border border-amber-300 bg-amber-50 p-2 font-semibold text-amber-950">
                  {notice} · <Link href="/team" className="underline">Zum Team</Link>
                </p>
                <button type="button" onClick={close} className="min-h-11 rounded-lg border border-sky-800 px-3 font-semibold">Schliessen</button>
              </>
            )}
            {error && <p role="alert" data-testid="command-error" className="rounded-lg border border-rose-300 bg-rose-50 p-2 font-semibold text-rose-800">{error}</p>}
          </div>
        </div>
      )}
    </div>
  );
}

/**
 * ABS1: the team's current and future absences; the absent member and the colleague who recorded it may withdraw or
 * shorten it. UX1-6 (ADR-104): below her visits of the day, unchanged in content.
 */
export function AbsenceList({ today, absences }: { today: string; absences: TeamAbsence[] }) {
  const { pending, error, run } = useAbsenceRun();
  const mine = absences.filter((a) => a.is_me);
  if (absences.length === 0) return null;

  return (
    <section aria-label="Abwesenheit" data-testid="absence-list" className="mb-4 grid gap-2 rounded-2xl border-l-4 border-sky-700 bg-sky-50 p-3 text-sm">
      {mine.length > 0 && (
        <p data-testid="my-absence" className="font-semibold text-sky-950">
          Du bist abwesend: {mine.map((a) => formatAbsencePeriod(a.starts_at, a.ends_at)).join(", ")}. Deine Einsätze sind im Team offen.
        </p>
      )}
      {error && <p role="alert" data-testid="command-error" className="rounded-lg border border-rose-300 bg-rose-50 p-2 font-semibold text-rose-800">{error}</p>}
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
    </section>
  );
}

/**
 * ABS1 "Offen im Team": every planned visit of the team with nobody responsible (absence, removal, qualification
 * change, a plan without deputy, planned by hand). One tap to take, first wins. "kennt die Klientin" is a label,
 * not an assignment. A care assistant is not offered category B or needs-assessment visits.
 */
export function OpenVisitsSection({ open, today }: { open: OpenVisit[]; today: string }) {
  const router = useRouter();
  const [pending, setPending] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [expanded, setExpanded] = useState(false);
  if (open.length === 0) return null;
  // UX1-6a: while collapsed, the earliest visit of today she may take stays one tap away in the header.
  const first = expanded ? null : earliestTakeableToday(open, today);

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
      <div className="flex items-center justify-between gap-2">
        <h2 className="font-bold text-orange-950">Offen im Team ({open.length})</h2>
        <button type="button" aria-expanded={expanded} aria-controls="offen-im-team-liste" data-testid="open-in-team-toggle"
          onClick={() => setExpanded((x) => !x)} className="min-h-11 rounded-lg border border-orange-700 bg-white px-3 font-semibold text-orange-950">
          {expanded ? "Weniger anzeigen" : "Alle anzeigen"}
        </button>
      </div>
      {error && <p role="alert" data-testid="command-error" className="rounded-lg border border-rose-300 bg-rose-50 p-2 font-semibold text-rose-800">{error}</p>}
      {first && (
        <div data-testid="open-visit-next" className="flex items-center justify-between gap-2 rounded-xl bg-white p-2">
          <p className="font-semibold">
            Heute · {formatTime(first.time_start) ?? "Zeit offen"}{first.time_end ? `–${formatTime(first.time_end)}` : ""} · {first.client_name ?? "Klient:in"}
          </p>
          <button type="button" disabled={pending !== null} onClick={() => take(first.visit_id)}
            className="min-h-11 shrink-0 rounded-lg bg-orange-700 px-3 font-bold text-white disabled:opacity-60">
            {pending === first.visit_id ? "Wird gespeichert …" : "Übernehmen"}
          </button>
        </div>
      )}
      {expanded && (
      <ul id="offen-im-team-liste" className="grid gap-2" aria-label="Offene Einsätze">
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
      )}
    </section>
  );
}
