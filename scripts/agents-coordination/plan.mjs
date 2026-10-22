// Coordination planner — PURE (no I/O). Given the collaboration layer and, per item, when the PO
// last changed its PO status and when Engineering last changed its state, it returns the set of
// hand-off issues that SHOULD be open. scripts/agents-coordination/run.mjs syncs GitHub to it.
//
// Hand-offs (see docs/agents/COORDINATION.md):
//   eng:<ID>       Engineering must implement (PO approved) or address requested changes.
//   po:<ID>        PO must review a delivered item (Engineering's READY_FOR_REVIEW = `delivered`).
//   decision:<ID>  The named owner must answer an open decision.
// The highest-ranked unblocked eng hand-off is labelled `active`: when the PO accepts an item,
// its hand-offs close and the next item becomes active without anyone passing a message.

export const LABELS = {
  base: "agents",
  eng: "agent:eng",
  po: "agent:po",
  human: "human-decision",
  active: "active",
  blocked: "blocked",
};

const HUMAN_OWNERS = new Set(["owner", "legal", "clinical"]);

/**
 * Issue = { key, kind, id, title, labels, body, assignOwner }.
 * @param {any} layer  readLayerTexts(...) result
 * @param {Record<string, { po?: number, eng?: number }>} [changed]  unix seconds of the last change per item (0 = unknown)
 * @returns {{ issues: any[], active: string | null }}
 */
export function planCoordination(layer, changed = {}) {
  const statusById = new Map(layer.status.map((s) => [s.id, s]));
  const openById = new Map(layer.open.map((d) => [d.id, d]));
  const issues = [];

  const blockersFor = (id, row) => {
    const fromRow = (row?.blockedBy ?? []).filter((b) => openById.has(b));
    const fromDecisions = layer.open.filter((d) => d.blocks.includes(id)).map((d) => d.id);
    return [...new Set([...fromRow, ...fromDecisions])].map((b) => openById.get(b));
  };

  const engCandidates = [];
  for (const q of [...layer.queue].sort((a, b) => a.rank - b.rank)) {
    const s = statusById.get(q.id);
    const state = s?.state ?? "not-started";
    const t = changed[q.id] ?? {};
    const poNewer = (t.po ?? 0) > (t.eng ?? 0);
    // READY_FOR_REVIEW: `ready-for-review` or `delivered` (merged with green CI). `in-review` = PR open.
    const readyForReview = state === "ready-for-review" || state === "delivered";
    const engDone = state === "in-review" || readyForReview;

    // Engineering hand-off
    let engReason = null;
    if (q.poStatus === "approved" && !engDone) engReason = "implement";
    if (q.poStatus === "changes-requested" && (!engDone || poNewer)) engReason = "changes";
    if (engReason) engCandidates.push({ q, s, engReason, blockers: blockersFor(q.id, s) });

    // PO hand-off: delivered and not yet accepted; after changes-requested only when Engineering delivered again
    const awaitingReview =
      readyForReview && q.poStatus !== "accepted" && q.poStatus !== "withdrawn" &&
      (q.poStatus !== "changes-requested" || !poNewer);
    if (awaitingReview) {
      issues.push({
        key: `po:${q.id}`, kind: "po", id: q.id,
        title: `[PO review] ${q.id} ${clean(q.capability)} is delivered`,
        labels: [LABELS.base, LABELS.po],
        assignOwner: false,
        body: [
          `Engineering marked **${q.id}** as \`${state}\` (READY_FOR_REVIEW): merged with green CI.`,
          "",
          `- Brief: \`docs/agents/briefs/${q.id}.md\` (acceptance criteria)`,
          `- Pull requests: ${(s?.prs ?? []).join(", ") || "–"}`,
          `- Engineering summary: ${clean(s?.summary ?? "")}`,
          "",
          "**PO:** review against the acceptance criteria and set *PO status* in `NEXT_CAPABILITY.md` to `accepted` or `changes-requested` (with the reasons in the brief). This issue closes automatically.",
        ].join("\n"),
      });
    }
  }

  // The highest-ranked unblocked engineering hand-off is the active one.
  const activeCandidate = engCandidates.find((c) => c.blockers.length === 0) ?? null;
  for (const c of engCandidates) {
    const isActive = c === activeCandidate;
    const blocked = c.blockers.length > 0;
    issues.push({
      key: `eng:${c.q.id}`, kind: "eng", id: c.q.id,
      title: `[Engineering] ${c.engReason === "changes" ? "Address PO changes for" : "Implement"} ${c.q.id} ${clean(c.q.capability)}`,
      labels: [LABELS.base, LABELS.eng, ...(isActive ? [LABELS.active] : []), ...(blocked ? [LABELS.blocked] : [])],
      assignOwner: false,
      body: [
        c.engReason === "changes"
          ? `The PO set **${c.q.id}** to \`changes-requested\`. The requested changes are in \`docs/agents/briefs/${c.q.id}.md\`.`
          : `The PO approved **${c.q.id}** (queue rank ${c.q.rank}).`,
        "",
        `- Brief: \`docs/agents/briefs/${c.q.id}.md\``,
        `- Current engineering state: \`${c.s?.state ?? "not-started"}\``,
        blocked
          ? `- **Blocked by:** ${c.blockers.map((b) => `${b.id} (owner: ${b.owner})`).join(", ")}. Build what does not depend on them; record the rest as deviations.`
          : "- Blockers: none",
        isActive ? "- **This is the active capability** (highest-ranked unblocked item)." : "",
        "",
        "**Engineering:** implement per the operating model, open a PR, and set the status row to `in-review`, then `delivered` once merged with green CI. This issue closes automatically.",
      ].filter((l) => l !== "").join("\n"),
    });
  }

  // Decisions: the named owner must answer.
  for (const d of layer.open) {
    const human = HUMAN_OWNERS.has(d.owner);
    issues.push({
      key: `decision:${d.id}`, kind: "decision", id: d.id,
      title: `[Decision ${d.owner}] ${d.id}: ${truncate(clean(d.question), 90)}`,
      labels: [LABELS.base, human ? LABELS.human : d.owner === "po" ? LABELS.po : LABELS.eng],
      assignOwner: human,
      body: [
        `**Owner:** \`${d.owner}\` · **Kind:** \`${d.kind}\` · **Blocks:** ${d.blocks.join(", ") || "–"}`,
        "",
        `**Question:** ${clean(d.question)}`,
        "",
        `**Recommendation:** ${clean(d.recommendation)}`,
        "",
        "Answer by moving the row to *Decided* in `docs/agents/OPEN_DECISIONS.md` (via a pull request). This issue closes automatically.",
      ].join("\n"),
    });
  }

  return { issues, active: activeCandidate ? activeCandidate.q.id : null };
}

/**
 * Diff the plan against existing hand-off issues (by key).
 * @param {any[]} planned
 * @param {any[]} existing
 */
export function diffIssues(planned, existing) {
  const byKey = new Map(existing.map((e) => [e.key, e]));
  const plannedKeys = new Set(planned.map((p) => p.key));
  const create = planned.filter((p) => !byKey.has(p.key));
  const update = planned
    .filter((p) => byKey.has(p.key))
    .map((p) => ({ planned: p, existing: byKey.get(p.key) }))
    .filter(({ planned: p, existing: e }) => p.title !== e.title || p.body !== e.body || !sameSet(p.labels, e.labels));
  const close = existing.filter((e) => !plannedKeys.has(e.key));
  return { create, update, close };
}

/**
 * Why a hand-off closed, from the current layer.
 * @param {string} key
 * @param {any} layer
 */
export function closeReason(key, layer) {
  const [kind, id] = key.split(":");
  const q = layer.queue.find((x) => x.id === id);
  const s = layer.status.find((x) => x.id === id);
  if (kind === "decision") {
    const d = layer.decided.find((x) => x.id === id);
    return d ? `Decided by \`${d.owner}\` (${clean(d.date)}): ${clean(d.answer)}` : "The decision is no longer open.";
  }
  if (q?.poStatus === "accepted") return `**${id} accepted by the PO.** The next capability is activated automatically.`;
  if (kind === "eng" && s) return `Engineering moved ${id} to \`${s.state}\`.`;
  if (kind === "po" && q) return `The PO set ${id} to \`${q.poStatus}\`.`;
  return `${id} no longer needs this hand-off.`;
}

const clean = (v) => (v ?? "").replace(/\s+/g, " ").trim();
const truncate = (v, n) => (v.length > n ? `${v.slice(0, n - 1)}…` : v);
const sameSet = (a, b) => a.length === b.length && a.every((x) => b.includes(x));
