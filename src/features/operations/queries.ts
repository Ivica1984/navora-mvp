import "server-only";

import { requireUser } from "@/lib/auth/session";
import { CASE_SUMMARY_COLUMNS, type CaseSummaryRow } from "@/features/cases/types";
import type { TeamRow } from "@/features/teams/types";
import type { OperationsDashboard, OperationsException } from "./types";
import { errorFields, logEvent } from "@/lib/log";

const TEAM_COLUMNS =
  "id, name, region, care_focus, status, open_slots, utilization, lead_name, next_step, created_at, priority, coach_name";

/**
 * Data for /operations (T10, SR-06):
 * - every select lists only the columns the UI needs;
 * - ADM1: the unvalidated prototype hints (and the partner-request and quality-event reads that fed only
 *   them) were removed; OPS1 exceptions are the validated source;
 * - OPS1 exceptions are derived in the database (operations_exceptions, migration 0019);
 * - COND2-3 (IPA1-C1, ADR-101): no care_visits read. Nothing on the page shows a visit list since IPA1
 *   (ADR-099), so the visit rows with the nurse's name are neither loaded nor sent to the browser;
 * - the returned object is exactly what is serialised to the browser.
 * RLS (T9) limits all rows to the user's organisation.
 */
export async function getOperationsDashboard(): Promise<OperationsDashboard> {
  // Runs as the signed-in user (RLS sees auth.uid()); redirects to /login otherwise.
  const { supabase } = await requireUser();

  // OPS1: close handled exceptions whose cause is gone (writes an auto-close note; idempotent).
  const sync = await supabase.rpc("sync_exceptions");
  if (sync.error) logEvent("warn", "operations.sync_failed", errorFields(sync.error));

  const [casesResult, teamsResult, exceptionsResult] =
    await Promise.all([
      supabase.from("cases").select(CASE_SUMMARY_COLUMNS).order("created_at", { ascending: false }),
      supabase.from("teams").select(TEAM_COLUMNS).order("created_at", { ascending: true }),
      // OPS1: derived exceptions with handling state (coordination roles only; empty for others).
      supabase.rpc("operations_exceptions"),
    ]);

  const firstError = [
    casesResult,
    teamsResult,
    exceptionsResult,
  ].find((result) => result.error)?.error;

  if (firstError) {
    logEvent("error", "operations.load_failed", errorFields(firstError));
    throw new Error("Operations Dashboard konnte nicht geladen werden.");
  }

  // No casts (T14): the typed client checks that each select returns exactly
  // the shape the rules and the view expect.
  const cases: CaseSummaryRow[] = casesResult.data ?? [];
  const teams: TeamRow[] = teamsResult.data ?? [];
  const exceptions: OperationsException[] = exceptionsResult.data ?? [];

  return { cases, teams, exceptions };
}
