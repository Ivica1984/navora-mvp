import { connection } from "next/server";
import Sidebar from "@/components/layout/Sidebar";
import { getIntakeData } from "@/features/intake/queries";
import IntakeClient from "./intake-client";

// J1: referral intake (ARCHITECTURE data flow: partner_requests → cases → matching_requests).
export default async function IntakePage() {
  await connection();
  const { organizationId, requests, cases, linkable } = await getIntakeData();

  return (
    <div className="grid min-h-screen bg-stone-100 text-emerald-950 md:grid-cols-[280px_1fr]">
      <div className="hidden md:block">
        <Sidebar active="intake" />
      </div>
      <main className="mx-auto w-full max-w-4xl p-4 md:p-8">
        <p className="text-xs font-bold uppercase tracking-widest text-emerald-900/60">Aufnahme</p>
        <h1 className="text-2xl font-bold md:text-3xl">Zuweisungen aufnehmen</h1>
        <p className="mt-1 max-w-2xl text-sm text-emerald-900/70">
          Anfrage von Spital, Heim, Hausarzt oder Angehörigen erfassen, prüfen und in einen Klientenfall überführen.
          Danach entscheiden die Teams der Region selbst, wer den Fall übernimmt.
        </p>
        {organizationId ? (
          <IntakeClient organizationId={organizationId} requests={requests} cases={cases} linkable={linkable} />
        ) : (
          <p role="status" className="mt-6 rounded-xl border border-dashed border-emerald-900/20 bg-white p-6">
            Die Aufnahme ist Admin- und Operations-Rollen vorbehalten.
          </p>
        )}
      </main>
    </div>
  );
}
