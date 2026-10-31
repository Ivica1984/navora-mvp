import { ENTRY_TITLE, emptyText, entryAuthorLabel, entryLines, entryQualificationMissing, ruleText, sourceText, type SinceLast } from "@/features/handover/rules";
import { QUALIFICATION_NOT_RECORDED_TEXT } from "@/features/field/authorship";

function formatDateTime(iso: string) {
  return new Intl.DateTimeFormat("de-CH", {
    timeZone: "Europe/Zurich", day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit", hourCycle: "h23",
  }).format(new Date(iso));
}

// HAND1: everything recorded about this client since the nurse was last here, oldest first, with its source.
// Open before the visit starts; collapsible, so a nurse who has read it gets on with the visit. No acknowledgement:
// starting the visit records what the section held (database trigger, migration 0033).
export default function SinceLastSection({ block, visitStatus }: { block: SinceLast | undefined; visitStatus: string | null }) {
  if (!block) return null;
  const beforeStart = visitStatus === "planned" || visitStatus === "on_the_way";
  const count = block.entries.length;
  return (
    <details
      open={beforeStart}
      aria-label="Seit deinem letzten Einsatz"
      data-testid="since-last"
      className="mt-3 rounded-xl border-l-4 border-amber-500 bg-amber-50 p-3 text-sm"
    >
      <summary className="flex min-h-11 cursor-pointer items-center font-bold text-amber-900">
        Seit deinem letzten Einsatz{count > 0 ? ` (${count})` : ""}
      </summary>
      <p data-testid="since-last-rule" className="text-xs text-amber-900/80">{ruleText(block.rule, block.sinceDate, block.lookback)}</p>
      {count === 0 ? (
        <p className="mt-2">{emptyText(block.rule, block.sinceDate)}</p>
      ) : (
        <ol className="mt-2 grid gap-3">
          {block.entries.map((entry) => {
            const source = sourceText(entry.sourceVisitDate, entry.sourceVisitStart);
            return (
              <li key={entry.id} data-kind={entry.kind} className="border-t border-amber-900/10 pt-2 first:border-t-0 first:pt-0">
                <p className="font-semibold">{ENTRY_TITLE[entry.kind] ?? entry.kind}</p>
                {entryLines(entry.kind, entry.detail).map((line, i) => (
                  <p key={i} className={i === 0 && entry.kind === "observation" ? "whitespace-pre-wrap" : ""}>{line}</p>
                ))}
                {entryQualificationMissing(entry) && (
                  <p data-testid="handover-qualification-marker" className="text-xs text-stone-700">{QUALIFICATION_NOT_RECORDED_TEXT}</p>
                )}
                <p className="text-xs text-secondary">
                  <span data-testid="handover-author">{entryAuthorLabel(entry)}</span> · {formatDateTime(entry.at)}
                  {source ? ` · ${source}` : ""}
                </p>
              </li>
            );
          })}
        </ol>
      )}
    </details>
  );
}
