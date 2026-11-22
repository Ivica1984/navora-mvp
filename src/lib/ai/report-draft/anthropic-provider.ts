import { ModelCallError, type DraftInput, type ModelUsage, type Provider, type ProviderOutput } from "./contract";
import { ModelConfigError, REPORT_DRAFT_SYSTEM_PROMPT, parseDraftJson } from "./model-provider";

/**
 * Claude through the Anthropic API (founder decision 2026-11-18 ca. 23:58, live session with `eng`):
 * synthetic data, staging only (guards in config.ts). An exception to FE-085 (A) for Phase A synthetic data;
 * for real persons D-35 rule A stays in force. The host is fixed here, not taken from the environment.
 */
export const ANTHROPIC_HOST = "api.anthropic.com";
/** Contract BK-e2 point 2 (`aia` gate point 6): exactly this text. */
export const CLAUDE_ORIGIN_LABEL = "KI-Entwurf (Claude), synthetische Daten";
/**
 * `lca` 2026-11-19 03:43 (c) (2), contract point 2: the processing region is set explicitly, so the region registered
 * for `report_draft_model` (0151: `us`) is what the call asks for. Parameter name and value as `lca` read them in the
 * Anthropic data-residency docs; if the API refuses it the call fails and the carer gets no model draft (fail closed).
 */
export const CLAUDE_INFERENCE_GEO = "us";
const ENDPOINT = `https://${ANTHROPIC_HOST}/v1/messages`;
/**
 * AI1 / ADR-227 point 6: the answer cap. Equal to `max_output_tokens` of the 0166 limits row, so the reserve covers the
 * longest possible answer; an answer cut at the cap (`stop_reason = max_tokens`) is invalid, never parsed.
 */
export const CLAUDE_MAX_OUTPUT_TOKENS = 1024;

type MessagesBody = {
  content?: Array<{ type?: string; text?: unknown }>;
  stop_reason?: unknown;
  usage?: { input_tokens?: unknown; output_tokens?: unknown };
};

function usageOf(body: MessagesBody | null): ModelUsage | undefined {
  const i = body?.usage?.input_tokens;
  const o = body?.usage?.output_tokens;
  return Number.isInteger(i) && Number.isInteger(o) && (i as number) >= 0 && (o as number) >= 0
    ? { inputTokens: i as number, outputTokens: o as number }
    : undefined;
}

export type AnthropicProviderOptions = {
  apiKey: string;
  model: string;
  fetch: typeof fetch;
  timeoutMs?: number;
};

export function createAnthropicProvider(opts: AnthropicProviderOptions): Provider {
  if (!opts.apiKey) throw new ModelConfigError("api_key_missing");
  if (!opts.model) throw new ModelConfigError("model_missing");

  return {
    kind: "model",
    label: CLAUDE_ORIGIN_LABEL,
    modelId: opts.model,
    async propose(input: DraftInput): Promise<ProviderOutput> {
      let res: Response;
      try {
        res = await opts.fetch(ENDPOINT, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-api-key": opts.apiKey,
            "anthropic-version": "2023-06-01",
          },
          body: JSON.stringify({
            model: opts.model,
            max_tokens: CLAUDE_MAX_OUTPUT_TOKENS,
            temperature: 0,
            inference_geo: CLAUDE_INFERENCE_GEO,
            system: REPORT_DRAFT_SYSTEM_PROMPT,
            messages: [{ role: "user", content: JSON.stringify({ segments: input.segments, facts: input.facts }) }],
          }),
          signal: AbortSignal.timeout(opts.timeoutMs ?? 30000),
        });
      } catch (e) {
        throw new ModelCallError(e instanceof Error && e.name === "TimeoutError" ? "timeout" : "provider_error");
      }
      if (!res.ok) throw new ModelCallError("provider_error");
      let body: MessagesBody | null;
      try {
        body = (await res.json()) as MessagesBody | null;
      } catch {
        throw new ModelCallError("invalid");
      }
      const usage = usageOf(body);
      // ADR-227 point 6: a cut answer is never parsed, even if its prefix happens to be valid JSON.
      if (body?.stop_reason === "max_tokens") throw new ModelCallError("max_tokens", usage);
      const text = body?.content?.find((c) => c?.type === "text")?.text;
      try {
        return { ...parseDraftJson(text), usage };
      } catch {
        throw new ModelCallError("invalid", usage);
      }
    },
  };
}
