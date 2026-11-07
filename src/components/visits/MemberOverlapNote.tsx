"use client";

import { useEffect, useState } from "react";
import { getMemberOverlapFact } from "@/features/visits/overlap-commands";
import { memberOverlapNote, type MemberOverlapFact } from "@/features/visits/member-overlap-rules";
import type { OverlapSlot } from "@/components/visits/OverlapNote";

/**
 * PLAN3-16 (ADR-161, `cra` CGR-137): whether the chosen member already has a visit at the form's times, in any team.
 * Re-read whenever member or slot changes (debounced); an answer for an earlier member or slot is never used.
 * `shown` is whether the sentence is on screen now: the save sends it as `member_overlap_shown`.
 */
export function useMemberOverlapNote(
  caseId: string | null,
  visitId: string | null,
  member: { id: string; label: string; me: boolean } | null,
  slot: OverlapSlot,
  enabled = true,
) {
  const [fact, setFact] = useState<{ key: string; value: MemberOverlapFact } | null>(null);
  const memberId = member?.id ?? "";
  const key = `${caseId ?? ""}|${visitId ?? ""}|${memberId}|${slot.date}|${slot.start}|${slot.end}`;
  const active = enabled && memberId !== "";

  useEffect(() => {
    if (!active) return;
    let live = true;
    const timer = setTimeout(() => {
      void getMemberOverlapFact({ caseId, visitId, memberId, date: slot.date, start: slot.start, end: slot.end }).then(
        (value) => { if (live) setFact({ key, value }); },
        () => { if (live) setFact({ key, value: null }); },
      );
    }, 250);
    return () => {
      live = false;
      clearTimeout(timer);
    };
  }, [active, key, caseId, visitId, memberId, slot.date, slot.start, slot.end]);

  const answered = active && fact !== null && fact.key === key;
  const note = answered ? memberOverlapNote(fact.value, member) : null;
  return { note, shown: note !== null, answered };
}

/**
 * PLAN3-16: the one `info` line directly under "Verantwortlich"; a polite status region. It never blocks or delays
 * the save, adds no confirmation and no reason field. The save button points at it (`aria-describedby` = `id`).
 */
export default function MemberOverlapNote({ id, note, answered }: { id: string; note: string | null; answered: boolean }) {
  return (
    // data-read: whether the answer for the current member and times has arrived (tests wait on it).
    <p id={id} data-testid="member-overlap-note" data-tone="info" data-read={answered ? "yes" : "no"} role="status" aria-live="polite"
      className={note ? "rounded-lg border border-stone-300 bg-white p-2 text-sm text-stone-700" : "sr-only"}>
      {note ?? ""}
    </p>
  );
}

/** PLAN3-16: the server found the overlap the form did not show; stated after the save (`info`). */
export function MemberOverlapAfterSave({ note }: { note: string | null }) {
  if (!note) return null;
  return (
    <p role="status" data-testid="member-overlap-after-save" data-tone="info" className="mt-1 rounded-lg border border-stone-300 bg-white p-2 text-sm text-stone-700">
      {note}
    </p>
  );
}
