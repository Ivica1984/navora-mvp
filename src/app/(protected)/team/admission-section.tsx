"use client";

// ADM2-10: "Kollegin vorschlagen" and the team's open proposals (migration 0091, ADR-114). The team decides by consent;
// the database counts and admits. Shown only when the organisation switched team admission on (ADM2-1).

import { useState, useTransition } from "react";
import { decideCandidate, proposeCandidate } from "@/features/admission/commands";
import type { TeamAdmissionView } from "@/features/admission/queries";
import {
  OBJECTION_LABEL, OBJECTION_REASONS, OUTCOME_LABEL, PENSUM_BANDS, availableDecisions, consentLine, zurichDate,
  type Decision, type ObjectionReason, type TeamProposal,
} from "@/features/admission/rules";
import { QUALIFICATION_LABEL } from "@/features/team/rules";

const field = "min-h-11 rounded-lg border border-stone-300 bg-white px-2";
const primary = "min-h-11 rounded-lg bg-emerald-900 px-3 text-sm font-semibold text-white disabled:opacity-60";
const secondary = "min-h-11 rounded-lg border border-stone-400 bg-white px-3 text-sm font-semibold disabled:opacity-60";

export default function AdmissionSection({ views }: { views: TeamAdmissionView[] }) {
  if (views.length === 0) return null;
  return (
    <section aria-label="Aufnahme ins Team" className="mt-6 grid gap-3">
      <h2 className="text-lg font-bold">Aufnahme ins Team</h2>
      {views.map((v) => <TeamAdmission key={v.teamId} view={v} showTeam={views.length > 1} />)}
    </section>
  );
}

function TeamAdmission({ view, showTeam }: { view: TeamAdmissionView; showTeam: boolean }) {
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [open, setOpen] = useState(false);
  const { admissions } = view;

  const propose = (form: FormData) => start(async () => {
    setError(null);
    setNotice(null);
    const r = await proposeCandidate({
      teamId: view.teamId, displayName: String(form.get("name") ?? ""), qualification: String(form.get("qualification") ?? ""),
      pensumBand: String(form.get("pensum") ?? ""), idempotencyKey: crypto.randomUUID(),
    });
    if (r.ok) {
      setOpen(false);
      setNotice("Vorschlag erfasst. Dein Team entscheidet.");
    } else setError(r.error);
  });

  return (
    <div className="grid gap-2 rounded-2xl bg-white p-4 shadow-sm" data-testid="team-admission">
      {showTeam && <h3 className="font-bold">{view.teamName}</h3>}
      <p className="text-sm text-secondary">
        Ihr nehmt neue Kolleginnen selbst auf: aufgenommen, wenn {admissions.consents_needed} von euch zustimmen und kein
        Einwand besteht. Ohne Entscheid verfällt ein Vorschlag nach {admissions.lapse_days} Tagen. Den Vertrag erfasst danach
        die Administration.
      </p>
      {admissions.proposals.length === 0 && <p className="text-sm">Keine offenen Vorschläge.</p>}
      <ul className="grid gap-2" aria-label="Offene Vorschläge">
        {admissions.proposals.map((p) => (
          <li key={p.proposal_id}><ProposalCard proposal={p} /></li>
        ))}
      </ul>
      {!open ? (
        <button type="button" className={`${secondary} justify-self-start`} onClick={() => setOpen(true)}>
          Kollegin vorschlagen
        </button>
      ) : (
        <form action={propose} aria-label="Kollegin vorschlagen" className="grid gap-2 rounded-xl bg-stone-50 p-3">
          <label className="grid gap-1 text-xs font-semibold">
            Name (wie im Team gebraucht)
            <input name="name" required minLength={2} maxLength={80} autoComplete="off" className={field} />
          </label>
          <label className="grid gap-1 text-xs font-semibold">
            Angegebene Qualifikation
            <select name="qualification" required defaultValue="" className={field}>
              <option value="" disabled>Bitte wählen</option>
              <option value="registered_nurse">{QUALIFICATION_LABEL.registered_nurse}</option>
              <option value="care_assistant">{QUALIFICATION_LABEL.care_assistant}</option>
            </select>
          </label>
          <label className="grid gap-1 text-xs font-semibold">
            Pensum
            <select name="pensum" required defaultValue="" className={field}>
              <option value="" disabled>Bitte wählen</option>
              {PENSUM_BANDS.map((b) => <option key={b} value={b}>{b} %</option>)}
            </select>
          </label>
          <p className="text-xs text-secondary">
            Nur diese drei Angaben. Keine Kontaktdaten, kein Lebenslauf, keine Gesundheitsangaben. Sie werden gelöscht,
            sobald entschieden ist.
          </p>
          <div className="flex flex-wrap gap-2">
            <button type="submit" className={primary} disabled={pending}>Vorschlagen</button>
            <button type="button" className={secondary} onClick={() => setOpen(false)}>Abbrechen</button>
          </div>
        </form>
      )}
      {error && <p role="alert" data-testid="command-error" className="font-semibold text-rose-800">{error}</p>}
      {notice && <p role="status" className="text-sm text-emerald-900">{notice}</p>}
    </div>
  );
}

const DECISION_LABEL: Record<Decision, string> = {
  consent: "Zustimmen",
  objection: "Einwand",
  withdraw_objection: "Einwand zurückziehen",
  withdraw_proposal: "Vorschlag zurückziehen",
};

function ProposalCard({ proposal: p }: { proposal: TeamProposal }) {
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [objecting, setObjecting] = useState(false);

  const decide = (decision: Decision, reason: ObjectionReason | null = null) => start(async () => {
    setError(null);
    const r = await decideCandidate({ proposalId: p.proposal_id, decision, reason, idempotencyKey: crypto.randomUUID() });
    if (r.ok) setObjecting(false);
    else setError(r.error);
  });

  return (
    <article aria-label={`Vorschlag ${p.display_name}`} className="grid gap-1 rounded-xl border border-stone-200 p-3 text-sm">
      <p className="font-semibold">{p.display_name}</p>
      <p>
        angegeben: {QUALIFICATION_LABEL[p.claimed_qualification] ?? p.claimed_qualification} · Pensum {p.pensum_band} %
      </p>
      <p className="text-secondary">
        Vorgeschlagen von {p.proposed_by_me ? "dir" : (p.proposer_name ?? "einem Teammitglied")}
        {p.outcome === null ? ` · verfällt am ${zurichDate(p.lapses_at)}` : ""}
      </p>
      {p.outcome === null ? (
        <p data-testid="consent-count" className="font-semibold">{consentLine(p)}</p>
      ) : (
        <p data-testid="proposal-outcome" className="font-semibold text-emerald-900">
          {OUTCOME_LABEL[p.outcome]} – wartet auf «Vertrag erfasst» der Administration
        </p>
      )}
      {p.objections > 0 && (
        <p className="font-semibold text-amber-800">
          Einwand: {p.objection_reasons.map((r) => OBJECTION_LABEL[r] ?? r).join(", ")}
        </p>
      )}
      {p.my_stance === "consent" && <p className="text-xs">Du hast zugestimmt.</p>}
      {p.my_stance === "objection" && p.my_reason && <p className="text-xs">Dein Einwand: {OBJECTION_LABEL[p.my_reason]}</p>}
      <div className="flex flex-wrap gap-2">
        {availableDecisions(p).map((d) => (
          <button key={d} type="button" disabled={pending}
            className={d === "consent" ? primary : secondary}
            onClick={() => (d === "objection" ? setObjecting(true) : decide(d))}>
            {DECISION_LABEL[d]}
          </button>
        ))}
      </div>
      {objecting && (
        <fieldset className="grid gap-1" aria-label="Einwand begründen">
          <legend className="text-xs font-semibold">Grund des Einwands</legend>
          {OBJECTION_REASONS.map((r) => (
            <button key={r} type="button" disabled={pending} className={`${secondary} text-left`} onClick={() => decide("objection", r)}>
              {OBJECTION_LABEL[r]}
            </button>
          ))}
          <button type="button" className="min-h-11 text-left text-sm underline" onClick={() => setObjecting(false)}>Abbrechen</button>
        </fieldset>
      )}
      {error && <p role="alert" data-testid="command-error" className="font-semibold text-rose-800">{error}</p>}
    </article>
  );
}
