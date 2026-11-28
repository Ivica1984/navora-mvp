"use client";

// UXR-309 (HD-PEN-HAND): the Monatssoll form asks «Wert» or «kein Monatssoll». Without a target «kein Monatssoll» is
// pre-selected (the page passes it), a typed number selects «Wert», and choosing «kein Monatssoll» empties the number, so
// the first input never costs a refused save («bitte wählen»). Without JavaScript the server keeps refusing an
// inconsistent pair (fail safe, unchanged). Names and test ids are the ones the server action and e2e read.
import { useRef } from "react";

export function MonthTargetChoice({ noValue, target, inputClass }: { noValue: string; target: string; inputClass: string }) {
  const value = useRef<HTMLInputElement>(null);
  const none = useRef<HTMLInputElement>(null);
  const hasTarget = target !== "";
  return (
    <div className="flex flex-wrap items-center gap-2">
      <label className="flex min-h-11 items-center gap-1">
        <input ref={value} type="radio" name="target_choice" value="wert" defaultChecked={hasTarget} data-testid="heim-month-target-value" /> Wert
      </label>
      <input name="target" inputMode="decimal" aria-label="Monatssoll in Stunden" defaultValue={target}
        onInput={(e) => { if (e.currentTarget.value.trim() !== "" && value.current) value.current.checked = true; }}
        className={`${inputClass} w-24`} data-testid="heim-month-target-input" />
      <label className="flex min-h-11 items-center gap-1">
        <input ref={none} type="radio" name="target_choice" value={noValue} defaultChecked={!hasTarget}
          onChange={(e) => {
            const form = e.currentTarget.form;
            const field = form?.elements.namedItem("target");
            if (e.currentTarget.checked && field instanceof HTMLInputElement) field.value = "";
          }}
          data-testid="heim-month-target-none-choice" /> kein Monatssoll
      </label>
    </div>
  );
}
