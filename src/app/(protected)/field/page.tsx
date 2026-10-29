import { connection } from "next/server";
import { getCountersignQueue, getDoorNotes, getSafetyAlertHistory, getSafetyAlerts, getFieldNotes, getFieldReports, getFieldVisits, getReturnedReports, getSinceLast, getTeamOpenReports } from "@/features/field/queries";
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
  const [visits, notes, reports, quality, qualityTypes, statusNotes, countersign, returned, cover, sinceLast, visitAlerts, absence, signals, doorNotes, safetyAlerts, alertHistory, teamOpenReports] = await Promise.all([
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
  ]);

  return (
    <FieldClient
      day={day}
      isToday={day === today}
      today={today}
      previousDay={shiftDay(day, -1)}
      nextDay={shiftDay(day, 1)}
      visits={visits}
      notes={notes}
      reports={reports}
      quality={quality}
      qualityTypes={qualityTypes}
      statusNotes={statusNotes}
      countersign={countersign}
      returned={returned}
      cover={cover}
      sinceLast={sinceLast}
      openFollowups={visitAlerts.filter((a) => a.exception_type === "visit_interrupted")}
      absence={{ today, ...absence }}
      signals={signals}
      doorNotes={doorNotes}
      safetyAlerts={safetyAlerts}
      alertHistory={alertHistory}
      teamOpenReports={teamOpenReports}
      focusAt={parseFocusInstant(zeit)}
      moved={moved}
      movedOverlap={movedOverlap}
    />
  );
}
