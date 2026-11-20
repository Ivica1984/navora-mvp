"use client";

// BK-f (contract 2026-11-20 06:39 points 1, 2 (c), (e), (f); migration 0156): «Rechnungsentwürfe» of the caller's teams.
// The database builds each draft from the signed report without any input and decides every state and refusal; this
// section shows them and sends one command per tap («Bestätigen und senden»). Simulated invoice, synthetic data
// (Phase A); no PDF, no payment (R-12). Every function is a fixed rule; no AI model.
import { useRouter } from "next/navigation";
import { useState } from "react";
import type { TeamInvoiceRow } from "@/features/invoices/queries";
import { rebuildTeamInvoiceDraft, sendTeamInvoiceDraft } from "@/features/invoices/commands";
import {
  canRetry,
  formatChf,
  formatHours,
  INVOICE_LABEL,
  refusalLine,
  SEND_BUTTON,
  SEND_HINT,
  stateLabel,
  VOID_AFTER_SEND_TEXT,
} from "@/features/invoices/rules";

function day(iso: string | null) {
  if (!iso) return "";
  const [y, m, d] = iso.split("-");
  return `${d}.${m}.${y}`;
}

export default function InvoiceDraftsSection({ rows }: { rows: TeamInvoiceRow[] }) {
  return (
    <section aria-labelledby="invoice-drafts-heading" className="grid gap-3" data-testid="invoice-drafts">
      <h2 id="invoice-drafts-heading" className="text-lg font-bold">Rechnungsentwürfe</h2>
      <p data-testid="invoice-label" className="rounded-lg border border-amber-400 bg-amber-50 p-2 text-xs font-semibold text-amber-950">
        {INVOICE_LABEL}
      </p>
      {rows.length === 0 && (
        <p className="rounded-2xl border border-dashed border-emerald-900/20 bg-white/70 p-4 text-sm">
          Noch kein Rechnungsentwurf. Er entsteht von selbst, sobald ein Bericht einer übernommenen Schicht unterschrieben ist.
        </p>
      )}
      <ul className="grid gap-3" aria-label="Rechnungsentwürfe">
        {rows.map((r) => (
          <li key={r.id}>
            <InvoiceDraftCard row={r} />
          </li>
        ))}
      </ul>
    </section>
  );
}

function InvoiceDraftCard({ row }: { row: TeamInvoiceRow }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function run(call: () => Promise<{ ok: boolean; error?: string }>) {
    setBusy(true);
    setError(null);
    const res = await call();
    setBusy(false);
    if (!res.ok) setError(res.error ?? "Nicht gespeichert.");
    router.refresh();
  }

  const refused = row.state === "refused";
  return (
    <article
      data-testid="invoice-draft"
      data-state={row.state}
      className={`grid gap-1 rounded-2xl border-l-4 bg-white p-3 text-sm ${refused ? "border-amber-500" : row.state === "void" ? "border-stone-400" : "border-emerald-600"}`}
    >
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <p className="font-semibold break-words">{row.client_name ?? "Auftraggeber"} · {day(row.visit_date)}</p>
        <p data-testid="invoice-state" className="text-xs font-bold">{stateLabel(row.state, "team")}</p>
      </div>
      <p className="text-xs text-secondary">{row.team_name}</p>
      {refused ? (
        <p data-testid="invoice-refusal" role="status" className="font-semibold text-amber-900">
          {refusalLine(row.refusal_reason, row.recorded_minutes, row.ordered_minutes)}
        </p>
      ) : (
        <dl className="grid grid-cols-3 gap-1">
          <div><dt className="text-xs text-secondary">Stunden</dt><dd data-testid="invoice-hours">{formatHours(row.recorded_minutes)}</dd></div>
          <div><dt className="text-xs text-secondary">Preis pro Std.</dt><dd data-testid="invoice-price">{formatChf(row.price_per_hour)}</dd></div>
          <div><dt className="text-xs text-secondary">Betrag</dt><dd data-testid="invoice-amount" className="font-bold">{formatChf(row.amount_chf)}</dd></div>
        </dl>
      )}
      {row.state === "void" && <p data-testid="invoice-void-text" className="text-xs">{VOID_AFTER_SEND_TEXT}</p>}
      {row.state === "draft" && (
        <div className="grid gap-1">
          <button
            type="button"
            data-testid="invoice-send"
            disabled={busy}
            onClick={() => run(() => sendTeamInvoiceDraft({ draftId: row.id, idempotencyKey: crypto.randomUUID() }))}
            className="min-h-11 rounded-lg bg-emerald-800 px-4 font-semibold text-white disabled:opacity-60"
          >
            {SEND_BUTTON}
          </button>
          <p className="text-xs text-secondary">{SEND_HINT}</p>
        </div>
      )}
      {refused && canRetry(row.refusal_reason) && (
        <button
          type="button"
          data-testid="invoice-retry"
          disabled={busy}
          onClick={() => run(() => rebuildTeamInvoiceDraft({ reportId: row.report_id, idempotencyKey: crypto.randomUUID() }))}
          className="min-h-11 justify-self-start rounded-lg border border-emerald-800 px-4 font-semibold text-emerald-900 disabled:opacity-60"
        >
          Neu prüfen
        </button>
      )}
      {error && <p role="alert" className="text-xs font-semibold text-red-800">{error}</p>}
    </article>
  );
}
