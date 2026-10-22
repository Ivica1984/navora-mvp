import type { Database } from "@/lib/supabase/database.types";
import type { TenantRow } from "@/lib/supabase/tables";
import type { CaseSummaryRow } from "@/features/cases/types";
import type { TeamRow } from "@/features/teams/types";
import type { CareVisitRow } from "@/features/visits/types";


export type PartnerRequestRow = TenantRow<"partner_requests">;

export type CareNoteRow = TenantRow<"care_notes">;

export type QualityEventRow = TenantRow<"quality_events">;


// --- Minimal row shapes selected for Operations (T10, SR-06) ------------------

/** Only the review status of notes — never their clinical content. */

export type OperationsVisit = Pick<
  CareVisitRow,
  "id" | "case_id" | "visit_date" | "time_start" | "time_end" | "team_member_name" | "status" | "created_at"
> & { team_id: string | null };
export const OPERATIONS_VISIT_COLUMNS =
  "id, case_id, team_id, visit_date, time_start, time_end, team_member_name, status, created_at";

/** Exactly what is sent to the browser for /operations. */
export type OperationsDashboard = {
  cases: CaseSummaryRow[];
  teams: TeamRow[];
  visits: OperationsVisit[];
  /** OPS1: exceptions derived in the database with handling state (migration 0019). */
  exceptions: OperationsException[];
};

/** One row of public.operations_exceptions() — generated from the migration (T14). */
export type OperationsException = Database["public"]["Functions"]["operations_exceptions"]["Returns"][number];
