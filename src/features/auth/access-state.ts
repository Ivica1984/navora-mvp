/**
 * LEAVE1-6 (migrations 0074, 0075): the signed-in person's own access state, from `public.my_access_state()`.
 * Only `{ended, ended_at}`: no reason code, names or counts reach the app.
 */
export type AccessState = { ended: boolean; endedAt: string | null };

/** The one text a person whose access ended sees, on every protected route. */
export const ACCESS_ENDED_MESSAGE = "Ihr Zugang ist beendet. Bitte wenden Sie sich an Ihre Organisation.";

/**
 * Reads the RPC result defensively. Anything unexpected counts as "not ended": the database still refuses every read
 * and command for her (LEAVE1-3), so this screen is a courtesy, never the control.
 */
export function parseAccessState(data: unknown): AccessState {
  if (!data || typeof data !== "object" || Array.isArray(data)) return { ended: false, endedAt: null };
  const v = data as Record<string, unknown>;
  return {
    ended: v.ended === true,
    endedAt: v.ended === true && typeof v.ended_at === "string" ? v.ended_at : null,
  };
}
