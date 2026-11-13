# Blueprint V3 und Handbook V2: Bilder und PDFs

Begleitordner zu [Blueprint V3.1](../ARCHITECTURE_REVIEW_AND_IMPLEMENTATION_BLUEPRINT_V3.md) und [Architecture Handbook V2.1](../../architecture/ARCHITECTURE_HANDBOOK_V2.md) (FE-075, FE-076). Nur Dokumentation, kein Anwendungscode, nur synthetische Daten.

| Ordner | Inhalt | Quelle |
|---|---|---|
| `wireframes/` | sechs Wireframes: `/order`, `/team`, `/field`, `/b2b-institution`, `/family`, `/platform` | `uxa`, 2026-11-13 |
| `diagrams/` | Grundriss, Auftragsfluss Teil A und B, Engines und Tabellen, Geldfluss je Schicht (SVG, erzeugt); ERD in drei Ausschnitten (Mermaid, `eng`) | `scripts/docs/gen-*.py`; `eng` |
| `pdf/` | PDF-Fassungen zur Founder-Freigabe | `scripts/docs/build-pdf.py` |

Neu erzeugen (lokal, ohne Netz):

```
python3 scripts/docs/gen-platform-map.py docs/product/blueprint-v3/diagrams/platform-map.svg
python3 scripts/docs/gen-e2e-swimlane.py docs/product/blueprint-v3/diagrams
python3 scripts/docs/gen-engine-map.py docs/product/blueprint-v3/diagrams/engine-map.svg
python3 scripts/docs/gen-value-chain.py docs/product/blueprint-v3/diagrams/value-chain.svg
python3 scripts/docs/build-pdf.py docs/product/ARCHITECTURE_REVIEW_AND_IMPLEMENTATION_BLUEPRINT_V3.md docs/product/blueprint-v3/pdf/NAVORA_Blueprint_V3.1.pdf --title "Architecture Blueprint V3.1"
python3 scripts/docs/build-pdf.py docs/architecture/ARCHITECTURE_HANDBOOK_V2.md docs/product/blueprint-v3/pdf/NAVORA_Architecture_Handbook_V2.1.pdf --title "Architecture Handbook V2.1"
```
