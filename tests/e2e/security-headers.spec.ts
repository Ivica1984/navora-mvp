import { expect, test } from "@playwright/test";

// T11 / SR-13: security headers, per-request CSP nonce, and no CSP violations
// while using the app. Runs after auth.spec.ts (alphabetical, single worker).

test("baseline security headers on a public page", async ({ request }) => {
  const response = await request.get("/login");
  const h = response.headers();

  expect(h["x-powered-by"]).toBeUndefined();
  expect(h["x-frame-options"]).toBe("DENY");
  expect(h["x-content-type-options"]).toBe("nosniff");
  expect(h["referrer-policy"]).toBe("same-origin");
  expect(h["strict-transport-security"]).toContain("max-age=");
  expect(h["permissions-policy"]).toContain("geolocation=()");

  const csp = h["content-security-policy"];
  expect(csp).toMatch(/script-src 'self' 'nonce-[^']+' 'strict-dynamic'/);
  expect(csp).toContain("frame-ancestors 'none'");
  expect(csp).not.toMatch(/script-src[^;]*'unsafe-inline'/);
});

test("a fresh nonce for every request", async ({ request }) => {
  const nonce = async () =>
    (await request.get("/login")).headers()["content-security-policy"].match(/'nonce-([^']+)'/)?.[1];
  const [a, b] = [await nonce(), await nonce()];
  expect(a).toBeTruthy();
  expect(a).not.toBe(b);
});

test("redirects to /login also carry the CSP", async ({ request }) => {
  const response = await request.get("/operations", { maxRedirects: 0 });
  expect(response.status()).toBe(307);
  expect(response.headers()["content-security-policy"]).toContain("frame-ancestors 'none'");
});

test("the app works under the CSP: no violations while signing in and navigating", async ({ page }) => {
  const violations: string[] = [];
  page.on("console", (msg) => {
    if (/Content Security Policy|Refused to (execute|load|apply)/i.test(msg.text())) {
      violations.push(msg.text());
    }
  });
  page.on("pageerror", (err) => violations.push(`pageerror: ${err.message}`));

  await page.goto("/login");
  // All inline and external scripts carry the nonce Next.js applied.
  const scriptsWithoutNonce = await page.evaluate(
    () => Array.from(document.scripts).filter((s) => !s.nonce).length
  );
  expect(scriptsWithoutNonce).toBe(0);

  await page.getByLabel("E-Mail").fill("pflege.test@navora.test");
  await page.getByLabel("Passwort").fill("navora-local-only");
  await page.getByRole("button", { name: "Anmelden" }).click();
  // F1: a nurse lands in the field tool (Tailwind classes, client buttons) — also checked under the CSP.
  await expect(page).toHaveURL(/\/field$/);
  await expect(page.getByRole("navigation", { name: "Tag wechseln" })).toBeVisible();

  for (const path of ["/teams", "/visits", "/operations"]) {
    await page.goto(path);
    await page.waitForLoadState("networkidle");
  }
  // Client-side navigation and hydration work (sidebar link → client router).
  // UX1-4 (selector change only): /visits is no longer a menu item, so the check follows a nurse's menu item instead.
  await page.getByRole("navigation", { name: "Hauptmenü" }).getByRole("link", { name: "Meine Einstellungen" }).click();
  await expect(page).toHaveURL(/\/settings$/);
  await expect(page.getByRole("heading", { name: "Meine Einstellungen" })).toBeVisible();

  expect(violations, violations.join("\n")).toEqual([]);
});
