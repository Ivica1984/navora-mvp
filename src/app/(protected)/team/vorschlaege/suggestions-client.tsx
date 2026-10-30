"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { confirmSuggestion, confirmSuggestions } from "@/features/ai/commands";
import type { OpenSuggestion, TeamMemberOption, TeamSuggestions } from "@/features/ai/queries";
import { NOT_FOUND_TEXT, bulkConfirmLabel, fieldLabel, formatDate, hhmm, proposedByText } from "@/features/ai/labels";

const button = "min-h-11 rounded-lg px-3 text-sm font-semibold disabled:opacity-60";

/**
 * AIG1-3/-4/-5 (CGR-78 (b)): one line per proposed value. Every line is decided on its own (Bestätigen, Ändern,
 * Ablehnen; a "nicht gefunden" proposal only as "nicht gefunden"). Values the database marks bulk-eligible carry a
 * tick box that starts unticked; each box ticks only its own line; there is no "select all"; the button names its count.
 */
export default function SuggestionsClient({ teams }: { teams: TeamSuggestions[] }) {
  const open = teams.filter((t) => t.suggestions.length > 0);
  if (open.length === 0) {
    return (
      <p data-testid="suggestions-empty" className="rounded-2xl border border-dashed border-emerald-900/20 bg-white/70 p-6 text-center">
        Keine offenen Vorschläge für deine Teams.
      </p>
    );
  }
  return (
    <>
      {open.map((t) => (
        <TeamList key={t.team_id} team={t} />
      ))}
    </>
  );
}

function TeamList({ team }: { team: TeamSuggestions }) {
  const router = useRouter();
  const [ticked, setTicked] = useState<string[]>([]);
  const [pending, setPending] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const eligible = team.suggestions.filter((s) => s.bulk_allowed);

  function toggle(id: string, on: boolean) {
    setTicked((prev) => (on ? [...prev.filter((x) => x !== id), id] : prev.filter((x) => x !== id)));
  }

  async function confirmTicked() {
    if (ticked.length === 0) return;
    setPending(true);
    setError(null);
    setMessage(null);
    const result = await confirmSuggestions({ suggestionIds: ticked, idempotencyKey: crypto.randomUUID() });
    setPending(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setTicked([]);
    const n = result.confirmed ?? 0;
    setMessage(n === 1 ? "1 Wert bestätigt." : `${n} Werte bestätigt.`);
    if (result.refused && result.refused.length > 0) setError(result.refused.join(" "));
    router.refresh();
  }

  return (
    <section aria-label={`Vorschläge ${team.team_name}`} className="grid gap-2 rounded-2xl bg-white p-3 shadow-sm">
      <h2 className="text-lg font-bold">{team.team_name}</h2>
      <ul className="grid gap-2" aria-label="Offene Vorschläge">
        {team.suggestions.map((s) => (
          <li key={s.suggestion_id}>
            <SuggestionLine
              suggestion={s}
              client={team.clients[s.entity_id] ?? null}
              members={team.members}
              tickable={s.bulk_allowed}
              ticked={ticked.includes(s.suggestion_id)}
              onTick={(on) => toggle(s.suggestion_id, on)}
            />
          </li>
        ))}
      </ul>
      {eligible.length > 0 && (
        <div className="grid gap-1 border-t border-stone-200 pt-2">
          <p className="text-xs text-secondary">Angekreuzte Werte werden unverändert bestätigt, jeder einzeln mit deinem Namen.</p>
          <button
            type="button"
            data-testid="bulk-confirm"
            disabled={pending || ticked.length === 0}
            onClick={confirmTicked}
            className={`${button} bg-emerald-800 text-white`}
          >
            {pending ? "Wird gespeichert …" : bulkConfirmLabel(ticked.length)}
          </button>
        </div>
      )}
      {message && (
        <p role="status" data-testid="bulk-result" className="text-sm font-semibold">
          {message}
        </p>
      )}
      {error && (
        <p role="alert" data-testid="command-error" className="rounded border border-rose-300 bg-white p-2 text-sm font-semibold text-rose-800">
          {error}
        </p>
      )}
    </section>
  );
}

function SuggestionLine({
  suggestion: s,
  client,
  members,
  tickable,
  ticked,
  onTick,
}: {
  suggestion: OpenSuggestion;
  client: string | null;
  members: TeamMemberOption[];
  tickable: boolean;
  ticked: boolean;
  onTick: (on: boolean) => void;
}) {
  const router = useRouter();
  const [mode, setMode] = useState<"idle" | "change">("idle");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const when = [s.visit_date ? formatDate(s.visit_date) : null, s.time_start ? hhmm(s.time_start) : null].filter(Boolean).join(" ");
  const label = [client, when].filter(Boolean).join(" · ");
  const proposedValue = s.not_found ? NOT_FOUND_TEXT : (s.proposed_name ?? "Teammitglied");
  const proposedId = typeof s.proposed_value === "string" ? s.proposed_value : null;
  const others = members.filter((m) => m.user_id !== proposedId);

  async function send(outcome: "confirmed" | "corrected" | "rejected" | "not_found", value: string | null) {
    setPending(true);
    setError(null);
    const result = await confirmSuggestion({ suggestionId: s.suggestion_id, outcome, value, idempotencyKey: crypto.randomUUID() });
    setPending(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setMode("idle");
    router.refresh();
  }

  return (
    <article aria-label={`Vorschlag ${label}`} data-testid="suggestion" className="grid gap-1 rounded-xl border border-stone-200 p-3 text-sm">
      <div className="flex items-start gap-2">
        {tickable && (
          <input
            type="checkbox"
            data-testid="suggestion-tick"
            aria-label={`Ankreuzen: ${label}`}
            checked={ticked}
            onChange={(e) => onTick(e.target.checked)}
            className="mt-1 h-6 w-6 shrink-0"
          />
        )}
        <div className="grid gap-0.5">
          <p className="font-semibold">{label || "Einsatz"}</p>
          <p data-testid="suggestion-value">
            {fieldLabel(s.field)}: <span className="font-bold">{proposedValue}</span>
          </p>
          <p data-testid="suggestion-agent" className="text-xs text-secondary">
            {proposedByText(s.agent_name)}
          </p>
        </div>
      </div>
      {error && (
        <p role="alert" data-testid="command-error" className="rounded border border-rose-300 bg-white p-2 font-semibold text-rose-800">
          {error}
        </p>
      )}
      {mode === "idle" ? (
        <div className="flex flex-wrap gap-2">
          {s.not_found ? (
            <button type="button" disabled={pending} onClick={() => send("not_found", null)} className={`${button} bg-emerald-800 text-white`}>
              Als „{NOT_FOUND_TEXT}“ bestätigen
            </button>
          ) : (
            <>
              <button type="button" disabled={pending} onClick={() => send("confirmed", null)} className={`${button} bg-emerald-800 text-white`}>
                Bestätigen
              </button>
              <button type="button" disabled={pending || others.length === 0} onClick={() => setMode("change")} className={`${button} border border-stone-400 bg-white`}>
                Ändern
              </button>
              <button type="button" disabled={pending} onClick={() => send("rejected", null)} className={`${button} border border-stone-400 bg-white`}>
                Ablehnen
              </button>
            </>
          )}
          <Link href={`/visits/${s.entity_id}`} className="flex min-h-11 items-center px-1 text-sm font-semibold underline underline-offset-4">
            Einsatz öffnen
          </Link>
        </div>
      ) : (
        <form
          aria-label="Wert ändern"
          action={(form) => {
            const v = String(form.get("member") ?? "");
            if (v) void send("corrected", v);
          }}
          className="grid gap-2"
        >
          <label className="grid gap-1">
            <span className="text-xs font-semibold">{fieldLabel(s.field)}</span>
            <select name="member" required defaultValue="" className="min-h-11 rounded-lg border border-stone-300 bg-white px-2">
              <option value="" disabled>
                Person wählen
              </option>
              {others.map((m) => (
                <option key={m.user_id} value={m.user_id}>
                  {m.me ? `${m.name ?? "Ich"} (du)` : (m.name ?? "Teammitglied")}
                </option>
              ))}
            </select>
          </label>
          <div className="flex gap-2">
            <button type="submit" disabled={pending} className={`${button} bg-emerald-800 text-white`}>
              {pending ? "Wird gespeichert …" : "Geänderten Wert bestätigen"}
            </button>
            <button type="button" onClick={() => setMode("idle")} className={`${button} border border-stone-300 bg-white`}>
              Abbrechen
            </button>
          </div>
        </form>
      )}
    </article>
  );
}
