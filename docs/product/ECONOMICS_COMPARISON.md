# NAVORA Wirtschaftliche Vergleichsrechnung: direkter Teamauftrag gegenüber Temporär- und Spitex-Strukturen; B2B-Module getrennt

**Besitzer:** Product Owner (`po`) · **Version:** 1.0, 2026-11-06 22:30 (Europe/Zurich) · **Auslöser:** FE-040 · **Konstellationen:** [`BUSINESS_MODELS_AND_CONSTELLATIONS.md`](BUSINESS_MODELS_AND_CONSTELLATIONS.md) · **Gebührenmodelle:** [`PRICING_MODEL_COMPARISON.md`](PRICING_MODEL_COMPARISON.md), Paket D-14

**Lesehinweis:** Jede Zahl ist entweder **[B] belegt** (Quelle in §6, mit Datum und Einschränkung) oder **[A] Annahme** (vom PO gesetzt, zu ersetzen). Ergebnisse aus Annahmen sind **Szenarien, keine Prognose**. Dass ein direkter Teamauftrag das Einkommen der Pflegenden erhöht, ist **nicht bewiesen** (HYP-3, FE-032). Die Rechnung zeigt, **unter welchen Bedingungen** es möglich ist und wann nicht. Keine Rechtsauskunft: Vertragsform, Bewilligung und Abrechnungsweg sind offen (D-44).

---

## 1. Eingangsgrössen

| ID | Grösse | Wert | Art | Einschränkung |
|---|---|---|---|---|
| B1 | Spitex-Tarif Basel-Stadt ab 2026-01-01, je Stunde (Gesamttarif: Versicherer + Kanton/Gemeinde + Klient) | Bedarfsabklärung 96.00 (76.90 + 11.45 + 7.65); Behandlungspflege 90.00 (63.00 + 19.35 + 7.65); Grundpflege 80.00 (52.60 + 19.75 + 7.65); zweite Tabelle: 80.00 / 80.00 / 70.00 ohne Klientenanteil | [B] | Für welche Leistungserbringer die Tabelle gilt (öffentliche/private Spitex, freiberuflich) und ob Tabelle 2 die zweite Stunde ist, steht nicht eindeutig im Dokument (L-9) |
| B2 | Temporärpersonal im Pflegeheim kostet „rund 1.7 Mal so viel wie Festangestellte“ | Faktor 1.7 | [B] | eine Trägerschaft (Domicil Bern, 22 Heime), SRF 2025-02-13; Bezugsbasis (Stundenkosten oder Vollkosten) nicht angegeben |
| B3 | Temporärpersonal pro Stunde „etwa 30 Prozent teurer“ (direkte Kosten); unter Einbezug indirekter Kosten „nur etwa 10 %“ teurer | Faktor 1.3 bzw. 1.1 | [B] | Nau 2023-12-15; 30 % ist Hörensagen im Artikel; die 10 bis 11 % stammen aus einer ZHAW-Studie 2018 **im Auftrag eines Personalverleihers** (careanesth) |
| B4 | Ersatzsuche kostet Führungskräfte rund 55 Minuten je Absenz | 55 min | [B] | ZHAW 2018 (dieselbe Auftragsstudie wie B3) |
| B5 | Durchschnittslohn Pflegefachperson HF Spitex (mit besonderen Aufgaben) | 40.21 CHF/h, 6'754.92 CHF/Monat | [B] | Lohnbuch Schweiz (Kanton Zürich, Ausgabe 2025, zitiert von medi-karriere); **nicht Basel**; ob 13. Monatslohn enthalten ist, UNKNOWN |
| B6 | Durchschnittslohn FaGe EFZ Spitex | 28.03 CHF/h, 4'708.46 CHF/Monat | [B] | wie B5 |
| A1 | Arbeitgeberkosten auf dem Lohn (Sozialversicherungen, BVG, UVG, KTG, FAK, Ferien-/Feiertagsanteil, soweit nicht im Lohn) | 20 % | [A] | Gesetzlich fest sind nur Teile (AHV/IV/EO, ALV); Rest je Vertrag und Kanton UNKNOWN |
| A2 | Gemeinkosten eines Teams (Verwaltung, Haftpflicht- und Betriebsversicherung, Weiterbildung, Material, Buchhaltung) | 10 % des Umsatzes | [A] | ohne NAVORA-Gebühr; real je Rechtsform (D-44) |
| A3 | NAVORA-Plattformgebühr, umgerechnet | 4 % des Umsatzes | [A] | **kein Preis**; D-14 (F3 je aktives Mitglied/Monat) ist offen; die Umrechnung in % dient nur dem Vergleich und ist kein Vorschlag für eine prozentuale Gebühr (L-10) |
| A4 | Auslastung: Anteil der angebotenen Stunden, die tatsächlich gebucht werden | 100 %, 85 %, 70 % | [A] | Hauptrisiko für das Einkommen (siehe §2.3) |
| A5 | Anteil verrechenbarer direkter Pflegezeit an der bezahlten Arbeitszeit, Spitex heute vs. NAVORA-Hypothese | 60 % vs. 70 % | [A] | NAVORA-Hypothese HYP-1; Messung M-15 erst auf synthetischem Seed, Phase-B-Ausgangswert fehlt |

---

## 2. KON-1: Pflegeheim überbrückt einen Ausfall (Temporärbüro vs. direkter Teamauftrag)

### 2.1 Was das Heim heute zahlt (je Stunde einer HF-Pflegefachperson)

| Position | Rechnung | CHF/h | Art |
|---|---|---|---|
| eigene festangestellte HF (Arbeitgeberkosten) | 40.21 × 1.20 | 48.25 | B5, A1 |
| Temporär, Faktor 1.7 | 48.25 × 1.7 | 82.03 | B2 auf A1-Basis |
| Temporär, Faktor 1.3 | 48.25 × 1.3 | 62.73 | B3 |
| Temporär, Faktor 1.1 | 48.25 × 1.1 | 53.08 | B3 (Auftragsstudie) |

Die Spanne 53 bis 82 CHF/h zeigt, wie unsicher die Ausgangslage ist. Für eine Entscheidung braucht es die realen Rechnungen eines Heims (Phase B, D-42).

### 2.2 Was beim direkten Teamauftrag bei der Pflegeperson bleibt (Bruttolohn-Äquivalent je gebuchter Stunde)

Formel: *Bruttolohn je Stunde* = Preis an das Heim × (1 − A2 − A3) ÷ (1 + A1)

| Preis an das Heim (CHF/h) | Bruttolohn-Äquivalent (CHF/h) | gegenüber B5 (40.21) | Ersparnis des Heims gegenüber Temporär 1.7 | Lesart |
|---|---|---|---|---|
| 82.03 (= Temporärpreis 1.7) | 58.79 | +46 % | 0 % | Obergrenze: Heim spart nichts, Team erhält die ganze Marge |
| 70.00 | 50.17 | +25 % | 14.7 % | geteilte Ersparnis |
| 65.00 | 46.58 | +16 % | 20.8 % | geteilte Ersparnis |
| 58.00 | 41.57 | +3 % | – | kaum Vorteil für die Pflegenden |
| 55.00 | 39.42 | −2 % | – | **kein** Einkommensvorteil |

Gebühr und Gemeinkosten machen hier 14 % des Preises aus [A2, A3]. NAVORAs Gebühr (4 % [A]) ist damit kleiner als die Differenz zwischen Temporärpreis und Festanstellung (B2/B3), aber nicht vernachlässigbar.

### 2.3 Auslastung: das Hauptrisiko

Ein festangestellter Lohn ist garantiert; das Team wird nur für gebuchte Stunden bezahlt.

| Preis | Auslastung 100 % | 85 % | 70 % |
|---|---|---|---|
| 70.00 | 50.17 (+25 %) | 42.64 (+6 %) | 35.12 (−13 %) |
| 65.00 | 46.58 (+16 %) | 39.59 (−2 %) | 32.61 (−19 %) |

*(Bruttolohn-Äquivalent je **angebotener** Stunde, gegenüber B5.)* Ein Einkommensvorteil entsteht also nur, wenn das Team **ausgelastet** ist, etwa durch Rahmenverträge mit mehreren Heimen, die Kombination mit ambulanten Einsätzen (KON-4) oder eine Grundauslastung durch einen Partner (D-12). Das ist eine Produkt- und Vertragsfrage, keine Softwarefrage.

### 2.4 Was offen bleibt

- Vertragsform (Personalverleih mit GAV-Mindestlöhnen und Bewilligung oder Auftrag) verändert Kosten und Pflichten (L-7).
- Haftung und Versicherung bei Fehlern im Einsatz (L-7, D-44).
- Ob das Heim überhaupt externe, nicht verliehene Teams einsetzen darf und wie es sie in seine Stellenplanvorgaben einrechnet (D-25, L-2).

---

## 3. KON-4/KON-3b: ambulante Pflege (bisherige Spitex vs. selbstorganisiertes Team)

Formel: *Lohnbudget je bezahlter Stunde* = Tarif × verrechenbarer Anteil × (1 − A2 − A3) ÷ (1 + A1)

| Leistung (BS 2026, erste Tabelle) | Tarif [B1] | verrechenbar 60 % [A5] | verrechenbar 70 % [A5] |
|---|---|---|---|
| Behandlungspflege | 90.00 | 38.70 | 45.15 |
| Grundpflege | 80.00 | 34.40 | 40.13 |

Lesart: Bei gleichem Tarif steigt das mögliche Lohnbudget nur, wenn **mehr bezahlte Zeit direkte, verrechenbare Pflege** ist (weniger Wege, Koordination, Doppeldokumentation: NAVORAs Nordstern, HYP-1) **oder** die Gemeinkosten sinken. Die heutige Gemeinkostenquote einer Spitex-Organisation ist hier nicht belegt (UNKNOWN); A2 = 10 % für ein Team ist eine Annahme, keine Messung. Ob die Restfinanzierung (Kanton/Gemeinde-Anteil in B1) einem Team gleich zusteht wie einer Organisation mit Leistungsauftrag, ist offen (L-9).

---

## 4. B2B-Module (getrennt vom Teamgeschäft)

Kein Preis ist festgelegt. NAVORAs eigene Kosten sind UNKNOWN (`PRICING_MODEL_COMPARISON.md` §2). Gezeigt wird nur der **Nutzen beim Kunden**, der eine Preisobergrenze begründen kann:

| Modul | Nutzen beim Kunden (Formel) | Beispiel mit markierten Werten | Messung in Phase A |
|---|---|---|---|
| **M-PLAN** KI-Planung und Ausfallkoordination für eigene Mitarbeitende | (a) vermiedene Temporärstunden × (Temporärkosten − eigene Kosten); (b) Koordinationszeit je Absenz × Anzahl Absenzen × Stundenkosten Führung | (a) 100 vermiedene Stunden/Monat × (82.03 − 48.25) = **3'378 CHF/Monat** [B2, B5, A1; 100 h ist A]; (b) 55 min [B4] × 40 Absenzen/Monat [A] × 60 CHF/h Führung [A] = **2'200 CHF/Monat** | Zeit bis zur bestätigten Vertretung, Anteil ohne Vorschlag, Anteil Eskalationen (QUAL1-Simulation, AN3) |
| **M-DOK** Diktat, Protokoll, Bericht mit Prüfung und Freigabe (Add-on) | gesparte Dokumentationsminuten je Bericht × Berichte × Stundenkosten Pflege − Prüfzeit | UNKNOWN: M-16 (Akte je Bericht) und Prüfzeit noch nicht gemessen (AUT-54); keine Zahl ohne Messung | M-16 auf synthetischem Seed vor dem Bau (AUT-54) |
| **Betriebsplattform** (KON-2) | Summe der Module plus weniger Systeme und Schnittstellen | UNKNOWN | NH-A-Briefs |

**Preisgrundlagen (Vorschlag, nicht entschieden, FD-29):** je Bett oder je Mitarbeitende/Monat für M-PLAN, je freigegebenem Bericht oder je Nutzerin für M-DOK. Kein Preis wird ohne Kostenbasis und ohne Founder-Entscheid gesetzt.

---

## 5. Ergebnis und was es nicht ist

1. Ein Einkommensvorteil für Pflegende im Teamauftrag ist **rechnerisch möglich**, wenn das Heim heute deutlich über den Kosten einer Festanstellung zahlt (B2) und das Team gut ausgelastet ist. Bei tiefem Temporärzuschlag (B3, 10 %) oder schlechter Auslastung **verschwindet** er.
2. Die NAVORA-Gebühr ist in diesen Szenarien kleiner als die heutige Vermittlungsdifferenz, muss aber transparent und für kleine Teams tragbar bleiben (D-14, Fixkostenfrage in `PRICING_MODEL_COMPARISON.md` §4).
3. Für die ambulante Pflege hängt der Vorteil an der direkten Pflegezeit (HYP-1), nicht am Tarif. Der Tarif ist vorgegeben.
4. **Nicht bewiesen** ist: dass Heime Teams direkt beauftragen dürfen und wollen, dass Teams ausgelastet sind, dass die Gemeinkosten tiefer sind, dass die direkte Pflegezeit steigt.

**Nächste Schritte:** Phase A misst die Planungs- und Ausfallkennzahlen auf synthetischen Daten (QUAL1, AN3, M-15); Phase B ersetzt B2/B3 durch die Rechnungen des Pilotheims und A1/A2 durch die Zahlen der gewählten Rechtsform (D-44, D-42). `csa` wird um eine Gegenprüfung der Annahmen gebeten.

---

## 6. Quellen (gelesen 2026-11-06)

- [B1] Gesundheitsdepartement Basel-Stadt, Spitextarife ab 1.1.2026: <https://media.bs.ch/original_file/a7e3981116985890d289f28a78b01dceb5e872da/spitextarife-bs-2026-01-01.pdf>
- [B2] SRF News, Nora Meuli, „Pflegeheime: Mit eigenen Personalpools gegen teure Temporäre“, 2025-02-13: <https://www.srf.ch/news/wirtschaft/fachkraeftemangel-in-der-pflege-pflegeheime-mit-eigenen-personalpools-gegen-teure-temporaere>
- [B3] Nau.ch, „Pflegende kündigen Festanstellung und arbeiten temporär“, 2023-12-15: <https://www.nau.ch/news/schweiz/pflegende-kundigen-festanstellung-und-arbeiten-temporar-66670993>; T. Brand, F. Liberatore, A. Meyer, „Temporärkräfte in der Pflege – flexibel und nur wenig teurer“, *Competence* 10/2018 (im Auftrag von careanesth): <https://digitalcollection.zhaw.ch/bitstream/11475/13221/2/2018_Brand-Liberatore-Meyer_Temporaerkraefte-Pflege-flexibel_Hplus.pdf>
- [B4] wie B3 (ZHAW 2018).
- [B5], [B6] medi-karriere.ch, „Lohnbuch Schweiz“ (zitiert Volkswirtschaftsdirektion Kanton Zürich, Lohnbuch 2025): <https://www.medi-karriere.ch/magazin/lohnbuch-schweiz-2025/>
