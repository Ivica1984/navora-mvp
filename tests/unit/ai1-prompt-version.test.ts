import { createHash } from "node:crypto";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it, vi } from "vitest";
import { createAnthropicProvider } from "@/lib/ai/report-draft/anthropic-provider";
import {
  REPORT_DRAFT_AGENT_VERSION,
  REPORT_DRAFT_PROMPT_VERSIONS,
  reportDraftPromptDigest,
  reportDraftPromptMaterial,
} from "@/lib/ai/report-draft/prompt-version";

/**
 * AI1 contract item 2 (AUT-167 via AUT-191): a prompt change without a new agent version is red here.
 * The three places that must agree: the prompt material in code, the version → digest list in code, and the
 * registrations and the current version that the migrations leave in the database (0151 insert, 0167 registry).
 */
const MIGRATIONS = "supabase/migrations";
const sql = readdirSync(MIGRATIONS)
  .filter((f) => f.endsWith(".sql"))
  .sort()
  .map((f) => readFileSync(join(MIGRATIONS, f), "utf8"))
  .join("\n");

/** Every ('report_draft_model', '<version>', '<digest>') row inserted into the prompt registry by a migration. */
function registeredVersions(): Array<[string, string]> {
  const out: Array<[string, string]> = [];
  const block = /insert into private\.ai_agent_prompt_versions[^;]*;/g;
  for (const m of sql.matchAll(block)) {
    for (const r of m[0].matchAll(/\('report_draft_model', '([^']+)', '([0-9a-f]{64})'\)/g)) out.push([r[1], r[2]]);
  }
  return out;
}

/** The agent version the migrations leave: the 0151 insert, then any later `update … set version = '<n>'`. */
function migratedAgentVersion(): string {
  let v: string | null = null;
  const insert = /values \('report_draft_model', 'KI-Berichtsentwurf \(Claude\)', 'G', 'ai', '([^']+)'/.exec(sql);
  if (insert) v = insert[1];
  for (const m of sql.matchAll(/update public\.ai_agent_definitions\s+set version = '([^']+)'\s+where key = 'report_draft_model'/g)) v = m[1];
  if (!v) throw new Error("no agent version for report_draft_model in the migrations");
  return v;
}

describe("AI1 / AUT-167: the report-draft prompt is pinned to the registered agent version", () => {
  it("the digest of today's prompt material is the one listed for the current version", () => {
    expect(reportDraftPromptDigest()).toBe(createHash("sha256").update(reportDraftPromptMaterial(), "utf8").digest("hex"));
    expect(
      REPORT_DRAFT_PROMPT_VERSIONS[REPORT_DRAFT_AGENT_VERSION],
      "prompt changed: add a new version with its digest and a migration that registers it and sets the version",
    ).toBe(reportDraftPromptDigest());
  });

  it("every listed version is registered by a migration with the same digest, once, and nothing else is registered", () => {
    const reg = registeredVersions();
    expect(reg.map(([v]) => v).sort()).toEqual(Object.keys(REPORT_DRAFT_PROMPT_VERSIONS).sort());
    expect(new Set(reg.map(([v]) => v)).size).toBe(reg.length);
    expect(new Set(reg.map(([, d]) => d)).size).toBe(reg.length);
    for (const [v, d] of reg) expect(d, `version ${v}`).toBe(REPORT_DRAFT_PROMPT_VERSIONS[v]);
  });

  it("the agent version the migrations leave in the database is the app's version", () => {
    expect(migratedAgentVersion()).toBe(REPORT_DRAFT_AGENT_VERSION);
  });

  it("the digested material is what the provider actually sends (system prompt, temperature, answer cap, user keys)", async () => {
    const fetch = vi.fn(async () =>
      new Response(JSON.stringify({ content: [{ type: "text", text: '{"lines":[],"unplaced":[]}' }], stop_reason: "end_turn" })),
    );
    await createAnthropicProvider({ apiKey: "k", model: "c", fetch }).propose({ segments: [{ id: "s1", text: "A." }], facts: [] });
    const body = JSON.parse(String((fetch.mock.calls[0] as unknown as [string, RequestInit])[1].body));
    const material = JSON.parse(reportDraftPromptMaterial());
    expect(body.system).toBe(material.system);
    expect(body.temperature).toBe(material.temperature);
    expect(body.max_tokens).toBe(material.max_tokens);
    expect(Object.keys(JSON.parse(body.messages[0].content))).toEqual(material.user_keys);
  });

  it("a changed prompt gives another digest (the pin is sensitive to one character)", () => {
    const changed = JSON.stringify({ ...JSON.parse(reportDraftPromptMaterial()), system: JSON.parse(reportDraftPromptMaterial()).system + " " });
    expect(createHash("sha256").update(changed, "utf8").digest("hex")).not.toBe(reportDraftPromptDigest());
  });
});
