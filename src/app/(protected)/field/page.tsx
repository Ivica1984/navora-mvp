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
import { carriedVisits, withCarriedCaseRows, withCarriedRows } from "@/features/field/carried";
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

  // BK-e1c (ADR-203 amendment, UXR-248, CGR-257): a night visit of the day before still running today is on this day
  // (field_visits, migration 0149). Its notes, report, quality, status notes, door notes, «Seit dem letzten Einsatz» and
  // alert history are dated by the visit: read them for the day before too and keep only the carried visits' rows.
  // Safety alerts already come for the carried visit from field_safety_alerts (same predicate). Display only.
  const carried = carriedVisits(visits);
  const carriedIds = new Set(carried.map((v) => v.visit_id));
  const carriedCaseIds = new Set(carried.flatMap((v) => (v.case_id ? [v.case_id] : [])));
  const before = carried.length > 0 ? shiftDay(day, -1) : null;
  const [notesB, reportsB, qualityB, statusNotesB, sinceLastB, doorNotesB, alertHistoryB] = before
    ? await Promise.all([
        getFieldNotes(before),
        getFieldReports(before),
        getFieldQuality(before),
        getVisitStatusNotes(before),
        getSinceLast(before),
        getDoorNotes(before),
        getSafetyAlertHistory(before),
      ])
    : [[], [], [], [], [], [], []];

  return (
    <FieldClient
      day={day}
      isToday={day === today}
      today={today}
      previousDay={shiftDay(day, -1)}
      nextDay={shiftDay(day, 1)}
      visits={visits}
      notes={withCarriedRows(notes, notesB, carriedIds)}
      reports={withCarriedRows(reports, reportsB, carriedIds)}
      quality={withCarriedRows(quality, qualityB, carriedIds)}
      qualityTypes={qualityTypes}
      statusNotes={withCarriedRows(statusNotes, statusNotesB, carriedIds)}
      countersign={countersign}
      returned={returned}
      cover={cover}
      sinceLast={withCarriedRows(sinceLast, sinceLastB, carriedIds)}
      openFollowups={visitAlerts.filter((a) => a.exception_type === "visit_interrupted")}
      absence={{ today, ...absence }}
      signals={signals}
      doorNotes={withCarriedRows(doorNotes, doorNotesB, carriedIds)}
      safetyAlerts={safetyAlerts}
      alertHistory={withCarriedCaseRows(alertHistory, alertHistoryB, carriedCaseIds)}
      teamOpenReports={teamOpenReports}
      focusAt={parseFocusInstant(zeit)}
      moved={moved}
      movedOverlap={movedOverlap}
      unqualifiedTeams={unqualifiedTeams}
      assessmentsToConfirm={assessmentsToConfirm}
      openTeamOffers={openTeamOffers}
    />
  );
}
