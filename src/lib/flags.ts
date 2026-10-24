// Feature flags read at build/request time. Default: everything optional is off.

/**
 * Legacy demo pages (/matching, /partners) show hard-coded, invented data and a
 * DEPRECATED client-side matching score (ADR-006, SR-15, SR-16). Off unless
 * explicitly enabled for a local demo.
 */
export const demoPagesEnabled =
  process.env.NEXT_PUBLIC_FEATURE_DEMO_PAGES === "true";
