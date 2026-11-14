import { connection } from "next/server";
import { parseDayParam, shiftDay, todayInZurich } from "@/features/field/rules";
import { getMyUnexportedDays, getMyWorkingDay, getMyWorkingDayVersions, getWorkingTimeNotice } from "@/features/work/queries";
import { getMyContractEnd } from "@/features/contract-end/queries";
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
  // WORK1-C3 (d): her own count of confirmed days not yet exported (only after the information text).
  const unexported = notice.acknowledged ? await getMyUnexportedDays() : null;
  // ADM2-14 (a): from 14 days before her recorded contract end, the date her access ends (export reminder).
  const contractEnd = await getMyContractEnd();
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
      unexported={unexported}
      contractEnd={contractEnd}
    />
  );
}
