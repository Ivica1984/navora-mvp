import "server-only";

import { cache } from "react";
import { errorFields, logEvent } from "@/lib/log";
import { NO_ACCESS, type NavAccess } from "./nav";
import { requireUser } from "./session";

/**
 * UX1-3 (ADR-103): the caller's own roles and team membership, read as herself (RLS: own memberships; a coordinator
 * may read other people's team memberships, so the read is filtered to her own user id). Used only to choose menu
 * items; every page and command keeps its own server-side check. Fails closed: on an error the menu shows no item.
 */
export const getNavAccess = cache(async function getNavAccess(): Promise<NavAccess> {
  const { supabase, user } = await requireUser();
  const [orgs, teams, clients] = await Promise.all([
    supabase.from("organization_memberships").select("role").eq("user_id", user.id),
    supabase.from("team_memberships").select("team_id").eq("user_id", user.id).limit(1),
    // BK-a (UXR-198): own client accounts only (definer function over the caller's own client_account_members rows).
    supabase.rpc("my_client_accounts"),
  ]);
  if (orgs.error || teams.error) {
    logEvent("warn", "auth.nav_access_failed", errorFields(orgs.error ?? teams.error));
    return NO_ACCESS;
  }
  const roles = (orgs.data ?? []).map((row) => row.role);
  const inTeam = (teams.data ?? []).length > 0;
  if (clients.error) {
    // Fail closed for /order only: the other items keep their own reads.
    logEvent("warn", "auth.nav_client_accounts_failed", errorFields(clients.error));
    return { roles, inTeam, clientAccount: false };
  }
  return { roles, inTeam, clientAccount: (clients.data ?? []).length > 0 };
});
