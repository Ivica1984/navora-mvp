import { connection } from "next/server";
import { getTeams } from "@/features/teams/queries";
import TeamsClient from "./teams-client";

export default async function TeamsPage() {
  // Care data is never prerendered or cached (ADR-010, SR-05).
  await connection();
  const teams = await getTeams();

  return <TeamsClient teams={teams} />;
}