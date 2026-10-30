"use client";

// ASM1 (migration 0100, ADR-123): the needs assessment of a case as recorded facts (ASM1-10) and, on the care plan, the
// assessment it rests on with the assessed minutes beside the items as written (ASM1-7, ASM1-11). Display only: nothing
// here sums, compares, colours or warns (`cra` CGR-81); nothing blocks saving, planning or billing.

import { useRouter } from "next/navigation";
import { useState } from "react";
import { confirmAssessment, recordAssessment } from "@/features/assessment/commands";
import {
  CATEGORIES,
  STATE_LABEL,
  assessedMinutes,
  assessmentLine,
  currentRecord,
  formatDate,
  instrumentLabel,
  type AssessmentRecord,
  type CaseAssessments,
  type Instrument,
} from "@/features/assessment/rules";
import { memberLabel } from "@/features/team/rules";

type Member = { user_id: string; qualification: string | null; me: boolean; name?: string | null };

const field = "min-h-11 rounded-lg border border-stone-300 bg-white px-2";

function ErrorLine({ message }: { message: string | null }) {
  if (!message) return null;
  return (
    <p role="alert" data-testid="assessment-error" className="mt-2 rounded-lg border border-rose-300 bg-rose-50 p-2 text-sm font-semibold text-rose-800">
      {message}
    </p>
  );
}

function intOrNull(v: FormDataEntryValue | null): number | null {
  const s = String(v ?? "").trim();
  if (s === "") return null;
  const n = Number.parseInt(s, 10);
  return Number.isFinite(n) ? n : Number.NaN;
}
function textOrNull(v: FormDataEntryValue | null): string | null {
  const s = String(v ?? "").trim();
  return s === "" ? null : s;
}

/** ASM1-10: current assessment, history with superseded records marked, a form to record and to supersede. */
export default function AssessmentSection({
  caseId,
  view,
  instruments,
  members,
}: {
  caseId: string;
  view: CaseAssessments | null;
  instruments: Instrument[];
  members: Member[];
}) {
  const router = useRouter();
  const [mode, setMode] = useState<{ kind: "new" } | { kind: "supersede"; record: AssessmentRecord } | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);
  const records = view?.records ?? [];
  const current = currentRecord(view);
  const nurses = members.filter((m) => m.qualification === "registered_nurse");

  async function submit(form: FormData) {
    setPending(true);
    setError(null);
    const result = await recordAssessment({
      caseId,
      assessmentDate: String(form.get("assessment_date") ?? ""),
      instrumentId: String(form.get("instrument") ?? ""),
      assessorId: String(form.get("assessor") ?? ""),
      documentRef: textOrNull(form.get("document_ref")),
      minutesA: intOrNull(form.get("minutes_a")),
      periodA: textOrNull(form.get("period_a")),
      minutesB: intOrNull(form.get("minutes_b")),
      periodB: textOrNull(form.get("period_b")),
      minutesC: intOrNull(form.get("minutes_c")),
      periodC: textOrNull(form.get("period_c")),
      supersedesId: mode?.kind === "supersede" ? mode.record.id : null,
      reason: mode?.kind === "supersede" ? textOrNull(form.get("reason")) : null,
      idempotencyKey: crypto.randomUUID(),
    });
    setPending(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setMode(null);
    router.refresh();
  }

  async function confirm(recordId: string) {
    setPending(true);
    setError(null);
    const result = await confirmAssessment({ recordId, idempotencyKey: crypto.randomUUID() });
    setPending(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    router.refresh();
  }

  const prefill = mode?.kind === "supersede" ? mode.record : null;

  return (
    <section aria-label="Bedarfsabklärung" data-ref="ASM1" className="mt-3 rounded-xl bg-stone-50 p-2 text-sm">
      <h4 className="text-xs font-bold uppercase tracking-wide text-secondary">Bedarfsabklärung</h4>
      {records.length === 0 ? (
        <p className="italic text-secondary">Noch keine Bedarfsabklärung erfasst.</p>
      ) : (
        <ul aria-label="Erfasste Bedarfsabklärungen" className="mt-1 grid gap-2">
          {records.map((r) => (
            <li
              key={r.id}
              aria-label={`Bedarfsabklärung vom ${formatDate(r.assessment_date)}${r.superseded_by ? " (ersetzt)" : ""}`}
              data-testid={r.current ? "assessment-current" : "assessment-history"}
              className="rounded-lg border border-stone-200 bg-white p-2"
            >
              <p className="font-semibold">
                {r.current ? "Aktuell: " : r.superseded_by ? "Ersetzt: " : "Frühere: "}
                {assessmentLine(r)}
              </p>
              <p data-testid="assessment-state" className="text-xs text-secondary">
                Status: {STATE_LABEL[r.state]}
              </p>
              <ul className="mt-1 grid gap-0.5 text-xs">
                {CATEGORIES.map((c) => (
                  <li key={c}>
                    Kategorie {c}: {assessedMinutes(r, c) ?? "keine Minuten erfasst"}
                  </li>
                ))}
              </ul>
              {r.document_ref && <p className="text-xs text-secondary">Referenz: {r.document_ref}</p>}
              {r.supersedes_id && r.supersede_reason && (
                <p className="text-xs text-secondary">Ersetzt eine frühere Erfassung. Grund: {r.supersede_reason}</p>
              )}
              <div className="mt-1 flex flex-wrap gap-2">
                {r.assessor_is_me && r.state === "unconfirmed" && !r.superseded_by && (
                  <button
                    type="button"
                    disabled={pending}
                    onClick={() => confirm(r.id)}
                    className="min-h-11 rounded-lg bg-emerald-800 px-3 font-bold text-white disabled:opacity-60"
                  >
                    Als abklärende Pflegefachperson bestätigen
                  </button>
                )}
                {!r.superseded_by && (
                  <button
                    type="button"
                    onClick={() => setMode({ kind: "supersede", record: r })}
                    className="min-h-11 px-2 text-xs font-semibold underline"
                  >
                    Korrigieren (ersetzen)
                  </button>
                )}
              </div>
            </li>
          ))}
        </ul>
      )}
      {current === null && records.length > 0 && <p className="text-xs text-secondary">Keine aktuelle Bedarfsabklärung.</p>}
      <ErrorLine message={error} />
      {mode === null ? (
        <button type="button" onClick={() => setMode({ kind: "new" })} className="mt-1 min-h-11 px-2 font-semibold underline">
          Bedarfsabklärung erfassen
        </button>
      ) : (
        <form
          action={submit}
          aria-label={mode.kind === "supersede" ? "Bedarfsabklärung ersetzen" : "Bedarfsabklärung erfassen"}
          className="mt-2 grid gap-2"
          key={prefill?.id ?? "new"}
        >
          <p className="text-xs text-secondary">
            Erfasst wird, was in eurem Abklärungsinstrument steht. Die vollständige Abklärung bleibt dort; hier steht nur ihre Referenz.
          </p>
          <div className="grid grid-cols-2 gap-2">
            <label className="grid gap-1 text-xs font-semibold">
              Datum der Abklärung
              <input name="assessment_date" type="date" required defaultValue={prefill?.assessment_date ?? ""} className={field} />
            </label>
            <label className="grid gap-1 text-xs font-semibold">
              Instrument
              <select name="instrument" required defaultValue="" className={field}>
                <option value="" disabled>–</option>
                {instruments.map((i) => (
                  <option key={i.id} value={i.id}>
                    {instrumentLabel(i.name, i.version, i.third_party_mark)} (gültig ab {formatDate(i.valid_from)}
                    {i.valid_to ? ` bis ${formatDate(i.valid_to)}` : ""})
                  </option>
                ))}
              </select>
            </label>
            <label className="grid gap-1 text-xs font-semibold">
              Abklärende Pflegefachperson
              <select name="assessor" required defaultValue="" className={field}>
                <option value="" disabled>–</option>
                {nurses.map((m) => (
                  <option key={m.user_id} value={m.user_id}>
                    {memberLabel(members, m.user_id)}
                  </option>
                ))}
              </select>
            </label>
            <label className="grid gap-1 text-xs font-semibold">
              Referenz im Abklärungsinstrument
              <input name="document_ref" maxLength={64} defaultValue={prefill?.document_ref ?? ""} placeholder="z. B. BA-2026-0042" className={field} />
            </label>
          </div>
          <fieldset className="grid gap-2">
            <legend className="text-xs font-semibold">Minuten pro Kategorie, je mit dem Zeitraum aus der Abklärung (optional)</legend>
            {CATEGORIES.map((c) => {
              const key = c.toLowerCase() as "a" | "b" | "c";
              return (
                <div key={c} className="grid grid-cols-2 gap-2">
                  <label className="grid gap-1 text-xs font-semibold">
                    Minuten {c}
                    <input name={`minutes_${key}`} type="number" min={0} max={99999} defaultValue={prefill?.[`minutes_${key}`] ?? ""} className={field} />
                  </label>
                  <label className="grid gap-1 text-xs font-semibold">
                    Zeitraum {c}
                    <input name={`period_${key}`} maxLength={60} defaultValue={prefill?.[`period_${key}`] ?? ""} className={field} />
                  </label>
                </div>
              );
            })}
          </fieldset>
          {mode.kind === "supersede" && (
            <label className="grid gap-1 text-xs font-semibold">
              Grund für den Ersatz
              <input name="reason" required minLength={10} maxLength={500} className={field} />
            </label>
          )}
          <div className="grid grid-cols-2 gap-2">
            <button type="submit" disabled={pending} className="min-h-11 rounded-lg bg-emerald-800 font-bold text-white disabled:opacity-60">
              {mode.kind === "supersede" ? "Ersatz speichern" : "Bedarfsabklärung speichern"}
            </button>
            <button type="button" onClick={() => setMode(null)} className="min-h-11 rounded-lg border border-stone-300 font-semibold">
              Abbrechen
            </button>
          </div>
        </form>
      )}
    </section>
  );
}
