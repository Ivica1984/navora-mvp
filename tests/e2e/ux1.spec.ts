import { expect, test, type Page } from "@playwright/test";
import { CANCEL_CONSEQUENCE, HOLD_CONSEQUENCE } from "@/features/field/rules";
import { NOTICE_HEADINGS, NOTICE_LEAD } from "@/features/work/rules";

// UX1 parts (a) and (b) (ADR-103): phone width of /settings, /admin and /operations, and the menu by role.
// UX1 part (c) (ADR-104): the /field order and action hierarchy, the header menu on /field, /team and /work (UX1-20),
// and the scannable WORK1 notice (UX1-21).
// Synthetic local-only accounts from supabase/seed.sql:
//   pflege.test  nurse, Testteam Nord      coach.test  coach, no team
//   ops.test     operations, no team       admin.test  administrator of org A, no team
const PASSWORD = "navora-local-only";
const PHONE = { width: 390, height: 844 };

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

async function noHorizontalScroll(page: Page, path: string) {
  await page.goto(path);
  await page.waitForLoadState("networkidle");
  const width = await page.evaluate(() => document.documentElement.scrollWidth);
  expect(width, `${path}: scrollWidth ${width} at ${PHONE.width} px`).toBeLessThanOrEqual(PHONE.width);
}

/** The text of the last link or button inside a menu panel (UXR-11: "Abmelden" comes last). */
async function lastItemText(menu: ReturnType<Page["getByTestId"]>): Promise<string> {
  return menu.evaluate((root) => {
    const items = (Array.from(root.querySelectorAll("a, button")) as HTMLElement[]).filter((el) => el.offsetParent !== null);
    return (items[items.length - 1]?.textContent ?? "").trim();
  });
}

/** Texts and markers with which a page tells a person it is not for her (existing refusals, unchanged). */
async function expectNoRefusal(page: Page, path: string) {
  await expect(page.getByTestId("admin-denied"), path).toHaveCount(0);
  await expect(page.getByTestId("no-kpis"), path).toHaveCount(0);
  await expect(page.getByText(/vorbehalten/), path).toHaveCount(0);
  await expect(page.getByTestId("access-ended"), path).toHaveCount(0);
}

test.describe("UX1-1 / UX1-2: no horizontal scroll at 390 px", () => {
  test.use({ viewport: PHONE });

  test("a nurse on /settings: no sideways scroll, the menu is collapsed", async ({ page }) => {
    await signIn(page, "pflege.test@navora.test");
    await noHorizontalScroll(page, "/settings");
    // Below 768 px the side column is not shown; the menu is one closed control at the top.
    await expect(page.getByRole("complementary")).toHaveCount(0);
    const menu = page.getByTestId("mobile-menu");
    await expect(menu).toBeVisible();
    await expect(menu.getByRole("link")).toHaveCount(0);
    // UX1-20 / UXR-11 (ADR-104): "Abmelden" is not the bar's most prominent control: it is the last item inside "Menü",
    // which is at least 44 px high.
    await expect(page.getByRole("button", { name: "Abmelden" })).toHaveCount(0);
    const summary = await menu.locator("summary").boundingBox();
    expect(summary!.height).toBeGreaterThanOrEqual(44);
    await menu.locator("summary").click();
    await expect(menu.getByRole("link", { name: "Meine Einstellungen" })).toBeVisible();
    await expect(menu.getByRole("button", { name: "Abmelden" })).toBeVisible();
    expect(await lastItemText(menu)).toBe("Abmelden");
  });

  // UX1-2 (amended by po 2026-10-27 16:25 for UXR-10, #548): a nurse starting at /field (no goto("/settings")) reaches
  // /settings by the UX1-20 route and sees the SIG2 state. Deviation (ADR-103, unchanged): without a DPF entry the
  // channel is off in CI (as in push.spec), so the switch is not offered; the state she sees is the confirmed "not
  // active" with the reason, fully inside the page width.
  test("UX1-2: a nurse starting at /field reaches the push settings in two taps", async ({ page }) => {
    await signIn(page, "pflege.test@navora.test");
    await expect(page).toHaveURL(/\/field$/);
    const menu = page.getByTestId("header-menu");
    await menu.locator("summary").click();
    await menu.getByRole("link", { name: "Meine Einstellungen" }).click();
    await page.waitForURL(/\/settings$/);
    const section = page.getByRole("region", { name: "Benachrichtigung ausserhalb der App" });
    await expect(section.getByTestId("push-status")).toHaveText("Benachrichtigung ausserhalb der App: nicht aktiv");
    await expect(section.getByTestId("push-information")).toBeVisible();
    await expect(section.getByTestId("push-channel-off")).toBeVisible();
    const box = await section.boundingBox();
    expect(box).not.toBeNull();
    expect(box!.x).toBeGreaterThanOrEqual(0);
    expect(box!.x + box!.width).toBeLessThanOrEqual(PHONE.width);
  });

  test("an administrator on /admin and /operations", async ({ page }) => {
    await signIn(page, "admin.test@navora.test");
    await noHorizontalScroll(page, "/admin");
    await expect(page.getByRole("region", { name: "Mitglieder" })).toBeVisible();
    await noHorizontalScroll(page, "/operations");
    await expect(page.getByRole("region", { name: "Pflegeteams" })).toBeVisible();
  });

  test("operations and a coach on /operations", async ({ page }) => {
    await signIn(page, "ops.test@navora.test");
    await noHorizontalScroll(page, "/operations");
    await page.goto("/settings");
    // UX1-20 / UXR-11: "Abmelden" is the last item inside "Menü" on the phone.
    await page.getByTestId("mobile-menu").locator("summary").click();
    await page.getByRole("button", { name: "Abmelden" }).click();
    await page.waitForURL(/\/login$/);
    await signIn(page, "coach.test@navora.test");
    await noHorizontalScroll(page, "/operations");
  });
});

// UX1-3: the items each seed person sees (in order) are exactly the pages whose own check admits her.
const MENU: Record<string, { email: string; items: string[] }> = {
  nurse: {
    email: "pflege.test@navora.test",
    items: ["Mein Tag (mobil)", "Mein Arbeitstag", "KPI / Analytics", "Meine Einstellungen"],
  },
  coach: {
    email: "coach.test@navora.test",
    items: ["Operations Board", "Mein Arbeitstag", "KPI / Analytics", "Meine Einstellungen"],
  },
  operations: {
    email: "ops.test@navora.test",
    items: ["Operations Board", "Aufnahme", "Mein Arbeitstag", "KPI / Analytics", "Meine Einstellungen"],
  },
  admin: {
    email: "admin.test@navora.test",
    items: ["Operations Board", "Aufnahme", "Mein Arbeitstag", "KPI / Analytics", "Meine Einstellungen", "Administration"],
  },
};

for (const [role, { email, items }] of Object.entries(MENU)) {
  test(`UX1-3 / UX1-4: the ${role}'s menu shows only pages that admit her, and each opens without a refusal`, async ({ page }) => {
    await signIn(page, email);
    await page.goto("/settings");
    const menu = page.getByRole("navigation", { name: "Hauptmenü" });
    await expect(menu.getByRole("link")).toHaveText(items);
    // UX1-4: no item without a target; the first-MVP pages are not in the menu.
    await expect(page.getByText("Qualitätsmanagement")).toHaveCount(0);
    await expect(menu.locator('a[href="/teams"], a[href="/visits"]')).toHaveCount(0);

    const hrefs = await menu.getByRole("link").evaluateAll((links) => links.map((a) => a.getAttribute("href") ?? ""));
    for (const href of hrefs) {
      const response = await page.goto(href);
      expect(response?.status(), href).toBeLessThan(400);
      await page.waitForLoadState("networkidle");
      await expectNoRefusal(page, href);
    }
  });
}

test("UX1-5: a nurse who types /admin or /intake still gets the existing refusal", async ({ page }) => {
  await signIn(page, "pflege.test@navora.test");
  await page.goto("/admin");
  await expect(page.getByTestId("admin-denied")).toHaveText("Diese Seite ist der NAVORA-Administration vorbehalten.");
  await expect(page.getByRole("navigation", { name: "Hauptmenü" }).getByRole("link", { name: "Administration" })).toHaveCount(0);
  await page.goto("/intake");
  await expect(page.getByText("Die Aufnahme ist Admin- und Operations-Rollen vorbehalten.")).toBeVisible();
});

// UX1 part (c) (ADR-104). Seed nurse: pflege.test (registered nurse, Testteam Nord), viewport 390 × 844. Days in the
// Europe/Zurich calendar (the seed and the app use it; CI's clock runs in UTC).
function zurichDay(offset = 0): string {
  const [y, m, d] = new Date().toLocaleDateString("sv-SE", { timeZone: "Europe/Zurich" }).split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d + offset)).toISOString().slice(0, 10);
}
// Visit 508 (Testteam Nord, 09:00) is planned in the seed for the day after today, so that day has an open visit.
const NEXT_DAY = zurichDay(1);

test.describe("UX1 part (c) at 390 × 844", () => {
  test.use({ viewport: PHONE });

  test("UX1-6: the next visit comes first, inside the first viewport; safety signals stay above it", async ({ page }) => {
    await signIn(page, "pflege.test@navora.test");
    await page.goto(`/field?datum=${NEXT_DAY}`);
    const next = page.getByTestId("next-visit");
    await expect(next).toHaveCount(1);
    await expect(next.getByTestId("next-visit-label")).toHaveText("Erster offener Einsatz");
    const heading = next.getByRole("article").getByRole("heading", { level: 2 });
    const box = await heading.boundingBox();
    expect(box).not.toBeNull();
    // The brief's measure is for a nurse without a P1 signal. A signal (time-dependent in the seed) is always above
    // everything (UX1-6 (1)); only its own height may push the visit down.
    const signals = page.getByTestId("safety-signals");
    const signalHeight = (await signals.count()) > 0 ? ((await signals.boundingBox())?.height ?? 0) : 0;
    expect(box!.y + box!.height, "next visit heading inside 390 × 844").toBeLessThanOrEqual(PHONE.height + signalHeight);
    if (signalHeight > 0) {
      const above = await page.evaluate(() => {
        const s = document.querySelector('[data-testid="safety-signals"]');
        const n = document.querySelector('[data-testid="next-visit"]');
        return !!s && !!n && (s.compareDocumentPosition(n) & Node.DOCUMENT_POSITION_FOLLOWING) !== 0;
      });
      expect(above, "safety signals above the next visit").toBe(true);
    }
    // (4) "Offen im Team" and (5) the workday link and counters come after her visits.
    const order = await page.evaluate(() => {
      const n = document.querySelector('[data-testid="next-visit"]');
      const later = [
        document.querySelector('[data-testid="open-in-team"]'),
        document.querySelector('[data-testid="absence-list"]'),
        // The workday link in the page (the header menu also links to /work).
        document.querySelector('main a[href^="/work"]'),
        document.querySelector('[aria-label="Tagesübersicht"]'),
      ].filter(Boolean) as Element[];
      return later.every((el) => n && (n.compareDocumentPosition(el) & Node.DOCUMENT_POSITION_FOLLOWING) !== 0);
    });
    expect(order, "open team visits, workday link and counters below her visits").toBe(true);
    // UX1-6a: "Ich kann nicht arbeiten" stays inside the first viewport.
    await expect(page.getByTestId("absence-open")).toBeInViewport();
    const width = await page.evaluate(() => document.documentElement.scrollWidth);
    expect(width).toBeLessThanOrEqual(PHONE.width);
  });

  test("UX1-7: at most one filled button per visit card", async ({ page }) => {
    await signIn(page, "pflege.test@navora.test");
    for (const day of [zurichDay(0), NEXT_DAY]) {
      await page.goto(`/field?datum=${day}`);
      await page.waitForLoadState("networkidle");
      const counts = await page.getByRole("list", { name: "Einsätze" }).getByRole("article").evaluateAll((cards) =>
        cards.map((card) => {
          const filled = (Array.from(card.querySelectorAll("button")) as HTMLButtonElement[]).filter((b) => {
            if (b.offsetParent === null) return false;
            const bg = getComputedStyle(b).backgroundColor;
            return bg !== "rgba(0, 0, 0, 0)" && bg !== "transparent" && bg !== "rgb(255, 255, 255)";
          });
          return { card: card.getAttribute("aria-label"), filled: filled.map((b) => (b.textContent ?? "").trim()) };
        }),
      );
      for (const c of counts) expect(c.filled.length, `${day} ${c.card}: ${c.filled.join(", ")}`).toBeLessThanOrEqual(1);
    }
  });

  test("UX1-8 / UX1-9: cancel and hold need two taps and state their consequence; reporting an event stays one tap", async ({ page }) => {
    await signIn(page, "pflege.test@navora.test");
    // A planned visit of its own (six days ahead, 05:00, no other test uses that day), as the ABS1 test plans one:
    // seed visits on nearby days may be started or cancelled by earlier specs. Nothing is cancelled or held here.
    const day = zurichDay(6);
    await page.goto("/team");
    const caseCard = page.getByRole("article", { name: /Fall Testfall 08/ });
    await caseCard.getByRole("button", { name: "Einsatz planen" }).click();
    const planForm = caseCard.getByRole("form", { name: "Einsatz planen" });
    await planForm.getByLabel("Datum").fill(day);
    await planForm.getByLabel("Von").fill("05:00");
    await planForm.getByLabel("Bis").fill("05:30");
    await planForm.getByLabel("A", { exact: true }).fill("30");
    await planForm.getByRole("button", { name: "Einsatz speichern" }).click();
    await expect(caseCard.getByRole("list", { name: "Geplante Einsätze" })).toContainText("05:00–05:30");

    await page.goto(`/field?datum=${day}`);
    const card = page.getByRole("article", { name: /05:00 – 05:30/ });
    await expect(card).toHaveCount(1);
    // UX1-9: one tap, outline, on the card.
    await expect(card.getByTestId("quality").getByRole("button", { name: "Ereignis melden" })).toBeVisible();
    // UX1-8: not on the card itself.
    await expect(card.getByRole("button", { name: "Einsatz absagen" })).toHaveCount(0);
    await expect(card.getByRole("button", { name: "Abrechnungssperre setzen" })).toHaveCount(0);

    await card.getByTestId("visit-more").click();
    await card.getByRole("button", { name: "Einsatz absagen" }).click();
    const cancel = card.getByRole("group", { name: "Einsatz absagen" });
    await expect(cancel.getByTestId("more-consequence")).toHaveText(CANCEL_CONSEQUENCE);
    await expect(cancel.getByRole("button", { name: "Absage speichern" })).toBeVisible();
    await cancel.getByRole("button", { name: "Abbrechen" }).click();
    await expect(card.getByTestId("more-consequence")).toHaveCount(0);

    await card.getByTestId("visit-more").click();
    await card.getByRole("button", { name: "Abrechnungssperre setzen" }).click();
    const hold = card.getByRole("form", { name: "Abrechnungssperre setzen" });
    await expect(hold.getByTestId("more-consequence")).toHaveText(HOLD_CONSEQUENCE);
    await expect(hold).toContainText("Gesperrt ist nur die Abrechnung");
    await hold.getByRole("button", { name: "Abbrechen" }).click();
    await expect(card.getByTestId("more-consequence")).toHaveCount(0);
    // Nothing was saved: the visit is still open and has no hold.
    await expect(card.getByTestId("quality-hold")).toHaveCount(0);
    await expect(card.getByTestId("cancel-reason")).toHaveCount(0);
  });

  for (const path of ["/field", "/team", "/work"]) {
    test(`UX1-20: from ${path} the nurse reaches /settings in two taps; the menu control is in the first viewport`, async ({ page }) => {
      await signIn(page, "pflege.test@navora.test");
      await page.goto(path);
      const menu = page.getByTestId("header-menu");
      const summary = menu.locator("summary");
      const box = await summary.boundingBox();
      expect(box).not.toBeNull();
      expect(box!.y + box!.height).toBeLessThanOrEqual(PHONE.height);
      expect(box!.height).toBeGreaterThanOrEqual(44);
      await summary.click();
      await expect(menu.getByRole("button", { name: "Abmelden" })).toBeVisible();
      expect(await lastItemText(menu)).toBe("Abmelden");
      await menu.getByRole("link", { name: "Meine Einstellungen" }).click();
      await page.waitForURL(/\/settings$/);
      const width = await page.evaluate(() => document.documentElement.scrollWidth);
      expect(width).toBeLessThanOrEqual(PHONE.width);
    });
  }

  // UX1-25 (uxa UXR-13, PO 2026-10-27 20:15: merge condition of #554): the absence form is a modal dialog.
  test("UX1-25: the absence dialog takes focus, keeps Tab inside, closes on Escape without sending and returns focus", async ({ page }) => {
    await signIn(page, "pflege.test@navora.test");
    await page.goto("/field");
    const trigger = page.getByTestId("absence-open");
    await trigger.click();
    const dialog = page.getByRole("dialog", { name: "Abwesenheit" });
    await expect(dialog.getByRole("form", { name: "Abwesenheit erfassen" })).toBeVisible();
    const focusInside = () => page.evaluate(() => !!document.activeElement?.closest("dialog[open]"));
    expect(await focusInside(), "focus moved into the dialog").toBe(true);
    // More Tabs than the form has stops (date and time inputs have one per segment), so focus must wrap at least once.
    for (let i = 0; i < 30; i += 1) {
      await page.keyboard.press("Tab");
      expect(await focusInside(), `Tab ${i + 1} stays inside the dialog`).toBe(true);
    }
    await page.keyboard.press("Escape");
    await expect(dialog).toHaveCount(0);
    await expect(page.getByRole("form", { name: "Abwesenheit erfassen" })).toHaveCount(0);
    await expect(trigger).toBeFocused();
    // Nothing was sent: she is not recorded absent.
    await expect(page.getByTestId("my-absence")).toHaveCount(0);
  });

  // UX1-26 (uxa UXR-14): the header menu closes on Escape, on a tap outside and when an item is chosen.
  test("UX1-26: the header menu closes on Escape and on a tap outside", async ({ page }) => {
    await signIn(page, "pflege.test@navora.test");
    await page.goto("/field");
    const menu = page.getByTestId("header-menu");
    const item = menu.getByRole("link", { name: "Meine Einstellungen" });
    await menu.locator("summary").click();
    await expect(item).toBeVisible();
    await page.keyboard.press("Escape");
    await expect(item).toBeHidden();
    await expect(menu.locator("summary")).toBeFocused();
    await menu.locator("summary").click();
    await expect(item).toBeVisible();
    await page.getByRole("heading", { level: 1 }).click();
    await expect(item).toBeHidden();
  });

  test("UX1-21: the WORK1 notice shows the lead line and one heading per paragraph; lead and first heading in the first viewport", async ({ page }) => {
    // pflege.test has not acknowledged the notice in the seed (only assist.test has, work.spec).
    await signIn(page, "pflege.test@navora.test");
    await page.goto("/work");
    const notice = page.getByRole("region", { name: "Information zu deinem Arbeitstag" });
    await expect(notice.getByTestId("notice-lead")).toHaveText(NOTICE_LEAD);
    await expect(notice.getByTestId("notice-heading")).toHaveText([...NOTICE_HEADINGS]);
    await expect(notice.getByRole("button", { name: "Gelesen und verstanden" })).toBeVisible();
    for (const el of [notice.getByTestId("notice-lead"), notice.getByTestId("notice-heading").first()]) {
      const box = await el.boundingBox();
      expect(box).not.toBeNull();
      expect(box!.y + box!.height).toBeLessThanOrEqual(PHONE.height);
    }
  });
});

// UX1 part (f) (ADR-105): the sign-in page for every role at 390 × 844, and inputs that stay inside their form on /intake.
test.describe("UX1 part (f)", () => {
  test.describe("at 390 × 844", () => {
    test.use({ viewport: PHONE });

    test("UX1-15 / UX1-16: /login fits the phone; e-mail, password and Anmelden are in the first viewport", async ({ page }) => {
      await page.goto("/login");
      const width = await page.evaluate(() => document.documentElement.scrollWidth);
      expect(width).toBeLessThanOrEqual(PHONE.width);
      await expect(page.getByRole("heading", { name: "Bei NAVORA anmelden" })).toBeVisible();
      for (const el of [page.getByLabel("E-Mail"), page.getByLabel("Passwort"), page.getByRole("button", { name: "Anmelden" })]) {
        const box = await el.boundingBox();
        expect(box).not.toBeNull();
        expect(box!.y + box!.height).toBeLessThanOrEqual(PHONE.height);
      }
      for (const input of [page.getByLabel("E-Mail"), page.getByLabel("Passwort")]) {
        const box = await input.boundingBox();
        expect(box!.width).toBeGreaterThanOrEqual(300);
      }
    });
  });

  for (const viewport of [PHONE, { width: 1440, height: 900 }]) {
    test(`UX1-19 (i): every input on /intake stays inside its form at ${viewport.width} px`, async ({ page }) => {
      await page.setViewportSize(viewport);
      await signIn(page, "ops.test@navora.test");
      await page.goto("/intake");
      await page.waitForLoadState("networkidle");
      const outside = await page.evaluate(() => {
        const found: string[] = [];
        for (const form of Array.from(document.querySelectorAll("form"))) {
          const right = form.getBoundingClientRect().right;
          for (const el of Array.from(form.querySelectorAll("input, select, textarea")) as HTMLElement[]) {
            if (el.offsetParent === null) continue; // hidden inputs and closed sections
            const box = el.getBoundingClientRect();
            if (box.right > right + 0.5) found.push(`${el.getAttribute("name")}: ${Math.round(box.right)} > ${Math.round(right)}`);
          }
        }
        return found;
      });
      expect(outside).toEqual([]);
    });
  }
});
