import { connection } from "next/server";
import { getOperationsDashboard } from "@/features/operations/queries";
import { getOpenHolds } from "@/features/quality/queries";
import OperationsClient from "./operations-client";

export default async function OperationsPage() {
  // Care data is never prerendered or cached (ADR-010, SR-05).
  await connection();
  const [dashboard, holds] = await Promise.all([getOperationsDashboard(), getOpenHolds()]);

  return <OperationsClient dashboard={dashboard} holds={holds} />;
}
