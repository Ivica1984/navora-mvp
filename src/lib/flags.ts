// Feature flags read at build/request time. Default: everything optional is off.

/**
 * Legacy demo page (/partners) shows hard-coded, invented data (ADR-006, SR-15, SR-16).
 * Off unless explicitly enabled for a local demo. The /matching demo and its
 * client-side scorer were removed by IPA1-4 (ADR-099).
 */
export const demoPagesEnabled =
  process.env.NEXT_PUBLIC_FEATURE_DEMO_PAGES === "true";
