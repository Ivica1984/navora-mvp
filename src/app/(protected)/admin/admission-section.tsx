"use client";

// ADM2-1 / ADM2-6 / ADM2-9 (migration 0091, ADR-114): the switch, "Vertrag erfassen" for proposals the team admitted,
// and every admission with team, outcome and date. The administrator records a fact; the team's decision is not
// changed here (no judgement field).

import { useState, useTransition } from "react";
import { recordContract, setTeamAdmission } from "@/features/admission/commands";
import { OUTCOME_LABEL, awaitingContract, zurichDate, type AdminAdmissions, type AdminProposal } from "@/features/admission/rules";
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

export default function AdmissionAdmin({ organizationId, admissions }: { organizationId: string; admissions: AdminAdmissions }) {
  const { run, pending, error, notice } = useRun();
  // UX2-23 (ADR-124): the switch asks once; the first tap only opens the step, "Abbrechen" changes nothing.
  const [confirming, setConfirming] = useState(false);
  const switchLabel = admissions.enabled ? "Ausschalten" : "Einschalten";
  const waiting = awaitingContract(admissions.proposals);
  const history = admissions.proposals.filter((p) => p.outcome !== "admitted");
  return (
    <section aria-label="Aufnahme durch das Team" className="grid gap-3 rounded-2xl border border-stone-200 bg-white p-5">
      <h3 className="text-lg font-bold">Aufnahme durch das Team</h3>
      <p className="text-xs text-stone-600">
        Teams schlagen neue Kolleginnen vor und nehmen sie selbst auf. Hier wird nur «Vertrag erfasst»: das Konto, der
        Vertragsbeginn und ein allfälliges Vertragsende. Die Qualifikation setzt die Administration wie bisher beim Mitglied.
        Für eine echte Organisation erst nach deren Freigabe einschalten.
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
      {waiting.length === 0 && <p className="text-sm text-stone-600">Keine Aufnahme wartet auf «Vertrag erfasst».</p>}
      <ul className="grid gap-2" aria-label="Wartet auf Vertrag erfasst">
        {waiting.map((p) => <li key={p.proposal_id}><ContractForm proposal={p} /></li>)}
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

function ContractForm({ proposal: p }: { proposal: AdminProposal }) {
  const { run, pending, error, notice } = useRun();
  return (
    <form aria-label={`Vertrag erfassen ${p.display_name ?? ""}`} className="grid gap-2 rounded-xl border border-stone-200 p-3"
      onSubmit={(e) => {
        e.preventDefault();
        const f = new FormData(e.currentTarget);
        const end = String(f.get("end") ?? "").trim();
        run(() => recordContract({
          proposalId: p.proposal_id, email: String(f.get("email") ?? "").trim(), startDate: String(f.get("start") ?? ""),
          endDate: end === "" ? null : end, idempotencyKey: crypto.randomUUID(),
        }));
      }}>
      <p className="text-sm">
        <span className="font-semibold">{p.display_name}</span> · {p.team}
        {p.claimed_qualification ? ` · angegeben: ${QUALIFICATION_LABEL[p.claimed_qualification] ?? p.claimed_qualification}` : ""}
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
