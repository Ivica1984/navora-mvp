import { describe, expect, it } from "vitest";
import { readLayerTexts } from "../../scripts/agents-coordination/parse.mjs";
import { closeReason, diffIssues, mergedLabels, planCoordination } from "../../scripts/agents-coordination/plan.mjs";

type Issue = { key: string; kind: string; id: string; title: string; labels: string[]; body: string; assignOwner: boolean };

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

function plan(n: string, s: string, d = decisions(), changed: Record<string, { po?: number; eng?: number }> = {}) {
  const layer = readLayerTexts({ next: n, status: s, decisions: d });
  const result = planCoordination(layer, changed);
  return { layer, issues: result.issues as Issue[], active: result.active };
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

  it("decisions go to their owner; human owners are assigned, agents get labels", () => {
    const { issues } = plan(next(""), status(""), decisions(
      "| D-11 | owner | regulatory | Pilot canton? | one canton | J5 | 2026-10-21 (po) |\n| Q11 | po | product | Which minutes? | planned | J5 | 2026-10-22 (eng) |",
    ));
    const human = issues.find((i) => i.key === "decision:D-11")!;
    expect(human.assignOwner).toBe(true);
    expect(human.labels).toContain("human-decision");
    expect(issues.find((i) => i.key === "decision:Q11")!.labels).toContain("agent:po");
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
    const layer = readLayerTexts({ next: read("NEXT_CAPABILITY.md"), status: read("IMPLEMENTATION_STATUS.md"), decisions: read("OPEN_DECISIONS.md") });
    expect(layer.queue.length).toBeGreaterThan(0);
    expect(layer.status.length).toBeGreaterThan(0);
    expect(() => planCoordination(layer, {})).not.toThrow();
  });
});
