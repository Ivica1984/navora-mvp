"use client";

// ASM1 (migration 0100, ADR-123): the needs assessment of a case as recorded facts (ASM1-10) and, on the care plan, the
// assessment it rests on with the assessed minutes beside the items as written (ASM1-7, ASM1-11). Display only: nothing
// here sums, compares, colours or warns (`cra` CGR-81); nothing blocks saving, planning or billing.

import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { confirmAssessment, recordAssessment } from "@/features/assessment/commands";
import {
  CATEGORIES,
  STATE_LABEL,
  assessedMinutes,
  assessmentLine,
  currentRecord,
  formatDate,
  instrumentLabel,
  recordAnchor,
  REFERENCE_HINT,
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
  const historyRef = useRef<HTMLDetailsElement>(null);

  // ASM1-C1: the "Zu bestätigen" link on /field jumps to a record; when that record sits in the closed history, open it.
  useEffect(() => {
    const target = typeof window === "undefined" ? "" : window.location.hash.slice(1);
    const el = historyRef.current;
    if (!target || !el) return;
    if (el.querySelector(`[id="${CSS.escape(target)}"]`)) {
      el.open = true;
      document.getElementById(target)?.scrollIntoView();
    }
  }, [records.length]);

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

  const earlier = records.filter((r) => !r.current);

  // A render function, not a nested component: React would remount a component defined during render.
  function renderRecord(r: AssessmentRecord, inHistory: boolean) {
    return (
      <li
        key={r.id}
        id={recordAnchor(r.id)}
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
        {/* ASM1-C2 (UXR-55): the minutes with their period are shown once per card, in the care-plan block (ASM1-11);
            an earlier record keeps them here in short form, inside the closed history. */}
        {inHistory && (
          <p className="text-xs">
            {CATEGORIES.map((c) => `${c}: ${assessedMinutes(r, c) ?? "keine Minuten"}`).join(" · ")}
          </p>
        )}
        {r.document_ref && <p className="text-xs text-secondary">Referenz: {r.document_ref}</p>}
        {r.supersedes_id && r.supersede_reason && (
          <p data-testid="assessment-supersede-reason" className="text-xs text-secondary">
            Ersetzt eine frühere Erfassung. Grund: {r.supersede_reason}
          </p>
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
    );
  }

  return (
    <section aria-label="Bedarfsabklärung" data-ref="ASM1" className="mt-3 rounded-xl bg-stone-50 p-2 text-sm">
      <h4 className="text-xs font-bold uppercase tracking-wide text-secondary">Bedarfsabklärung</h4>
      {records.length === 0 ? (
        <p className="italic text-secondary">Noch keine Bedarfsabklärung erfasst.</p>
      ) : (
        <>
          {/* ASM1-C2 (UXR-55, `cra` 09:30): the current record (line, state, its actions, the "Ersetzt …" line) stays open. */}
          {current && (
            <ul aria-label="Aktuelle Bedarfsabklärung" className="mt-1 grid gap-2">
              {renderRecord(current, false)}
            </ul>
          )}
          {earlier.length > 0 && (
            <details ref={historyRef} data-testid="assessment-history-details" className="mt-2">
              <summary className="min-h-11 cursor-pointer py-2 text-xs font-semibold">Frühere Erfassungen ({earlier.length})</summary>
              <ul aria-label="Frühere Erfassungen" className="grid gap-2">
                {earlier.map((r) => renderRecord(r, true))}
              </ul>
            </details>
          )}
        </>
      )}
      {current === null && records.length > 0 && <p className="text-xs text-secondary">Keine aktuelle Bedarfsabklärung.</p>}
      <ErrorLine message={error} />
      {mode === null ? (
        <button type="button" onClick={() => setMode({ kind: "new" })} className="mt-1 min-h-11 px-2 font-semibold underline">
          Bedarfsabklärung erfassen
        </button>
      ) : (
        <form
          // onSubmit, not a form action: React resets a form after its action, which would empty the fields after a
          // refusal (the nurse corrects one field, not all of them).
          onSubmit={(e) => {
            e.preventDefault();
            void submit(new FormData(e.currentTarget));
          }}
          aria-label={mode.kind === "supersede" ? "Bedarfsabklärung ersetzen" : "Bedarfsabklärung erfassen"}
          className="mt-2 grid gap-2"
          key={prefill?.id ?? "new"}
        >
          {prefill && (
            <p data-testid="supersede-target" className="text-xs font-semibold">
              Ersetzt: {assessmentLine(prefill)}
            </p>
          )}
          <p className="text-xs text-secondary">
            Erfasst wird, was in eurem Abklärungsinstrument steht. Die vollständige Abklärung bleibt dort; hier steht nur ihre Referenz.
          </p>
          <div className="grid gap-2 sm:grid-cols-2">
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
            <div className="grid gap-1">
              <label className="grid gap-1 text-xs font-semibold">
                Referenz der vollständigen Abklärung
                <input
                  name="document_ref"
                  maxLength={64}
                  defaultValue={prefill?.document_ref ?? ""}
                  placeholder="z. B. BA-2026-0042"
                  aria-describedby={`ref-hint-${caseId}`}
                  className={field}
                />
              </label>
              {/* ASM1-C3 (UXR-54): the rule is visible before any refusal (outside the label, so the field's name stays short). */}
              <p id={`ref-hint-${caseId}`} data-testid="reference-hint" className="text-xs text-secondary">
                {REFERENCE_HINT}
              </p>
            </div>
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
