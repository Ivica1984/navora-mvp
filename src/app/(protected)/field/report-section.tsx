"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import {
  correctReport,
  countersignReport,
  createReportDraft,
  returnReport,
  signAtCompletion,
  updateReportDraft,
  withdrawReportCorrection,
} from "@/features/field/report-commands";
import { returnConfirmation, reportView, type FieldReport } from "@/features/field/report";

const TONE_CLASS = {
  open: "border-amber-500 bg-amber-50",
  waiting: "border-blue-500 bg-blue-50",
  final: "border-emerald-600 bg-emerald-50",
} as const;

function formatStamp(iso: string | null) {
  if (!iso) return "";
  return new Intl.DateTimeFormat("de-CH", {
    timeZone: "Europe/Zurich", day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit", hourCycle: "h23",
  }).format(new Date(iso));
}

/**
 * F6: the visit report on a completed /field card. The draft is built by the server from
 * times, planned minutes, services and observations (no re-entry); the nurse may add a summary.
 */
export default function ReportSection({
  visitId,
  visitStatus,
  report,
}: {
  visitId: string;
  visitStatus: string | null;
  report: FieldReport | null;
}) {
  const router = useRouter();
  const [mode, setMode] = useState<"idle" | "edit" | "correct" | "withdraw" | "return">("idle");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const view = reportView(visitStatus, report);
  if (!view) return null;

  async function run(call: () => Promise<{ ok: boolean; error?: string }>) {
    setPending(true);
    setError(null);
    const result = await call();
    setPending(false);
    if (!result.ok) {
      setError(result.error ?? "Bericht konnte nicht gespeichert werden.");
      // CSR1 / CGR-02: a refusal means the report or its facts are not what the card shows; reload them.
      router.refresh();
      return;
    }
    setMode("idle");
    router.refresh();
  }

  const summaryOf = (form: FormData) => {
    const text = String(form.get("summary") ?? "").trim();
    return text.length > 0 ? text : null;
  };

  return (
    <section
      aria-label="Bericht"
      data-testid="visit-report"
      className={`mt-3 grid gap-2 rounded-xl border-l-4 p-3 text-sm ${TONE_CLASS[view.tone]}`}
    >
      <div className="flex items-center justify-between gap-2">
        <h3 className="font-bold">Bericht</h3>
        <p data-testid="report-status" className="text-xs font-bold">{view.label}</p>
      </div>

      {report?.summary && mode === "idle" && !(report.status === "draft" && view.actions.includes("sign")) && (
        <p className="whitespace-pre-wrap">{report.summary}</p>
      )}
      {report?.correction_reason && (
        <p className="text-xs text-emerald-900/70">Korrektur: {report.correction_reason}</p>
      )}
      {report?.signed_at && (
        <p className="text-xs text-emerald-900/70">
          Unterschrieben {formatStamp(report.signed_at)}
          {report.i_signed ? " von dir" : report.signed_by_name ? ` von ${report.signed_by_name}` : ""}
          {report.countersigned_at
            ? ` · gegengezeichnet ${formatStamp(report.countersigned_at)}${report.countersigned_by_name ? ` von ${report.countersigned_by_name}` : ""}`
            : ""}
        </p>
      )}
      {view.hint && <p className="text-xs text-emerald-900/70">{view.hint}</p>}
      {report?.returned && report.return_reason && (
        // F6R-7: the reason is shown only to the performer and the team's registered nurses (the database nulls it otherwise).
        <div data-testid="return-reason" className="grid gap-1 rounded-lg border border-amber-300 bg-white p-2 text-xs">
          <p>
            <span className="font-semibold">Zurückgegeben</span>
            {report.returned_at ? ` ${formatStamp(report.returned_at)}` : ""}
            {report.returned_by_name ? ` von ${report.returned_by_name}` : ""}:
          </p>
          <p className="whitespace-pre-wrap">{report.return_reason}</p>
          {report.returned_snapshot != null && (
            <details>
              <summary className="min-h-11 cursor-pointer content-center font-semibold underline underline-offset-4">
                Zurückgegebene Fassung ansehen
              </summary>
              <ReportFacts snapshot={report.returned_snapshot} />
            </details>
          )}
        </div>
      )}

      {error && (
        <p role="alert" data-testid="command-error" className="rounded-lg border border-rose-300 bg-rose-50 p-2 font-semibold text-rose-800">
          {error}
        </p>
      )}

      {view.actions.includes("create") && (
        <form
          action={(form) => run(() => createReportDraft({ visitId, summary: summaryOf(form), idempotencyKey: crypto.randomUUID() }))}
          className="grid gap-2"
        >
          <SummaryField />
          <button type="submit" disabled={pending} className="min-h-11 rounded-lg bg-emerald-800 font-bold text-white disabled:opacity-60">
            {pending ? "Wird gespeichert …" : "Berichtsentwurf erstellen"}
          </button>
          <p className="text-xs text-emerald-900/60">
            Zeiten, geplante Minuten, Leistungen und Beobachtungen übernimmt der Entwurf automatisch.
          </p>
        </form>
      )}

      {mode === "edit" && report && (
        <form
          action={(form) =>
            run(() => updateReportDraft({ reportId: report.report_id, summary: summaryOf(form), idempotencyKey: crypto.randomUUID() }))
          }
          className="grid gap-2"
        >
          <SummaryField initial={report.summary ?? ""} />
          <div className="grid grid-cols-2 gap-2">
            <button type="submit" disabled={pending} className="min-h-11 rounded-lg bg-emerald-800 font-bold text-white disabled:opacity-60">
              {pending ? "Wird gespeichert …" : "Entwurf speichern"}
            </button>
            <button type="button" onClick={() => setMode("idle")} className="min-h-11 rounded-lg border border-stone-300 font-semibold">
              Abbrechen
            </button>
          </div>
        </form>
      )}

      {mode === "correct" && report && (
        <form
          action={(form) =>
            run(() =>
              correctReport({
                reportId: report.report_id,
                reason: String(form.get("reason") ?? ""),
                summary: summaryOf(form),
                idempotencyKey: crypto.randomUUID(),
              }),
            )
          }
          className="grid gap-2"
        >
          <label className="grid gap-1">
            <span className="text-xs font-semibold">Begründung der Korrektur</span>
            <textarea name="reason" required minLength={3} maxLength={300} rows={2} className="rounded-lg border border-stone-300 bg-white p-2" />
          </label>
          <SummaryField initial={report.summary ?? ""} />
          <div className="grid grid-cols-2 gap-2">
            <button type="submit" disabled={pending} className="min-h-11 rounded-lg bg-emerald-800 font-bold text-white disabled:opacity-60">
              {pending ? "Wird gespeichert …" : "Neue Fassung anlegen"}
            </button>
            <button type="button" onClick={() => setMode("idle")} className="min-h-11 rounded-lg border border-stone-300 font-semibold">
              Abbrechen
            </button>
          </div>
          <p className="text-xs text-emerald-900/60">
            Die abgeschlossene Fassung bleibt unverändert; die neue Fassung wird erneut unterschrieben.
          </p>
        </form>
      )}

      {mode === "idle" && report && view.actions.includes("sign") && (
        // F7: review and sign at completion, one confirmation; the summary is optional.
        <form
          aria-label="Bericht prüfen und unterschreiben"
          action={(form) =>
            run(() =>
              signAtCompletion({
                reportId: report.report_id,
                summary: summaryOf(form),
                previousSummary: report.summary ?? null,
                // CSR1 / CGR-02: the hash of exactly the facts shown below; the database signs only those.
                snapshotHash: report.snapshot_hash,
                idempotencyKey: crypto.randomUUID(),
              }),
            )
          }
          className="grid gap-2"
        >
          <ReportFacts snapshot={report.snapshot} />
          <SummaryField initial={report.summary ?? ""} />
          <p className="text-xs text-emerald-900/70">
            Mit der Unterschrift bestätigst du die Angaben. Danach ist der Bericht nicht mehr änderbar. Du kannst auch später unterschreiben.
          </p>
          <button type="submit" disabled={pending} className="min-h-12 rounded-lg bg-emerald-800 font-bold text-white disabled:opacity-60">
            {pending ? "Wird gespeichert …" : "Bericht unterschreiben"}
          </button>
        </form>
      )}

      {mode === "idle" && report && view.actions.includes("withdraw") && (
        // CSR1 / CGR-24-W: one tap with a confirmation; no reason (nothing changed).
        <button
          type="button"
          data-testid="withdraw-correction"
          onClick={() => setMode("withdraw")}
          className="min-h-11 rounded-lg border border-stone-300 bg-white font-semibold"
        >
          Korrektur zurückziehen
        </button>
      )}

      {mode === "withdraw" && report && (
        <div role="group" aria-label="Korrektur zurückziehen" className="grid gap-2">
          <p className="text-xs text-emerald-900/80">
            Die Korrektur wird zurückgezogen, ohne dass sich etwas ändert. Die abgeschlossene Fassung bleibt gültig; Zeiten
            und Beobachtungen sind wieder gesperrt. Nur möglich, solange in der Korrektur nichts geändert wurde.
          </p>
          <div className="grid grid-cols-2 gap-2">
            <button
              type="button"
              data-testid="withdraw-correction-confirm"
              disabled={pending}
              onClick={() => run(() => withdrawReportCorrection({ reportId: report.report_id, idempotencyKey: crypto.randomUUID() }))}
              className="min-h-11 rounded-lg bg-emerald-800 font-bold text-white disabled:opacity-60"
            >
              {pending ? "Wird gespeichert …" : "Zurückziehen"}
            </button>
            <button type="button" onClick={() => setMode("idle")} className="min-h-11 rounded-lg border border-stone-300 font-semibold">
              Abbrechen
            </button>
          </div>
        </div>
      )}

      {mode === "return" && report && (
        // F6R-8: required reason; the confirmation names what happens.
        <form
          aria-label="Bericht zurückgeben"
          action={(form) =>
            run(() =>
              returnReport({ reportId: report.report_id, reason: String(form.get("reason") ?? ""), idempotencyKey: crypto.randomUUID() }),
            )
          }
          className="grid gap-2"
        >
          <label className="grid gap-1">
            <span className="text-xs font-semibold">Was muss korrigiert werden?</span>
            <textarea name="reason" required minLength={10} maxLength={500} rows={3} className="rounded-lg border border-stone-300 bg-white p-2" />
          </label>
          <p data-testid="return-confirmation" className="text-xs text-emerald-900/80">{returnConfirmation(report.signed_by_name)}</p>
          <div className="grid grid-cols-2 gap-2">
            <button type="submit" disabled={pending} className="min-h-11 rounded-lg bg-amber-700 font-bold text-white disabled:opacity-60">
              {pending ? "Wird gespeichert …" : "Zurückgeben"}
            </button>
            <button type="button" onClick={() => setMode("idle")} className="min-h-11 rounded-lg border border-stone-300 font-semibold">
              Abbrechen
            </button>
          </div>
        </form>
      )}

      {mode === "idle" && report && view.actions.some((a) => a === "countersign" || a === "correct") && (
        <div className="grid grid-cols-2 gap-2">
          {view.actions.includes("countersign") && (
            <button
              type="button"
              disabled={pending}
              onClick={() => run(() => countersignReport({ reportId: report.report_id, idempotencyKey: crypto.randomUUID() }))}
              className="col-span-2 min-h-11 rounded-lg bg-blue-800 font-bold text-white disabled:opacity-60"
            >
              {pending ? "Wird gespeichert …" : "Gegenzeichnen"}
            </button>
          )}
          {view.actions.includes("return") && (
            <button
              type="button"
              onClick={() => setMode("return")}
              className="col-span-2 min-h-11 rounded-lg border border-amber-600 bg-white font-semibold text-amber-900"
            >
              Zurückgeben
            </button>
          )}
          {view.actions.includes("correct") && (
            <button type="button" onClick={() => setMode("correct")} className="col-span-2 min-h-11 rounded-lg border border-stone-300 bg-white font-semibold">
              Bericht korrigieren
            </button>
          )}
        </div>
      )}
    </section>
  );
}

/** F7: what the draft took over from the visit, so the nurse can check it before signing (no re-entry). */
function ReportFacts({ snapshot }: { snapshot: unknown }) {
  const snap = (snapshot ?? {}) as {
    planned?: { start?: string | null; end?: string | null; a?: number | null; b?: number | null; c?: number | null };
    services?: string[];
    events?: { type: string; at: string }[];
    observations?: { content: string; recorded_at: string; handover?: boolean; edited?: boolean }[];
  };
  const at = (type: string) => snap.events?.find((e) => e.type === type)?.at ?? null;
  const time = (iso: string | null) =>
    iso ? new Intl.DateTimeFormat("de-CH", { timeZone: "Europe/Zurich", hour: "2-digit", minute: "2-digit", hourCycle: "h23" }).format(new Date(iso)) : "–";
  const minutes = [["A", snap.planned?.a], ["B", snap.planned?.b], ["C", snap.planned?.c]]
    .filter(([, m]) => typeof m === "number" && m > 0).map(([k, m]) => `${k} ${m} min`).join(" · ");
  return (
    <dl className="grid grid-cols-[auto_1fr] gap-x-3 gap-y-0.5 text-xs" data-testid="report-facts">
      <dt className="font-semibold">Zeit</dt><dd>{time(at("started"))}–{time(at("completed"))}</dd>
      <dt className="font-semibold">Geplant</dt><dd>{minutes || "–"}</dd>
      <dt className="font-semibold">Leistungen</dt><dd>{snap.services?.length ? snap.services.join(", ") : "–"}</dd>
      <dt className="font-semibold">Beobachtungen</dt>
      <dd>
        {snap.observations?.length ? (
          <ul className="grid gap-1" aria-label="Beobachtungen im Bericht">
            {snap.observations.map((o, i) => (
              <li key={i} className="whitespace-pre-wrap">
                <span className="font-semibold">{time(o.recorded_at)}{o.handover ? " · Übergabe" : " · Beobachtung"}{o.edited ? " · geändert" : ""}:</span> {o.content}
              </li>
            ))}
          </ul>
        ) : "keine"}
      </dd>
    </dl>
  );
}

function SummaryField({ initial = "" }: { initial?: string }) {
  return (
    <label className="grid gap-1">
      <span className="text-xs font-semibold">Zusammenfassung (optional)</span>
      <textarea name="summary" maxLength={4000} rows={3} defaultValue={initial} className="rounded-lg border border-stone-300 bg-white p-2" />
    </label>
  );
}
