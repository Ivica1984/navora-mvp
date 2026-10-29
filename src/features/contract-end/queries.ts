import "server-only";

import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import {
  currentContracts, readHandover, readMyContractEnd, readSuccessorItems,
  type Contract, type ContractRow, type Leaver, type MyContractEnd, type SuccessorItem,
} from "./rules";

/** ADM2-11: the current contract per member of the organisation (administrators read the record, RLS 0091). */
export async function getAdminContracts(organizationId: string): Promise<Record<string, Contract>> {
  const { supabase } = await requireUser();
  const r = await supabase.from("member_contract_events").select("user_id, start_date, end_date, seq").eq("organization_id", organizationId);
  if (r.error) {
    logEvent("error", "contract_end.contracts_failed", errorFields(r.error));
    return {};
  }
  return currentContracts((r.data ?? []) as ContractRow[]);
}

/** ADM2-12 / ADM2-15 (a): leavers in the next 14 days (administrators; registered nurses of their teams). */
export async function getContractEndHandover(): Promise<Leaver[]> {
  const { supabase } = await requireUser();
  const r = await supabase.rpc("contract_end_handover");
  if (r.error) {
    logEvent("error", "contract_end.handover_failed", errorFields(r.error));
    return [];
  }
  return readHandover(r.data);
}

/** ADM2-15 (b): open cases of the caller's teams that still name a person whose access ended. */
export async function getSuccessorItems(): Promise<SuccessorItem[]> {
  const { supabase } = await requireUser();
  const r = await supabase.rpc("team_successor_items");
  if (r.error) {
    logEvent("error", "contract_end.successor_failed", errorFields(r.error));
    return [];
  }
  return readSuccessorItems(r.data);
}

/** ADM2-14 (a): her own end date and access-end date in the 14-day window (null otherwise). */
export async function getMyContractEnd(): Promise<MyContractEnd | null> {
  const { supabase } = await requireUser();
  const r = await supabase.rpc("my_contract_end");
  if (r.error) {
    logEvent("error", "contract_end.mine_failed", errorFields(r.error));
    return null;
  }
  return readMyContractEnd(r.data);
}

export type LeaverOpenReport = { kind: string; visit_date: string; team_name: string };

/**
 * ADM2-12: her open reports by kind, visit date and team, from the existing LEAVE1-12 list (`member_open_reports`, same
 * readers: the organisation's administrators and the registered nurses of the report's team). One call per leaver.
 */
export async function getLeaverOpenReports(leavers: Leaver[]): Promise<Record<string, LeaverOpenReport[]>> {
  if (leavers.length === 0) return {};
  const { supabase } = await requireUser();
  const lists = await Promise.all(leavers.map((l) => supabase.rpc("member_open_reports", { p_user_id: l.user_id })));
  const out: Record<string, LeaverOpenReport[]> = {};
  lists.forEach((r, i) => {
    if (r.error) {
      logEvent("error", "contract_end.open_reports_failed", errorFields(r.error));
      return;
    }
    out[leavers[i].user_id] = (r.data ?? []) as LeaverOpenReport[];
  });
  return out;
}
