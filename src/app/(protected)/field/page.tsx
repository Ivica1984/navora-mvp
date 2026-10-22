import { connection } from "next/server";
import { getCountersignQueue, getFieldNotes, getFieldReports, getFieldVisits } from "@/features/field/queries";
import { parseDayParam, shiftDay, todayInZurich } from "@/features/field/rules";
import { getFieldQuality, getQualityEventTypes } from "@/features/quality/queries";
import { getVisitStatusNotes } from "@/features/lifecycle/queries";
import { getCover } from "@/features/cover/queries";
import FieldClient from "./field-client";

// F1: the nurse's day. Mobile-first; visits of her own teams only (public.field_visits).
export default async function FieldPage({ searchParams }: PageProps<"/field">) {
  // Care data is never prerendered or cached (ADR-010, SR-05).
  await connection();

  const today = todayInZurich();
  const { datum } = await searchParams;
  const day = parseDayParam(datum, today);
  const [visits, notes, reports, quality, qualityTypes, statusNotes, countersign, cover] = await Promise.all([
    getFieldVisits(day),
    getFieldNotes(day),
    getFieldReports(day),
    getFieldQuality(day),
    getQualityEventTypes(),
    getVisitStatusNotes(day),
    getCountersignQueue(),
    getCover(),
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
    />
  );
}
