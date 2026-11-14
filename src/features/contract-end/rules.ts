// ADM2 part (b): the recorded contract end ends access on time (migration 0092, ADR-115). Pure helpers and labels, no
// Next or Supabase imports. The database decides every rule (window, access end, release, readers); these helpers only
// read and word its result.

const isObj = (v: unknown): v is Record<string, unknown> => typeof v === "object" && v !== null && !Array.isArray(v);
const isDate = (v: unknown): v is string => typeof v === "string" && /^\d{4}-\d{2}-\d{2}$/.test(v);

/** "2026-11-18" → "18.11.2026" (a calendar date, no time zone). */
export function dayLabel(iso: string | null | undefined): string {
  if (!iso || !isDate(iso.slice(0, 10))) return "";
  const [y, m, d] = iso.slice(0, 10).split("-");
  return `${d}.${m}.${y}`;
}

/** Messages for the results of `set_member_contract_end`. */
export const CONTRACT_END_MESSAGES: Record<string, string> = {
  invalid: "Bitte ein gültiges Datum angeben.",
  failed: "Das Vertragsende konnte nicht gespeichert werden.",
  rejected: "Nur die Administration ihrer Organisation darf das Vertragsende erfassen.",
  self: "Das eigene Vertragsende erfasst eine andere Administratorin.",
  admission_off: "Das Vertragsende wird mit der Aufnahme durch das Team erfasst; diese ist nicht eingeschaltet.",
  in_past: "Das Vertragsende liegt in der Vergangenheit. Ein früheres Ende braucht «Zugang beenden».",
  access_ended: "Ihr Zugang ist schon beendet. Zuerst den Zugang wiederherstellen.",
  no_contract: "Es ist kein Vertragsende erfasst.",
  last_admin: "Sie ist die letzte Administratorin mit Zugang. Zuerst eine weitere Administratorin bestimmen.",
  has_planned_visits: "Sie vertritt nach dem Vertragsende geplante Einsätze eines anderen Teams. Diese zuerst klären.",
};

/** The newest contract row per person (member_contract_events: the newest row is current). */
export type ContractRow = { user_id: string; start_date: string | null; end_date: string | null; seq: number };
export type Contract = { startDate: string | null; endDate: string | null };

export function currentContracts(rows: ContractRow[]): Record<string, Contract> {
  const out: Record<string, Contract & { seq: number }> = {};
  for (const r of rows) {
    if (!r || typeof r.user_id !== "string" || typeof r.seq !== "number") continue;
    const cur = out[r.user_id];
    if (!cur || r.seq > cur.seq) {
      out[r.user_id] = { startDate: isDate(r.start_date) ? r.start_date : null, endDate: isDate(r.end_date) ? r.end_date : null, seq: r.seq };
    }
  }
  return Object.fromEntries(Object.entries(out).map(([k, v]) => [k, { startDate: v.startDate, endDate: v.endDate }]));
}

/** The calendar day after a date ("access ends at the start of the Zurich day after the end date"). */
export function dayAfter(iso: string): string {
  const [y, m, d] = iso.split("-").map(Number);
  const t = new Date(Date.UTC(y, m - 1, d + 1));
  return t.toISOString().slice(0, 10);
}

/** The line in the administrator's member row. */
export function contractEndLine(c: Contract | undefined, today: string): string | null {
  if (!c?.endDate) return null;
  return c.endDate < today
    ? `Vertrag endete am ${dayLabel(c.endDate)}; Zugang beendet seit ${dayLabel(dayAfter(c.endDate))} (Vertragsende).`
    : `Vertragsende ${dayLabel(c.endDate)} · Zugang endet am ${dayLabel(dayAfter(c.endDate))} ohne weiteren Schritt.`;
}

/** The success notice after recording the end date (her released visits per team). */
export function contractEndNotice(released: Record<string, number> | null | undefined, accessEndsOn: string | null): string {
  const n = Object.values(released ?? {}).reduce((a, b) => a + (Number.isInteger(b) ? b : 0), 0);
  const when = accessEndsOn ? ` Ihr Zugang endet am ${dayLabel(accessEndsOn)}.` : "";
  if (n === 0) return `Vertragsende gespeichert.${when}`;
  return `Vertragsende gespeichert.${when} ${n === 1 ? "1 geplanter Einsatz nach dem Vertragsende ist" : `${n} geplante Einsätze nach dem Vertragsende sind`} jetzt offen im Team.`;
}

// ADM2-12 / ADM2-15 (a): the handover list ---------------------------------------------------------------------------------
export type HandoverCase = { case_id: string; case_ref: string; team: string; role: "primary" | "deputy" };
export type HandoverVisit = { case_ref: string; visit_date: string; team: string; role: "responsible" | "covering" };
export type Leaver = {
  user_id: string;
  member_name: string | null;
  end_date: string;
  access_ends_on: string;
  teams: string[];
  cases: HandoverCase[];
  visits: HandoverVisit[];
};

export function readHandover(raw: unknown): Leaver[] {
  if (!Array.isArray(raw)) return [];
  return raw.filter(isObj).filter((x) => typeof x.user_id === "string" && isDate(x.end_date)).map((x) => ({
    user_id: x.user_id as string,
    member_name: typeof x.member_name === "string" ? x.member_name : null,
    end_date: x.end_date as string,
    access_ends_on: isDate(x.access_ends_on) ? x.access_ends_on : dayAfter(x.end_date as string),
    teams: Array.isArray(x.teams) ? x.teams.filter((t): t is string => typeof t === "string") : [],
    cases: Array.isArray(x.cases) ? (x.cases.filter(isObj) as unknown as HandoverCase[]) : [],
    visits: Array.isArray(x.visits) ? (x.visits.filter(isObj) as unknown as HandoverVisit[]) : [],
  }));
}

export const CASE_ROLE_LABEL: Record<string, string> = { primary: "Bezugspflege", deputy: "Stellvertretung" };
export const VISIT_ROLE_LABEL: Record<string, string> = { responsible: "verantwortlich", covering: "vertritt" };

export const caseRefLabel = (ref: string) => `Fall-Ref. ${ref}`;

/**
 * ADM2-15 (c), ADR-115 addendum: the same reference as `private.case_reference` (0092), computed from the case id the
 * card already has (last six hex digits, upper case). No new read path; pgTAP 092 and vitest pin the same example.
 */
export function caseReference(caseId: string): string {
  return caseId.replace(/-/g, "").slice(-6).toUpperCase();
}

/** ADM2-15 (c): the anchor of a case card's "Kontinuität" section on /team. */
export const continuityAnchorId = (caseId: string) => `kontinuitaet-${caseId}`;

export function leaverHeadline(l: Pick<Leaver, "member_name" | "end_date" | "access_ends_on">): string {
  return `${l.member_name ?? "Teammitglied"}: Vertragsende ${dayLabel(l.end_date)}, Zugang endet am ${dayLabel(l.access_ends_on)}`;
}

// ADM2-15 (b): open responsibilities of a person whose access ended -------------------------------------------------------------
export type SuccessorItem = {
  case_id: string;
  case_ref: string;
  team_id: string;
  team: string;
  role: "primary" | "deputy";
  member_name: string | null;
  access_ended_on: string | null;
};

export function readSuccessorItems(raw: unknown): SuccessorItem[] {
  if (!Array.isArray(raw)) return [];
  return raw.filter(isObj).filter((x) => typeof x.case_id === "string" && (x.role === "primary" || x.role === "deputy"))
    .map((x) => ({
      case_id: x.case_id as string,
      case_ref: typeof x.case_ref === "string" ? x.case_ref : "",
      team_id: typeof x.team_id === "string" ? x.team_id : "",
      team: typeof x.team === "string" ? x.team : "",
      role: x.role as "primary" | "deputy",
      member_name: typeof x.member_name === "string" ? x.member_name : null,
      access_ended_on: isDate(x.access_ended_on) ? x.access_ended_on : null,
    }));
}

/** "Bezugspflege neu bestimmen" / "Stellvertretung neu bestimmen" (brief ADM2-15 (b)). */
export function successorTitle(role: SuccessorItem["role"]): string {
  return role === "primary" ? "Bezugspflege neu bestimmen" : "Stellvertretung neu bestimmen";
}

export function successorLine(i: SuccessorItem): string {
  const since = i.access_ended_on ? ` seit ${dayLabel(i.access_ended_on)}` : "";
  return `${caseRefLabel(i.case_ref)} · ${i.team}: ${i.member_name ?? "Teammitglied"} (${CASE_ROLE_LABEL[i.role]}) hat keinen Zugang mehr${since}. Das Team bestimmt, wer übernimmt.`;
}

// ADM2-14 (a): her own notice ----------------------------------------------------------------------------------------------------
export type MyContractEnd = { end_date: string; access_ends_on: string };

export function readMyContractEnd(raw: unknown): MyContractEnd | null {
  if (!isObj(raw) || !isDate(raw.end_date)) return null;
  return { end_date: raw.end_date, access_ends_on: isDate(raw.access_ends_on) ? raw.access_ends_on : dayAfter(raw.end_date) };
}

export function myContractEndText(c: MyContractEnd): string {
  return `Dein Vertrag endet am ${dayLabel(c.end_date)}. Ab ${dayLabel(c.access_ends_on)} hast du keinen Zugang mehr zu NAVORA. Exportiere vorher deine bestätigten Arbeitstage.`;
}

/** LEAVE1-6 / ADM2-6: the text before her contract start. */
export function accessStartsText(startsOn: string): string {
  return `Ihr Zugang beginnt am ${dayLabel(startsOn)}, mit Ihrem Vertragsbeginn.`;
}

/** The Zurich calendar date (YYYY-MM-DD) of an instant. */
export function zurichDay(iso: string): string {
  const parts = new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Zurich", year: "numeric", month: "2-digit", day: "2-digit" })
    .formatToParts(new Date(iso));
  const get = (t: string) => parts.find((p) => p.type === t)?.value ?? "";
  return `${get("year")}-${get("month")}-${get("day")}`;
}

/**
 * ADM2-13: the administrator's view of her access, as the database decides it (private.access_ended, 0092): ended from
 * the Zurich day after her recorded end date, unless an access event was recorded on or after that day (a restore).
 * Only for display; the database is the control.
 */
export function withContractEnds<T extends { ended: boolean; endedAt: string | null; reasonCode: string | null }>(
  access: Record<string, T>, contracts: Record<string, Contract>, lastEventAt: Record<string, string>, today: string,
): Record<string, T | { ended: true; endedAt: string; reasonCode: "contract_end" }> {
  const out: Record<string, T | { ended: true; endedAt: string; reasonCode: "contract_end" }> = { ...access };
  for (const [user, c] of Object.entries(contracts)) {
    if (!c.endDate) continue;
    const from = dayAfter(c.endDate);
    if (from > today) continue;
    const last = lastEventAt[user];
    if (last && zurichDay(last) >= from) continue;
    if (out[user]?.ended) continue;
    out[user] = { ended: true, endedAt: from, reasonCode: "contract_end" };
  }
  return out;
}
