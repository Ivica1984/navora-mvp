// Shared result model for Server Action commands (T10).
// Pure module — no "use server", so schemas and mappers can be unit-tested.

export type CommandResult = { ok: true } | { ok: false; error: string };

/** Codes returned by the Postgres command functions (migration …0004). */
export type DbCommandCode = "ok" | "duplicate" | "rejected";

type DbError = { code?: string } | null;

/**
 * Maps a command function's outcome to the UI result.
 * - ok / duplicate → success (a replayed idempotency key is not an error)
 * - rejected       → not permitted (RLS) or no longer in the expected state
 * - 23514          → state machine refused the transition
 * - 22023          → invalid input caught by the database
 * - NV001          → registered nurse required to start (J3, migration 0014)
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
  return { ok: false, error: messages.failed };
}
