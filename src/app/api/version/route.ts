import { appVersion, buildVersionEnv } from "@/lib/version";

// Q1 (a), ADR-220: public, no session, no data: the deployed commit and the migration level the build expects.
// The CI check `staging-version` compares it with the migrations applied on navora-staging.
export function GET() {
  return Response.json(appVersion(buildVersionEnv()), { headers: { "Cache-Control": "no-store" } });
}
