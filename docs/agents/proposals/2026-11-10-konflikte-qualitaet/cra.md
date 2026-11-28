# Stellungnahme `cra` zu V1-V14

**Stand:** 2026-11-11 01:26 (Europe/Zurich), Clinical & Regulatory Architect (Review-Rolle, KI-Agent, keine zugelassene Fachperson). Alle Punkte sind VORGESCHLAGEN; bindend ist nur `FOUNDER_DECISIONS.md`. Massstab: Nachvollziehbarkeit klinischer, Abrechnungs- und Sicherheitsnachweise (Kriterium → Test → Lauf), nicht Geschwindigkeit allein.

| Nr | Stellungnahme | Grund |
|---|---|---|
| V1 | Zustimmung | kein Sicherheitsbezug; ADR-Verweise in meinen Befunden bleiben gültig, wenn die Nummern gleich bleiben |
| V2 | Zustimmung mit Bedingung | `agents-check` muss weiter erkennen, wenn ein Item ohne Gate als `delivered` steht |
| V3 | Zustimmung | falsche Typen nach Merge können eine Prüfung im Client umgehen; neu erzeugen statt von Hand mergen ist sicherer |
| V4 | **Zustimmung** | ein Kriterium = eine Testdatei macht jeden Sicherheitsnachweis (z. B. B2-T12e, B5-T9) einzeln auffindbar. Bedingung: bestehende Assertions in 067/110/080 werden **nicht** verschoben oder gelöscht, nur neue Fälle in neue Dateien; ein Verschieben wäre eine Änderung der Nachweise und braucht ein Gate |
| V5 | Zustimmung | eine Datei je Block mit Kriterien-ID, Status, Test, Lauf-ID ist genau das, was ich für Gates lese; die Stoppfall-Tabelle §5 bleibt **eine** Übersicht (Phase-A-Bedingung CGR-161) |
| V6 | Zustimmung | eine Zeile „Gate fehlt von `cra`“ hilft mir, nichts zu übersehen |
| V7 | **Zustimmung mit Ausnahme** | kleinere PRs prüfe ich gründlicher. Ausnahme: eine Regel und ihr Negativtest gehören in denselben PR; eine Migration ohne ihren pgTAP-Negativfall wird nicht getrennt geliefert, auch wenn der Richtwert überschritten wird |
| V8 | Zustimmung | ein Gate gilt für einen Kopf; nach dem Nachziehen prüfe ich die Differenz in `src supabase tests e2e` erneut (wie bei #1020, #1032) |
| V9 | Zustimmung | ein roter `recovery/main` kann einen Sicherheitstest verdecken; Revert zuerst ist sicherer |
| V10 | **Zustimmung** | entspricht meiner Bedingung für B0-4 (#1039: rot vor #922, grün heute). Für Sicherheitsregeln ist das der stärkste Nachweis, dass der Test etwas prüft |
| V11 | Zustimmung mit Bedingung | ich laufe alle 4 h (:26), also «zwei Läufe» = bis 8 h. Wenn ich im zweiten Lauf ein Gate nicht schreibe, nenne ich den Grund im Bericht; der PO darf den Engpass dem Owner nennen, aber **nie ohne Gate mergen**, wo das Gate Pflicht ist (PO_MERGE_PROCESS Bedingung 2) |
| V12 | IMPLEMENTED (Owner 22:55) | keine Einwände |
| V13 | Zustimmung | lokale Tests verringern rote CI-Läufe; Nachweis bleibt die CI auf dem Kopf |
| V14 | **Zustimmung mit Bedingung** | der Durchgangstest wird erst Pflicht, wenn er die Punkte von CGR-175 erfüllt (Abklärungsbesuch statt ASM1, abrechenbarer Fakt ohne Gründe, Prüfung beim Start); sonst schützt die Pflicht einen Test, der weniger beweist, als er scheint |

## Eigener Vorschlag

- **V-cra-1 Gate-Zeile im PR-Kopf maschinenlesbar:** `agents-check` erkennt `cra-gate: #<n> <sha> clear` im PR-Kommentar und im Bericht und meldet, wenn der Merge-Kopf vom Gate-Kopf abweicht und die Differenz `src`, `supabase`, `tests` oder `e2e` berührt. Wirkung: kein Merge auf einem ungeprüften Kopf, ohne dass jemand die Köpfe von Hand vergleicht.
