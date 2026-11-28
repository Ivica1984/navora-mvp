"use client";

// UX2-23 (uxa UXR-43, layout uxa 16:10, po 16:24; ADR-124): the confirming step opens in place under its control, focus
// moves to its consequence sentence, two buttons: the action (action-primary) and "Abbrechen" (action-outline).
// "Abbrechen" runs nothing, so no command and no audit row; the action runs the existing command once.
import { useEffect, useId, useRef } from "react";
import { CONFIRM_CANCEL_LABEL } from "@/features/admin/confirm-texts";

export default function ConfirmStep({ sentence, actionLabel, pending, onConfirm, onCancel, testId }: {
  sentence: string;
  actionLabel: string;
  pending: boolean;
  onConfirm: () => void;
  onCancel: () => void;
  testId: string;
}) {
  const id = useId();
  const sentenceRef = useRef<HTMLParagraphElement>(null);
  useEffect(() => {
    sentenceRef.current?.focus();
  }, []);
  return (
    <div role="group" aria-labelledby={id} data-testid={testId} className="grid w-full gap-2 rounded-xl border border-stone-300 bg-stone-50 p-3">
      <p id={id} ref={sentenceRef} tabIndex={-1} data-testid={`${testId}-sentence`} className="text-sm font-semibold text-stone-900">
        {sentence}
      </p>
      <div className="flex flex-wrap gap-2">
        <button type="button" disabled={pending} onClick={onConfirm}
          className="min-h-11 rounded-lg bg-emerald-800 px-3 text-sm font-bold text-white disabled:opacity-60">
          {actionLabel}
        </button>
        <button type="button" disabled={pending} onClick={onCancel}
          className="min-h-11 rounded-lg border border-stone-400 bg-white px-3 text-sm font-semibold text-stone-900 disabled:opacity-60">
          {CONFIRM_CANCEL_LABEL}
        </button>
      </div>
    </div>
  );
}
