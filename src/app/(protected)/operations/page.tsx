import { connection } from "next/server";
import { getOperationsDashboard } from "@/features/operations/queries";
import { getOpenHolds } from "@/features/quality/queries";
import { getContinuity } from "@/features/team/queries";
import { todayInZurich } from "@/features/field/rules";
import OperationsClient from "./operations-client";

export default async function OperationsPage() {
  // Care data is never prerendered or cached (ADR-010, SR-05).
  await connection();
  const [dashboard, holds, continuity] = await Promise.all([getOperationsDashboard(), getOpenHolds(), getContinuity(todayInZurich())]);

  return <OperationsClient dashboard={dashboard} holds={holds} continuity={continuity} />;
}
