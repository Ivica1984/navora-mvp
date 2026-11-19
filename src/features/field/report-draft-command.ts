"use server";

// BK-e2a part 2 (ADR-207): a report-draft proposal for the carer's own typed notes on her open report.
// Read-only: it writes nothing. Lines reach the report only through the carer's own decisions and the existing
// F6 commands (update or sign), which the database checks again. Synthetic data only in Phase A.

import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import { resolveReportDraftProvider } from "@/lib/ai/report-draft/config";
import { buildReportDraft } from "@/lib/ai/report-draft/draft";
import { errorFields, logEvent } from "@/lib/log";
import { assistAllowed, assistFromDraft, factsFromSnapshot, withLedgerGuard, type ReportAssist } from "./report-assist";

/** AUT-138: flipped by the reviewed PR that adds the AIG1 ledger entry for model proposals (BK-e2a part 2b). */
const MODEL_LEDGER_READY = false;

const schema = z.object({
  visitId: z.uuid(),
  day: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  text: z.string().max(8000),
});

export type ProposeResult =
  | { ok: true; assist: ReportAssist; modelBlocked?: string }
  | { ok: false; error: string };

const NOT_ALLOWED = "Einen Entwurf kann nur die Pflegekraft dieses Einsatzes für ihren offenen Bericht anfordern.";
const FAILED = "Der Entwurf konnte nicht erstellt werden. Du kannst den Bericht wie bisher selbst schreiben.";

export async function proposeReportDraft(input: unknown): Promise<ProposeResult> {
  const parsed = schema.safeParse(input);
  if (!parsed.success) return { ok: false, error: "Bitte höchstens 8000 Zeichen eingeben." };
  if (parsed.data.text.trim().length === 0) return { ok: false, error: "Bitte zuerst Notizen eingeben." };
  const { supabase } = await requireUser();

  // Team-scoped in the database (field_reports, field_visits); the performer check uses the server's answer.
  const [reports, visits] = await Promise.all([
    supabase.rpc("field_reports", { p_date: parsed.data.day }),
    supabase.rpc("field_visits", { p_date: parsed.data.day }),
  ]);
  if (reports.error || visits.error) {
    logEvent("warn", "report_draft.load_failed", errorFields(reports.error ?? visits.error));
    return { ok: false, error: FAILED };
  }
  const report = (reports.data ?? []).find((r) => r.visit_id === parsed.data.visitId) ?? null;
  const visit = (visits.data ?? []).find((v) => v.visit_id === parsed.data.visitId) ?? null;
  if (!visit || !assistAllowed(report)) return { ok: false, error: NOT_ALLOWED };

  const team = await supabase.from("teams").select("organizations(simulation)").eq("id", visit.team_id).maybeSingle();
  const org = (team.data as { organizations?: { simulation?: boolean } | null } | null)?.organizations;
  const simulationOrg = org?.simulation === true;

  const resolved = withLedgerGuard(resolveReportDraftProvider(process.env, { simulationOrg }), MODEL_LEDGER_READY);
  if (!resolved.provider) return { ok: false, error: "Berichtsentwürfe sind ausgeschaltet." };

  const draft = await buildReportDraft({ text: parsed.data.text, facts: factsFromSnapshot(report!.snapshot) }, resolved.provider);
  // Origin, outcome and a count only; never the typed text (log allowlist, no clinical free text in logs).
  logEvent("info", "report_draft.proposed", {
    op: `report_draft.${draft.origin}`,
    code: draft.ok ? (resolved.modelBlocked ?? "ok") : draft.error,
    count: draft.ok ? draft.unplaced.length : 0,
  });
  if (!draft.ok) return { ok: false, error: draft.error === "input_too_long" ? "Bitte höchstens 8000 Zeichen eingeben." : FAILED };
  return { ok: true, assist: assistFromDraft(draft), modelBlocked: resolved.modelBlocked };
}
