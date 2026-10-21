import { connection } from "next/server";
import { getOperationsDashboard } from "@/features/operations/queries";
import OperationsClient from "./operations-client";

export default async function OperationsPage() {
  // Care data is never prerendered or cached (ADR-010, SR-05).
  await connection();
  const dashboard = await getOperationsDashboard();

  return <OperationsClient dashboard={dashboard} />;
}
