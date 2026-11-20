import "server-only";

// BK-f (contract 2026-11-20 06:39; migration 0156): readers of the simulated invoice views. Every row comes from a
// SECURITY DEFINER reader that checks the caller (take team, LEAVE1-3; client account member); the table itself has no
// grant to app roles. Nothing here widens a read or computes an amount.
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";

export type TeamInvoiceRow = {
  id: string;
  team_id: string;
  team_name: string;
  client_name: string | null;
  visit_date: string | null;
  state: string;
  refusal_reason: string | null;
  ordered_minutes: number | null;
  recorded_minutes: number | null;
  price_per_hour: number | null;
  amount_chf: number | null;
  currency: string;
  report_id: string;
  report_version: number;
  created_at: string;
  sent_at: string | null;
  voided_at: string | null;
  void_reason: string | null;
};

export type ClientInvoiceRow = {
  id: string;
  client_account_id: string;
  visit_date: string | null;
  hours: number | null;
  price_per_hour: number | null;
  amount_chf: number | null;
  currency: string;
  team_name: string;
  state: string;
  sent_at: string | null;
  voided_at: string | null;
};

/** BK-f (0155): the current price of one of the caller's teams (`my_team_prices()`); null when the team set none. */
export type TeamPriceRow = { team_id: string; team_name: string; price_per_hour: number | null; currency: string | null; set_at: string | null };

export type TakeInvoiceState = { state: string; refusal_reason: string | null; amount_chf: number | null };

// The generated types gain these readers with the db-types-sync commit; the rows are typed here from migration 0156.
type Rpc = (fn: string, args?: Record<string, unknown>) => PromiseLike<{ data: unknown; error: { message: string } | null }>;

export async function getMyTeamInvoiceDrafts(): Promise<TeamInvoiceRow[]> {
  const { supabase } = await requireUser();
  const { data, error } = await (supabase.rpc as unknown as Rpc)("my_team_invoice_drafts");
  if (error) {
    logEvent("error", "bk_f.team_invoice_drafts_failed", errorFields(error));
    throw new Error("Rechnungsentwürfe konnten nicht geladen werden.");
  }
  return (data ?? []) as TeamInvoiceRow[];
}

export async function getMyTeamPrices(): Promise<TeamPriceRow[]> {
  const { supabase } = await requireUser();
  const { data, error } = await (supabase.rpc as unknown as Rpc)("my_team_prices");
  if (error) {
    logEvent("error", "bk_f.team_prices_failed", errorFields(error));
    throw new Error("Stundenpreise konnten nicht geladen werden.");
  }
  return (data ?? []) as TeamPriceRow[];
}

export async function getClientInvoices(): Promise<ClientInvoiceRow[]> {
  const { supabase } = await requireUser();
  const { data, error } = await (supabase.rpc as unknown as Rpc)("client_invoices");
  if (error) {
    logEvent("error", "bk_f.client_invoices_failed", errorFields(error));
    throw new Error("Rechnungen konnten nicht geladen werden.");
  }
  return (data ?? []) as ClientInvoiceRow[];
}

/** /field: the newest invoice row per taken-shift visit (only visits whose report is final are asked). */
export async function getTakeInvoiceStates(visitIds: string[]): Promise<Record<string, TakeInvoiceState>> {
  if (visitIds.length === 0) return {};
  const { supabase } = await requireUser();
  const out: Record<string, TakeInvoiceState> = {};
  await Promise.all(
    visitIds.map(async (id) => {
      const { data, error } = await (supabase.rpc as unknown as Rpc)("my_take_invoice_state", { p_visit_id: id });
      if (error) {
        // Display only: a failed read hides the line, it never blocks the card or the signature.
        logEvent("warn", "bk_f.take_invoice_state_failed", errorFields(error));
        return;
      }
      const row = ((data ?? []) as TakeInvoiceState[])[0];
      if (row) out[id] = row;
    }),
  );
  return out;
}
