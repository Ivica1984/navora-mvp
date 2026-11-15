import Link from "next/link";
import { connection } from "next/server";
import { PAGE_LABEL } from "@/lib/auth/nav";
import { getMyTeamReach, getPostcodeOptions } from "@/features/reach/queries";
import ReachClient from "./reach-client";

// BK-b1s (PO amendment 2026-11-14 10:39 (3), AUT-117 (c); ADR-195 addendum 11:10): «Unser Einsatzgebiet». An active
// member sees and changes the service postcodes and the maximum distance of her own teams only (`my_team_reach`,
// `set_team_reach`); anybody else sees no team here and can change none (the database refuses, BK-b1s (c)).
export default async function ReachPage() {
  // Team data is never prerendered or cached (ADR-010).
  await connection();
  const [teams, postcodes] = await Promise.all([getMyTeamReach(), getPostcodeOptions()]);
  return (
    <div className="min-h-screen bg-stone-100 text-emerald-950">
      <header className="bg-emerald-950 px-4 pb-4 pt-3 text-white">
        <div className="mx-auto flex max-w-xl flex-wrap items-center justify-between gap-1">
          <Link href="/team" className="ml-auto flex min-h-11 items-center rounded-lg px-2 text-sm font-semibold underline underline-offset-4">
            {PAGE_LABEL.team}
          </Link>
        </div>
        <h1 className="mx-auto mt-1 max-w-xl text-xl font-bold">Unser Einsatzgebiet</h1>
      </header>
      <main className="mx-auto grid max-w-xl gap-3 px-4 py-4">
        <ReachClient teams={teams} postcodes={postcodes} />
      </main>
    </div>
  );
}
