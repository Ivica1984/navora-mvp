# Stellungnahme `uxa` zu V1-V14

**Stand:** 2026-11-11 03:52 (Europe/Zurich), UX/UI Design Architect (Review-Rolle, KI-Agent). Alle Punkte sind VORGESCHLAGEN; bindend ist nur `FOUNDER_DECISIONS.md`. Massstab: ob die Software für die Nutzerin als Ganzes bedienbar bleibt (kein toter Punkt, jeder Schritt vom vorigen Bildschirm erreichbar, 390 px) und ob ich ein Gate rechtzeitig und auf dem richtigen Kopf schreiben kann.

| Nr | Stellungnahme | Grund |
|---|---|---|
| V1 | Zustimmung | kein Bildschirmbezug; meine Verweise auf ADR-Nummern bleiben gültig, wenn die Nummern gleich bleiben |
| V2 | Zustimmung | ich lese den Status je Item; eine Datei je Item ist leichter zu finden |
| V3 | Zustimmung | kein Bildschirmbezug |
| V4 | Zustimmung | eine e2e-Datei je Kriterium macht die Prüfung eines Bildschirmkriteriums (z. B. 390 px, Sprungverweis) einzeln auffindbar; bestehende Fälle bleiben, wo sie sind (wie `cra`) |
| V5 | Zustimmung mit Bitte | je Block eine Datei mit Kriterien-ID, Status, Test, Lauf-ID ist, was ich für Gates lese. Bitte: je Bildschirmkriterium eine Spalte «Bildschirm und Breite» (z. B. `/field`, 390 × 844), damit klar ist, was ich prüfe |
| V6 | Zustimmung | eine Zeile «Gate fehlt von `uxa`» verhindert, dass ein Gate übersehen wird |
| V7 | Zustimmung mit Ausnahme | kleinere PRs prüfe ich gründlicher. Ausnahme: eine Bildschirmänderung und ihr Playwright-Fall bei 390 px gehören in denselben PR |
| V8 | Zustimmung | mein Gate gilt für einen Kopf; nach dem Nachziehen prüfe ich die Differenz in `src/app`, `src/components`, `tests/e2e` erneut |
| V9 | Zustimmung | kein Einwand |
| V10 | Zustimmung | auch für Bildschirmkriterien: ein Playwright-Fall, der ohne die Änderung rot ist, beweist, dass er die Anzeige prüft |
| V11 | Zustimmung mit Bedingung | ich laufe alle 4 h (:47), «zwei Läufe» = bis 8 h. Schreibe ich im zweiten Lauf kein Gate, nenne ich den Grund im Bericht. Ohne `ui-screenshots`-Archiv prüfe ich aus dem Code und sage das; der PO merged nie ohne ein Pflicht-Gate |
| V12 | IMPLEMENTED (Owner 22:55) | keine Einwände |
| V13 | keine Stellungnahme | FE-056 (Owner): kein npm-Zugang für Agentensitzungen; GitHub Actions ist die Testumgebung |
| V14 | **Zustimmung mit Bedingung** | der Durchgangstest wird Pflicht, sobald er die `uxa`-Punkte G-1 bis G-6 erfüllt (Bericht `UX_REVIEW.md` 2026-11-11 03:52): jeder Schritt über ein Bedienelement des vorigen Bildschirms oder das Menü, kein `page.goto` ausser `/login`; Schritte der Pflegenden bei 390 × 844; je Übergabe eine Prüfung dessen, was die nächste Person zuerst sieht. Sonst schützt die Pflicht einen Ablauf, den nur der Test findet, nicht die Nutzerin |

## Eigener Vorschlag

- **V-uxa-1 Bildschirmfotos aus dem Durchgangstest:** der Durchgangstest legt je Schritt ein Bildschirmfoto bei 390 × 844 im Artefakt `ui-screenshots` ab (nur synthetische Daten, nie in `recovery/main` eingecheckt). Wirkung: das `uxa`-Gate prüft den ganzen Ablauf auf einem Kopf an echten Bildern statt nur am Code; ein Rückschritt eines Bildschirms fällt im selben Lauf auf.
