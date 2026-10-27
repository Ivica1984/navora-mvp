"use client";

import { useState, useTransition, type ReactNode } from "react";
import { AppFrame } from "@/components/layout/Sidebar";
import type { AdminData, AdminExceptionRule, AdminMember, AdminTeam } from "@/features/admin/queries";
import {
  addTeamMember, createTeam, deactivateTeam, endMemberAccess, inviteMember, prepareMemberAccessEnd, removeTeamMember, resetExceptionRule,
  restoreMemberAccess, revokeInvitation, setDisplayName, setExceptionRule, setMemberQualification, setMemberRole,
  setResponseDeadline, updateTeam,
} from "@/features/admin/commands";
import {
  ROLES, ROLE_LABEL, QUALIFICATIONS, REFERRAL_TYPE_LABEL, UNIT_LABEL, DEADLINE_UNITS,
  allowedPriorities, changedLabel, checkRuleInput, isValidEmail, releasedNotice, RULES_INTRO, stricterHint,
  ACCESS_END_REASONS, ACCESS_REASON_LABEL, ACCESS_RESTORE_REASONS, OPEN_REPORT_LABEL, accessEndedNotice, countOpenReports,
  openReportsText, unexportedDaysText, unexportedEndPrompt,
} from "@/features/admin/rules";
import { QUALIFICATION_LABEL } from "@/features/team/rules";
import type { CommandResult } from "@/lib/commands/result";
import type { AdminPush } from "@/features/push/queries";
import OutsideDelivery from "./outside-section";
import EvaluatorHealthNotice from "@/components/signals/EvaluatorHealth";
import type { EvaluatorHealth, OutsideWatchedVisit } from "@/features/signals/rules";
import OutsideWatchedVisits from "@/components/signals/OutsideWatchedVisits";

const field = "min-h-10 rounded-lg border border-stone-300 bg-white px-2 text-sm";
const button = "min-h-10 rounded-lg bg-emerald-800 px-3 text-sm font-bold text-white disabled:opacity-60";
const secondary = "min-h-10 rounded-lg border border-stone-400 bg-white px-3 text-sm font-semibold";

type Run = (call: () => Promise<CommandResult>, done?: () => void) => void;

function useCommand(): { run: Run; pending: boolean; error: string | null; notice: string | null } {
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const run: Run = (call, done) => {
    setError(null);
    setNotice(null);
    start(async () => {
      const result = await call();
      if (result.ok) {
        setNotice("Gespeichert.");
        done?.();
      } else setError(result.error);
    });
  };
  return { run, pending, error, notice };
}

function Feedback({ error, notice }: { error: string | null; notice: string | null }) {
  if (error) return <p role="alert" data-testid="command-error" className="rounded-lg border border-rose-300 bg-rose-50 p-2 text-sm font-semibold text-rose-800">{error}</p>;
  if (notice) return <p role="status" className="text-sm text-emerald-900">{notice}</p>;
  return null;
}

const newKey = () => crypto.randomUUID();
const text = (f: FormData, k: string) => String(f.get(k) ?? "").trim();

export default function AdminClient({ data, push = null, evaluator = [], outsideWatched = [] }: {
  data: AdminData | null; push?: AdminPush | null; evaluator?: EvaluatorHealth[];
  /** SIG2-C1 (2): planned visits outside the watched hours (null: could not be loaded). */
  outsideWatched?: OutsideWatchedVisit[] | null;
}) {
  return (
    <AppFrame active="admin" style={{ background: "#f4f7f4", color: "#153328" }}>
      <main className="grid content-start gap-6 break-words p-4 md:p-8">
        <header>
          <p className="text-xs uppercase tracking-widest text-stone-500">Administration</p>
          <h2 className="text-2xl font-bold">Pilotbetrieb verwalten</h2>
          <p className="text-sm text-stone-600">Mitglieder, Teams und Betriebsregeln. Tarife und Referenzdaten ändern sich nur über eine geprüfte Migration mit Quelle.</p>
        </header>
        {!data ? (
          <p data-testid="admin-denied" className="rounded-xl border border-stone-300 bg-white p-4">
            Diese Seite ist der NAVORA-Administration vorbehalten.
          </p>
        ) : (
          <>
            <Members data={data} />
            <Invitations data={data} />
            <Teams data={data} />
            <Deadlines data={data} />
            <Rules data={data} />
            <EvaluatorHealthNotice health={evaluator} showRunning />
            {push && <OutsideDelivery organizationId={data.organizationId} push={push} />}
            <OutsideWatchedVisits rows={outsideWatched} />
          </>
        )}
      </main>
    </AppFrame>
  );
}

function Section({ title, label, children }: { title: string; label: string; children: ReactNode }) {
  return (
    <section aria-label={label} className="grid gap-3 rounded-2xl border border-stone-200 bg-white p-5">
      <h3 className="text-lg font-bold">{title}</h3>
      {children}
    </section>
  );
}

type TeamEntry = { team_id: string; team: string; qualification: string };
const teamsOf = (m: AdminMember): TeamEntry[] => (Array.isArray(m.teams) ? (m.teams as TeamEntry[]) : []);

// Members -------------------------------------------------------------------------------------------------------
function Members({ data }: { data: AdminData }) {
  return (
    <Section title="Mitglieder" label="Mitglieder">
      <ul className="grid gap-3">
        {data.members.map((m) => <MemberRow key={m.user_id} member={m} data={data} />)}
      </ul>
    </Section>
  );
}

function MemberRow({ member, data }: { member: AdminMember; data: AdminData }) {
  const { run, pending, error, notice } = useCommand();
  const [mode, setMode] = useState<"idle" | "name" | "role" | "team">("idle");
  // ADM1 changes: a removal releases her future planned visits to the team; the count stays visible here
  // (the membership row itself disappears after the removal).
  const [released, setReleased] = useState<string | null>(null);
  const activeTeams = data.teams.filter((t) => t.status !== "closed");
  const label = member.display_name || member.email;
  return (
    <li aria-label={`Mitglied ${label}`} className="grid gap-2 rounded-xl border border-stone-200 p-3">
      <p>
        <span className="font-semibold" data-testid="member-name">{member.display_name || "ohne Namen"}</span>
        {" · "}{member.email}{" · "}<span data-testid="member-role">{ROLE_LABEL[member.role] ?? member.role}</span>
      </p>
      <ul className="grid gap-1 text-sm" aria-label="Teams">
        {teamsOf(member).map((t) => (
          <TeamMembership key={t.team_id} entry={t} userId={member.user_id} onReleased={setReleased} />
        ))}
        {teamsOf(member).length === 0 && <li className="text-stone-500">in keinem Team</li>}
      </ul>
      {released && <p role="status" data-testid="released-visits" className="text-sm font-semibold text-amber-900">{released}</p>}
      <MemberAccess member={member} data={data} />
      {mode === "idle" && (
        <div className="flex flex-wrap gap-2">
          <button type="button" className={secondary} onClick={() => setMode("name")}>Name</button>
          <button type="button" className={secondary} onClick={() => setMode("role")}>Rolle</button>
          <button type="button" className={secondary} onClick={() => setMode("team")}>Zu Team hinzufügen</button>
        </div>
      )}
      {mode === "name" && (
        <form aria-label="Name ändern" className="flex flex-wrap items-end gap-2" onSubmit={(e) => {
          e.preventDefault();
          const f = new FormData(e.currentTarget);
          run(() => setDisplayName({ organizationId: data.organizationId, userId: member.user_id, displayName: text(f, "name"), idempotencyKey: newKey() }), () => setMode("idle"));
        }}>
          <label className="grid gap-1 text-xs font-semibold">Anzeigename<input name="name" required minLength={2} maxLength={80} defaultValue={member.display_name ?? ""} className={field} /></label>
          <button type="submit" disabled={pending} className={button}>Speichern</button>
          <button type="button" className={secondary} onClick={() => setMode("idle")}>Abbrechen</button>
        </form>
      )}
      {mode === "role" && (
        <form aria-label="Rolle ändern" className="flex flex-wrap items-end gap-2" onSubmit={(e) => {
          e.preventDefault();
          const f = new FormData(e.currentTarget);
          run(() => setMemberRole({ organizationId: data.organizationId, userId: member.user_id, role: text(f, "role"), reason: text(f, "reason"), idempotencyKey: newKey() }), () => setMode("idle"));
        }}>
          <label className="grid gap-1 text-xs font-semibold">Rolle
            <select name="role" defaultValue={member.role} className={field}>{ROLES.map((r) => <option key={r} value={r}>{ROLE_LABEL[r]}</option>)}</select>
          </label>
          <label className="grid gap-1 text-xs font-semibold">Begründung<input name="reason" required minLength={3} maxLength={300} className={field} /></label>
          <button type="submit" disabled={pending} className={button}>Speichern</button>
          <button type="button" className={secondary} onClick={() => setMode("idle")}>Abbrechen</button>
        </form>
      )}
      {mode === "team" && (
        <form aria-label="Zu Team hinzufügen" className="flex flex-wrap items-end gap-2" onSubmit={(e) => {
          e.preventDefault();
          const f = new FormData(e.currentTarget);
          run(() => addTeamMember({ teamId: text(f, "team"), userId: member.user_id, qualification: text(f, "qualification"), idempotencyKey: newKey() }), () => setMode("idle"));
        }}>
          <label className="grid gap-1 text-xs font-semibold">Team
            <select name="team" required defaultValue="" className={field}>
              <option value="" disabled>– bitte wählen –</option>
              {activeTeams.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
            </select>
          </label>
          <label className="grid gap-1 text-xs font-semibold">Qualifikation
            <select name="qualification" required defaultValue="" className={field}>
              <option value="" disabled>– bitte wählen –</option>
              {QUALIFICATIONS.map((q) => <option key={q} value={q}>{QUALIFICATION_LABEL[q]}</option>)}
            </select>
          </label>
          <button type="submit" disabled={pending} className={button}>Hinzufügen</button>
          <button type="button" className={secondary} onClick={() => setMode("idle")}>Abbrechen</button>
        </form>
      )}
      <Feedback error={error} notice={notice} />
    </li>
  );
}

// LEAVE1 (migrations 0074, 0075): her open reports (LEAVE1-12 (1)), ending and restoring her access.
const day = (iso: string | null | undefined) => {
  if (!iso) return "";
  const [y, m, d] = iso.slice(0, 10).split("-");
  return `${d}.${m}.${y}`;
};

function MemberAccess({ member, data }: { member: AdminMember; data: AdminData }) {
  const { run, pending, error, notice } = useCommand();
  const [mode, setMode] = useState<"idle" | "end" | "restore">("idle");
  const [ended, setEnded] = useState<string | null>(null);
  const state = data.access[member.user_id];
  const open = data.openReports[member.user_id] ?? [];
  // COND1-5a (PO 16:20), COND2-1 (ADR-101): her unexported-days count is read when the end step opens, through the
  // recorded prepare_member_access_end command, never shown in the row itself.
  const [unexported, setUnexported] = useState<number | null>(null);
  const openEnd = () => {
    setMode("end");
    setUnexported(null);
    prepareMemberAccessEnd({ userId: member.user_id, idempotencyKey: crypto.randomUUID() }).then(setUnexported, () => setUnexported(null));
  };
  return (
    <div className="grid gap-1 text-sm" aria-label="Zugang">
      {state?.ended && (
        <p data-testid="access-state" className="font-semibold text-rose-900">
          Zugang beendet seit {day(state.endedAt)}{state.reasonCode ? ` (${ACCESS_REASON_LABEL[state.reasonCode] ?? state.reasonCode})` : ""}
        </p>
      )}
      <div data-testid="open-reports">
        <p className="text-stone-700">Offene Berichte: {openReportsText(countOpenReports(open))}</p>
        {open.length > 0 && (
          <ul className="grid gap-0.5 pl-3 text-xs text-stone-700" aria-label="Offene Berichte">
            {open.map((r, i) => (
              <li key={`${r.visit_date}:${r.kind}:${i}`}>{day(r.visit_date)} · {r.team_name} · {OPEN_REPORT_LABEL[r.kind] ?? r.kind}</li>
            ))}
          </ul>
        )}
      </div>
      {ended && <p role="status" data-testid="access-ended-notice" className="font-semibold text-amber-900">{ended}</p>}
      {mode === "idle" && (
        <div className="flex flex-wrap gap-2">
          {state?.ended
            ? <button type="button" className={secondary} onClick={() => setMode("restore")}>Zugang wiederherstellen</button>
            : <button type="button" className={secondary} onClick={openEnd}>Zugang beenden</button>}
        </div>
      )}
      {mode !== "idle" && (
        <form aria-label={mode === "end" ? "Zugang beenden" : "Zugang wiederherstellen"} className="flex flex-wrap items-end gap-2" onSubmit={(e) => {
          e.preventDefault();
          const f = new FormData(e.currentTarget);
          setEnded(null);
          run(() => mode === "end"
            ? endMemberAccess({ userId: member.user_id, reasonCode: text(f, "reason"), idempotencyKey: newKey() })
                .then((r) => { if (r.ok) setEnded(accessEndedNotice(r.openReports, r.released, r.takenSignals, r.unexportedDays)); return r.ok ? { ok: true as const } : r; })
            : restoreMemberAccess({ userId: member.user_id, reasonCode: text(f, "reason"), idempotencyKey: newKey() }),
          () => setMode("idle"));
        }}>
          <label className="grid gap-1 text-xs font-semibold">Grund
            <select name="reason" required defaultValue="" className={field}>
              <option value="" disabled>– bitte wählen –</option>
              {(mode === "end" ? [...ACCESS_END_REASONS] as string[] : [...ACCESS_RESTORE_REASONS] as string[]).map((r) => (
                <option key={r} value={r}>{ACCESS_REASON_LABEL[r]}</option>
              ))}
            </select>
          </label>
          <button type="submit" disabled={pending} className={button}>{mode === "end" ? "Zugang beenden" : "Wiederherstellen"}</button>
          <button type="button" className={secondary} onClick={() => setMode("idle")}>Abbrechen</button>
          {mode === "end" && unexportedDaysText(unexported) && (
            // WORK1-C3 (a), COND1-5a: one number for this person now, administrators only, in the end step only.
            <p data-testid="unexported-end-count" className="w-full text-xs text-stone-700">{unexportedDaysText(unexported)}</p>
          )}
          {mode === "end" && unexportedEndPrompt(unexported) && (
            // G-19 item (4): ask her to export first; nothing is exported on her behalf.
            <p data-testid="unexported-end-prompt" className="w-full text-xs font-semibold text-amber-900">{unexportedEndPrompt(unexported)}</p>
          )}
          {mode === "end" && (
            <p className="w-full text-xs text-stone-600">
              Danach sieht sie keine Daten mehr und kann nichts mehr tun. Ihre geplanten Einsätze ab heute werden offen im Team. Ihre offenen Berichte bleiben für das Team sichtbar und werden nicht verrechnet.
            </p>
          )}
        </form>
      )}
      <Feedback error={error} notice={notice} />
    </div>
  );
}

function TeamMembership({ entry, userId, onReleased }: { entry: TeamEntry; userId: string; onReleased: (notice: string | null) => void }) {
  const { run, pending, error } = useCommand();
  const [mode, setMode] = useState<"idle" | "qualification" | "remove">("idle");
  return (
    <li className="grid gap-1">
      <span>
        {entry.team} · {QUALIFICATION_LABEL[entry.qualification] ?? entry.qualification}{" "}
        {mode === "idle" && (
          <>
            <button type="button" className="underline" onClick={() => setMode("qualification")}>Qualifikation ändern</button>{" · "}
            <button type="button" className="underline" onClick={() => setMode("remove")}>Aus Team entfernen</button>
          </>
        )}
      </span>
      {mode !== "idle" && (
        <form aria-label={mode === "remove" ? "Aus Team entfernen" : "Qualifikation ändern"} className="flex flex-wrap items-end gap-2" onSubmit={(e) => {
          e.preventDefault();
          const f = new FormData(e.currentTarget);
          onReleased(null);
          run(() => mode === "remove"
            ? removeTeamMember({ teamId: entry.team_id, userId, reason: text(f, "reason"), idempotencyKey: newKey() })
                .then((r) => { if (r.ok) onReleased(releasedNotice(r.released)); return r; })
            : setMemberQualification({ teamId: entry.team_id, userId, qualification: text(f, "qualification"), reason: text(f, "reason"), idempotencyKey: newKey() }),
          () => setMode("idle"));
        }}>
          {mode === "qualification" && (
            <label className="grid gap-1 text-xs font-semibold">Qualifikation
              <select name="qualification" defaultValue={entry.qualification} className={field}>
                {QUALIFICATIONS.map((q) => <option key={q} value={q}>{QUALIFICATION_LABEL[q]}</option>)}
              </select>
            </label>
          )}
          <label className="grid gap-1 text-xs font-semibold">Begründung<input name="reason" required minLength={3} maxLength={300} className={field} /></label>
          <button type="submit" disabled={pending} className={button}>{mode === "remove" ? "Entfernen" : "Speichern"}</button>
          <button type="button" className={secondary} onClick={() => setMode("idle")}>Abbrechen</button>
        </form>
      )}
      {error && <p role="alert" data-testid="command-error" className="text-sm font-semibold text-rose-800">{error}</p>}
    </li>
  );
}

// Invitations ----------------------------------------------------------------------------------------------------
function Invitations({ data }: { data: AdminData }) {
  const { run, pending, error, notice } = useCommand();
  const [localError, setLocalError] = useState<string | null>(null);
  const activeTeams = data.teams.filter((t) => t.status !== "closed");
  return (
    <Section title="Einladungen" label="Einladungen">
      <form aria-label="Person einladen" className="grid gap-2 md:grid-cols-3" onSubmit={(e) => {
        e.preventDefault();
        const form = e.currentTarget;
        const f = new FormData(form);
        const email = text(f, "email");
        const team = text(f, "team") || null;
        const qualification = text(f, "qualification") || null;
        if (!isValidEmail(email)) return setLocalError("Bitte eine gültige E-Mail angeben.");
        if ((team === null) !== (qualification === null)) return setLocalError("Für ein Team braucht es eine Qualifikation.");
        setLocalError(null);
        run(() => inviteMember({ organizationId: data.organizationId, email, role: text(f, "role"), displayName: text(f, "name"),
          teamId: team, qualification, idempotencyKey: newKey() }), () => form.reset());
      }}>
        <label className="grid gap-1 text-xs font-semibold">E-Mail<input name="email" type="email" required className={field} /></label>
        <label className="grid gap-1 text-xs font-semibold">Anzeigename<input name="name" required minLength={2} maxLength={80} className={field} /></label>
        <label className="grid gap-1 text-xs font-semibold">Rolle
          <select name="role" defaultValue="nurse" className={field}>{ROLES.map((r) => <option key={r} value={r}>{ROLE_LABEL[r]}</option>)}</select>
        </label>
        <label className="grid gap-1 text-xs font-semibold">Team (optional)
          <select name="team" defaultValue="" className={field}>
            <option value="">kein Team</option>
            {activeTeams.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
          </select>
        </label>
        <label className="grid gap-1 text-xs font-semibold">Qualifikation (mit Team)
          <select name="qualification" defaultValue="" className={field}>
            <option value="">–</option>
            {QUALIFICATIONS.map((q) => <option key={q} value={q}>{QUALIFICATION_LABEL[q]}</option>)}
          </select>
        </label>
        <div className="flex items-end"><button type="submit" disabled={pending} className={button}>Einladen</button></div>
      </form>
      <p className="text-xs text-stone-600">
        Die Einladung gilt 14 Tage. Meldet sich die Person mit dieser E-Mail an, wird sie Mitglied mit Rolle, Team und Qualifikation.
        Das Benutzerkonto und die Einladungs-E-Mail richtet vorerst die NAVORA-Betriebsverantwortung ein (Entscheid D-26 offen).
      </p>
      <Feedback error={localError ?? error} notice={notice} />
      <ul className="grid gap-1 text-sm" aria-label="Offene Einladungen">
        {data.invitations.map((i) => (
          <li key={i.id} className="flex flex-wrap items-center gap-2">
            <span>{i.display_name} · {i.email} · {ROLE_LABEL[i.role] ?? i.role}
              {i.team_id ? ` · ${data.teams.find((t) => t.id === i.team_id)?.name ?? "Team"} (${QUALIFICATION_LABEL[i.qualification ?? ""] ?? ""})` : ""}</span>
            <button type="button" disabled={pending} className="underline" onClick={() => run(() => revokeInvitation({ invitationId: i.id, idempotencyKey: newKey() }))}>Zurückziehen</button>
          </li>
        ))}
        {data.invitations.length === 0 && <li className="text-stone-500">keine offenen Einladungen</li>}
      </ul>
    </Section>
  );
}

// Teams -------------------------------------------------------------------------------------------------------------
function Teams({ data }: { data: AdminData }) {
  const { run, pending, error, notice } = useCommand();
  return (
    <Section title="Teams" label="Teams">
      <form aria-label="Team erstellen" className="flex flex-wrap items-end gap-2" onSubmit={(e) => {
        e.preventDefault();
        const form = e.currentTarget;
        const f = new FormData(form);
        run(() => createTeam({ organizationId: data.organizationId, name: text(f, "name"), region: text(f, "region"), idempotencyKey: newKey() }), () => form.reset());
      }}>
        <label className="grid gap-1 text-xs font-semibold">Teamname<input name="name" required minLength={2} maxLength={80} className={field} /></label>
        <label className="grid gap-1 text-xs font-semibold">Region<input name="region" required minLength={2} maxLength={80} className={field} /></label>
        <button type="submit" disabled={pending} className={button}>Team erstellen</button>
      </form>
      <Feedback error={error} notice={notice} />
      <ul className="grid gap-2">
        {data.teams.map((t) => <TeamRow key={t.id} team={t} />)}
      </ul>
    </Section>
  );
}

function TeamRow({ team }: { team: AdminTeam }) {
  const { run, pending, error } = useCommand();
  const [mode, setMode] = useState<"idle" | "edit" | "deactivate">("idle");
  const closed = team.status === "closed";
  return (
    <li aria-label={`Team ${team.name}`} className="grid gap-1 rounded-xl border border-stone-200 p-3 text-sm">
      <p><span className="font-semibold">{team.name}</span> · {team.region ?? "ohne Region"} · <span data-testid="team-status">{closed ? "deaktiviert" : "aktiv"}</span></p>
      {!closed && mode === "idle" && (
        <div className="flex gap-2">
          <button type="button" className={secondary} onClick={() => setMode("edit")}>Bearbeiten</button>
          <button type="button" className={secondary} onClick={() => setMode("deactivate")}>Deaktivieren</button>
        </div>
      )}
      {mode !== "idle" && (
        <form aria-label={mode === "edit" ? "Team bearbeiten" : "Team deaktivieren"} className="flex flex-wrap items-end gap-2" onSubmit={(e) => {
          e.preventDefault();
          const f = new FormData(e.currentTarget);
          run(() => mode === "edit"
            ? updateTeam({ teamId: team.id, name: text(f, "name"), region: text(f, "region"), idempotencyKey: newKey() })
            : deactivateTeam({ teamId: team.id, reason: text(f, "reason"), idempotencyKey: newKey() }), () => setMode("idle"));
        }}>
          {mode === "edit" ? (
            <>
              <label className="grid gap-1 text-xs font-semibold">Teamname<input name="name" required defaultValue={team.name} className={field} /></label>
              <label className="grid gap-1 text-xs font-semibold">Region<input name="region" required defaultValue={team.region ?? ""} className={field} /></label>
            </>
          ) : (
            <label className="grid gap-1 text-xs font-semibold">Begründung<input name="reason" required minLength={3} maxLength={300} className={field} /></label>
          )}
          <button type="submit" disabled={pending} className={button}>{mode === "edit" ? "Speichern" : "Deaktivieren"}</button>
          <button type="button" className={secondary} onClick={() => setMode("idle")}>Abbrechen</button>
        </form>
      )}
      {error && <p role="alert" data-testid="command-error" className="font-semibold text-rose-800">{error}</p>}
    </li>
  );
}

// Response deadlines ----------------------------------------------------------------------------------------------
function Deadlines({ data }: { data: AdminData }) {
  const { run, pending, error, notice } = useCommand();
  return (
    <Section title="Antwortfristen der Teams" label="Antwortfristen">
      <ul className="grid gap-2">
        {data.deadlines.map((d) => (
          <li key={d.referral_type} aria-label={`Frist ${REFERRAL_TYPE_LABEL[d.referral_type] ?? d.referral_type}`}>
            <form className="flex flex-wrap items-end gap-2 text-sm" onSubmit={(e) => {
              e.preventDefault();
              const f = new FormData(e.currentTarget);
              run(() => setResponseDeadline({ organizationId: data.organizationId, referralType: d.referral_type, amount: Number(text(f, "amount")),
                unit: text(f, "unit"), idempotencyKey: newKey() }));
            }}>
              <span className="w-32 font-semibold">{REFERRAL_TYPE_LABEL[d.referral_type] ?? d.referral_type}</span>
              <label className="grid gap-1 text-xs font-semibold">Frist<input name="amount" type="number" min={1} max={240} required defaultValue={d.amount ?? ""} className={field} /></label>
              <label className="grid gap-1 text-xs font-semibold">Einheit
                <select name="unit" defaultValue={d.unit ?? "working_days"} className={field}>{DEADLINE_UNITS.map((u) => <option key={u} value={u}>{UNIT_LABEL[u]}</option>)}</select>
              </label>
              <button type="submit" disabled={pending} className={secondary}>Speichern</button>
              <span className="text-xs text-stone-600" data-testid="deadline-changed">{changedLabel(d.is_default, d.updated_by_name, d.updated_at)}</span>
            </form>
          </li>
        ))}
      </ul>
      <Feedback error={error} notice={notice} />
    </Section>
  );
}

// Exception rules ---------------------------------------------------------------------------------------------------
function Rules({ data }: { data: AdminData }) {
  return (
    <Section title="Ausnahmen: Schwellen und Prioritäten" label="Ausnahmeregeln">
      <p className="text-xs text-stone-600">{RULES_INTRO}</p>
      <ul className="grid gap-2">{data.rules.map((r) => <RuleRow key={r.exception_type} rule={r} organizationId={data.organizationId} />)}</ul>
    </Section>
  );
}

function RuleRow({ rule, organizationId }: { rule: AdminExceptionRule; organizationId: string }) {
  const { run, pending, error } = useCommand();
  const [localError, setLocalError] = useState<string | null>(null);
  const range = { default_priority: rule.default_priority, default_amount: rule.default_amount, default_escalate: rule.default_escalate,
    min_amount: rule.min_amount, max_amount: rule.max_amount, max_escalate: rule.max_escalate,
    amount_direction: rule.amount_direction, unit: rule.unit };
  const hint = stricterHint(rule.amount_direction, rule.unit);
  return (
    <li aria-label={`Regel ${rule.label}`} className="rounded-xl border border-stone-200 p-3 text-sm">
      {/* noValidate: the safe range is checked below (and again in the database) with a clear message. */}
      <form noValidate className="flex flex-wrap items-end gap-2" onSubmit={(e) => {
        e.preventDefault();
        const f = new FormData(e.currentTarget);
        const priority = text(f, "priority");
        const amount = rule.default_amount === null ? null : Number(text(f, "amount"));
        const escalate = rule.default_escalate === null ? null : Number(text(f, "escalate"));
        const problem = checkRuleInput(range, priority, amount, escalate);
        if (problem) return setLocalError(problem);
        setLocalError(null);
        run(() => setExceptionRule({ organizationId, exceptionType: rule.exception_type, priority, amount, escalate, idempotencyKey: newKey() }));
      }}>
        <span className="w-64 font-semibold">{rule.label}</span>
        <label className="grid gap-1 text-xs font-semibold">Priorität
          <select name="priority" defaultValue={rule.priority} className={field}>
            {allowedPriorities(rule.default_priority).map((p) => <option key={p} value={p}>{p}</option>)}
          </select>
        </label>
        {rule.default_amount !== null && (
          <label className="grid gap-1 text-xs font-semibold">Schwelle ({UNIT_LABEL[rule.unit ?? ""] ?? rule.unit}, {rule.min_amount} bis {rule.max_amount})
            <input name="amount" type="number" min={rule.min_amount ?? 0} max={rule.max_amount ?? 0} required defaultValue={rule.amount ?? ""} className={field} />
          </label>
        )}
        {rule.default_escalate !== null && (
          <label className="grid gap-1 text-xs font-semibold">Eskalation nach (Stunden, max. {rule.max_escalate})
            <input name="escalate" type="number" min={0} max={rule.max_escalate ?? 0} required defaultValue={rule.escalate_to_p1_after_hours ?? ""} className={field} />
          </label>
        )}
        <button type="submit" disabled={pending} className={secondary}>Speichern</button>
        {!rule.is_default && (
          <button type="button" disabled={pending} className="underline"
            onClick={() => run(() => resetExceptionRule({ organizationId, exceptionType: rule.exception_type, idempotencyKey: newKey() }))}>
            Standard ({rule.default_priority}{rule.default_amount !== null ? `, ${rule.default_amount}` : ""}) wiederherstellen
          </button>
        )}
        {hint && <span className="w-full text-xs text-stone-600" data-testid="rule-direction">{hint}</span>}
        <span className="text-xs text-stone-600" data-testid="rule-changed">{changedLabel(rule.is_default, rule.updated_by_name, rule.updated_at)}</span>
      </form>
      {(localError ?? error) && <p role="alert" data-testid="command-error" className="font-semibold text-rose-800">{localError ?? error}</p>}
    </li>
  );
}
