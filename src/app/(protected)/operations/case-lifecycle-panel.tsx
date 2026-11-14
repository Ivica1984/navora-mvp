"use client";

import { useState } from "react";
import CaseLifecycleControls, { ClosedCases } from "../team/case-lifecycle";
import type { CaseLifecycle } from "@/features/lifecycle/queries";
import { REASON_LABEL } from "@/features/lifecycle/rules";

/** C1 (PO addendum): Operations closes a case with a reason and reopens a closed one. Pausing stays with the team. */
export default function CaseLifecyclePanel({ items }: { items: CaseLifecycle[] }) {
  const [query, setQuery] = useState("");
  const open = items.filter((c) => c.lifecycle !== "closed")
    .filter((c) => !query || (c.client_name ?? "").toLowerCase().includes(query.toLowerCase()));
  return (
    <section aria-label="Fallstatus (Operations)" data-testid="ops-case-lifecycle" className="grid gap-3 rounded-2xl border border-stone-200 bg-white p-5">
      <h3 className="text-lg font-bold">Fallstatus</h3>
      <label className="grid gap-1 text-xs font-semibold">
        Fall suchen
        <input value={query} onChange={(e) => setQuery(e.target.value)} className="min-h-10 rounded-lg border border-stone-300 px-2" />
      </label>
      <ul className="grid gap-2">
        {open.slice(0, 20).map((c) => (
          <li key={c.case_id}>
            <article aria-label={`Fallstatus ${c.client_name ?? ""}`} className="rounded-xl border border-stone-200 p-3 text-sm">
              <p className="font-semibold">{c.client_name ?? "Klient:in"} · {c.team_name ?? "ohne Team"} ·{" "}
                {c.lifecycle === "paused" ? `pausiert (${REASON_LABEL[c.last_reason ?? ""] ?? c.last_reason})` : "aktiv"}</p>
              <CaseLifecycleControls item={c} operations />
            </article>
          </li>
        ))}
      </ul>
      <ClosedCases items={items.filter((c) => c.lifecycle === "closed")} />
    </section>
  );
}
