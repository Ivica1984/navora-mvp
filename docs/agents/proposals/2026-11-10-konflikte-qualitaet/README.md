# Vorschläge: weniger Konflikte, effiziente Arbeit, höchste Qualität

**Stand:** 2026-11-10 22:50 (Europe/Zurich), `po`, im Auftrag des Owners (live): „Arbeite mit dem Team weitere Vorschläge aus.“ **Status aller Vorschläge: VORGESCHLAGEN.** Bindend ist nur, was in [`FOUNDER_DECISIONS.md`](../../product/FOUNDER_DECISIONS.md) steht (FE-053 Journal je Datei, FE-054 Block für Block, Merge nur mit grünen Tests, Durchgang als nächster Block).

**Ablauf:** Jede Rolle schreibt ihre Stellungnahme in ihrem nächsten Lauf als **eigene Datei** in diesem Ordner, `<rolle>.md` (z. B. `eng.md`), je Vorschlag V1-V14: Zustimmung, Ablehnung mit Grund oder Änderung, dazu eigene neue Vorschläge (V-<rolle>-1 …). Diese Datei ändert nur der PO, damit keine Konflikte entstehen. Der PO fasst danach zusammen; was eine Regel ändert, geht als Paket an den Owner. Issue: siehe Journal `po` 2026-11-10 22:50.

## Messung (Grundlage)

Dateien, die in den Konfliktauflösungs-Merges seit 2026-11-03 am häufigsten vorkamen (aus `git log`, Näherung):

| Datei | Anzahl | Ursache |
|---|---|---|
| `docs/agents/JOURNAL.md` | 205 | alle Rollen schreiben oben in eine Datei → **gelöst durch FE-053** |
| `docs/engineering/DECISIONS.md` | 107 | alle ADRs in einer Datei |
| `docs/agents/IMPLEMENTATION_STATUS.md` | 101 | alle Statuszeilen in einer Datei |
| `src/lib/supabase/database.types.ts` | 47 | generierte Datei, von Hand gemergt |
| `docs/engineering/READ_PATHS.md` | 39 | Sammeldatei |
| pgTAP `067_…`, `110_…`; `team-client.tsx`; `labels.ts`-Dateien | 27-36 | mehrere Kriterien im selben Test bzw. derselben Datei |

## Vorschläge

| Nr | Vorschlag | Wirkung | Wer baut | Stellungnahme erbeten von |
|---|---|---|---|---|
| V1 | **ADRs je Datei:** `docs/engineering/adr/ADR-<n>.md`; `DECISIONS.md` wird Index/Archiv (wie FE-053) | zweithäufigste Konfliktquelle weg | `eng` | `eng` |
| V2 | **Status je Item:** `IMPLEMENTATION_STATUS.md` als Verzeichnis `status/<ID>.md` oder Generierung aus Dateien; `agents-check` liest es | dritthäufigste Konfliktquelle weg | `eng` (Skript), `po` (Freigabe) | `eng`, `po` |
| V3 | **Generierte Dateien nie von Hand mergen:** `database.types.ts` bei Konflikt neu erzeugen (Skript), CI prüft, dass die Datei zur Migration passt | keine falschen Typen nach Merge | `eng` | `eng` |
| V4 | **Ein Kriterium = ein Testfile:** neue pgTAP- und e2e-Fälle in eigene Dateien je Kriterium (z. B. `124_b2_t12e_….test.sql`) statt Anhängen an 067/110 | weniger Konflikte, klare Zuordnung Kriterium → Test | `eng` | `eng`, `cra` |
| V5 | **Blöcke je Datei:** `docs/product/blocks/B0.md`, `BD.md`, `B2.md` …; `PRODUCT_BLOCKS.md` bleibt Übersicht; Kriterien als Liste mit ID, Status, Test, Lauf-ID | lesbar, keine 16 000-Zeichen-Zelle | `po` | `cra`, `lca`, `uxa`, `aia` |
| V6 | **Block-Tafel:** eine kurze Datei `docs/agents/BLOCK_BOARD.md`: aktiver Block, offene Kriterien, wer, PR, Gate fehlt von wem, nächster Merge | jede Rolle sieht in 30 Sekunden, was blockiert | `po` | alle |
| V7 | **Kleine PRs, ein Kriterium:** höchstens ein Kriterium je Engineering-PR; Richtwert ≤ 400 geänderte Zeilen ohne generierte Dateien | schnellere, gründlichere Prüfung | `eng` | `eng`, `cra` |
| V8 | **Sofortiges Nachziehen:** nach jedem Merge zieht der Autor offener PRs `recovery/main` im nächsten Lauf ein (Merge-Commit, kein Rebase); der PO merged nur PRs, die auf dem aktuellen Stand grün sind | keine veralteten grünen Läufe | alle | `eng` |
| V9 | **Revert zuerst:** wird die CI auf einem Merge-Commit rot, öffnet `eng` im selben Lauf einen Revert-PR; der PO merged ihn vor allem anderen; Ursachenanalyse danach | `recovery/main` bleibt immer grün | `eng`, `po` | `eng` |
| V10 | **Test zuerst sichtbar:** jeder Engineering-PR zeigt einen Test, der ohne die Änderung rot ist (Lauf-ID oder Probe-Branch), wie bei B0-7 | Tests prüfen wirklich etwas | `eng` | `eng`, `cra` |
| V11 | **Gate innerhalb von zwei Läufen:** `cra`, `lca`, `uxa` schreiben ihre Gate-Zeile spätestens im zweiten Lauf nach „bereit“; sonst nennt der PO den Engpass dem Owner | Gates werden nicht zum Stau | alle Gate-Rollen | `cra`, `lca`, `uxa` |
| V12 | **Takt der Aufgaben:** Gate-Rollen laufen vor dem PO-Lauf (z. B. `cra`/`lca` :20, PO :39, `eng` :10), damit eine Gate-Zeile im selben Stundenzyklus gemergt werden kann | eine Stunde weniger Wartezeit je Gate | Owner (Aufgaben-Prompts) | alle |
| V13 | **Lokale Tests möglich machen:** npm-Registry für die Agentensitzungen freigeben (E-1); heute kann `eng` `npm test`, `lint`, `build` lokal nicht ausführen | Fehler vor dem Push statt in der CI | Owner (Netzwerkeinstellung) | `eng` |
| V14 | **Durchgangstest als Pflichtlauf:** ab BD läuft `durchgang-ambulant` auf jedem PR, der `src/` oder `supabase/` ändert; ein PR, der ihn rot macht, wird nicht gemergt | die Software bleibt als Ganzes lauffähig | `eng` | `eng`, `uxa` |

## Stellungnahmen

Eigene Dateien der Rollen in diesem Ordner: `eng.md`, `cra.md`, `lca.md`, `uxa.md`, `aia.md`, `csa.md` (noch keine).
