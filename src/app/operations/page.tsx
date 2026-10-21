import { getOperationsDashboard } from "@/features/operations/queries";
import OperationsClient from "./operations-client";

export default async function OperationsPage() {
  const dashboard = await getOperationsDashboard();

  return <OperationsClient dashboard={dashboard} />;
}
