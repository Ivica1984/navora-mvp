import { describe, expect, it } from "vitest";
import { buildContentSecurityPolicy, createNonce, STATIC_SECURITY_HEADERS } from "@/lib/security/csp";

const directives = (csp: string) =>
  Object.fromEntries(
    csp.split("; ").map((d) => {
      const [name, ...values] = d.split(" ");
      return [name, values];
    })
  );

describe("buildContentSecurityPolicy (production)", () => {
  const csp = directives(buildContentSecurityPolicy("abc123", { dev: false }));

  it("allows scripts only by nonce (no unsafe-inline / unsafe-eval)", () => {
    expect(csp["script-src"]).toEqual(["'self'", "'nonce-abc123'", "'strict-dynamic'"]);
    expect(csp["script-src"]).not.toContain("'unsafe-inline'");
    expect(csp["script-src"]).not.toContain("'unsafe-eval'");
  });

  it("forbids framing, plugins and foreign form targets", () => {
    expect(csp["frame-ancestors"]).toEqual(["'none'"]);
    expect(csp["object-src"]).toEqual(["'none'"]);
    expect(csp["form-action"]).toEqual(["'self'"]);
    expect(csp["base-uri"]).toEqual(["'self'"]);
  });

  it("allows a service worker from its own origin only (SIG2)", () => {
    expect(csp["worker-src"]).toEqual(["'self'"]);
  });

  it("lets the browser connect only to its own origin (no Supabase from the browser)", () => {
    expect(csp["connect-src"]).toEqual(["'self'"]);
  });
});

describe("buildContentSecurityPolicy (development)", () => {
  it("adds eval and websocket only in dev", () => {
    const csp = directives(buildContentSecurityPolicy("n", { dev: true }));
    expect(csp["script-src"]).toContain("'unsafe-eval'");
    expect(csp["connect-src"]).toContain("ws:");
  });
});

describe("createNonce", () => {
  it("is unique per call and safe for a header value", () => {
    const a = createNonce();
    const b = createNonce();
    expect(a).not.toBe(b);
    expect(a).toMatch(/^[A-Za-z0-9+/=]{24,}$/);
  });
});

describe("STATIC_SECURITY_HEADERS", () => {
  it("contains the baseline headers", () => {
    const keys = STATIC_SECURITY_HEADERS.map((h) => h.key);
    for (const key of [
      "Strict-Transport-Security",
      "X-Content-Type-Options",
      "X-Frame-Options",
      "Referrer-Policy",
      "Permissions-Policy",
    ]) {
      expect(keys).toContain(key);
    }
  });
});
