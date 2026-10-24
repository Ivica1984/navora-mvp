import { expect, test, type Page } from "@playwright/test";

// SIG2 (migration 0062, ADR-076): delivery outside the app. No push service is reached from CI: the database records
// no DPF entry (fail closed), so the channel cannot be switched on here; pgTAP 064 tests the delivery rules with the
// entry set inside a test transaction. Synthetic local-only accounts from supabase/seed.sql.
const PASSWORD = "navora-local-only";

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

test("SIG2-1: the member reads the information before any switch; with the channel off she is told so", async ({ page }) => {
  await signIn(page, "pflege.test@navora.test");
  await page.goto("/settings");
  const section = page.getByRole("region", { name: "Benachrichtigung ausserhalb der App" });
  await expect(section.getByTestId("push-status")).toHaveText("Benachrichtigung ausserhalb der App: nicht aktiv");
  const info = section.getByTestId("push-information");
  await expect(info).toContainText("NAVORA: Ein Sicherheitssignal wartet auf dich.");
  await expect(info).toContainText("Keine Klientendaten");
  await expect(info).toContainText("Ausschalten");
  await expect(section.getByTestId("push-channel-off")).toBeVisible();
  await expect(section.getByRole("button", { name: "Auf diesem Gerät einschalten" })).toHaveCount(0);
});

test("SIG2-3 / SIG2-6: the administrator sees the vendors as recorded; without a DPF entry the channel stays off", async ({ page }) => {
  await signIn(page, "admin.test@navora.test");
  await page.goto("/admin");
  const section = page.getByRole("region", { name: "Benachrichtigung ausserhalb der App" });
  await expect(section.getByTestId("push-vendor")).toHaveCount(2);
  await expect(section.getByTestId("push-vendor").first()).toContainText("nicht freigegeben");
  await expect(section.getByTestId("push-channel")).toHaveText("Ausgeschaltet");
  await expect(section.getByRole("button", { name: "Einschalten" })).toBeDisabled();
  // Watched hours: refused when invalid, saved when valid, shown again after a reload.
  await section.getByLabel("Überwachte Zeiten Mo").fill("20:00-07:00");
  await section.getByRole("button", { name: "Zeiten speichern" }).click();
  await expect(section.getByTestId("command-error")).toContainText("Mo:");
  await section.getByLabel("Überwachte Zeiten Mo").fill("07:00-20:00");
  await section.getByRole("button", { name: "Zeiten speichern" }).click();
  await expect(section.getByRole("status")).toHaveText("Gespeichert.");
  await page.reload();
  await expect(page.getByRole("region", { name: "Benachrichtigung ausserhalb der App" }).getByLabel("Überwachte Zeiten Mo")).toHaveValue("07:00-20:00");
  // Leave the seed as it was for other files.
  await page.getByRole("region", { name: "Benachrichtigung ausserhalb der App" }).getByLabel("Überwachte Zeiten Mo").fill("");
  await page.getByRole("region", { name: "Benachrichtigung ausserhalb der App" }).getByRole("button", { name: "Zeiten speichern" }).click();
  await expect(page.getByRole("region", { name: "Benachrichtigung ausserhalb der App" }).getByRole("status")).toHaveText("Gespeichert.");
});

test("SIG2-9: the sender's entry point refuses a request without the secret; the service worker is served", async ({ request }) => {
  const res = await request.post("/api/push/dispatch");
  expect(res.status()).toBe(401);
  const wrong = await request.post("/api/push/dispatch", { headers: { Authorization: "Bearer not-the-secret" } });
  expect(wrong.status()).toBe(401);
  const sw = await request.get("/sw.js");
  expect(sw.status()).toBe(200);
  expect(await sw.text()).toContain("NAVORA: Ein Sicherheitssignal wartet auf dich.");
});
