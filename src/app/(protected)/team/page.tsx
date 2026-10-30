import { connection } from "next/server";
import { getContinuity, getTeamCases, getTeamOffers, getTeamVisitAlerts } from "@/features/team/queries";
import { todayInZurich } from "@/features/field/rules";
import { getBillingPreview } from "@/features/billing/queries";
import { monthStart } from "@/features/billing/rules";
import { getCaseLifecycle } from "@/features/lifecycle/queries";
import { getPlanStatus } from "@/features/planning/queries";
import { getMySignals, getVisitsOutsideWatchedHours } from "@/features/signals/queries";
import { getGpNotices } from "@/features/gp/queries";
import { getTeamPushStatus } from "@/features/push/queries";
import { getMyTeamAdmissions } from "@/features/admission/queries";
import { getContractEndHandover, getLeaverOpenReports, getSuccessorItems } from "@/features/contract-end/queries";
import { getAssessmentInstruments, getTeamCaseAssessments } from "@/features/assessment/queries";
import TeamClient from "./team-client";

// J2: requests offered to the caller's teams — the team decides (Teamautonomie).
// J3: the team plans visits for its own cases.
export default async function TeamPage() {
  await connection();
  // J6: continuity per client for the current month.
  // J5: monthly billing estimate for the team.
  const month = monthStart(todayInZurich());
  // PLAN2: refresh the four-week series first, so the case cards show the generated visits.
  const planStatus = await getPlanStatus();
  // CSR1 / CGR-04: overdue and stuck visits of the team, after the plan refresh.
  // ORD0-3: "Hausärztin/Hausarzt informiert" records of the team's cases.
  // SIG2-2: per member, whether delivery outside the app is active.
  // SIG2-C1 (2): planned visits of the team's next 7 days outside the watched hours (own teams only).
  // ADM2-10: the team's admission proposals (only when the organisation switched team admission on).
  // ADM2-12 / ADM2-15: colleagues whose contract ends in the next 14 days (registered nurses) and open responsibilities of
  // a person whose access ended.
  // ASM1 (0100): the assessment records of the team's cases and the organisation's instrument list.
  const [offers, cases, continuity, billing, lifecycle, visitAlerts, signals, gpNotices, pushStatus, outsideWatched, admissions, leavers, successorItems, assessments, instruments] = await Promise.all([
    getTeamOffers(),
    getTeamCases(),
    getContinuity(month),
    getBillingPreview(month),
    getCaseLifecycle(),
    getTeamVisitAlerts(),
    getMySignals(),
    getGpNotices(),
    getTeamPushStatus(),
    getVisitsOutsideWatchedHours(true),
    getMyTeamAdmissions(),
    getContractEndHandover(),
    getSuccessorItems(),
    getTeamCaseAssessments(),
    getAssessmentInstruments(),
  ]);
  const leaverReports = await getLeaverOpenReports(leavers);
  return <TeamClient offers={offers} cases={cases} continuity={continuity} billing={billing} month={month} lifecycle={lifecycle} planStatus={planStatus} visitAlerts={visitAlerts} signals={signals} gpNotices={gpNotices} pushStatus={pushStatus} outsideWatched={outsideWatched} admissions={admissions} leavers={leavers} leaverReports={leaverReports} successorItems={successorItems} assessments={assessments} instruments={instruments} />;
}
