"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { mapLegacyRegion } from "@/features/regions/commands";
import type { UnmappedRegionPanel } from "@/features/regions/queries";
import { UNMAPPED_REGIONS_HEADING, UNMAPPED_REGIONS_INTRO } from "@/features/regions/rules";

const field = "min-h-11 w-full min-w-0 rounded-lg border border-stone-300 bg-white px-3";

/**
 * B1.1-1 (Δ1, ADR-186): region texts in use that are not on the list. Operations assigns each to a list entry by hand;
 * the database writes the audit row (who, when, from, to). Until then the old text keeps matching as before.
 */
export default function UnmappedRegionsPanel({ data }: { data: UnmappedRegionPanel }) {
  if (data.rows.length === 0) return null;
  return (
    <section aria-label={UNMAPPED_REGIONS_HEADING} className="grid gap-2 rounded-xl border border-stone-200 bg-white p-4 shadow-sm">
      <h2 className="text-lg font-bold">{UNMAPPED_REGIONS_HEADING} ({data.rows.length})</h2>
      <p className="text-sm text-secondary">{UNMAPPED_REGIONS_INTRO}</p>
      <ul className="grid gap-2">
        {data.rows.map((r) => (
          <li key={r.legacy_value}>
            <UnmappedRow data={data} row={r} />
          </li>
        ))}
      </ul>
    </section>
  );
}

function UnmappedRow({ data, row }: { data: UnmappedRegionPanel; row: UnmappedRegionPanel["rows"][number] }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  return (
    <form
      aria-label={`Region zuordnen: ${row.legacy_value}`}
      className="grid gap-2 rounded-lg border border-stone-200 p-3 text-sm md:grid-cols-[minmax(0,1fr)_minmax(0,14rem)_auto] md:items-end"
      onSubmit={(e) => {
        e.preventDefault();
        const regionId = String(new FormData(e.currentTarget).get("regionId") ?? "");
        setError(null);
        start(async () => {
          const result = await mapLegacyRegion({
            organizationId: data.organizationId, legacyValue: row.legacy_value, regionId, idempotencyKey: crypto.randomUUID(),
          });
          if (result.ok) router.refresh();
          else setError(result.error);
        });
      }}
    >
      <p className="break-words">
        <span className="font-semibold">{row.legacy_value}</span>
        <span className="block text-secondary">
          {row.teams} Teams · {row.cases} Fälle · {row.referrals} Anfragen · {row.open_searches} offene Teamsuchen
        </span>
      </p>
      <label className="grid gap-1 text-xs font-semibold">
        Region aus der Liste
        <select name="regionId" required defaultValue="" className={field}>
          <option value="" disabled>bitte wählen</option>
          {data.regions.map((g) => <option key={g.id} value={g.id}>{g.name}</option>)}
        </select>
      </label>
      <button type="submit" disabled={pending} className="min-h-11 rounded-lg bg-emerald-800 px-4 font-semibold text-white disabled:opacity-60">
        Zuordnen
      </button>
      {error && <p role="alert" className="font-semibold text-rose-800 md:col-span-3">{error}</p>}
    </form>
  );
}
