import { requireUser } from "@/lib/auth/session";
import { signOut } from "@/features/auth/actions";
import { ACCESS_ENDED_MESSAGE, parseAccessState } from "@/features/auth/access-state";
import { errorFields, logEvent } from "@/lib/log";

// Second guard after the proxy: no protected route renders without a valid
// session. Queries and commands check again themselves (ADR-017).
export default async function ProtectedLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const { supabase } = await requireUser();

  // LEAVE1-6 (ADR-088): a person whose access ended sees one notice on every route, with no client data, names or
  // counts. The database already returns her nothing and refuses every command (LEAVE1-3); this only replaces the page.
  const { data, error } = await supabase.rpc("my_access_state");
  if (error) logEvent("warn", "auth.access_state_failed", errorFields(error));
  if (parseAccessState(error ? null : data).ended) {
    return (
      <main className="grid min-h-screen place-items-center bg-stone-50 p-4">
        <section
          aria-label="Zugang beendet"
          data-testid="access-ended"
          className="grid max-w-md gap-4 rounded-2xl border border-stone-300 bg-white p-6 text-center"
        >
          <p className="text-lg font-semibold text-stone-900">{ACCESS_ENDED_MESSAGE}</p>
          <form action={signOut}>
            <button type="submit" className="min-h-11 rounded-lg border border-stone-400 px-4 text-sm font-semibold">
              Abmelden
            </button>
          </form>
        </section>
      </main>
    );
  }

  return children;
}
