"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { convertPartnerRequest, recordPartnerRequest } from "@/features/intake/commands";
import type { OpenPartnerRequest } from "@/features/intake/queries";
import { PARTNER_TYPES, URGENCIES, parseServices } from "@/features/intake/rules";

const URGENCY_CLASS: Record<string, string> = {
  hoch: "bg-rose-100 text-rose-900",
  mittel: "bg-amber-100 text-amber-900",
  niedrig: "bg-stone-200 text-stone-800",
};

const field = "min-h-11 rounded-lg border border-stone-300 bg-white px-3";

export default function IntakeClient({ organizationId, requests }: { organizationId: string; requests: OpenPartnerRequest[] }) {
  return (
    <div className="mt-6 grid gap-6 lg:grid-cols-[1fr_1fr]">
      <NewRequestForm organizationId={organizationId} />
      <section aria-label="Offene Anfragen" className="grid content-start gap-3">
        <h2 className="text-lg font-bold">Offene Anfragen ({requests.length})</h2>
        {requests.length === 0 && (
          <p className="rounded-xl border border-dashed border-emerald-900/20 bg-white/70 p-4 text-sm">Keine offenen Anfragen.</p>
        )}
        <ul className="grid gap-3">
          {requests.map((r) => (
            <li key={r.id}>
              <RequestCard request={r} />
            </li>
          ))}
        </ul>
      </section>
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

function RequestCard({ request }: { request: OpenPartnerRequest }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function convert(form: FormData) {
    setPending(true);
    setError(null);
    const result = await convertPartnerRequest({
      requestId: request.id,
      firstName: String(form.get("firstName") ?? ""),
      lastName: String(form.get("lastName") ?? ""),
      consentConfirmed: form.get("consent") === "on",
      idempotencyKey: crypto.randomUUID(),
    });
    setPending(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
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
              {pending ? "Wird überführt …" : "Fall eröffnen"}
            </button>
            <button type="button" onClick={() => { setOpen(false); setError(null); }} className="min-h-11 rounded-xl border border-stone-300 font-semibold">
              Abbrechen
            </button>
          </div>
          <p className="text-xs text-emerald-900/60">
            Der Fall erhält kein Team: Die Teams der Region entscheiden selbst über die Übernahme.
          </p>
        </form>
      )}
    </article>
  );
}
