#!/usr/bin/env python3
"""Generate the NAVORA end-to-end order flow as two swimlane SVGs (FE-076 (3)).

Docs-only helper. No app code.
Usage: python3 scripts/docs/gen-e2e-swimlane.py <out-dir>
Writes e2e-a-auftrag.svg (order to acceptance) and e2e-b-einsatz.svg (visit to invoice).
"""
import os
import sys
from xml.sax.saxutils import escape

INK, MUTED, LINE = "#022c22", "#44403c", "#d6d3d1"
COL = {"human": ("#065f46", "#ecfdf5"), "engine": ("#075985", "#f0f9ff"),
       "ledger": ("#92400e", "#fffbeb"), "stop": ("#b91c1c", "#fef2f2")}
STAT = {"IMPL": ("#065f46", "IMPLEMENTED"), "PLAN": ("#92400e", "PLANNED"), "TEIL": ("#075985", "TEILWEISE")}


def render(path, title, subtitle, lanes, ncols, cards, arrows, extras=None):
    W, LX, LW, TOP, LH, CH = 1520, 20, 150, 92, 150, 116
    colx0 = LX + LW + 12
    colw = (W - 20 - colx0) / ncols
    cw = colw - 26
    H = TOP + len(lanes) * LH + 46
    o = []

    def t(x, y, s, size=14, weight="400", fill=INK, anchor="start"):
        o.append(f'<text x="{x:.1f}" y="{y:.1f}" font-size="{size}" font-weight="{weight}" fill="{fill}" text-anchor="{anchor}">{escape(s)}</text>')

    def box_of(c, lane):
        x = colx0 + c * colw + 4
        y = TOP + lane * LH + (LH - 6 - CH) / 2
        return x, y

    o.append(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" font-family="Inter, Arial, sans-serif">')
    o.append('<defs><marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 z" fill="context-stroke"/></marker></defs>')
    o.append(f'<rect width="{W}" height="{H}" fill="#ffffff"/>')
    t(20, 34, title, 23, "700")
    t(20, 60, subtitle, 14, "400", MUTED)
    for i, (name, sub) in enumerate(lanes):
        y = TOP + i * LH
        o.append(f'<rect x="{LX}" y="{y}" width="{W - 40}" height="{LH - 6}" rx="10" fill="{"#fafaf9" if i % 2 == 0 else "#ffffff"}" stroke="{LINE}"/>')
        t(LX + 14, y + LH / 2 - 6, name, 16, "700")
        t(LX + 14, y + LH / 2 + 14, sub, 13, "400", MUTED)
    pos = {}
    for key, c, lane, num, head, lines, kind, status in cards:
        x, y = box_of(c, lane)
        pos[key] = (x, y)
        stroke, bg = COL[kind]
        o.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{cw:.1f}" height="{CH}" rx="10" fill="{bg}" stroke="{stroke}" stroke-width="1.6"/>')
        if num:
            o.append(f'<circle cx="{x + 17:.1f}" cy="{y + 19:.1f}" r="12" fill="{stroke}"/>')
            t(x + 17, y + 24, str(num), 13, "700", "#ffffff", "middle")
            t(x + 36, y + 25, head, 15, "700", INK)
        else:
            t(x + 12, y + 25, head, 15, "700", stroke)
        for j, l in enumerate(lines):
            t(x + 12, y + 48 + j * 17, l, 13.5, "400", INK)
        if status:
            sc, sl = STAT[status]
            t(x + 12, y + CH - 10, sl, 11, "700", sc)
    for a, b, label, kind in arrows:
        (x1, y1), (x2, y2) = pos[a], pos[b]
        color = COL["stop"][0] if kind == "stop" else INK
        dash = ' stroke-dasharray="6 4"' if kind in ("stop", "back") else ""
        if abs(x1 - x2) < 1:  # same column: vertical
            if y2 > y1:
                d = f"M{x1 + cw / 2:.1f} {y1 + CH:.1f} L{x2 + cw / 2:.1f} {y2 - 2:.1f}"
            else:
                d = f"M{x1 + cw / 2:.1f} {y1:.1f} L{x2 + cw / 2:.1f} {y2 + CH + 2:.1f}"
        elif abs(y1 - y2) < 1:  # same lane: horizontal
            if x2 > x1:
                d = f"M{x1 + cw:.1f} {y1 + CH / 2:.1f} L{x2 - 2:.1f} {y2 + CH / 2:.1f}"
            else:
                d = f"M{x1:.1f} {y1 + CH / 2:.1f} L{x2 + cw + 2:.1f} {y2 + CH / 2:.1f}"
        else:
            xm = x1 + cw + (x2 - x1 - cw) / 2 if x2 > x1 else x1 - 13
            d = f"M{x1 + cw:.1f} {y1 + CH / 2:.1f} L{xm:.1f} {y1 + CH / 2:.1f} L{xm:.1f} {y2 + CH / 2:.1f} L{x2 - 2:.1f} {y2 + CH / 2:.1f}"
        o.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="2"{dash} marker-end="url(#ah)"/>')
        if label:
            if abs(x1 - x2) < 1:
                t(x1 + cw / 2 + 8, (y1 + y2 + CH) / 2 + 4, label, 12, "600", color)
    for e in extras or []:
        e(o, pos, cw, CH, t)
    ly = H - 22
    for i, (lab, kind) in enumerate([("Mensch entscheidet", "human"), ("Engine / System", "engine"), ("Ledger", "ledger"), ("Sicherheitsnetz / Stopp", "stop")]):
        x = 20 + i * 220
        o.append(f'<rect x="{x}" y="{ly - 12}" width="18" height="15" rx="3" fill="{COL[kind][1]}" stroke="{COL[kind][0]}"/>')
        t(x + 26, ly, lab, 13, "600")
    t(W - 20, ly, "Statusmarke je Karte: Stand recovery/main 13.11.2026", 13, "400", MUTED, "end")
    o.append("</svg>")
    open(path, "w").write("\n".join(o))


def ledger_wall(o, pos, cw, ch, t):
    x = pos["abo"][0] + cw + 13
    y = pos["abo"][1]
    o.append(f'<line x1="{x:.1f}" y1="{y - 4:.1f}" x2="{x:.1f}" y2="{y + ch + 4:.1f}" stroke="#b91c1c" stroke-width="2.5" stroke-dasharray="6 4"/>')


out = sys.argv[1]
os.makedirs(out, exist_ok=True)

render(os.path.join(out, "e2e-a-auftrag.svg"),
       "Teil A · Vom Bedarf zur Zusage in Minuten statt Telefonketten",
       "Referenzfall FE-073 (5): Pflegeheim 4052 Basel, Krankmeldung 14:15, Spätschicht 16:30–21:30, Demenzabteilung. Phase A, synthetische Daten.",
       [("Auftraggeber", "/order"), ("KI und Engines", "Regeln zuerst"), ("Team", "/team")], 7,
       [("bed", 0, 0, 1, "Bedarf sagen", ["Diktat oder ein Satz:", "«Spätschicht heute,", "Demenz, 4052»"], "human", "PLAN"),
        ("ext", 1, 1, 2, "KI-Extraktion", ["Engine 2 erkennt Datum,", "Zeit, PLZ, Stufe,", "Merkmal: «bitte prüfen»"], "engine", "PLAN"),
        ("ok", 2, 0, 3, "Bestätigen", ["jedes Feld geprüft,", "1-Klick-Zusammen-", "fassung, verbindlich"], "human", "PLAN"),
        ("e1", 3, 1, 4, "Engine 1", ["deterministisch: PLZ,", "Matrix, ganze Schicht,", "bestätigtes Merkmal"], "engine", "TEIL"),
        ("stop", 3, 2, None, "Stoppfall", ["Ungeeignete Teams", "erhalten nie ein Ange-", "bot; Grund protokolliert"], "stop", "TEIL"),
        ("rank", 4, 1, 5, "Rangfolge", ["Engine 2 ordnet nur", "Geeignete, begründet", "in Worten, kein Score"], "engine", "PLAN"),
        ("card", 5, 2, 6, "Angebotskarte", ["Push an das beste", "Team, exklusiv", "bis 14:45"], "engine", "PLAN"),
        ("net", 5, 1, None, "Kaskade, Engine 5", ["Ablehnung oder Zeit um:", "nächstes Team; sonst", "«nicht gedeckt» sichtbar"], "stop", "TEIL"),
        ("yes", 6, 2, 7, "1-Klick-Zusage", ["Team entscheidet", "selbst, NAVORA prüft", "alle Regeln erneut"], "human", "IMPL"),
        ("cov", 6, 0, None, "Status «gedeckt»", ["«Gedeckt durch", "Team Gundeli»", "um 14:31"], "human", "PLAN")],
       [("bed", "ext", None, ""), ("ext", "ok", None, ""), ("ok", "e1", None, ""), ("e1", "stop", "nicht geeignet", "stop"),
        ("e1", "rank", None, ""), ("rank", "card", None, ""), ("card", "net", "abgelehnt", "stop"), ("card", "yes", None, ""), ("yes", "cov", None, "")])

render(os.path.join(out, "e2e-b-einsatz.svg"),
       "Teil B · Vom Einsatz zur Rechnung ohne Provision",
       "Die Pflegekraft spricht 30 Sekunden statt ein Formular zu tippen. Beträge rechnet nie die KI. Der Pflegeerlös gehört ganz dem Team.",
       [("Pflegekraft", "/field"), ("KI und Engines", "Regeln zuerst"), ("Team", "/team"), ("Finanzen", "drei Ledger")], 7,
       [("in", 0, 0, 8, "Check-in", ["1 Tap auf /field,", "Zeit und Aufgaben", "laufen mit"], "human", "IMPL"),
        ("dict", 1, 0, 9, "Diktat 30 s", ["Sprachnotiz statt", "Formular; offline", "zwischengespeichert"], "human", "PLAN"),
        ("e3", 2, 1, 10, "Engine 3", ["Berichtsentwurf,", "jeder Satz mit Quelle,", "nichts dazuerfunden"], "engine", "PLAN"),
        ("sign", 3, 0, 11, "Signieren", ["Pflegekraft korrigiert", "und signiert; erst", "dann verbindlich"], "human", "IMPL"),
        ("e4", 4, 1, 12, "Engine 4", ["Stunden × Preis;", "Doppelabrechnung und", "Zeitkonflikt gesperrt"], "engine", "TEIL"),
        ("rel", 5, 2, 13, "Freigeben", ["Team prüft die", "Rechnung und sendet", "sie dem Auftraggeber"], "human", "PLAN"),
        ("led", 6, 3, None, "Team-Ledger", ["Pflegeerlös gehört", "ganz dem Team;", "0 % Provision"], "ledger", "PLAN"),
        ("abo", 3, 3, None, "NAVORA-Ledger A", ["feste Monatsgebühr", "je Mitglied, eigene", "Rechnung, nie je Einsatz"], "ledger", "PLAN"),
        ("b2b", 2, 3, None, "NAVORA-Ledger B", ["B2B-Lizenzen", "der Heimsuite,", "getrennt"], "ledger", "PLAN")],
       [("in", "dict", None, ""), ("dict", "e3", None, ""), ("e3", "sign", None, ""), ("sign", "e4", None, ""),
        ("e4", "rel", None, ""), ("rel", "led", None, "")],
       [ledger_wall])
