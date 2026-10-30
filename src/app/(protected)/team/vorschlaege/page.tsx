import Link from "next/link";
import { connection } from "next/server";
import { HeaderMenu } from "@/components/layout/Sidebar";
import { PAGE_LABEL } from "@/lib/auth/nav";
import { getTeamSuggestions } from "@/features/ai/queries";
import SuggestionsClient from "./suggestions-client";

// AIG1 part (b) (ADR-129): the confirm screen of the team (AIG1-3, -4, -5; 390 px first). A named member confirms each
// proposed value; nothing becomes record content without her command (migration 0097).
export default async function SuggestionsPage() {
  // Care data is never prerendered or cached (ADR-010, SR-05).
  await connection();
  const teams = await getTeamSuggestions();
  return (
    <div className="min-h-screen bg-stone-100 text-emerald-950">
      <header className="bg-emerald-950 px-4 pb-4 pt-3 text-white">
        <div className="mx-auto flex max-w-xl flex-wrap items-center justify-between gap-1">
          <Link href="/team" className="ml-auto flex min-h-11 items-center rounded-lg px-2 text-sm font-semibold underline underline-offset-4">
            {PAGE_LABEL.team}
          </Link>
          <HeaderMenu active="team" />
        </div>
        <h1 className="mx-auto mt-1 max-w-xl text-xl font-bold">Vorschläge</h1>
        <p className="mx-auto max-w-xl text-sm text-emerald-100">
          Ein Assistent schlägt Werte vor. Übernommen wird nur, was eine Person aus dem Team bestätigt, Wert für Wert.
        </p>
      </header>
      <main className="mx-auto grid max-w-xl gap-3 px-4 py-4">
        <SuggestionsClient teams={teams} />
      </main>
    </div>
  );
}
