# NAVORA

Du arbeitest am NAVORA-Projekt.

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
