# Owner agenda: every open ask on one page

**Owner:** `po` · **Since:** 2026-10-27 14:45 CET (STR-14 adopted, [rule](../DECISION_PACKAGES.md#frozen-packages)) · **Last update:** 2026-10-29 18:12 CET (D-1 changed: review date asked; key rotation decoupling asked, from the `lca` 17:00 dossier). Earlier 2026-10-29 17:00 CET (D-1 changed: owner precaution recorded, the remaining ask narrowed to origin and naming legal and data protection; D-7 changed: the "real or not sure" condition holds, ask now B). Earlier 2026-10-28 18:15 CET (D-38 ask item (3) changed: the T16 stop fall-back period moves to the Clinical Owner, from `cra` CGR-88 and `lca` 17:41; the D-38 T16 adviser question replaced, not added). Earlier 2026-10-28 15:15 CET (D-38 combined ask on T1-T18 and T10 now in bundle 2; one adviser question added). Earlier 2026-10-28 14:20 CET (D-38 still nothing to answer: `cra` 13:40 in, only `eng` open; a Clinical Owner deputy question noted for the combined ask). Earlier 2026-10-28 12:15 CET (D-38 still nothing to answer: `lca` in, `cra` and `eng` open; five D-38 questions added to the adviser list, the adviser ask itself unchanged). Earlier 2026-10-28 11:10 CET (STR-17 F5: each ask names its version date; D-38 ask paused and reopened for T15-T18 and T10 options, `csa` STR-18; operational line for the task prompts, F7; STR-19 kit question noted as coming). Earlier 2026-10-28 00:15 CET (D-38 T12 (i) (b) and T3 amended from `lca` 23:41; ask unchanged). Earlier 2026-10-27 22:15 CET (D-38 terms T12 (i) and T13 amended from `cra` CGR-82/-83 and `lca` 21:45; adviser questions added; ask unchanged). Earlier 2026-10-27 21:15 CET (D-38 ask amended: terms as amended, cut-over window length; adviser questions added). Earlier 2026-10-27 20:15 CET (D-38 entered bundle 2) · **Updated** only when a package enters or leaves `awaiting-approval`, or its ask changes.

Each line is one ask. Answer in one line, for example "D-7: approved". Each package holds the reasoning. Until you answer, the safe default written in the package stays in force.

## Bundle 1: now (minutes each)

| Ask | What to answer | Unblocks |
|---|---|---|
| [D-1](D-1.md) **urgent** | **Changed since you last looked (2026-10-29):** your precaution is in force (treated as real until clarified; no real client data for tests or pilot). Still asked: where the content came from (yes / no / not sure; and was the old app ever reachable from outside the Codespace?), and name legal counsel and the data-protection responsible person **and give the review a date**; the breach and reporting question is theirs, on the facts dossier (drafted 2026-10-29). **New (2026-10-29 18:12):** approve rotating the key after SR-26 step 3 in one dated session, without waiting for the end of the review (default until then: your order, rotation after the review). Also now: switch on leaked-password protection. | containment; SR-26; D-7 |
| [SR-26](SR-26.md) | After D-1: approve A (check whether the other application still writes, move `orders` to its own protected project and verify, then drop it here), and confirm you are that application's controller. *(ask of 2026-10-24 20:09)* | live database hygiene |
| [D-7](D-7.md) | **Changed since you last looked (2026-10-29):** apply the ruleset on `main` and `recovery/main` (PR required, checks `app`, `db`, `e2e`, no force-push or deletion) and secret scanning with push protection, **and switch to private on a paid plan (B)**: your D-1 precaution meets its condition. | M2; D-1 precaution |
| [D-8](D-8.md) | Approve B: two `preserve-*` tags, then merge PR #3 with a merge commit after D-7. *(ask of 2026-10-24 18:12)* | M2 (the claude.ai Project syncs `main`) |
| [G-1](../reports/G1_CLINICAL_OWNER_APPOINTMENT.md) | Name the Clinical Owner (route B recommended) and a deputy, or tell `po` to prepare a search profile and mandate draft. *(ask of 2026-10-27 14:45)* | the 9 `clinical` packages below; D-37 |

**Operational, optional (no decision, a setting only you can change):** (a) let each scheduled agent task's prompt point to README rule 9 (frozen packages bind every role; `csa` STR-17 F7; agents never edit scheduled tasks); (b) merge `cra` PR #589, then close #582, or give the `cra` task merge permission (po 2026-10-28 10:10).

## Bundle 2: pilot foundation (one meeting)

| Ask | What to answer | Unblocks |
|---|---|---|
| [D-11](D-11.md) | Approve Zurich as the pilot canton (`csa` STR-1: include one municipality with a known financing path for a new provider). *(ask of 2026-10-27 12:05)* | D-18, D-25, holidays, statistics |
| Partner (D-12) | Name the partner provider, or say none is in view. With the partner, find out its CIRS rules and whether it wants QG1 events at all (D-16, po 2026-10-27 19:10). *(ask of 2026-10-27 19:10)* | D-38, D-18, D-29, D-4, D-16 (CIRS) |
| Legal adviser | Name one Zurich legal adviser. *(ask of 2026-10-27 14:45)* | questions in D-22, D-18, D-9, D-4, D-12 (a)-(c) and R-11 rule adoption, D-38 (T3, T5, T9, T11, T13, T14; AUT-10 (a), AUT-11 preset form, AUT-12 shared service, PatG ZH § 18 period; dual employment partner/C for remaining clients; MepV reporting of a rule withdrawal for the regulatory adviser; added 2026-10-28 12:15: T15 (d) how the partner's stay commitment binds for each nurse, T17 loan or deferral vs control and *Vergünstigung*, T10 (ii) care services, T10 (iii) incubation fee, T18 (a) cooperative form; added 2026-10-30 10:15: D-4 question on a misfiled needs assessment (kept struck or removed; insurer notice), from D-13 / CGR-103; replaced 2026-10-28 18:15 (`lca` 17:41 (c)): T16 whether making a team-owned provider's start depend on a NAVORA-appointed person who sets the transition safety levels, records the lift of a safety stop and sets or agrees its fall-back period, while NAVORA decides when she is named, is control over it or restricts its Leitung Pflege's responsibility), D-16 (CIRS export) |
| [D-36](D-36.md) | Give `lca` the interRAI licence terms (licensee, licensor, instrument and edition, territory and term, permitted uses incl. contractors, AI processing and software design, confidentiality). A fact, not a decision. *(ask of 2026-10-27 13:35)* | D-37 |
| [D-2](D-2.md) | Approve the two paid plans (staging, EU/CH), create both and add the staging deploy secrets. *(ask of 2026-10-27 12:05)* | T12 staging |
| [D-26](D-26.md) | Approve: in production no service-role key on the app host; invitations and the push sender run in Edge Functions. *(ask of 2026-10-24 21:10)* | ADM1 invitations in production |
| [D-29](D-29.md) | Approve option B (evidence, second-person confirmation, re-check date, expiry downgrades) as the real-data gate; the licence holder stays responsible. *(ask of 2026-10-24 14:40)* | real clients |
| [D-38](D-38.md) | **Changed since you last looked (ask of 2026-10-28 18:15; item (3) changed: you now set two periods; the T16 stop fall-back period is set by the Clinical Owner, or by you only with her recorded agreement, fixed in the LOI, none before G-1; no team transfers before the Clinical Owner has set the transition levels):** approve terms T1-T18 as the minimum content of the partner's letter of intent, and sign no LOI naming the sunset before. With it: (1) which T10 options NAVORA may offer the partner (product view: (i) and (iv); (ii) non-care services only; (iii) only after the adviser); (2) any T17 fee deferral at all (default none); (3) two periods: the T12 (i) cut-over window and the T16 extension option (the T16 stop fall-back is the Clinical Owner's, or yours only with her recorded agreement); (4) a deputy for the Clinical Owner (with G-1); (5) T6 route, T7, T8 as before. New since 00:15: T15-T18 (team-level transition criteria, independence and fallbacks, C's financing, governance after the transition); a safety stop is lifted by the Clinical Owner's record plus each Leitung Pflege's agreement, never by one person alone. | the partner's LOI; the C transfer |
| [D-14](D-14.md) | Approve F3 (fee per active team member per month) or F4 (per client); no per-hour or revenue-share fee. *(ask of 2026-10-25 00:10)* | J7 |

## Bundle 3: once a legal adviser is named or a trigger holds

| Ask | What to answer | Trigger |
|---|---|---|
| [D-22](D-22.md) | Approve the recommended default (care and billing parts) and have the adviser answer `lca` questions 1-4. *(ask of 2026-10-24 15:10)* | legal adviser |
| [D-18](D-18.md) | Give the tariff contract the provider signs, with `lca` questions 1-3, to the adviser. *(ask of 2026-10-24 05:15)* | D-11, partner |
| [D-9](D-9.md) | Approve option D (protective variant) as the intake model; `lca` questions 1-5 to the adviser. *(ask of 2026-10-24 10:11)* | legal adviser |
| [D-4](D-4.md) | Approve C + D; the adviser sets the retention periods. *(ask of 2026-10-24 10:11)* | D-11, partner |
| [D-24](D-24.md) | Approve A now (no nursing-home build); B later under hard boundaries 1-5. *(ask of 2026-10-25 01:16)* | none needed for A |
| [D-25](D-25.md) | Only once D-24 moves past A: name an adviser for the partner home's canton, or approve D (ask the canton). *(ask of 2026-10-25 01:16)* | D-24 past A |

## Waiting for the Clinical Owner (G-1), not for the owner

[D-28](D-28.md), [D-31](D-31.md), [D-3](D-3.md), [D-30](D-30.md), [D-16](D-16.md), [D-19](D-19.md), [D-17](D-17.md), [D-15](D-15.md), [D-10](D-10.md). Each is complete and waits; the strict defaults stay in force.

## Coming once the inputs are in (not asked yet)

- Provider kit (`csa` STR-19, #594): "may the second team found its provider directly from the kit, without a partner?" Becomes due once the first C is admitted and the adviser has answered P-24 (shared regulated services). Not asked before.

- [D-37](D-37.md): interRAI HC as the designated target instrument (B), with C as a horizon-2 target. Waits only for the D-36 licence terms (bundle 2); `cra`, `lca` in, Engineering drafted by po (2026-10-27 20:15).
