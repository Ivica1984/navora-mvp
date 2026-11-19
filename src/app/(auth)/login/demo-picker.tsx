"use client";

import { useActionState } from "react";
import { demoSignIn } from "@/features/auth/actions";
import type { DemoPersona } from "@/features/auth/demo-login";
import type { SignInState } from "@/features/auth/schema";

const initialState: SignInState = { error: null };

// DEMO1 (ADR-212): staging only. One button per synthetic seed person; the server picks the account by key.
export default function DemoPicker({ personas }: { personas: readonly DemoPersona[] }) {
  const [state, formAction, isPending] = useActionState(demoSignIn, initialState);

  return (
    <section aria-labelledby="demo-heading" data-testid="demo-picker" className="mt-8 border-t border-[#d8e0db] pt-6">
      <h2 id="demo-heading" className="m-0 text-lg font-semibold">Ansehen als …</h2>
      <p className="text-secondary mb-4 mt-1 text-sm leading-relaxed">
        Nur Staging · synthetische Daten · keine echten Personen.
      </p>
      <form action={formAction} className="grid gap-3">
        {personas.map((p) => (
          <button
            key={p.key}
            type="submit"
            name="persona"
            value={p.key}
            disabled={isPending}
            data-testid={`demo-${p.key}`}
            className="min-h-11 rounded-2xl border border-[#d8e0db] bg-white px-4 py-3 text-left hover:border-[#16392d] disabled:cursor-not-allowed"
          >
            <span className="block font-semibold">{p.title}</span>
            <span className="text-secondary block text-sm">{p.description}</span>
          </button>
        ))}
      </form>
      {isPending && <p className="mt-3 text-sm">Anmeldung läuft …</p>}
      {state.error && (
        <p role="alert" className="mt-3 text-sm text-red-800">{state.error}</p>
      )}
    </section>
  );
}
