import type { DraftInput, Provider, ProviderOutput } from "./contract";

/**
 * Hosts a model provider may call. Empty on purpose (ADR-206 (3)): the founder chooses a provider with Swiss
 * hosting and no data retention (founder 2026-11-18 ca. 23:30, FE-085 (A), Handbook V2.2 T-6); adding its host
 * is a reviewed code change, never an environment variable.
 */
export const ALLOWED_MODEL_HOSTS: readonly string[] = Object.freeze([]);

export class ModelConfigError extends Error {}

export type ModelProviderOptions = {
  baseUrl: string;
  apiKey: string;
  model: string;
  fetch: typeof fetch;
  allowedHosts?: readonly string[];
  timeoutMs?: number;
};

export const REPORT_DRAFT_SYSTEM_PROMPT = [
  "Du strukturierst einen Pflege-Einsatzbericht aus Textsegmenten und erfassten Fakten.",
  "Regeln:",
  "1. Verwende nur Inhalte aus den Segmenten und Fakten. Erfinde nichts, ergänze keine Werte, Befunde oder Massnahmen.",
  "2. Jede Zeile nennt in 'sources' die ids der Segmente oder Fakten, aus denen sie stammt.",
  "3. Ein Segment, das du nicht sicher einordnen kannst, kommt in 'unplaced'.",
  'Antworte nur mit JSON: {"lines":[{"text":"…","sources":["s1"]}],"unplaced":["s2"]}',
].join("\n");

/** OpenAI-compatible chat-completions client for a Swiss-hosted model. Sends only segments and facts. */
export function createModelProvider(opts: ModelProviderOptions): Provider {
  const allowed = opts.allowedHosts ?? ALLOWED_MODEL_HOSTS;
  let url: URL;
  try {
    url = new URL(opts.baseUrl);
  } catch {
    throw new ModelConfigError("base_url_invalid");
  }
  if (url.protocol !== "https:") throw new ModelConfigError("https_required");
  if (url.username || url.password) throw new ModelConfigError("credentials_in_url");
  if (!allowed.includes(url.hostname)) throw new ModelConfigError("host_not_allowed");
  if (!opts.apiKey) throw new ModelConfigError("api_key_missing");
  if (!opts.model) throw new ModelConfigError("model_missing");

  const endpoint = `${opts.baseUrl.replace(/\/+$/, "")}/chat/completions`;

  return {
    kind: "model",
    label: `KI-Entwurf · Modell ${opts.model} · synthetische Daten · jede Zeile prüfen`,
    async propose(input: DraftInput): Promise<ProviderOutput> {
      const res = await opts.fetch(endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${opts.apiKey}` },
        body: JSON.stringify({
          model: opts.model,
          temperature: 0,
          response_format: { type: "json_object" },
          messages: [
            { role: "system", content: REPORT_DRAFT_SYSTEM_PROMPT },
            { role: "user", content: JSON.stringify({ segments: input.segments, facts: input.facts }) },
          ],
        }),
        signal: AbortSignal.timeout(opts.timeoutMs ?? 20000),
      });
      if (!res.ok) throw new Error(`model_http_${res.status}`);
      const body = (await res.json()) as { choices?: Array<{ message?: { content?: unknown } }> };
      return parseDraftJson(body?.choices?.[0]?.message?.content);
    },
  };
}

/** Parses the model's JSON answer; a ```json fence around it is tolerated. Anything else fails, nothing is guessed. */
export function parseDraftJson(content: unknown): ProviderOutput {
  if (typeof content !== "string") throw new Error("model_output_invalid");
  const fenced = content.trim().match(/^```(?:json)?\s*([\s\S]*?)\s*```$/);
  let parsed: unknown;
  try {
    parsed = JSON.parse(fenced ? fenced[1] : content);
  } catch {
    throw new Error("model_output_invalid");
  }
  const p = parsed as Partial<ProviderOutput>;
  if (!p || !Array.isArray(p.lines)) throw new Error("model_output_invalid");
  return { lines: p.lines, unplaced: Array.isArray(p.unplaced) ? p.unplaced : [] };
}
