"use server";

// BK-e2a part 2 (ADR-207): a report-draft proposal for the carer's own typed notes on her open report.
// Read-only: it writes nothing. Lines reach the report only through the carer's own decisions and the existing
// F6 commands (update or sign), which the database checks again. Synthetic data only in Phase A.

import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import { randomUUID } from "node:crypto";
import { resolveReportDraftProvider } from "@/lib/ai/report-draft/config";
import { buildReportDraft } from "@/lib/ai/report-draft/draft";
import type { Provider } from "@/lib/ai/report-draft/contract";
import { ruleProvider } from "@/lib/ai/report-draft/rule-provider";
import { reportDraftPromptDigest } from "@/lib/ai/report-draft/prompt-version";
import { MAX_MODEL_INPUT_CHARS } from "@/lib/ai/report-draft/segment";
import { errorFields, logEvent } from "@/lib/log";
import { assistAllowed, assistFromDraft, factsForProvider, type ReportAssist } from "./report-assist";
import { attachSuggestions, ledgerGate, ledgerLines, ledgerOutcome, reservation, type LedgerGate } from "./report-ledger";

// AUT-138, AUT-153 (ADR-216): there is no constant any more. Whether the model may run is the database gate's answer
// (0151 `report_draft_model_gate`: performer, open draft, simulation organisation, threshold row, stop rule), read on
// every request; any doubt keeps the model closed.

const schema = z.object({
  visitId: z.uuid(),
  day: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  text: z.string().max(8000),
  /** AI1 (ADR-227 point 2): one key per «Entwurf vorschlagen» request; a repeat of it (double tap) never calls twice. */
  idempotencyKey: z.uuid(),
});

export type ProposeResult =
  | { ok: true; assist: ReportAssist; modelBlocked?: string; notice?: string }
  | { ok: false; error: string };

const NOT_ALLOWED = "Einen Entwurf kann nur die Pflegekraft dieses Einsatzes für ihren offenen Bericht anfordern.";
const FAILED = "Der Entwurf konnte nicht erstellt werden. Du kannst den Bericht wie bisher selbst schreiben.";
// AI1 wording, for `uxa` in the gate window (ADR-227 decisions): honest, short, no technical reason.
const NOTICE_TOO_LONG_FOR_MODEL = "Deine Notizen sind zu lang für den KI-Entwurf (höchstens 4000 Zeichen). Hier ist der regelbasierte Entwurf.";
const NOTICE_ATTEMPT_LIMIT =
  "Für diese Fassung wurde schon zweimal ein KI-Entwurf erstellt. Du kannst selbst schreiben. Hier ist der regelbasierte Entwurf.";
const NOTICE_MODEL_UNAVAILABLE = "Der KI-Entwurf ist gerade nicht verfügbar. Hier ist der regelbasierte Entwurf.";
const ALREADY_RUNNING = "Der Entwurf wird schon erstellt. Bitte einen Moment warten.";

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

  // The gate is read only when the model mode is configured; otherwise the rule substitute needs no ledger.
  const gate: LedgerGate =
    process.env.AI_REPORT_DRAFT_MODE === "model"
      ? ledgerGate(await supabase.rpc("report_draft_model_gate", { p_report_id: report!.report_id }))
      : { ready: false, reason: "ledger_missing" };
  const resolved = resolveReportDraftProvider(process.env, { simulationOrg, ledgerReady: gate.ready });
  if (!resolved.provider) return { ok: false, error: "Berichtsentwürfe sind ausgeschaltet." };
  // Name the database's own reason (no threshold row, stop rule, …) instead of the generic «ledger missing».
  let modelBlocked: string | undefined =
    resolved.modelBlocked === "ledger_missing" && !gate.ready ? gate.reason : resolved.modelBlocked;

  // AI1 (ADR-227 points 1, 2, 6): no provider call without a reservation in the database. Notes over the model limit
  // are refused for the model before anything is reserved; any refusal or doubt falls back to the rule substitute.
  let provider: Provider = resolved.provider;
  let notice: string | undefined;
  let reservationId: string | null = null;
  if (provider.kind === "model") {
    if (parsed.data.text.length > MAX_MODEL_INPUT_CHARS) {
      provider = ruleProvider;
      modelBlocked = "too_long_for_model";
      notice = NOTICE_TOO_LONG_FOR_MODEL;
    } else {
      // AUT-167 (0167): the digest of the prompt this server sends; the database refuses it unless it is the current
      // agent version's, so a prompt change without a registered version never reaches the model.
      const rsv = reservation(
        await supabase.rpc("reserve_report_draft_call", {
          p_report_id: report!.report_id,
          p_idempotency_key: parsed.data.idempotencyKey,
          p_prompt_digest: reportDraftPromptDigest(),
        }),
      );
      if (rsv.kind === "duplicate") {
        logEvent("info", "report_draft.proposed", { op: "report_draft.model", code: "duplicate", count: 0 });
        return { ok: false, error: ALREADY_RUNNING };
      }
      if (rsv.kind === "refused") {
        provider = ruleProvider;
        modelBlocked = rsv.reason;
        notice = rsv.reason === "attempt_limit" ? NOTICE_ATTEMPT_LIMIT : NOTICE_MODEL_UNAVAILABLE;
      } else reservationId = rsv.reservationId;
    }
  }

  const started = Date.now();
  let draft = await buildReportDraft({ text: parsed.data.text, facts: factsForProvider(report!.snapshot, provider.kind) }, provider);
  if (reservationId) {
    // Outcome, tokens and latency of the reserved call; never the text. If settling fails the call stays charged at its
    // reserve (fail closed for money) and the draft is still shown.
    const settled = await supabase.rpc("settle_report_draft_call", {
      p_reservation_id: reservationId,
      p_outcome: draft.ok ? "ok" : (draft.outcome ?? "provider_error"),
      p_input_tokens: (draft.usage?.inputTokens ?? null) as number,
      p_output_tokens: (draft.usage?.outputTokens ?? null) as number,
      p_latency_ms: Math.min(Math.max(Date.now() - started, 0), 600000),
    });
    const result = (settled.data as { result?: unknown } | null)?.result;
    if (settled.error || (result !== "ok" && result !== "duplicate")) {
      logEvent("warn", "report_draft.settle_failed", { op: "report_draft.model", code: settled.error ? "error" : String(result ?? "none") });
    } else if ((settled.data as { cost_basis?: unknown } | null)?.cost_basis === "bounded") {
      // #1697 R4 (0169): more input tokens than 2 x the reserve input were reported; the bound was charged. Visible for the
      // ADR-227 evaluation run, which measures the real worst case.
      logEvent("warn", "report_draft.settle_bounded", { op: "report_draft.model", code: "bounded", count: draft.usage?.inputTokens ?? 0 });
    }
  }
  let assist = draft.ok ? assistFromDraft(draft) : null;

  // No model line on screen without its ledger row (ADR-216): record first; on any failure fall back to the rule
  // substitute with its own label. Only line index, sources, a keyed digest, length and model id are stored (ADR-215).
  if (draft.ok && draft.origin === "model" && assist && assist.lines.length > 0) {
    const recorded = attachSuggestions(
      assist,
      await supabase.rpc("record_report_draft_proposal", {
        p_report_id: report!.report_id,
        p_model: draft.modelId ?? "",
        p_lines: ledgerLines(assist),
        p_idempotency_key: randomUUID(),
      }),
    );
    if (recorded) assist = recorded;
    else {
      logEvent("warn", "report_draft.ledger_failed", { op: "report_draft.model", code: "ledger_missing" });
      modelBlocked = "ledger_missing";
      draft = await buildReportDraft({ text: parsed.data.text, facts: factsForProvider(report!.snapshot, "rule") }, ruleProvider);
      assist = draft.ok ? assistFromDraft(draft) : null;
    }
  }
  // Origin, outcome and a count only; never the typed text (log allowlist, no clinical free text in logs).
  logEvent("info", "report_draft.proposed", {
    op: `report_draft.${draft.origin}`,
    code: draft.ok ? (modelBlocked ?? "ok") : draft.error,
    count: draft.ok ? draft.unplaced.length : 0,
  });
  if (!draft.ok || !assist) return { ok: false, error: !draft.ok && draft.error === "input_too_long" ? "Bitte höchstens 8000 Zeichen eingeben." : FAILED };
  return { ok: true, assist, modelBlocked, notice };
}

const decideSchema = z.object({
  suggestionId: z.uuid(),
  decision: z.enum(["taken", "dropped"]),
  text: z.string().min(1).max(2000),
  idempotencyKey: z.uuid(),
});

export type DecideResult = { ok: true } | { ok: false; error: string };

/**
 * ADR-216: the carer's decision on one model line, written to the ledger before the screen shows it as decided.
 * One line per call, never in bulk (`aia` gate point 7). The database checks performer and open draft again.
 */
export async function decideReportDraftLine(input: unknown): Promise<DecideResult> {
  const parsed = decideSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: DECIDE_FAILED };
  const outcome = ledgerOutcome(parsed.data.decision);
  if (!outcome) return { ok: false, error: DECIDE_FAILED };
  const { supabase } = await requireUser();
  const res = await supabase.rpc("decide_report_draft_line", {
    p_suggestion_id: parsed.data.suggestionId,
    p_outcome: outcome,
    // A rejected line carries no text (0151); a confirmed one is compared by its keyed digest.
    p_text: (outcome === "confirmed" ? parsed.data.text : null) as string,
    p_idempotency_key: parsed.data.idempotencyKey,
  });
  const result = (res.data as { result?: unknown } | null)?.result;
  logEvent("info", "report_draft.decided", { op: `report_draft.${outcome}`, code: res.error ? "error" : String(result ?? "none") });
  if (res.error || (result !== "ok" && result !== "duplicate")) return { ok: false, error: DECIDE_FAILED };
  return { ok: true };
}

const DECIDE_FAILED = "Die Entscheidung konnte nicht gespeichert werden. Bitte nochmals versuchen.";

const inputSchema = z.object({
  visitId: z.uuid(),
  day: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  record: z.object({
    origin: z.enum(["rule", "model"]),
    segments: z
      .array(z.object({ id: z.string().regex(/^s[1-9]\d{0,3}$/), text: z.string().min(1).max(8000), decision: z.enum(["taken", "dropped", "inserted", "omitted"]) }))
      .min(1)
      .max(400),
    lines: z.array(z.object({ sources: z.array(z.string().regex(/^[sf][1-9]\d{0,3}$/)).min(1).max(50), decision: z.enum(["taken", "dropped"]) })).max(400),
  }),
  idempotencyKey: z.uuid(),
});

const INPUT_FAILED = "Deine Entscheidungen konnten nicht gespeichert werden. Bitte nochmals «übernehmen».";

/**
 * BK-e2b (ADR-219): stores her notes with one decision per sentence on her open report before the draft goes into the
 * summary (migration 0152). If it fails, the draft stays on screen and nothing goes into the summary (fail closed).
 */
export async function recordReportInput(input: unknown): Promise<DecideResult> {
  const parsed = inputSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: INPUT_FAILED };
  const { supabase } = await requireUser();
  const reports = await supabase.rpc("field_reports", { p_date: parsed.data.day });
  const report = (reports.data ?? []).find((r) => r.visit_id === parsed.data.visitId) ?? null;
  if (reports.error || !assistAllowed(report)) return { ok: false, error: NOT_ALLOWED };
  const { record } = parsed.data;
  const res = await supabase.rpc("record_report_input", {
    p_report_id: report!.report_id,
    p_origin: record.origin,
    p_segments: record.segments,
    p_lines: record.lines,
    p_idempotency_key: parsed.data.idempotencyKey,
  });
  const result = (res.data as { result?: unknown } | null)?.result;
  // Counts and outcome only; never the typed text.
  logEvent("info", "report_draft.input_recorded", { op: `report_draft.${record.origin}`, code: res.error ? "error" : String(result ?? "none"), count: record.segments.length });
  if (res.error || (result !== "ok" && result !== "duplicate")) return { ok: false, error: INPUT_FAILED };
  return { ok: true };
}
