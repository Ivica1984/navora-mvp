import { getTeams } from "@/features/teams/queries";
import TeamsClient from "./teams-client";

export default async function TeamsPage() {
  const teams = await getTeams();

  return <TeamsClient teams={teams} />;
}