import type { DraftInput, Provider, ProviderOutput } from "./contract";
import { ModelConfigError, REPORT_DRAFT_SYSTEM_PROMPT, parseDraftJson } from "./model-provider";

/**
 * Claude through the Anthropic API (founder decision 2026-11-18 ca. 23:58, live session with `eng`):
 * synthetic data, staging only (guards in config.ts). An exception to FE-085 (A) for Phase A synthetic data;
 * for real persons D-35 rule A stays in force. The host is fixed here, not taken from the environment.
 */
export const ANTHROPIC_HOST = "api.anthropic.com";
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
    label: `KI-Entwurf · Claude ${opts.model} · synthetische Daten · jede Zeile prüfen`,
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
