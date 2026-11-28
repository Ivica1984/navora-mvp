#!/usr/bin/env python3
"""Generate the shift value chain bar chart (Founder reference values, FE-073 (5)) as SVG.

Docs-only helper for Blueprint V3.1 Kap. 1.2 (FE-076). No app code.
Usage: python3 scripts/docs/gen-value-chain.py docs/product/blueprint-v3/diagrams/value-chain.svg
"""
import sys
from xml.sax.saxutils import escape

W, H = 1400, 560
INK, MUTED = "#022c22", "#44403c"
o = []


def t(x, y, s, size=16, weight="400", fill=INK, anchor="start"):
    o.append(f'<text x="{x}" y="{y}" font-size="{size}" font-weight="{weight}" fill="{fill}" text-anchor="{anchor}">{escape(s)}</text>')


X0, SCALE, BH = 230, 2.35, 74  # 1 CHF = 2.35 px


def seg(x, y, chf, fill, stroke, label, sub, txt="#ffffff"):
    w = chf * SCALE
    o.append(f'<rect x="{x}" y="{y}" width="{w}" height="{BH}" fill="{fill}" stroke="{stroke}" stroke-width="1.5"/>')
    t(x + 14, y + 32, label, 18, "700", txt)
    t(x + 14, y + 56, sub, 14, "400", txt)
    return x + w


o.append(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" font-family="Inter, Arial, sans-serif">')
o.append(f'<rect width="{W}" height="{H}" fill="#ffffff"/>')
t(30, 40, "Wohin das Geld einer Spätschicht fliesst", 26, "700")
t(30, 68, "Founder-Referenzfall: Pflegeheim 4052 Basel, Spätschicht 16:30–21:30 (5 Stunden). Brutto, vor Abgaben des Teams; kein Tarif.", 15, "400", MUTED)

# Today
y1 = 120
t(30, y1 + 32, "Heute", 20, "700")
t(30, y1 + 56, "Temporärbüro", 15, "400", MUTED)
x = seg(X0, y1, 140, "#065f46", "#065f46", "Pflegekraft 140 CHF", "Bruttolohn, 28 CHF/h")
x = seg(x, y1, 235, "#b91c1c", "#b91c1c", "Zwischenhandel 235 CHF", "Abgaben, Verwaltung, Marge (Aufteilung UNKNOWN)")
t(x + 14, y1 + 46, "Heim zahlt 375 CHF", 18, "700")

# NAVORA
y2 = 260
t(30, y2 + 32, "NAVORA", 20, "700")
t(30, y2 + 56, "Team direkt", 15, "400", MUTED)
x2 = seg(X0, y2, 260, "#065f46", "#065f46", "Team 260 CHF", "voller Erlös, 52 CHF/h, 0 % Provision")
t(x2 + 14, y2 + 46, "Heim zahlt 260 CHF", 18, "700")

# deltas
xa = X0 + 140 * SCALE
xb = X0 + 260 * SCALE
xc = X0 + 375 * SCALE
o.append(f'<line x1="{xa}" y1="{y1 + BH + 6}" x2="{xa}" y2="{y2 - 6}" stroke="#065f46" stroke-dasharray="5 4" stroke-width="2"/>')
o.append(f'<line x1="{xb}" y1="{y1 + BH + 6}" x2="{xb}" y2="{y2 - 6}" stroke="#92400e" stroke-dasharray="5 4" stroke-width="2"/>')
o.append(f'<line x1="{xc}" y1="{y1 + BH + 6}" x2="{xc}" y2="{y2 + BH}" stroke="#92400e" stroke-dasharray="5 4" stroke-width="2"/>')
o.append(f'<rect x="{xb}" y="{y2}" width="{xc - xb}" height="{BH}" fill="#fffbeb" stroke="#92400e" stroke-dasharray="6 4" stroke-width="1.5"/>')
t(xb + 14, y2 + 32, "Heim spart 115 CHF", 18, "700", "#92400e")
t(xb + 14, y2 + 56, "−30,7 % je Schicht", 14, "400", "#92400e")

# NAVORA fee note
y3 = 380
o.append(f'<rect x="{X0}" y="{y3}" width="{7.5 * SCALE * 4}" height="44" fill="#f0f9ff" stroke="#075985" stroke-width="1.5"/>')
t(X0 + 7.5 * SCALE * 4 + 14, y3 + 20, "NAVORA-Abo: feste Monatsgebühr, eigene Rechnung an das Team, nie je Schicht.", 15, "600", "#075985")
t(X0 + 7.5 * SCALE * 4 + 14, y3 + 40, "Rechnerisch 7.50 CHF je Schicht bei 120 CHF/Monat und 16 Schichten (Founder-Beispiel, D-14 OPEN). Massstab 4-fach vergrössert.", 13.5, "400", MUTED)

# summary
y4 = 460
o.append(f'<rect x="30" y="{y4}" width="{W - 60}" height="76" rx="12" fill="#ecfdf5" stroke="#065f46" stroke-width="1.5"/>')
t(54, y4 + 32, "Pflegende +120 CHF je Schicht · Heim −115 CHF je Schicht · Zwischenhandel −235 CHF", 21, "700", "#065f46")
t(54, y4 + 58, "Beide gewinnen, weil die Marge des Zwischenhandels wegfällt. Vom Brutto zum Netto des Teams: Rechenmodell in Kap. 3.2.", 15, "400", INK)
o.append("</svg>")
open(sys.argv[1], "w").write("\n".join(o))
