import { createAnthropicProvider } from "./anthropic-provider";
import { CI_FAKE_MODEL_ID, createCiFakeProvider } from "./ci-fake-provider";
import type { Provider } from "./contract";
import { ALLOWED_MODEL_HOSTS, createModelProvider, ModelConfigError } from "./model-provider";
import { ruleProvider } from "./rule-provider";

/** Live Supabase project: never a target of any AI call (agent hard rule). */
const LIVE_PROJECT_REF = "jwmfxrmougneeceldhsa";
/** Staging project (navora-staging). An external model is called only from staging (founder 2026-11-18). */
const STAGING_PROJECT_REF = "qpmdryxkktbqqkqpsnkj";

export type ModelBlockedReason =
  | "kill_switch"
  | "live_project"
  | "not_staging"
  | "not_simulation_org"
  | "provider_unknown"
  /**
   * #1697 F1 (ADR-227 addendum 2026-11-24 12:17): `AI_MODEL_PROVIDER=ci-fake` outside a GitHub Actions job on the local Supabase
   * stack. Its own reason, so `/api/version` can report `misconfigured` and the staging smoke turns red instead of silent.
   */
  | "ci_fake_outside_ci"
  | "base_url_invalid"
  | "https_required"
  | "credentials_in_url"
  | "host_not_allowed"
  | "api_key_missing"
  | "model_missing"
  /** AUT-138, AUT-153: the AIG1 ledger for model proposals is not built yet (ADR-207 (3)). Checked here, in the single resolver. */
  | "ledger_missing";

export type ResolvedProvider = { provider: Provider | null; modelBlocked?: ModelBlockedReason };

type Env = Record<string, string | undefined>;

const STAGING_HOST = `${STAGING_PROJECT_REF}.supabase.co`;

/** AUT-150: the stop switch lets the model run only when it is unset, empty or exactly «off». Any other value stops. */
function killSwitchOn(value: string | undefined): boolean {
  return value !== undefined && value !== "" && value !== "off";
}

/** AUT-150: staging only on the exact https host of navora-staging; a substring of the URL is not enough. */
function isStagingUrl(url: string): boolean {
  try {
    const u = new URL(url);
    return u.protocol === "https:" && u.hostname === STAGING_HOST && u.port === "" && u.username === "" && u.password === "";
  } catch {
    return false;
  }
}

/** Port of the local Supabase API in CI (`supabase start`, config.toml `[api] port`). */
const LOCAL_STACK_PORT = "54321";

/**
 * #1697 F2: the CI fake is allowed only against the local stack: http, hostname exactly 127.0.0.1 or localhost, the
 * stack port, no credentials. No substring test; no other loopback form ([::1], 127.0.0.2, …) is accepted.
 */
function isLocalStackUrl(url: string): boolean {
  try {
    const u = new URL(url);
    return (
      u.protocol === "http:" &&
      (u.hostname === "127.0.0.1" || u.hostname === "localhost") &&
      u.port === LOCAL_STACK_PORT &&
      u.username === "" &&
      u.password === ""
    );
  } catch {
    return false;
  }
}

/** ADR-227 addendum point 1: every condition must hold; `RENDER` set in any form (even empty) blocks. */
function ciFakeAllowed(env: Env, supabaseUrl: string): boolean {
  return env.GITHUB_ACTIONS === "true" && env.RENDER === undefined && isLocalStackUrl(supabaseUrl);
}

/**
 * Picks the report-draft provider (AUT-136 guards, ADR-206 (4)).
 * AI_REPORT_DRAFT_MODE: "off" (no draft), "rule" (default), "model".
 * AI_MODEL_PROVIDER (with "model"): "anthropic" (Claude, founder decision 2026-11-18) or "openai-compatible"
 * (default; Swiss-hosted model, host allowlist empty until a reviewed change).
 * The model is used only if every guard holds; otherwise the rule provider is used, with its own honest label,
 * and the reason is returned so the screen and the log can say why.
 * `ledgerReady` is required (AUT-153): every caller states whether the AIG1 ledger entry for model proposals
 * exists; while it does not, no caller can get a model provider from here.
 */
export function resolveReportDraftProvider(
  env: Env,
  ctx: { simulationOrg: boolean; ledgerReady: boolean; allowedHosts?: readonly string[]; fetch?: typeof fetch },
): ResolvedProvider {
  const mode = env.AI_REPORT_DRAFT_MODE ?? "rule";
  if (mode === "off") return { provider: null };
  if (mode !== "model") return { provider: ruleProvider };

  const blocked = (modelBlocked: ModelBlockedReason): ResolvedProvider => ({ provider: ruleProvider, modelBlocked });
  if (killSwitchOn(env.AI_KILL_SWITCH)) return blocked("kill_switch");
  const supabaseUrl = env.NEXT_PUBLIC_SUPABASE_URL ?? "";
  // Any mention of the live project blocks first (most protective); staging needs the exact host.
  if (supabaseUrl.includes(LIVE_PROJECT_REF)) return blocked("live_project");
  const kind = env.AI_MODEL_PROVIDER ?? "openai-compatible";
  // ADR-227 addendum (CI fake): order kill switch → live project → ci-fake conditions; `not_staging` stays unchanged for
  // every real provider. The fake makes no network call.
  if (kind === "ci-fake") {
    if (!ciFakeAllowed(env, supabaseUrl)) return blocked("ci_fake_outside_ci");
    if (!ctx.simulationOrg) return blocked("not_simulation_org");
    if (!ctx.ledgerReady) return blocked("ledger_missing");
    return { provider: createCiFakeProvider({ callsFile: env.NAVORA_CI_FAKE_CALLS || undefined }) };
  }
  if (!isStagingUrl(supabaseUrl)) return blocked("not_staging");
  if (!ctx.simulationOrg) return blocked("not_simulation_org");

  if (kind !== "anthropic" && kind !== "openai-compatible") return blocked("provider_unknown");

  try {
    const provider =
      kind === "anthropic"
        ? createAnthropicProvider({
            apiKey: env.AI_MODEL_API_KEY ?? "",
            model: env.AI_MODEL_NAME ?? "",
            fetch: ctx.fetch ?? fetch,
          })
        : createModelProvider({
            baseUrl: env.AI_MODEL_BASE_URL ?? "",
            apiKey: env.AI_MODEL_API_KEY ?? "",
            model: env.AI_MODEL_NAME ?? "",
            allowedHosts: ctx.allowedHosts ?? ALLOWED_MODEL_HOSTS,
            fetch: ctx.fetch ?? fetch,
          });
    // AUT-153: last guard, after every configuration reason, so an earlier reason stays visible.
    if (!ctx.ledgerReady) return blocked("ledger_missing");
    return { provider };
  } catch (e) {
    if (e instanceof ModelConfigError) return blocked(e.message as ModelBlockedReason);
    throw e;
  }
}

/**
 * `ci-fake`: the CI test substitute on the model path (never on a deployed server). `misconfigured`: the fake was asked
 * for outside CI; the staging smoke treats both words as red (#1697 F1).
 */
export type ReportDraftMode = "off" | "rule" | "model" | "ci-fake" | "misconfigured";

/**
 * AI1 / ADR-227 point 7: which report draft this running server is configured to give, for the public version endpoint,
 * so a staging smoke can check that the label on screen is honest for the configured state. Only the environment
 * guards are applied (mode, kill switch, staging host, provider, key present); the database answers per request
 * (gate, switch, caps, price) and are not part of it. Returns a word only: never a key, a model name or a host.
 */
export function configuredReportDraftMode(env: Env): ReportDraftMode {
  const never: typeof fetch = () => Promise.reject(new Error("not called"));
  const r = resolveReportDraftProvider(env, { simulationOrg: true, ledgerReady: true, fetch: never });
  if (r.modelBlocked === "ci_fake_outside_ci") return "misconfigured";
  if (r.provider === null) return "off";
  return r.provider.kind === "model" && r.provider.modelId === CI_FAKE_MODEL_ID ? "ci-fake" : r.provider.kind;
}
