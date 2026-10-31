"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { formatDayLabel } from "@/features/field/rules";
import { HeaderMenu } from "@/components/layout/Sidebar";
import { PAGE_LABEL } from "@/lib/auth/nav";
import { acknowledgeWorkingTimeNotice, confirmWorkingDay, exportWorkingMonth } from "@/features/work/commands";
import { myContractEndText, type MyContractEnd } from "@/features/contract-end/rules";
import type { DayVersion } from "@/features/work/queries";
import {
  CORRECTED_MARK, KIND_LABEL, NOTICE_DRAFT_HINT, NOTICE_HEADINGS, NOTICE_LEAD, NOTICE_PARAGRAPHS, NOTICE_TITLE, OUTSIDE_KINDS, REASON_CODES, REASON_LABEL,
  VISIT_TIME_HINT, VISIT_TIME_LINK, buildPayload, monthOf, nextDate, openQuestions, proposalSegments, unexportedText,
  visitCorrectionHref, visitSegmentChanged, zurichInstant, zurichTime,
  type DayDraft, type OutsideKind, type ProposalRow, type ReasonCode, type VisitKind,
} from "@/features/work/rules";

type Props = {
  day: string;
  today: string;
  previousDay: string;
  nextDay: string | null;
  acknowledged: boolean;
  proposal: ProposalRow[];
  versions: DayVersion[];
  /** WORK1-C3 (d): her own number of confirmed days not yet exported (null when not available). */
  unexported: number | null;
  /** ADM2-14 (a): her recorded contract end within the next 14 days (null otherwise). */
  contractEnd?: MyContractEnd | null;
};

const primary = "min-h-11 rounded-lg bg-emerald-800 px-4 text-sm font-bold text-white disabled:opacity-60";
const secondary = "min-h-11 rounded-lg border border-stone-400 bg-white px-3 text-sm font-semibold disabled:opacity-60";
const input = "min-h-11 rounded-lg border border-stone-300 bg-white px-2";

function hhmm(iso: string | null): string {
  return iso ? zurichTime(iso) : "";
}

function Header({ day, today, previousDay, nextDay }: Pick<Props, "day" | "today" | "previousDay" | "nextDay">) {
  return (
    <header className="sticky top-0 z-10 bg-emerald-950 px-4 pb-4 pt-3 text-white shadow-md">
      <div className="mx-auto flex max-w-xl flex-wrap items-center justify-between gap-x-2 gap-y-1">
        <p className="text-xs font-semibold uppercase tracking-widest text-emerald-200">{PAGE_LABEL.work}</p>
        <Link href={`/field?datum=${day}`} className="ml-auto flex min-h-11 items-center rounded-lg px-3 text-sm font-semibold text-emerald-100 underline underline-offset-4">
          {PAGE_LABEL.field}
        </Link>
        {/* UX1-20: the role's menu (and "Meine Einstellungen") from the nurse's screens, inside the first viewport. */}
        <HeaderMenu active="work" />
      </div>
      <div className="mx-auto mt-1 max-w-xl">
        <h1 className="text-xl font-bold leading-tight">{formatDayLabel(day)}</h1>
        <nav aria-label="Tag wechseln" className="mt-3 grid grid-cols-3 gap-2 text-sm font-semibold">
          <Link href={`/work?datum=${previousDay}`} className="flex min-h-11 items-center justify-center rounded-lg bg-emerald-900">← Vortag</Link>
          <Link href="/work" aria-current={day === today ? "date" : undefined} className="flex min-h-11 items-center justify-center rounded-lg bg-emerald-900">Heute</Link>
          {nextDay ? (
            <Link href={`/work?datum=${nextDay}`} className="flex min-h-11 items-center justify-center rounded-lg bg-emerald-900">Folgetag →</Link>
          ) : <span />}
        </nav>
      </div>
    </header>
  );
}

function Notice() {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  return (
    <section aria-label={NOTICE_TITLE} className="grid gap-3 rounded-2xl border border-stone-300 bg-white p-4">
      <h2 className="text-lg font-bold">{NOTICE_TITLE}</h2>
      {/* UX1-21: lead line and one heading per paragraph (lca 11:41); every paragraph word for word, nothing collapsed. */}
      <p data-testid="notice-lead" className="text-sm leading-relaxed">{NOTICE_LEAD}</p>
      {NOTICE_PARAGRAPHS.map((p, i) => (
        <div key={p} className="grid gap-1">
          <h3 data-testid="notice-heading" className="text-base font-bold">{NOTICE_HEADINGS[i]}</h3>
          <p className="text-sm leading-relaxed">{p}</p>
        </div>
      ))}
      <p className="text-xs text-stone-600">{NOTICE_DRAFT_HINT}</p>
      {error && <p role="alert" className="text-sm font-semibold text-red-800">{error}</p>}
      <button type="button" disabled={pending} className={primary} onClick={() => start(async () => {
        const r = await acknowledgeWorkingTimeNotice({ idempotencyKey: crypto.randomUUID() });
        if (r.ok) router.refresh(); else setError(r.message || "Nicht möglich.");
      })}>
        Gelesen und verstanden
      </button>
    </section>
  );
}

type Row = { start: string; end: string };
type OutRow = Row & { kind: OutsideKind };

function draftFrom(proposal: ProposalRow[], latest: DayVersion | undefined): Omit<DayDraft, "date"> {
  if (!latest) {
    // Nothing is pre-answered (WORK1-2): start, end and both questions stay empty.
    return { dayStart: "", dayEnd: "", segments: proposalSegments(proposal), breaks: null, outside: null, reason: null, note: "" };
  }
  const visit = latest.entries.filter((e) => ["travel", "care", "visit_pause"].includes(e.kind))
    .map((e) => ({ kind: e.kind as VisitKind, start: e.start, end: e.end, origin: { start: e.start, end: e.end, corrected: false } }));
  const breaks = latest.breaks_answer === "none" ? "none" as const
    : latest.entries.filter((e) => e.kind === "break").map((e) => ({ start: zurichTime(e.start), end: zurichTime(e.end) }));
  const outside = latest.outside_answer === "none" ? "none" as const
    : latest.entries.filter((e) => (OUTSIDE_KINDS as readonly string[]).includes(e.kind))
      .map((e) => ({ kind: e.kind as OutsideKind, start: zurichTime(e.start), end: zurichTime(e.end) }));
  return { dayStart: zurichTime(latest.day_start), dayEnd: zurichTime(latest.day_end), segments: visit, breaks, outside, reason: null, note: "" };
}

function IntervalRows<T extends Row>({ legend, rows, onChange, withKind }: {
  legend: string; rows: T[]; onChange: (rows: T[]) => void; withKind?: boolean;
}) {
  return (
    <div className="grid gap-2">
      {rows.map((r, i) => (
        <div key={i} className="grid grid-cols-[1fr_1fr_auto] items-end gap-2" role="group" aria-label={`Eintrag ${i + 1}`}>
          {withKind && (
            <label className="col-span-3 grid gap-1 text-sm">
              Art
              <select className={input} value={(r as unknown as OutRow).kind}
                onChange={(e) => onChange(rows.map((x, j) => (j === i ? { ...x, kind: e.target.value as OutsideKind } : x)))}>
                {OUTSIDE_KINDS.map((k) => <option key={k} value={k}>{KIND_LABEL[k]}</option>)}
              </select>
            </label>
          )}
          <label className="grid gap-1 text-sm">
            Von
            <input type="time" className={input} value={r.start} onChange={(e) => onChange(rows.map((x, j) => (j === i ? { ...x, start: e.target.value } : x)))} />
          </label>
          <label className="grid gap-1 text-sm">
            Bis
            <input type="time" className={input} value={r.end} onChange={(e) => onChange(rows.map((x, j) => (j === i ? { ...x, end: e.target.value } : x)))} />
          </label>
          <button type="button" className={secondary} onClick={() => onChange(rows.filter((_, j) => j !== i))}>Entfernen</button>
        </div>
      ))}
    </div>
  );
}

function Question<T extends Row>({ legend, value, onChange, empty, withKind }: {
  legend: string; value: "none" | T[] | null; onChange: (v: "none" | T[] | null) => void; empty: T; withKind?: boolean;
}) {
  const listed = Array.isArray(value);
  return (
    <fieldset className="grid gap-2 rounded-xl border border-stone-300 bg-white p-3">
      <legend className="px-1 font-semibold">{legend}</legend>
      <div className="grid grid-cols-2 gap-2">
        <label className="flex min-h-11 items-center gap-2 rounded-lg border border-stone-300 px-3">
          <input type="radio" name={legend} checked={value === "none"} onChange={() => onChange("none")} /> Keine
        </label>
        <label className="flex min-h-11 items-center gap-2 rounded-lg border border-stone-300 px-3">
          <input type="radio" name={legend} checked={listed} onChange={() => onChange(listed ? value : [{ ...empty }])} /> Ja, eintragen
        </label>
      </div>
      {listed && (
        <>
          <IntervalRows legend={legend} rows={value} onChange={(rows) => onChange(rows)} withKind={withKind} />
          <button type="button" className={secondary} onClick={() => onChange([...value, { ...empty }])}>Weitere hinzufügen</button>
        </>
      )}
    </fieldset>
  );
}

function DayForm({ day, proposal, versions }: Pick<Props, "day" | "proposal" | "versions">) {
  const router = useRouter();
  const latest = versions[0];
  const [d, setD] = useState(() => draftFrom(proposal, latest));
  const [correcting, setCorrecting] = useState(!latest);
  const [pending, start] = useTransition();
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const marks = proposal.filter((p) => p.kind === "report_signed");
  const open = openQuestions(d);
  const set = (patch: Partial<typeof d>) => setD((x) => ({ ...x, ...patch }));
  // A changed clock time is read on the day, or on the next day when it lies before the day's start (night shift).
  const instantFor = (t: string) => (d.dayStart && t < d.dayStart ? zurichInstant(nextDate(day), t) : zurichInstant(day, t));

  const confirm = () => start(async () => {
    setMsg(null);
    const r = await confirmWorkingDay({ day, payload: buildPayload({ date: day, ...d }), idempotencyKey: crypto.randomUUID() });
    setMsg({ ok: r.ok, text: r.message });
    if (r.ok) router.refresh();
  });

  return (
    <div className="grid gap-4">
      <section aria-label="Vorschlag aus deinen Einsätzen" className="grid gap-2 rounded-2xl border border-stone-300 bg-white p-4">
        <h2 className="font-bold">{latest && !correcting ? `Bestätigt (Fassung ${latest.version})` : "Vorschlag aus deinen Einsätzen"}</h2>
        {d.segments.length === 0 && <p className="text-sm text-stone-700">Keine Einsatzzeiten an diesem Tag.</p>}
        <ol className="grid gap-2">
          {d.segments.map((s, i) => (
            <li key={i} className="grid grid-cols-[1fr_auto_auto] items-center gap-2 text-sm" aria-label={`Abschnitt ${i + 1}: ${KIND_LABEL[s.kind]}`}>
              <span>{KIND_LABEL[s.kind]}</span>
              <input aria-label={`Abschnitt ${i + 1} von`} type="time" className={input} disabled={!correcting} value={hhmm(s.start)}
                onChange={(e) => set({ segments: d.segments.map((x, j) => (j === i ? { ...x, start: instantFor(e.target.value) } : x)) })} />
              <input aria-label={`Abschnitt ${i + 1} bis`} type="time" className={input} disabled={!correcting} value={hhmm(s.end)}
                placeholder="Ende offen"
                onChange={(e) => set({ segments: d.segments.map((x, j) => (j === i ? { ...x, end: instantFor(e.target.value) } : x)) })} />
              {!s.end && <span className="col-span-3 text-xs font-semibold text-amber-900">Ende offen: bitte eintragen.</span>}
              {s.origin?.corrected && !visitSegmentChanged(s) && (
                <span data-testid="segment-corrected" className="col-span-3 text-xs text-stone-700">{CORRECTED_MARK}</span>
              )}
              {visitSegmentChanged(s) && (
                <p data-testid="visit-time-hint" className="col-span-3 rounded-lg bg-amber-50 p-2 text-xs text-amber-950">
                  {VISIT_TIME_HINT}{" "}
                  <Link href={visitCorrectionHref(s.origin, day)} className="font-semibold underline underline-offset-2">{VISIT_TIME_LINK}</Link>
                </p>
              )}
            </li>
          ))}
        </ol>
        {marks.map((m) => (
          <p key={m.seq} className="text-xs text-stone-700">
            {KIND_LABEL.report_signed} um {hhmm(m.starts_at)}. Später geschriebene Berichtszeit als «Administration» eintragen.
          </p>
        ))}
      </section>

      <section aria-label="Beginn und Ende" className="grid grid-cols-2 gap-2 rounded-2xl border border-stone-300 bg-white p-4">
        <label className="grid gap-1 text-sm font-semibold">
          Beginn des Arbeitstags?
          <input type="time" className={input} disabled={!correcting} value={d.dayStart} onChange={(e) => set({ dayStart: e.target.value })} />
        </label>
        <label className="grid gap-1 text-sm font-semibold">
          Ende des Arbeitstags?
          <input type="time" className={input} disabled={!correcting} value={d.dayEnd} onChange={(e) => set({ dayEnd: e.target.value })} />
        </label>
      </section>

      {correcting ? (
        <>
          <Question legend="Pausen von 30 Minuten oder mehr?" value={d.breaks} empty={{ start: "", end: "" }}
            onChange={(v) => set({ breaks: v })} />
          <Question legend="Arbeit ausserhalb der Einsätze?" value={d.outside} empty={{ kind: "administration" as OutsideKind, start: "", end: "" }}
            onChange={(v) => set({ outside: v })} withKind />
          {latest && (
            <fieldset className="grid gap-2 rounded-xl border border-stone-300 bg-white p-3">
              <legend className="px-1 font-semibold">Grund der Korrektur</legend>
              <select aria-label="Grund" className={input} value={d.reason ?? ""} onChange={(e) => set({ reason: (e.target.value || null) as ReasonCode | null })}>
                <option value="">Bitte wählen</option>
                {REASON_CODES.map((c) => <option key={c} value={c}>{REASON_LABEL[c]}</option>)}
              </select>
              <label className="grid gap-1 text-sm">
                Notiz (nur für dich, höchstens 200 Zeichen)
                <textarea className={`${input} py-2`} maxLength={200} value={d.note ?? ""} onChange={(e) => set({ note: e.target.value })} />
              </label>
            </fieldset>
          )}
          {open.length > 0 && <p className="text-sm text-stone-700">Noch offen: {open.map((q) => ({ day_start: "Beginn", day_end: "Ende", breaks: "Pausen", outside_work: "Arbeit ausserhalb der Einsätze" })[q]).join(", ")}.</p>}
          <button type="button" className={primary} disabled={pending || open.length > 0 || (Boolean(latest) && !d.reason)} onClick={confirm}>
            {latest ? "Korrektur bestätigen" : "Arbeitstag bestätigen"}
          </button>
        </>
      ) : (
        latest && (
          <section aria-label="Bestätigter Tag" className="grid gap-2 rounded-2xl border border-emerald-300 bg-emerald-50 p-4 text-sm">
            <p>Pausen von 30 Minuten oder mehr: {latest.breaks_answer === "none" ? "keine" : latest.entries.filter((e) => e.kind === "break").map((e) => `${hhmm(e.start)}–${hhmm(e.end)}`).join(", ")}</p>
            <p>Arbeit ausserhalb der Einsätze: {latest.outside_answer === "none" ? "keine" : latest.entries.filter((e) => (OUTSIDE_KINDS as readonly string[]).includes(e.kind)).map((e) => `${KIND_LABEL[e.kind]} ${hhmm(e.start)}–${hhmm(e.end)}`).join(", ")}</p>
            <p data-testid="paid-minutes">Bezahlte Arbeitszeit (ohne Pausen): {latest.paid_minutes} Min.</p>
            <button type="button" className={secondary} onClick={() => { setCorrecting(true); setMsg(null); }}>Korrigieren</button>
          </section>
        )
      )}
      {msg && <p role={msg.ok ? "status" : "alert"} className={`text-sm font-semibold ${msg.ok ? "text-emerald-900" : "text-red-800"}`}>{msg.text}</p>}

      {versions.length > 1 && (
        <section aria-label="Frühere Fassungen" className="grid gap-1 rounded-2xl border border-stone-300 bg-white p-4 text-sm">
          <h2 className="font-bold">Frühere Fassungen</h2>
          <ol className="grid gap-1">
            {versions.slice(1).map((v) => (
              <li key={v.version}>
                Fassung {v.version}: {hhmm(v.day_start)}–{hhmm(v.day_end)}, {v.paid_minutes} Min.
                {v.reason_code && ` · ${REASON_LABEL[v.reason_code as ReasonCode] ?? v.reason_code}`}
                {v.note && ` · ${v.note}`}
              </li>
            ))}
          </ol>
        </section>
      )}
    </div>
  );
}

function Export({ day, unexported }: { day: string; unexported: number | null }) {
  const [month, setMonth] = useState(monthOf(day));
  const [pending, start] = useTransition();
  const [msg, setMsg] = useState<string | null>(null);
  return (
    <section aria-label="Monat exportieren" className="grid gap-2 rounded-2xl border border-stone-300 bg-white p-4">
      <h2 className="font-bold">Monat exportieren</h2>
      <p className="text-sm text-stone-700">Nur bestätigte Tage. Die Datei enthält keine Klient:innen, Einsätze oder Notizen.</p>
      {unexportedText(unexported) && (
        // WORK1-C3 (d): her own count, with a prompt to export (nothing is exported on her behalf).
        <p data-testid="unexported-days" className={unexported ? "text-sm font-semibold text-amber-900" : "text-sm text-stone-700"}>
          {unexportedText(unexported)}
        </p>
      )}
      <label className="grid gap-1 text-sm">
        Monat
        <input type="month" className={input} value={month} onChange={(e) => setMonth(e.target.value)} />
      </label>
      <button type="button" className={secondary} disabled={pending} onClick={() => start(async () => {
        setMsg(null);
        const r = await exportWorkingMonth({ month, idempotencyKey: crypto.randomUUID() });
        if (!r.ok) return setMsg(r.message);
        const url = URL.createObjectURL(new Blob([r.csv], { type: "text/csv;charset=utf-8" }));
        const a = document.createElement("a");
        a.href = url;
        a.download = r.filename;
        document.body.appendChild(a);
        a.click();
        a.remove();
        URL.revokeObjectURL(url);
        setMsg("Datei erstellt.");
      })}>
        Als CSV herunterladen
      </button>
      {msg && <p role="status" className="text-sm font-semibold">{msg}</p>}
    </section>
  );
}

export default function WorkClient(props: Props) {
  return (
    <div className="min-h-screen bg-stone-100 text-emerald-950">
      <Header {...props} />
      <main className="mx-auto grid max-w-xl gap-4 px-4 py-4">
        {props.contractEnd && (
          // ADM2-14 (a): the date her access ends; the count and the export prompt stay in "Monat exportieren".
          <p role="status" data-testid="contract-end-notice" className="rounded-2xl border-2 border-amber-500 bg-amber-50 p-4 text-sm font-semibold text-amber-950">
            {myContractEndText(props.contractEnd)}
          </p>
        )}
        {props.acknowledged ? (
          <>
            <DayForm day={props.day} proposal={props.proposal} versions={props.versions} />
            <Export day={props.day} unexported={props.unexported} />
          </>
        ) : (
          <Notice />
        )}
      </main>
    </div>
  );
}
