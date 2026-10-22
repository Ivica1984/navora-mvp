import { connection } from "next/server";
import { getContinuity, getTeamCases, getTeamOffers } from "@/features/team/queries";
import { todayInZurich } from "@/features/field/rules";
import TeamClient from "./team-client";

// J2: requests offered to the caller's teams — the team decides (Teamautonomie).
// J3: the team plans visits for its own cases.
export default async function TeamPage() {
  await connection();
  // J6: continuity per client for the current month.
  const [offers, cases, continuity] = await Promise.all([getTeamOffers(), getTeamCases(), getContinuity(todayInZurich())]);
  return <TeamClient offers={offers} cases={cases} continuity={continuity} />;
}
