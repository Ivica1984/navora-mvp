# Owner agenda: every open ask on one page

**Owner:** `po` · **Since:** 2026-10-27 14:45 CET (STR-14 adopted, [rule](../DECISION_PACKAGES.md#frozen-packages)) · **Last update:** 2026-10-27 22:15 CET (D-38 terms T12 (i) and T13 amended from `cra` CGR-82/-83 and `lca` 21:45; adviser questions added; ask unchanged). Earlier 2026-10-27 21:15 CET (D-38 ask amended: terms as amended, cut-over window length; adviser questions added). Earlier 2026-10-27 20:15 CET (D-38 entered bundle 2) · **Updated** only when a package enters or leaves `awaiting-approval`, or its ask changes.

Each line is one ask. Answer in one line, for example "D-7: approved". Each package holds the reasoning. Until you answer, the safe default written in the package stays in force.

## Bundle 1: now (minutes each)

| Ask | What to answer | Unblocks |
|---|---|---|
| [D-1](D-1.md) **urgent** | Are any rows in the live project about a real person (also renamed or adapted)? yes / no / not sure, and where the content came from. Also now: switch on leaked-password protection. | containment; SR-26; D-7 visibility |
| [SR-26](SR-26.md) | After D-1: approve A (check whether the other application still writes, move `orders` to its own protected project and verify, then drop it here), and confirm you are that application's controller. | live database hygiene |
| [D-7](D-7.md) | Apply the ruleset on `main` and `recovery/main` (PR required, checks `app`, `db`, `e2e`, no force-push or deletion) and secret scanning with push protection. | M2 |
| [D-8](D-8.md) | Approve B: two `preserve-*` tags, then merge PR #3 with a merge commit after D-7. | M2 (the claude.ai Project syncs `main`) |
| [G-1](../reports/G1_CLINICAL_OWNER_APPOINTMENT.md) | Name the Clinical Owner (route B recommended) and a deputy, or tell `po` to prepare a search profile and mandate draft. | the 9 `clinical` packages below; D-37 |

## Bundle 2: pilot foundation (one meeting)

| Ask | What to answer | Unblocks |
|---|---|---|
| [D-11](D-11.md) | Approve Zurich as the pilot canton (`csa` STR-1: include one municipality with a known financing path for a new provider). | D-18, D-25, holidays, statistics |
| Partner (D-12) | Name the partner provider, or say none is in view. With the partner, find out its CIRS rules and whether it wants QG1 events at all (D-16, po 2026-10-27 19:10). | D-38, D-18, D-29, D-4, D-16 (CIRS) |
| Legal adviser | Name one Zurich legal adviser. | questions in D-22, D-18, D-9, D-4, D-12 (a)-(c) and R-11 rule adoption, D-38 (T3, T5, T9, T11, T13, T14; AUT-10 (a), AUT-11 preset form, AUT-12 shared service, PatG ZH § 18 period; dual employment partner/C for remaining clients; MepV reporting of a rule withdrawal for the regulatory adviser), D-16 (CIRS export) |
| [D-36](D-36.md) | Give `lca` the interRAI licence terms (licensee, licensor, instrument and edition, territory and term, permitted uses incl. contractors, AI processing and software design, confidentiality). A fact, not a decision. | D-37 |
| [D-2](D-2.md) | Approve the two paid plans (staging, EU/CH), create both and add the staging deploy secrets. | T12 staging |
| [D-26](D-26.md) | Approve: in production no service-role key on the app host; invitations and the push sender run in Edge Functions. | ADM1 invitations in production |
| [D-29](D-29.md) | Approve option B (evidence, second-person confirmation, re-check date, expiry downgrades) as the real-data gate; the licence holder stays responsible. | real clients |
| [D-38](D-38.md) | Approve terms T1-T14 (T2, T12 (i), T13 amended 21:15 and 22:15) as the minimum content of the partnership letter of intent; sign no LOI naming the 12-month sunset before. Also: set the cut-over window length (T12 (i)); ask the Gesundheitsdirektion who issues a new provider's Leistungsauftrag and what training duty applies to it (T14). (po 2026-10-27 20:15, amended 21:15, 22:15) | the partner's LOI; the C transfer |
| [D-14](D-14.md) | Approve F3 (fee per active team member per month) or F4 (per client); no per-hour or revenue-share fee. | J7 |

## Bundle 3: once a legal adviser is named or a trigger holds

| Ask | What to answer | Trigger |
|---|---|---|
| [D-22](D-22.md) | Approve the recommended default (care and billing parts) and have the adviser answer `lca` questions 1-4. | legal adviser |
| [D-18](D-18.md) | Give the tariff contract the provider signs, with `lca` questions 1-3, to the adviser. | D-11, partner |
| [D-9](D-9.md) | Approve option D (protective variant) as the intake model; `lca` questions 1-5 to the adviser. | legal adviser |
| [D-4](D-4.md) | Approve C + D; the adviser sets the retention periods. | D-11, partner |
| [D-24](D-24.md) | Approve A now (no nursing-home build); B later under hard boundaries 1-5. | none needed for A |
| [D-25](D-25.md) | Only once D-24 moves past A: name an adviser for the partner home's canton, or approve D (ask the canton). | D-24 past A |

## Waiting for the Clinical Owner (G-1), not for the owner

[D-28](D-28.md), [D-31](D-31.md), [D-3](D-3.md), [D-30](D-30.md), [D-16](D-16.md), [D-19](D-19.md), [D-17](D-17.md), [D-15](D-15.md), [D-10](D-10.md). Each is complete and waits; the strict defaults stay in force.

## Coming once the inputs are in (not asked yet)

- [D-37](D-37.md): interRAI HC as the designated target instrument (B), with C as a horizon-2 target. Waits only for the D-36 licence terms (bundle 2); `cra`, `lca` in, Engineering drafted by po (2026-10-27 20:15).
