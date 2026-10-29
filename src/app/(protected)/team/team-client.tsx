"use client";

import AdmissionSection from "./admission-section";
import type { TeamAdmissionView } from "@/features/admission/queries";
import Link from "next/link";
import { HeaderMenu } from "@/components/layout/Sidebar";
import { PAGE_LABEL } from "@/lib/auth/nav";
import SignalBanner from "@/components/signals/SignalBanner";
import type { OutsideWatchedVisit, SignalRow } from "@/features/signals/rules";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { addCarePlanItem, completeCaseTask, decideMatchingRequest, planVisit, removePlannedVisit, rescheduleVisit, retireCarePlanItem, setPrimaryNurse } from "@/features/team/commands";
import { returnReferralFacts, returningOfferText, reviewTaskLabel, type ReturnReferralFacts } from "@/features/returning/rules";
import {
  DECLINE_REASONS,
  DECLINE_REASON_LABEL,
  PLAN_FLAG_LABEL,
  QUALIFICATION_LABEL,
  declineError,
  formatContinuity,
  formatMinutesByCategory,
  formatResponseDue,
  formatWeeklyHours,
  memberLabel,
  minutesFromForm,
  sortVisitAlerts,
  visitAlertHandling,
  CLEARANCE_SUMMARY,
  CLEARANCE_TEXT,
  PROVISIONAL_NOTE,
  SIGNAL_POINTER,
  alertRepeatsSignal,
} from "@/features/team/rules";
import { splitSignals } from "@/features/signals/rules";
import { SETTINGS_ITEM } from "@/lib/auth/nav";
import { PRIORITY_LABEL, alertFlagLabels, formatAge } from "@/features/operations/exceptions";
import { MEDICAL_ORDER_LABEL, TASK_LABEL, urgencyBadgeClass, urgencyWithSource } from "@/features/intake/rules";
import type { ContinuityRow, TeamCase, TeamOffer, TeamVisitAlert } from "@/features/team/queries";
import type { BillingPreviewRow } from "@/features/billing/queries";
import BillingPreview from "@/components/billing/billing-preview";
import InterruptionFollowupForm from "@/components/lifecycle/InterruptionFollowupForm";
import CaseLifecycleControls, { ClosedCases } from "./case-lifecycle";
import AutoPlan, { type ScheduledItem } from "./auto-plan";
import type { PlanStatus } from "@/features/planning/queries";
import type { CaseLifecycle } from "@/features/lifecycle/queries";
import { RESPONSIBLE_ABSENT_NOTE } from "@/features/lifecycle/rules";
import { RELEASED_ON_MOVE, formatDayLabel, shiftDay, todayInZurich } from "@/features/field/rules";
import { getVisitStatusLabel } from "@/features/visits/types";
import { recordGpInformed } from "@/features/gp/commands";
import { OUTSIDE_LABEL, REACH_GAP_TEXT, TEAM_STATUS_NOTE, allReachable, statusText } from "@/features/push/rules";
import type { TeamPushRow } from "@/features/push/queries";
import OutsideWatchedVisits from "@/components/signals/OutsideWatchedVisits";
import { GP_CHANNELS, GP_CHANNEL_LABEL, GP_MESSAGES, gpInformedText, informedOnProblem, latestNoticeByCase, type GpNotice } from "@/features/gp/rules";

function hoursSince(iso: string) {
  return Math.max(0, Math.floor((Date.now() - Date.parse(iso)) / 3_600_000));
}

export default function TeamClient({
  offers,
  cases,
  continuity,
  billing,
  month,
  lifecycle,
  planStatus,
  visitAlerts = [],
  signals = [],
  gpNotices = [],
  pushStatus = [],
  outsideWatched = [],
  admissions = [],
}: {
  offers: TeamOffer[];
  cases: TeamCase[];
  continuity: ContinuityRow[];
  billing: BillingPreviewRow[];
  month: string;
  lifecycle: CaseLifecycle[];
  planStatus: PlanStatus[];
  visitAlerts?: TeamVisitAlert[];
  /** SIG1: the caller's open P1 safety signals. */
  signals?: SignalRow[];
  /** ORD0-3: "Hausärztin/Hausarzt informiert" records of the team's cases. */
  gpNotices?: GpNotice[];
  /** SIG2-2: per member, whether delivery outside the app is active. */
  pushStatus?: TeamPushRow[];
  /** SIG2-C1 (2): planned visits of the team's next 7 days outside the watched hours (null: could not be loaded). */
  outsideWatched?: OutsideWatchedVisit[] | null;
  /** ADM2-10: the team's admission proposals (empty when team admission is off). */
  admissions?: TeamAdmissionView[];
}) {
  const gpByCase = latestNoticeByCase(gpNotices);
  const open = offers.filter((o) => !o.my_team_declined);
  const declined = offers.filter((o) => o.my_team_declined);
  // UX1-22: the cards the banner shows now (polled), so a pointer line never points at a card that is gone.
  const [liveSignals, setLiveSignals] = useState<SignalRow[]>(signals);

  return (
    <div className="min-h-screen bg-stone-100 text-emerald-950">
      <header className="bg-emerald-950 px-4 pb-4 pt-3 text-white">
        <div className="mx-auto flex max-w-xl flex-wrap items-center justify-between gap-1">
          <Link href="/analytics" className="ml-auto flex min-h-11 items-center rounded-lg px-2 text-sm font-semibold underline underline-offset-4">
            {PAGE_LABEL.analytics}
          </Link>
          <Link href="/field" className="flex min-h-11 items-center rounded-lg px-2 text-sm font-semibold underline underline-offset-4">
            {PAGE_LABEL.field}
          </Link>
          {/* UX1-20: the role's menu (and "Meine Einstellungen") from the nurse's screens, inside the first viewport. */}
          <HeaderMenu active="team" />
        </div>
        <h1 className="mx-auto mt-1 max-w-xl text-xl font-bold">{PAGE_LABEL.team}</h1>
        <p className="mx-auto max-w-xl text-sm text-emerald-100">
          Ihr entscheidet selbst, welche Klientinnen und Klienten ihr übernehmt. Der erste Zusage-Entscheid eines Teams gilt.
        </p>
      </header>

      <main className="mx-auto grid max-w-xl gap-3 px-4 py-4">
        <SignalBanner initial={signals} onRows={setLiveSignals} />
        <VisitAlerts alerts={visitAlerts} openSignals={splitSignals(liveSignals).open} />
        <OutsideDeliveryStatus rows={pushStatus} />
        <OutsideWatchedVisits rows={outsideWatched} />

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
            <h2 className="text-sm font-bold uppercase tracking-wide text-secondary">Von deinem Team abgelehnt</h2>
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
                <CaseCard
                  teamCase={c}
                  continuity={continuity.find((r) => r.case_id === c.case_id) ?? null}
                  lifecycle={lifecycle.find((l) => l.case_id === c.case_id) ?? null}
                  planStatus={planStatus.find((p) => p.case_id === c.case_id) ?? null}
                  gpNotice={gpByCase.get(c.case_id) ?? null}
                />
              </li>
            ))}
          </ul>
        </section>

        <AdmissionSection views={admissions} />

        <ClosedCases items={lifecycle.filter((l) => l.lifecycle === "closed")} />

        <div className="mt-6">
          <BillingPreview rows={billing} month={month} />
        </div>

        <p className="mt-4 text-xs leading-relaxed text-secondary">
          Angeboten werden Anfragen aus der Region deines aktiven Teams. Kompetenzen, Kapazität und
          Sicherheitsvorbehalte werden noch nicht automatisch geprüft (Qualifikation schon) – bitte im Team beurteilen. Namen und Kontaktdaten
          sind erst nach der Zusage sichtbar.
        </p>
      </main>
    </div>
  );
}

// CSR1 / CGR-04: a visit that did not happen, or is stuck, stays visible to the whole team until it moves on or a
// person closes it. CSR1 / CGR-25: a visit ended as not completed stays until someone records the follow-up decision. CSR1 / CGR-24: a report correction not final after the report_not_final threshold stays until it is final. Thresholds are PROVISIONAL (D-28, clinical); no clinical instruction is given here.
function VisitAlerts({ alerts, openSignals }: { alerts: TeamVisitAlert[]; openSignals: SignalRow[] }) {
  if (alerts.length === 0) return null;
  return (
    <section aria-label="Einsätze mit Handlungsbedarf" className="grid gap-2 rounded-2xl border border-rose-300 bg-rose-50 p-3">
      <h2 className="text-lg font-bold text-rose-950">Einsätze mit Handlungsbedarf</h2>
      <ul className="grid gap-2">
        {sortVisitAlerts(alerts).map((a) =>
          // UX1-22 / `cra` C-1: an entry that only repeats an open signal card above shows one pointer line; an entry with
          // its own action, flags or handling state stays in full (`alertRepeatsSignal`, fail-safe).
          alertRepeatsSignal(a, openSignals) ? (
            <li key={a.exception_key} data-testid="visit-alert" data-pointer="signal" className="rounded-xl bg-white px-3 py-2 text-sm shadow-sm">
              <p>
                <span className="font-semibold">{a.label}</span>
                {" · "}{a.client_name ?? "Klient:in"}
                {" · "}<span data-testid="visit-alert-pointer">{SIGNAL_POINTER}</span>
              </p>
            </li>
          ) : (
            <li key={a.exception_key} data-testid="visit-alert" className="rounded-xl bg-white p-3 text-sm shadow-sm">
              <p className="font-semibold">
                <span className={a.priority === "P1" ? "text-rose-800" : "text-amber-800"}>{a.priority} {PRIORITY_LABEL[a.priority] ?? ""}</span>
                {" · "}{a.label}
              </p>
              <p>{a.client_name ?? "Klient:in"} · {a.detail}</p>
              {alertFlagLabels(a.flags).map((label) => (
                // CSR1 / CGR-32: computed from the absence (fixed label, no reason); the visit keeps its responsible member.
                <p key={label} data-testid="visit-alert-flag" className="font-semibold text-rose-900">{label}</p>
              ))}
              <p className="text-xs text-stone-600">{formatAge(a.since)} · {a.team_name} · {visitAlertHandling(a.taken)}</p>
              {a.exception_type === "visit_interrupted" && (
                // CSR1 / CGR-25: ends only with this decision (PROVISIONAL, D-31).
                <div className="mt-2"><InterruptionFollowupForm visitId={a.visit_id} /></div>
              )}
            </li>
          ),
        )}
      </ul>
      {/* UX1-22 / C-1: the clearance explanation behind one tap; its last sentence stays visible. */}
      <details data-testid="visit-alert-clearance" className="text-xs text-rose-900/80">
        <summary className="flex min-h-11 cursor-pointer items-center font-semibold">{CLEARANCE_SUMMARY}</summary>
        <p>{CLEARANCE_TEXT}</p>
      </details>
      <p data-testid="visit-alert-provisional" className="text-xs text-rose-900/80">{PROVISIONAL_NOTE}</p>
    </section>
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
          <p className="text-sm text-secondary">
            {offer.region} · für {offer.team_name} · seit {hoursSince(offer.created_at)} h offen
          </p>
        </div>
        <span className={`shrink-0 rounded-full px-3 py-1 text-xs font-bold ${urgencyBadgeClass(offer.urgency)}`}>
          {offer.urgency}
        </span>
      </div>
      {/* IPA1-7: the level is never shown without who set it. */}
      <p data-testid="urgency-source" className="mt-1 text-sm text-secondary">
        {urgencyWithSource(offer.urgency, offer.urgency_source)}
      </p>
      {offer.returning_client && (
        // RET1: only the previous team sees this; other teams get the plain J2 offer after the window.
        <p data-testid="returning-client" className="mt-2 rounded-lg bg-emerald-50 p-2 text-sm font-semibold text-emerald-900">
          {returningOfferText(offer.first_refusal_until)}
        </p>
      )}
      <p className="mt-2 text-sm">
        Leistungen: {offer.required_services?.length ? offer.required_services.join(", ") : "nicht angegeben"}
      </p>
      <dl className="mt-2 grid grid-cols-[9rem_1fr] gap-x-2 gap-y-0.5 text-sm" aria-label="Eckdaten">
        <dt className="text-secondary">Beginn</dt>
        <dd>{offer.requested_start ? formatDayLabel(offer.requested_start) : "nicht erfasst"}</dd>
        {/* IPA1-8: the referrer's date, shown only (never orders, filters or escalates). */}
        <dt className="text-secondary">Gewünschter Beginn (laut Zuweiser)</dt>
        <dd data-testid="referrer-start">
          {offer.referrer_requested_start ? formatDayLabel(offer.referrer_requested_start) : "nicht angegeben"}
        </dd>
        <dt className="text-secondary">Umfang</dt>
        <dd>{formatWeeklyHours(offer.expected_hours_per_week)}</dd>
        <dt className="text-secondary">Qualifikation</dt>
        <dd>
          {offer.required_qualification
            ? `${QUALIFICATION_LABEL[offer.required_qualification] ?? offer.required_qualification} nötig`
            : "keine besondere"}
        </dd>
        <dt className="text-secondary">Antwortfrist</dt>
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
  generated?: boolean;   // PLAN2: created from the care plan
  responsible_me: boolean;
  responsible_set: boolean;
  covered_by_team?: string | null;   // COVER1
  responsible_id?: string | null;    // ADM1
  flags: string[] | null;
  last_change: { change: string; reason: string | null; own: boolean; responsible_absent?: boolean } | null;
};
type PlanItem = {
  id: string; service: string; category: string; minutes: number; frequency: string; review_date: string; goal?: string | null;
  // PLAN2 (migration 0025)
  freq_times?: number | null; freq_period?: string | null; freq_weekdays?: number[] | null; window_start?: string | null; window_end?: string | null;
};
const toScheduled = (i: PlanItem): ScheduledItem => ({
  id: i.id, service: i.service, category: i.category, minutes: i.minutes,
  freq_times: i.freq_times ?? null, freq_period: i.freq_period ?? null, freq_weekdays: i.freq_weekdays ?? null,
  window_start: i.window_start ?? null, window_end: i.window_end ?? null,
});
type Member = { user_id: string; qualification: string | null; me: boolean; name?: string | null };

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

function CaseCard({ teamCase, continuity, lifecycle, planStatus, gpNotice }: {
  teamCase: TeamCase; continuity: ContinuityRow | null; lifecycle: CaseLifecycle | null; planStatus: PlanStatus | null;
  gpNotice: GpNotice | null;
}) {
  const upcoming = arr<Upcoming>(teamCase.upcoming, "visit_id");
  const plan = arr<PlanItem>(teamCase.care_plan, "category");
  const members = arr<Member>(teamCase.members, "user_id");
  const needs = teamCase.care_needs ?? [];
  const order = teamCase.medical_order_status as keyof typeof MEDICAL_ORDER_LABEL | null;

  return (
    <article aria-label={`Fall ${teamCase.client_name ?? ""}`} className="rounded-2xl bg-white p-4 shadow-sm">
      <h3 className="font-bold">{teamCase.client_name ?? "Klient:in"}</h3>
      <p className="text-sm text-secondary">
        {teamCase.region} · {teamCase.team_name}
        {needs.length > 0 ? ` · ${needs.join(", ")}` : ""}
      </p>
      <p className="mt-1 text-xs text-secondary">
        Verordnung: {order ? MEDICAL_ORDER_LABEL[order] ?? order : "nicht erfasst"}
        {teamCase.medical_order_valid_until ? ` (gültig bis ${teamCase.medical_order_valid_until})` : ""}
        {" · "}
        {teamCase.needs_assessment_done ? "Bedarfsabklärung erfolgt" : "Bedarfsabklärung ausstehend"}
      </p>
      {teamCase.open_tasks.length > 0 && (
        <ul aria-label="Offene Aufgaben" className="mt-2 grid gap-0.5 text-sm">
          {teamCase.open_tasks.map((t) =>
            t === "review_after_pause" ? (
              <ReviewTask
                key={t}
                caseId={teamCase.case_id}
                reason={teamCase.review_after_pause_reason}
                facts={returnReferralFacts(teamCase)}
              />
            ) : t === "inform_gp" ? (
              <GpInformedTask key={t} caseId={teamCase.case_id} />
            ) : (
              <li key={t}>☐ {TASK_LABEL[t] ?? t}</li>
            ),
          )}
        </ul>
      )}

      {gpNotice && (
        // ORD0-3: the recorded fact (date and channel), shown also after the task closed.
        <p data-testid="gp-informed" className="mt-1 text-xs font-semibold text-emerald-900">{gpInformedText(gpNotice)}</p>
      )}

      {lifecycle && <CaseLifecycleControls item={lifecycle} />}

      <Continuity teamCase={teamCase} members={members} continuity={continuity} />

      <CarePlan caseId={teamCase.case_id} items={plan} />

      <AutoPlan caseId={teamCase.case_id} status={planStatus} items={plan.map(toScheduled)} />

      <h4 className="mt-3 text-xs font-bold uppercase tracking-wide text-secondary">Geplante Einsätze</h4>
      {upcoming.length === 0 ? (
        <p className="text-sm italic text-secondary">Noch keine Einsätze geplant.</p>
      ) : (
        <ul className="mt-1 grid gap-2" aria-label="Geplante Einsätze">
          {upcoming.map((v) => (
            <li key={v.visit_id}>
              <PlannedVisit visit={v} members={members} />
            </li>
          ))}
        </ul>
      )}

      <PlanForm caseId={teamCase.case_id} assessmentDone={teamCase.needs_assessment_done} members={members} />
    </article>
  );
}

// RET1: non-blocking task after a resumed pause; the team decides and closes it.
// COND2-4 (ADR-102): the returning referral's level with its source and the referrer's date, shown only (no order).
function ReviewTask({ caseId, reason, facts }: { caseId: string; reason: string | null; facts: ReturnReferralFacts | null }) {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  async function done() {
    setPending(true);
    setError(null);
    const result = await completeCaseTask({ caseId, kind: "review_after_pause", idempotencyKey: crypto.randomUUID() });
    setPending(false);
    if (!result.ok) setError(result.error);
    else router.refresh();
  }
  return (
    <li data-testid="review-after-pause" className="grid gap-1">
      <span>☐ {reviewTaskLabel(reason)}</span>
      {facts && (
        <span className="grid gap-0.5 pl-5 text-xs text-emerald-900/80">
          <span data-testid="return-urgency">{facts.urgencyLine}</span>
          <span data-testid="return-referrer-start">
            Gewünschter Beginn (laut Zuweiser): {facts.referrerStart ? formatDayLabel(facts.referrerStart) : "nicht angegeben"}
          </span>
        </span>
      )}
      <button type="button" onClick={done} disabled={pending} className="justify-self-start min-h-11 px-1 font-semibold underline underline-offset-4 disabled:opacity-60">
        {pending ? "Wird gespeichert …" : "Entschieden – erledigt"}
      </button>
      {error && <ErrorText message={error} />}
    </li>
  );
}

// ORD0-1/2: one step records that the doctor was informed (date, channel code; no free text) and closes the task.
function GpInformedTask({ caseId }: { caseId: string }) {
  const router = useRouter();
  const today = todayInZurich();
  const [open, setOpen] = useState(false);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const field = "min-h-11 rounded-lg border border-stone-300 bg-white px-2";

  async function save(form: FormData) {
    const informedOn = String(form.get("informed_on") ?? "");
    const channel = String(form.get("channel") ?? "");
    const problem = informedOnProblem(informedOn, today);
    if (problem || !channel) {
      setError(problem === "future" ? GP_MESSAGES.future : GP_MESSAGES.invalid);
      return;
    }
    setPending(true);
    setError(null);
    const result = await recordGpInformed({ caseId, informedOn, channel, idempotencyKey: crypto.randomUUID() });
    setPending(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setOpen(false);
    router.refresh();
  }

  return (
    <li data-testid="inform-gp-task" className="grid gap-1">
      <span>☐ {TASK_LABEL.inform_gp}</span>
      {!open ? (
        <button type="button" onClick={() => setOpen(true)} className="justify-self-start min-h-11 px-1 font-semibold underline underline-offset-4">
          Informiert – erfassen
        </button>
      ) : (
        <form action={save} aria-label="Hausärztin/Hausarzt informiert" className="grid gap-2 rounded-xl bg-stone-50 p-3">
          <label className="grid gap-1 text-sm">
            Informiert am
            <input type="date" name="informed_on" defaultValue={today} max={today} required className={field} />
          </label>
          <fieldset className="grid gap-1 text-sm">
            <legend>Kanal</legend>
            <div className="flex flex-wrap gap-x-4 gap-y-1">
              {GP_CHANNELS.map((c) => (
                <label key={c} className="flex min-h-11 items-center gap-2">
                  <input type="radio" name="channel" value={c} required /> {GP_CHANNEL_LABEL[c]}
                </label>
              ))}
            </div>
          </fieldset>
          <div className="flex flex-wrap gap-2">
            <button type="submit" disabled={pending} className="min-h-11 rounded-lg bg-emerald-800 px-4 font-semibold text-white disabled:opacity-60">
              {pending ? "Wird gespeichert …" : "Informiert speichern"}
            </button>
            <button type="button" onClick={() => setOpen(false)} className="min-h-11 px-2 font-semibold underline underline-offset-4">
              Abbrechen
            </button>
          </div>
          <p className="text-xs text-secondary" data-ref="D-22">Nur Datum und Kanal, keine Inhalte. Frist und Inhalt der Information sind offen.</p>
        </form>
      )}
      {error && <ErrorText message={error} />}
    </li>
  );
}

// J6 (PO brief): primary nurse and deputy per case; changing needs a reason; the measure is per client only.
function Continuity({ teamCase, members, continuity }: { teamCase: TeamCase; members: Member[]; continuity: ContinuityRow | null }) {
  const router = useRouter();
  const [editing, setEditing] = useState(false);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const hasPrimary = !!teamCase.primary_nurse_id;
  const field = "min-h-11 rounded-lg border border-stone-300 bg-white px-2";

  async function save(form: FormData) {
    setPending(true);
    setError(null);
    const deputy = String(form.get("deputy") ?? "");
    const result = await setPrimaryNurse({
      caseId: teamCase.case_id,
      primaryId: String(form.get("primary") ?? ""),
      deputyId: deputy || null,
      reason: String(form.get("reason") ?? ""),
      idempotencyKey: crypto.randomUUID(),
    });
    setPending(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setEditing(false);
    router.refresh();
  }

  return (
    <section aria-label="Kontinuität" className="mt-3 grid gap-1 rounded-xl bg-stone-50 p-3 text-sm">
      <h4 className="text-xs font-bold uppercase tracking-wide text-secondary">Kontinuität</h4>
      {!hasPrimary && <p className="font-semibold text-amber-800" data-testid="primary-missing">Bezugspflege noch nicht bestimmt.</p>}
      {!hasPrimary && teamCase.proposed_primary_nurse_id && (
        // RET1: the previous primary nurse of a returning client is proposed; the team confirms or changes it.
        <p data-testid="primary-proposal">
          Vorschlag: frühere Bezugspflege {memberLabel(members, teamCase.proposed_primary_nurse_id)} (bitte bestätigen oder ändern)
        </p>
      )}
      {hasPrimary && (
        <p>
          Bezugspflege: <span data-testid="primary-nurse">{memberLabel(members, teamCase.primary_nurse_id)}</span>
          {" · "}Stellvertretung: {memberLabel(members, teamCase.deputy_nurse_id)}
        </p>
      )}
      {continuity && <p className="text-xs text-secondary" data-testid="continuity">Diesen Monat: {formatContinuity(continuity)}</p>}
      {error && <ErrorText message={error} />}
      {!editing ? (
        <button type="button" onClick={() => setEditing(true)} className="justify-self-start min-h-11 px-1 font-semibold underline underline-offset-4">
          {hasPrimary ? "Bezugspflege ändern" : "Bezugspflege bestimmen"}
        </button>
      ) : (
        <form action={save} aria-label="Bezugspflege" className="grid gap-2">
          <label className="grid gap-1 text-xs font-semibold">
            Bezugspflegende
            <select name="primary" required defaultValue={teamCase.primary_nurse_id ?? teamCase.proposed_primary_nurse_id ?? members.find((m) => m.me)?.user_id ?? ""} className={field}>
              {members.map((m) => (
                <option key={m.user_id} value={m.user_id}>{memberLabel(members, m.user_id)}</option>
              ))}
            </select>
          </label>
          <label className="grid gap-1 text-xs font-semibold">
            Stellvertretung (optional)
            <select name="deputy" defaultValue={teamCase.deputy_nurse_id ?? ""} className={field}>
              <option value="">keine</option>
              {members.map((m) => (
                <option key={m.user_id} value={m.user_id}>{memberLabel(members, m.user_id)}</option>
              ))}
            </select>
          </label>
          {hasPrimary && (
            <label className="grid gap-1 text-xs font-semibold">
              Begründung des Wechsels
              <input name="reason" maxLength={300} className={field} />
            </label>
          )}
          <div className="grid grid-cols-2 gap-2">
            <button type="submit" disabled={pending} className="min-h-11 rounded-lg bg-emerald-800 font-bold text-white disabled:opacity-60">
              {pending ? "Wird gespeichert …" : "Speichern"}
            </button>
            <button type="button" onClick={() => setEditing(false)} className="min-h-11 rounded-lg border border-stone-300 font-semibold">
              Abbrechen
            </button>
          </div>
        </form>
      )}
    </section>
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
      <h4 className="text-xs font-bold uppercase tracking-wide text-secondary">Pflegeplan (Leistungen nach KLV)</h4>
      {items.length === 0 ? (
        <p className="italic text-secondary">Noch keine Leistungen erfasst.</p>
      ) : (
        <ul className="mt-1 grid gap-1">
          {items.map((i) => (
            <li key={i.id} className="flex items-center justify-between gap-2">
              <span>
                <strong>{i.category}</strong> · {i.service} · {i.minutes} min · {i.frequency} · Überprüfung {i.review_date}
                {i.goal && <span className="block text-xs text-secondary">Ziel: {i.goal}</span>}
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
          <p className="text-xs text-secondary" data-ref="D-15">
            Die Zuordnung zur KLV-Kategorie trifft das Team; die fachliche Freigabe der Zuordnung ist offen.
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

function PlannedVisit({ visit, members }: { visit: Upcoming; members: Member[] }) {
  const router = useRouter();
  const [mode, setMode] = useState<"view" | "move" | "remove">("view");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [released, setReleased] = useState(false);
  const isPlanned = visit.status === "planned";

  async function submit(form: FormData) {
    setPending(true);
    setError(null);
    setReleased(false);
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
    setReleased(result.released);
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
            <span className="text-secondary">· {getVisitStatusLabel(visit.status)}</span>
          </p>
          <p className="text-xs text-secondary">
            {visit.generated ? <span data-testid="generated-visit">aus Pflegeplan · </span> : null}
            {visit.needs_assessment ? "Bedarfsabklärung · " : ""}
            {formatMinutesByCategory(visit)} · {visit.responsible_me
              ? "verantwortlich: ich"
              : visit.covered_by_team
                ? `übernommen von Team ${visit.covered_by_team}`
                : visit.responsible_set
                  ? `verantwortlich: ${members.find((m) => m.user_id === visit.responsible_id)?.name?.trim() || "Teammitglied"}`
                  : "noch niemand verantwortlich"}
          </p>
          {visit.last_change?.reason && (
            <p className="text-xs text-secondary">
              {visit.last_change.change === "moved" ? "Verschoben" : "Geändert"} {visit.last_change.own ? "von dir" : "im Team"}: {visit.last_change.reason}
              {/* AN2 / CGR-35: stored by the server on the `moved` row (migration 0056), never chosen here. */}
              {visit.last_change.change === "moved" && visit.last_change.responsible_absent === true && (
                <span data-testid="moved-responsible-absent"> · {RESPONSIBLE_ABSENT_NOTE}</span>
              )}
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
      {released && (
        <p role="status" data-testid="moved-into-absence" className="mt-1 text-xs font-semibold text-amber-900">
          {RELEASED_ON_MOVE}
        </p>
      )}
      <ErrorText message={error} />
    </div>
  );
}

// SIG2-2: whose delivery outside the app works. Active / not active only; nothing else about the member.
function OutsideDeliveryStatus({ rows }: { rows: TeamPushRow[] }) {
  if (rows.length === 0) return null;
  const teams = [...new Set(rows.map((r) => r.team_id))];
  // UX1-24 (`uxa` UXR-7; `cra` C-3 "confirm with change"): while not every active member receives P1 signals outside
  // the app, the line is open, in amber (not the P1 colour), with the fixed text and a link to "Meine Einstellungen";
  // collapsed and neutral when all are on. No per-member detail beyond SIG2-2 (active / not active).
  const gap = !allReachable(rows);
  return (
    <details
      open={gap}
      className={gap ? "rounded-2xl border border-amber-800 bg-amber-50 p-4" : "rounded-2xl border border-emerald-900/10 bg-white p-4"}
      aria-label={OUTSIDE_LABEL}
      data-testid="push-team-status"
      data-reach={gap ? "gap" : "all"}
    >
      <summary className="cursor-pointer text-sm font-bold">
        {OUTSIDE_LABEL}: {rows.filter((r) => r.active).length} von {rows.length} aktiv
      </summary>
      {gap && (
        <p data-testid="push-team-gap" className="mt-2 text-sm font-semibold text-amber-900">
          {REACH_GAP_TEXT}{" "}
          <Link href={SETTINGS_ITEM.href} className="inline-flex min-h-11 items-center underline underline-offset-4">
            {SETTINGS_ITEM.label}
          </Link>
        </p>
      )}
      <p className="mt-2 text-xs text-stone-600">{TEAM_STATUS_NOTE}</p>
      {teams.map((teamId) => (
        <ul key={teamId} className="mt-2 grid gap-1 text-sm" aria-label={rows.find((r) => r.team_id === teamId)?.team_name}>
          {rows.filter((r) => r.team_id === teamId).map((r) => (
            <li key={r.user_id} className="flex justify-between gap-2">
              <span>{r.member_name}</span>
              <span className={r.active ? "font-semibold text-emerald-800" : "text-stone-700"}>{statusText(r.active).replace(`${OUTSIDE_LABEL}: `, "")}</span>
            </li>
          ))}
        </ul>
      ))}
    </details>
  );
}
