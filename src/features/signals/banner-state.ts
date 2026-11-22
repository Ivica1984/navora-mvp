// S-1 (founder order 2026-11-22, PR #1671 comments 7071385024 and 7071578135; LEARNINGS 2026-11-21 «Eine Hinweisliste
// darf die ganze Seite der Pflegekraft nicht mitreissen»): the P1 safety signals are never dropped silently.
// Before S-1, a failed `my_signals` read gave the banner an empty list, so the page looked exactly like «no open P1
// signal», and a failed 30 s poll left the cards as they were with no mark. That also broke the SIG1-3 promise that a
// new P1 shows within 60 s, without anyone seeing it.
// The banner now knows three states: `ok` (the last read succeeded), `unavailable` (no read has succeeded on this page
// yet, so nothing is known) and `stale` (an earlier read succeeded, the latest did not: the last known cards stay and
// are marked as not current). The banner is fail-visible, not fail-hard: the page and its visit commands stay usable.
// Pure module, unit-tested in tests/unit/s1-signal-banner-state.test.ts. Working wording; final wording at the `uxa`
// gate, content check by `cra`.

import type { SignalRow } from "./rules";

/** One server read of `public.my_signals`. `unavailable` rows are always empty, never a partial list. */
export type SignalLoad = { rows: SignalRow[]; unavailable: boolean };

export type BannerStatus = "ok" | "unavailable" | "stale";

export type BannerState = {
  rows: SignalRow[];
  status: BannerStatus;
  /** Epoch ms of the last successful read on this page; null when none succeeded yet. */
  lastOkAt: number | null;
};

export const SIGNALS_UNAVAILABLE_TEXT = "Sicherheitssignale konnten nicht geladen werden.";
export const SIGNALS_STALE_TEXT = "Sicherheitssignale konnten nicht aktualisiert werden.";
export const SIGNALS_RETRY_LABEL = "Erneut laden";

export function signalsLoaded(rows: SignalRow[] | null | undefined): SignalLoad {
  return { rows: rows ?? [], unavailable: false };
}

export function signalsUnavailable(): SignalLoad {
  return { rows: [], unavailable: true };
}

/** No read has happened yet on this page. */
const NEVER_LOADED: BannerState = { rows: [], status: "unavailable", lastOkAt: null };

/** A successful read always wins: the rows are the database's current answer. */
export function onReadOk(rows: SignalRow[], now: number): BannerState {
  return { rows, status: "ok", lastOkAt: now };
}

/**
 * A failed read never empties the banner. With an earlier success, the last known cards stay and are marked `stale`.
 * Without one, the banner is `unavailable`.
 */
export function onReadFailed(state: BannerState): BannerState {
  if (state.lastOkAt === null) return { rows: state.rows, status: "unavailable", lastOkAt: null };
  return { rows: state.rows, status: "stale", lastOkAt: state.lastOkAt };
}

/** A server render (first load or router.refresh) brings one read, which is applied like a poll. */
export function onServerLoad(state: BannerState, load: SignalLoad, now: number): BannerState {
  return load.unavailable ? onReadFailed(state) : onReadOk(load.rows, now);
}

export function initialBannerState(load: SignalLoad, now: number): BannerState {
  return onServerLoad(NEVER_LOADED, load, now);
}

/** The hidden «no open signal» marker is set only when the last read succeeded and returned nothing. */
export function showsEmptyMarker(state: BannerState): boolean {
  return state.status === "ok" && state.rows.length === 0;
}

const timeFormat = new Intl.DateTimeFormat("de-CH", { timeZone: "Europe/Zurich", hour: "2-digit", minute: "2-digit", hourCycle: "h23" });

/** The visible line while the signals are not current, or null when they are. */
export function bannerNotice(state: BannerState): { status: Exclude<BannerStatus, "ok">; text: string } | null {
  if (state.status === "ok") return null;
  if (state.status === "unavailable") return { status: "unavailable", text: SIGNALS_UNAVAILABLE_TEXT };
  const at = state.lastOkAt === null ? "" : ` Stand ${timeFormat.format(new Date(state.lastOkAt))}.`;
  return { status: "stale", text: `${SIGNALS_STALE_TEXT}${at}` };
}
