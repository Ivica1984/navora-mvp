# NAVORA Vergleich der Abrechnungsmodelle

> **Hinweis 2026-11-12 15:39 (`po`, FE-070):** Im Teamgeschäft zahlt das Team (bzw. seine Struktur) NAVORA eine **feste monatliche Plattformgebühr ohne Provision**; F1 und F2 sind damit ausgeschlossen, und «Käufer» in §1 ist für das Teamgeschäft das Team, nicht die Organisation mit Betriebsbewilligung. Ob F3 oder F5 gilt und welche Beträge, bleibt eine Preisfrage beim Founder (D-14). Überarbeitung mit FE-070 Lieferung 3; Abweichung in [`FE-070_LIEFERUNG_2.md`](FE-070_LIEFERUNG_2.md) §1.5.

**Besitzer:** Product Owner (`po`) · **Stand:** 2026-11-06 (Europe/Zurich) · **Auftrag:** Founder-Schreiben 2026-11-06, Punkt 5 (FE-023) · **Status:** Vorbereitung für D-14. **Kein Preis ist gewählt** (F3 ist nur eine mögliche Kalkulationsbasis). Dieses Dokument nennt keine Frankenbeträge: Preise und Kosten sind UNKNOWN, bis Phase A die Kosten pro Nutzung misst. Alle Beispiele rechnen mit einer neutralen Einheit **P** (Gebühr pro Abrechnungseinheit), nicht mit Franken.

**Rechtlicher Hinweis:** Ob und wie eine Plattformgebühr aus KVG-finanzierten Leistungen getragen werden darf, ist eine Rechtsfrage. `lca` hat sie in D-14 teilweise beantwortet; für Basel (BS, BL) und Pflegeheime ist sie neu zu prüfen (FE-019, FE-022). Dieses Dokument trifft dazu keine Aussage.

---

## 1. Wer zahlt, wer nutzt, wofür NAVORA Umsatz erzielt

| Rolle | Wer | Beziehung zu NAVORA |
|---|---|---|
| **Käufer (Vertragspartner, zahlt die Gebühr)** | die Organisation mit Betriebsbewilligung: Spitex-Organisation, Pflegeheim, später Spital oder teameigener Anbieter | schliesst den Plattformvertrag, zahlt NAVORA |
| **Nutzer** | Teammitglieder (Pflegefachpersonen, Pflegeassistenz), Administration, Operations; später Angehörige (nur lesend, D-40) | nutzen NAVORA, zahlen nichts |
| **Leistungserbringer** | die Organisation (rechtlich), die Teams (tatsächlich) | erbringt die Pflege, rechnet sie ab |
| **Kostenträger der Pflege** | Krankenversicherer, Kanton/Gemeinde (Restfinanzierung), betreute Person (Eigenanteil) | zahlen die Pflege, **nicht** NAVORA |
| **Betreute Person** | Klient:in, Bewohner:in | nutzt NAVORA nicht direkt |

**Wofür NAVORA Umsatz erzielt:** für den Betrieb der Plattform (Planung, Dokumentation, Koordination, Abrechnungsvorbereitung, Qualität, Auswertung, KI-Arbeitsabläufe) und deren Pflege, Sicherheit und Support. NAVORA verdient **nicht** an der Menge oder Art der erbrachten Pflege; das schützt die Regel „Einkommen folgt der Pflege, nicht der Einstufung“ (D-14).

## 2. Kostenarten von NAVORA (alle Beträge UNKNOWN)

| Kostenart | Treiber | Verhalten | Messung in Phase A |
|---|---|---|---|
| Hosting (Datenbank, App, Backups, CH/EU) | Organisationen, Datenmenge | fix je Umgebung, wächst stufenweise | Rechnung der genehmigten Pläne (D-2) |
| KI-Verarbeitung | Anzahl Entwürfe und Prüfungen | variabel je Nutzung | Kosten je Dokumentationsentwurf und je Abrechnungsprüfung auf synthetischen Daten (nur mit Anbieter, Frage O-4) |
| Support und Einführung | Organisationen, neue Teams | fix je Einführung, dann laufend | Stunden je simulierter Einführung |
| Sicherheit, Datenschutz, Compliance | Organisationen, Kantone | fix | externe Prüfungen (M10) |
| Weiterentwicklung | Produkt | fix | – |
| Zahlungsausfall, Vertrieb | Organisationen | variabel | – |

## 3. Modelle im Vergleich

| Modell | Formel (Gebühr pro Monat) | Wer zahlt | Neutral gegenüber Pflegemenge und Einstufung | Planbarkeit für den Käufer | Skaliert NAVORA-Umsatz mit Nutzen | Passt zu Pflegeheim | Bewertung |
|---|---|---|---|---|---|---|---|
| **F1** pro abrechenbare Stunde | P × Stunden | Organisation | **nein**: NAVORA verdient an mehr Stunden | mittel | ja | schlecht (Pflegeheim rechnet nicht in Stunden ab) | nicht empfohlen |
| **F2** Prozent vom Umsatz | p % × Pflegeumsatz | Organisation | **nein**: verdient an höherer Einstufung | gering | ja | mittel | nicht empfohlen |
| **F3** pro aktivem Teammitglied | P × aktive Mitglieder | Organisation | ja | hoch | mit der Teamgrösse | ja | **Kandidat** |
| **F4** pro betreuter Person | P × betreute Personen | Organisation | ja (unabhängig von Besuchsdauer) | mittel (Belegung schwankt) | mit Klient:innen | ja, als **pro belegtem Platz** (F4b) | Kandidat für Pflegeheime |
| **F5** Pauschale je Organisation nach Stufe | Stufe S, M, L | Organisation | ja | sehr hoch | stufenweise | ja | einfach, aber Stufengrenzen erzeugen Sprünge |
| **F6** Grundgebühr + pro Mitglied | G + P × aktive Mitglieder | Organisation | ja | hoch | ja | ja | **Kandidat**: deckt fixe Kosten je Organisation |
| **F7** KI-Zusatz nach Nutzung | Basis + q × KI-Vorgänge | Organisation | teilweise (Anreiz zu mehr KI-Nutzung) | gering | ja | ja | nur als spätere Ergänzung, wenn KI-Kosten stark variieren |

„Aktives Teammitglied“ braucht eine prüfbare Definition (z. B. mindestens ein bestätigter Arbeitstag oder Einsatz im Monat). NAVORA hat diese Daten bereits (WORK1, Einsatzereignisse); IMPLEMENTED auf synthetischen Daten.

## 4. Wirtschaftliche Folgen für kleine und grosse Teams (Beispiel in Einheiten P, keine Franken)

Beispielannahmen (nur zur Veranschaulichung, keine Daten): Team K mit 6 Mitgliedern zu durchschnittlich 50 % Pensum; Team G mit 12 Mitgliedern zu 80 %. Grundgebühr in F6: G = 4P.

| Modell | Team K: Gebühr | K: pro Vollzeitstelle | Team G: Gebühr | G: pro Vollzeitstelle | Folge |
|---|---|---|---|---|---|
| F3 | 6P | 6P ÷ 3,0 = **2,0P** | 12P | 12P ÷ 9,6 = **1,25P** | Teilzeit-starke Teams zahlen pro geleisteter Arbeit mehr |
| F3 mit Pensum-Gewichtung | 3,0P | 1,0P | 9,6P | 1,0P | fair pro Arbeit; braucht bestätigte Pensen (Lohnnähe, `lca`) |
| F6 (G = 4P) | 4P + 6P = 10P | 3,3P | 4P + 12P = 16P | 1,7P | kleine Organisationen tragen die Fixkosten stärker |
| F5 (S = 8P, M = 14P) | 8P | 2,7P | 14P | 1,5P | einfach; Sprung an der Stufengrenze |

Lesart: Jedes kopfbasierte Modell belastet kleine und teilzeit-starke Teams relativ stärker. Das widerspricht teilweise dem Ziel „höheres Pflegeeinkommen“ (Wert 3), weil gerade kleine, neue teameigene Anbieter am meisten tragen. Eine Pensum-Gewichtung oder ein Einführungsrabatt für junge Teams gleicht das aus. Ob eine Pensum-Gewichtung zulässig ist (Lohndaten), prüft `lca`.

## 5. Empfehlung (PO, nicht entschieden)

1. **Engere Wahl: F3 (mit Pensum-Gewichtung als Variante) und F6.** Für Pflegeheime zusätzlich **F4b pro belegtem Platz** prüfen, weil die Pflegeheim-Finanzierung platz- und tagesbezogen ist (Rechtsgrundlage UNKNOWN, `lca`).
2. **F1 und F2 nicht weiterverfolgen:** sie machen NAVORA abhängig von Pflegemenge oder Einstufung.
3. **Entscheid D-14 erst nach Phase A**, wenn Kosten je aktivem Mitglied (Hosting, KI, Support) aus der Simulation gemessen sind. Bis dahin gilt: kein Preis festgelegt, keine Preiszusage an Dritte.
4. Mit dem Preis gemeinsam entscheiden: Teamüberschuss (S1-S4 in D-14), damit die Gebühr das Pflegeeinkommen nicht schmälert.

## 6. Was fehlt (UNKNOWN), und wer es liefert

| Fehlende Angabe | Liefert | Wann |
|---|---|---|
| Kosten je Umgebung (Hosting) | owner (D-2), `eng` | mit D-2 |
| KI-Kosten je Vorgang | `eng`, `aia` | Phase A, wenn ein Anbieter für synthetische Daten freigegeben ist (O-4) |
| Zulässigkeit der Gebühr aus KVG-finanzierten Leistungen in BS/BL und im Pflegeheim | `lca` | vor dem Preisentscheid |
| Zahlungsbereitschaft der Käufer | owner (Gespräche, Phase B) | Phase B |
