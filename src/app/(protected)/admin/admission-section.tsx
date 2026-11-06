"use client";

// ADM2-1 / ADM2-6 / ADM2-9 (migration 0091, ADR-114): the switch, "Vertrag erfassen" for proposals the team admitted,
// and every admission with team, outcome and date. The administrator records a fact; the team's decision is not
// changed here (no judgement field).
// UX2-26 (ADR-136, `aia` AUT-21, `uxa` 16:10): after "Vertrag erfasst" the same card offers the EXISTING
// set_member_qualification for that member and team (no new command, check, read scope or audit type; the
// administrator stays the only actor, D-29 unchanged). No value is selected on render; "Später" runs nothing.

import { useState, useTransition } from "react";
import { recordContract, setTeamAdmission } from "@/features/admission/commands";
import { setMemberQualification } from "@/features/admin/commands";
import {
  MISSING_QUALIFICATION_HEADING, OUTCOME_LABEL, QUALIFICATION_OFFER_TITLE, QUALIFICATION_REASON_LABEL, awaitingContract,
  findRecordedMember, qualificationOfferOptions, validQualificationReason, zurichDate, type AdminAdmissions, type AdminProposal,
  type MissingQualification,
} from "@/features/admission/rules";
import { QUALIFICATION_LABEL } from "@/features/team/rules";
import type { CommandResult } from "@/lib/commands/result";
import { ADMISSION_OFF_CONSEQUENCE, ADMISSION_ON_CONSEQUENCE } from "@/features/admin/confirm-texts";
import ConfirmStep from "./confirm-step";

const field = "min-h-10 rounded-lg border border-stone-300 bg-white px-2 text-sm";
const button = "min-h-10 rounded-lg bg-emerald-800 px-3 text-sm font-bold text-white disabled:opacity-60";
const secondary = "min-h-10 rounded-lg border border-stone-400 bg-white px-3 text-sm font-semibold disabled:opacity-60";

function useRun() {
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const run = (call: () => Promise<CommandResult>, done?: () => void) => start(async () => {
    setError(null);
    setNotice(null);
    const r = await call();
    if (r.ok) {
      setNotice("Gespeichert.");
      done?.();
    } else setError(r.error);
  });
  return { run, pending, error, notice };
}

type Recorded = { proposal: AdminProposal; email: string };

export default function AdmissionAdmin({ organizationId, admissions, missing = [] }: {
  organizationId: string; admissions: AdminAdmissions;
  /** UX2-26 (2): every team membership without a qualification (admin_members, the existing fact). */
  missing?: MissingQualification[];
}) {
  const { run, pending, error, notice } = useRun();
  // UX2-26 (1): proposals whose contract was recorded in this sitting keep their card for the qualification offer.
  const [recorded, setRecorded] = useState<Recorded[]>([]);
  const [offerNotice, setOfferNotice] = useState<string | null>(null);
  const close = (proposalId: string, message: string | null) => {
    setRecorded((r) => r.filter((x) => x.proposal.proposal_id !== proposalId));
    setOfferNotice(message);
  };
  const shownInCard = recorded
    .map((r) => findRecordedMember(missing, r.email, r.proposal.team_id))
    .filter((m): m is MissingQualification => m !== null);
  const stillMissing = missing.filter((m) => !shownInCard.some((c) => c.userId === m.userId && c.teamId === m.teamId));
  // UX2-23 (ADR-124): the switch asks once; the first tap only opens the step, "Abbrechen" changes nothing.
  const [confirming, setConfirming] = useState(false);
  const switchLabel = admissions.enabled ? "Ausschalten" : "Einschalten";
  const waiting = awaitingContract(admissions.proposals)
    .filter((p) => !recorded.some((r) => r.proposal.proposal_id === p.proposal_id));
  const history = admissions.proposals.filter((p) => p.outcome !== "admitted");
  return (
    <section aria-label="Aufnahme durch das Team" className="grid gap-3 rounded-2xl border border-stone-200 bg-white p-5">
      <h3 className="text-lg font-bold">Aufnahme durch das Team</h3>
      <p className="text-xs text-stone-600">
        Teams schlagen neue Kolleginnen vor und nehmen sie selbst auf. Hier wird nur «Vertrag erfasst»: das Konto, der
        Vertragsbeginn und ein allfälliges Vertragsende. Für eine echte Organisation erst nach deren Freigabe einschalten.
      </p>
      <div className="flex flex-wrap items-center gap-2 text-sm">
        <span data-testid="admission-switch" className="font-semibold">{admissions.enabled ? "Eingeschaltet" : "Ausgeschaltet"}</span>
        {!confirming && (
          <button type="button" className={secondary} disabled={pending} onClick={() => setConfirming(true)}>
            {switchLabel}
          </button>
        )}
        {confirming && (
          <ConfirmStep
            testId="admission-confirm"
            sentence={admissions.enabled ? ADMISSION_OFF_CONSEQUENCE : ADMISSION_ON_CONSEQUENCE}
            actionLabel={switchLabel}
            pending={pending}
            onCancel={() => setConfirming(false)}
            onConfirm={() => run(
              () => setTeamAdmission({ organizationId, enabled: !admissions.enabled, idempotencyKey: crypto.randomUUID() }),
              () => setConfirming(false),
            )}
          />
        )}
      </div>
      {error && <p role="alert" data-testid="command-error" className="font-semibold text-rose-800">{error}</p>}
      {notice && <p role="status" className="text-sm text-emerald-900">{notice}</p>}

      <h4 className="font-bold">Vom Team aufgenommen – Vertrag erfassen</h4>
      {waiting.length === 0 && recorded.length === 0 && <p className="text-sm text-stone-600">Keine Aufnahme wartet auf «Vertrag erfasst».</p>}
      {offerNotice && <p role="status" data-testid="qualification-offer-notice" className="text-sm text-emerald-900">{offerNotice}</p>}
      <ul className="grid gap-2" aria-label="Wartet auf Vertrag erfasst">
        {recorded.map((r) => (
          <li key={r.proposal.proposal_id}>
            <RecordedCard proposal={r.proposal} member={findRecordedMember(missing, r.email, r.proposal.team_id)}
              onClose={(message) => close(r.proposal.proposal_id, message)} />
          </li>
        ))}
        {waiting.map((p) => (
          <li key={p.proposal_id}>
            <ContractForm proposal={p} onRecorded={(email) => { setOfferNotice(null); setRecorded((r) => [...r, { proposal: p, email }]); }} />
          </li>
        ))}
      </ul>

      <h4 className="font-bold">{MISSING_QUALIFICATION_HEADING}</h4>
      {stillMissing.length === 0 && <p className="text-sm text-stone-600">Niemand.</p>}
      <ul className="grid gap-1 text-sm" aria-label={MISSING_QUALIFICATION_HEADING}>
        {stillMissing.map((m) => (
          <li key={`${m.userId}:${m.teamId}`} data-testid="qualification-missing-row">
            {m.displayName || m.email} · {m.team}
          </li>
        ))}
      </ul>

      <h4 className="font-bold">Alle Aufnahmen</h4>
      {history.length === 0 && <p className="text-sm text-stone-600">Noch keine.</p>}
      <ul className="grid gap-1 text-sm" aria-label="Alle Aufnahmen">
        {history.map((p) => (
          <li key={p.proposal_id} data-testid="admission-row">
            {p.team} · {OUTCOME_LABEL[p.outcome] ?? p.outcome} · {zurichDate(p.outcome_at ?? p.created_at)}
            {p.display_name ? ` · ${p.display_name}` : ""}
          </li>
        ))}
      </ul>
    </section>
  );
}

function claimLine(p: AdminProposal): string {
  return p.claimed_qualification ? ` · angegeben: ${QUALIFICATION_LABEL[p.claimed_qualification] ?? p.claimed_qualification}` : "";
}

function ContractForm({ proposal: p, onRecorded }: { proposal: AdminProposal; onRecorded: (email: string) => void }) {
  const { run, pending, error, notice } = useRun();
  return (
    <form aria-label={`Vertrag erfassen ${p.display_name ?? ""}`} className="grid gap-2 rounded-xl border border-stone-200 p-3"
      onSubmit={(e) => {
        e.preventDefault();
        const f = new FormData(e.currentTarget);
        const end = String(f.get("end") ?? "").trim();
        const email = String(f.get("email") ?? "").trim();
        run(() => recordContract({
          proposalId: p.proposal_id, email, startDate: String(f.get("start") ?? ""),
          endDate: end === "" ? null : end, idempotencyKey: crypto.randomUUID(),
        }), () => onRecorded(email));
      }}>
      <p className="text-sm">
        <span className="font-semibold">{p.display_name}</span> · {p.team}
        {claimLine(p)}
        {p.pensum_band ? ` · Pensum ${p.pensum_band} %` : ""}
      </p>
      <label className="grid gap-1 text-xs font-semibold">
        E-Mail des angelegten Kontos
        <input name="email" type="email" required maxLength={254} autoComplete="off" className={field} />
      </label>
      <div className="grid grid-cols-2 gap-2">
        <label className="grid gap-1 text-xs font-semibold">
          Vertragsbeginn
          <input name="start" type="date" required className={field} />
        </label>
        <label className="grid gap-1 text-xs font-semibold">
          Vertragsende (falls bekannt)
          <input name="end" type="date" className={field} />
        </label>
      </div>
      <button type="submit" disabled={pending} className={`${button} justify-self-start`}>Vertrag erfassen</button>
      {error && <p role="alert" data-testid="command-error" className="font-semibold text-rose-800">{error}</p>}
      {notice && <p role="status" className="text-sm text-emerald-900">{notice}</p>}
    </form>
  );
}

// UX2-26 (1), `uxa` 16:10 layout: "<Name> · <Team> · angegeben: <Qualifikation>", a success line "Vertrag erfasst",
// then the fieldset "Qualifikation festlegen" (one radio per qualification, 44 px rows, none selected, the claimed one
// neither marked nor ordered first), the reason, "Qualifikation festlegen" (primary) and "Später" (outline).
function RecordedCard({ proposal: p, member, onClose }: {
  proposal: AdminProposal; member: MissingQualification | null; onClose: (message: string | null) => void;
}) {
  const { run, pending, error } = useRun();
  const [localError, setLocalError] = useState<string | null>(null);
  const name = p.display_name ?? "";
  return (
    <article aria-label={`Vertrag erfasst ${name}`} data-testid="recorded-card" className="grid gap-2 rounded-xl border border-stone-200 p-3">
      <p className="text-sm">
        <span className="font-semibold">{name}</span> · {p.team}{claimLine(p)}
      </p>
      <p role="status" data-testid="contract-recorded" className="text-sm font-semibold text-emerald-900">Vertrag erfasst</p>
      {member === null ? (
        // The membership is not (yet) in the member list read: nothing is set here; she stays listed below.
        <>
          <p className="text-sm text-stone-700">Sie steht noch nicht in der Mitgliederliste. Die Qualifikation legst du unter «Mitglieder» fest.</p>
          <button type="button" className={`${secondary} justify-self-start`} onClick={() => onClose(null)}>Später</button>
        </>
      ) : (
        <form aria-label={`${QUALIFICATION_OFFER_TITLE} ${name}`} className="grid gap-2" onSubmit={(e) => {
          e.preventDefault();
          if (member === null) return;
          const f = new FormData(e.currentTarget);
          const qualification = String(f.get("qualification") ?? "");
          const reason = String(f.get("reason") ?? "").trim();
          if (qualification === "") return setLocalError("Bitte eine Qualifikation wählen.");
          if (!validQualificationReason(reason)) return setLocalError("Die Begründung braucht 3 bis 300 Zeichen.");
          setLocalError(null);
          run(() => setMemberQualification({
            teamId: member.teamId, userId: member.userId, qualification, reason, idempotencyKey: crypto.randomUUID(),
          }), () => onClose("Qualifikation festgelegt."));
        }}>
          <fieldset className="grid gap-1">
            <legend className="text-sm font-bold">{QUALIFICATION_OFFER_TITLE}</legend>
            {qualificationOfferOptions().map((q) => (
              <label key={q} className="flex min-h-11 items-center gap-2 text-sm">
                <input type="radio" name="qualification" value={q} required className="h-5 w-5" />
                {QUALIFICATION_LABEL[q] ?? q}
              </label>
            ))}
          </fieldset>
          <label className="grid gap-1 text-xs font-semibold">
            {QUALIFICATION_REASON_LABEL}
            <input name="reason" required minLength={3} maxLength={300} autoComplete="off" className={field} />
          </label>
          <div className="flex flex-wrap gap-2">
            <button type="submit" disabled={pending} className={button}>{QUALIFICATION_OFFER_TITLE}</button>
            <button type="button" disabled={pending} className={secondary} onClick={() => onClose(null)}>Später</button>
          </div>
          {(localError ?? error) && <p role="alert" data-testid="command-error" className="font-semibold text-rose-800">{localError ?? error}</p>}
        </form>
      )}
    </article>
  );
}
