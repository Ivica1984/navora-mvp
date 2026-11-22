"use client";

import { useRouter } from "next/navigation";
import { useTransition } from "react";
import {
  VISIT_ALERTS_RELOAD_LABEL,
  VISIT_ALERTS_UNAVAILABLE_MISSING,
  VISIT_ALERTS_UNAVAILABLE_NEXT,
  VISIT_ALERTS_UNAVAILABLE_NOTICE,
} from "@/features/team/aux-list";

// PERF1 (CGR-272): one visible block in place of the visit hint list while it cannot be loaded; sits where the list
// would be and above the visit cards. The text is a `role="status"` line (announced once, never steals focus); the
// «Neu laden» control sits outside the live region (UXR-276). It re-reads the page on the server (router.refresh), so
// the day view, its scroll position and any open form stay; the notice disappears only when the list loads again.
// Wording and placement are for the `uxa` gate; `cra` checks the content (CGR-277).
export default function HintsUnavailableNotice() {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  return (
    <div data-testid="visit-alerts-unavailable" data-tone="warning"
      className="mb-4 rounded-xl border border-amber-600 bg-amber-50 p-3 text-sm text-amber-900">
      <p role="status">
        <strong className="font-semibold">{VISIT_ALERTS_UNAVAILABLE_NOTICE}</strong>{" "}
        {VISIT_ALERTS_UNAVAILABLE_MISSING} {VISIT_ALERTS_UNAVAILABLE_NEXT}
      </p>
      <button type="button" disabled={pending} aria-busy={pending || undefined}
        onClick={() => startTransition(() => router.refresh())}
        className="mt-2 inline-flex min-h-11 items-center rounded-lg border border-amber-700 bg-white px-3 font-semibold text-amber-900 disabled:opacity-60">
        {VISIT_ALERTS_RELOAD_LABEL}
      </button>
    </div>
  );
}
