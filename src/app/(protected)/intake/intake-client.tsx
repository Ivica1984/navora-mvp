"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { convertPartnerRequest, linkReturningReferral, recordPartnerRequest, updateCaseIntake } from "@/features/intake/commands";
import { linkEffect, linkableLabel } from "@/features/returning/rules";
import type { IntakeCase, LinkableCase, OpenPartnerRequest } from "@/features/intake/queries";
import {
  CANTONS,
  INSURANCE_TYPES,
  MEDICAL_ORDER_LABEL,
  MEDICAL_ORDER_STATUSES,
  PARTNER_TYPES,
  TASK_LABEL,
  URGENCIES,
  factsFromForm,
  parseMissing,
  parseServices,
  type ReadinessItem,
} from "@/features/intake/rules";

const URGENCY_CLASS: Record<string, string> = {
  hoch: "bg-rose-100 text-rose-900",
  mittel: "bg-amber-100 text-amber-900",
  niedrig: "bg-stone-200 text-stone-800",
};

const field = "min-h-11 rounded-lg border border-stone-300 bg-white px-3";

export default function IntakeClient({
  organizationId,
  requests,
  cases,
  linkable,
}: {
  organizationId: string;
  requests: OpenPartnerRequest[];
  cases: IntakeCase[];
  linkable: Record<string, LinkableCase[]>;
}) {
  return (
    <div className="mt-6 grid gap-6 lg:grid-cols-[1fr_1fr]">
      <NewRequestForm organizationId={organizationId} />
      <div className="grid content-start gap-6">
      <section aria-label="Fälle in Aufnahme" className="grid content-start gap-3">
        <h2 className="text-lg font-bold">Fälle in Aufnahme ({cases.length})</h2>
        {cases.length === 0 && (
          <p className="rounded-xl border border-dashed border-emerald-900/20 bg-white/70 p-4 text-sm">Keine unvollständigen Fälle.</p>
        )}
        <ul className="grid gap-3">
          {cases.map((c) => (
            <li key={c.case_id}>
              <IntakeCaseCard intakeCase={c} />
            </li>
          ))}
        </ul>
      </section>
      <section aria-label="Offene Anfragen" className="grid content-start gap-3">
        <h2 className="text-lg font-bold">Offene Anfragen ({requests.length})</h2>
        {requests.length === 0 && (
          <p className="rounded-xl border border-dashed border-emerald-900/20 bg-white/70 p-4 text-sm">Keine offenen Anfragen.</p>
        )}
        <ul className="grid gap-3">
          {requests.map((r) => (
            <li key={r.id}>
              <RequestCard request={r} linkable={linkable[r.id] ?? []} />
            </li>
          ))}
        </ul>
      </section>
      </div>
    </div>
  );
}

function ErrorBox({ message }: { message: string | null }) {
  if (!message) return null;
  return (
    <p role="alert" data-testid="command-error" className="rounded-lg border border-rose-300 bg-rose-50 p-3 text-sm font-semibold text-rose-800">
      {message}
    </p>
  );
}

function NewRequestForm({ organizationId }: { organizationId: string }) {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [formKey, setFormKey] = useState(0);

  async function save(form: FormData) {
    setPending(true);
    setError(null);
    setSaved(false);
    const get = (k: string) => String(form.get(k) ?? "");
    const result = await recordPartnerRequest({
      organizationId,
      partnerName: get("partnerName"),
      partnerType: get("partnerType"),
      region: get("region"),
      city: get("city"),
      urgency: get("urgency"),
      timeInfo: get("timeInfo"),
      requestTitle: get("requestTitle"),
      needSummary: get("needSummary"),
      services: parseServices(get("services")),
      idempotencyKey: crypto.randomUUID(),
    });
    setPending(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setSaved(true);
    setFormKey((k) => k + 1);
    router.refresh();
  }

  return (
    <form key={formKey} action={save} aria-label="Neue Anfrage" className="grid content-start gap-3 rounded-2xl bg-white p-4 shadow-sm">
      <h2 className="text-lg font-bold">Neue Anfrage erfassen</h2>
      <label className="grid gap-1 text-sm">
        <span className="font-semibold">Zuweisende Stelle</span>
        <input name="partnerName" required minLength={2} maxLength={120} className={field} />
      </label>
      <div className="grid grid-cols-2 gap-3">
        <label className="grid gap-1 text-sm">
          <span className="font-semibold">Art</span>
          <select name="partnerType" className={field} defaultValue="Spital">
            {PARTNER_TYPES.map((t) => (
              <option key={t}>{t}</option>
            ))}
          </select>
        </label>
        <label className="grid gap-1 text-sm">
          <span className="font-semibold">Dringlichkeit</span>
          <select name="urgency" className={field} defaultValue="mittel">
            {URGENCIES.map((u) => (
              <option key={u} value={u}>{u}</option>
            ))}
          </select>
        </label>
        <label className="grid gap-1 text-sm">
          <span className="font-semibold">Region</span>
          <input name="region" required minLength={2} maxLength={80} className={field} />
        </label>
        <label className="grid gap-1 text-sm">
          <span className="font-semibold">Ort</span>
          <input name="city" maxLength={80} className={field} />
        </label>
      </div>
      <label className="grid gap-1 text-sm">
        <span className="font-semibold">Titel</span>
        <input name="requestTitle" required minLength={3} maxLength={160} className={field} placeholder="z. B. Austritt nach Hüft-OP" />
      </label>
      <label className="grid gap-1 text-sm">
        <span className="font-semibold">Bedarf (Zusammenfassung)</span>
        <textarea name="needSummary" required minLength={3} maxLength={2000} rows={3} className="rounded-lg border border-stone-300 bg-white p-2" />
      </label>
      <label className="grid gap-1 text-sm">
        <span className="font-semibold">Leistungen (mit Komma getrennt)</span>
        <input name="services" maxLength={1000} className={field} placeholder="Grundpflege, Wundversorgung" />
      </label>
      <label className="grid gap-1 text-sm">
        <span className="font-semibold">Zeitpunkt</span>
        <input name="timeInfo" maxLength={120} className={field} placeholder="z. B. ab Montag" />
      </label>
      <ErrorBox message={error} />
      {saved && <p role="status" className="text-sm font-semibold text-emerald-800">Anfrage gespeichert.</p>}
      <button type="submit" disabled={pending} className="min-h-12 rounded-xl bg-emerald-800 font-bold text-white disabled:opacity-60">
        {pending ? "Wird gespeichert …" : "Anfrage speichern"}
      </button>
    </form>
  );
}

function RequestCard({ request, linkable }: { request: OpenPartnerRequest; linkable: LinkableCase[] }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  // RET1: an explicit link to an earlier case, chosen by the intake role (no automatic identity matching).
  const [linkCaseId, setLinkCaseId] = useState("");
  const linked = linkable.find((c) => c.case_id === linkCaseId) ?? null;
  const resumes = linked?.lifecycle === "paused";

  async function convert(form: FormData) {
    setPending(true);
    setError(null);
    const common = {
      requestId: request.id,
      firstName: String(form.get("firstName") ?? ""),
      lastName: String(form.get("lastName") ?? ""),
      consentConfirmed: form.get("consent") === "on",
      facts: factsFromForm((k) => String(form.get(k) ?? "")),
      idempotencyKey: crypto.randomUUID(),
    };
    const result = linked
      ? await linkReturningReferral({ ...common, caseId: linked.case_id, reason: String(form.get("linkReason") ?? "") })
      : await convertPartnerRequest(common);
    setPending(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    // Not ready → the case appears under "Fälle in Aufnahme" with the missing items.
    router.refresh();
  }

  return (
    <article aria-label={`Anfrage ${request.request_title}`} className="rounded-2xl bg-white p-4 shadow-sm">
      <div className="flex items-start justify-between gap-2">
        <div>
          <h3 className="font-bold">{request.request_title}</h3>
          <p className="text-sm text-emerald-900/70">
            {request.partner_name}
            {request.partner_type ? ` · ${request.partner_type}` : ""} · {request.region}
            {request.city ? `, ${request.city}` : ""}
          </p>
        </div>
        <span className={`shrink-0 rounded-full px-3 py-1 text-xs font-bold ${URGENCY_CLASS[request.urgency] ?? "bg-stone-200"}`}>
          {request.urgency}
        </span>
      </div>
      <p className="mt-2 whitespace-pre-wrap text-sm">{request.need_summary}</p>
      {request.requested_services && request.requested_services.length > 0 && (
        <p className="mt-1 text-sm text-emerald-900/70">Leistungen: {request.requested_services.join(", ")}</p>
      )}
      {request.time_info && <p className="text-sm text-emerald-900/70">Zeitpunkt: {request.time_info}</p>}

      {!open ? (
        <button type="button" onClick={() => setOpen(true)} className="mt-3 min-h-11 w-full rounded-xl border-2 border-emerald-800 font-bold text-emerald-900">
          Prüfen und in Fall überführen
        </button>
      ) : (
        <form action={convert} className="mt-3 grid gap-2 rounded-xl bg-stone-50 p-3">
          {linkable.length > 0 && (
            <fieldset className="grid gap-2 rounded-xl border border-stone-200 bg-white p-3">
              <legend className="px-1 text-sm font-bold">Rückkehrende Klient:in?</legend>
              <label className="grid gap-1 text-sm">
                <span className="font-semibold">Mit früherem Fall verknüpfen (optional)</span>
                <select name="linkCaseId" value={linkCaseId} onChange={(e) => setLinkCaseId(e.target.value)} className={field}>
                  <option value="">Nein, neue Klient:in</option>
                  {linkable.map((c) => (
                    <option key={c.case_id} value={c.case_id}>{linkableLabel(c)}</option>
                  ))}
                </select>
              </label>
              {linked && (
                <>
                  <p data-testid="link-effect" className="text-sm text-emerald-900/80">{linkEffect(linked.lifecycle)}</p>
                  <label className="grid gap-1 text-sm">
                    <span className="font-semibold">Grund der Verknüpfung</span>
                    <input name="linkReason" required minLength={3} maxLength={300} className={field} placeholder="z. B. Austritt nach Spitalaufenthalt, gleiche Person" />
                  </label>
                </>
              )}
              <p className="text-xs text-emerald-900/60">NAVORA sucht keine Personen automatisch; nur ihr entscheidet über eine Verknüpfung.</p>
            </fieldset>
          )}
          {!resumes && (
            <div className="grid grid-cols-2 gap-2">
              <label className="grid gap-1 text-sm">
                <span className="font-semibold">Vorname</span>
                <input name="firstName" required maxLength={100} className={field} />
              </label>
              <label className="grid gap-1 text-sm">
                <span className="font-semibold">Nachname</span>
                <input name="lastName" required maxLength={100} className={field} />
              </label>
            </div>
          )}
          <FactsFields />
          <label className="flex items-start gap-2 text-sm">
            <input name="consent" type="checkbox" required className="mt-1 size-5 shrink-0" />
            <span>
              Die Einwilligung der Klientin / des Klienten (oder der vertretungsberechtigten Person) zur Bearbeitung
              ihrer Daten durch NAVORA liegt vor.
            </span>
          </label>
          <ErrorBox message={error} />
          <div className="grid grid-cols-[2fr_1fr] gap-2">
            <button type="submit" disabled={pending} className="min-h-11 rounded-xl bg-emerald-800 font-bold text-white disabled:opacity-60">
              {pending ? "Wird überführt …" : resumes ? "Fall fortsetzen" : "Fall eröffnen"}
            </button>
            <button type="button" onClick={() => { setOpen(false); setError(null); }} className="min-h-11 rounded-xl border border-stone-300 font-semibold">
              Abbrechen
            </button>
          </div>
          <p className="text-xs text-emerald-900/60">
            Die Teamsuche startet erst, wenn Einwilligung, Wohnort, Versicherer und Versicherungsart sowie Bedarf mit
            Beginn vorliegen. Danach entscheiden die Teams der Region selbst über die Übernahme.
          </p>
        </form>
      )}
    </article>
  );
}

function FactsFields({ initial }: { initial?: Partial<IntakeCase> }) {
  const sel = "min-h-11 rounded-lg border border-stone-300 bg-white px-2";
  const yn = (v: boolean | null | undefined) => (v === true ? "yes" : v === false ? "no" : "");
  return (
    <fieldset className="grid gap-2 rounded-xl border border-stone-200 bg-white p-3">
      <legend className="px-1 text-sm font-bold">Angaben für Versorgung und Finanzierung</legend>
      <div className="grid grid-cols-[2fr_1fr] gap-2">
        <label className="grid gap-1 text-sm">
          <span className="font-semibold">Wohngemeinde</span>
          <input name="residence_municipality" maxLength={80} defaultValue={initial?.residence_municipality ?? ""} className={sel} />
        </label>
        <label className="grid gap-1 text-sm">
          <span className="font-semibold">Kanton</span>
          <select name="residence_canton" defaultValue={initial?.residence_canton ?? ""} className={sel}>
            <option value="">–</option>
            {CANTONS.map((c) => (
              <option key={c}>{c}</option>
            ))}
          </select>
        </label>
        <label className="grid gap-1 text-sm">
          <span className="font-semibold">Krankenversicherer</span>
          <input name="insurer_name" maxLength={120} defaultValue={initial?.insurer_name ?? ""} className={sel} />
        </label>
        <label className="grid gap-1 text-sm">
          <span className="font-semibold">Versicherungsart</span>
          <select name="insurance_type" defaultValue={initial?.insurance_type ?? ""} className={sel}>
            <option value="">–</option>
            {INSURANCE_TYPES.map((t) => (
              <option key={t} value={t}>{t === "unknown" ? "unbekannt" : t === "private" ? "privat" : t}</option>
            ))}
          </select>
        </label>
        <label className="grid gap-1 text-sm">
          <span className="font-semibold">Ärztliche Verordnung</span>
          <select name="medical_order_status" defaultValue={initial?.medical_order_status ?? ""} className={sel}>
            <option value="">–</option>
            {MEDICAL_ORDER_STATUSES.map((s) => (
              <option key={s} value={s}>{MEDICAL_ORDER_LABEL[s]}</option>
            ))}
          </select>
        </label>
        <label className="grid gap-1 text-sm">
          <span className="font-semibold">Verordnung gültig bis</span>
          <input name="medical_order_valid_until" type="date" defaultValue={initial?.medical_order_valid_until ?? ""} className={sel} />
        </label>
        <label className="grid gap-1 text-sm">
          <span className="font-semibold">Gewünschter Beginn</span>
          <input name="requested_start" type="date" defaultValue={initial?.requested_start ?? ""} className={sel} />
        </label>
        <label className="grid gap-1 text-sm">
          <span className="font-semibold">Erwartete Stunden pro Woche</span>
          <input
            name="expected_hours_per_week"
            type="number"
            inputMode="decimal"
            min={0.5}
            max={168}
            step={0.5}
            defaultValue={initial?.expected_hours_per_week ?? ""}
            className={sel}
          />
        </label>
        <label className="grid gap-1 text-sm">
          <span className="font-semibold">Hausärztin/-arzt bekannt</span>
          <select name="gp_named" defaultValue={yn(initial?.gp_named)} className={sel}>
            <option value="">offen</option>
            <option value="yes">ja</option>
            <option value="no">nein</option>
          </select>
        </label>
        <label className="grid gap-1 text-sm">
          <span className="font-semibold">Andere Dienste aktiv</span>
          <select name="other_providers_active" defaultValue={yn(initial?.other_providers_active)} className={sel}>
            <option value="">offen</option>
            <option value="yes">ja</option>
            <option value="no">nein</option>
          </select>
        </label>
      </div>
      <label className="grid gap-1 text-sm">
        <span className="font-semibold">Sprache / Verständigung</span>
        <input name="language_notes" maxLength={500} defaultValue={initial?.language_notes ?? ""} className={sel} />
      </label>
      <label className="grid gap-1 text-sm">
        <span className="font-semibold">Zugang zur Wohnung</span>
        <input name="access_notes" maxLength={500} defaultValue={initial?.access_notes ?? ""} className={sel} />
      </label>
    </fieldset>
  );
}

function MissingList({ missing }: { missing: ReadinessItem[] }) {
  if (missing.length === 0) return null;
  return (
    <div role="status" aria-label="Warum nicht bereit" className="rounded-lg border-l-4 border-amber-500 bg-amber-50 p-2 text-sm">
      <p className="font-bold text-amber-900">Noch nicht bereit für die Teamsuche:</p>
      <ul className="list-disc pl-5">
        {missing.map((m) => (
          <li key={m.item}>{m.reason}</li>
        ))}
      </ul>
    </div>
  );
}

function IntakeCaseCard({ intakeCase }: { intakeCase: IntakeCase }) {
  const router = useRouter();
  const [editing, setEditing] = useState(false);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const missing = parseMissing(intakeCase.missing);

  async function save(form: FormData) {
    setPending(true);
    setError(null);
    const result = await updateCaseIntake({
      caseId: intakeCase.case_id,
      facts: factsFromForm((k) => String(form.get(k) ?? "")),
      idempotencyKey: crypto.randomUUID(),
    });
    setPending(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setEditing(false);
    router.refresh();
  }

  return (
    <article aria-label={`Fall in Aufnahme ${intakeCase.client_name ?? ""}`} className="rounded-2xl bg-white p-4 shadow-sm">
      <h3 className="font-bold">{intakeCase.client_name ?? "Klient:in"}</h3>
      <p className="text-sm text-emerald-900/70">
        {intakeCase.region} · {intakeCase.urgency}
        {intakeCase.care_needs?.length ? ` · ${intakeCase.care_needs.join(", ")}` : ""}
      </p>
      <div className="mt-2">
        <MissingList missing={missing} />
      </div>
      {intakeCase.open_tasks.length > 0 && (
        <ul aria-label="Offene Aufgaben" className="mt-2 grid gap-1 text-sm">
          {intakeCase.open_tasks.map((t) => (
            <li key={t}>☐ {TASK_LABEL[t] ?? t}</li>
          ))}
        </ul>
      )}
      <ErrorBox message={error} />
      {!editing ? (
        <button type="button" onClick={() => setEditing(true)} className="mt-3 min-h-11 w-full rounded-xl border-2 border-emerald-800 font-bold text-emerald-900">
          Angaben ergänzen
        </button>
      ) : (
        <form action={save} aria-label="Angaben ergänzen" className="mt-3 grid gap-2">
          <FactsFields initial={intakeCase} />
          <div className="grid grid-cols-[2fr_1fr] gap-2">
            <button type="submit" disabled={pending} className="min-h-11 rounded-xl bg-emerald-800 font-bold text-white disabled:opacity-60">
              {pending ? "Wird gespeichert …" : "Speichern und prüfen"}
            </button>
            <button type="button" onClick={() => setEditing(false)} className="min-h-11 rounded-xl border border-stone-300 font-semibold">
              Abbrechen
            </button>
          </div>
        </form>
      )}
    </article>
  );
}
