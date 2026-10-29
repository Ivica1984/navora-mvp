/**
 * LEAVE1-6 (migrations 0074, 0075): the signed-in person's own access state, from `public.my_access_state()`.
 * Only `{ended, ended_at, starts_on}`: no reason code, names or counts reach the app. ADM2-6 (migration 0092): before
 * her recorded contract start she has no access either; `starts_on` names that date.
 */
export type AccessState = { ended: boolean; endedAt: string | null; startsOn?: string | null };

/** The one text a person whose access ended sees, on every protected route. */
export const ACCESS_ENDED_MESSAGE = "Ihr Zugang ist beendet. Bitte wenden Sie sich an Ihre Organisation.";

/**
 * Reads the RPC result defensively. Anything unexpected counts as "not ended": the database still refuses every read
 * and command for her (LEAVE1-3), so this screen is a courtesy, never the control.
 */
export function parseAccessState(data: unknown): AccessState {
  if (!data || typeof data !== "object" || Array.isArray(data)) return { ended: false, endedAt: null };
  const v = data as Record<string, unknown>;
  const state: AccessState = {
    ended: v.ended === true,
    endedAt: v.ended === true && typeof v.ended_at === "string" ? v.ended_at : null,
  };
  if (v.ended === true && typeof v.starts_on === "string" && /^\d{4}-\d{2}-\d{2}$/.test(v.starts_on)) state.startsOn = v.starts_on;
  return state;
}
