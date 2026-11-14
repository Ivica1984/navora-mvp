"use client";

// ASM1-C6 (migration 0106, ADR-140; `cra` CGR-103, `lca` 09:40, po 13:28 and 18:25, `uxa` 15:50): "Irrtümlich erfasst"
// on a record that is not superseded. The form (P-37 two options, `cra` supersede sentence first) then one confirming
// step (UX2-23 pattern): "Abbrechen" runs nothing, so no act and no audit row. The database decides who may (a
// registered nurse of the case's team, provisional) and stores the preset text as shown. No colour above `info`.

import { useRouter } from "next/navigation";
import { useState } from "react";
import ConfirmStep from "@/app/(protected)/admin/confirm-step";
import { voidAssessment } from "@/features/assessment/commands";
import { VOID_CONFIRM_SENTENCE, VOID_SUBMIT_LABEL, type VoidChoice } from "@/features/assessment/rules";
import VoidReasonForm from "./assessment-void-fields";
import { ErrorText } from "./error-text";

export default function AssessmentVoidForm({ recordId, onClose }: { recordId: string; onClose: () => void }) {
  const router = useRouter();
  const [choice, setChoice] = useState<VoidChoice | null>(null);
  const [text, setText] = useState("");
  const [asking, setAsking] = useState(false);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function run() {
    if (!choice) return;
    setPending(true);
    setError(null);
    const result = await voidAssessment({
      recordId,
      reasonKind: choice,
      reason: choice === "other" ? text : null,
      idempotencyKey: crypto.randomUUID(),
    });
    setPending(false);
    if (!result.ok) {
      setAsking(false);
      setError(result.error);
      return;
    }
    onClose();
    router.refresh();
  }

  return (
    <div data-testid="assessment-void" className="grid gap-1">
      {asking ? (
        <ConfirmStep
          sentence={VOID_CONFIRM_SENTENCE}
          actionLabel={VOID_SUBMIT_LABEL}
          pending={pending}
          onConfirm={run}
          onCancel={() => setAsking(false)}
          testId="assessment-void-confirm"
        />
      ) : (
        <VoidReasonForm
          idBase={`void-${recordId}`}
          choice={choice}
          text={text}
          pending={pending}
          onChoice={setChoice}
          onText={setText}
          onSubmit={() => setAsking(true)}
          onCancel={onClose}
        />
      )}
      {/* UX2-30 (3) (UXR-58): the /team screen's one error line, merged in from recovery/main. */}
      <ErrorText message={error} testId="assessment-void-error" />
    </div>
  );
}
