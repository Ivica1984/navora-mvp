import type { DraftInput, Provider, ProviderOutput } from "./contract";
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
      const res = await opts.fetch(ENDPOINT, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": opts.apiKey,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: opts.model,
          max_tokens: 4096,
          temperature: 0,
          inference_geo: CLAUDE_INFERENCE_GEO,
          system: REPORT_DRAFT_SYSTEM_PROMPT,
          messages: [{ role: "user", content: JSON.stringify({ segments: input.segments, facts: input.facts }) }],
        }),
        signal: AbortSignal.timeout(opts.timeoutMs ?? 30000),
      });
      if (!res.ok) throw new Error(`model_http_${res.status}`);
      const body = (await res.json()) as { content?: Array<{ type?: string; text?: unknown }> };
      const text = body?.content?.find((c) => c?.type === "text")?.text;
      return parseDraftJson(text);
    },
  };
}
