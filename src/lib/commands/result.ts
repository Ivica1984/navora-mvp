// Shared result model for Server Action commands (T10).
// Pure module — no "use server", so schemas and mappers can be unit-tested.

export type CommandResult = { ok: true } | { ok: false; error: string };

/** Codes returned by the Postgres command functions (migration …0004; VIS1 adds the day outcomes, 0089). */
export type DbCommandCode = "ok" | "duplicate" | "rejected" | "not_today" | "started_before_date";

/** VIS1 / CGR-87: a visit dated after today is not departed, started or ended (database outcome `not_today`). */
export const NOT_TODAY_MESSAGE =
  "Dieser Einsatz ist für einen späteren Tag geplant. Wenn du ihn heute machst, verschiebe ihn zuerst auf heute.";
/** VIS1 / CGR-87: a visit started before its day is not completed (database outcome `started_before_date`). */
export const STARTED_BEFORE_DATE_MESSAGE =
  "Dieser Einsatz wurde vor seinem geplanten Tag begonnen und kann so nicht abgeschlossen werden. Bitte im Team klären.";

type DbError = { code?: string } | null;

/**
 * Maps a command function's outcome to the UI result.
 * - ok / duplicate → success (a replayed idempotency key is not an error)
 * - rejected       → not permitted (RLS) or no longer in the expected state
 * - 23514          → state machine refused the transition
 * - 22023          → invalid input caught by the database
 * - NV001          → registered nurse required to start (J3, migration 0014)
 * - not_today / started_before_date → the visit's day (VIS1, migration 0089)
 */
export function toCommandResult(
  data: unknown,
  error: DbError,
  messages: { rejected: string; failed: string }
): CommandResult {
  if (error) {
    if (error.code === "23514") {
      return { ok: false, error: "Dieser Statuswechsel ist nicht erlaubt." };
    }
    if (error.code === "NV001") {
      return { ok: false, error: "Diesen Einsatz beginnt eine Pflegefachperson (Kategorie B oder Bedarfsabklärung)." };
    }
    if (error.code === "22023") {
      return { ok: false, error: "Ungültige Eingabe." };
    }
    return { ok: false, error: messages.failed };
  }
  if (data === "ok" || data === "duplicate") return { ok: true };
  if (data === "rejected") return { ok: false, error: messages.rejected };
  // VIS1 (migration 0089): the visit's day.
  if (data === "not_today") return { ok: false, error: NOT_TODAY_MESSAGE };
  if (data === "started_before_date") return { ok: false, error: STARTED_BEFORE_DATE_MESSAGE };
  return { ok: false, error: messages.failed };
}
