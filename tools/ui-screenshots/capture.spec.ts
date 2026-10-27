import { test, type Browser } from "@playwright/test";
import { mkdirSync, writeFileSync } from "node:fs";

// Temporary: one screenshot per screen and width, signed in as the seeded synthetic users.
const PASSWORD = "navora-local-only";
const OUT = "ui-screenshots";
const PHONE = { width: 390, height: 844 };
const DESKTOP = { width: 1440, height: 900 };

type Shot = { name: string; user: string; route: string; size: { width: number; height: number } };
const shots: Shot[] = [
  { name: "field-phone", user: "pflege.test@navora.test", route: "/field", size: PHONE },
  { name: "field-desktop", user: "pflege.test@navora.test", route: "/field", size: DESKTOP },
  { name: "work-phone", user: "pflege.test@navora.test", route: "/work", size: PHONE },
  { name: "work-desktop", user: "pflege.test@navora.test", route: "/work", size: DESKTOP },
  { name: "team-desktop", user: "pflege.test@navora.test", route: "/team", size: DESKTOP },
  { name: "team-phone", user: "pflege.test@navora.test", route: "/team", size: PHONE },
  { name: "analytics-team-desktop", user: "pflege.test@navora.test", route: "/analytics", size: DESKTOP },
  { name: "operations-desktop", user: "ops.test@navora.test", route: "/operations", size: DESKTOP },
  { name: "intake-desktop", user: "ops.test@navora.test", route: "/intake", size: DESKTOP },
  { name: "analytics-desktop", user: "coach.test@navora.test", route: "/analytics", size: DESKTOP },
  { name: "admin-desktop", user: "admin.test@navora.test", route: "/admin", size: DESKTOP },
  { name: "admin-as-nurse-desktop", user: "pflege.test@navora.test", route: "/admin", size: DESKTOP },
  { name: "settings-phone", user: "pflege.test@navora.test", route: "/settings", size: PHONE },
];

async function capture(browser: Browser, s: Shot) {
  const context = await browser.newContext({ viewport: s.size, locale: "de-CH", timezoneId: "Europe/Zurich" });
  const page = await context.newPage();
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(s.user);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((u) => !u.pathname.startsWith("/login"), { timeout: 30_000 });
  const landing = new URL(page.url()).pathname;
  await page.goto(s.route);
  await page.waitForLoadState("load");
  await page.waitForTimeout(3000);
  await page.screenshot({ path: `${OUT}/${s.name}.png`, fullPage: true });
  await page.screenshot({ path: `${OUT}/${s.name}-top.png`, fullPage: false });
  const headings = await page.locator("h1, h2, h3").allInnerTexts();
  const sections = await page.locator("section[aria-label]").evaluateAll((els) => els.map((e) => e.getAttribute("aria-label")));
  const buttons = await page.getByRole("button").allInnerTexts();
  const height = await page.evaluate(() => document.documentElement.scrollHeight);
  const meta = { ...s, landing, finalUrl: new URL(page.url()).pathname, headings, sections, buttons: [...new Set(buttons.map((b) => b.trim()).filter(Boolean))], height };
  writeFileSync(`${OUT}/${s.name}.json`, JSON.stringify(meta, null, 2));
  await context.close();
}

test.describe.configure({ mode: "serial" });
for (const s of shots) {
  test(s.name, async ({ browser }) => {
    mkdirSync(OUT, { recursive: true });
    await capture(browser, s);
  });
}
