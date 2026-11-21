# BK-5 offer: the single template (broadcast, FE-078 part 2)

**Owner:** `uxa` · **Created:** 2026-11-14 on founder instruction (live session) · **Status:** PROPOSED until the PO merges and places it; then the one screen reference for BK-c. **Block:** BK; BK-5 belongs to slice **BK-c** (active since 2026-11-17; BK-c2 screens on #1358). This file starts no feature work (README rule 12). **2026-11-17 11:48:** §2 (8), §3 and §4 carry the BK-c2 words (`uxa` 07:52, placed by the PO 08:39 (2)–(5), 09:39 (2)); rows marked UXR-224 to UXR-228 are PROPOSED and not yet placed.

Everything here is presentation: what the offer card and the client status show and never show. It sets no clinical, legal or tariff rule. Wording of a safety state is `cra`'s to confirm; anything one party sees about another is `lca`'s; the recommendation reasons are `aia`'s.

## 1. Which source wins

| Rank | Source | What it fixes |
|---|---|---|
| 1 | `docs/product/FOUNDER_DECISIONS.md` **FE-078 part 2** (status *verbindlich*, v29, 2026-11-14 15:00) | Every team that passes the hard checks sees the offer **at the same time**; the AI only orders and explains, never excludes; the team decides freely. PO notes (a) legal reading is the founder's assessment, **D-44 stays unresolved, Q-44e open**; (b) visible only to teams passing **every** hard check; (c) «nicht gedeckt» stays. |
| 2 | `docs/agents/briefs/BK.md`, PO amendments 15:00 (1)-(4), 17:40 (1)-(3), 20:40 (2)-(3) | BK-5 broadcast, BK-5a first valid take wins, BK-5n nobody assigns, cover-time state, CGR-223 loss of cover, **no team count to the client** (20:40 (3) overrides the count in 15:00 (4)). |
| 3 | This file | Card anatomy, states, words, what never appears, tests. |
| 4 | Pictures: `docs/product/img/v3/p2-team.png` (phone), `blueprint-v3/wireframes/team.svg` (desktop), `order.svg` (client) | Illustrations of 1-3. **If a picture differs from 1-3, the picture is wrong.** |

**Superseded (do not build from them):** BK brief criterion BK-5 «Offer cascade … exclusive window» (now marked in place); BK-5n «the cascade continues»; 15:00 (4) «count of eligible teams» for the client; ADR-191 (4), (6) and ADR-195 (3) where they say «cascade» (`eng` lists the change in the BK-c ADR, `BK-c_ADR_DRAFT.md` §2); Blueprint Annex C rows that say «Rangfolge und exklusive Kaskade» (the word is stale, **the legal question Q-44e stays open**, owner `lca`); in `p2-team.png` state B the active-looking «Übernehmen mit Person …» with nobody chosen and the «Heute» tab marker (UXR-218; §3 wins until the PO redraws it); every picture before Blueprint 3.2.15 and the PDF `blueprint-v3/pdf/NAVORA_Blueprint_V3.2.pdf` until the PO regenerates it.

## 2. Offer card (`/team`, team members with the take-over right)

Order from top to bottom:

1. Tag «Neues Angebot».
2. Title: «Empfohlen für euch: …» (one reason from the hard checks) and the shift as a fact: «Spätschicht · Fr 13.11. 16:30–21:30 · 5 Std.», then place and distance of **this** team only.
3. One neutral line: **«Alle passenden Teams sehen dieses Angebot.»**
4. «Passt, weil:» the hard checks this team passes, ticked, in words, with the same member for every condition.
5. Price line (Phase A synthetic): hourly rate and shift total, «0 CHF an NAVORA».
6. Recommendation box «Warum empfohlen»: reasons about **this** team only, source line «vorgeschlagen von Empfehlungs-Assistent · ohne Punktzahl», and «Kein anderes passendes Team ist ausgeschlossen.» (`aia` confirms the reasons).
7. Actions: primary **«Übernehmen mit …»**, outline **«Ablehnen»** (no reason asked in BK).
8. Footer: «Beim Übernehmen prüft NAVORA alle Bedingungen für die gewählte Person erneut. ‹Gedeckt› sieht der Auftraggeber, wenn diese Person geprüft ist und, falls ihr jemand anderen wählt, bestätigt hat.» (UXR-228, PROPOSED, `cra` confirms; built text on #1358 is the earlier sentence.)

**Never on the card:** a countdown, clock, deadline or amber window; «exklusiv», «Kaskade», «als Nächstes», «zuerst euch», «wer zuerst übernimmt»; the name, count, distance or ranking position of another team; any team's or person's exclusion or decline reason; «Vermittlung», «Vermittlungsgebühr», «Provision»; a payment through NAVORA.

## 3. Card states (team side)

| State | Words | Rule |
|---|---|---|
| Choosing who goes | Heading «Wählt, wer geht»; only members who pass every check; primary reads **«Person wählen»** until one is ticked, then «Übernehmen mit [Vorname N.]» (UXR-218) | Tab stays «Angebote». |
| Own tap pending | Button busy, card stays | No optimistic removal (`cra` condition (i)). |
| Another team was first | `role="status"`, neutral: «Bereits übernommen. Ein anderes Team hat diese Schicht übernommen. Für euch ist nichts gespeichert.» · «Schliessen» | No name of the other team; not an error colour. |
| Taken by another team, not tapped | Card leaves the list after the server committed the take; no history line | `cra` (i). |
| Take failed elsewhere | Card returns as an ordinary open offer, no badge | `cra` (ii). |
| Own team declined | «Abgelehnt. Ihr seht dieses Angebot nicht mehr.» | |
| Own named person stops passing before the start (CGR-223) | «Nicht mehr gedeckt: [Vorname N.] erfüllt die Bedingungen für diese Schicht nicht mehr.» · primary «Andere Person wählen» | Never the reason (absence, evidence). Nobody else assigns (FE-039). |
| Choosing who goes, caller free (H-BK-06:39, AUT-132) | Caller listed first as «Ich ([Vorname])» and pre-selected; colleagues as «[Vorname N.]»; only members who pass every check | Read-only check; the server re-checks at the tap. |
| Choosing who goes, caller not free | One neutral line above the list: «Du selbst kannst diese Schicht nicht übernehmen.» | Never the reason (`lca`). |
| Nobody in the team can take any more (UXR-226, PROPOSED) | One line «Niemand in eurem Team kann diese Schicht zurzeit übernehmen.»; no «Du selbst …» line; **no primary button**; «Ablehnen» stays | Replaces the built «Zurzeit erfüllt niemand im Team alle Bedingungen.» and the disabled «Person wählen». |
| Taken, the caller named herself (UXR-221) | Tag «Übernommen» · «Ihr habt diese Schicht übernommen. Es geht: [Vorname N.]» | No button (no un-take in BK-c). Counts as acknowledged (CGR-230 (a)). |
| Taken, a colleague named, not yet acknowledged (team view, also the taker) | Tag «Übernommen» · «Es geht: [Vorname N.] · Bestätigung ausstehend» · «Übernommen von [Vorname N.] um 14:31.» · «Bestätigt [Vorname] nicht bis Sa 14.11., 03:00, gilt die Übernahme nicht mehr.» | `latest_cover_at` as a fact, never a countdown or amber. The taker cannot withdraw in BK-c2 (PO 10:39 (3) (a)). |
| Named person's own card, not yet acknowledged (CGR-230, UXR-222) | Tag «Für dich eingeteilt» · «[Vorname N.] hat diese Schicht für euer Team übernommen und dich eingeteilt.» · shift facts · «Bitte bis Sa 14.11., 03:00 bestätigen.» · primary **«Bestätigen»** · outline **«Ich kann nicht»** · PROPOSED (UXR-224): under the buttons «Mit dem Bestätigen bist du fest eingeteilt.» | First in the list; only she sees the buttons; no third action (H-BK-09:39). |
| She tapped «Ich kann nicht» (UXR-224, PROPOSED, #1361) | Inline step: «Du gibst diese Schicht frei. Sie geht sofort an alle passenden Teams; du kannst sie danach nicht mehr übernehmen.» · «Freigeben» · «Zurück» | Focus to the sentence; the first tap writes nothing. `cra` confirms. |
| A member tapped «Ablehnen» (UXR-224, PROPOSED) | Inline step: «Euer Team sieht dieses Angebot danach nicht mehr.» · «Ablehnen» · «Zurück» | As above. |
| Acknowledged | Team: «Es geht: [Vorname N.] · bestätigt um 15:02» · her card: tag «Für dich eingeteilt» · «Du bist für diese Schicht eingeteilt.» | No button; «Ich kann nicht» is refused after the acknowledgement (PO 10:39 (3) (b)). |
| Released by «Ich kann nicht» (CGR-234 (d)) | «Nicht mehr übernommen: [Vorname N.] kann diese Schicht nicht übernehmen.» · primary «Andere Person wählen» while the offer is still with the team | Never a reason. |
| Not acknowledged at `latest_cover_at` | «Die Übernahme gilt nicht mehr: [Vorname N.] hat nicht bis 03:00 bestätigt.» | No blame wording; `cra` confirms. |

## 4. Client status (`/order`, top line of the order card, `role="status"`)

| State | Words |
|---|---|
| Open, before the coverage time | «Noch nicht gedeckt · Beginn Sa 14.11., 07:00» · «Angebot an alle passenden Teams gleichzeitig.» (no relative time: a server-rendered «in 5 Std.» goes stale; `uxa` 2026-11-17 11:48) |
| Taken, colleague named, not yet acknowledged (UXR-223, PO 08:39 (3)) | «Noch nicht gedeckt · Beginn …» · «Ein Team hat übernommen; die eingeteilte Person bestätigt noch.» (no team name, ADR-200 (5)) |
| Taken with a named, checked person (acknowledged or self-named) | «Gedeckt · Person benannt, geprüft für [bestellte Stufe, z. B. FaGe]» · «Team … · übernommen um 14:31» (CGR-226 (a): the ordered level, never the person's grade) |
| Coverage time reached | «Nicht gedeckt · Beginn …» · «Bis jetzt hat kein Team diese Schicht übernommen.» |
| Every eligible team declined, or no team eligible (one neutral state, F-1) | «Nicht gedeckt · Beginn …» · «Kein passendes Team ist frei.» |
| Shift start reached | «Nicht gedeckt · Die Schicht hat um 07:00 begonnen.» |
| Named person dropped out after «Gedeckt» was shown (CGR-223) | «Nicht mehr gedeckt · Beginn …» · «Die eingeteilte Person kann nicht. Das Angebot geht wieder an alle passenden Teams.» (no team name: DB contract, ADR-200 addendum (4) (c)) |
| Named person dropped out **before** her acknowledgement (UXR-225, PROPOSED) | «Noch nicht gedeckt · Beginn …» · «Die eingeteilte Person kann nicht. Das Angebot geht wieder an alle passenden Teams.» (never «Nicht mehr gedeckt»: the client was never covered) |
| Next step under «Nicht gedeckt» (CGR-226 (b), UXR-227) | Directly under the headline, before the detail: «Über NAVORA übernimmt kein Team diese Schicht. Bitte jetzt euren eigenen Ersatzplan nutzen: [Ersatzplan]». **[Ersatzplan] UNKNOWN**, substance from `cra` and the Clinical Owner (Blueprint §5.1). Not built in BK-c2 (PO 11:39); required before any gate «released for real persons and data». |

**Never for the client:** a team count (exact, banded or live), «Team 1 von 3», other teams' names before a take, any decline or exclusion reason, a payment through NAVORA.

## 5. Tests for BK-c (proposed acceptance; the PO places them)

- Playwright 390 × 844 and 1440: the offer card has no element matching `/exklusiv|Kaskade|bis \d{1,2}:\d{2}|zuerst|Vermittlung/i`, no `timer` role, no other team's name; it contains «Alle passenden Teams sehen dieses Angebot.»
- Two seeded eligible teams both see the card (equals `order_offers`, 20:40 (2)); an ineligible team does not.
- Second tap after a committed take shows «Bereits übernommen», nothing stored.
- Client read model and screen: no count field, no «von \d Teams»; each state of §4 at the pinned clock of CGR-222 (c).
- **Visible evidence for review:** CI artifacts cannot be opened by the reviewing agents (proxy). Proposed, PO to decide: the BK-c PR attaches the 390 px and 1440 px screenshots of the offer card and the client status (synthetic seed only) as images in a PR comment, and the `uxa` gate line names the images it looked at. Until then a green `ui-screenshots` job is not a visual review.

## 6. Open, kept visible

- **Legal:** the broadcast is product logic, not a finding that real operation falls outside job placement or staff lending rules. **D-44 unresolved, Q-44e open** until the qualified legal review (`lca`, legal adviser).
- **Clinical:** coverage-time value (K-8), next-step words, position and colour of the states (`cra`).
- **AI:** recommendation reasons (`aia`).

## Change log

- 2026-11-14 (`uxa`, founder instruction): created. Pictures `team.svg`, `order.svg`, `platform.svg`, `platform-map.svg`, `engine-map.svg`, `erd-b-auftrag.mmd` aligned in the same PR; superseded lines in `briefs/BK.md` marked in place.
- 2026-11-17 11:48 (`uxa`, PO 08:39 (5)): BK-c2 words transferred into §2 (8), §3 and §4 (07:52 rows as placed; F-1 replaces two client rows; CGR-226 (a), UXR-223); relative time removed from §4; PROPOSED rows UXR-224 (#1361), UXR-225, UXR-226, UXR-227, UXR-228 added. Status line updated (BK-c active).
