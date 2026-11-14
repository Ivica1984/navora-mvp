// Supabase connection settings. Server-side only (ADR-017): these variables are
// deliberately NOT prefixed with NEXT_PUBLIC_, so Next.js never inlines them into
// browser bundles. The app has no Supabase client in the browser.

export type SupabaseEnv = { url: string; key: string };

export function getSupabaseEnv(): SupabaseEnv {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_ANON_KEY;

  if (!url || !key) {
    throw new Error(
      "SUPABASE_URL und SUPABASE_ANON_KEY müssen gesetzt sein (siehe .env.example)."
    );
  }

  return { url, key };
}
