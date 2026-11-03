"use client";

// ADM2 part (b) on /team (migration 0092, ADR-115):
// * ADM2-15 (b): open cases of the team that still name a person whose access ended, "Bezugspflege neu bestimmen" /
//   "Stellvertretung neu bestimmen". The team resolves it on the case card (J6 "Kontinuität"); NAVORA names nobody.
// * ADM2-12 / ADM2-15 (a): for registered nurses, colleagues whose contract ends in the next 14 days: end date, her open
//   cases and visits (case reference, date, role only) and her open reports by kind (LEAVE1-12). No client name.
import { OPEN_REPORT_LABEL, countOpenReports, openReportsText } from "@/features/admin/rules";
import {
  CASE_ROLE_LABEL, VISIT_ROLE_LABEL, caseRefLabel, continuityAnchorId, dayLabel, leaverHeadline, successorLine, successorTitle,
  type Leaver, type SuccessorItem,
} from "@/features/contract-end/rules";
import type { MouseEvent, ReactNode } from "react";
import type { LeaverOpenReport } from "@/features/contract-end/queries";

// ADM2-15 (c) (po 08:15 from `uxa` UXR-42): "Fall öffnen" lands on the case card's "Kontinuität" section, in view and
// focused. Without JavaScript the plain #anchor still scrolls there.
function openCase(e: MouseEvent<HTMLAnchorElement>, caseId: string) {
  const target = document.getElementById(continuityAnchorId(caseId));
  if (!target) return;
  e.preventDefault();
  target.scrollIntoView({ block: "start" });
  target.focus({ preventScroll: true });
  history.replaceState(null, "", `#${continuityAnchorId(caseId)}`);
}

export function SuccessorItems({ items }: { items: SuccessorItem[] }) {
  if (items.length === 0) return null;
  return (
    <section aria-label="Offene Verantwortung nach Austritt" className="grid gap-2 rounded-2xl border-2 border-amber-500 bg-amber-50 p-4">
      <h2 className="font-bold">Offene Verantwortung nach Austritt</h2>
      <ul className="grid gap-2">
        {items.map((i) => (
          <li key={`${i.case_id}:${i.role}`} data-testid="successor-item" className="grid gap-1 rounded-xl border border-amber-300 bg-white p-3">
            <p className="font-semibold">{successorTitle(i.role)}</p>
            <p className="text-sm">{successorLine(i)}</p>
            <p className="text-secondary text-xs">In der Fallkarte unter «Kontinuität» neu bestimmen.</p>
            <a
              href={`#${continuityAnchorId(i.case_id)}`}
              onClick={(e) => openCase(e, i.case_id)}
              className="justify-self-start inline-flex min-h-11 min-w-11 items-center rounded-lg border border-stone-400 bg-white px-3 font-semibold"
            >
              Fall öffnen
            </a>
          </li>
        ))}
      </ul>
    </section>
  );
}

export function TeamHandover({ leavers, openReports }: { leavers: Leaver[]; openReports: Record<string, LeaverOpenReport[]> }) {
  if (leavers.length === 0) return null;
  return (
    <section aria-label="Austritte in den nächsten 14 Tagen" className="grid gap-2 rounded-2xl border border-stone-300 bg-white p-4">
      <h2 className="font-bold">Austritte in den nächsten 14 Tagen</h2>
      <ul className="grid gap-3">
        {leavers.map((l) => <LeaverEntry key={l.user_id} leaver={l} reports={openReports[l.user_id]} />)}
      </ul>
    </section>
  );
}

/** `reports` undefined: her list could not be read (getLeaverOpenReports logs it); never shown as "keine". */
export function LeaverEntry({ leaver, reports, children }: { leaver: Leaver; reports: LeaverOpenReport[] | undefined; children?: ReactNode }) {
  return (
    <li data-testid="leaver" className="grid gap-1 rounded-xl border border-stone-200 p-3 text-sm">
      <p className="font-semibold">{leaverHeadline(leaver)}</p>
      <p data-testid="leaver-cases">
        {leaver.cases.length === 0
          ? "Keine offenen Fälle als Bezugspflege oder Stellvertretung."
          : leaver.cases.map((c) => `${caseRefLabel(c.case_ref)} (${CASE_ROLE_LABEL[c.role] ?? c.role}, ${c.team})`).join(" · ")}
      </p>
      {leaver.visits.length > 0 && (
        <ul className="grid gap-0.5 pl-3 text-xs" aria-label="Ihre Einsätze bis zum Vertragsende">
          {leaver.visits.map((v, i) => (
            <li key={`${v.visit_date}:${v.case_ref}:${i}`}>{dayLabel(v.visit_date)} · {caseRefLabel(v.case_ref)} · {VISIT_ROLE_LABEL[v.role] ?? v.role}</li>
          ))}
        </ul>
      )}
      {reports === undefined
        ? <p role="alert" className="font-semibold text-rose-800" data-testid="leaver-reports">Offene Berichte konnten nicht geladen werden.</p>
        : <p className="text-secondary" data-testid="leaver-reports">Offene Berichte: {openReportsText(countOpenReports(reports))}</p>}
      {reports !== undefined && reports.length > 0 && (
        <ul className="grid gap-0.5 pl-3 text-xs" aria-label="Offene Berichte">
          {reports.map((r, i) => <li key={`${r.visit_date}:${r.kind}:${i}`}>{dayLabel(r.visit_date)} · {r.team_name} · {OPEN_REPORT_LABEL[r.kind] ?? r.kind}</li>)}
        </ul>
      )}
      {children}
    </li>
  );
}
