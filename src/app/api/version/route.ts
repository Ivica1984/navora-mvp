import { configuredReportDraftMode } from "@/lib/ai/report-draft/config";
import { runningVersion } from "@/lib/version";

// Q1 (a), ADR-220: public, no session, no data: the deployed commit and the migration level the build expects.
// The CI check `staging-version` compares it with the migrations applied on navora-staging.
// AI1 / ADR-227 point 7: plus one word, the configured report draft («off», «rule», «model»), read from the run-time
// environment; no key, no model name, no host.
export function GET() {
  return Response.json(
    { ...runningVersion(), report_draft: configuredReportDraftMode(process.env) },
    { headers: { "Cache-Control": "no-store" } },
  );
}
