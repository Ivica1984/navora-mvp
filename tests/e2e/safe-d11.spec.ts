import { expect, test, type Page } from "@playwright/test";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { zurichDay } from "./support/durchgang-time";

// SAFE-D11 R2 (brief docs/agents/briefs/SAFE-D11.md, ADR-184, migration 0125): a case closed while it was still in the
// team search and reopened while a readiness item is missing gets no new search, but a visible Operations exception
// «Wiedereröffneter Fall ohne Team» at 1440 px on /operations; a team nurse does not see it. Synthetic local-only
// accounts from supabase/seed.sql; the case is created by this spec in a region without any team, so no seeded team
// gets an offer and no other spec sees it.
//
// Close and reopen run in the app (Fallstatus panel). The setup and the removal of a fact run through the API as the
// signed-in Operations person (anon key + her session; RLS and the command audit apply, as in durchgang-ambulant):
// the app has no form that makes a ready case incomplete (update_case_intake needs a reason for a funding fact on a
// ready case and /intake lists only cases never ready, `intake_cases`), so the R2 state is reached only that way.
const OPS = "ops.test@navora.test";
const NURSE = "pflege.test@navora.test";
const PASSWORD = "navora-local-only";
const ORG_A = "00000000-0000-4000-b000-000000000011";
const REGION = "Region ohne Team SAFE-D11";
const LAST = `SafeD11 ${Date.now().toString(36)}`;
const CLIENT = `Klient ${LAST}`;
const LABEL = "Wiedereröffneter Fall ohne Team";
const NEXT = "Fehlende Angaben ergänzen; die Teamsuche öffnet sich dann selbst. Nie automatisch zuweisen.";

async function signIn(page: Page, email: string, landing: RegExp) {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await page.waitForURL(landing);
}

async function asPerson(email: string): Promise<SupabaseClient> {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_ANON_KEY;
  if (!url || !key) throw new Error("SUPABASE_URL and SUPABASE_ANON_KEY of the local stack are needed for the SAFE-D11 setup");
  const db = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  const { error } = await db.auth.signInWithPassword({ email, password: PASSWORD });
  if (error) throw new Error(`sign-in for the SAFE-D11 setup failed: ${error.message}`);
  return db;
}

test("a reopened case without a team and with a missing item shows Operations «Wiedereröffneter Fall ohne Team» at 1440 px; a nurse does not see it (SAFE-D11 R2)", async ({ page, browser }) => {
  const ops = await asPerson(OPS);

  // Setup: one synthetic referral, converted with complete facts -> ready, in the team search (J1).
  const title = `Anfrage ${LAST}`;
  const { data: recorded, error: recordError } = await ops.rpc("record_partner_request", {
    p_organization_id: ORG_A, p_partner_name: `Spital ${LAST}`, p_partner_type: "Spital", p_region: REGION, p_city: "",
    p_urgency: "mittel", p_time_info: "", p_request_title: title, p_need_summary: `Bedarf ${LAST}`,
    p_requested_services: ["Grundpflege"], p_idempotency_key: crypto.randomUUID(), p_urgency_source: "referrer_stated",
  });
  expect(recordError, "record_partner_request").toBeNull();
  expect(recorded).toBe("ok");
  const { data: request, error: requestError } = await ops.from("partner_requests").select("id").eq("request_title", title).single();
  expect(requestError, "read the new referral").toBeNull();
  const { data: converted, error: convertError } = await ops.rpc("convert_partner_request", {
    p_request_id: request!.id, p_first_name: "Klient", p_last_name: LAST, p_consent_confirmed: true,
    p_facts: { residence_municipality: "Teststadt", residence_canton: "BS", insurer_name: "Testkasse", insurance_type: "KVG",
      requested_start: zurichDay(Date.now(), 1) },
    p_idempotency_key: crypto.randomUUID(),
  });
  expect(convertError, "convert_partner_request").toBeNull();
  const conv = converted as { result: string; case_id: string; ready: boolean };
  expect(conv.result).toBe("ok");
  expect(conv.ready, "setup: the case is ready, so its team search opens").toBe(true);
  const caseId = conv.case_id;

  // The insurance type is no longer known (API only, with a reason; see the header).
  const { data: unready, error: unreadyError } = await ops.rpc("update_case_intake", {
    p_case_id: caseId, p_facts: { insurance_type: "unknown" }, p_idempotency_key: crypto.randomUUID(),
    p_reason: "Synthetisch: Versicherungsart unklar",
  });
  expect(unreadyError, "update_case_intake").toBeNull();
  expect((unready as { result: string; ready: boolean }).ready).toBe(false);

  // In the app at 1440 px: Operations closes the case while it is in the search, then reopens it.
  await page.setViewportSize({ width: 1440, height: 900 });
  await signIn(page, OPS, /\/operations$/);
  const panel = page.getByTestId("ops-case-lifecycle");
  await panel.getByLabel("Fall suchen").fill(LAST);
  const card = panel.getByRole("article", { name: new RegExp(`Fallstatus ${CLIENT}`) });
  await expect(card).toContainText("ohne Team");
  await card.getByRole("button", { name: "Fall abschliessen" }).click();
  const form = card.getByRole("form", { name: "Fall abschliessen" });
  await form.locator("select[name=code]").selectOption("declined");
  await form.getByRole("button", { name: "Abschliessen" }).click();
  const closed = panel.getByRole("article", { name: new RegExp(`Abgeschlossen ${CLIENT}`) });
  await expect(closed).toBeVisible();
  await closed.getByRole("button", { name: "Wiedereröffnen" }).click();
  await closed.getByLabel("Begründung").fill("Synthetisch: Rückkehr nach Hause");
  await closed.getByRole("button", { name: "Wiedereröffnen" }).click();
  await expect(panel.getByRole("article", { name: new RegExp(`Abgeschlossen ${CLIENT}`) })).toHaveCount(0);

  // R2: exactly one exception for the case, P2, label, missing item, next step; it closes only with its cause.
  await page.reload();
  const center = page.getByRole("region", { name: "Ausnahmen" });
  const exception = center.getByTestId("exception").filter({ hasText: LABEL }).filter({ hasText: LAST });
  await expect(exception).toHaveCount(1);
  await expect(exception).toContainText("P2");
  await expect(exception).toContainText(REGION);
  await expect(exception).toContainText("insurance_type");
  await expect(exception).toContainText(`Nächster Schritt: ${NEXT}`);
  await expect(exception.getByTestId("exception-closes-with-cause")).toContainText("schliesst automatisch");
  await expect(exception.getByRole("button", { name: "Schliessen" })).toHaveCount(0);
  // No dispatch from the exception (R5): nothing assigns a team.
  await expect(exception.getByRole("button", { name: /Team zuweisen|Matching starten/ })).toHaveCount(0);
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  expect(overflow).toBeLessThanOrEqual(0);

  // Negative: a team nurse of organisation A sees no Operations exception for it.
  const other = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const nurse = await other.newPage();
  await signIn(nurse, NURSE, /\/field$/);
  await nurse.goto("/operations");
  await expect(nurse.getByTestId("exception").filter({ hasText: LAST })).toHaveCount(0);
  await expect(nurse.getByText(LABEL)).toHaveCount(0);
  await other.close();

  // The cause resolved: the missing fact is completed -> the exception is gone, the case still has no team (R5).
  const { data: ready, error: readyError } = await ops.rpc("update_case_intake", {
    p_case_id: caseId, p_facts: { insurance_type: "KVG" }, p_idempotency_key: crypto.randomUUID(),
    p_reason: "Synthetisch: Versicherungsart bestätigt",
  });
  expect(readyError, "update_case_intake (complete)").toBeNull();
  expect((ready as { result: string; ready: boolean }).ready).toBe(true);
  await page.reload();
  await expect(page.getByRole("region", { name: "Ausnahmen" }).getByTestId("exception").filter({ hasText: LABEL })
    .filter({ hasText: LAST })).toHaveCount(0);
  await page.getByTestId("ops-case-lifecycle").getByLabel("Fall suchen").fill(LAST);
  await expect(page.getByTestId("ops-case-lifecycle").getByRole("article", { name: new RegExp(`Fallstatus ${CLIENT}`) }))
    .toContainText("ohne Team");

  // Clean-up: the case is closed again, so later specs see no open search in this region.
  const { data: reclosed, error: recloseError } = await ops.rpc("close_case", {
    p_case_id: caseId, p_reason_code: "other", p_reason: "Synthetisch: Ende SAFE-D11 e2e", p_idempotency_key: crypto.randomUUID(),
  });
  expect(recloseError, "close_case (clean-up)").toBeNull();
  expect(reclosed).toBe("ok");
});
