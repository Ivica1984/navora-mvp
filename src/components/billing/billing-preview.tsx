"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { generateBillableFacts } from "@/features/billing/commands";
import { REFERENCE_NOT_VALIDATED, formatChf, notBillableText, parseNotBillable } from "@/features/billing/rules";
import type { BillingPreviewRow } from "@/features/billing/queries";

/**
 * J5: monthly billing preview per team. An ESTIMATE from billable facts — never an invoice.
 * Patient and residual shares appear only once cantonal reference data is on file (D-11).
 * CSR1 / CGR-08: unvalidated rates or minimums are labelled "nicht validiert".
 */
export default function BillingPreview({ rows, month }: { rows: BillingPreviewRow[]; month: string }) {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  async function generate() {
    setPending(true);
    setMessage(null);
    const result = await generateBillableFacts({ month });
    setPending(false);
    setMessage(result.ok ? `${result.created} neue Abrechnungsfakten erfasst.` : result.error);
    router.refresh();
  }

  return (
    <section aria-label="Abrechnungsvorschau" className="grid gap-3 rounded-xl border border-stone-200 bg-white p-4 shadow-sm">
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <div>
          <h2 className="text-lg font-bold">Abrechnungsvorschau {month.slice(0, 7)}</h2>
          <p className="text-sm font-semibold text-amber-800" data-testid="estimate-label">
            Schätzung – keine Rechnung. Nur abgeschlossene, unterschriebene Einsätze ohne Qualitäts-Stopp zählen.
          </p>
        </div>
        <button type="button" onClick={generate} disabled={pending}
          className="min-h-11 rounded-lg border-2 border-emerald-800 bg-white px-3 font-semibold disabled:opacity-60">
          {pending ? "Wird erfasst …" : "Abrechnungsfakten erzeugen"}
        </button>
      </div>
      {message && <p role="status" className="text-sm">{message}</p>}
      {rows.length === 0 ? (
        <p className="text-sm text-stone-500">Keine Teams.</p>
      ) : (
        <ul className="grid gap-3">
          {rows.map((r) => {
            const missing = parseNotBillable(r.not_billable);
            return (
              <li key={r.team_id}>
                <article aria-label={`Vorschau ${r.team_name}`} data-testid="billing-team" className="grid gap-1 rounded-lg bg-stone-50 p-3 text-sm">
                  <h3 className="font-bold">{r.team_name}</h3>
                  <p>
                    {r.billable_visits} abrechenbare Einsätze · A {r.minutes_a} min · B {r.minutes_b} min · C {r.minutes_c} min
                  </p>
                  <p>
                    Krankenversicherer (Schätzung): <span data-testid="insurer-chf">{formatChf(Number(r.insurer_chf))}</span>
                    {!r.insurer_complete && <span className="text-amber-800"> · Tarif fehlt für einen Teil der Minuten</span>}
                  </p>
                  {!r.reference_validated && (
                    <p className="font-semibold text-amber-800" data-testid="reference-not-validated">
                      {REFERENCE_NOT_VALIDATED}
                    </p>
                  )}
                  <p className="text-xs text-stone-600">
                    Patientenbeteiligung: {r.patient_on_file ? "hinterlegt" : "nicht hinterlegt"} · Restfinanzierung:{" "}
                    {r.residual_on_file ? "hinterlegt" : "nicht hinterlegt (Pilotkanton offen, D-11)"}
                  </p>
                  {missing.length > 0 && (
                    <details>
                      <summary className="min-h-11 cursor-pointer content-center font-semibold">
                        {missing.length} nicht abrechenbare Einsätze
                      </summary>
                      <ul className="grid gap-0.5 text-xs" aria-label="Nicht abrechenbar">
                        {missing.map((m) => (
                          <li key={m.visit_id}>
                            {m.date} · {m.client ?? "Klient:in"} — {notBillableText(m.reasons)}
                          </li>
                        ))}
                      </ul>
                    </details>
                  )}
                </article>
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}
