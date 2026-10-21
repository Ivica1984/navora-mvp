import { connection } from "next/server";
import { getTeamCases, getTeamOffers } from "@/features/team/queries";
import TeamClient from "./team-client";

// J2: requests offered to the caller's teams — the team decides (Teamautonomie).
// J3: the team plans visits for its own cases.
export default async function TeamPage() {
  await connection();
  const [offers, cases] = await Promise.all([getTeamOffers(), getTeamCases()]);
  return <TeamClient offers={offers} cases={cases} />;
}
