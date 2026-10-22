// Pure Markdown-table reader for the agent collaboration layer (docs/agents).
// Same table rules as scripts/agents-check.mjs: the first table under "## <heading>".

export const NONE = new Set(["", "–", "-", "—"]);
export const bare = (v) => (v ?? "").replace(/[`*]/g, "").trim();
export const list = (v) => (NONE.has((v ?? "").trim()) ? [] : bare(v).split(",").map((s) => s.trim()).filter(Boolean));

/** Heading match: exact, or a prefix followed by a space or "(" (e.g. "## Next up (approved briefs …)"). */
export function parseTable(text, heading) {
  const lines = (text ?? "").split("\n");
  const h = `## ${heading}`;
  const start = lines.findIndex((l) => {
    const t = l.trim();
    return t === h || t.startsWith(`${h} `) || t.startsWith(`${h}(`);
  });
  if (start < 0) return [];
  const rows = [];
  let header = null;
  for (let i = start + 1; i < lines.length; i++) {
    const line = lines[i].trim();
    if (line.startsWith("## ")) break;
    if (!line.startsWith("|")) {
      if (header) break;
      continue;
    }
    const cells = line.replace(/^\|/, "").replace(/\|$/, "").split(/(?<!\\)\|/).map((c) => c.trim());
    if (!header) {
      header = cells;
      continue;
    }
    if (cells.every((c) => /^:?-+:?$/.test(c))) continue;
    if (cells.length !== header.length) continue;
    rows.push(Object.fromEntries(header.map((h, j) => [h, cells[j]])));
  }
  return rows;
}

/** The three official files → typed rows. */
export function readLayerTexts({ next, status, decisions }) {
  return {
    queue: [
      ...parseTable(next, "Priority queue").map((r) => ({
        rank: Number(bare(r.Rank)), id: bare(r.ID), capability: r.Capability, poStatus: bare(r["PO status"]), brief: r.Brief,
      })),
      // "Next up": approved briefs the PO has lined up after the queue (ranked after it, in their order).
      ...parseTable(next, "Next up").map((r, i) => ({
        rank: 1000 + (Number(bare(r.Order)) || i + 1), id: bare(r.ID), capability: r.Capability, poStatus: "approved", brief: r.Brief,
      })),
    ],
    status: parseTable(status, "Items").map((r) => ({
      id: bare(r.ID), origin: bare(r.Origin), state: bare(r.State), summary: r.Summary, next: r.Next,
      prs: list(r.PRs), blockedBy: list(r["Blocked by"]),
    })),
    open: parseTable(decisions, "Open").map((r) => ({
      id: bare(r.ID), owner: bare(r.Owner), kind: bare(r.Kind), question: r.Question, recommendation: r.Recommendation,
      blocks: list(r.Blocks),
    })),
    decided: parseTable(decisions, "Decided").map((r) => ({ id: bare(r.ID), owner: bare(r.Owner), answer: r.Answer, date: r.Date })),
  };
}
