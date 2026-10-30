"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { confirmSuggestion } from "@/features/ai/commands";
import type { RecordLookbackLine, TeamMemberOption } from "@/features/ai/queries";
import { RECORD_ACTIONS, RECORD_LOOKBACK_TEXT, fieldLabel, notOpenText, proposedByText } from "@/features/ai/labels";

const button = "min-h-11 rounded-lg px-3 text-sm font-semibold disabled:opacity-60";

/**
 * AIG1-C2 (a)/(b) (ADR-130): a value of this record that is on a look-back list. Only the record's team gets lines
 * (`record_lookback_lines`), so a coordinator who is not a team member sees no control (d). For a visit still open: two
 * one-by-one actions, "Erneut bestätigen" and "Ändern", both `confirm_suggestion` on the listed suggestion; never the
 * ticked list (AIG1-13 (a)). A refusal shows its AIG1-15 reason and the line stays. For a visit no longer open
 * (AIG1-C1): no action, "Besuch nicht mehr offen".
 */
export default function LookbackActions({
  lines,
  members,
  heldUserId,
  visitDate,
}: {
  lines: RecordLookbackLine[];
  members: TeamMemberOption[];
  heldUserId: string | null;
  visitDate: string | null;
}) {
  const [message, setMessage] = useState<string | null>(null);
  if (lines.length === 0 && !message) return null;
  return (
    <section aria-label="Rückblick" data-testid="record-lookback" className="grid gap-2 rounded-2xl bg-white p-4 shadow-sm">
      {lines.map((l) => (
        <LookbackLine
          key={l.suggestion_id}
          line={l}
          members={members.filter((m) => m.user_id !== heldUserId)}
          visitDate={visitDate}
          onDone={setMessage}
        />
      ))}
      {message && (
        <p role="status" data-testid="record-lookback-result" className="text-sm font-semibold">
          {message}
        </p>
      )}
    </section>
  );
}

function LookbackLine({
  line,
  members,
  visitDate,
  onDone,
}: {
  line: RecordLookbackLine;
  members: TeamMemberOption[];
  visitDate: string | null;
  onDone: (message: string) => void;
}) {
  const router = useRouter();
  const [mode, setMode] = useState<"idle" | "change">("idle");
  const [chosen, setChosen] = useState<string>("");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function send(outcome: "confirmed" | "corrected", value: string | null) {
    setPending(true);
    setError(null);
    const result = await confirmSuggestion({
      suggestionId: line.suggestion_id,
      outcome,
      value,
      idempotencyKey: crypto.randomUUID(),
    });
    setPending(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setMode("idle");
    onDone(outcome === "confirmed" ? "Wert erneut bestätigt." : "Geänderter Wert bestätigt.");
    router.refresh();
  }

  return (
    <article aria-label={`Rückblick ${fieldLabel(line.field)}`} data-testid="record-lookback-line" className="grid gap-1 text-sm">
      <p>{RECORD_LOOKBACK_TEXT}</p>
      <p className="text-xs text-secondary">
        {fieldLabel(line.field)} · {proposedByText(line.agent_name)}
      </p>
      {!line.record_open ? (
        <p data-testid="record-lookback-not-open" className="font-semibold">
          {notOpenText(visitDate)}
        </p>
      ) : (
        <>
          {error && (
            <p role="alert" data-testid="command-error" className="rounded border border-rose-300 bg-white p-2 font-semibold text-rose-800">
              {error}
            </p>
          )}
          {mode === "idle" ? (
            <div className="flex flex-wrap gap-2">
              <button type="button" disabled={pending} onClick={() => send("confirmed", null)} className={`${button} bg-emerald-800 text-white`}>
                {RECORD_ACTIONS.reconfirm}
              </button>
              <button
                type="button"
                disabled={pending || members.length === 0}
                onClick={() => setMode("change")}
                className={`${button} border border-stone-400 bg-white`}
              >
                {RECORD_ACTIONS.change}
              </button>
            </div>
          ) : (
            <form
              className="grid gap-2"
              onSubmit={(e) => {
                e.preventDefault();
                if (chosen) void send("corrected", chosen);
              }}
            >
              <label className="grid gap-1">
                <span className="text-xs font-semibold">{fieldLabel(line.field)}</span>
                <select value={chosen} onChange={(e) => setChosen(e.target.value)} className="min-h-11 rounded-lg border border-stone-400 bg-white px-2">
                  <option value="">Teammitglied wählen</option>
                  {members.map((m) => (
                    <option key={m.user_id} value={m.user_id}>
                      {(m.name ?? "Teammitglied") + (m.me ? " (du)" : "")}
                    </option>
                  ))}
                </select>
              </label>
              <div className="flex flex-wrap gap-2">
                <button type="submit" disabled={pending || !chosen} className={`${button} bg-emerald-800 text-white`}>
                  Geänderten Wert bestätigen
                </button>
                <button type="button" disabled={pending} onClick={() => setMode("idle")} className={`${button} border border-stone-400 bg-white`}>
                  Abbrechen
                </button>
              </div>
            </form>
          )}
        </>
      )}
    </article>
  );
}
