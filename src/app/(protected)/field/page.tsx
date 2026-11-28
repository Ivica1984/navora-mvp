import { connection } from "next/server";
import { getCountersignQueue, getDoorNotes, getSafetyAlertHistory, getSafetyAlerts, getFieldNotes, getFieldReports, getFieldVisits, getReturnedReports, getSinceLast, getTeamOpenReports, getOwnQualificationGaps, getOpenTeamOfferCount } from "@/features/field/queries";
import { parseDayParam, parseMovedNotice, shiftDay, todayInZurich } from "@/features/field/rules";
import { parseOverlapParam } from "@/features/visits/overlap-rules";
import { PLAN_FLAG_LABEL } from "@/features/team/rules";
import { parseFocusInstant } from "@/features/field/time";
import { getFieldQuality, getQualityEventTypes } from "@/features/quality/queries";
import { getVisitStatusNotes } from "@/features/lifecycle/queries";
import { getCover } from "@/features/cover/queries";
import { getTeamVisitAlerts } from "@/features/team/queries";
import { getAbsenceView } from "@/features/absence/queries";
import { getMySignals } from "@/features/signals/queries";
import { recordPushTap } from "@/features/push/queries";
import { getMyAssessmentsToConfirm } from "@/features/assessment/queries";
import { carriedVisitIds, withCarriedRows } from "@/features/field/carried";
import { getTakeInvoiceStates } from "@/features/invoices/queries";
import FieldClient from "./field-client";

// F1: the nurse's day. Mobile-first; visits of her own teams only (public.field_visits).
export default async function FieldPage({ searchParams }: PageProps<"/field">) {
  // Care data is never prerendered or cached (ADR-010, SR-05).
  await connection();

  const today = todayInZurich();
  const { datum, von, zeit, verschoben, offen, hinweise, ueberschneidung } = await searchParams;
  // VIS1-3d / VIS1-3e (ADR-112): the result of a "Heute machen" move, shown once on today's view (display only).
  const moved = parseMovedNotice(verschoben, offen, hinweise, Object.keys(PLAN_FLAG_LABEL));
  // VIS2-5 (2): an overlap the server found at that move and the confirmation did not show (display only).
  const movedOverlap = moved ? parseOverlapParam(ueberschneidung) : null;
  // SIG2-8: opened from the push message: record the tap (never display on the device).
  if (von === "push") await recordPushTap();
  const day = parseDayParam(datum, today);
  const [visits, notes, reports, quality, qualityTypes, statusNotes, countersign, returned, cover, sinceLast, visitAlerts, absence, signals, doorNotes, safetyAlerts, alertHistory, teamOpenReports, unqualifiedTeams, assessmentsToConfirm, openTeamOffers] = await Promise.all([
    getFieldVisits(day),
    getFieldNotes(day),
    getFieldReports(day),
    getFieldQuality(day),
    getQualityEventTypes(),
    getVisitStatusNotes(day),
    getCountersignQueue(),
    getReturnedReports(),
    getCover(),
    getSinceLast(day),
    getTeamVisitAlerts(),
    getAbsenceView(day),
    getMySignals(),
    getDoorNotes(day),
    getSafetyAlerts(day),
    getSafetyAlertHistory(day),
    getTeamOpenReports(),
    // UX2-22 (ADR-124): her own membership rows only; the teams where her qualification is not yet recorded.
    getOwnQualificationGaps(),
    // ASM1-C1 (UXR-59): the assessment records that name her and wait for her confirmation.
    getMyAssessmentsToConfirm(),
    // BD / UXR-155 (ADR-179): referrals waiting for her teams' decision; the number only, the decision stays on /team.
    getOpenTeamOfferCount(),
  ]);

  // BK-e1c (C1, ADR-203 (22)): a running night visit of the previous day is on this day's list (field_visits, 0149);
  // its notes, report, quality events, status notes, door facts, since-last and alert history are dated by its own day,
  // so they are read for the previous day and only the carried visits' rows are kept. Its safety alerts come with the
  // day itself (field_safety_alerts, same predicate). Display only.
  const carried = carriedVisitIds(visits);
  const carriedCases = new Set(visits.filter((v) => carried.has(v.visit_id) && v.case_id).map((v) => v.case_id as string));
  const prevDay = shiftDay(day, -1);
  const prev = carried.size === 0 ? null : await Promise.all([
    getFieldNotes(prevDay),
    getFieldReports(prevDay),
    getFieldQuality(prevDay),
    getVisitStatusNotes(prevDay),
    getSinceLast(prevDay),
    getDoorNotes(prevDay),
    getSafetyAlertHistory(prevDay),
  ]);
  const byVisit = (r: { visit_id: string | null }) => r.visit_id;
  // BK-f (0156): the one invoice line under a signed taken shift (display only; never blocks the card or the signature).
  const allReports = withCarriedRows(reports, prev?.[1] ?? [], carried, byVisit);
  const invoiceStates = await getTakeInvoiceStates(
    visits
      .filter((v) => v.from_take === true && allReports.some((r) => r.visit_id === v.visit_id && r.status === "final"))
      .map((v) => v.visit_id),
  );

  return (
    <FieldClient
      day={day}
      isToday={day === today}
      today={today}
      previousDay={shiftDay(day, -1)}
      nextDay={shiftDay(day, 1)}
      visits={visits}
      notes={withCarriedRows(notes, prev?.[0] ?? [], carried, byVisit)}
      reports={allReports}
      quality={withCarriedRows(quality, prev?.[2] ?? [], carried, byVisit)}
      qualityTypes={qualityTypes}
      statusNotes={withCarriedRows(statusNotes, prev?.[3] ?? [], carried, byVisit)}
      countersign={countersign}
      returned={returned}
      cover={cover}
      sinceLast={withCarriedRows(sinceLast, prev?.[4] ?? [], carried, byVisit)}
      openFollowups={visitAlerts.rows.filter((a) => a.exception_type === "visit_interrupted")}
      // PERF1 (CGR-272): the hint list failed; the day view and its commands stay, one notice line replaces the list.
      visitAlertsUnavailable={visitAlerts.unavailable}
      absence={{ today, ...absence }}
      signals={signals}
      doorNotes={withCarriedRows(doorNotes, prev?.[5] ?? [], carried, byVisit)}
      safetyAlerts={safetyAlerts}
      alertHistory={withCarriedRows(alertHistory, prev?.[6] ?? [], carriedCases, (r) => r.case_id)}
      teamOpenReports={teamOpenReports}
      focusAt={parseFocusInstant(zeit)}
      moved={moved}
      movedOverlap={movedOverlap}
      unqualifiedTeams={unqualifiedTeams}
      assessmentsToConfirm={assessmentsToConfirm}
      openTeamOffers={openTeamOffers}
      invoiceStates={invoiceStates}
    />
  );
}
