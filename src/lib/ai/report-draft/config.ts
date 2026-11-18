import type { Provider } from "./contract";
import { ALLOWED_MODEL_HOSTS, createModelProvider, ModelConfigError } from "./model-provider";
import { ruleProvider } from "./rule-provider";

/** Live Supabase project: never a target of any AI call (agent hard rule). */
const LIVE_PROJECT_REF = "jwmfxrmougneeceldhsa";

export type ModelBlockedReason =
  | "kill_switch"
  | "live_project"
  | "not_simulation_org"
  | "base_url_invalid"
  | "https_required"
  | "credentials_in_url"
  | "host_not_allowed"
  | "api_key_missing"
  | "model_missing";

export type ResolvedProvider = { provider: Provider | null; modelBlocked?: ModelBlockedReason };

type Env = Record<string, string | undefined>;

/**
 * Picks the report-draft provider (AUT-136 guards, ADR-206 (4)).
 * AI_REPORT_DRAFT_MODE: "off" (no draft), "rule" (default), "model".
 * The model is used only if every guard holds; otherwise the rule provider is used, with its own honest label,
 * and the reason is returned so the screen and the log can say why.
 */
export function resolveReportDraftProvider(
  env: Env,
  ctx: { simulationOrg: boolean; allowedHosts?: readonly string[]; fetch?: typeof fetch },
): ResolvedProvider {
  const mode = env.AI_REPORT_DRAFT_MODE ?? "rule";
  if (mode === "off") return { provider: null };
  if (mode !== "model") return { provider: ruleProvider };

  const blocked = (modelBlocked: ModelBlockedReason): ResolvedProvider => ({ provider: ruleProvider, modelBlocked });
  if (env.AI_KILL_SWITCH === "on") return blocked("kill_switch");
  if ((env.NEXT_PUBLIC_SUPABASE_URL ?? "").includes(LIVE_PROJECT_REF)) return blocked("live_project");
  if (!ctx.simulationOrg) return blocked("not_simulation_org");

  try {
    const provider = createModelProvider({
      baseUrl: env.AI_MODEL_BASE_URL ?? "",
      apiKey: env.AI_MODEL_API_KEY ?? "",
      model: env.AI_MODEL_NAME ?? "",
      allowedHosts: ctx.allowedHosts ?? ALLOWED_MODEL_HOSTS,
      fetch: ctx.fetch ?? fetch,
    });
    return { provider };
  } catch (e) {
    if (e instanceof ModelConfigError) return blocked(e.message as ModelBlockedReason);
    throw e;
  }
}
