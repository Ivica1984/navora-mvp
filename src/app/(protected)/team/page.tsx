import { connection } from "next/server";
import { getTeamOffers } from "@/features/team/queries";
import TeamClient from "./team-client";

// J2: requests offered to the caller's teams — the team decides (Teamautonomie).
export default async function TeamPage() {
  await connection();
  const offers = await getTeamOffers();
  return <TeamClient offers={offers} />;
}
