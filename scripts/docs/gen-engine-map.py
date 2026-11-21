#!/usr/bin/env python3
"""Generate the engine / table map (which engine reads and writes which table, where a human confirms).

Docs-only helper for Handbook V2.1 §2.0a (FE-076). Content from the `eng` review of 2026-11-13. No app code.
Usage: python3 scripts/docs/gen-engine-map.py docs/product/blueprint-v3/diagrams/engine-map.svg
"""
import sys
from xml.sax.saxutils import escape

W, H = 1520, 900
INK, MUTED, LINE = "#022c22", "#44403c", "#d6d3d1"
GREEN, GREEN_BG = "#065f46", "#ecfdf5"
BLUE, BLUE_BG = "#075985", "#f0f9ff"
AMBER, AMBER_BG = "#92400e", "#fffbeb"
o = []


def t(x, y, s, size=13, weight="400", fill=INK, anchor="start"):
    o.append(f'<text x="{x:.1f}" y="{y:.1f}" font-size="{size}" font-weight="{weight}" fill="{fill}" text-anchor="{anchor}">{escape(s)}</text>')


def rect(x, y, w, h, fill, stroke, r=8, dash=None, sw=1.4):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    o.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"{d}/>')


STEPS = [
    ("Engine 2", "Erfassung", "PLAN, regelbasiert zuerst", [], ["ai_suggestions"], "Auftraggeber bestätigt jedes Feld → partner_requests (Befehl)"),
    ("Engine 1", "Harte Filter", "IMPL Region + HF; PLAN PLZ, Matrix, Slot, Merkmal",
     ["partner_requests", "postcodes (PLAN)", "member_attributes (PLAN)", "qual_matrix_cells", "member_absences", "care_visits"],
     ["matching_requests", "Ausschlussgründe"], None),
    ("Engine 2", "Rangfolge", "PLAN, nur unter Geeigneten", ["matching_requests"], ["ai_suggestions (Reihenfolge)"], None),
    ("Engine 1", "Kaskade", "PLAN; heute RET1 Erstzugriff IMPL", ["Reihenfolge"], ["matching_offer_steps (PLAN)"],
     "Team übernimmt → team_decisions (decide_matching_request)"),
    ("Engine 5", "Deckung, Signale", "SIG1 SIG2 OPS1 IMPL; Deckungsstand PLAN", ["matching_offer_steps", "care_visits"],
     ["exception_events", "signal_deliveries"], "Operations behandelt nur Ausnahmen"),
    ("Engine 3", "Bericht", "Entwurf getippt IMPL; Diktat PLAN", ["care_visits", "Eingabe der Pflegekraft"], ["visit_reports (Entwurf)"],
     "Pflegekraft prüft und signiert → visit_reports final (sign_report)"),
    ("Engine 4", "Billing", "Fakten IMPL; Rechnung PLAN", ["visit_reports (final)", "working_time_facts"],
     ["billable_facts", "invoices, invoice_lines (PLAN)"], "Team gibt die Rechnung frei"),
]

o.append(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" font-family="Inter, Arial, sans-serif">')
o.append('<defs><marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0 0 L10 5 L0 10 z" fill="#022c22"/></marker></defs>')
o.append(f'<rect width="{W}" height="{H}" fill="#ffffff"/>')
t(20, 34, "Engines und Tabellen: wer liest, wer schreibt, wo der Mensch bestätigt", 23, "700")
t(20, 60, "Prüfung eng 13.11.2026 auf recovery/main 227e742. Namen mit PLAN sind Vorschläge von eng (OPEN bis zur ADR). Keine Engine schreibt team_decisions: keine zentrale Disposition (FE-039).", 13.5, "400", MUTED)

n = len(STEPS)
gap = 14
cw = (W - 40 - gap * (n - 1)) / n
ROW_H, ROW_E, ROW_R, ROW_W = 92, 250, 400, 620
# row labels
for y, lab, col in [(ROW_H, "Mensch bestätigt", GREEN), (ROW_E, "Engine", BLUE), (ROW_R, "liest", MUTED), (ROW_W, "schreibt", AMBER)]:
    pass
for i, (eng, name, status, reads, writes, human) in enumerate(STEPS):
    x = 20 + i * (cw + gap)
    # human
    if human:
        rect(x, ROW_H, cw, 120, GREEN_BG, GREEN)
        t(x + 10, ROW_H + 22, "Mensch", 12, "700", GREEN)
        words = human.split(" ")
        line, ly = "", ROW_H + 42
        for w_ in words:
            if len(line + " " + w_) > 24:
                t(x + 10, ly, line.strip(), 12.5); ly += 17; line = ""
            line += " " + w_
        t(x + 10, ly, line.strip(), 12.5)
        o.append(f'<path d="M{x + cw / 2:.1f} {ROW_E:.1f} L{x + cw / 2:.1f} {ROW_H + 124:.1f}" stroke="{GREEN}" stroke-width="2" marker-end="url(#ah)"/>')
    # engine
    rect(x, ROW_E, cw, 120, BLUE_BG, BLUE, sw=1.8)
    o.append(f'<circle cx="{x + 18:.1f}" cy="{ROW_E + 20:.1f}" r="12" fill="{BLUE}"/>')
    t(x + 18, ROW_E + 24.5, str(i + 1), 12.5, "700", "#ffffff", "middle")
    t(x + 36, ROW_E + 25, eng, 13, "700", BLUE)
    t(x + 10, ROW_E + 52, name, 17, "700")
    words = status.split(" ")
    line, ly = "", ROW_E + 76
    for w_ in words:
        if len(line + " " + w_) > 26:
            t(x + 10, ly, line.strip(), 11.5, "400", MUTED); ly += 15; line = ""
        line += " " + w_
    t(x + 10, ly, line.strip(), 11.5, "400", MUTED)
    if i < n - 1:
        o.append(f'<path d="M{x + cw:.1f} {ROW_E + 60:.1f} L{x + cw + gap - 1:.1f} {ROW_E + 60:.1f}" stroke="{INK}" stroke-width="2" marker-end="url(#ah)"/>')
    # reads
    if reads:
        t(x, ROW_R - 10, "liest", 12, "700", MUTED)
        for j, r in enumerate(reads):
            yy = ROW_R + j * 32
            o.append(f'<ellipse cx="{x + 12:.1f}" cy="{yy + 13:.1f}" rx="7" ry="4" fill="#f5f5f4" stroke="{MUTED}"/>')
            rect(x, yy, cw, 26, "#fafaf9", LINE, r=6, sw=1)
            t(x + 10, yy + 17.5, r, 12)
        o.append(f'<path d="M{x + cw / 2:.1f} {ROW_R - 4:.1f} L{x + cw / 2:.1f} {ROW_E + 124:.1f}" stroke="{MUTED}" stroke-width="1.5" stroke-dasharray="4 3" marker-end="url(#ah)"/>')
    # writes
    t(x, ROW_W - 10, "schreibt", 12, "700", AMBER)
    for j, w_ in enumerate(writes):
        yy = ROW_W + j * 32
        rect(x, yy, cw, 26, AMBER_BG, AMBER, r=6, sw=1.2)
        t(x + 10, yy + 17.5, w_, 12, "600")

# bottom invariants
y = 760
rect(20, y, W - 40, 112, "#ffffff", LINE, r=12)
t(40, y + 30, "Invarianten (eng)", 15, "700")
inv = ["Engine 2 schreibt nur in das Vorschlagsbuch und ordnet nur, was Engine 1 als geeignet geschrieben hat.",
       "Jede verbindliche Zeile (bestätigter Auftrag, Teamentscheid, signierter Bericht, Rechnung) entsteht durch eine menschliche Handlung über eine Befehlsfunktion.",
       "Beträge rechnet nie die KI. Ein Team, das eine harte Prüfung nicht besteht, erhält nie eine Angebotszeile; der Test prüft die Zeilen, nicht die Oberfläche."]
for k, s in enumerate(inv):
    t(40, y + 56 + k * 19, "· " + s, 13)
o.append("</svg>")
open(sys.argv[1], "w").write("\n".join(o))
