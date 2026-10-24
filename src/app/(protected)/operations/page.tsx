import { connection } from "next/server";
import { getOperationsDashboard } from "@/features/operations/queries";
import { getOpenHolds } from "@/features/quality/queries";
import { getContinuity } from "@/features/team/queries";
import { todayInZurich } from "@/features/field/rules";
import { getBillingPreview } from "@/features/billing/queries";
import { monthStart } from "@/features/billing/rules";
import { getOpsCaseLifecycle } from "@/features/lifecycle/queries";
import { getMySignals } from "@/features/signals/queries";
import OperationsClient from "./operations-client";

export default async function OperationsPage() {
  // Care data is never prerendered or cached (ADR-010, SR-05).
  await connection();
  const month = monthStart(todayInZurich());
  const [dashboard, holds, continuity, billing, lifecycle, signals] = await Promise.all([
    getOperationsDashboard(),
    getOpenHolds(),
    getContinuity(month),
    getBillingPreview(month),
    getOpsCaseLifecycle(),
    getMySignals(),
  ]);

  return <OperationsClient dashboard={dashboard} holds={holds} continuity={continuity} billing={billing} month={month} lifecycle={lifecycle} signals={signals} />;
}
