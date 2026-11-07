import type { Database } from "@/lib/supabase/database.types";
import type { TenantRow } from "@/lib/supabase/tables";
import type { CaseSummaryRow } from "@/features/cases/types";
import type { TeamRow } from "@/features/teams/types";


export type PartnerRequestRow = TenantRow<"partner_requests">;

export type CareNoteRow = TenantRow<"care_notes">;

export type QualityEventRow = TenantRow<"quality_events">;


// --- Minimal row shapes selected for Operations (T10, SR-06) ------------------

// COND2-3 (IPA1-C1, ADR-101): OperationsVisit and OPERATIONS_VISIT_COLUMNS were removed with the
// care_visits read; /operations shows no visit list and receives none.

/** Exactly what is sent to the browser for /operations. */
export type OperationsDashboard = {
  cases: CaseSummaryRow[];
  teams: TeamRow[];
  /** OPS1: exceptions derived in the database with handling state (migration 0019). */
  exceptions: OperationsException[];
};

/** One row of public.operations_exceptions() — generated from the migration (T14). */
export type OperationsException = Database["public"]["Functions"]["operations_exceptions"]["Returns"][number];
