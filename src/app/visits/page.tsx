import { getCareVisits } from "@/features/visits/queries";
import VisitsClient from "./visits-client";

export default async function VisitsPage() {
  const visits = await getCareVisits();

  return <VisitsClient visits={visits} />;
}
