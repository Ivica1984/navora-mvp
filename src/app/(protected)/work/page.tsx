import { connection } from "next/server";
import { parseDayParam, shiftDay, todayInZurich } from "@/features/field/rules";
import { getMyWorkingDay, getMyWorkingDayVersions, getWorkingTimeNotice } from "@/features/work/queries";
import WorkClient from "./work-client";

// WORK1 (migration 0079, ADR-092): the nurse's own working day, proposed from her visit events, confirmed and exported
// by her. Only she reads it (the database returns nobody else's day). Mobile-first.
export default async function WorkPage({ searchParams }: PageProps<"/work">) {
  // Working time is personal data: never prerendered or cached (ADR-010).
  await connection();
  const today = todayInZurich();
  const { datum } = await searchParams;
  const day = parseDayParam(datum, today);
  const notice = await getWorkingTimeNotice();
  const [proposal, versions] = notice.acknowledged
    ? await Promise.all([getMyWorkingDay(day), getMyWorkingDayVersions(day)])
    : [[], []];
  return (
    <WorkClient
      key={`${day}:${versions[0]?.version ?? 0}`}
      day={day}
      today={today}
      previousDay={shiftDay(day, -1)}
      nextDay={day < today ? shiftDay(day, 1) : null}
      acknowledged={notice.acknowledged}
      proposal={proposal}
      versions={versions}
    />
  );
}
