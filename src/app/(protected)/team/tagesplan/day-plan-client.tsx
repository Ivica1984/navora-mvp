"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState, type ReactNode } from "react";
import { confirmSuggestion, confirmSuggestions } from "@/features/ai/commands";
import { bulkResultText, hhmm } from "@/features/ai/labels";
import { proposeDayPlan, setTeamDayProposal } from "@/features/planning/day-plan-commands";
import {
  confirmButtonLabel,
  dayPlanRefusalText,
  lineNotFoundText,
  lineReasonText,
  otherTeamVisitsLine,
  switchedOnLine,
} from "@/features/planning/day-plan-labels";
import type { DayPlanState, DayPlanTeam } from "@/features/planning/day-plan-queries";
import {
  groupDayPlan,
  lineDecisionText,
  lineFlags,
  loadText,
  minuteCategoryText,
  tickableLineIds,
  type DayPlanLine,
  type DayPlanLoadRow,
  type DayPlanMember,
} from "@/features/planning/day-plan-view";

const button = "min-h-11 rounded-lg px-3 text-sm font-semibold disabled:opacity-60";
const primary = `${button} bg-emerald-800 text-white`;
const secondary = `${button} border border-stone-400 bg-white`;

type Props = {
  teams: { team_id: string; team_name: string }[];
  team: DayPlanTeam;
  state: DayPlanState | null;
  date: string | null;
  bounds: { min: string; max: string };
  lines: DayPlanLine[];
  load: DayPlanLoadRow[];
};

function addOneDay(iso: string): string {
  const d = new Date(`${iso}T12:00:00Z`);
  d.setUTCDate(d.getUTCDate() + 1);
  return d.toISOString().slice(0, 10);
}

function hrefFor(teamId: string, date: string | null): string {
  const q = new URLSearchParams({ team: teamId });
  if (date) q.set("datum", date);
  return `/team/tagesplan?${q.toString()}`;
}

/**
 * PLAN3-9 (CGR-78 (b)): ask for a day, see the proposal per member with reasons and minutes, confirm per line or by a
 * list she ticked. Every line starts unticked; each box ticks its own line; no "select all"; the button names its count.
 */
export default function DayPlanClient({ teams, team, state, date, bounds, lines, load }: Props) {
  const agentOn = state?.agent_state === "on";
  const teamOn = state?.team_enabled === true;
  return (
    <>
      {teams.length > 1 && (
        <nav aria-label="Team wählen" className="flex flex-wrap gap-2">
          {teams.map((t) => (
            <Link
              key={t.team_id}
              href={hrefFor(t.team_id, date)}
              aria-current={t.team_id === team.team_id ? "page" : undefined}
              className={`flex min-h-11 items-center rounded-lg px-3 text-sm font-semibold ${t.team_id === team.team_id ? "bg-emerald-900 text-white" : "border border-stone-300 bg-white"}`}
            >
              {t.team_name}
            </Link>
          ))}
        </nav>
      )}
      <TeamSwitch teamId={team.team_id} teamName={team.team_name} teamOn={teamOn} since={state?.enabled_since ?? null} />
      {!agentOn ? (
        // PLAN3-6: with the agent off or stopped every team plans by hand, whatever its own switch.
        <p data-testid="day-plan-unavailable" className="rounded-2xl border border-stone-300 bg-white p-4 text-sm font-semibold">
          {dayPlanRefusalText("agent_off")}
        </p>
      ) : teamOn ? (
        <AskForm teamId={team.team_id} date={date} bounds={bounds} />
      ) : null}
      {date && <Proposal key={lines[0]?.proposal_id ?? "none"} team={team} date={date} lines={lines} load={load} />}
    </>
  );
}

/** PLAN3-10: the team decides for itself; the line shows the date, never who switched it. */
function TeamSwitch({ teamId, teamName, teamOn, since }: { teamId: string; teamName: string; teamOn: boolean; since: string | null }) {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  async function toggle() {
    setPending(true);
    setError(null);
    const result = await setTeamDayProposal({ teamId, on: !teamOn, idempotencyKey: crypto.randomUUID() });
    setPending(false);
    if (!result.ok) return setError(result.error);
    router.refresh();
  }
  return (
    <section aria-label={`Tagesvorschlag ${teamName}`} className="grid gap-2 rounded-2xl bg-white p-3 text-sm shadow-sm">
      <h2 className="text-lg font-bold">{teamName}</h2>
      <p data-testid="day-plan-switch-state">
        {teamOn ? (switchedOnLine(since) ?? "Tagesvorschlag eingeschaltet") : dayPlanRefusalText("team_off")}
      </p>
      <p className="text-xs text-secondary">Euer Team entscheidet, ob es den Tagesvorschlag nutzt.</p>
      <button type="button" data-testid="day-plan-switch" disabled={pending} onClick={toggle} className={teamOn ? secondary : primary}>
        {teamOn ? "Tagesvorschlag ausschalten" : "Tagesvorschlag einschalten"}
      </button>
      {error && (
        <p role="alert" data-testid="command-error" className="rounded border border-rose-300 bg-white p-2 font-semibold text-rose-800">
          {error}
        </p>
      )}
    </section>
  );
}

/** PLAN3-1: a day from today to 14 days ahead; "auch zugewiesene neu vorschlagen" is unticked by default. */
function AskForm({ teamId, date, bounds }: { teamId: string; date: string | null; bounds: { min: string; max: string } }) {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const initial = date ?? addOneDay(bounds.min);
  return (
    <form
      aria-label="Tag vorschlagen"
      className="grid gap-2 rounded-2xl bg-white p-3 text-sm shadow-sm"
      action={async (form) => {
        const day = String(form.get("datum") ?? "");
        setPending(true);
        setError(null);
        const result = await proposeDayPlan({
          teamId,
          date: day,
          includeAssigned: form.get("auch_zugewiesene") === "on",
          idempotencyKey: crypto.randomUUID(),
        });
        setPending(false);
        // An earlier proposal of that day with open lines is shown, so the team decides it first.
        if (result.ok || result.reason === "open_proposal") router.push(hrefFor(teamId, day));
        if (!result.ok) setError(result.error);
        else router.refresh();
      }}
    >
      <label className="grid gap-1 font-semibold">
        Tag
        <input type="date" name="datum" required min={bounds.min} max={bounds.max} defaultValue={initial} className="min-h-11 rounded-lg border border-stone-300 bg-white px-2" />
      </label>
      <label className="flex min-h-11 items-center gap-2">
        <input type="checkbox" name="auch_zugewiesene" className="h-6 w-6" />
        auch zugewiesene neu vorschlagen
      </label>
      <div className="flex flex-wrap gap-2">
        <button type="submit" disabled={pending} className={primary}>
          {pending ? "Wird vorgeschlagen …" : "Tag vorschlagen"}
        </button>
        {date && (
          <Link href={hrefFor(teamId, null)} className="flex min-h-11 items-center px-1 text-sm font-semibold underline underline-offset-4">
            Anderen Tag wählen
          </Link>
        )}
      </div>
      {error && (
        <p role="alert" data-testid="day-plan-error" className="rounded border border-rose-300 bg-white p-2 font-semibold text-rose-800">
          {error}
        </p>
      )}
    </form>
  );
}

function formatDay(iso: string): string {
  const [y, m, d] = iso.split("-");
  return `${d}.${m}.${y}`;
}

function Proposal({ team, date, lines, load }: { team: DayPlanTeam; date: string; lines: DayPlanLine[]; load: DayPlanLoadRow[] }) {
  const router = useRouter();
  const [ticked, setTicked] = useState<string[]>([]);
  const [pending, setPending] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  // AIG1-C3 (2) / PLAN3-14 (2): the reason of each line refused at confirm stays on its line.
  const [refusals, setRefusals] = useState<Record<string, string>>({});
  const [refusedCount, setRefusedCount] = useState(0);
  const groups = groupDayPlan(lines, load);
  const tickable = new Set(tickableLineIds(lines));

  if (lines.length === 0) {
    return (
      <p data-testid="day-plan-empty" className="rounded-2xl border border-dashed border-emerald-900/20 bg-white/70 p-6 text-center text-sm">
        Für den {formatDay(date)} liegt kein Vorschlag vor.
      </p>
    );
  }

  function toggle(id: string, on: boolean) {
    setTicked((prev) => (on ? [...prev.filter((x) => x !== id), id] : prev.filter((x) => x !== id)));
  }

  async function confirmTicked() {
    if (ticked.length === 0) return;
    setPending(true);
    setError(null);
    setMessage(null);
    setRefusals({});
    setRefusedCount(0);
    const result = await confirmSuggestions({ suggestionIds: ticked, idempotencyKey: crypto.randomUUID() });
    setPending(false);
    if (!result.ok) return setError(result.error);
    setTicked([]);
    const refused = result.refused ?? [];
    setRefusals(Object.fromEntries(refused.map((x) => [x.id, x.text])));
    setRefusedCount(refused.length);
    setMessage(bulkResultText(result.confirmed ?? 0, refused.length));
    router.refresh();
  }

  const lineProps = (l: DayPlanLine) => ({
    line: l,
    client: team.clients[l.case_id] ?? null,
    members: groups.members,
    tickable: tickable.has(l.suggestion_id),
    ticked: ticked.includes(l.suggestion_id),
    onTick: (on: boolean) => toggle(l.suggestion_id, on),
    refusal: refusals[l.suggestion_id] ?? null,
    onRefused: (id: string, text: string) => setRefusals((r) => ({ ...r, [id]: text })),
  });

  return (
    <section aria-label={`Vorschlag für den ${formatDay(date)}`} data-testid="day-plan" className="grid gap-3">
      <h2 className="text-lg font-bold">Vorschlag für den {formatDay(date)}</h2>
      {groups.members.map((m) => (
        <MemberBlock key={m.member_id} member={m}>
          {m.lines.map((l) => (
            <li key={l.suggestion_id}>
              <Line {...lineProps(l)} />
            </li>
          ))}
        </MemberBlock>
      ))}
      {groups.withoutProposal.length > 0 && (
        <section aria-label="Ohne Vorschlag" className="grid gap-2 rounded-2xl bg-white p-3 shadow-sm">
          <h3 className="font-bold">Ohne Vorschlag</h3>
          <ul className="grid gap-2" aria-label="Einsätze ohne Vorschlag">
            {groups.withoutProposal.map((l) => (
              <li key={l.suggestion_id}>
                <Line {...lineProps(l)} />
              </li>
            ))}
          </ul>
        </section>
      )}
      <div className="grid gap-1 rounded-2xl bg-white p-3 shadow-sm">
        <p className="text-xs text-secondary">Angekreuzte Zeilen werden unverändert bestätigt, jede einzeln mit deinem Namen.</p>
        <button type="button" data-testid="day-plan-confirm" disabled={pending || ticked.length === 0} onClick={confirmTicked} className={primary}>
          {pending ? "Wird gespeichert …" : ticked.length > 0 ? confirmButtonLabel(ticked.length) : "Zeilen ankreuzen, um sie zu bestätigen"}
        </button>
        {message && (
          <p role={refusedCount > 0 ? "alert" : "status"} data-testid="day-plan-result" className="text-sm font-semibold">
            {message}
          </p>
        )}
        {error && (
          <p role="alert" data-testid="command-error" className="rounded border border-rose-300 bg-white p-2 text-sm font-semibold text-rose-800">
            {error}
          </p>
        )}
      </div>
    </section>
  );
}

/** PLAN3-4 / PLAN3-14: the member's minutes of this team before and after, and only whether she has visits elsewhere. */
function MemberBlock({ member, children }: { member: DayPlanMember; children: ReactNode }) {
  const name = member.name ?? "Teammitglied";
  const load = loadText(member.minutesNow, member.minutesWith);
  const other = otherTeamVisitsLine(member.otherTeams);
  return (
    <section aria-label={`Einsätze ${name}`} data-testid="day-plan-member" className="grid gap-2 rounded-2xl bg-white p-3 shadow-sm">
      <h3 className="font-bold">{name}</h3>
      {load && <p data-testid="day-plan-load" className="text-sm">{load}</p>}
      {other && <p data-testid="day-plan-other-teams" className="text-xs text-secondary">{other}</p>}
      <ul className="grid gap-2" aria-label={`Vorgeschlagene Einsätze ${name}`}>
        {children}
      </ul>
    </section>
  );
}

function Line({
  line: l,
  client,
  members,
  tickable,
  ticked,
  onTick,
  refusal,
  onRefused,
}: {
  line: DayPlanLine;
  client: string | null;
  members: DayPlanMember[];
  tickable: boolean;
  ticked: boolean;
  onTick: (on: boolean) => void;
  refusal: string | null;
  onRefused: (id: string, text: string) => void;
}) {
  const router = useRouter();
  const [mode, setMode] = useState<"idle" | "change">("idle");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const time = `${hhmm(l.time_start)}${l.time_end ? `–${hhmm(l.time_end)}` : ""}`;
  const label = [time, client].filter(Boolean).join(" · ");
  const open = l.decision === "open";
  const notFound = !l.member_id;
  const others = members.filter((m) => m.member_id !== l.member_id);
  const decided = lineDecisionText(l.decision);

  async function send(outcome: "confirmed" | "corrected" | "rejected" | "not_found", value: string | null) {
    setPending(true);
    setError(null);
    const result = await confirmSuggestion({ suggestionId: l.suggestion_id, outcome, value, idempotencyKey: crypto.randomUUID() });
    setPending(false);
    if (!result.ok) {
      // A line the J3 checks or the overlap test refuse stays open; its visit stays in the uncovered path.
      onRefused(l.suggestion_id, result.error);
      setMode("idle");
      return;
    }
    setMode("idle");
    router.refresh();
  }

  const text = (
    <span className="grid gap-0.5">
      <span className="block font-semibold">{label}</span>
      <span className="block" data-testid="day-plan-minutes">{minuteCategoryText(l)}</span>
      <span className="block" data-testid="day-plan-reason">
        {notFound ? lineNotFoundText(l.not_found_reason) : (lineReasonText(l.reason, l.known_visits) ?? "")}
      </span>
      {lineFlags(l).map((f) => (
        <span key={f} className="block text-xs font-semibold" data-testid="day-plan-flag">
          {f}
        </span>
      ))}
      {decided && (
        <span className="block text-xs text-secondary" data-testid="day-plan-decision">
          {decided}
        </span>
      )}
    </span>
  );

  return (
    <article aria-label={`Einsatz ${label}`} data-testid="day-plan-line" className="grid gap-1 rounded-xl border border-stone-200 p-3 text-sm">
      {tickable ? (
        <label className="flex min-h-11 cursor-pointer items-start gap-2">
          <input
            type="checkbox"
            data-testid="day-plan-tick"
            aria-label={`Ankreuzen: ${label}`}
            checked={ticked}
            onChange={(e) => onTick(e.target.checked)}
            className="mt-1 h-6 w-6 shrink-0"
          />
          {text}
        </label>
      ) : (
        <div className="flex items-start gap-2">{text}</div>
      )}
      {(refusal ?? error) && (
        <p role="alert" data-testid="day-plan-refusal" className="rounded border border-rose-300 bg-white p-2 font-semibold text-rose-800">
          {refusal ?? error}
        </p>
      )}
      {open && mode === "idle" && (
        <div className="flex flex-wrap gap-2">
          {notFound ? (
            <button type="button" disabled={pending} onClick={() => send("not_found", null)} className={primary}>
              Als „kein Vorschlag“ bestätigen
            </button>
          ) : (
            <>
              <button type="button" disabled={pending} onClick={() => send("confirmed", null)} className={primary}>
                Bestätigen
              </button>
              <button type="button" disabled={pending || others.length === 0} onClick={() => setMode("change")} className={secondary}>
                Ändern
              </button>
              <button type="button" disabled={pending} onClick={() => send("rejected", null)} className={secondary}>
                Ablehnen
              </button>
            </>
          )}
          <Link href={`/visits/${l.visit_id}`} className="flex min-h-11 items-center px-1 text-sm font-semibold underline underline-offset-4">
            Einsatz öffnen
          </Link>
        </div>
      )}
      {open && mode === "change" && (
        <form
          aria-label="Zuteilung ändern"
          action={(form) => {
            const v = String(form.get("member") ?? "");
            if (v) void send("corrected", v);
          }}
          className="grid gap-2"
        >
          <label className="grid gap-1">
            <span className="text-xs font-semibold">Zuständig</span>
            <select name="member" required defaultValue="" className="min-h-11 rounded-lg border border-stone-300 bg-white px-2">
              <option value="" disabled>
                Person wählen
              </option>
              {others.map((m) => (
                <option key={m.member_id} value={m.member_id}>
                  {m.name ?? "Teammitglied"}
                </option>
              ))}
            </select>
          </label>
          <div className="flex gap-2">
            <button type="submit" disabled={pending} className={primary}>
              {pending ? "Wird gespeichert …" : "Geänderte Zuteilung bestätigen"}
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
