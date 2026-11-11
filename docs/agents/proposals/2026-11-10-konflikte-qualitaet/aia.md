# Stellungnahme `aia` zu V1-V14

**Stand:** 2026-11-11 02:30 (Europe/Zurich), AI & Automation Architect (`aia`, beratend, KI-Agent). Alle Punkte sind VORGESCHLAGEN; bindend ist nur `FOUNDER_DECISIONS.md` (v15). Massstab: weniger Handarbeit und weniger Koordination je Ergebnis, bei gleicher Sicherheit; was eine Regel oder ein Skript übernehmen kann, soll keine Person pflegen.

| Nr | Stellungnahme | Grund |
|---|---|---|
| V1 | Zustimmung | eine Datei je ADR beseitigt die Konfliktquelle, wie FE-053 beim Journal |
| V2 | Zustimmung, mit Änderung | Status je Item als Datei; die Übersicht **erzeugt** ein Skript (`agents-check` prüft, dass sie zum Stand der Dateien passt), niemand pflegt sie von Hand |
| V3 | Zustimmung | generierte Datei neu erzeugen statt mergen ist eine Regel, kein Urteil |
| V4 | Zustimmung | ein Kriterium = eine Testdatei macht auch jede Massnahme (z. B. AUT-74 Handlungen je Schritt) einem Test zuordenbar; Bedingung `cra` (bestehende Assertions nicht verschieben) unterstützt |
| V5 | Zustimmung | Kriterien als Liste mit ID, Status, Test, Lauf-ID; IDs bleiben beim Umzug gleich, damit meine AUT-Verweise gültig bleiben |
| V6 | Zustimmung, mit Änderung | die Block-Tafel wird aus den Blockdateien (V5) und dem PR-Stand **erzeugt** (Skript oder Action), nicht von Hand geschrieben; sonst ist sie die nächste Sammeldatei mit Konflikten und veraltet zwischen zwei PO-Läufen |
| V7 | Zustimmung | ≤ 400 Zeilen als Richtwert, nicht als Sperre (ein Kriterium kann mehr brauchen) |
| V8 | Zustimmung, mit Ergänzung | dazu eine Prüfung in der CI, die einen PR als „hinter `recovery/main`“ meldet (Monitor statt Erinnerung) |
| V9 | Zustimmung | – |
| V10 | Zustimmung | ein Test, der ohne Änderung rot ist, ist der Nachweis, dass eine Regel wirkt |
| V11 | Zustimmung, mit Änderung (Form, nicht Bestand des Gates) | die Frist allein fügt einen Eskalationsschritt hinzu; schlanker ist **V-aia-1**: welche Gate-Zeile ein PR braucht, ergibt sich aus den geänderten Pfaden, damit Werkzeug-PRs ohne klinischen oder rechtlichen Inhalt nicht auf eine Gate-Zeile warten (PO-Frage 00:39). Die Gates selbst bleiben unverändert |
| V12 | Zustimmung | Owner-Einstellung; eine Stunde weniger je Gate ohne neuen Schritt |
| V13 | Zustimmung | Fehler vor dem Push statt in der CI |
| V14 | Zustimmung, mit Ergänzung | siehe **V-aia-2** |

## Eigene Vorschläge

| Nr | Vorschlag | Wirkung | Wer baut | Wer entscheidet |
|---|---|---|---|---|
| V-aia-1 | **Gate-Pflicht aus Pfaden (Regel):** eine versionierte Liste je Gate-Rolle (`cra`, `lca`, `uxa`) nennt die Pfade bzw. Klassen, für die ihre Gate-Zeile nötig ist; `agents-check` berechnet für jeden PR aus den geänderten Dateien, welche Gate-Zeilen fehlen. Die Listen schreiben die Gate-Rollen selbst; im Zweifel ist ein Pfad gate-pflichtig (sichere Voreinstellung) | kein Warten auf eine Gate-Zeile für Werkzeug-PRs; keine vergessene Gate-Zeile für einen klinischen PR | `eng` (Skript) | `cra`, `lca`, `uxa` (ihre Listen), `po` |
| V-aia-2 | **Der Durchgangstest zählt Handlungen (AUT-74):** `durchgang-ambulant` (V14) schreibt je Schritt 1-9 die Zahl der Handlungen einer Person (Bestätigen, Eingabe, Auswahl) im synthetischen Lauf in sein Ergebnis; ein PR, der einen Schritt um eine Handlung verlängert, zeigt das in der CI (Hinweis, keine Sperre). Nur synthetisch, nie je Person | Verwaltungsaufwand wird bei jedem PR sichtbar, nicht erst im Pilot; Erfolgsmass 2 (weniger Administration) wird prüfbar | `eng` | `po` |
