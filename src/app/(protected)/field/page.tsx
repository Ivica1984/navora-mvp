import { connection } from "next/server";
import { getCountersignQueue, getFieldNotes, getFieldReports, getFieldVisits, getSinceLast } from "@/features/field/queries";
import { parseDayParam, shiftDay, todayInZurich } from "@/features/field/rules";
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
  const { datum, von } = await searchParams;
  // SIG2-8: opened from the push message: record the tap (never display on the device).
  if (von === "push") await recordPushTap();
  const day = parseDayParam(datum, today);
  const [visits, notes, reports, quality, qualityTypes, statusNotes, countersign, cover, sinceLast, visitAlerts, absence, signals] = await Promise.all([
    getFieldVisits(day),
    getFieldNotes(day),
    getFieldReports(day),
    getFieldQuality(day),
    getQualityEventTypes(),
    getVisitStatusNotes(day),
    getCountersignQueue(),
    getCover(),
    getSinceLast(day),
    getTeamVisitAlerts(),
    getAbsenceView(day),
    getMySignals(),
  ]);

  return (
    <FieldClient
      day={day}
      isToday={day === today}
      previousDay={shiftDay(day, -1)}
      nextDay={shiftDay(day, 1)}
      visits={visits}
      notes={notes}
      reports={reports}
      quality={quality}
      qualityTypes={qualityTypes}
      statusNotes={statusNotes}
      countersign={countersign}
      cover={cover}
      sinceLast={sinceLast}
      openFollowups={visitAlerts.filter((a) => a.exception_type === "visit_interrupted")}
      absence={{ today, ...absence }}
      signals={signals}
    />
  );
}
