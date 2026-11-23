import { createHash } from "node:crypto";
import { CLAUDE_MAX_OUTPUT_TOKENS } from "./anthropic-provider";
import { REPORT_DRAFT_SYSTEM_PROMPT } from "./model-provider";

/**
 * AI1 contract item 2 (AUT-167 via AUT-191, `aia` review 84): the prompt of the report-draft model is pinned to the
 * agent version registered in the database (`ai_agent_definitions.version` of `report_draft_model`, 0151).
 *
 * - The digest covers everything that shapes the model's answer and is fixed in code: the system prompt (which also
 *   states the output schema), temperature, the answer cap and the keys of the user message. The model id is not part
 *   of it (it is an environment value and is written to every ledger line, ADR-215).
 * - Every version and its digest are registered by a reviewed migration in `private.ai_agent_prompt_versions`
 *   (append-only, 0167). The app sends its digest with every reservation; the database refuses the call when it is not
 *   the digest of the current version (`prompt_version_mismatch`, fail closed: rule draft, no provider call).
 * - A new version opens a fresh stop-rule window (AUT-152): the window starts no earlier than the version's
 *   registration, so correction shares of two prompts are never mixed.
 *
 * Changing the prompt: change the text, add `"<n+1>": "<new digest>"` here, and in the same PR a migration that inserts
 * the new row and sets `ai_agent_definitions.version` to `<n+1>`. `tests/unit/ai1-prompt-version.test.ts` is red until
 * all three agree; an existing entry is never edited.
 */
export const REPORT_DRAFT_AGENT_VERSION = "1";

/** Version → SHA-256 (hex) of `reportDraftPromptMaterial()`. Append only; each entry has its migration row. */
export const REPORT_DRAFT_PROMPT_VERSIONS: Readonly<Record<string, string>> = Object.freeze({
  "1": "6385db265f21c2ac0ede72a630bd1ca93034661176bf0166b724fd560d74f3c9",
});

/** Model request properties that are fixed in code, in a fixed key order (canonical JSON). */
export function reportDraftPromptMaterial(): string {
  return JSON.stringify({
    system: REPORT_DRAFT_SYSTEM_PROMPT,
    temperature: 0,
    max_tokens: CLAUDE_MAX_OUTPUT_TOKENS,
    user_keys: ["segments", "facts"],
  });
}

export function reportDraftPromptDigest(): string {
  return createHash("sha256").update(reportDraftPromptMaterial(), "utf8").digest("hex");
}
