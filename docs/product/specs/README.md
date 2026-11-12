# Spezifikationen «Ready for Design & Development»

**Besitzer:** Product Owner (`po`) · **Auftrag:** Founder-Entscheid FE-068 (2026-11-12) · **Bau-Reihenfolge:** unverändert nach FE-054 (BD, dann B1 bis B10). Eine Spezifikation ändert die Reihenfolge nicht und gibt keinen Block frei.

## Wozu

Je Block eine verbindliche Arbeitsgrundlage für Design (`uxa` und das Design-Team) und Entwicklung (`eng`). Ziel: keine strukturellen Annahmen, keine Korrekturschleifen. Jede Aussage ist überprüfbar: am Code, an einem Test oder an einem Entscheid.

## Rangfolge der Quellen

1. Founder-Entscheide (`FOUNDER_DECISIONS.md`, neuester gilt).
2. Der Code auf `recovery/main` (CLAUDE.md: «Der tatsächliche Repository-Code hat Vorrang»). Die Spezifikation beschreibt den Ist-Stand mit Datei und Zeile.
3. Diese Spezifikation für alles, was sich ändern soll (SOLL).
4. Briefs (`docs/agents/briefs/`) und `ARCHITECTURE.md` als Herleitung.

Widerspricht eine Spezifikation dem Code, gilt der Code, bis die SOLL-Änderung gebaut und abgenommen ist. Der PO trägt die Abweichung als SOLL-Zeile ein; er ändert nichts stillschweigend.

## Kennzeichnung jeder Aussage

| Marke | Bedeutung |
|---|---|
| **IST** | IMPLEMENTED: so baut der Code es heute (mit Beleg `datei:zeile`). |
| **SOLL Δn** | PLANNED: Änderung, die mit dem Block gebaut wird. Jede SOLL-Zeile hat ein Abnahmekriterium. Entschieden vom PO im Rahmen der Produktautorität, ohne neue klinische, rechtliche oder tarifliche Regel. |
| **OFFEN** | Hängt an einem Entscheid (Nummer, wer entscheidet) oder an einer Prüfung durch `cra` / `lca`. Die Spezifikation nennt das Verhalten, das bis dahin gilt. |
| **UNKNOWN** | Im Code nicht vorhanden und nicht entschieden. |
| **SIM** | Regel läuft nur als Simulationsregel auf synthetischen Daten (FE-069, D-27): sichtbar als «Simulationsregel» (~~«vorläufig»~~, ersetzt PO 12.11.2026 17:39 nach `lca` 16:35: «vorläufig» bleibt für eine von einer Person befristet bestätigte Regel), nie als freigegeben. |

## Aufbau je Block

Je Modul des Blocks, immer in dieser Reihenfolge:

1. **Zweck und Inhalt:** wer, wozu, welche Daten (Feldtabelle: Feld, Typ, Pflicht, Validierung, Quelle).
2. **Logik und Interaktion:** jede Aktion (Vorbedingung, Ergebnis, gespeicherte Fakten, Folgen für andere Personen, Fehlertexte wörtlich).
3. **Zustände:** leer, Laden, Fehler, viele Einträge, lange Texte, Doppeltipp, keine Berechtigung, Zugang beendet.
4. **Sichtbarkeit:** wer sieht was (RLS), was andere Organisationen nie sehen.
5. **Regeln:** Regel-ID und Status (UNVALIDATED, PROVISIONAL, SIM).
6. **SOLL-Änderungen und OFFEN-Punkte.**
7. **Abnahmetests:** e2e, pgTAP oder Unit, je Kriterium.

Dazu je Block die **Visualisierung**: Wireframes je Screen (Handy 390 × 844, Desktop 1440) in Claude Design und der User Flow auf einem Whiteboard. Die Links stehen im Kopf der Block-Datei. Die Visualisierung zeigt Hierarchie, Reihenfolge und Fluss; Farben und Typografie kommen aus `docs/design/DESIGN_SYSTEM.md` (`uxa`).

## Status «Ready»

Ein Block ist «Ready for Design & Development», wenn:

- jedes Modul alle sieben Abschnitte hat;
- `uxa` die Visualisierung und die Zustände geprüft hat (Zeile im `UX_REVIEW.md`);
- `cra` die Stellen mit Pflege- oder Sicherheitsbezug geprüft hat;
- `lca` die Stellen mit Datenschutz-, Abrechnungs- oder Vertragsbezug geprüft hat;
- jeder OFFEN-Punkt ein geltendes Verhalten bis zum Entscheid hat.

## Plan (vorgeschlagen 2026-11-12, FE-068)

| Lieferung | Inhalt | Ziel | Status |
|---|---|---|---|
| 1 | [`00_PLATTFORM.md`](00_PLATTFORM.md) (Rollen, Navigation, globale Zustände), [`B1.md`](B1.md) (Musterblock) | Fr 2026-11-13 | Entwurf 2026-11-12, Prüfung `uxa`, `cra`, `lca` angefragt |
| Founder-Freigabe der Form | am Musterblock | Mo 2026-11-16 | OFFEN |
| 2 | BD, B2 (inkl. D-43 als SIM, FE-069), B3 | Di 2026-11-17 | geplant |
| 3 | B4, B5, B6 | Do 2026-11-19 | geplant |
| 4 | B7, B8 (inkl. D-18 als SIM, FE-069) | Mo 2026-11-23 | geplant |
| 5 | B9, B10 | Mi 2026-11-25 | geplant |

## Eingaben für spätere Spezifikationen (PO 12.11.2026 17:39)

**B8 (Abrechnung), aus `lca` D-18 16:35 (beratend, keine Rechtsberatung), in die B8-Spezifikation zu übernehmen, sobald sie geschrieben wird:**
- **SIM-1** Das Label reist mit dem Wert: jede abrechenbare Tatsache, Schätzzeile, Exportzeile und jedes PDF speichert Version und Status des D-18-Regelsatzes und zeigt das Label aus dem gespeicherten Status; ein späterer Statuswechsel beschriftet alte Zahlen nicht um.
- **SIM-2** Der Status sperrt, das Label informiert: ein Regelsatz im Status SIM erzeugt keine Tatsache für eine Organisation mit echten Daten (Phase B) und keine Rechnung oder Kostenträgerexport. pgTAP: SIM-Regelsatz + Organisation mit echten Daten → abgelehnt mit benanntem Code.
- **SIM-3** Kein Agent und keine App-Rolle setzt einen D-18-Regelsatz auf einen bestätigten Status; die Bestätigung nennt Person und Quelle (Vertrag, Artikel, Version). `lca`-Lesarten heissen «Lesart lca (KI-Analyse, keine Rechtsberatung)».
- **SIM-4** Screenshots und Demo zeigen die Langform mindestens einmal pro Ansicht.
- Wortlaut (PROPOSED, `uxa` entscheidet den Bildschirmtext): D-18 «Simulationsregel – nicht mit Tarifvertrag und kantonalen Regeln abgeglichen. Nur synthetische Daten.»; D-43 «Simulationsregel – fachlich nicht freigegeben. Nur synthetische Daten.» Ob der Founder bei der Bestätigung der FE-069-Lesart ein einziges Label für beide will, bleibt seine Wahl (FE-069 nennt «bzw.»); bis dahin gilt die getrennte Form als Vorschlag, nicht als Ersatz von FE-069.
