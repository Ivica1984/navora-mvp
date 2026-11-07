import { EVALUATOR_DOWN_CONSEQUENCE, EVALUATOR_RUNNING, evaluatorDown, evaluatorDownText, type EvaluatorHealth } from "@/features/signals/rules";

// SIG2-11 (0064, ADR-078): "Signalprüfung läuft nicht" on /operations and /admin when the scheduled evaluator of the
// organisation has not run for more than 5 minutes. `showRunning` adds the quiet "läuft" line (/admin).
export default function EvaluatorHealthNotice({ health, showRunning = false }: { health: EvaluatorHealth[]; showRunning?: boolean }) {
  const down = evaluatorDown(health);
  if (down.length === 0) {
    return showRunning && health.length > 0
      ? <p data-testid="signal-evaluator" className="text-sm text-emerald-900">{EVALUATOR_RUNNING}.</p>
      : null;
  }
  return (
    <div role="alert" data-testid="signal-evaluator" className="grid gap-1 rounded-xl border border-rose-300 bg-rose-50 p-3 text-sm text-rose-900">
      {down.map((r) => <p key={r.organization_id} className="font-bold">{evaluatorDownText(r)}</p>)}
      <p>{EVALUATOR_DOWN_CONSEQUENCE}</p>
    </div>
  );
}
