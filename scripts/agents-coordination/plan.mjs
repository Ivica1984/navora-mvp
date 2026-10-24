// Coordination planner — PURE (no I/O). Given the collaboration layer and, per item, when the PO
// last changed its PO status and when Engineering last changed its state, it returns the set of
// hand-off issues that SHOULD be open. scripts/agents-coordination/run.mjs syncs GitHub to it.
//
// Hand-offs (see docs/agents/COORDINATION.md):
//   eng:<ID>       Engineering must implement (PO approved) or address requested changes.
//   po:<ID>        PO must review a delivered item (Engineering's READY_FOR_REVIEW = `delivered`).
//   decision:<ID>  The named owner must answer an open decision. For owners `owner`, `legal`, `clinical`
//                  (COORD5): a person is assigned only once the decision package is
//                  `awaiting-approval: <role>` (docs/agents/decisions/INDEX.md); before that the issue is
//                  the agents' work item (`agent:po` + `decision-package`, nobody assigned).
// The highest-ranked unblocked eng hand-off is labelled `active`: when the PO accepts an item,
// its hand-offs close and the next item becomes active without anyone passing a message.

export const LABELS = {
  base: "agents",
  eng: "agent:eng",
  po: "agent:po",
  human: "human-decision",
  active: "active",
  blocked: "blocked",
  pkg: "decision-package",
};

/** Comment posted once when an assigned human-decision issue goes back to package preparation (COORD5). */
export const PACKAGE_COMMENT =
  "Wird zuerst als Entscheidungspaket vorbereitet (DECISION_PACKAGES.md); du wirst erst bei Freigabebedarf zugewiesen.";

const AWAITING_RE = /^awaiting-approval: (owner|clinical|legal)$/;

const HUMAN_OWNERS = new Set(["owner", "legal", "clinical"]);

/**
 * Issue = { key, kind, id, title, labels, body, assignOwner }.
 * @param {any} layer  readLayerTexts(...) result
 * @param {Record<string, { po?: number, eng?: number }>} [changed]  unix seconds of the last change per item (0 = unknown)
 * @param {{ packageBase?: string }} [options]  link prefix for package files (run.mjs passes the GitHub blob URL)
 * @returns {{ issues: any[], active: string | null, decisions: { id: string, owner: string, packageStatus: string }[] }}
 */
export function planCoordination(layer, changed = {}, options = {}) {
  const pkgBase = options.packageBase ?? "docs/agents/decisions/";
  const packageById = new Map((layer.packages ?? []).map((p) => [p.id, p]));
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

  // Decisions: the named owner must answer. Human owners only once the package asks for approval (COORD5).
  const decisions = [];
  for (const d of layer.open) {
    const human = HUMAN_OWNERS.has(d.owner);
    const pkg = packageById.get(d.id);
    const packageStatus = pkg?.status ?? "none";
    decisions.push({ id: d.id, owner: d.owner, packageStatus });
    const header = [
      `**Owner:** \`${d.owner}\` · **Kind:** \`${d.kind}\` · **Blocks:** ${d.blocks.join(", ") || "–"}`,
      "",
      `**Question:** ${clean(d.question)}`,
      "",
      `**Recommendation:** ${clean(d.recommendation)}`,
    ];
    const footer = "Answer by moving the row to *Decided* in `docs/agents/OPEN_DECISIONS.md` (via a pull request). This issue closes automatically.";
    if (!human) {
      issues.push({
        key: `decision:${d.id}`, kind: "decision", id: d.id,
        title: `[Decision ${d.owner}] ${d.id}: ${truncate(clean(d.question), 90)}`,
        labels: [LABELS.base, d.owner === "po" ? LABELS.po : LABELS.eng],
        assignOwner: false, packageStatus,
        body: [...header, "", footer].join("\n"),
      });
      continue;
    }
    // A package is ready for a person only when it says so AND its file exists (validator enforces both).
    const awaiting = AWAITING_RE.test(packageStatus) && Boolean(pkg?.file);
    const link = pkg?.file ? `${pkgBase}${pkg.file}` : null;
    if (awaiting) {
      const role = packageStatus.replace("awaiting-approval: ", "");
      issues.push({
        key: `decision:${d.id}`, kind: "decision", id: d.id,
        title: `[Decision ${d.owner}] ${d.id}: ${truncate(clean(d.question), 90)}`,
        labels: [LABELS.base, LABELS.human],
        assignOwner: true, packageStatus,
        body: [
          ...header,
          "",
          `**Decision package:** [${pkg.file}](${link}) · status \`${packageStatus}\` (approval by \`${role}\`)`,
          "",
          "**Owner approval required?** (quoted from the package)",
          "",
          quote(pkg.approval) || "> (section *Owner approval required?* not found in the package; read the package)",
          "",
          footer,
        ].join("\n"),
      });
    } else {
      // not-started, inputs-requested, no INDEX row, or po-decided/decided while still in Open
      // (the PO has not recorded it yet; the validator warns): the agents' work item, nobody assigned.
      issues.push({
        key: `decision:${d.id}`, kind: "decision", id: d.id,
        title: `[Decision package] ${d.id}: ${truncate(clean(d.question), 90)}`,
        labels: [LABELS.base, LABELS.po, LABELS.pkg],
        assignOwner: false, packageStatus,
        body: [
          ...header,
          "",
          `**Decision package:** ${link ? `[${pkg.file}](${link})` : "not written yet"} · status \`${packageStatus}\``,
          "",
          "Prepared by the agents first (`docs/agents/DECISION_PACKAGES.md`). No person is asked until the package is `awaiting-approval: <role>` in `docs/agents/decisions/INDEX.md`; the safe default in the row stays in force.",
          "",
          footer,
        ].join("\n"),
      });
    }
  }

  return { issues, active: activeCandidate ? activeCandidate.q.id : null, decisions };
}

/** Labels the watcher owns. Any other label on an issue (e.g. `claimed`) is left alone. */
export const MANAGED = new Set(Object.values(LABELS));

/** Planned managed labels plus the issue's own unmanaged labels (claims survive every sync). */
export function mergedLabels(plannedLabels, existingLabels) {
  return [...plannedLabels, ...(existingLabels ?? []).filter((l) => !MANAGED.has(l) && !plannedLabels.includes(l))];
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
    .filter(({ planned: p, existing: e }) =>
      p.title !== e.title || p.body !== e.body || !sameSet(p.labels, (e.labels ?? []).filter((l) => MANAGED.has(l))) ||
      (p.kind === "decision" && Boolean(p.assignOwner) !== Boolean(e.assignedOwner)));
  const close = existing.filter((e) => !plannedKeys.has(e.key));
  return { create, update, close };
}

/**
 * Assignees after a sync (COORD5): add the owner when the plan assigns, remove only the owner otherwise.
 * Other assignees are left alone. Returns null when nothing changes.
 * @param {any} planned
 * @param {string[]} assignees  current logins
 * @param {string} ownerLogin
 */
export function nextAssignees(planned, assignees, ownerLogin) {
  if (planned.kind !== "decision" || !ownerLogin) return null;
  const has = (assignees ?? []).includes(ownerLogin);
  if (planned.assignOwner && !has) return [...(assignees ?? []), ownerLogin];
  if (!planned.assignOwner && has) return assignees.filter((a) => a !== ownerLogin);
  return null;
}

/**
 * The one comment for an existing issue that leaves the owner's desk for package preparation:
 * it was a human-decision issue (label or owner assigned) and is now a decision-package issue.
 */
export function packageTransitionComment(planned, existing) {
  const wasHuman = (existing.labels ?? []).includes(LABELS.human) || Boolean(existing.assignedOwner);
  return planned.labels.includes(LABELS.pkg) && wasHuman ? PACKAGE_COMMENT : null;
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

const quote = (v) => (v ?? "").trim() ? truncate((v ?? "").trim(), 4000).split("\n").map((l) => `> ${l}`.trimEnd()).join("\n") : "";
const clean = (v) => (v ?? "").replace(/\s+/g, " ").trim();
const truncate = (v, n) => (v.length > n ? `${v.slice(0, n - 1)}…` : v);
const sameSet = (a, b) => a.length === b.length && a.every((x) => b.includes(x));
