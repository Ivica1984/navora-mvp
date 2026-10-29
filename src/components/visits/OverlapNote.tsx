"use client";

import { useEffect, useState } from "react";
import { getClientOverlapFact } from "@/features/visits/overlap-commands";
import { overlapNote, type OverlapFact } from "@/features/visits/overlap-rules";

export type OverlapSlot = { date: string; start: string; end: string };

/** Reads date, start and end from a form whose inputs are named `date`, `start`, `end` (missing ones as given). */
export function slotFromForm(form: HTMLFormElement, fallback: OverlapSlot): OverlapSlot {
  const data = new FormData(form);
  const read = (k: keyof OverlapSlot) => {
    const v = data.get(k);
    return typeof v === "string" ? v : fallback[k];
  };
  return { date: read("date"), start: read("start"), end: read("end") };
}

/**
 * VIS2-1 / VIS2-2 / VIS2-5 (1) (ADR-121): the client's overlap for the times in the form. Re-read whenever the slot
 * changes (debounced) and whenever the form is offered again (mount); an answer for an earlier slot is never used.
 * `shown` is whether the sentence is on screen now: the save sends it as `overlap_shown` (VIS2-4).
 */
export function useOverlapNote(caseId: string | null, visitId: string | null, slot: OverlapSlot, today: string, enabled = true) {
  const [fact, setFact] = useState<{ key: string; value: OverlapFact } | null>(null);
  const key = `${caseId ?? ""}|${visitId ?? ""}|${slot.date}|${slot.start}|${slot.end}`;

  useEffect(() => {
    if (!enabled) return;
    let live = true;
    const timer = setTimeout(() => {
      void getClientOverlapFact({ caseId, visitId, date: slot.date, start: slot.start, end: slot.end }).then(
        (value) => { if (live) setFact({ key, value }); },
        () => { if (live) setFact({ key, value: null }); },
      );
    }, 250);
    return () => {
      live = false;
      clearTimeout(timer);
    };
  }, [enabled, key, caseId, visitId, slot.date, slot.start, slot.end]);

  const note = enabled && fact && fact.key === key ? overlapNote(slot.date, fact.value, today) : null;
  return { note, shown: note !== null };
}

/**
 * VIS2-1: the sentence, `info`, below "Von"/"Bis"; a polite status region, so it is announced when it appears and
 * disappears with the times. It never blocks or delays the save and adds no field or colour above `info`. The save
 * button points at it (`aria-describedby` = `id`).
 */
export default function OverlapNote({ id, note }: { id: string; note: string | null }) {
  return (
    <p id={id} data-testid="overlap-note" data-tone="info" role="status" aria-live="polite"
      className={note ? "rounded-lg border border-stone-300 bg-white p-2 text-sm text-stone-700" : "sr-only"}>
      {note ?? ""}
    </p>
  );
}

/** VIS2-5 (2): the server found an overlap the form did not show; shown on the card after the save (`info`). */
export function OverlapAfterSave({ note }: { note: string | null }) {
  if (!note) return null;
  return (
    <p role="status" data-testid="overlap-after-save" data-tone="info" className="mt-1 rounded-lg border border-stone-300 bg-white p-2 text-sm text-stone-700">
      {note}
    </p>
  );
}
