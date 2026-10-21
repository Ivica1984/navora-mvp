# NAVORA

Du arbeitest am NAVORA-Projekt.

ZUSAMMENARBEIT (offiziell, vom Owner am 2026-10-21 freigegeben)

Jeder Agent beginnt mit dem Collaboration Layer in docs/agents/:

docs/agents/README.md                 (Protokoll, Rollen, Regeln)
docs/agents/NEXT_CAPABILITY.md        (Product Owner: was als Nächstes gebaut wird)
docs/agents/IMPLEMENTATION_STATUS.md  (Engineering: Stand je Item)
docs/agents/OPEN_DECISIONS.md         (offene Entscheide: Owner, Empfehlung, blockiert)
docs/agents/JOURNAL.md                (Übergaben, neueste zuerst)

Schreibe nur die Abschnitte deiner Rolle, halte die Dateien bei jeder Änderung aktuell
und prüfe sie mit `npm run agents:check` (läuft auch in CI).

Lies vor jeder Architektur- oder Codeänderung:

MASTER_CONTEXT.md
ARCHITECTURE.md
DOMAIN_RULES.md
TECHNICAL_DECISIONS.md
CURRENT_IMPLEMENTATION_STATUS.md

WICHTIG

Diese Dokumente sind eine Übergabedokumentation.

Der tatsächliche Repository-Code hat Vorrang.

Wenn Dokumentation und Code widersprüchlich sind:
1. dokumentiere die Abweichung
2. analysiere die Ursache
3. ändere nichts automatisch
4. schlage eine sichere Lösung vor

Arbeitsprozess:

1 Analyse
2 Architekturprüfung
3 Plan
4 Implementierung
5 Build
6 Tests
7 Regressionstest
8 Dokumentation

Behaupte niemals, Tests ausgeführt zu haben, wenn sie nicht ausgeführt wurden.

Kennzeichne Aussagen immer als:

IMPLEMENTED
PLANNED
OPEN
UNKNOWN

Wichtige Prinzipien:

- Patientensicherheit vor Geschwindigkeit
- Datenschutz vor Komfort
- Reale Daten vor Annahmen
- Verifizierte Regeln vor KI-Annahmen
- Teamautonomie vor zentraler Disposition
- Keine Erfindung von Daten
- Keine Erfindung von medizinischen Regeln
- Keine Erfindung von PAG-, MQI- oder LTCF-Logik
