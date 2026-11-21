import { expect, test, type Page } from "@playwright/test";

// ADM2-10 (migration 0091, ADR-114): the team proposes and admits a colleague on /team at phone width; the
// administrator switches team admission on and records "Vertrag erfasst" on /admin; the new member appears in the
// team list. Synthetic local-only accounts from supabase/seed.sql:
// - pflege.test (RN) and assist.test (CA) are the two active members of Testteam Nord, so one consent admits there
//   (ADM2-5: all other active members when fewer than two exist); the two-consent path is proven in pgTAP 091.
// - coach.test (org A, in no team) stands for "not a member of this team": she does not see the proposal. The seed
//   has no nurse of another team with a password; pgTAP 091 covers that refusal.
// - aufnahme.test is the hand-made account (D-26 default A; no membership, never signs in).
// Clean-up (also in afterAll if a step failed): the new member is removed from Nord by the ADM1 path and the switch is
// turned off, so the specs that run later see the seed's teams (workers: 1).
const ADMIN = "admin.test@navora.test";
const PROPOSER = "pflege.test@navora.test";
const COLLEAGUE = "assist.test@navora.test";
const OUTSIDER = "coach.test@navora.test";
const NEW_ACCOUNT = "aufnahme.test@navora.test";
const PASSWORD = "navora-local-only";
const CANDIDATE = "Kandidatin E2E Test";

async function signIn(page: Page, email: string) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"));
}

const admin2 = (page: Page) => page.getByRole("region", { name: "Aufnahme durch das Team" });

async function signOut(page: Page) {
  await page.context().clearCookies();
}

function zurichToday(): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Zurich" }).format(new Date());
}

async function cleanUp(page: Page) {
  await signIn(page, ADMIN);
  await page.goto("/admin");
  const row = page.getByRole("region", { name: "Mitglieder" }).locator('li[aria-label^="Mitglied "]', { hasText: NEW_ACCOUNT });
  if (await row.count()) {
    const remove = row.getByRole("button", { name: "Aus Team entfernen" });
    if (await remove.isVisible()) {
      await remove.click();
      const form = row.getByRole("form", { name: "Aus Team entfernen" });
      await form.getByLabel("Begründung").fill("E2E aufräumen");
      await form.getByRole("button", { name: "Entfernen" }).click();
      await expect(row.getByText("in keinem Team")).toBeVisible();
    }
  }
  const section = page.getByRole("region", { name: "Aufnahme durch das Team" });
  if ((await section.getByTestId("admission-switch").textContent()) === "Eingeschaltet") {
    await section.getByRole("button", { name: "Ausschalten" }).click();
    // UX2-23 (ADR-124): the switch asks once; the step's own button runs the command.
    await section.getByTestId("admission-confirm").getByRole("button", { name: "Ausschalten" }).click();
    await expect(section.getByTestId("admission-switch")).toHaveText("Ausgeschaltet");
  }
  await signOut(page);
}

test.afterAll(async ({ browser }) => {
  const page = await browser.newPage();
  await cleanUp(page);
  await page.close();
});

test("the team admits a colleague by consent and the administrator records the contract (ADM2-10)", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });

  // ADM2-1: off by default; the administrator switches it on.
  await signIn(page, ADMIN);
  await page.goto("/admin");
  const admin = page.getByRole("region", { name: "Aufnahme durch das Team" });
  await expect(admin.getByTestId("admission-switch")).toHaveText("Ausgeschaltet");
  await admin.getByRole("button", { name: "Einschalten" }).click();
  // UX2-23 (ADR-124): the switch asks once; the step's own button runs the command.
  await admin.getByTestId("admission-confirm").getByRole("button", { name: "Einschalten" }).click();
  await expect(admin.getByTestId("admission-switch")).toHaveText("Eingeschaltet");
  await signOut(page);

  // ADM2-2: a member proposes with three fields only.
  await signIn(page, PROPOSER);
  await page.goto("/team");
  const section = page.getByRole("region", { name: "Aufnahme ins Team" });
  await section.getByRole("button", { name: "Kollegin vorschlagen" }).click();
  const form = section.getByRole("form", { name: "Kollegin vorschlagen" });
  await expect(form.locator("input, select")).toHaveCount(3);
  await form.getByLabel("Name (wie im Team gebraucht)").fill(CANDIDATE);
  await form.getByLabel("Angegebene Qualifikation").selectOption("care_assistant");
  await form.getByLabel("Pensum").selectOption("40-60");
  await form.getByRole("button", { name: "Vorschlagen" }).click();
  const card = section.getByRole("article", { name: `Vorschlag ${CANDIDATE}` });
  await expect(card.getByTestId("consent-count")).toHaveText("0 von 1 Zustimmung");
  await expect(card.getByRole("button", { name: "Zustimmen" })).toHaveCount(0); // not her own proposal
  await signOut(page);

  // Someone outside the team does not see it.
  await signIn(page, OUTSIDER);
  await page.goto("/team");
  await expect(page.getByText(CANDIDATE)).toHaveCount(0);
  await signOut(page);

  // ADM2-5: the colleague consents; the team admits her.
  await signIn(page, COLLEAGUE);
  await page.goto("/team");
  const colleagueCard = page.getByRole("region", { name: "Aufnahme ins Team" }).getByRole("article", { name: `Vorschlag ${CANDIDATE}` });
  await colleagueCard.getByRole("button", { name: "Zustimmen" }).click();
  await expect(colleagueCard.getByTestId("proposal-outcome")).toContainText("vom Team aufgenommen");
  await signOut(page);

  // ADM2-6: "Vertrag erfasst" is the administrator's only step.
  await signIn(page, ADMIN);
  await page.goto("/admin");
  const contract = page.getByRole("form", { name: `Vertrag erfassen ${CANDIDATE}` });
  await contract.getByLabel("E-Mail des angelegten Kontos").fill(NEW_ACCOUNT);
  await contract.getByLabel("Vertragsbeginn").fill(zurichToday());
  await contract.getByRole("button", { name: "Vertrag erfassen" }).click();
  await expect(page.getByRole("form", { name: `Vertrag erfassen ${CANDIDATE}` })).toHaveCount(0);
  // ADM2-9: listed with team and outcome; the candidate record is gone, so no name in the list.
  await expect(page.getByRole("list", { name: "Alle Aufnahmen" }).getByTestId("admission-row").first()).toContainText("Vertrag erfasst");
  await expect(page.getByRole("list", { name: "Alle Aufnahmen" })).not.toContainText(CANDIDATE);
  // The member appears with her name (ADM1 profile) and without a qualification until the administrator sets it.
  const member = page.getByRole("region", { name: "Mitglieder" }).locator('li[aria-label^="Mitglied "]', { hasText: NEW_ACCOUNT });
  await expect(member.getByTestId("member-name")).toHaveText(CANDIDATE);
  await expect(member.getByRole("list", { name: "Teams" })).toContainText("Testteam Nord");
  await expect(member.getByTestId("qualification-missing")).toBeVisible();

  // UX2-26 (ADR-136): the same card offers the existing set_member_qualification; nothing is selected on render.
  const recorded = page.getByRole("article", { name: `Vertrag erfasst ${CANDIDATE}` });
  await expect(recorded).toContainText("angegeben: Pflegeassistenz");
  await expect(recorded.getByTestId("contract-recorded")).toHaveText("Vertrag erfasst");
  const offer = recorded.getByRole("form", { name: `Qualifikation festlegen ${CANDIDATE}` });
  const radios = offer.getByRole("radio");
  await expect(radios).toHaveCount(2);
  for (const r of await radios.all()) await expect(r).not.toBeChecked();
  // 44 px rows (uxa 16:10).
  for (const row of await offer.locator("label:has(input[type=radio])").all()) {
    expect((await row.boundingBox())?.height ?? 0).toBeGreaterThanOrEqual(44);
  }
  // The text above the list no longer sends her to the member entry.
  await expect(admin2(page)).not.toContainText("Die Qualifikation setzt die Administration wie bisher beim Mitglied");
  await offer.getByRole("radio", { name: "Pflegeassistenz" }).check();
  await offer.getByLabel("Begründung (3–300 Zeichen)").fill("Ausweis E2E geprüft");
  await offer.getByRole("button", { name: "Qualifikation festlegen" }).click();
  await expect(page.getByTestId("qualification-offer-notice")).toHaveText("Qualifikation festgelegt.");
  await expect(recorded).toHaveCount(0);
  // The membership carries the chosen value (same command as "Qualifikation ändern" on the member entry).
  await expect(member.getByRole("list", { name: "Teams" })).toContainText("Testteam Nord · Pflegeassistenz");
  await expect(member.getByTestId("qualification-missing")).toHaveCount(0);
  await expect(admin2(page).getByRole("list", { name: "Vertrag erfasst, Qualifikation fehlt" })).not.toContainText(CANDIDATE);
  await signOut(page);

  // The proposal has left the team's open list (decided).
  await signIn(page, PROPOSER);
  await page.goto("/team");
  await expect(page.getByRole("region", { name: "Aufnahme ins Team" }).getByText(CANDIDATE)).toHaveCount(0);
  await signOut(page);

  await cleanUp(page);
});

// UX2-26 (2) (ADR-136): "Später" sets nothing; the member stays listed under "Vertrag erfasst, Qualifikation fehlt".
test("\"Später\" leaves the new member listed without a qualification (UX2-26)", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await signIn(page, ADMIN);
  await page.goto("/admin");
  if ((await admin2(page).getByTestId("admission-switch").textContent()) !== "Eingeschaltet") {
    await admin2(page).getByRole("button", { name: "Einschalten" }).click();
    await admin2(page).getByTestId("admission-confirm").getByRole("button", { name: "Einschalten" }).click();
    await expect(admin2(page).getByTestId("admission-switch")).toHaveText("Eingeschaltet");
  }
  await signOut(page);

  await signIn(page, PROPOSER);
  await page.goto("/team");
  const section = page.getByRole("region", { name: "Aufnahme ins Team" });
  await section.getByRole("button", { name: "Kollegin vorschlagen" }).click();
  const form = section.getByRole("form", { name: "Kollegin vorschlagen" });
  await form.getByLabel("Name (wie im Team gebraucht)").fill(CANDIDATE);
  await form.getByLabel("Angegebene Qualifikation").selectOption("registered_nurse");
  await form.getByLabel("Pensum").selectOption("60-80");
  await form.getByRole("button", { name: "Vorschlagen" }).click();
  await expect(section.getByRole("article", { name: `Vorschlag ${CANDIDATE}` })).toBeVisible();
  await signOut(page);

  await signIn(page, COLLEAGUE);
  await page.goto("/team");
  const colleagueCard = page.getByRole("region", { name: "Aufnahme ins Team" }).getByRole("article", { name: `Vorschlag ${CANDIDATE}` });
  await colleagueCard.getByRole("button", { name: "Zustimmen" }).click();
  await expect(colleagueCard.getByTestId("proposal-outcome")).toContainText("vom Team aufgenommen");
  await signOut(page);

  await signIn(page, ADMIN);
  await page.goto("/admin");
  const contract = page.getByRole("form", { name: `Vertrag erfassen ${CANDIDATE}` });
  await contract.getByLabel("E-Mail des angelegten Kontos").fill(NEW_ACCOUNT);
  await contract.getByLabel("Vertragsbeginn").fill(zurichToday());
  await contract.getByRole("button", { name: "Vertrag erfassen" }).click();
  const recorded = page.getByRole("article", { name: `Vertrag erfasst ${CANDIDATE}` });
  await expect(recorded).toContainText("angegeben: Pflegefachperson");
  for (const r of await recorded.getByRole("radio").all()) await expect(r).not.toBeChecked();
  await recorded.getByRole("button", { name: "Später" }).click();
  await expect(recorded).toHaveCount(0);
  await expect(admin2(page).getByRole("list", { name: "Vertrag erfasst, Qualifikation fehlt" })).toContainText(`${CANDIDATE} · Testteam Nord`);
  const member = page.getByRole("region", { name: "Mitglieder" }).locator('li[aria-label^="Mitglied "]', { hasText: NEW_ACCOUNT });
  await expect(member.getByTestId("qualification-missing")).toBeVisible();
  // After a reload the fact still lists her (it is the membership row, not page state).
  await page.reload();
  await expect(admin2(page).getByRole("list", { name: "Vertrag erfasst, Qualifikation fehlt" })).toContainText(`${CANDIDATE} · Testteam Nord`);
  await signOut(page);

  await cleanUp(page);
});
