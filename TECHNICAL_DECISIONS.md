# NAVORA — Technical Decisions and Rejected Approaches

**Status:** Verlaufskonsolidierung, kein impliziter Beschluss für nie besprochene Anbieter. Implementierungen: **VERIFY AGAINST REPOSITORY**.

| Thema | Beschluss / Status | Begründung / Grenze |
|---|---|---|
| Gemeinsame Datenbasis | **DECIDED:** Supabase/PostgreSQL als Source of Truth | Kein Sidebar-spezifischer Mockzustand als Fachwahrheit |
| Webstack | **IMPLEMENTED alt:** Next.js/React/TypeScript/Tailwind; Next 16.3.4 später in Codespace | Versions- und Sicherheitsstand heute neu prüfen |
| Backend-Grenze | **DECIDED:** sensible Aktionen und Algorithmen serverseitig; konkrete Server Actions/RPC/Edge-Verteilung **OPEN** | Auth, Transaktion, Geheimnisse, Audit |
| Auth | **DECIDED:** SSR-Cookie-Sessions und serverseitige Prüfung; Paket installiert, Integration **UNKNOWN** | Browser-Login allein schützt Serverdaten nicht |
| Operations | **DECIDED:** Interventionen/Attention, nicht CRM/Matching-Aktionsseite | Operations bleibt schmal und risikogesteuert |
| Matching | **DECIDED:** Hard Filters + fachlicher Fit + Qualität + Teamentscheid serverseitig | Client-Scoring zu einfach, Gewichte geheim und versioniert |
| Geodaten | **IMPLEMENTED damalige DB:** PostGIS, Standortfelder, Distanzfunktion | Keine erfundenen Kilometer; Worker/Provider **OPEN** |
| Teammodell | **DECIDED:** selbstorganisiert und vielfach zuweisbar | Keine globale Ein-Fall-pro-Team-Regel |
| Field Tool | **DECIDED:** mobiler Einsatz mit Zeit/Dokumentation als Produktkern | Operations nicht Ersatz für Pflegekraft-Tool |
| KI | **DECIDED:** assistierend, quellgebunden, menschliche Freigabe | Keine autonome Diagnose/Bericht-/Billing-Freigabe |
| Assessments | **DECIDED:** autorisierte Instrumentenadapter statt InterRAI-Kopie | Urheber-/Nutzungsrechte und Versionspflege |
| Rule Engine | **DECIDED Ziel:** Quelle→Regel→UI→Ergebnis→Test/Audit | Konkrete DSL/Engine und Integration **OPEN** |
| Python | **OPEN/zu Beginn nicht bevorzugt** | TypeScript-Kern vermeidet frühe Service-Komplexität; Python für spätere Evaluation möglich |
| Hosting | **UNKNOWN:** Render nicht bestätigt | Betriebs-/Datenresidenzentscheid offen |
| Payments | **UNKNOWN:** Stripe nicht bestätigt | `orders` ist kein Nachweis |

## Verworfen [DEPRECATED]

- Manuelles Matching aus Operations: widerspricht Modulgrenze; angelegte Action wurde wieder entfernt.
- Produktives Matching als naive Client-Punktzahl und Browser-offene Gewichte.
- Harte Demo-Team- und Anfragedaten als vermeintliche Supabase-Daten.
- Statische 3-/18-km-Distanzen als tatsächliche Wegstrecke.
- InterRAI-Fragen/Scorings ohne Nutzungsrechte kopieren; reines „InterRAI 2.0“-Formular.
- KI als automatische klinische Entscheiderin oder Freigebende.
- Pauschales individuelles Pflegekräfte-Ranking nach Umsatz/Leistung/MQI.
- RLS `{public}` oder `authenticated` allein als Berechtigungsmodell.
- Blindes Entfernen öffentlicher Policies ohne getestete neue Auth-/RLS-Schicht.
- Ein Team auf einen Fall/Einsatz beschränken.
- `npm audit fix --force` ohne kontrollierte Versions-/Buildprüfung.

## Offene ADRs [OPEN]

1. Rechtsträger/Arbeitgeber/Leistungserbringer (Care-Genossenschaft vs. andere Struktur).
2. Organisations- und Versorgungskontext in bestehende Daten migrieren.
3. Finaler Hostingstandort, Render/Alternative und Datenresidenz.
4. Exakte klinische Instrumentrechte und LTCF-/PAG-/MQI-Versionen.
5. Rule DSL/Engine, Review-Governance und Auswirkungsanalyse.
6. Geocoding-Anbieter, Transportdistanz vs. Luftlinie, Feldzugriff.
7. KI-/Speech-Provider, Datennutzung, Schutz und Evaluation.
8. Verfügbarkeit, Kapazitätsfenster, Teamqualitätsmessung und Matching-Fairness.
9. Billing- und Payroll-Anbieter, Tarife, kantonale Anwendbarkeit, Stripe-Use Case.
10. Offline-Geräteschutz und Konfliktlösung.

Für jede neue Entscheidung ADR mit Kontext, Optionen, Fachowner, Sicherheitsfolge, Migration, Testplan und Reversibilität schreiben.
