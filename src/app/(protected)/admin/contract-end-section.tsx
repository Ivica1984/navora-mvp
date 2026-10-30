"use client";

// ADM2 part (b) on /admin (migration 0092, ADR-115):
// * ADM2-11: "Vertragsende" per member: record, change or remove the end date (switch on). Her planned visits after it
//   go to the team at once; her access ends at the start of the Zurich day after it, without a further step (ADM2-13).
// * ADM2-12 / ADM2-14 (b) / ADM2-15 (a): leavers of the next 14 days with their open cases, visits and reports; the entry
//   "Austritt vorbereiten" opens the recorded access-end read (prepare_member_access_end, 0087), so her unexported-days
//   count is read inside the access-end path only and every read leaves its audit row.
import { useState, useTransition } from "react";
import { prepareMemberAccessEnd } from "@/features/admin/commands";
import { unexportedDaysText, unexportedEndPrompt } from "@/features/admin/rules";
import { setMemberContractEnd } from "@/features/contract-end/commands";
import { contractEndLine, contractEndNotice, type Contract, type Leaver } from "@/features/contract-end/rules";
import type { LeaverOpenReport } from "@/features/contract-end/queries";
import { LeaverEntry } from "../team/contract-end-section";
import { CONTRACT_END_REMOVE_CONSEQUENCE } from "@/features/admin/confirm-texts";
import ConfirmStep from "./confirm-step";

const field = "min-h-10 rounded-lg border border-stone-300 bg-white px-2 text-sm";
const button = "min-h-10 rounded-lg bg-emerald-800 px-3 text-sm font-bold text-white disabled:opacity-60";
const secondary = "min-h-10 rounded-lg border border-stone-400 bg-white px-3 text-sm font-semibold";


export function ContractEndControl({ userId, contract, today, enabled }: {
  userId: string; contract: Contract | undefined; today: string; enabled: boolean;
}) {
  // UX2-23 (ADR-124): "Vertragsende entfernen" asks once ("confirm-remove"); "Abbrechen" changes nothing.
  const [mode, setMode] = useState<"idle" | "edit" | "confirm-remove">("idle");
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const line = contractEndLine(contract, today);
  const save = (endDate: string | null) => start(async () => {
    setError(null);
    setNotice(null);
    const r = await setMemberContractEnd({ userId, endDate, idempotencyKey: crypto.randomUUID() });
    if (!r.ok) return setError(r.error);
    setNotice(endDate ? contractEndNotice(r.released, r.accessEndsOn) : "Vertragsende entfernt.");
    setMode("idle");
  });
  return (
    <div className="grid gap-1 text-sm" aria-label="Vertragsende">
      {line && <p data-testid="contract-end-line" className="text-stone-700">{line}</p>}
      {enabled && mode === "idle" && (!contract?.endDate || contract.endDate >= today) && (
        <div className="flex flex-wrap gap-2">
          <button type="button" className={secondary} onClick={() => setMode("edit")}>
            {contract?.endDate ? "Vertragsende ändern" : "Vertragsende erfassen"}
          </button>
          {contract?.endDate && (
            <button type="button" className={secondary} disabled={pending} onClick={() => setMode("confirm-remove")}>Vertragsende entfernen</button>
          )}
        </div>
      )}
      {enabled && mode === "confirm-remove" && contract?.endDate && (
        <ConfirmStep
          testId="contract-end-remove-confirm"
          sentence={CONTRACT_END_REMOVE_CONSEQUENCE}
          actionLabel="Vertragsende entfernen"
          pending={pending}
          onCancel={() => setMode("idle")}
          onConfirm={() => save(null)}
        />
      )}
      {mode === "edit" && (
        <form aria-label="Vertragsende erfassen" className="flex flex-wrap items-end gap-2" onSubmit={(e) => {
          e.preventDefault();
          save(String(new FormData(e.currentTarget).get("end") ?? ""));
        }}>
          <label className="grid gap-1 text-xs font-semibold">Letzter Vertragstag
            <input name="end" type="date" required min={today} defaultValue={contract?.endDate ?? ""} className={field} />
          </label>
          <button type="submit" disabled={pending} className={button}>Speichern</button>
          <button type="button" className={secondary} onClick={() => setMode("idle")}>Abbrechen</button>
          <p className="w-full text-xs text-stone-600">
            Ihre geplanten Einsätze nach diesem Tag werden sofort offen im Team. Ihr Zugang endet am Tag danach um 00:00 Uhr,
            ohne weiteren Schritt. Endet sie früher, braucht es «Zugang beenden».
          </p>
        </form>
      )}
      {error && <p role="alert" data-testid="command-error" className="rounded-lg border border-rose-300 bg-rose-50 p-2 text-sm font-semibold text-rose-800">{error}</p>}
      {notice && <p role="status" data-testid="contract-end-notice" className="font-semibold text-amber-900">{notice}</p>}
    </div>
  );
}

export function AdminHandover({ leavers, openReports }: { leavers: Leaver[]; openReports: Record<string, LeaverOpenReport[]> }) {
  if (leavers.length === 0) return null;
  return (
    <section aria-label="Austritte in den nächsten 14 Tagen" className="grid gap-3 rounded-2xl border border-stone-200 bg-white p-5">
      <h3 className="text-lg font-bold">Austritte in den nächsten 14 Tagen</h3>
      <ul className="grid gap-3">
        {leavers.map((l) => (
          <LeaverEntry key={l.user_id} leaver={l} reports={openReports[l.user_id] ?? []}>
            <PrepareEnd userId={l.user_id} />
          </LeaverEntry>
        ))}
      </ul>
    </section>
  );
}

function PrepareEnd({ userId }: { userId: string }) {
  const [pending, start] = useTransition();
  const [count, setCount] = useState<number | null | "unread">("unread");
  return (
    <div className="grid gap-1">
      <button type="button" className={secondary} disabled={pending} onClick={() => start(async () => {
        setCount(await prepareMemberAccessEnd({ userId, idempotencyKey: crypto.randomUUID() }));
      })}>Austritt vorbereiten</button>
      {count !== "unread" && unexportedDaysText(count) && (
        <p data-testid="handover-unexported-count" className="text-xs text-stone-700">{unexportedDaysText(count)}</p>
      )}
      {count !== "unread" && unexportedEndPrompt(count) && (
        <p data-testid="handover-unexported-prompt" className="text-xs font-semibold text-amber-900">{unexportedEndPrompt(count)}</p>
      )}
    </div>
  );
}
