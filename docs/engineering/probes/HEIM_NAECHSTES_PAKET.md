# Erstes Heim-Paket und Reihenfolge bis zur ersten KI-Demo: kurze Entscheidungsvorlage (`eng`-Teil)

**Stand:** 2026-11-20 ca. 16:00, `eng`. Grundlage: der Founder-Brief «Grundriss V1 – Richtung richtig, Heimregister kleiner schneiden, echte KI verbindlich einplanen». Der **PO-Teil fehlt noch**; der PO setzt das aktive Paket in *Active now*. Nichts davon ist gebaut. Zeitangaben sind ESTIMATE in Engineering-Läufen, ohne Gate-Fenster.

**Vorbedingung, das aktive Paket BK-f:**
- Gemergt (`e4e02c9`) und auf Staging ausgeführt: `staging-smoke` 44744533079, 4 von 4.
- `ci-repeat` 44746720886 auf `40a2ce1`: 22 von 22 Jobs grün (Startfenster, je 10× `db` und `e2e`, Abschluss).
- Die Abnahme erklärt der PO auf einem benannten Commit; danach erst startet das nächste Paket.

## Reihenfolge mit Abhängigkeiten

| # | Paket | Was die Heimleitung danach in der echten Staging-App tut | Braucht | STAB1 nötig? | ESTIMATE |
|---|---|---|---|---|---|
| **1** | **H1 Heim-Start: Woche der Aufträge** | nach dem Login ihre Woche sehen, mit allen Aufträgen, echtem Deckungsstatus, «Jetzt zu entscheiden» und Rechnungen | nur vorhandene Daten | nein (nur neue Lesefunktionen) | 2–3 |
| 2 | **AI1 KI-Berichtsentwurf** (erste echte KI) | *Pflegekraft:* drei Zeilen tippen, Claude macht den Entwurf mit Quelle je Zeile, sie korrigiert und unterschreibt. Das Team sieht die Rechnung. | Founder setzt danach die Render-Werte; `lca` liest die Anbieterbedingungen | nein (`field_visits` wird nur gelesen; Kostengrenze als neue Funktion) | 3–5 |
| 3 | **W1a Personal & Dienstplan** (B2B) | Stationen anlegen, Mitarbeitende mit Namen und vom Heim bestätigter Stufe erfassen, Dienstvorlagen festlegen, die Woche zuteilen | H1 (Startseite als Rahmen) | nein (neue Tabellen) | 3–4 |
| 4 | **W1b Abwesenheit & Lücke** (B2B) | Abwesenheit eintragen, die Lücke erscheint von selbst, «kann vertreten» aus dem eigenen Personal, «Soll/geplant» als Zusammenfassung | W1a | nein | 2–3 |
| 5 | STAB1, begrenzt | nichts Sichtbares | – | – | 1–2 |
| 6 | **W2 Lücke → Auftrag → Status zurück** | aus der Lücke mit zwei Tipps einen Auftrag senden; Woche und Start zeigen «angefragt», «übernommen», «besetzt extern» | W1b, STAB1 | **ja** (Auftrags- und Übernahmefunktionen bekommen Station und Lückenbezug) | 3–5 |
| 7 | **K-1 KI im Auftragsentwurf** | Zusatzbedarf in eigenen Worten oder per Gerätediktat; KI-Vorschläge sind markiert und werden bestätigt | AI1-Anschluss, W2 | ja (wie W2) | 3–4 |

**Meilensteine (ESTIMATE):**
- **Erste echte KI-Demo** auf Staging nach Paket 2: grob **5–8 Läufe** ab Start von H1.
- **«Lücke → Auftrag → Status zurück»** nach Paket 6: grob **14–22 Läufe**.

**STAB1 geprüft:** Es muss nur vor Paketen liegen, die eine der aufgeräumten Funktionen **ändern**. Das ist erst W2 der Fall. Neue Funktionen entstehen ohnehin als lesbare Datei (FE-100). Der STAB1-Umfang wird auf die Funktionen begrenzt, die W2 und K-1 ändern; die Liste legt der PO im STAB1-Vertrag fest.

**Damit AI1 nicht wartet:** Der PO kann die `lca`-Lesung der Anbieterbedingungen (AI1 §7 (3)) schon während H1 starten. Das ist Prüfarbeit, kein zweites Baupaket.

## Empfohlenes nächstes aktives Paket: H1

**Warum H1 vor AI1:**
- Es ist das kleinste Paket, und der Founder will es als erstes Heimregister.
- Es hat keine Abhängigkeit.
- AI1 folgt direkt danach mit festem Demopunkt.

## Die Register im Überblick

| Register | Was die Heimleitung erledigt | Daten aus dem Kern / fehlende Backend-Funktion | Regel · Testersatz · KI | Neu sichtbar auf Staging | Test · Gate |
|---|---|---|---|---|---|
| **H1 Start/Woche** | sehen, was offen, gedeckt oder nicht mehr gedeckt ist; direkt zum Auftrag oder zur Rechnung springen; neuen Auftrag starten | **vorhanden:** `client_orders` (Status), `client_invoices`. **Fehlt:** Lesefunktion Woche je Tag mit Statusleiter und Grund; Anzahl gesendeter Angebote je Auftrag | nur feste Regeln; kein Testersatz, keine KI | Startseite statt Formular; Raster Mo–So; «Jetzt zu entscheiden» (nicht gedeckt, Besetzung weggefallen, Rechnung erhalten) | pgTAP: nur eigenes Konto, Statuscodes stimmen. e2e 390/1440 px. `staging-smoke` Pfad 4. Gates `uxa`, `cra` (Wortlaut «gefährdet»/«nicht gedeckt») |
| **W1a Personal & Dienstplan** | Station, Mitarbeitende, Stufe, Dienstvorlage, Woche zuteilen | **fehlt:** B2B-Tabellen mit RLS (nur Heim-Rollen), Funktionen zuteilen und ändern mit Audit | feste Regeln (Stufe erfüllt Vorlage); keine KI | Register «Woche» und «Personal» mit synthetischen Namen | pgTAP: Team und andere Heime sehen nichts; Audit. e2e. `staging-smoke` Pfad 5. Gates `lca` (Personaldaten), `uxa` |
| **W1b Abwesenheit & Lücke** | Abwesenheit eintragen (ohne Grund), Lücke sehen, intern vertreten | **fehlt:** Lückenberechnung, «kann vertreten» | feste Regel; sichtbarer Hinweis «Arbeitszeit nicht geprüft» | Lücke in der Woche, Vorschlag aus dem eigenen Personal | pgTAP: Lücke und Vertretung in Grenzfällen. `staging-smoke` Pfad 6. Gates `lca`, `cra` |
| **W2 Lücke → Auftrag** | aus der Lücke einen Auftrag senden, Status im Plan sehen | **vorhanden:** Prüfen/Absenden, Angebot, Übernahme. **Fehlt:** Station und Lückenbezug am Auftrag, Brücke 2 | feste Regeln | Knopf «extern anbieten»; Zelle «besetzt extern · Team» | pgTAP + e2e Ende zu Ende. `staging-smoke` Pfad 7. Gates `cra`, `lca`, `uxa` |
| **K-1 KI-Ergänzung** | Freitext → markierte Vorschläge → bestätigen | AI1-Anschluss; neues Protokoll Vorschlag/Entscheid | **echte KI** (Claude, Staging, synthetisch); CI: Testersatz, nie «KI» genannt | «KI-Vorschlag aus Ihrem Text» je Feld | Evaluationssatz synthetischer Sätze; `staging-smoke` mit Modell an und mit Not-Aus. Gates `aia`, `lca`, `cra` |

## B2B-Modul und Fremdkomponenten

- Gebaut wird ein eigenes Planungsmodul, für den simulierten Heimkontext mit synthetischen Daten, gemäss Founder-Freigabe vom 20.11.
- **Keine Fremdkomponente vorgesehen.** Das Raster entsteht mit dem vorhandenen Stack: Next.js, React, Supabase, zod und die Schrift geist. Keine Kalender-Bibliothek, kein übernommener Code oder Inhalt Dritter.
- Wird später eine Komponente nötig, benennt `eng` sie vorher mit Lizenz zur Prüfung.
- Keine realen Heimdaten, kein realer Betrieb.

## Für den PO

- Der PO setzt das nächste Paket in *Active now* und schreibt den H1-Vertrag.
- Er korrigiert Blueprint §5 (`/order` ist gebaut und auf Staging nachgewiesen), mit Changelog-Zeile. `eng` ändert den Blueprint nicht.
- Danach legt er diese Vorlage dem Founder gemeinsam vor.
