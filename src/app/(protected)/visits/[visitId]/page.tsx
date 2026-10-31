import Link from "next/link";
import { notFound } from "next/navigation";
import { connection } from "next/server";
import { getHomeLink, getRecordLookback, getVisitRecord } from "@/features/ai/queries";
import LookbackActions from "./lookback-actions";
import { fieldLabel, formatDate, hhmm, provenanceLine, recordBackLink } from "@/features/ai/labels";
import { getVisitStatusLabel } from "@/features/visits/types";

// AIG1 part (b) (ADR-129): one visit as a look-back line or a proposal opens it. The visit comes through its existing
// read path (care_visits RLS: team, coordination; READ_PATHS); the AIG1-3 line "vorgeschlagen von <Agent> / bestätigt
// von <Name> am <Datum>" comes from value_provenance for this one value, which answers only the record's team members
// (AIG1-11 (2a)); everybody else sees the visit without it. AIG1-C1/-C2 (ADR-130): a value of this record on a look-back
// list offers the record's team "Erneut bestätigen" and "Ändern" directly under the provenance line while the visit is
// open, and states "Einsatz nicht mehr offen" otherwise; `record_lookback_lines` answers only the record's team, so
// coordinators get no control. AIG1-C3 (1): the back link returns to the list that opened the page (origin in the link).
export default async function VisitRecordPage({
  params,
  searchParams,
}: {
  params: Promise<{ visitId: string }>;
  searchParams: Promise<{ von?: string | string[]; stopp?: string | string[] }>;
}) {
  await connection();
  const { visitId } = await params;
  const query = await searchParams;
  const one = (v: string | string[] | undefined) => (Array.isArray(v) ? v[0] : v) ?? null;
  if (!/^[0-9a-f-]{36}$/i.test(visitId)) notFound();
  const record = await getVisitRecord(visitId);
  if (!record) notFound();
  const [lookback, home] = await Promise.all([getRecordLookback(record.id, record.team_id), getHomeLink()]);
  const back = recordBackLink(one(query.von), one(query.stopp), home);
  return (
    <main className="mx-auto grid max-w-xl gap-3 bg-stone-100 px-4 py-4 text-emerald-950">
      <Link href={back.href} data-testid="record-back" className="flex min-h-11 items-center text-sm font-semibold underline underline-offset-4">
        {back.label}
      </Link>
      <article aria-label="Einsatz" data-testid="visit-record" className="grid gap-2 rounded-2xl bg-white p-4 shadow-sm">
        <h1 className="text-xl font-bold">
          Einsatz {record.visit_date ? formatDate(record.visit_date) : "–"} · {hhmm(record.time_start)} – {hhmm(record.time_end)}
        </h1>
        <dl className="grid grid-cols-[8rem_1fr] gap-x-2 gap-y-1 text-sm">
          <dt className="text-secondary">Team</dt>
          <dd>{record.team_name ?? "–"}</dd>
          <dt className="text-secondary">Status</dt>
          <dd>{getVisitStatusLabel(record.status)}</dd>
          <dt className="text-secondary">{fieldLabel("responsible_user_id")}</dt>
          <dd data-testid="visit-responsible">
            {record.responsible_set ? (record.responsible_name ?? "Teammitglied") : "Noch offen"}
          </dd>
        </dl>
        {record.provenance && (
          <p data-testid="value-provenance" className="text-sm">
            {provenanceLine(record.provenance)}
          </p>
        )}
        <LookbackActions lines={lookback.lines} members={lookback.members} heldUserId={record.responsible_user_id} />
      </article>
    </main>
  );
}
