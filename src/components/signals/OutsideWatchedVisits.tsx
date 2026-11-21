import {
  OUTSIDE_WATCHED_EMPTY,
  OUTSIDE_WATCHED_LABEL,
  OUTSIDE_WATCHED_NOTE,
  outsideWatchedLine,
  type OutsideWatchedVisit,
} from "@/features/signals/rules";

// SIG2-C1 (2) (migration 0068, ADR-082): the planned visits of the next 7 days outside the organisation's watched
// periods, on /admin (organisation) and /team (own teams). Date, times and team only; no client data. `rows === null`:
// the list could not be loaded, which is never shown as "none".
export default function OutsideWatchedVisits({ rows }: { rows: OutsideWatchedVisit[] | null }) {
  return (
    <section aria-label={OUTSIDE_WATCHED_LABEL} data-testid="outside-watched"
      className="grid gap-2 rounded-2xl border border-stone-200 bg-white p-4 text-sm">
      <h3 className="text-base font-bold">{OUTSIDE_WATCHED_LABEL}</h3>
      {rows === null && (
        <p role="alert" data-testid="outside-watched-failed" className="font-semibold text-rose-800">
          Die Liste konnte nicht geladen werden. Bitte die Seite neu laden.
        </p>
      )}
      {rows !== null && rows.length === 0 && <p data-testid="outside-watched-empty">{OUTSIDE_WATCHED_EMPTY}</p>}
      {rows !== null && rows.length > 0 && (
        <details>
          <summary data-testid="outside-watched-count" className="cursor-pointer font-semibold text-amber-900">
            {rows.length} {rows.length === 1 ? "Einsatz" : "Einsätze"} in den nächsten 7 Tagen
          </summary>
          <ul className="mt-2 grid gap-1" aria-label={`${OUTSIDE_WATCHED_LABEL}: Liste`}>
            {rows.map((r) => (
              <li key={r.visit_id} data-testid="outside-watched-visit" className="break-words">{outsideWatchedLine(r)}</li>
            ))}
          </ul>
        </details>
      )}
      <p className="text-xs text-stone-600">{OUTSIDE_WATCHED_NOTE}</p>
    </section>
  );
}
