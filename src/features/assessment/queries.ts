import "server-only";

import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import { toCaseAssessments, type CaseAssessments, type Instrument } from "./rules";

/**
 * ASM1 (migration 0100, ADR-123): per case of the caller's teams the assessment records, the care plan's basis, the
 * "Neuere Bedarfsabklärung" date and the dated facts since the current assessment (public.team_case_assessments,
 * pgTAP 100). Members of the case's assigned team only.
 */
export async function getTeamCaseAssessments(): Promise<Record<string, CaseAssessments>> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("team_case_assessments");
  if (error) {
    logEvent("error", "assessment.load_failed", errorFields(error));
    throw new Error("Bedarfsabklärungen konnten nicht geladen werden.");
  }
  return toCaseAssessments(data);
}

/** ASM1-6: the organisation's instrument entries (names only, no personal data; RLS: members of the organisation). */
export async function getAssessmentInstruments(): Promise<Instrument[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase
    .from("assessment_instruments")
    .select("id, name, version, valid_from, valid_to, third_party_mark")
    .order("name")
    .order("valid_from");
  if (error) {
    logEvent("error", "assessment.instruments_load_failed", errorFields(error));
    throw new Error("Instrumentenliste konnte nicht geladen werden.");
  }
  return (data ?? []) as Instrument[];
}
