"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import {
  correctReport,
  countersignReport,
  createReportDraft,
  signReport,
  updateReportDraft,
} from "@/features/field/report-commands";
import { reportView, type FieldReport } from "@/features/field/report";

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
  const [mode, setMode] = useState<"idle" | "edit" | "correct">("idle");
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

      {report?.summary && mode === "idle" && <p className="whitespace-pre-wrap">{report.summary}</p>}
      {report?.correction_reason && (
        <p className="text-xs text-emerald-900/70">Korrektur: {report.correction_reason}</p>
      )}
      {report?.signed_at && (
        <p className="text-xs text-emerald-900/70">
          Unterschrieben {formatStamp(report.signed_at)}
          {report.i_signed ? " von dir" : ""}
          {report.countersigned_at ? ` · gegengezeichnet ${formatStamp(report.countersigned_at)}` : ""}
        </p>
      )}
      {view.hint && <p className="text-xs text-emerald-900/70">{view.hint}</p>}

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

      {mode === "idle" && report && view.actions.some((a) => a !== "create") && (
        <div className="grid gap-2">
          {view.actions.includes("sign") && (
            <p className="text-xs text-emerald-900/70">
              Mit der Unterschrift bestätigst du die Angaben. Danach ist der Bericht nicht mehr änderbar.
            </p>
          )}
          <div className="grid grid-cols-2 gap-2">
            {view.actions.includes("edit") && (
              <button type="button" onClick={() => setMode("edit")} className="min-h-11 rounded-lg border-2 border-emerald-800 bg-white font-semibold">
                Zusammenfassung bearbeiten
              </button>
            )}
            {view.actions.includes("sign") && (
              <button
                type="button"
                disabled={pending}
                onClick={() => run(() => signReport({ reportId: report.report_id, idempotencyKey: crypto.randomUUID() }))}
                className="min-h-11 rounded-lg bg-emerald-800 font-bold text-white disabled:opacity-60"
              >
                {pending ? "Wird gespeichert …" : "Bericht unterschreiben"}
              </button>
            )}
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
            {view.actions.includes("correct") && (
              <button type="button" onClick={() => setMode("correct")} className="col-span-2 min-h-11 rounded-lg border border-stone-300 bg-white font-semibold">
                Bericht korrigieren
              </button>
            )}
          </div>
        </div>
      )}
    </section>
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
