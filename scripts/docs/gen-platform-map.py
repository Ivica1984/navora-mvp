#!/usr/bin/env python3
"""Generate the NAVORA platform floor plan (Grundriss) as SVG.

Docs-only helper for Blueprint V3.1 / Handbook V2.1 (FE-076). No app code.
Usage: python3 scripts/docs/gen-platform-map.py docs/product/blueprint-v3/diagrams/platform-map.svg
"""
import sys
from xml.sax.saxutils import escape

W, H = 1440, 1010
INK, MUTED, LINE, BG, CARD = "#022c22", "#44403c", "#d6d3d1", "#fafaf9", "#ffffff"
GREEN, GREEN_BG = "#065f46", "#ecfdf5"
BLUE, BLUE_BG = "#075985", "#f0f9ff"
AMBER, AMBER_BG = "#92400e", "#fffbeb"
out = []


def t(x, y, s, size=13, weight="400", fill=INK, anchor="start"):
    out.append(f'<text x="{x}" y="{y}" font-size="{size}" font-weight="{weight}" fill="{fill}" text-anchor="{anchor}">{escape(s)}</text>')


def box(x, y, w, h, fill=CARD, stroke=LINE, r=10, dash=None, sw=1.2):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    out.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"{d}/>')


def badge(x, y, label, kind):
    col = {"IMPL": (GREEN, GREEN_BG), "PLAN": (AMBER, AMBER_BG), "TEIL": (BLUE, BLUE_BG)}[kind]
    w = 12 + 7.0 * len(label)
    box(x, y, w, 18, fill=col[1], stroke=col[0], r=9, sw=1)
    t(x + w / 2, y + 13, label, 10.5, "600", col[0], "middle")


def layer(y, h, title, sub):
    box(20, y, W - 40, h, fill=BG, stroke=LINE, r=14)
    t(36, y + 24, title, 15, "700")
    t(36, y + 42, sub, 11.5, "400", MUTED)


out.append(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" font-family="Inter, Arial, sans-serif">')
out.append(f'<rect width="{W}" height="{H}" fill="#ffffff"/>')
t(20, 30, "NAVORA Plattform-Grundriss", 22, "700")
t(20, 52, "Sechs Portale · fünf Engines · eine Sicherheitsgrenze · drei getrennte Ledger. Status am 13.11.2026 auf recovery/main; Phase A, nur synthetische Daten.", 13, "400", MUTED)
badge(1030, 38, "IMPLEMENTED", "IMPL"); badge(1140, 38, "TEILWEISE", "TEIL"); badge(1232, 38, "PLANNED", "PLAN")

# Layer 1: portals
layer(70, 190, "1  Menschen und Portale", "Jede Rolle sieht nur ihre eigenen Daten. Eine Hauptaktion je Karte.")
portals = [
    ("/order", "Auftraggeber", "Heim, Spital, Privatperson", "Bedarf per Diktat oder Text,", "Felder bestätigen, Stand «gedeckt»", "PLAN"),
    ("/team", "Team-Dashboard", "selbstorganisiertes Team", "Angebot mit Begründung,", "Übernehmen mit einem Klick", "TEIL"),
    ("/field", "Pflegekraft mobil", "390 px, offline-first (offen)", "1-Tap Check-in, Diktat,", "Bericht prüfen und signieren", "TEIL"),
    ("/b2b-institution", "B2B-Heimsuite", "Heim für eigenes Personal", "Schichtplan, Ausfälle,", "Module 1 bis 3", "PLAN"),
    ("/family", "Angehörige", "nur mit Berechtigung", "freigegebene Updates,", "kein Chat, keine Akte", "PLAN"),
    ("/platform", "Betrieb und Coach", "NAVORA, ohne Akteneinsicht", "Abos, Ausnahmen,", "Vermittlung ohne Aufsicht", "TEIL"),
]
pw, gap = 222, 8
for i, (route, name, who, l1, l2, st) in enumerate(portals):
    x = 36 + i * (pw + gap)
    box(x, 124, pw, 124)
    t(x + 12, 146, route, 12, "700", GREEN)
    t(x + 12, 166, name, 15, "700")
    t(x + 12, 184, who, 11.5, "400", MUTED)
    t(x + 12, 206, l1, 12, "400", INK)
    t(x + 12, 222, l2, 12, "400", INK)
    badge(x + pw - 100, 133, {"IMPL": "IMPLEMENTED", "PLAN": "PLANNED", "TEIL": "TEILWEISE"}[st], st)

# Layer 2: app
layer(272, 84, "2  Next.js-App: Server Components und Befehle", "Keine Geschäftslogik im Browser. Jede Schreibaktion ist ein Datenbank-Befehl mit Rechteprüfung und Audit.")
for i, (s, st) in enumerate([("Server Components · Server Actions", "IMPL"), ("Web Push /api/push/dispatch", "IMPL"), ("/api/ai/* nur Muster 4", "PLAN")]):
    x = 735 + i * 228
    box(x, 288, 220, 52)
    t(x + 10, 309, s, 12, "600")
    badge(x + 10, 316, {"IMPL": "IMPLEMENTED", "PLAN": "PLANNED"}[st], st)

# Layer 3: engines
layer(368, 214, "3  Fünf Engines", "Zuerst deterministisch, dann KI, immer der Mensch. Ein KI-Score überspielt nie eine fehlende Qualifikation.")
engines = [
    ("Engine 1", "Matching", ["PLZ-Distanz, Qualifikation", "nach Matrix, Verfügbarkeit,", "bestätigte Merkmale", "→ nur Geeignete"], "TEIL", "deterministisch, SQL"),
    ("Engine 2", "KI-Orchestrierung", ["erkennt Felder,", "ordnet nur Geeignete,", "begründet in Worten", "→ schlägt vor"], "TEIL", "Vorschlagsbuch AIG1"),
    ("Engine 3", "Voice-to-Report", ["30 s Diktat →", "Entwurf mit Quelle", "je Satz →", "Mensch signiert"], "TEIL", "Signatur IMPLEMENTED"),
    ("Engine 4", "Finanzen", ["Stunden × Preis,", "Doppelabrechnung blockiert,", "Rechnung des Teams", "ohne Provision"], "TEIL", "Fakten IMPLEMENTED"),
    ("Engine 5", "Signale", ["nicht gedeckt, überfällig,", "Sicherheitssignal,", "Eskalation", "→ nie still verfallen"], "TEIL", "SIG1 SIG2 OPS1"),
]
ew = 270
for i, (n, name, lines, st, foot) in enumerate(engines):
    x = 36 + i * (ew + 7)
    box(x, 420, ew, 150, fill=CARD, stroke=GREEN if i == 0 else LINE, sw=1.6 if i == 0 else 1.2)
    t(x + 12, 442, n, 12, "700", GREEN)
    t(x + 12, 462, name, 15, "700")
    for j, l in enumerate(lines):
        t(x + 12, 484 + j * 17, l, 12, "400", INK)
    t(x + 12, 561, foot, 11, "600", MUTED)
    badge(x + ew - 92, 430, "TEILWEISE", st)

# Layer 4: database / security boundary
layer(594, 170, "4  Sicherheitsgrenze: Supabase Postgres (RLS auf jeder Tabelle, Befehle mit search_path='', Audit)", "Datenbank entscheidet Sicherheit, Qualifikation, Fristen und Beträge. Migrationen nur anhängend. Phase A: nur synthetische Daten.")
dbs = [("Aufträge und Fälle", "partner_requests, cases,", "matching_requests"), ("Teams und Qualifikation", "teams, Nachweise,", "Matrix v0.2 PROPOSED"),
       ("Einsätze und Berichte", "care_visits, visit_reports", "(Versionen, Signatur)"), ("KI-Vorschlagsbuch", "ai_suggestions,", "Bestätigung je Wert"),
       ("Audit", "audit_events,", "audit_read_log"), ("Signale", "safety_signals,", "exception_events")]
dw = 226
for i, (a, b, c) in enumerate(dbs):
    x = 36 + i * (dw + 5)
    box(x, 646, dw, 104)
    t(x + 12, 670, a, 13.5, "700")
    t(x + 12, 692, b, 12, "400", MUTED)
    t(x + 12, 709, c, 12, "400", MUTED)
    badge(x + 12, 722, "IMPLEMENTED", "IMPL")

# Layer 5: ledgers
layer(776, 150, "5  Drei getrennte Erlösströme (GMSEP, PLANNED)", "Kein Fremdschlüssel und keine Ansicht verbindet die Ledger. Eine Pflegerechnung enthält nie eine NAVORA-Position.")
ledgers = [("Team-Ledger", "Pflegeerlös gehört dem Team", "Rechnung Team → Auftraggeber", GREEN, GREEN_BG),
           ("NAVORA-Ledger A", "feste Monatsgebühr je Mitglied", "nie Provision, nie je Stunde", BLUE, BLUE_BG),
           ("NAVORA-Ledger B", "B2B-Lizenzen je Modul", "Heim oder Spital als Softwarekunde", BLUE, BLUE_BG)]
lw = 440
for i, (a, b, c, col, bg) in enumerate(ledgers):
    x = 36 + i * (lw + 26)
    box(x, 828, lw, 84, fill=bg, stroke=col, sw=1.5)
    t(x + 14, 852, a, 15, "700", col)
    t(x + 14, 874, b, 12.5, "600", INK)
    t(x + 14, 893, c, 12, "400", MUTED)
    if i < 2:
        xs = x + lw + 13
        out.append(f'<line x1="{xs}" y1="832" x2="{xs}" y2="908" stroke="#b91c1c" stroke-width="2" stroke-dasharray="5 4"/>')

# Side notes: AI and human guard rail
box(20, 940, 700, 56, fill=AMBER_BG, stroke=AMBER, r=10)
t(36, 962, "KI im eigenen Schweizer Rechenzentrum (Muster 4) · PLANNED", 13, "700", AMBER)
t(36, 982, "D-35 Regel A: keine Klienten- oder Personaldaten an einen externen KI-Dienst. Phase A nur synthetisch.", 12, "400", INK)
box(730, 940, 690, 56, fill=GREEN_BG, stroke=GREEN, r=10)
t(746, 962, "Der Mensch entscheidet und signiert", 13, "700", GREEN)
t(746, 982, "Auftraggeber bestätigt · Team übernimmt · Pflegekraft signiert · keine zentrale Disposition", 12, "400", INK)

# vertical flow arrows between layers
for y1, y2 in [(260, 272), (356, 368), (582, 594), (764, 776)]:
    for x in (360, 720, 1080):
        out.append(f'<path d="M{x} {y1} L{x} {y2}" stroke="{GREEN}" stroke-width="2"/>')
out.append("</svg>")
open(sys.argv[1], "w").write("\n".join(out))
