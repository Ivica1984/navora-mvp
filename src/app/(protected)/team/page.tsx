import { connection } from "next/server";
import { getContinuity, getTeamCases, getTeamOffers, getTeamVisitAlerts } from "@/features/team/queries";
import { todayInZurich } from "@/features/field/rules";
import { getBillingPreview } from "@/features/billing/queries";
import { monthStart } from "@/features/billing/rules";
import { getCaseLifecycle } from "@/features/lifecycle/queries";
import { getPlanStatus } from "@/features/planning/queries";
import { getMySignals } from "@/features/signals/queries";
import { getGpNotices } from "@/features/gp/queries";
import { getTeamPushStatus } from "@/features/push/queries";
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
  const [offers, cases, continuity, billing, lifecycle, visitAlerts, signals, gpNotices, pushStatus] = await Promise.all([
    getTeamOffers(),
    getTeamCases(),
    getContinuity(month),
    getBillingPreview(month),
    getCaseLifecycle(),
    getTeamVisitAlerts(),
    getMySignals(),
    getGpNotices(),
    getTeamPushStatus(),
  ]);
  return <TeamClient offers={offers} cases={cases} continuity={continuity} billing={billing} month={month} lifecycle={lifecycle} planStatus={planStatus} visitAlerts={visitAlerts} signals={signals} gpNotices={gpNotices} pushStatus={pushStatus} />;
}
