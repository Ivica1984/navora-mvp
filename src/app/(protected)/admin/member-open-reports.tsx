// LEAVE1-12 (1), RLS4-C2: her open reports, shown in the access-end step before the end can be confirmed.
// RLS4-C3 (po 2026-11-03 06:30; `cra` CGR-111, `uxa` UXR-73 and 07:52; ADR-138): when the read failed, the failure line
// carries one action "Erneut laden" (action-outline, at least 44 px, directly after the line) that reads the list again
// for this one member. Ending access stays possible without the list (product decision); the step never says "keine"
// when the list is missing. Pure component (no hooks): the state and the read stay in MemberAccess.
import type { MemberOpenReport } from "@/features/admin/commands";
import {
  OPEN_REPORT_LABEL, OPEN_REPORTS_RETRY_LABEL, OPEN_REPORTS_UNREAD_MESSAGE, countOpenReports, openReportsText,
} from "@/features/admin/rules";

const day = (iso: string) => {
  const [y, m, d] = iso.slice(0, 10).split("-");
  return `${d}.${m}.${y}`;
};

export default function MemberOpenReportsStep({ open, onRetry }: {
  /** "loading" until the read returns; null when it could not be read. */
  open: MemberOpenReport[] | null | "loading";
  onRetry: () => void;
}) {
  return (
    <div data-testid="open-reports" className="w-full">
      {open === "loading"
        ? <p className="text-stone-700">Offene Berichte werden geladen …</p>
        : open === null
          ? (
            <div className="grid justify-items-start gap-1">
              <p role="alert" className="font-semibold text-rose-800">{OPEN_REPORTS_UNREAD_MESSAGE}</p>
              <button type="button" onClick={onRetry} data-testid="open-reports-retry"
                className="min-h-11 rounded-lg border border-stone-400 bg-white px-3 text-sm font-semibold text-stone-900">
                {OPEN_REPORTS_RETRY_LABEL}
              </button>
            </div>
          )
          : <p className="text-stone-700">Offene Berichte: {openReportsText(countOpenReports(open))}</p>}
      {Array.isArray(open) && open.length > 0 && (
        <ul className="grid gap-0.5 pl-3 text-xs text-stone-700" aria-label="Offene Berichte">
          {open.map((r, i) => (
            <li key={`${r.visit_date}:${r.kind}:${i}`}>{day(r.visit_date)} · {r.team_name} · {OPEN_REPORT_LABEL[r.kind] ?? r.kind}</li>
          ))}
        </ul>
      )}
    </div>
  );
}
