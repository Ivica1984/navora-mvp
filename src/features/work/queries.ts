import "server-only";

// WORK1 (migration 0079): the signed-in person's own working day. The database returns only her own rows (WORK1-5);
// there is no person argument. A failure never blocks the page.

import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import type { ConfirmedEntry, ProposalRow } from "./rules";

export type NoticeState = { textVersion: string; acknowledged: boolean };

export type DayVersion = {
  version: number;
  confirmed_at: string;
  day_start: string;
  day_end: string;
  breaks_answer: "none" | "listed";
  outside_answer: "none" | "listed";
  entries: ConfirmedEntry[];
  paid_minutes: number;
  care_minutes: number;
  break_minutes: number;
  reason_code: string | null;
  note: string | null;
};

/** WORK1-8: whether she acknowledged the current information text. */
export async function getWorkingTimeNotice(): Promise<NoticeState> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("my_working_time_notice");
  if (error) logEvent("error", "work.notice_failed", errorFields(error));
  const d = (data ?? {}) as { text_version?: string; acknowledged?: boolean };
  return { textVersion: String(d.text_version ?? ""), acknowledged: Boolean(d.acknowledged) };
}

/** WORK1-1: her proposal for a Zurich day (empty before the information text is acknowledged). */
export async function getMyWorkingDay(day: string): Promise<ProposalRow[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("my_working_day", { p_date: day });
  if (error) {
    logEvent("error", "work.proposal_failed", errorFields(error));
    return [];
  }
  return (data ?? []) as ProposalRow[];
}

/** WORK1-3: every confirmed version of her day, newest first. */
export async function getMyWorkingDayVersions(day: string): Promise<DayVersion[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("my_working_day_versions", { p_date: day });
  if (error) {
    logEvent("error", "work.versions_failed", errorFields(error));
    return [];
  }
  return (data ?? []).map((v) => ({
    ...v,
    entries: (Array.isArray(v.entries) ? v.entries : []) as ConfirmedEntry[],
    breaks_answer: v.breaks_answer as DayVersion["breaks_answer"],
    outside_answer: v.outside_answer as DayVersion["outside_answer"],
  }));
}
