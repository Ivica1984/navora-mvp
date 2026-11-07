// ASM1-C6 (4) with P-37 (migration 0106, ADR-140; po 2026-10-30 18:25, `uxa` 15:50, `cra` 17:35): the void form's fields.
// Presentational and controlled (the state lives in assessment-void-form.tsx); imports only the pure rules, so
// tests/unit/asm1-c6-void.test.ts renders it. The `cra` sentence comes before the options; neither option is
// preselected; the free text and its hint appear only after "Anderer Grund"; submit stays disabled until valid.

import {
  VOID_CHOICES,
  VOID_REASON_HINT,
  VOID_SUBMIT_LABEL,
  VOID_SUPERSEDE_SENTENCE,
  voidSubmitEnabled,
  type VoidChoice,
} from "@/features/assessment/rules";

const field = "min-h-11 rounded-lg border border-stone-300 bg-white px-2";

export default function VoidReasonForm({
  idBase,
  choice,
  text,
  pending,
  onChoice,
  onText,
  onSubmit,
  onCancel,
}: {
  idBase: string;
  choice: VoidChoice | null;
  text: string;
  pending: boolean;
  onChoice?: (c: VoidChoice) => void;
  onText?: (t: string) => void;
  onSubmit?: () => void;
  onCancel?: () => void;
}) {
  const enabled = voidSubmitEnabled(choice, text) && !pending;
  return (
    <form
      aria-label="Irrtümlich erfasst"
      data-testid="assessment-void-form"
      onSubmit={(e) => {
        e.preventDefault();
        if (enabled) onSubmit?.();
      }}
      className="mt-2 grid gap-2"
    >
      <p data-testid="void-supersede-sentence" className="text-xs">
        {VOID_SUPERSEDE_SENTENCE}
      </p>
      <fieldset className="grid gap-1">
        <legend className="text-xs font-semibold">Grund</legend>
        {VOID_CHOICES.map((c) => (
          <label key={c.value} className="flex min-h-11 items-center gap-2 text-sm">
            <input
              type="radio"
              name={`${idBase}-kind`}
              value={c.value}
              checked={choice === c.value}
              onChange={() => onChoice?.(c.value)}
            />
            {c.label}
          </label>
        ))}
      </fieldset>
      {choice === "other" && (
        <div className="grid gap-1">
          <label className="grid gap-1 text-xs font-semibold">
            Grund (eigener Text)
            <textarea
              name="void_reason"
              aria-describedby={`${idBase}-hint`}
              minLength={10}
              maxLength={500}
              rows={2}
              value={text}
              onChange={(e) => onText?.(e.target.value)}
              className={`${field} py-1`}
            />
          </label>
          <p id={`${idBase}-hint`} data-testid="void-reason-hint" className="text-xs text-secondary">
            {VOID_REASON_HINT}
          </p>
        </div>
      )}
      <div className="flex flex-wrap gap-2">
        <button
          type="submit"
          disabled={!enabled}
          className="min-h-11 rounded-lg border border-stone-400 bg-white px-3 text-sm font-semibold disabled:opacity-60"
        >
          {VOID_SUBMIT_LABEL}
        </button>
        <button type="button" onClick={() => onCancel?.()} className="min-h-11 rounded-lg border border-stone-300 px-3 text-sm font-semibold">
          Abbrechen
        </button>
      </div>
    </form>
  );
}
