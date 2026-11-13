#!/usr/bin/env python3
"""Build a print PDF from a NAVORA Markdown document (docs only, FE-075 / FE-076).

- Mermaid blocks are rendered with `mmdc` to PNG.
- Images (SVG wireframes and diagrams) are resolved relative to the Markdown file.
- `<div class="landscape" markdown="1">` blocks print on A4 landscape pages.

Usage:
  python3 scripts/docs/build-pdf.py <in.md> <out.pdf> --title "..." --subtitle "..."
Needs: python-markdown, playwright (Python) with Chromium, mmdc. No app code, no network.
"""
import argparse
import hashlib
import html
import pathlib
import re
import subprocess
import tempfile

import markdown
from playwright.sync_api import sync_playwright

CSS = r"""
@page { size: A4; margin: 18mm 16mm 18mm 16mm; }
@page landscape { size: A4 landscape; margin: 12mm 12mm 14mm 12mm; }
:root { --ink:#022c22; --muted:#44403c; --line:#d6d3d1; --green:#065f46; --greenbg:#ecfdf5; --bg:#fafaf9; }
html { font-family: Inter, "Helvetica Neue", Arial, sans-serif; color: var(--ink); font-size: 9.6pt; line-height: 1.45; }
body { margin: 0; background: #fff; }
h1, h2, h3, h4 { color: var(--ink); line-height: 1.2; break-after: avoid; }
h1 { font-size: 22pt; margin: 0 0 6pt; }
h2 { font-size: 15.5pt; margin: 22pt 0 8pt; padding-top: 8pt; border-top: 3px solid var(--green); break-before: page; }
h3 { font-size: 12pt; margin: 16pt 0 6pt; color: var(--green); }
h4 { font-size: 10.5pt; margin: 12pt 0 4pt; }
p, li { orphans: 3; widows: 3; }
a { color: var(--green); text-decoration: none; }
code { font-family: "JetBrains Mono", Menlo, Consolas, monospace; font-size: 8.4pt; background: #f5f5f4; padding: 0 2px; border-radius: 3px; }
pre { background: #f5f5f4; border: 1px solid var(--line); border-radius: 6px; padding: 8px 10px; font-size: 8.2pt; white-space: pre-wrap; break-inside: avoid; }
pre code { background: none; padding: 0; }
table { border-collapse: collapse; width: 100%; margin: 6pt 0 10pt; font-size: 8.4pt; }
th { background: var(--greenbg); color: var(--ink); text-align: left; font-weight: 700; }
th, td { border: 1px solid var(--line); padding: 4px 6px; vertical-align: top; }
tr { break-inside: avoid; }
blockquote { border-left: 4px solid var(--green); margin: 8pt 0; padding: 4pt 10pt; background: var(--greenbg); }
hr { display: none; }
img { max-width: 100%; }
img.mermaid { display: block; margin: 8pt auto; max-height: 230mm; }
.landscape { page: landscape; break-before: page; }
.landscape img { display: block; width: 100%; max-height: 172mm; object-fit: contain; margin: 0 auto; }
.landscape img.mermaid { max-height: 172mm; }
.landscape h3 { margin-top: 0; }
.landscape + * { break-before: page; }
.cover { height: 250mm; display: flex; flex-direction: column; justify-content: space-between; break-after: page; }
.cover .band { background: var(--ink); color: #fff; padding: 22mm 14mm 16mm; border-radius: 6px; }
.cover .band .brand { font-size: 12pt; letter-spacing: .25em; opacity: .8; }
.cover .band h1 { color: #fff; font-size: 30pt; margin: 10mm 0 4mm; }
.cover .band .sub { font-size: 13pt; opacity: .92; max-width: 150mm; }
.cover .meta { font-size: 9.5pt; color: var(--muted); }
.cover .meta table { font-size: 9pt; }
.cover .stamp { display:inline-block; border:2px solid #92400e; color:#92400e; padding:4px 10px; border-radius:6px; font-weight:700; margin-bottom:6mm; }
.toc { break-after: page; }
.toc h2 { break-before: auto; border-top: none; }
.toc ol { padding-left: 16px; }
.toc li { margin: 3px 0; font-size: 10pt; }
.toc li li { font-size: 9pt; color: var(--muted); }
"""


def render_mermaid(src: str, outdir: pathlib.Path, cfg: pathlib.Path) -> str:
    key = hashlib.sha1(src.encode()).hexdigest()[:12]
    mmd = outdir / f"m-{key}.mmd"
    png = outdir / f"m-{key}.png"
    if not png.exists():
        mmd.write_text(src)
        subprocess.run(["mmdc", "-i", str(mmd), "-o", str(png), "-c", str(cfg), "-w", "1600", "-s", "2", "-b", "white"],
                       check=True, capture_output=True)
    return png.as_uri()


def build(md_path: pathlib.Path, pdf_path: pathlib.Path, title: str, subtitle: str, stamp: str):
    text = md_path.read_text()
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="navora-pdf-"))
    cfg = tmp / "mermaid.json"
    cfg.write_text('{"theme":"neutral","themeVariables":{"fontFamily":"Inter, Arial, sans-serif","fontSize":"16px"}}')

    def mer(m):
        uri = render_mermaid(m.group(1), tmp, cfg)
        from PIL import Image  # wide diagrams get their own landscape page
        with Image.open(uri[len("file://"):]) as im:
            wide = im.width / im.height > 1.25
        tag = f'<img class="mermaid" src="{uri}" alt="Diagramm">'
        return f'\n\n<div class="landscape">{tag}</div>\n\n' if wide else tag

    text = re.sub(r"```mermaid\n(.*?)\n```", mer, text, flags=re.S)

    def img(m):
        alt, src = m.group(1), m.group(2)
        if not re.match(r"^[a-z]+:", src):
            src = (md_path.parent / src).resolve().as_uri()
        return f"![{alt}]({src})"

    text = re.sub(r"!\[([^\]]*)\]\(([^)]+)\)", img, text)
    # drop the document's own H1 and first metadata table (the cover replaces them)
    first_h1 = re.search(r"^# .*$", text, flags=re.M)
    if first_h1:
        text = text[:first_h1.start()] + text[first_h1.end():]
    md = markdown.Markdown(extensions=["tables", "fenced_code", "md_in_html", "toc", "sane_lists", "attr_list"],
                           extension_configs={"toc": {"toc_depth": "2-2"}})
    body = md.convert(text)
    toc = md.toc
    cover = (f'<section class="cover"><div class="band"><div class="brand">NAVORA</div><h1>{html.escape(title)}</h1>'
             f'<div class="sub">{html.escape(subtitle)}</div></div>'
             f'<div class="meta"><div class="stamp">{html.escape(stamp)}</div>'
             '<p>Phase A · nur synthetische Daten · keine klinische Freigabe · keine Rechtsauskunft. '
             'Quelle: Repository <code>Ivica1984/navora-mvp</code>, Branch <code>recovery/main</code>. '
             'Kennzeichnung: IMPLEMENTED · PLANNED · OPEN · UNKNOWN.</p></div></section>')
    doc = (f'<!doctype html><html lang="de-CH"><head><meta charset="utf-8"><title>{html.escape(title)}</title>'
           f'<style>{CSS}</style></head><body>{cover}<nav class="toc"><h2>Inhalt</h2>{toc}</nav>{body}</body></html>')
    htmlf = tmp / "doc.html"
    htmlf.write_text(doc)
    footer = ('<div style="font-size:7.5pt;color:#78716c;width:100%;padding:0 12mm;display:flex;justify-content:space-between;'
              f'font-family:Inter,Arial,sans-serif"><span>{html.escape(title)} · Entwurf zur Founder-Freigabe</span>'
              '<span><span class="pageNumber"></span> / <span class="totalPages"></span></span></div>')
    with sync_playwright() as p:
        b = p.chromium.launch()
        pg = b.new_page()
        pg.goto(htmlf.as_uri(), wait_until="networkidle")
        pg.pdf(path=str(pdf_path), prefer_css_page_size=True, print_background=True, display_header_footer=True,
               header_template="<span></span>", footer_template=footer)
        b.close()
    print(pdf_path)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("md")
    ap.add_argument("pdf")
    ap.add_argument("--title", required=True)
    ap.add_argument("--subtitle", default="")
    ap.add_argument("--stamp", default="Entwurf zur Founder-Freigabe")
    a = ap.parse_args()
    build(pathlib.Path(a.md).resolve(), pathlib.Path(a.pdf).resolve(), a.title, a.subtitle, a.stamp)
