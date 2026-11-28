import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import {
  SIGNALS_STALE_TEXT,
  SIGNALS_UNAVAILABLE_TEXT,
  bannerNotice,
  initialBannerState,
  onReadFailed,
  onReadOk,
  onServerLoad,
  showsEmptyMarker,
  signalsLoaded,
  signalsUnavailable,
} from "@/features/signals/banner-state";
import type { SignalRow } from "@/features/signals/rules";

// S-1 (founder order 2026-11-22; LEARNINGS 2026-11-21): the P1 safety signals are never dropped silently. Before S-1,
// getMySignals() returned [] on an error and the banner rendered the hidden «no signal» marker: the same screen as no
// open P1. These tests pin the three states and the source wiring.

const row = (id: string): SignalRow => ({ signal_id: id, signal_kind: "visit_overdue" }) as unknown as SignalRow;
// 2026-11-22 08:15 Europe/Zurich (UTC+1).
const T0 = Date.UTC(2026, 10, 22, 7, 15);

describe("S-1: a failed first read is never «no signal»", () => {
  it("an unavailable server read gives `unavailable`, no empty marker, and a visible line", () => {
    const s = initialBannerState(signalsUnavailable(), T0);
    expect(s.status).toBe("unavailable");
    expect(s.rows).toEqual([]);
    expect(showsEmptyMarker(s)).toBe(false);
    expect(bannerNotice(s)).toEqual({ status: "unavailable", text: SIGNALS_UNAVAILABLE_TEXT });
  });

  it("a failed poll after a failed first read stays `unavailable` (nothing is known yet)", () => {
    const s = onReadFailed(initialBannerState(signalsUnavailable(), T0));
    expect(s.status).toBe("unavailable");
    expect(s.lastOkAt).toBeNull();
  });

  it("control: a successful empty read is the only state with the empty marker and no line", () => {
    const s = initialBannerState(signalsLoaded([]), T0);
    expect(s.status).toBe("ok");
    expect(showsEmptyMarker(s)).toBe(true);
    expect(bannerNotice(s)).toBeNull();
  });
});

describe("S-1: a failed poll keeps the last known cards and marks them", () => {
  it("cards stay, status is `stale`, the line names the time of the last successful read (Zurich)", () => {
    const ok = initialBannerState(signalsLoaded([row("a"), row("b")]), T0);
    const s = onReadFailed(ok);
    expect(s.status).toBe("stale");
    expect(s.rows.map((r) => r.signal_id)).toEqual(["a", "b"]);
    expect(s.lastOkAt).toBe(T0);
    expect(bannerNotice(s)).toEqual({ status: "stale", text: `${SIGNALS_STALE_TEXT} Stand 08:15.` });
  });

  it("a failed poll after an empty successful read is `stale`, not the empty marker", () => {
    const s = onReadFailed(initialBannerState(signalsLoaded([]), T0));
    expect(s.status).toBe("stale");
    expect(showsEmptyMarker(s)).toBe(false);
    expect(bannerNotice(s)?.status).toBe("stale");
  });

  it("repeated failures keep the first stale time", () => {
    const s = onReadFailed(onReadFailed(initialBannerState(signalsLoaded([row("a")]), T0)));
    expect(s.lastOkAt).toBe(T0);
    expect(s.rows).toHaveLength(1);
  });

  it("a server refresh that fails keeps the known cards (router.refresh never empties the banner)", () => {
    const s = onServerLoad(initialBannerState(signalsLoaded([row("a")]), T0), signalsUnavailable(), T0 + 60_000);
    expect(s.status).toBe("stale");
    expect(s.rows.map((r) => r.signal_id)).toEqual(["a"]);
  });
});

describe("S-1: recovery", () => {
  it("a successful read replaces the cards with the database's answer and clears the line", () => {
    const stale = onReadFailed(initialBannerState(signalsLoaded([row("a")]), T0));
    const s = onReadOk([row("c")], T0 + 90_000);
    expect(s.status).toBe("ok");
    expect(s.rows.map((r) => r.signal_id)).toEqual(["c"]);
    expect(bannerNotice(s)).toBeNull();
    expect(stale.status).toBe("stale");
  });

  it("a successful server refresh after `unavailable` gives `ok`", () => {
    const s = onServerLoad(initialBannerState(signalsUnavailable(), T0), signalsLoaded([]), T0 + 30_000);
    expect(s.status).toBe("ok");
    expect(showsEmptyMarker(s)).toBe(true);
  });
});

describe("S-1: wiring in the source (fail closed by type)", () => {
  const read = (p: string) => readFileSync(p, "utf8");

  it("getMySignals returns a SignalLoad and never `return []` on its error path", () => {
    const src = read("src/features/signals/queries.ts");
    const body = src.slice(src.indexOf("export async function getMySignals"), src.indexOf("export async function getSignalEvaluatorHealth"));
    expect(body).toMatch(/Promise<SignalLoad>/);
    expect(body).toMatch(/return signalsUnavailable\(\)/);
    expect(body).not.toMatch(/return \[\]/);
  });

  it("the banner takes a SignalLoad and sets the empty marker only through showsEmptyMarker", () => {
    const src = read("src/components/signals/SignalBanner.tsx");
    expect(src).toMatch(/initial: SignalLoad/);
    expect(src).toMatch(/showsEmptyMarker\(state\)\) return <div data-testid="safety-signals-empty" hidden \/>/);
    expect(src).toMatch(/role="alert" data-testid="safety-signals-unavailable"/);
  });

  it("/field, /team and /operations take the signals as a required SignalLoad (no silent default)", () => {
    for (const p of ["src/app/(protected)/field/field-client.tsx", "src/app/(protected)/team/team-client.tsx", "src/app/(protected)/operations/operations-client.tsx"]) {
      const src = read(p);
      expect(src, p).toMatch(/\n  signals: SignalLoad;/);
      expect(src, p).not.toMatch(/signals = \[\]/);
    }
  });
});
