import { readFileSync } from "node:fs";
import { createElement, isValidElement, type ReactElement, type ReactNode } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";
import MemberOpenReportsStep from "@/app/(protected)/admin/member-open-reports";
import {
  OPEN_REPORTS_RETRY_LABEL, OPEN_REPORTS_UNKNOWN_SENTENCE, OPEN_REPORTS_UNREAD_MESSAGE, accessEndedNotice,
} from "@/features/admin/rules";

/**
 * RLS4-C3 (po 2026-11-03 06:30, `cra` CGR-111, `uxa` UXR-73; interim wording confirmed by `cra` 09:30; ADR-138): when the administrator's
 * pre-read of a leaver's open reports fails, the access-end step names one next step ("Erneut laden", which reads the
 * list again for that one member), ending access stays possible without the list, and the result line after the end
 * never claims "Keine offenen Berichte" when the count is missing. Synthetic rows only.
 */

type Props = { children?: ReactNode; onClick?: () => void; disabled?: boolean; className?: string };

/** Every element of a rendered tree (the step is a pure component: no hooks, so it can be called directly). */
function elements(node: ReactNode): ReactElement<Props>[] {
  if (Array.isArray(node)) return node.flatMap(elements);
  if (!isValidElement<Props>(node)) return [];
  return [node, ...elements(node.props.children)];
}

const step = (open: Parameters<typeof MemberOpenReportsStep>[0]["open"], onRetry = () => undefined) =>
  MemberOpenReportsStep({ open, onRetry });
const html = (open: Parameters<typeof MemberOpenReportsStep>[0]["open"]) =>
  renderToStaticMarkup(createElement(MemberOpenReportsStep, { open, onRetry: () => undefined }));

describe("RLS4-C3 (1): a failed read shows the alert and one action 'Erneut laden'", () => {
  it("with the read failed (null), the alert and the 'Erneut laden' button are shown", () => {
    const out = html(null);
    expect(out).toContain('role="alert"');
    expect(out).toContain(OPEN_REPORTS_UNREAD_MESSAGE);
    expect(OPEN_REPORTS_UNREAD_MESSAGE).toBe("Offene Berichte konnten nicht geladen werden.");
    expect(OPEN_REPORTS_RETRY_LABEL).toBe("Erneut laden");
    const buttons = elements(step(null)).filter((e) => e.type === "button");
    expect(buttons).toHaveLength(1);
    expect(buttons[0].props.children).toBe("Erneut laden");
    expect(out).toContain('type="button"');
  });

  it("the action is at least 44 px high (min-h-11) and directly follows the failure line in the same block", () => {
    const out = html(null);
    expect(out).toMatch(/<button[^>]*class="[^"]*min-h-11/);
    expect(out.indexOf(OPEN_REPORTS_UNREAD_MESSAGE)).toBeLessThan(out.indexOf("Erneut laden"));
    expect(out).toContain('data-testid="open-reports"');
  });

  it("a click on 'Erneut laden' calls the read again (onRetry once per click)", () => {
    const onRetry = vi.fn();
    const [button] = elements(step(null, onRetry)).filter((e) => e.type === "button");
    button.props.onClick?.();
    expect(onRetry).toHaveBeenCalledTimes(1);
    button.props.onClick?.();
    expect(onRetry).toHaveBeenCalledTimes(2);
  });

  it("no 'Erneut laden' while loading or once the list is read; never 'keine' on a failed read", () => {
    expect(html("loading")).not.toContain("Erneut laden");
    expect(html("loading")).toContain("Offene Berichte werden geladen");
    const read = html([{ kind: "unsigned", visit_date: "2026-10-29", team_name: "Testteam" }]);
    expect(read).not.toContain("Erneut laden");
    expect(read).toContain("Offene Berichte: 1");
    expect(html([])).toContain("keine offenen Berichte");
    expect(html(null).toLowerCase()).not.toContain("keine");
  });
});

describe("RLS4-C3 (1): /admin wires the action to the one-member read, and ending stays possible", () => {
  const client = readFileSync("src/app/(protected)/admin/admin-client.tsx", "utf8");

  it("the retry runs the same one-member read (readMemberOpenReports) and nothing else", () => {
    const start = client.indexOf("const readOpen = () => {");
    expect(start).toBeGreaterThan(-1);
    const readOpen = client.slice(start, client.indexOf("};", start));
    expect(readOpen).toContain('setOpen("loading")');
    expect(readOpen).toContain("readMemberOpenReports({ userId: member.user_id })");
    expect(readOpen).not.toContain("prepareMemberAccessEnd");
    expect(client).toContain("<MemberOpenReportsStep open={open} onRetry={readOpen} />");
  });

  it("the end button waits only while loading: a failed read does not block ending access (product decision)", () => {
    expect(client).toContain('disabled={pending || (mode === "end" && open === "loading")}');
    expect(client).not.toMatch(/open === null\)\}/);
  });
});

describe("RLS4-C3 (2): the result line never says 'Keine offenen Berichte' on a missing count", () => {
  it("accessEndedNotice(null, …) names the unknown count and where the team sees the reports", () => {
    const line = accessEndedNotice(null);
    expect(line).not.toContain("Keine offenen Berichte");
    expect(line).toBe(`Zugang beendet. ${OPEN_REPORTS_UNKNOWN_SENTENCE}`);
    expect(OPEN_REPORTS_UNKNOWN_SENTENCE)
      .toBe("Offene Berichte unbekannt: das Team sieht sie mit «Zugang beendet».");
  });

  it("released visits, taken signals and unexported days keep their sentences around the unknown count", () => {
    expect(accessEndedNotice(null, 2, 1, 3)).toBe(
      "Zugang beendet. 2 geplante Einsätze sind jetzt offen im Team. 1 übernommenes Sicherheitssignal ist wieder offen im Team. "
      + `${OPEN_REPORTS_UNKNOWN_SENTENCE} Bestätigte Tage, die sie noch nicht exportiert hat: 3.`);
    expect(accessEndedNotice(null, 0, 0, 3)).not.toContain("Keine offenen Berichte");
  });

  it("a read count of zero still says 'Keine offenen Berichte' (unchanged)", () => {
    expect(accessEndedNotice({ unsigned: 0, correction_draft: 0, returned: 0 })).toBe("Zugang beendet. Keine offenen Berichte.");
  });
});
