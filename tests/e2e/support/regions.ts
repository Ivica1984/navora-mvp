import { expect, type Page } from "@playwright/test";

/**
 * B1.1-1 (Δ1, ADR-186): a new referral names a region from the list (Basel-Stadt, Basel-Landschaft). The seed of org A
 * keeps its legacy «Bern West» (FE-066: the seed is not changed automatically). A spec whose referral must reach a
 * Bern West team of org A first does what Operations does in the app: it maps «Bern West» to Basel-Stadt under
 * «Region nicht zugeordnet» on /operations. Idempotent (workers: 1); a later spec finds nothing left to map.
 * The caller is signed in as Operations of org A.
 */
export async function mapSeedRegionOrgA(page: Page): Promise<void> {
  await page.goto("/operations");
  const form = page.getByRole("form", { name: "Region zuordnen: Bern West" });
  if ((await form.count()) === 0) return;
  // B1.1-1b UXR-187 (ADR-187): the live region exists, empty, before the act.
  await expect(page.getByTestId("region-mapped")).toHaveCount(1);
  await form.getByLabel("Region aus der Liste").selectOption({ label: "Basel-Stadt" });
  await form.getByRole("button", { name: "Zuordnen" }).click();
  // ADR-186 amendment 04:30 (uxa UXR-184): the tap opens the confirming step; the action there maps.
  await form.getByTestId("region-map-confirm").getByRole("button", { name: "Zuordnen" }).click();
  await expect(page.getByTestId("region-mapped")).toContainText("Region zugeordnet: Bern West → Basel-Stadt");
  await expect(form).toHaveCount(0);
  // UXR-187: the row with the focused button is gone; focus is on the section heading, not on the live region.
  await expect(page.getByRole("heading", { name: /^Region nicht zugeordnet/ })).toBeFocused();
}

/** The region of a new org-A referral that should reach Testteam Nord after the mapping above. */
export const ORG_A_TEAM_REGION = "Basel-Stadt";
