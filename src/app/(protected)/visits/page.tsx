import { connection } from "next/server";
import { getCareVisits } from "@/features/visits/queries";
import VisitsClient from "./visits-client";

export default async function VisitsPage() {
  // Care data is never prerendered or cached (ADR-010, SR-05).
  await connection();
  const visits = await getCareVisits();

  return <VisitsClient visits={visits} />;
}
