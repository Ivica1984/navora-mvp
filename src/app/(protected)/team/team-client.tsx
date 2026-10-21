"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { addCarePlanItem, decideMatchingRequest, planVisit, removePlannedVisit, rescheduleVisit, retireCarePlanItem } from "@/features/team/commands";
import {
  DECLINE_REASONS,
  DECLINE_REASON_LABEL,
  PLAN_FLAG_LABEL,
  QUALIFICATION_LABEL,
  declineError,
  formatMinutesByCategory,
  formatResponseDue,
  formatWeeklyHours,
  minutesFromForm,
} from "@/features/team/rules";
import { MEDICAL_ORDER_LABEL, TASK_LABEL } from "@/features/intake/rules";
import type { TeamCase, TeamOffer } from "@/features/team/queries";
import { formatDayLabel, shiftDay, todayInZurich } from "@/features/field/rules";
import { getVisitStatusLabel } from "@/features/visits/types";

const URGENCY_CLASS: Record<string, string> = {
  hoch: "bg-rose-100 text-rose-900",
  mittel: "bg-amber-100 text-amber-900",
  niedrig: "bg-stone-200 text-stone-800",
};

function hoursSince(iso: string) {
  return Math.max(0, Math.floor((Date.now() - Date.parse(iso)) / 3_600_000));
}

export default function TeamClient({ offers, cases }: { offers: TeamOffer[]; cases: TeamCase[] }) {
  const open = offers.filter((o) => !o.my_team_declined);
  const declined = offers.filter((o) => o.my_team_declined);

  return (
    <div className="min-h-screen bg-stone-100 text-emerald-950">
      <header className="bg-emerald-950 px-4 pb-4 pt-3 text-white">
        <div className="mx-auto flex max-w-xl items-center justify-between">
          <p className="text-xs font-semibold uppercase tracking-widest text-emerald-200">NAVORA · Team</p>
          <Link href="/field" className="flex min-h-11 items-center rounded-lg px-3 text-sm font-semibold underline underline-offset-4">
            Mein Tag
          </Link>
        </div>
        <h1 className="mx-auto mt-1 max-w-xl text-xl font-bold">Dein Team</h1>
        <p className="mx-auto max-w-xl text-sm text-emerald-100">
          Ihr entscheidet selbst, welche Klientinnen und Klienten ihr übernehmt. Der erste Zusage-Entscheid eines Teams gilt.
        </p>
      </header>

      <main className="mx-auto grid max-w-xl gap-3 px-4 py-4">
        <h2 className="text-lg font-bold">Anfragen an dein Team</h2>
        {open.length === 0 && (
          <p className="rounded-2xl border border-dashed border-emerald-900/20 bg-white/70 p-6 text-center">
            Keine offenen Anfragen für deine Teams.
          </p>
        )}
        <ul className="grid gap-3" aria-label="Offene Anfragen">
          {open.map((offer) => (
            <li key={`${offer.matching_request_id}-${offer.team_id}`}>
              <OfferCard offer={offer} />
            </li>
          ))}
        </ul>

        {declined.length > 0 && (
          <section aria-label="Abgelehnt" className="mt-4 grid gap-2">
            <h2 className="text-sm font-bold uppercase tracking-wide text-emerald-900/60">Von deinem Team abgelehnt</h2>
            {declined.map((o) => (
              <p key={`${o.matching_request_id}-${o.team_id}`} className="rounded-xl bg-white/60 p-3 text-sm">
                {o.request_title} · {o.region}
              </p>
            ))}
          </section>
        )}

        <section aria-label="Unsere Klientinnen und Klienten" className="mt-6 grid gap-3">
          <h2 className="text-lg font-bold">Unsere Klientinnen und Klienten</h2>
          {cases.length === 0 && (
            <p className="rounded-2xl border border-dashed border-emerald-900/20 bg-white/70 p-6 text-center">
              Dein Team betreut noch keine Fälle.
            </p>
          )}
          <ul className="grid gap-3">
            {cases.map((c) => (
              <li key={`${c.case_id}-${c.team_id}`}>
                <CaseCard teamCase={c} />
              </li>
            ))}
          </ul>
        </section>

        <p className="mt-4 text-xs leading-relaxed text-emerald-900/60">
          Angeboten werden Anfragen aus der Region deines aktiven Teams. Kompetenzen, Qualifikationen, Kapazität und
          Sicherheitsvorbehalte werden noch nicht automatisch geprüft – bitte im Team beurteilen. Namen und Kontaktdaten
          sind erst nach der Zusage sichtbar.
        </p>
      </main>
    </div>
  );
}

function OfferCard({ offer }: { offer: TeamOffer }) {
  const router = useRouter();
  const [pending, setPending] = useState<"accept" | "decline" | null>(null);
  const [declining, setDeclining] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [reason, setReason] = useState("");
  const [reasonCode, setReasonCode] = useState("");

  async function decide(decision: "accept" | "decline") {
    if (decision === "decline") {
      const problem = declineError(reasonCode, reason);
      if (problem) {
        setError(problem);
        return;
      }
    }
    setPending(decision);
    setError(null);
    const result = await decideMatchingRequest({
      requestId: offer.matching_request_id,
      teamId: offer.team_id,
      decision,
      reason: decision === "decline" ? reason : "",
      reasonCode: decision === "decline" ? reasonCode : null,
      idempotencyKey: crypto.randomUUID(),
    });
    setPending(null);
    if (!result.ok) setError(result.error);
    router.refresh();
  }

  return (
    <article aria-label={`Anfrage ${offer.request_title}`} className="rounded-2xl bg-white p-4 shadow-sm">
      <div className="flex items-start justify-between gap-3">
        <div>
          <h2 className="font-bold">{offer.request_title}</h2>
          <p className="text-sm text-emerald-900/70">
            {offer.region} · für {offer.team_name} · seit {hoursSince(offer.created_at)} h offen
          </p>
        </div>
        <span className={`shrink-0 rounded-full px-3 py-1 text-xs font-bold ${URGENCY_CLASS[offer.urgency] ?? "bg-stone-200"}`}>
          {offer.urgency}
        </span>
      </div>
      <p className="mt-2 text-sm">
        Leistungen: {offer.required_services?.length ? offer.required_services.join(", ") : "nicht angegeben"}
      </p>
      <dl className="mt-2 grid grid-cols-[9rem_1fr] gap-x-2 gap-y-0.5 text-sm" aria-label="Eckdaten">
        <dt className="text-emerald-900/60">Beginn</dt>
        <dd>{offer.requested_start ? formatDayLabel(offer.requested_start) : "nicht erfasst"}</dd>
        <dt className="text-emerald-900/60">Umfang</dt>
        <dd>{formatWeeklyHours(offer.expected_hours_per_week)}</dd>
        <dt className="text-emerald-900/60">Qualifikation</dt>
        <dd>
          {offer.required_qualification
            ? `${QUALIFICATION_LABEL[offer.required_qualification] ?? offer.required_qualification} nötig`
            : "keine besondere"}
        </dd>
        <dt className="text-emerald-900/60">Antwortfrist</dt>
        <dd data-testid="response-due">{formatResponseDue(offer.response_due_at)}</dd>
      </dl>
      <ul className="mt-2 grid gap-0.5 text-xs" aria-label="Prüfkriterien">
        <li>✓ Aktives Team · ✓ Region · ✓ Qualifikation</li>
        <li className="text-amber-800">○ Kompetenz, Kapazität, Sicherheitsvorbehalte: nicht automatisch geprüft</li>
      </ul>

      {error && (
        <p role="alert" data-testid="command-error" className="mt-3 rounded-lg border border-rose-300 bg-rose-50 p-3 text-sm font-semibold text-rose-800">
          {error}
        </p>
      )}

      {!declining ? (
        <div className="mt-4 grid grid-cols-[2fr_1fr] gap-2">
          <button
            type="button"
            onClick={() => decide("accept")}
            disabled={pending !== null}
            className="min-h-12 rounded-xl bg-emerald-800 font-bold text-white disabled:opacity-60"
          >
            {pending === "accept" ? "Wird gespeichert …" : "Fall übernehmen"}
          </button>
          <button
            type="button"
            onClick={() => setDeclining(true)}
            disabled={pending !== null}
            className="min-h-12 rounded-xl border-2 border-emerald-800 font-bold text-emerald-900"
          >
            Ablehnen
          </button>
        </div>
      ) : (
        <div className="mt-3 grid gap-2">
          <label className="grid gap-1 text-sm">
            <span className="font-semibold">Grund der Ablehnung</span>
            <select
              value={reasonCode}
              onChange={(e) => setReasonCode(e.target.value)}
              className="min-h-11 rounded-lg border border-stone-300 bg-white px-3"
            >
              <option value="">– bitte wählen –</option>
              {DECLINE_REASONS.map((code) => (
                <option key={code} value={code}>{DECLINE_REASON_LABEL[code]}</option>
              ))}
            </select>
          </label>
          <label className="grid gap-1 text-sm">
            <span className="font-semibold">Bemerkung {reasonCode === "other" ? "(nötig)" : "(optional)"}</span>
            <input
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              maxLength={500}
              className="min-h-11 rounded-lg border border-stone-300 bg-white px-3"
            />
          </label>
          <div className="grid grid-cols-2 gap-2">
            <button
              type="button"
              onClick={() => decide("decline")}
              disabled={pending !== null}
              className="min-h-11 rounded-xl bg-stone-700 font-bold text-white disabled:opacity-60"
            >
              {pending === "decline" ? "Wird gespeichert …" : "Ablehnung speichern"}
            </button>
            <button type="button" onClick={() => setDeclining(false)} className="min-h-11 rounded-xl border border-stone-300 font-semibold">
              Abbrechen
            </button>
          </div>
        </div>
      )}
    </article>
  );
}

type Upcoming = {
  visit_id: string;
  date: string;
  start: string | null;
  end: string | null;
  status: string | null;
  a: number | null;
  b: number | null;
  c: number | null;
  needs_assessment: boolean;
  responsible_me: boolean;
  responsible_set: boolean;
  flags: string[] | null;
  last_change: { change: string; reason: string | null; own: boolean } | null;
};
type PlanItem = { id: string; service: string; category: string; minutes: number; frequency: string; review_date: string; goal?: string | null };
type Member = { user_id: string; qualification: string | null; me: boolean };

function arr<T>(raw: unknown, key: string): T[] {
  return Array.isArray(raw) ? raw.filter((v): v is T => typeof v === "object" && v !== null && key in v) : [];
}

const hhmm = (t: string | null) => (t ? t.slice(0, 5) : "–");
const field = "min-h-11 rounded-lg border border-stone-300 bg-white px-2";

function SlotFields({ date, start, end }: { date: string; start: string; end: string }) {
  return (
    <div className="grid grid-cols-3 gap-2">
      <label className="grid gap-1 text-xs font-semibold">
        Datum
        <input name="date" type="date" required defaultValue={date} className={field} />
      </label>
      <label className="grid gap-1 text-xs font-semibold">
        Von
        <input name="start" type="time" required defaultValue={start} className={field} />
      </label>
      <label className="grid gap-1 text-xs font-semibold">
        Bis
        <input name="end" type="time" required defaultValue={end} className={field} />
      </label>
    </div>
  );
}

function Flags({ flags }: { flags: string[] | null | undefined }) {
  if (!flags || flags.length === 0) return null;
  return (
    <ul aria-label="Hinweise" className="mt-1 grid gap-0.5 text-xs font-semibold text-amber-800">
      {flags.map((f) => (
        <li key={f}>⚠ {PLAN_FLAG_LABEL[f] ?? f}</li>
      ))}
    </ul>
  );
}

function ErrorText({ message }: { message: string | null }) {
  if (!message) return null;
  return (
    <p role="alert" data-testid="command-error" className="mt-2 rounded-lg border border-rose-300 bg-rose-50 p-2 text-sm font-semibold text-rose-800">
      {message}
    </p>
  );
}

function CaseCard({ teamCase }: { teamCase: TeamCase }) {
  const upcoming = arr<Upcoming>(teamCase.upcoming, "visit_id");
  const plan = arr<PlanItem>(teamCase.care_plan, "category");
  const members = arr<Member>(teamCase.members, "user_id");
  const needs = teamCase.care_needs ?? [];
  const order = teamCase.medical_order_status as keyof typeof MEDICAL_ORDER_LABEL | null;

  return (
    <article aria-label={`Fall ${teamCase.client_name ?? ""}`} className="rounded-2xl bg-white p-4 shadow-sm">
      <h3 className="font-bold">{teamCase.client_name ?? "Klient:in"}</h3>
      <p className="text-sm text-emerald-900/70">
        {teamCase.region} · {teamCase.team_name}
        {needs.length > 0 ? ` · ${needs.join(", ")}` : ""}
      </p>
      <p className="mt-1 text-xs text-emerald-900/70">
        Verordnung: {order ? MEDICAL_ORDER_LABEL[order] ?? order : "nicht erfasst"}
        {teamCase.medical_order_valid_until ? ` (gültig bis ${teamCase.medical_order_valid_until})` : ""}
        {" · "}
        {teamCase.needs_assessment_done ? "Bedarfsabklärung erfolgt" : "Bedarfsabklärung ausstehend"}
      </p>
      {teamCase.open_tasks.length > 0 && (
        <ul aria-label="Offene Aufgaben" className="mt-2 grid gap-0.5 text-sm">
          {teamCase.open_tasks.map((t) => (
            <li key={t}>☐ {TASK_LABEL[t] ?? t}</li>
          ))}
        </ul>
      )}

      <CarePlan caseId={teamCase.case_id} items={plan} />

      <h4 className="mt-3 text-xs font-bold uppercase tracking-wide text-emerald-900/60">Geplante Einsätze</h4>
      {upcoming.length === 0 ? (
        <p className="text-sm italic text-emerald-900/60">Noch keine Einsätze geplant.</p>
      ) : (
        <ul className="mt-1 grid gap-2" aria-label="Geplante Einsätze">
          {upcoming.map((v) => (
            <li key={v.visit_id}>
              <PlannedVisit visit={v} />
            </li>
          ))}
        </ul>
      )}

      <PlanForm caseId={teamCase.case_id} assessmentDone={teamCase.needs_assessment_done} members={members} />
    </article>
  );
}

function CarePlan({ caseId, items }: { caseId: string; items: PlanItem[] }) {
  const router = useRouter();
  const [adding, setAdding] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  async function add(form: FormData) {
    setPending(true);
    setError(null);
    const result = await addCarePlanItem({
      caseId,
      service: String(form.get("service") ?? ""),
      category: String(form.get("category") ?? ""),
      minutes: Number.parseInt(String(form.get("minutes") ?? ""), 10),
      frequency: String(form.get("frequency") ?? ""),
      reviewDate: String(form.get("review_date") ?? ""),
      goal: String(form.get("goal") ?? ""),
      idempotencyKey: crypto.randomUUID(),
    });
    setPending(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setAdding(false);
    router.refresh();
  }

  const [retiring, setRetiring] = useState<string | null>(null);

  async function retire(form: FormData) {
    if (!retiring) return;
    setPending(true);
    setError(null);
    const result = await retireCarePlanItem({ itemId: retiring, reason: String(form.get("reason") ?? ""), idempotencyKey: crypto.randomUUID() });
    setPending(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setRetiring(null);
    router.refresh();
  }

  return (
    <section aria-label="Pflegeplan" className="mt-3 rounded-xl bg-stone-50 p-2 text-sm">
      <h4 className="text-xs font-bold uppercase tracking-wide text-emerald-900/60">Pflegeplan (Leistungen nach KLV)</h4>
      {items.length === 0 ? (
        <p className="italic text-emerald-900/60">Noch keine Leistungen erfasst.</p>
      ) : (
        <ul className="mt-1 grid gap-1">
          {items.map((i) => (
            <li key={i.id} className="flex items-center justify-between gap-2">
              <span>
                <strong>{i.category}</strong> · {i.service} · {i.minutes} min · {i.frequency} · Überprüfung {i.review_date}
                {i.goal && <span className="block text-xs text-emerald-900/70">Ziel: {i.goal}</span>}
              </span>
              <button type="button" onClick={() => setRetiring(i.id)} className="min-h-11 px-2 text-xs font-semibold underline">
                Beenden
              </button>
            </li>
          ))}
        </ul>
      )}
      {retiring && (
        <form action={retire} aria-label="Leistung beenden" className="mt-2 grid grid-cols-[2fr_1fr_1fr] items-end gap-2">
          <label className="grid gap-1 text-xs font-semibold">
            Grund für das Beenden
            <input name="reason" required minLength={3} maxLength={300} className={field} />
          </label>
          <button type="submit" disabled={pending} className="min-h-11 rounded-lg bg-rose-800 font-bold text-white disabled:opacity-60">
            Beenden
          </button>
          <button type="button" onClick={() => setRetiring(null)} className="min-h-11 rounded-lg border border-stone-300 font-semibold">
            Abbrechen
          </button>
        </form>
      )}
      <ErrorText message={error} />
      {!adding ? (
        <button type="button" onClick={() => setAdding(true)} className="mt-1 min-h-11 px-2 font-semibold underline">
          Leistung hinzufügen
        </button>
      ) : (
        <form action={add} aria-label="Leistung hinzufügen" className="mt-2 grid gap-2">
          <div className="grid grid-cols-[2fr_1fr] gap-2">
            <label className="grid gap-1 text-xs font-semibold">
              Leistung
              <input name="service" required minLength={2} maxLength={120} className={field} />
            </label>
            <label className="grid gap-1 text-xs font-semibold">
              Kategorie
              <select name="category" required defaultValue="" className={field}>
                <option value="" disabled>–</option>
                <option value="A">A – Abklärung/Beratung</option>
                <option value="B">B – Untersuchung/Behandlung</option>
                <option value="C">C – Grundpflege</option>
              </select>
            </label>
            <label className="grid gap-1 text-xs font-semibold">
              Minuten pro Einsatz
              <input name="minutes" type="number" min={1} max={600} required className={field} />
            </label>
            <label className="grid gap-1 text-xs font-semibold">
              Häufigkeit
              <input name="frequency" required maxLength={60} placeholder="z. B. 3x pro Woche" className={field} />
            </label>
            <label className="grid gap-1 text-xs font-semibold">
              Überprüfung am
              <input name="review_date" type="date" required className={field} />
            </label>
            <label className="col-span-2 grid gap-1 text-xs font-semibold">
              Pflegeziel (optional, erscheint auf der Einsatzkarte)
              <input name="goal" maxLength={300} className={field} />
            </label>
          </div>
          <div className="grid grid-cols-2 gap-2">
            <button type="submit" disabled={pending} className="min-h-11 rounded-lg bg-emerald-800 font-bold text-white disabled:opacity-60">
              Leistung speichern
            </button>
            <button type="button" onClick={() => setAdding(false)} className="min-h-11 rounded-lg border border-stone-300 font-semibold">
              Abbrechen
            </button>
          </div>
          <p className="text-xs text-emerald-900/60">
            Die Zuordnung zur KLV-Kategorie trifft das Team; die fachliche Freigabe der Zuordnung ist offen (D-15).
          </p>
        </form>
      )}
    </section>
  );
}

function PlanForm({ caseId, assessmentDone, members }: { caseId: string; assessmentDone: boolean; members: Member[] }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [flags, setFlags] = useState<string[]>([]);

  async function plan(form: FormData) {
    setPending(true);
    setError(null);
    const m = minutesFromForm((k) => String(form.get(k) ?? ""));
    const responsible = String(form.get("responsible") ?? "");
    const result = await planVisit({
      caseId,
      date: String(form.get("date") ?? ""),
      start: String(form.get("start") ?? ""),
      end: String(form.get("end") ?? ""),
      minutesA: m.a,
      minutesB: m.b,
      minutesC: m.c,
      needsAssessment: !assessmentDone,
      responsibleUserId: responsible || null,
      idempotencyKey: crypto.randomUUID(),
    });
    setPending(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setFlags(result.flags);
    setOpen(false);
    router.refresh();
  }

  if (!open) {
    return (
      <>
        <Flags flags={flags} />
        <button type="button" onClick={() => setOpen(true)} className="mt-3 min-h-11 w-full rounded-xl border-2 border-emerald-800 font-bold text-emerald-900">
          {assessmentDone ? "Einsatz planen" : "Abklärungsbesuch planen"}
        </button>
      </>
    );
  }

  return (
    <form action={plan} aria-label="Einsatz planen" className="mt-3 grid gap-2 rounded-xl bg-stone-50 p-3">
      {!assessmentDone && (
        <p className="rounded-lg bg-amber-50 p-2 text-xs font-semibold text-amber-900">
          Erster Einsatz = Bedarfsabklärung durch eine Pflegefachperson (Kategorie A). Bis sie erfolgt ist, sind keine anderen Einsätze planbar.
        </p>
      )}
      <SlotFields date={shiftDay(todayInZurich(), 1)} start="08:00" end="08:45" />
      <fieldset className="grid grid-cols-3 gap-2">
        <legend className="text-xs font-semibold">Geplante Minuten pro KLV-Kategorie</legend>
        <label className="grid gap-1 text-xs font-semibold">
          A
          <input name="minutes_a" type="number" min={0} max={600} defaultValue={assessmentDone ? "" : "45"} className={field} />
        </label>
        <label className="grid gap-1 text-xs font-semibold">
          B
          <input name="minutes_b" type="number" min={0} max={600} disabled={!assessmentDone} className={field} />
        </label>
        <label className="grid gap-1 text-xs font-semibold">
          C
          <input name="minutes_c" type="number" min={0} max={600} disabled={!assessmentDone} className={field} />
        </label>
      </fieldset>
      <label className="grid gap-1 text-xs font-semibold">
        Verantwortlich
        <select name="responsible" defaultValue={members.find((m) => m.me)?.user_id ?? ""} className={field}>
          <option value="">Team (noch niemand)</option>
          {members.map((m, i) => (
            <option key={m.user_id} value={m.user_id}>
              {m.me ? "Ich" : `Teammitglied ${i + 1}`}
              {m.qualification ? ` – ${QUALIFICATION_LABEL[m.qualification] ?? m.qualification}` : ""}
            </option>
          ))}
        </select>
      </label>
      <ErrorText message={error} />
      <div className="grid grid-cols-[2fr_1fr] gap-2">
        <button type="submit" disabled={pending} className="min-h-11 rounded-xl bg-emerald-800 font-bold text-white disabled:opacity-60">
          {pending ? "Wird gespeichert …" : "Einsatz speichern"}
        </button>
        <button type="button" onClick={() => { setOpen(false); setError(null); }} className="min-h-11 rounded-xl border border-stone-300 font-semibold">
          Abbrechen
        </button>
      </div>
    </form>
  );
}

function PlannedVisit({ visit }: { visit: Upcoming }) {
  const router = useRouter();
  const [mode, setMode] = useState<"view" | "move" | "remove">("view");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const isPlanned = visit.status === "planned";

  async function submit(form: FormData) {
    setPending(true);
    setError(null);
    const reason = String(form.get("reason") ?? "");
    const result =
      mode === "move"
        ? await rescheduleVisit({
            visitId: visit.visit_id,
            date: String(form.get("date") ?? ""),
            start: String(form.get("start") ?? ""),
            end: String(form.get("end") ?? ""),
            reason,
            idempotencyKey: crypto.randomUUID(),
          })
        : await removePlannedVisit({ visitId: visit.visit_id, reason, idempotencyKey: crypto.randomUUID() });
    setPending(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setMode("view");
    router.refresh();
  }

  return (
    <div className="rounded-lg bg-stone-50 p-2 text-sm">
      <div className="flex items-start justify-between gap-2">
        <div>
          <p>
            <span className="font-semibold">{formatDayLabel(visit.date)}</span>{" "}
            <span className="tabular-nums">
              {hhmm(visit.start)}–{hhmm(visit.end)}
            </span>{" "}
            <span className="text-emerald-900/60">· {getVisitStatusLabel(visit.status)}</span>
          </p>
          <p className="text-xs text-emerald-900/70">
            {visit.needs_assessment ? "Bedarfsabklärung · " : ""}
            {formatMinutesByCategory(visit)} · {visit.responsible_me ? "verantwortlich: ich" : visit.responsible_set ? "verantwortlich: Teammitglied" : "noch niemand verantwortlich"}
          </p>
          {visit.last_change?.reason && (
            <p className="text-xs text-emerald-900/60">
              {visit.last_change.change === "moved" ? "Verschoben" : "Geändert"} {visit.last_change.own ? "von dir" : "im Team"}: {visit.last_change.reason}
            </p>
          )}
          <Flags flags={visit.flags} />
        </div>
        {isPlanned && mode === "view" && (
          <div className="flex shrink-0 gap-1">
            <button type="button" onClick={() => setMode("move")} className="min-h-11 px-2 font-semibold underline underline-offset-4">
              Verschieben
            </button>
            <button type="button" onClick={() => setMode("remove")} className="min-h-11 px-2 font-semibold text-rose-800 underline underline-offset-4">
              Entfernen
            </button>
          </div>
        )}
      </div>
      {mode !== "view" && (
        <form action={submit} aria-label={mode === "move" ? "Einsatz verschieben" : "Einsatz entfernen"} className="mt-2 grid gap-2">
          {mode === "move" && <SlotFields date={visit.date} start={hhmm(visit.start)} end={hhmm(visit.end)} />}
          <label className="grid gap-1 text-xs font-semibold">
            Grund
            <input name="reason" required minLength={3} maxLength={300} className={field} />
          </label>
          <div className="grid grid-cols-2 gap-2">
            <button type="submit" disabled={pending} className={`min-h-11 rounded-lg font-bold text-white disabled:opacity-60 ${mode === "move" ? "bg-emerald-800" : "bg-rose-800"}`}>
              {mode === "move" ? "Verschieben" : "Entfernen"}
            </button>
            <button type="button" onClick={() => setMode("view")} className="min-h-11 rounded-lg border border-stone-300 font-semibold">
              Abbrechen
            </button>
          </div>
        </form>
      )}
      <ErrorText message={error} />
    </div>
  );
}
