// Shared result model for Server Action commands (T10).
// Pure module — no "use server", so schemas and mappers can be unit-tested.

import { qualRefusalText, type QualContext, type QualSubject } from "@/features/qualification/refusals";

export type CommandResult = { ok: true } | { ok: false; error: string };

/** Codes returned by the Postgres command functions (migration …0004; VIS1 adds the day outcomes, 0089). */
export type DbCommandCode =
  | "ok"
  | "duplicate"
  | "rejected"
  | "not_today"
  | "started_before_date"
  | "qualification_missing";

/** VIS1 / CGR-87: a visit dated after today is not departed, started or ended (database outcome `not_today`). */
export const NOT_TODAY_MESSAGE =
  "Dieser Einsatz ist für einen späteren Tag geplant. Wenn du ihn heute machst, verschiebe ihn zuerst auf heute.";
/** VIS1 / CGR-87: a visit started before its day is not completed (database outcome `started_before_date`). */
export const STARTED_BEFORE_DATE_MESSAGE =
  "Dieser Einsatz wurde vor seinem geplanten Tag begonnen und kann so nicht abgeschlossen werden. Bitte im Team klären.";

/**
 * ADM2-16 / CGR-92 (migration 0094): a member whose qualification is not yet recorded does not depart, start, resume or
 * complete a visit (database outcome `qualification_missing`). The administrator records it (ADM2-6).
 */
export const QUALIFICATION_MISSING_MESSAGE =
  "Deine Qualifikation ist noch nicht erfasst. Einsätze führst du durch, sobald die Administration sie eingetragen hat.";

/**
 * QUAL1-10 (migration 0121, ADR-164/-165): in a simulation organisation the database refuses a write that makes a member
 * responsible for or covering a visit for which the qualification check does not confirm every activity (42501
 * `qualification_not_allowed`). QUAL1-17: the check runs again at the start (42501 `qualification_lapsed`).
 * QUAL1-21 (ADR-166): the texts come from the one function in `@/features/qualification/refusals`; wording PROPOSED
 * (`uxa`), `cra` to confirm. They name no activity code, no rule state and no reason: the database detail may name the
 * member's evidence (CGR-152) and is never shown.
 */
export const QUALIFICATION_NOT_ALLOWED_MESSAGE = qualRefusalText("qualification_not_allowed", { kind: "chosen" }, "save");
export const QUALIFICATION_LAPSED_MESSAGE = qualRefusalText("qualification_lapsed", { kind: "self" }, "start");

type DbError = { code?: string; message?: string } | null;

/**
 * The QUAL1 refusal text for a database error, or null when the error is something else. Only 42501 with the exact
 * message counts (another 42501 is RLS, ADM2-6 or an AI prohibition). Commands call it before their generic branch.
 * `subject`/`context` default to an assignment write for "the chosen person"; take and cover pass `self`/`take`.
 * The lapsed refusal is always her own start.
 */
export function qualificationRefusal(
  error: { code?: string; message?: string } | null | undefined,
  opts: { subject?: QualSubject; context?: QualContext } = {},
): string | null {
  if (!error || error.code !== "42501") return null;
  if (error.message === "qualification_not_allowed") {
    return qualRefusalText("qualification_not_allowed", opts.subject ?? { kind: "chosen" }, opts.context ?? "save");
  }
  if (error.message === "qualification_lapsed") return QUALIFICATION_LAPSED_MESSAGE;
  return null;
}

/**
 * Maps a command function's outcome to the UI result.
 * - ok / duplicate → success (a replayed idempotency key is not an error)
 * - rejected       → not permitted (RLS) or no longer in the expected state
 * - 23514          → state machine refused the transition
 * - 22023          → invalid input caught by the database
 * - NV001          → registered nurse required to start (J3, migration 0014)
 * - not_today / started_before_date → the visit's day (VIS1, migration 0089)
 * - qualification_missing → no recorded qualification (ADM2-16, migration 0094)
 * - 42501 qualification_not_allowed / qualification_lapsed → the QUAL1 check (migration 0121, simulation only)
 */
export function toCommandResult(
  data: unknown,
  error: DbError,
  messages: { rejected: string; failed: string }
): CommandResult {
  if (error) {
    const qual = qualificationRefusal(error);
    if (qual) return { ok: false, error: qual };
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
  // ADM2-16 (migration 0094): no visit without a recorded qualification.
  if (data === "qualification_missing") return { ok: false, error: QUALIFICATION_MISSING_MESSAGE };
  return { ok: false, error: messages.failed };
}
