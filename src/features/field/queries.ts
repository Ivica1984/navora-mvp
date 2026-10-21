import "server-only";

import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import type { FieldNote, FieldVisit } from "./types";

/**
 * Visits of the signed-in user's teams on one day (F1).
 * Scope and data minimisation live in the database: public.field_visits()
 * (migration 0006, SECURITY INVOKER, pgTAP 008).
 */
export async function getFieldVisits(day: string): Promise<FieldVisit[]> {
  const { supabase } = await requireUser();

  const { data, error } = await supabase.rpc("field_visits", { p_date: day });

  if (error) {
    logEvent("error", "field.load_failed", errorFields(error));
    throw new Error("Deine Einsätze konnten nicht geladen werden.");
  }

  return data ?? [];
}

/**
 * Observations of the day's visits and handover notes for them (F4).
 * Team-scoped by RLS on visit_observations; public.field_notes() (migration 0009, pgTAP 011).
 */
export async function getFieldNotes(day: string): Promise<FieldNote[]> {
  const { supabase } = await requireUser();

  const { data, error } = await supabase.rpc("field_notes", { p_date: day });

  if (error) {
    logEvent("error", "field.notes_load_failed", errorFields(error));
    throw new Error("Beobachtungen konnten nicht geladen werden.");
  }

  return data ?? [];
}
