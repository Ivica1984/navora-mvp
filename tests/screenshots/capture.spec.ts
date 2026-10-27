import { mkdirSync } from "node:fs";
import { expect, test, type Page } from "@playwright/test";
import { navItemsFor, type NavAccess } from "@/lib/auth/nav";

// UX1-14 (ADR-103): every protected route on the synthetic seed, at 390 × 844 and 1440 × 900, signed in with each
// role that may open it. The routes per person come from the same table as the menu (src/lib/auth/nav.ts), plus the
// pages that are not menu items: /team for team members and the first-MVP pages /teams and /visits (every member,
// until UX2 decides them). Fails only on a render error (HTTP status >= 500, an uncaught page error, the Next.js error
// page); a visual difference is `uxa`'s review, not a test result. Synthetic local-only accounts from supabase/seed.sql.
const PASSWORD = "navora-local-only";
const OUT = "ui-screenshots";

const VIEWPORTS = [
  { name: "390x844", width: 390, height: 844 },
  { name: "1440x900", width: 1440, height: 900 },
] as const;

// The seed people and their memberships (supabase/seed.sql). The menu itself is checked against the database in
// tests/unit/nav-access.test.ts and per person in tests/e2e/ux1.spec.ts.
const PEOPLE: ReadonlyArray<{ role: string; email: string; access: NavAccess }> = [
  { role: "nurse", email: "pflege.test@navora.test", access: { roles: ["nurse"], inTeam: true } },
  { role: "coach", email: "coach.test@navora.test", access: { roles: ["coach"], inTeam: false } },
  { role: "operations", email: "ops.test@navora.test", access: { roles: ["operations"], inTeam: false } },
  { role: "admin", email: "admin.test@navora.test", access: { roles: ["admin"], inTeam: false } },
];

function routesFor(access: NavAccess): string[] {
  const menu = navItemsFor(access).map((item) => item.href);
  return [...menu, ...(access.inTeam ? ["/team"] : []), "/teams", "/visits"];
}

const fileName = (role: string, route: string, viewport: string, suffix = "") =>
  `${OUT}/${role}${route.replace(/\//g, "_")}${suffix}_${viewport}.png`;

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

async function capture(page: Page, route: string, file: string, errors: string[]) {
  const response = await page.goto(route);
  const status = response?.status() ?? 0;
  expect(status, `${route}: HTTP ${status}`).toBeLessThan(500);
  await page.waitForLoadState("networkidle");
  // The Next.js error page ("Application error" / "This page couldn't load") is a render error.
  await expect(page.getByText(/Application error|This page couldn.t load|Internal Server Error/), route).toHaveCount(0);
  await page.screenshot({ path: file, fullPage: true });
  expect(errors, `${route}: uncaught page errors`).toEqual([]);
}

test.beforeAll(() => {
  mkdirSync(OUT, { recursive: true });
});

for (const viewport of VIEWPORTS) {
  test(`login page at ${viewport.name}`, async ({ page }) => {
    const errors: string[] = [];
    page.on("pageerror", (err) => errors.push(err.message));
    await page.setViewportSize({ width: viewport.width, height: viewport.height });
    await capture(page, "/login", fileName("public", "/login", viewport.name), errors);
  });

  for (const person of PEOPLE) {
    test(`${person.role}: every route she may open at ${viewport.name}`, async ({ page }) => {
      test.setTimeout(120_000);
      const errors: string[] = [];
      page.on("pageerror", (err) => errors.push(err.message));
      await page.setViewportSize({ width: viewport.width, height: viewport.height });
      await signIn(page, person.email);
      for (const route of routesFor(person.access)) {
        await capture(page, route, fileName(person.role, route, viewport.name), errors);
      }
    });
  }
}

// UX1-19 (ii), UXR-8 (ADR-105): one capture of /field with the browser in dark mode. :root declares
// `color-scheme: light` until a dark theme is designed, so the page must look like the light capture.
test.describe("dark browser setting", () => {
  test.use({ colorScheme: "dark" });

  test("nurse: /field at 390x844 with colorScheme dark", async ({ page }) => {
    const errors: string[] = [];
    page.on("pageerror", (err) => errors.push(err.message));
    await page.setViewportSize({ width: 390, height: 844 });
    await signIn(page, "pflege.test@navora.test");
    await capture(page, "/field", fileName("nurse", "/field", "390x844", "_dark"), errors);
  });
});
