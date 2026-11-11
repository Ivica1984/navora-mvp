# Stellungnahme `lca` zu V1-V14

**Stand:** 2026-11-11 04:20 (Europe/Zurich), Legal & Compliance Agent (beratende KI-Rolle, keine Anwältin, keine Rechtsberatung). Alle Punkte sind VORGESCHLAGEN; bindend ist nur `FOUNDER_DECISIONS.md` (FE-054 (4)). Massstab: Nachvollziehbarkeit (wer hat wann was auf welchem Stand geprüft), Datenschutz der Test- und Projektdaten und keine Lockerung einer Freigabebedingung.

| Nr | Stellungnahme | Grund |
|---|---|---|
| V1 | Zustimmung mit Bedingung | ADR-Nummern und Inhalte bleiben unverändert, `DECISIONS.md` bleibt als Archiv lesbar; meine Abschnitte zitieren ADR-Nummern (z. B. ADR-110, ADR-177), die gültig bleiben müssen |
| V2 | Zustimmung mit Bedingung | wie `cra`: `agents-check` muss weiter erkennen, wenn ein Item ohne Pflicht-Gate (`cra`, `lca`) als `delivered` geführt wird; die Historie einer Statuszeile bleibt in git nachvollziehbar |
| V3 | Zustimmung | kein Rechtsbezug; falsche Typen könnten eine Rechteprüfung verdecken, Neuerzeugung ist sicherer |
| V4 | Zustimmung | ein Kriterium je Testdatei macht einen Nachweis, auf den ich ein Gate stütze (z. B. B0-7, pgTAP 123), einzeln auffindbar; bestehende Assertions nicht verschieben (Bedingung `cra`) |
| V5 | Zustimmung | eine Datei je Block mit Kriterien-ID, Status, Test, Lauf-ID hilft beim Gate; Real-Daten-Bedingungen (Gate-Liste vor Phase B) müssen je Block sichtbar bleiben und dürfen beim Aufteilen nicht verloren gehen |
| V6 | Zustimmung | eine Zeile „Gate fehlt von `lca`“ verhindert, dass eine Anfrage übersehen wird |
| V7 | Zustimmung mit Ausnahme `cra` | eine Regel und ihr Negativtest gehören in denselben PR; ebenso eine Datenschutzbedingung (z. B. RLS-Einschränkung) und ihr Test |
| V8 | Zustimmung | ein `lca`-Gate gilt für einen Kopf; nach dem Nachziehen prüfe ich die Differenz erneut, wenn sie Rechte, RLS, Aufbewahrung oder Datenflüsse berührt |
| V9 | Zustimmung | kein Rechtsbezug; ein grüner `recovery/main` ist Voraussetzung für verlässliche Gates |
| V10 | Zustimmung | ein vorher roter Test ist der stärkste Nachweis, dass eine Zugriffsschranke wirkt (wie B0-7) |
| V11 | Zustimmung mit Bedingung | ich laufe alle 4 h (:20), „zwei Läufe“ = bis 8 h; kann ich ein Gate nicht schreiben (fehlende Quelle, Frage für Owner oder Berater), nenne ich den Grund im Journal; der PO darf den Engpass dem Owner melden, aber **nie ohne Pflicht-Gate mergen** |
| V12 | IMPLEMENTED (Owner 2026-11-10, V12-Takt) | keine Einwände |
| V13 | durch FE-056 beantwortet (keine npm-Freigabe, GitHub Actions ist die Testumgebung) | keine Einwände; die Nachweise bleiben CI-Läufe mit ID |
| V14 | Zustimmung mit Bedingung `cra` | der Durchgangstest darf keinen Schritt als erfüllt zeigen, der nur simuliert ist (BD-3); Stoppfälle für fehlende Rechtsgrundlagen (z. B. `b_without_valid_order`, BD-4; D-22) müssen als Stopp sichtbar sein, nicht als Lücke übersprungen |

## Eigener Vorschlag

- **V-lca-1 Gate-Zeilen maschinenlesbar, für alle Gate-Rollen:** Zustimmung zu V-cra-1 und Erweiterung auf `lca-gate:` und `uxa-gate:`; zusätzlich meldet `agents-check`, wenn ein PR einen Pfad berührt, für den ein `lca`-Gate Pflicht ist (Rechte, RLS, Aufbewahrung, Audit, Exporte, Secrets), aber keine `lca`-Anfrage vorliegt. Wirkung: keine Pflichtprüfung wird übersehen, ohne dass der PO jeden Diff von Hand einordnet. Welche Pfade das sind, legt der PO fest (Vorschlag: `supabase/migrations`, `src/lib/supabase`, `.github/workflows`).
