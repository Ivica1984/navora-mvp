import "server-only";

import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import type { Database } from "@/lib/supabase/database.types";
import type { FieldReport } from "./report";
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

/**
 * Latest report version per visit of the day (F6). Team-scoped in the database:
 * public.field_reports() (migration 0016, pgTAP 016).
 */
export async function getFieldReports(day: string): Promise<FieldReport[]> {
  const { supabase } = await requireUser();

  const { data, error } = await supabase.rpc("field_reports", { p_date: day });

  if (error) {
    logEvent("error", "field.reports_load_failed", errorFields(error));
    throw new Error("Berichte konnten nicht geladen werden.");
  }

  return data ?? [];
}

export type CountersignItem = Database["public"]["Functions"]["field_countersign_queue"]["Returns"][number];

/** F7: reports of the caller's teams waiting for her countersignature, any date (registered nurses only). */
export async function getCountersignQueue(): Promise<CountersignItem[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("field_countersign_queue");
  if (error) {
    logEvent("error", "field.countersign_queue_failed", errorFields(error));
    throw new Error("Gegenzeichnungen konnten nicht geladen werden.");
  }
  return data ?? [];
}

export type ReturnedItem = Database["public"]["Functions"]["field_returned_reports"]["Returns"][number];

/** F6R-5: the caller's reports returned to her by a registered nurse, any date, until she signs again. */
export async function getReturnedReports(): Promise<ReturnedItem[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("field_returned_reports");
  if (error) {
    logEvent("error", "field.returned_reports_failed", errorFields(error));
    throw new Error("Zurückgegebene Berichte konnten nicht geladen werden.");
  }
  return data ?? [];
}

export type SinceLastRowDb = Database["public"]["Functions"]["field_since_last"]["Returns"][number];

/**
 * HAND1: everything recorded about each visit's client since the caller was last there.
 * Team-scoped and ordered in the database: public.field_since_last() (migration 0033, pgTAP 033).
 */
export async function getSinceLast(day: string): Promise<SinceLastRowDb[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("field_since_last", { p_date: day });
  if (error) {
    logEvent("error", "field.since_last_load_failed", errorFields(error));
    throw new Error("«Seit deinem letzten Einsatz» konnte nicht geladen werden.");
  }
  return data ?? [];
}
