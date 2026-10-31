import Link from "next/link";
import { connection } from "next/server";
import { AppFrame } from "@/components/layout/Sidebar";
import { getAgentHealth } from "@/features/ai/queries";
import { formatDate, formatShare, minReachedText, stateLabel, stopReasonText, windowText } from "@/features/ai/labels";

// AIG1-10 / AIG1-16 (ADR-129): one list of the organisation's assistants for Operations and administrators (desktop
// first). agent_health (0103) answers coordinators only and runs the stop check first; it has no person column.
// NAVORA shows the threshold written at switch-on and sets none.
export default async function AgentHealthPage() {
  await connection();
  const rows = await getAgentHealth();
  return (
    <AppFrame active="operations" className="bg-stone-50 text-emerald-950">
      <main className="grid min-w-0 gap-4 p-4 md:p-6">
        <Link href="/operations" className="text-sm font-semibold underline underline-offset-4">
          Zurück zu den Ausnahmen
        </Link>
        <header>
          <h1 className="text-2xl font-bold">Assistenten</h1>
          <p className="text-sm text-secondary">
            Was jeder Assistent vorschlägt, bestätigt eine Person. Ein Assistent stoppt von selbst, wenn sein Korrekturanteil
            im abgeschlossenen Fenster über der Schwelle liegt, die beim Einschalten geschrieben wurde.
          </p>
        </header>
        {rows.length === 0 ? (
          <p data-testid="agent-health-empty" className="rounded-lg border border-dashed border-stone-300 p-4 text-center text-secondary">
            Keine Assistenten sichtbar.
          </p>
        ) : (
          <div className="overflow-x-auto rounded-xl border border-stone-200 bg-white">
            <table aria-label="Assistenten" className="w-full text-left text-sm">
              <thead className="bg-stone-100 text-xs uppercase tracking-wide">
                <tr>
                  <th className="p-2">Assistent</th>
                  <th className="p-2">Zustand</th>
                  <th className="p-2">Letzter Vorschlag</th>
                  <th className="p-2">Korrekturanteil letztes Fenster</th>
                  <th className="p-2">Schwelle</th>
                  <th className="p-2">Mindestzahl</th>
                  <th className="p-2">Fenster</th>
                  <th className="p-2">Warum gestoppt</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.agent_key} data-testid="agent-health-row" className="border-t border-stone-200 align-top">
                    <td className="p-2 font-semibold">
                      {r.agent_name}
                      <span className="block text-xs font-normal text-secondary">
                        Stufe {r.level} · {r.kind === "rule" ? "Regel" : "KI"} · Version {r.version}
                      </span>
                    </td>
                    <td className="p-2" data-testid="agent-state">{stateLabel(r.state)}</td>
                    <td className="p-2">{r.last_proposal_at ? formatDate(r.last_proposal_at) : "–"}</td>
                    <td className="p-2" data-testid="agent-last-share">
                      {formatShare(r.last_window_share)}
                      {r.last_window_decided !== null && r.last_window_decided !== undefined && (
                        <span className="block text-xs text-secondary">{r.last_window_decided} entschieden</span>
                      )}
                    </td>
                    <td className="p-2" data-testid="agent-stop-share">{formatShare(r.stop_share)}</td>
                    <td className="p-2">
                      <span className="block" data-testid="agent-stop-min">{r.stop_min_proposals ?? "–"}</span>
                      {/* AIG1-C3 (4) / UXR-70: the minimum flag sits in the "Mindestzahl" cell. */}
                      <span className="block text-xs" data-testid="agent-min-reached">{minReachedText(r.last_window_min_reached)}</span>
                    </td>
                    <td className="p-2" data-testid="agent-stop-window">{windowText(r.stop_window_days)}</td>
                    <td className="p-2" data-testid="agent-stop-reason">
                      {r.state === "stopped" ? (
                        <>
                          {stopReasonText(r.stop_reason)}
                          {r.stopped_at && <span className="block text-xs text-secondary">seit {formatDate(r.stopped_at)}</span>}
                          {r.stop_id && (
                            <Link href={`/operations/assistenten/rueckblick/${r.stop_id}`} className="block font-semibold underline underline-offset-4">
                              Betroffene Werte ansehen
                            </Link>
                          )}
                        </>
                      ) : (
                        "–"
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </main>
    </AppFrame>
  );
}
