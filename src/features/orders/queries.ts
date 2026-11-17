import "server-only";

// BK-a (ADR-194): data for /order. The client reads only through its own functions (ADR-192 (3)) and the reference
// lists every signed-in user reads (postcodes, activity list). No team, case or member data.
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";

export type ClientAccount = { id: string; display_name: string; client_kind: string };
export type PostcodeOption = { postcode: string; place_name: string; region_name: string };
export type ActivityOption = { code: string; label_de: string };
export type ClientOrder = {
  id: string;
  sentence: string;
  shift_label: string | null;
  radius_km: number | null;
  activity_tags: string[];
  required_tags: string[];
  cover_state: string;
};

export type ClientOrderPage = {
  accounts: ClientAccount[];
  postcodes: PostcodeOption[];
  activities: ActivityOption[];
  orders: ClientOrder[];
  /** The Zurich calendar date, for the date words (AUT-120). */
  today: string;
};

export function zurichToday(now: Date = new Date()): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Zurich", year: "numeric", month: "2-digit", day: "2-digit" })
    .format(now);
}

export async function getClientOrderPage(): Promise<ClientOrderPage> {
  const { supabase } = await requireUser();
  const accounts = await supabase.rpc("my_client_accounts");
  if (accounts.error) {
    logEvent("error", "orders.accounts_failed", errorFields(accounts.error));
    throw new Error("Konto konnte nicht geladen werden.");
  }
  const list = (accounts.data ?? []) as ClientAccount[];
  if (list.length === 0) return { accounts: [], postcodes: [], activities: [], orders: [], today: zurichToday() };
  const [postcodes, activities, orders] = await Promise.all([
    supabase.from("postcodes").select("postcode, place_name, region_name").order("postcode"),
    supabase.from("qual_activities").select("code, label_de").order("sort"),
    supabase.rpc("client_orders"),
  ]);
  const failed = postcodes.error ?? activities.error ?? orders.error;
  if (failed) {
    logEvent("error", "orders.load_failed", errorFields(failed));
    throw new Error("Aufträge konnten nicht geladen werden.");
  }
  return {
    accounts: list,
    postcodes: (postcodes.data ?? []) as PostcodeOption[],
    activities: (activities.data ?? []) as ActivityOption[],
    orders: (orders.data ?? []) as unknown as ClientOrder[],
    today: zurichToday(),
  };
}
