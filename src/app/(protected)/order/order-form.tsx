"use client";

import { useRouter } from "next/navigation";
import { useEffect, useRef, useState, useTransition } from "react";
import { confirmClientOrder, previewClientOrder, type OrderFields, type OrderPreview } from "@/features/orders/commands";
import type { ActivityOption, PostcodeOption } from "@/features/orders/queries";
import {
  EMPTY_ORDER_FORM,
  GRADE_OPTIONS,
  dateLabel,
  dateUnknownShown,
  levelActivityConflictText,
  orderFieldControlId,
  orderFieldProblemId,
  orderFieldsFrom,
  orderInfoText,
  orderProblemField,
  orderProblemText,
  orderProblemsByField,
  orderStepAfterPreview,
  radiusLine,
  resolveOrderDate,
  shiftLabelLine,
  type OrderFormField,
  type OrderFormState,
} from "@/features/orders/rules";

const field = "min-h-11 w-full min-w-0 rounded-lg border border-stone-300 bg-white px-3";

/**
 * BK-a (ADR-194): the order form (no AI; BK-d adds the capture). Every required field is entered by the client; the
 * date words resolve to a concrete date only when they admit exactly one (AUT-120), otherwise the client picks. The
 * summary (UXR-196, UXR-197) comes from the database preview; nothing is written before «Bestätigen & Absenden».
 * UXR-200: when the preview names problems, the form stays: a list at its top (focus, each item a link to its field)
 * and a line under each field (`aria-invalid`, `aria-describedby`); the summary opens only with zero problems.
 * UXR-201: «Datum nicht erkannt» appears only after the client left the date field.
 */
export default function OrderForm({ accountId, today, postcodes, activities }: {
  accountId: string;
  today: string;
  postcodes: PostcodeOption[];
  activities: ActivityOption[];
}) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [form, setForm] = useState<OrderFormState>({ ...EMPTY_ORDER_FORM });
  const { dateWords, picked, startTime, endTime, postcode, grade, tags, required, radius } = form;
  const [problems, setProblems] = useState<string[]>([]);
  // BK-b2 / CGR-216: the activities the database named for `level_activity_conflict` (shown by name, never dropped).
  const [conflicts, setConflicts] = useState<string[]>([]);
  const activityLabels = Object.fromEntries(activities.map((a) => [a.code, a.label_de]));
  const problemText = (code: string) =>
    code === "level_activity_conflict" ? levelActivityConflictText(grade, conflicts, activityLabels) : orderProblemText(code);
  const [dateLeft, setDateLeft] = useState(false);
  const FIELD_OF: Partial<Record<keyof OrderFormState, OrderFormField>> = {
    dateWords: "date", picked: "date", startTime: "startTime", endTime: "endTime", postcode: "postcode",
    grade: "grade", tags: "tags", required: "tags", radius: "radius",
  };
  // A changed field drops its own problems (the next preview checks everything again).
  const clearField = (field: OrderFormField | undefined) =>
    field && setProblems((ps) => ps.filter((c) => orderProblemField(c) !== field));
  const set = <K extends keyof OrderFormState>(key: K, value: OrderFormState[K]) => {
    setForm((f) => ({ ...f, [key]: value }));
    clearField(FIELD_OF[key]);
  };
  const doneRef = useRef<HTMLDivElement>(null);
  const problemsRef = useRef<HTMLDivElement>(null);
  const grouped = orderProblemsByField(problems);
  const invalid = (f: OrderFormField) => (grouped.byField[f] ? true : undefined);
  const describedBy = (f: OrderFormField, extra?: string) =>
    [grouped.byField[f] ? orderFieldProblemId(f) : null, extra ?? null].filter(Boolean).join(" ") || undefined;
  const fieldProblem = (f: OrderFormField) =>
    grouped.byField[f] ? (
      <p id={orderFieldProblemId(f)} data-testid={orderFieldProblemId(f)} className="text-sm font-semibold text-rose-800">
        {grouped.byField[f]!.map(problemText).join(" ")}
      </p>
    ) : null;
  const [summary, setSummary] = useState<{ fields: OrderFields; preview: OrderPreview; key: string } | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState<string | null>(null);

  const resolution = resolveOrderDate(dateWords, today);
  const current = (): OrderFields => orderFieldsFrom(form, accountId, today);

  // UXR-199: after a confirmed order the focus moves to the confirmation naming it (the form is already empty).
  useEffect(() => {
    if (done && !summary) doneRef.current?.focus();
  }, [done, summary]);

  // UXR-200: a preview with problems moves the focus to the list naming them.
  const [problemsShownAt, setProblemsShownAt] = useState(0);
  useEffect(() => {
    if (problemsShownAt) problemsRef.current?.focus();
  }, [problemsShownAt]);

  const toggle = (list: string[], code: string) => (list.includes(code) ? list.filter((c) => c !== code) : [...list, code]);

  if (summary) {
    const { preview } = summary;
    const label = shiftLabelLine(preview.shiftLabel);
    const blocked = preview.problems.length > 0;
    return (
      <section aria-label="Zusammenfassung" data-testid="order-summary" className="grid gap-3 rounded-xl border border-stone-200 bg-white p-4">
        <h2 className="text-lg font-bold">Zusammenfassung</h2>
        {preview.sentence && <p data-testid="order-sentence" className="break-words font-semibold">{preview.sentence}</p>}
        {label && <p data-testid="order-label">{label}</p>}
        {preview.weekend && <p>Wochenende</p>}
        <p>Tätigkeiten: {summary.fields.activityTags.map((c) => activities.find((a) => a.code === c)?.label_de ?? c).join(", ")}</p>
        {summary.fields.requiredTags.length > 0 && (
          <p>Zwingend: {summary.fields.requiredTags.map((c) => activities.find((a) => a.code === c)?.label_de ?? c).join(", ")}</p>
        )}
        <p data-testid="order-radius">{radiusLine(summary.fields.radiusKm)}</p>
        {preview.info.map((c) => {
          const text = orderInfoText(c, preview.sameOrderSentence);
          // CGR-217: neutral information (not role="alert", not red, not amber); the confirm stays enabled.
          return text ? <p key={c} data-testid="order-info" className="rounded-lg border border-sky-200 bg-sky-50 p-3 text-sky-950">{text}</p> : null;
        })}
        {blocked && (
          <ul role="alert" className="grid gap-1 font-semibold text-rose-800">
            {preview.problems.map((p) => <li key={p}>{orderProblemText(p)}</li>)}
          </ul>
        )}
        {error && <p role="alert" className="font-semibold text-rose-800">{error}</p>}
        <div className="flex flex-wrap gap-2">
          <button type="button" disabled={pending || blocked}
            className="min-h-11 rounded-lg bg-emerald-800 px-4 font-semibold text-white disabled:opacity-60"
            onClick={() => start(async () => {
              setError(null);
              const r = await confirmClientOrder({ ...summary.fields, idempotencyKey: summary.key });
              if (r.ok) {
                // UXR-199: clear the form, so pressing on again cannot send the same order a second time.
                setForm({ ...EMPTY_ORDER_FORM });
                setDone(preview.sentence);
                setSummary(null);
                router.refresh();
              } else {
                setError(r.error);
              }
            })}>
            Bestätigen &amp; Absenden
          </button>
          <button type="button" disabled={pending} onClick={() => setSummary(null)}
            className="min-h-11 rounded-lg border border-stone-400 px-4 font-semibold">
            Ändern
          </button>
        </div>
      </section>
    );
  }

  return (
    <form
      aria-label="Auftrag"
      className="grid min-w-0 gap-4 rounded-xl border border-stone-200 bg-white p-4"
      onSubmit={(e) => {
        e.preventDefault();
        setError(null);
        setDone(null);
        const fields = current();
        start(async () => {
          const r = await previewClientOrder(fields);
          if (!r.ok) {
            setError(r.error);
          } else if (orderStepAfterPreview(r.preview.problems) === "summary") {
            setProblems([]);
            setSummary({ fields, preview: r.preview, key: crypto.randomUUID() });
          } else {
            setProblems(r.preview.problems);
            setConflicts(r.preview.conflictActivities);
            setProblemsShownAt(Date.now());
          }
        });
      }}
    >
      <div ref={doneRef} tabIndex={-1} role="status" data-testid="order-done" className="text-sm font-semibold text-emerald-900">
        {done && <p>Auftrag bestätigt: {done}</p>}
      </div>
      {problems.length > 0 && (
        <div ref={problemsRef} tabIndex={-1} role="alert" data-testid="order-problems" className="grid gap-1 text-sm font-semibold text-rose-800">
          <p>Bitte diese Angaben prüfen:</p>
          <ul className="grid gap-1">
            {grouped.form.map((c) => <li key={c}>{problemText(c)}</li>)}
            {(Object.keys(grouped.byField) as OrderFormField[]).flatMap((f) =>
              grouped.byField[f]!.map((c) => (
                <li key={c}><a href={`#${orderFieldControlId(f)}`} className="underline">{problemText(c)}</a></li>
              )),
            )}
          </ul>
        </div>
      )}
      <label className="grid gap-1 text-sm font-semibold">
        Datum (z. B. «Sonntag» oder 22.11.2026)
        <input name="date" id={orderFieldControlId("date")} value={dateWords}
          aria-invalid={invalid("date") ?? (dateUnknownShown(resolution, dateLeft) || undefined)}
          aria-describedby={describedBy("date", dateUnknownShown(resolution, dateLeft) ? "order-date-unknown" : undefined)}
          onBlur={() => setDateLeft(true)}
          onChange={(e) => { const v = e.target.value; setDateLeft(false); setForm((f) => ({ ...f, dateWords: v, picked: null })); clearField("date"); }} className={field} />
      </label>
      {fieldProblem("date")}
      {resolution.kind === "date" && <p data-testid="order-date">{dateLabel(resolution.date)}</p>}
      {resolution.kind === "relative_date_ambiguous" && (
        <fieldset className="grid gap-1 text-sm" data-testid="order-date-pick">
          <legend className="font-semibold">Welcher Tag ist gemeint?</legend>
          {resolution.candidates.map((c) => (
            <label key={c} className="flex min-h-11 items-center gap-2">
              <input type="radio" name="datePick" value={c} checked={picked === c} onChange={() => set("picked", c)} />
              {dateLabel(c)}
            </label>
          ))}
        </fieldset>
      )}
      {dateUnknownShown(resolution, dateLeft) && <p id="order-date-unknown" role="alert" data-testid="order-date-unknown" className="text-sm font-semibold text-rose-800">Datum nicht erkannt. Bitte als Wochentag, «morgen» oder TT.MM.JJJJ angeben.</p>}
      <div className="grid grid-cols-2 gap-3">
        <div className="grid content-start gap-1">
        <label className="grid gap-1 text-sm font-semibold">
          Beginn
          <input type="time" name="startTime" id={orderFieldControlId("startTime")} aria-invalid={invalid("startTime")} aria-describedby={describedBy("startTime")}
            value={startTime} onChange={(e) => set("startTime", e.target.value)} className={field} />
        </label>
        {fieldProblem("startTime")}
        </div>
        <div className="grid content-start gap-1">
        <label className="grid gap-1 text-sm font-semibold">
          Ende
          <input type="time" name="endTime" id={orderFieldControlId("endTime")} aria-invalid={invalid("endTime")} aria-describedby={describedBy("endTime")}
            value={endTime} onChange={(e) => set("endTime", e.target.value)} className={field} />
        </label>
        {fieldProblem("endTime")}
        </div>
      </div>
      <label className="grid gap-1 text-sm font-semibold">
        Einsatzort (Postleitzahl)
        <select name="postcode" id={orderFieldControlId("postcode")} aria-invalid={invalid("postcode")} aria-describedby={describedBy("postcode")}
          value={postcode} onChange={(e) => set("postcode", e.target.value)} className={field}>
          <option value="">bitte wählen</option>
          {postcodes.map((p) => <option key={p.postcode} value={p.postcode}>{p.postcode} {p.place_name}</option>)}
        </select>
      </label>
      {fieldProblem("postcode")}
      <fieldset id={orderFieldControlId("grade")} tabIndex={-1} aria-describedby={describedBy("grade")} className="grid gap-1 text-sm">
        <legend className="font-semibold">Stufe</legend>
        <div className="flex flex-wrap gap-3">
          {GRADE_OPTIONS.map((g) => (
            <label key={g.value} className="flex min-h-11 items-center gap-2">
              <input type="radio" name="grade" value={g.value} checked={grade === g.value} onChange={() => set("grade", g.value)} />
              {g.label}
            </label>
          ))}
        </div>
        {fieldProblem("grade")}
      </fieldset>
      <fieldset id={orderFieldControlId("tags")} tabIndex={-1} aria-describedby={describedBy("tags")} className="grid gap-1 text-sm">
        <legend className="font-semibold">Tätigkeiten</legend>
        {fieldProblem("tags")}
        <ul className="grid gap-1">
          {activities.map((a) => (
            <li key={a.code} className="flex flex-wrap items-center gap-x-4">
              <label className="flex min-h-11 min-w-0 items-center gap-2">
                <input type="checkbox" name="tag" value={a.code} aria-invalid={invalid("tags")} checked={tags.includes(a.code)} onChange={() => set("tags", toggle(tags, a.code))} />
                <span className="break-words">{a.label_de}</span>
              </label>
              {tags.includes(a.code) && (
                <label className="flex min-h-11 items-center gap-2 text-secondary">
                  <input type="checkbox" name="required" value={a.code} checked={required.includes(a.code)} onChange={() => set("required", toggle(required, a.code))} />
                  zwingend
                </label>
              )}
            </li>
          ))}
        </ul>
      </fieldset>
      <label className="grid gap-1 text-sm font-semibold">
        Höchstdistanz in km (freiwillig)
        <input name="radius" id={orderFieldControlId("radius")} aria-invalid={invalid("radius")} aria-describedby={describedBy("radius")}
          inputMode="decimal" value={radius} onChange={(e) => set("radius", e.target.value)} className={field} />
      </label>
      {fieldProblem("radius")}
      {error && <p role="alert" className="font-semibold text-rose-800">{error}</p>}
      <button type="submit" disabled={pending} className="min-h-11 rounded-lg bg-emerald-800 px-4 font-semibold text-white disabled:opacity-60">
        Weiter zur Zusammenfassung
      </button>
    </form>
  );
}
