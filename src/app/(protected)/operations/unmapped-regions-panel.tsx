"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import ConfirmStep from "@/app/(protected)/admin/confirm-step";
import { mapLegacyRegion } from "@/features/regions/commands";
import type { UnmappedRegionPanel } from "@/features/regions/queries";
import {
  MAP_REGION_CONFIRM_LABEL,
  UNMAPPED_REGIONS_HEADING,
  UNMAPPED_REGIONS_INTRO,
  mapRegionConfirmSentence,
  mapRegionDoneText,
  regionCountLine,
} from "@/features/regions/rules";

const field = "min-h-11 w-full min-w-0 rounded-lg border border-stone-300 bg-white px-3";

/**
 * B1.1-1 (Δ1, ADR-186): region texts in use that are not on the list. Operations assigns each to a list entry by hand;
 * the database writes the audit row (who, when, from, to). Until then the old text keeps matching as before.
 * Amendment 04:30 (uxa UXR-184): «Zuordnen» first opens an in-place confirming step whose sentence comes from the row
 * counts; «Abbrechen» runs nothing. After success the result line stays, also when no row is left.
 */
export default function UnmappedRegionsPanel({ data }: { data: UnmappedRegionPanel }) {
  const [done, setDone] = useState<string[]>([]);
  if (data.rows.length === 0 && done.length === 0) return null;
  return (
    <section aria-label={UNMAPPED_REGIONS_HEADING} className="grid gap-2 rounded-xl border border-stone-200 bg-white p-4 shadow-sm">
      <h2 className="text-lg font-bold">{UNMAPPED_REGIONS_HEADING} ({data.rows.length})</h2>
      {done.length > 0 && (
        <div role="status" data-testid="region-mapped" className="grid gap-1 text-sm font-semibold text-emerald-900">
          {done.map((d) => <p key={d}>{d}</p>)}
        </div>
      )}
      {data.rows.length > 0 && <p className="text-sm text-secondary">{UNMAPPED_REGIONS_INTRO}</p>}
      <ul className="grid gap-2">
        {data.rows.map((r) => (
          <li key={r.legacy_value}>
            <UnmappedRow data={data} row={r} onDone={(text) => setDone((d) => (d.includes(text) ? d : [...d, text]))} />
          </li>
        ))}
      </ul>
    </section>
  );
}

function UnmappedRow({ data, row, onDone }: {
  data: UnmappedRegionPanel;
  row: UnmappedRegionPanel["rows"][number];
  onDone: (text: string) => void;
}) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [regionId, setRegionId] = useState("");
  // One key per opened confirming step: a repeated tap on the action is a duplicate, never a second mapping.
  const [confirm, setConfirm] = useState<{ regionId: string; key: string } | null>(null);
  const target = data.regions.find((g) => g.id === (confirm?.regionId ?? regionId));
  return (
    <form
      aria-label={`Region zuordnen: ${row.legacy_value}`}
      className="grid gap-2 rounded-lg border border-stone-200 p-3 text-sm md:grid-cols-[minmax(0,1fr)_minmax(0,14rem)_auto] md:items-end"
      onSubmit={(e) => {
        e.preventDefault();
        setError(null);
        if (regionId) setConfirm({ regionId, key: crypto.randomUUID() });
      }}
    >
      <p className="break-words">
        <span className="font-semibold">{row.legacy_value}</span>
        <span className="block text-secondary">{regionCountLine(row)}</span>
      </p>
      <label className="grid gap-1 text-xs font-semibold">
        Region aus der Liste
        <select name="regionId" required value={regionId} disabled={confirm !== null}
          onChange={(e) => setRegionId(e.target.value)} className={field}>
          <option value="" disabled>bitte wählen</option>
          {data.regions.map((g) => <option key={g.id} value={g.id}>{g.name}</option>)}
        </select>
      </label>
      {confirm === null && (
        <button type="submit" disabled={pending} className="min-h-11 rounded-lg bg-emerald-800 px-4 font-semibold text-white disabled:opacity-60">
          {MAP_REGION_CONFIRM_LABEL}
        </button>
      )}
      {confirm !== null && target && (
        <div className="md:col-span-3">
          <ConfirmStep
            testId="region-map-confirm"
            sentence={mapRegionConfirmSentence(row.legacy_value, target.name, row)}
            actionLabel={MAP_REGION_CONFIRM_LABEL}
            pending={pending}
            onCancel={() => setConfirm(null)}
            onConfirm={() => {
              start(async () => {
                const result = await mapLegacyRegion({
                  organizationId: data.organizationId, legacyValue: row.legacy_value, regionId: confirm.regionId,
                  idempotencyKey: confirm.key,
                });
                if (result.ok) {
                  onDone(mapRegionDoneText(row.legacy_value, target.name));
                  router.refresh();
                } else {
                  setConfirm(null);
                  setError(result.error);
                }
              });
            }}
          />
        </div>
      )}
      {error && <p role="alert" className="font-semibold text-rose-800 md:col-span-3">{error}</p>}
    </form>
  );
}
