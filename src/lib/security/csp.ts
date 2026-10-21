// Content-Security-Policy (T11, SR-13). Pure module — unit-tested.
//
// Next.js App Router delivers page data in inline <script> tags, so a static
// policy would need 'unsafe-inline' for scripts and give little XSS protection.
// Instead the proxy issues a fresh nonce per request; Next.js reads it from the
// request's CSP header and applies it to its own scripts. 'strict-dynamic' lets
// those trusted scripts load the app chunks.
//
// style-src keeps 'unsafe-inline' because the legacy UI is built from inline
// style attributes (TD-01). Style injection is far less dangerous than script
// injection; remove it when the design system replaces inline styles.
//
// connect-src is 'self' only: the browser never talks to Supabase (ADR-017).

export function createNonce(): string {
  return btoa(crypto.randomUUID());
}

export function buildContentSecurityPolicy(nonce: string, options: { dev: boolean }): string {
  const scriptSrc = ["'self'", `'nonce-${nonce}'`, "'strict-dynamic'"];
  const connectSrc = ["'self'"];

  if (options.dev) {
    scriptSrc.push("'unsafe-eval'"); // React dev tooling only
    connectSrc.push("ws:"); // hot reload only
  }

  const directives: Record<string, string[]> = {
    "default-src": ["'self'"],
    "script-src": scriptSrc,
    "style-src": ["'self'", "'unsafe-inline'"],
    "img-src": ["'self'", "data:", "blob:"],
    "font-src": ["'self'"],
    "connect-src": connectSrc,
    "object-src": ["'none'"],
    "base-uri": ["'self'"],
    "form-action": ["'self'"],
    "frame-ancestors": ["'none'"],
    "manifest-src": ["'self'"],
  };

  return Object.entries(directives)
    .map(([name, values]) => `${name} ${values.join(" ")}`)
    .join("; ");
}

/** Headers that are the same for every response (set in next.config.ts). */
export const STATIC_SECURITY_HEADERS: ReadonlyArray<{ key: string; value: string }> = [
  // Browsers ignore HSTS on plain http (local, CI); it takes effect on https hosts.
  { key: "Strict-Transport-Security", value: "max-age=63072000; includeSubDomains" },
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "X-Frame-Options", value: "DENY" },
  { key: "Referrer-Policy", value: "same-origin" },
  {
    key: "Permissions-Policy",
    // Geolocation/camera stay off until the field tool needs them (M4) — then
    // enable only for 'self' with a documented purpose.
    value: "camera=(), microphone=(), geolocation=(), payment=(), usb=(), interest-cohort=()",
  },
  { key: "Cross-Origin-Opener-Policy", value: "same-origin" },
  { key: "X-DNS-Prefetch-Control", value: "off" },
];
