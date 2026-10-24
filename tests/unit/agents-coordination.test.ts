import { describe, expect, it } from "vitest";
import { readLayerTexts } from "../../scripts/agents-coordination/parse.mjs";
import {
  closeReason, diffIssues, mergedLabels, nextAssignees, PACKAGE_COMMENT, packageTransitionComment, planCoordination,
} from "../../scripts/agents-coordination/plan.mjs";

type Issue = { key: string; kind: string; id: string; title: string; labels: string[]; body: string; assignOwner: boolean; packageStatus: string };

const next = (rows: string, nextUp = "") => `# Next capability

## Priority queue

| Rank | ID | Capability | PO status | Brief | Why |
|---|---|---|---|---|---|
${rows}
${nextUp ? `
## Next up (approved briefs; engineering may start in this order)

| Order | ID | Capability | Brief | Why |
|---|---|---|---|---|
${nextUp}
` : ""}
## Notes
`;

const status = (rows: string) => `# Status

## Items

| ID | Origin | State | Summary | Next | PRs | ADRs | Blocked by | Deviations |
|---|---|---|---|---|---|---|---|---|
${rows}
`;

const decisions = (open = "", decided = "") => `# Decisions

## Open

| ID | Owner | Kind | Question | Recommendation | Blocks | Opened |
|---|---|---|---|---|---|---|
${open}

## Decided

| ID | Owner | Answer | Date |
|---|---|---|---|
${decided}
`;

// decisions/INDEX.md as the PO writes it: a title, prose, then the first table (no "## " heading).
const index = (rows: string) => `# Decision packages: index and order

The PO works this list top to bottom.

| Order | Tier | ID | Row owner | Question (short) | Blocks | CGR | Inputs | Preliminary route | Package status |
|---|---|---|---|---|---|---|---|---|---|
${rows}

**Not a decision row.**
`;
const pkgRow = (id: string, owner: string, cell: string) => `| 1 | 2 | ${id} | ${owner} | q | – | – | E | r | ${cell} |`;
const packageFile = (approval: string) => `---\nid: X\n---\n\n# X\n\n## Recommended default for NAVORA\nB.\n\n## Owner approval required?\n${approval}\n`;

function plan(
  n: string, s: string, d = decisions(), changed: Record<string, { po?: number; eng?: number }> = {},
  idx = "", packageFiles: Record<string, string> = {},
) {
  const layer = readLayerTexts({ next: n, status: s, decisions: d, index: idx, packageFiles });
  const result = planCoordination(layer, changed);
  return { layer, issues: result.issues as Issue[], active: result.active, decisions: result.decisions };
}
const keys = (issues: Issue[]) => issues.map((i) => i.key).sort();

describe("coordination planner", () => {
  it("PO approves → Engineering gets an active implement hand-off", () => {
    const { issues, active } = plan(next("| 1 | C1 | Lifecycle | approved | [C1](briefs/C1.md) | why |"), status("| C1 | po | not-started | s | n | – | – | – | – |"));
    expect(active).toBe("C1");
    const eng = issues.find((i) => i.key === "eng:C1")!;
    expect(eng.labels).toEqual(expect.arrayContaining(["agents", "agent:eng", "active"]));
    expect(eng.title).toContain("Implement C1");
  });

  it("Engineering delivers (READY_FOR_REVIEW) → the PO gets a review hand-off, Engineering's closes", () => {
    const { issues, active } = plan(next("| 1 | C1 | Lifecycle | approved | b | w |"), status("| C1 | po | delivered | s | n | #50 | – | – | – |"));
    expect(keys(issues)).toEqual(["po:C1"]);
    expect(issues[0].body).toContain("#50");
    expect(active).toBeNull();
  });

  it("READY_FOR_REVIEW as the literal state `ready-for-review` triggers the PO review", () => {
    const { issues } = plan(next("| 1 | C1 | L | approved | b | w |"), status("| C1 | po | ready-for-review | s | n | #50 | – | – | – |"));
    expect(keys(issues)).toEqual(["po:C1"]);
    expect(issues[0].body).toContain("`ready-for-review` (READY_FOR_REVIEW)");
  });

  it("in-review (PR open, CI running) needs no PO review yet", () => {
    const { issues } = plan(next("| 1 | C1 | L | approved | b | w |"), status("| C1 | po | in-review | s | n | #50 | – | – | – |"));
    expect(issues).toEqual([]);
  });

  it("PO accepts → all hand-offs for the item close and the next approved item becomes active", () => {
    const { issues, active, layer } = plan(
      next("| 1 | C1 | L | accepted | b | w |\n| 2 | ADM1 | Admin | approved | b | w |"),
      status("| C1 | po | delivered | s | n | #50 | – | – | – |\n| ADM1 | po | not-started | s | n | – | – | – | – |"),
    );
    expect(keys(issues)).toEqual(["eng:ADM1"]);
    expect(active).toBe("ADM1");
    expect(closeReason("po:C1", layer)).toContain("accepted by the PO");
  });

  it("changes-requested after delivery → Engineering again, only if the PO spoke last", () => {
    const n = next("| 1 | J5 | Billing | changes-requested | b | w |");
    const s = status("| J5 | po | delivered | s | n | #43 | – | – | – |");
    expect(keys(plan(n, s, decisions(), { J5: { po: 200, eng: 100 } }).issues)).toEqual(["eng:J5"]);
    expect(plan(n, s, decisions(), { J5: { po: 200, eng: 100 } }).issues[0].title).toContain("Address PO changes");
    // Engineering delivered the fix after the review → back to the PO
    expect(keys(plan(n, s, decisions(), { J5: { po: 100, eng: 200 } }).issues)).toEqual(["po:J5"]);
  });

  it("'Next up' items are approved and ranked after the queue", () => {
    const { issues, active } = plan(
      next("| 1 | F0 | Base | accepted | b | w |", "| 1 | C1 | Lifecycle | [C1](briefs/C1.md) | w |\n| 2 | ADM1 | Admin | b | w |"),
      status("| F0 | po | delivered | s | n | – | – | – | – |"),
    );
    expect(active).toBe("C1");
    expect(keys(issues)).toEqual(["eng:ADM1", "eng:C1"]);
    expect(issues.find((i) => i.key === "eng:ADM1")!.labels).not.toContain("active");
  });

  it("a blocked item is labelled, names its blockers and does not become active", () => {
    const { issues, active } = plan(
      next("| 1 | QG1 | Quality | approved | b | w |\n| 2 | J6 | Continuity | approved | b | w |"),
      status("| QG1 | po | not-started | s | n | – | – | D-16 | – |\n| J6 | po | not-started | s | n | – | – | – | – |"),
      decisions("| D-16 | clinical | clinical | Which events? | short list | QG1 | 2026-10-21 (po) |"),
    );
    const qg1 = issues.find((i) => i.key === "eng:QG1")!;
    expect(qg1.labels).toContain("blocked");
    expect(qg1.body).toContain("D-16 (owner: clinical)");
    expect(active).toBe("J6");
  });

  it("decisions go to their owner once the package asks; agent-owned decisions keep today's behaviour", () => {
    const { issues } = plan(next(""), status(""), decisions(
      "| D-11 | owner | regulatory | Pilot canton? | one canton | J5 | 2026-10-21 (po) |\n| Q11 | po | product | Which minutes? | planned | J5 | 2026-10-22 (eng) |\n| Q12 | eng | technical | Which index? | btree | – | 2026-10-22 (eng) |",
    ), {}, index(pkgRow("D-11", "owner", "[awaiting-approval: owner](D-11.md) (2026-10-24; Medium)")), { "D-11.md": packageFile("**Yes: `owner`.** Approve B.") });
    const human = issues.find((i) => i.key === "decision:D-11")!;
    expect(human.assignOwner).toBe(true);
    expect(human.labels).toEqual(["agents", "human-decision"]);
    const q11 = issues.find((i) => i.key === "decision:Q11")!;
    expect(q11.labels).toEqual(["agents", "agent:po"]);
    expect(q11.assignOwner).toBe(false);
    expect(issues.find((i) => i.key === "decision:Q12")!.labels).toEqual(["agents", "agent:eng"]);
  });

  describe("decision packages (COORD5)", () => {
    const open = (owner = "clinical") => decisions(`| D-30 | ${owner} | clinical | Correct a departed author's report? | refuse | F6 | 2026-10-22 (po) |`);
    const files = { "D-30.md": packageFile("**Yes: `clinical`** (the named Clinical Owner). **Asked:** approve recommendation 1 and 2.\n**Default until then:** refusal.") };
    const decisionIssue = (cell: string | null, owner = "clinical", pf: Record<string, string> = files) =>
      plan(next(""), status(""), open(owner), {}, cell === null ? "" : index(pkgRow("D-30", owner, cell)), pf).issues.find((i) => i.key === "decision:D-30");

    for (const cell of ["not-started", "[inputs-requested](D-30.md) (2026-10-24 03:10)"]) {
      it(`status ${cell.split(" ")[0]} → agents' work item: agent:po + decision-package, no human-decision, nobody assigned`, () => {
        const i = decisionIssue(cell)!;
        expect(i.labels).toEqual(["agents", "agent:po", "decision-package"]);
        expect(i.labels).not.toContain("human-decision");
        expect(i.assignOwner).toBe(false);
        expect(i.title).toContain("[Decision package] D-30");
      });
    }

    it("no INDEX row → decision-package, nobody assigned (validator reports the missing row)", () => {
      const i = decisionIssue(null)!;
      expect(i.labels).toEqual(["agents", "agent:po", "decision-package"]);
      expect(i.assignOwner).toBe(false);
      expect(i.packageStatus).toBe("none");
      expect(i.body).toContain("not written yet");
    });

    for (const role of ["owner", "legal", "clinical"]) {
      it(`awaiting-approval: ${role} → human-decision, assigned to the owner, body links the package and quotes the approval section`, () => {
        const i = decisionIssue(`[awaiting-approval: ${role}](D-30.md) (2026-10-24 08:18; Clinical Owner not named, G-1)`, role)!;
        expect(i.labels).toEqual(["agents", "human-decision"]);
        expect(i.assignOwner).toBe(true);
        expect(i.body).toContain("[D-30.md](docs/agents/decisions/D-30.md)");
        expect(i.body).toContain(`approval by \`${role}\``);
        expect(i.body).toContain("> **Yes: `clinical`** (the named Clinical Owner). **Asked:** approve recommendation 1 and 2.");
        expect(i.body).toContain("> **Default until then:** refusal.");
      });
    }

    it("awaiting-approval whose package file is missing is not handed to a person", () => {
      const i = decisionIssue("[awaiting-approval: clinical](D-30.md) (2026-10-24)", "clinical", {})!;
      // the link is in the INDEX but the file is not readable: approval text cannot be quoted → still assigned (file named)
      expect(i.assignOwner).toBe(true);
      expect(i.body).toContain("section *Owner approval required?* not found");
      // no file named at all ("awaiting-approval: clinical" as plain text) → stays with the agents
      const plain = decisionIssue("awaiting-approval: clinical", "clinical", {})!;
      expect(plain.assignOwner).toBe(false);
      expect(plain.labels).toContain("decision-package");
    });

    it("negative: po-decided (or decided) while still in Open keeps decision-package, never human-decision", () => {
      for (const cell of ["[po-decided](D-30.md) (2026-10-24)", "decided"]) {
        const i = decisionIssue(cell)!;
        expect(i.labels).toEqual(["agents", "agent:po", "decision-package"]);
        expect(i.labels).not.toContain("human-decision");
        expect(i.assignOwner).toBe(false);
      }
    });

    it("po-decided or decided and moved to Decided → the issue closes with the existing close reason", () => {
      const { issues, layer } = plan(next(""), status(""),
        decisions("", "| D-30 | po | Team RN withdraws an untouched draft ([D-30](decisions/D-30.md)) | 2026-10-24 |"), {},
        index(pkgRow("D-30", "clinical", "[po-decided](D-30.md) (2026-10-24)")), files);
      expect(issues).toEqual([]);
      const existing = [{ key: "decision:D-30", kind: "decision", title: "t", body: "b", labels: ["agents", "agent:po", "decision-package"], number: 9 }];
      expect(diffIssues(issues, existing).close.map((e: { key: string }) => e.key)).toEqual(["decision:D-30"]);
      expect(closeReason("decision:D-30", layer)).toContain("Decided by `po` (2026-10-24)");
    });

    it("an existing assigned human-decision issue is unassigned, relabelled and commented once", () => {
      const planned = decisionIssue("[inputs-requested](D-30.md) (2026-10-24)")!;
      const existing = {
        key: "decision:D-30", kind: "decision", number: 7, title: "[Decision clinical] D-30: old", body: "old",
        labels: ["agents", "human-decision", "claimed"], assignees: ["Ivica1984", "someone-else"], assignedOwner: true,
      };
      const { update } = diffIssues([planned], [existing]);
      expect(update).toHaveLength(1);
      expect(mergedLabels(planned.labels, existing.labels)).toEqual(["agents", "agent:po", "decision-package", "claimed"]);
      expect(nextAssignees(planned, existing.assignees, "Ivica1984")).toEqual(["someone-else"]);
      expect(packageTransitionComment(planned, existing)).toBe(PACKAGE_COMMENT);
      expect(PACKAGE_COMMENT).toBe("Wird zuerst als Entscheidungspaket vorbereitet (DECISION_PACKAGES.md); du wirst erst bei Freigabebedarf zugewiesen.");
      // after that sync the issue matches the plan: no further update, no second comment
      const synced = { ...existing, title: planned.title, body: planned.body, labels: ["agents", "agent:po", "decision-package", "claimed"], assignees: ["someone-else"], assignedOwner: false };
      expect(diffIssues([planned], [synced]).update).toEqual([]);
      expect(packageTransitionComment(planned, synced)).toBeNull();
      expect(nextAssignees(planned, synced.assignees, "Ivica1984")).toBeNull();
    });

    it("an assignee difference alone triggers an update; a package issue that becomes awaiting-approval is assigned", () => {
      const planned = decisionIssue("[awaiting-approval: clinical](D-30.md) (2026-10-24)")!;
      const existing = { ...planned, number: 3, assignees: [], assignedOwner: false };
      expect(diffIssues([planned], [existing]).update).toHaveLength(1);
      expect(nextAssignees(planned, [], "Ivica1984")).toEqual(["Ivica1984"]);
      expect(packageTransitionComment(planned, { labels: ["agents", "agent:po", "decision-package"] })).toBeNull();
    });

    it("the plan reports the package status per decision (printed by --dry-run)", () => {
      const r = plan(next(""), status(""), decisions(
        "| D-30 | clinical | clinical | q | r | – | 2026-10-22 (po) |\n| D-9 | legal | legal | q | r | – | 2026-10-22 (po) |",
      ), {}, index(pkgRow("D-30", "clinical", "[awaiting-approval: clinical](D-30.md) (x)")), files);
      expect(r.decisions).toEqual([
        { id: "D-30", owner: "clinical", packageStatus: "awaiting-approval: clinical" },
        { id: "D-9", owner: "legal", packageStatus: "none" },
      ]);
    });
  });

  it("withdrawn and draft items create no hand-offs", () => {
    const { issues } = plan(next("| 1 | J7 | Econ | draft | b | w |\n| 2 | X1 | Old | withdrawn | b | w |"),
      status("| J7 | po | not-started | s | n | – | – | – | – |\n| X1 | po | delivered | s | n | – | – | – | – |"));
    expect(issues).toEqual([]);
  });

  it("diff is idempotent: an unchanged plan produces no work", () => {
    const { issues } = plan(next("| 1 | C1 | L | approved | b | w |"), status("| C1 | po | not-started | s | n | – | – | – | – |"));
    const existing = issues.map((i) => ({ ...i, number: 1 }));
    expect(diffIssues(issues, existing)).toEqual({ create: [], update: [], close: [] });
    const stale = [...existing, { key: "po:F0", title: "t", body: "b", labels: ["agents"], number: 2 }];
    expect(diffIssues(issues, stale).close.map((e: { key: string }) => e.key)).toEqual(["po:F0"]);
  });

  it("a claim survives every sync: unmanaged labels are kept and never cause an update", () => {
    const { issues } = plan(next("| 1 | C1 | L | approved | b | w |"), status("| C1 | po | not-started | s | n | – | – | – | – |"));
    const claimed = issues.map((i) => ({ ...i, labels: [...i.labels, "claimed"], number: 1 }));
    expect(diffIssues(issues, claimed)).toEqual({ create: [], update: [], close: [] });
    expect(mergedLabels(["agents", "agent:eng"], ["agents", "agent:eng", "active", "claimed"])).toEqual(["agents", "agent:eng", "claimed"]);
  });

  it("reads the real collaboration layer without errors", async () => {
    const { readFileSync } = await import("node:fs");
    const read = (f: string) => readFileSync(`docs/agents/${f}`, "utf8");
    const layer = readLayerTexts({
      next: read("NEXT_CAPABILITY.md"), status: read("IMPLEMENTATION_STATUS.md"), decisions: read("OPEN_DECISIONS.md"), index: read("decisions/INDEX.md"),
    });
    expect(layer.queue.length).toBeGreaterThan(0);
    expect(layer.packages.length).toBeGreaterThan(0);
    expect(layer.status.length).toBeGreaterThan(0);
    expect(() => planCoordination(layer, {})).not.toThrow();
  });
});
