import "server-only";

import { requireUser } from "@/lib/auth/session";
import { CASE_SUMMARY_COLUMNS, type CaseSummaryRow } from "@/features/cases/types";
import type { TeamRow } from "@/features/teams/types";
import {
  OPERATIONS_VISIT_COLUMNS,
  type OperationsDashboard,
  type OperationsException,
  type OperationsVisit,
} from "./types";
import { errorFields, logEvent } from "@/lib/log";

const TEAM_COLUMNS =
  "id, name, region, care_focus, status, open_slots, utilization, lead_name, next_step, created_at, priority, coach_name";

/**
 * Data for /operations (T10, SR-06):
 * - every select lists only the columns the UI needs;
 * - ADM1: the unvalidated prototype hints (and the partner-request and quality-event reads that fed only
 *   them) were removed; OPS1 exceptions are the validated source;
 * - OPS1 exceptions are derived in the database (operations_exceptions, migration 0019);
 * - the returned object is exactly what is serialised to the browser.
 * RLS (T9) limits all rows to the user's organisation.
 */
export async function getOperationsDashboard(): Promise<OperationsDashboard> {
  // Runs as the signed-in user (RLS sees auth.uid()); redirects to /login otherwise.
  const { supabase } = await requireUser();

  // OPS1: close handled exceptions whose cause is gone (writes an auto-close note; idempotent).
  const sync = await supabase.rpc("sync_exceptions");
  if (sync.error) logEvent("warn", "operations.sync_failed", errorFields(sync.error));

  const [casesResult, teamsResult, visitsResult, exceptionsResult] =
    await Promise.all([
      supabase.from("cases").select(CASE_SUMMARY_COLUMNS).order("created_at", { ascending: false }),
      supabase.from("teams").select(TEAM_COLUMNS).order("created_at", { ascending: true }),
      supabase.from("care_visits").select(OPERATIONS_VISIT_COLUMNS).order("visit_date", { ascending: true }),
      // OPS1: derived exceptions with handling state (coordination roles only; empty for others).
      supabase.rpc("operations_exceptions"),
    ]);

  const firstError = [
    casesResult,
    teamsResult,
    visitsResult,
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
  const visits: OperationsVisit[] = visitsResult.data ?? [];
  const exceptions: OperationsException[] = exceptionsResult.data ?? [];

  return { cases, teams, visits, exceptions };
}
