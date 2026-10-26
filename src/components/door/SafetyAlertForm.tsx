"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { recordSafetyAlertValue } from "@/features/door/commands";
import {
  ALERT_NOTE_MAX, ALERT_SOURCES, ALERT_SOURCE_LABEL, ALERT_VALUES, accessHistory, accessLine, alertMetaLine, alertValueError, alertValueText,
  alertValueTone,
} from "@/features/door/rules";

export type AlertCategoryView = { code: string; label: string; help_text: string | null; refuses_codes: boolean };
export type AlertValueView = {
  value: string | null;
  note: string | null;
  source: string | null;
  recorded_at: string | null;
  actor_kind: string | null;
  actor_name: string | null;
};

// DOOR1-4: "unbekannt" is visually distinct from "nein" (amber, dashed border) and never looks like a confirmed answer.
const TONE_CLASS: Record<ReturnType<typeof alertValueTone>, string> = {
  unknown: "border-2 border-dashed border-amber-500 bg-amber-50 text-amber-900",
  no: "border border-stone-300 bg-stone-100 text-stone-800",
  yes: "border border-emerald-700 bg-emerald-50 text-emerald-900",
  none: "border border-dashed border-stone-300 bg-white italic text-emerald-900/50",
};

const VALUE_HINT: Record<string, string> = {
  unbekannt: "unbekannt (noch nicht geklärt)",
  nein: "nein",
  ja: "ja",
};

/**
 * DOOR1-4: one safety-alert category on the /field card: its latest value (or "nicht erfasst") with who, when and source,
 * and the form to record a new value. Display only (DOOR1-8). The database decides who may record (0073).
 */
export function SafetyAlertRow({ caseId, category, current }: { caseId: string; category: AlertCategoryView; current: AlertValueView | null }) {
  const meta = current ? alertMetaLine(current) : null;
  const tone = alertValueTone(current?.value);
  return (
    <div data-testid={`alert-${category.code}`} className="grid gap-1 rounded-lg bg-stone-50 p-2">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <span className="text-sm font-semibold">{category.label}</span>
        <span data-testid="alert-value" data-tone={tone} className={`rounded-full px-3 py-0.5 text-xs font-bold ${TONE_CLASS[tone]}`}>
          {alertValueText(current?.value)}
        </span>
      </div>
      {current?.note && <p data-testid="alert-note" className="text-sm">{current.note}</p>}
      {meta && <p data-testid="alert-meta" className="text-xs text-emerald-900/60">{meta}</p>}
      <SafetyAlertForm caseId={caseId} category={category} label="Ändern" defaultSource="team" />
    </div>
  );
}

export type AccessHistoryEntry = AlertValueView & { from_intake: boolean | null };

/**
 * DOOR1-13 (migration 0080): the one "Zugang" line of the card. The latest access-arrangement value (who, when, source);
 * without one the intake note "aus der Aufnahme" with the intake date; neither: "nicht erfasst". Once a value exists,
 * the intake note appears only in the history, as its earliest entry. Display only (DOOR1-8).
 */
export function AccessRow({
  caseId, category, current, intakeNote, intakeOn, history,
}: {
  caseId: string;
  category: AlertCategoryView | null;
  current: AlertValueView | null;
  intakeNote: string | null;
  intakeOn: string | null;
  history: AccessHistoryEntry[];
}) {
  const line = accessLine({ intakeNote, intakeOn, current });
  const tone = line.kind === "value" ? alertValueTone(current?.value) : "none";
  const past = accessHistory(history);
  return (
    <div data-testid="alert-access_arrangement" data-access-kind={line.kind} className="grid gap-1 rounded-lg bg-stone-50 p-2">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <span className="text-sm font-semibold">Zugang</span>
        {line.kind !== "intake" && (
          <span data-testid="alert-value" data-tone={tone} className={`rounded-full px-3 py-0.5 text-xs font-bold ${TONE_CLASS[tone]}`}>
            {line.kind === "value" ? line.value : line.text}
          </span>
        )}
      </div>
      {line.kind === "value" && line.note && <p data-testid="alert-note" className="text-sm">{line.note}</p>}
      {line.kind === "intake" && <p data-testid="alert-note" className="text-sm">{line.note}</p>}
      {line.kind !== "none" && line.meta && <p data-testid="alert-meta" className="text-xs text-emerald-900/60">{line.meta}</p>}
      {past.length > 0 && (
        <details data-testid="alert-history" className="text-xs">
          <summary className="min-h-11 cursor-pointer py-2 font-semibold">Verlauf ({past.length})</summary>
          <ol className="grid gap-1">
            {past.map((h, i) => (
              <li key={i} data-testid="alert-history-entry" className="rounded border border-stone-200 bg-white p-2">
                {h.value && <span className="font-semibold">{h.value}</span>}
                {h.note && <p className="text-sm">{h.note}</p>}
                <p className="text-emerald-900/60">{h.meta}</p>
              </li>
            ))}
          </ol>
        </details>
      )}
      {category && <SafetyAlertForm caseId={caseId} category={category} label="Ändern" defaultSource="team" />}
    </div>
  );
}

/**
 * DOOR1-3/-4 record form, on the /field card and at intake. "unbekannt" is offered first and preselected; "ja" needs the
 * note; for the access arrangement the note never holds a code ("Bitte keinen Code erfassen").
 */
export default function SafetyAlertForm({
  caseId,
  category,
  label = "Erfassen",
  defaultSource,
  onSaved,
}: {
  caseId: string;
  category: AlertCategoryView;
  label?: string;
  defaultSource: (typeof ALERT_SOURCES)[number];
  onSaved?: () => void;
}) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit(form: FormData) {
    const value = String(form.get("value") ?? "");
    const note = String(form.get("note") ?? "");
    const source = String(form.get("source") ?? "");
    const problem = alertValueError(value, note, category.refuses_codes);
    if (problem) return setError(problem);
    setPending(true);
    setError(null);
    const result = await recordSafetyAlertValue({
      caseId, category: category.code, value, note, source, refusesCodes: category.refuses_codes, idempotencyKey: crypto.randomUUID(),
    });
    setPending(false);
    if (!result.ok) return setError(result.error);
    setOpen(false);
    onSaved?.();
    router.refresh();
  }

  if (!open) {
    return (
      <button type="button" onClick={() => setOpen(true)} className="min-h-11 justify-self-start rounded-lg border border-emerald-800 px-3 text-sm font-semibold text-emerald-900">
        {label}
      </button>
    );
  }
  const noteId = `alert-note-${caseId}-${category.code}`;
  return (
    // onSubmit, not a form action: React resets a form after its action, which would drop the chosen value and source
    // after a refused attempt (e.g. "Bitte keinen Code erfassen") and save "unbekannt" on the next tap.
    <form
      onSubmit={(e) => { e.preventDefault(); void submit(new FormData(e.currentTarget)); }}
      aria-label={category.label}
      className="grid gap-2 text-sm"
    >
      <fieldset className="grid gap-1">
        <legend className="text-xs font-semibold">{category.label}</legend>
        <div className="flex flex-wrap gap-3">
          {ALERT_VALUES.map((v) => (
            <label key={v} className="flex min-h-11 items-center gap-2">
              <input type="radio" name="value" value={v} defaultChecked={v === "unbekannt"} className="size-5" />
              <span>{VALUE_HINT[v]}</span>
            </label>
          ))}
        </div>
      </fieldset>
      <label className="grid gap-1" htmlFor={noteId}>
        <span className="text-xs font-semibold">Notiz (bei «ja» nötig)</span>
        <textarea id={noteId} name="note" maxLength={ALERT_NOTE_MAX} rows={2} aria-describedby={`${noteId}-help`}
                  className="rounded-lg border border-stone-300 bg-white p-2" />
        {category.help_text && <span id={`${noteId}-help`} className="text-xs text-emerald-900/70">{category.help_text}</span>}
      </label>
      <label className="grid gap-1">
        <span className="text-xs font-semibold">Quelle</span>
        <select name="source" defaultValue={defaultSource} className="min-h-11 rounded-lg border border-stone-300 bg-white px-2">
          {ALERT_SOURCES.map((s) => <option key={s} value={s}>{ALERT_SOURCE_LABEL[s]}</option>)}
        </select>
      </label>
      {error && (
        <p role="alert" data-testid="command-error" className="rounded-lg border border-rose-300 bg-rose-50 p-2 font-semibold text-rose-800">{error}</p>
      )}
      <div className="grid grid-cols-2 gap-2">
        <button type="submit" disabled={pending} className="min-h-11 rounded-lg bg-emerald-800 font-bold text-white disabled:opacity-60">
          {pending ? "Wird gespeichert …" : "Speichern"}
        </button>
        <button type="button" onClick={() => { setOpen(false); setError(null); }} className="min-h-11 rounded-lg border border-stone-300 font-semibold">
          Abbrechen
        </button>
      </div>
    </form>
  );
}
