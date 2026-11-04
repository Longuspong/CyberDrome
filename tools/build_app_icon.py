#!/usr/bin/env python3
"""Erzeugt das App-Icon (Favicon, PWA-Icons): assets/icon/app_icon.svg.

Der Vireo-Sensorkopf (assets/parts/bot1/scout_head_south.svg) gross vor einem
Cyber-Hintergrund: Neon-Gitter als Boden, Leiterbahnen, ein leuchtender
Sechseck-Ring hinter dem Kopf. Alles Vektor -- Godot rastert es beim Import in
voller Groesse (512 px), daraus macht der Web-Export Favicon und PWA-Icons.

Bewusst ohne SVG-Filter (Blur): Godots SVG-Renderer kann sie nicht sicher.
Leuchten entsteht aus Verlaeufen und breiten, halbtransparenten Strichen.

    python3 tools/build_app_icon.py
"""

import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HEAD = ROOT / "assets/parts/bot1/scout_head_south.svg"
OUT = ROOT / "assets/icon/app_icon.svg"

SIZE = 512
CYAN = "#7cf9ff"
MAGENTA = "#ff3dbb"

# Kopf im Teil-Raster: etwa x 49.7..78.3, y 11.4..42.5 -> Mitte (64, 27).
HEAD_CENTER = (64.0, 27.0)
HEAD_SCALE = 7.4
HEAD_TARGET = (256.0, 252.0)


def head_paths() -> str:
    text = HEAD.read_text(encoding="utf-8")
    group = re.search(r"<g [^>]*>(.*?)</g>", text, re.S)
    if group is None:
        raise SystemExit("Kopf-SVG ohne <g>-Gruppe")
    return group.group(1).strip()


def visor_glow(paths: str) -> str:
    """Die cyanfarbenen Flaechen (Visier, Sensor) noch einmal als breiter,
    halbtransparenter Strich darunter -- ein Leuchten ohne Filter."""
    out = []
    for match in re.finditer(r'<path d="([^"]+)" fill="(#7cf9ff|#a9ffff)"', paths):
        out.append(f'<path d="{match.group(1)}" fill="none" stroke="{CYAN}" '
                   f'stroke-width="2.6" stroke-opacity="0.35" stroke-linejoin="round"/>')
    return "\n    ".join(out)


def hexagon(cx: float, cy: float, r: float) -> str:
    pts = []
    for i in range(6):
        a = math.radians(60 * i - 90)
        pts.append(f"{cx + r * math.cos(a):.1f},{cy + r * math.sin(a):.1f}")
    return " ".join(pts)


def floor_grid() -> str:
    """Perspektivisches Gitter im unteren Drittel, zum Fluchtpunkt hin."""
    horizon, bottom, vx = 330.0, 512.0, 256.0
    lines = []
    for i in range(-9, 10):
        x = vx + i * 70
        lines.append(f'<line x1="{vx + i * 9:.1f}" y1="{horizon}" x2="{x:.1f}" y2="{bottom}"/>')
    y, step = horizon + 6, 8.0
    while y < bottom:
        lines.append(f'<line x1="0" y1="{y:.1f}" x2="{SIZE}" y2="{y:.1f}"/>')
        step *= 1.35
        y += step
    return "\n    ".join(lines)


def traces() -> str:
    """Leiterbahnen in den Ecken, mit Loetpunkten an den Enden."""
    routes = [
        [(0, 70), (60, 70), (90, 40), (150, 40)],
        [(0, 120), (40, 120), (70, 150), (70, 205)],
        [(512, 60), (440, 60), (410, 90), (360, 90)],
        [(512, 140), (470, 140), (440, 170), (440, 215)],
        [(30, 0), (30, 30), (55, 55)],
        [(470, 0), (470, 25), (500, 25)],
    ]
    out = []
    for route in routes:
        d = " ".join(f"{'M' if i == 0 else 'L'}{x} {y}" for i, (x, y) in enumerate(route))
        out.append(f'<path d="{d}"/>')
        ex, ey = route[-1]
        out.append(f'<circle cx="{ex}" cy="{ey}" r="5" fill="#0a0f1f"/>')
    return "\n    ".join(out)


def build() -> str:
    paths = head_paths()
    hx, hy = HEAD_CENTER
    tx = HEAD_TARGET[0] - hx * HEAD_SCALE
    ty = HEAD_TARGET[1] - hy * HEAD_SCALE
    ring = hexagon(256, 250, 168)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {SIZE} {SIZE}" width="{SIZE}" height="{SIZE}">
  <title>CyberDrome</title>
  <!-- Erzeugt von tools/build_app_icon.py. Dort aendern, nicht hier. -->
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#0b1026"/>
      <stop offset="0.62" stop-color="#121a3f"/>
      <stop offset="1" stop-color="#05070f"/>
    </linearGradient>
    <radialGradient id="halo" cx="0.5" cy="0.48" r="0.5">
      <stop offset="0" stop-color="{CYAN}" stop-opacity="0.38"/>
      <stop offset="0.45" stop-color="#3a6cff" stop-opacity="0.16"/>
      <stop offset="1" stop-color="#3a6cff" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="horizon" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="{MAGENTA}" stop-opacity="0"/>
      <stop offset="0.5" stop-color="{MAGENTA}" stop-opacity="0.45"/>
      <stop offset="1" stop-color="{MAGENTA}" stop-opacity="0"/>
    </linearGradient>
    <linearGradient id="fade" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#05070f" stop-opacity="0.9"/>
      <stop offset="1" stop-color="#05070f" stop-opacity="0"/>
    </linearGradient>
  </defs>

  <rect width="{SIZE}" height="{SIZE}" fill="url(#bg)"/>

  <g stroke="{CYAN}" stroke-width="2" stroke-opacity="0.22" fill="none">
    {traces()}
  </g>

  <g stroke="{CYAN}" stroke-width="1.6" stroke-opacity="0.32">
    {floor_grid()}
  </g>
  <rect x="0" y="330" width="{SIZE}" height="40" fill="url(#fade)"/>
  <rect x="0" y="318" width="{SIZE}" height="24" fill="url(#horizon)"/>

  <circle cx="256" cy="250" r="240" fill="url(#halo)"/>

  <polygon points="{ring}" fill="none" stroke="{CYAN}" stroke-width="26" stroke-opacity="0.10" stroke-linejoin="round"/>
  <polygon points="{ring}" fill="none" stroke="{CYAN}" stroke-width="12" stroke-opacity="0.22" stroke-linejoin="round"/>
  <polygon points="{ring}" fill="#0a1024" fill-opacity="0.55" stroke="{CYAN}" stroke-width="4" stroke-linejoin="round"/>
  <polygon points="{hexagon(256, 250, 150)}" fill="none" stroke="{MAGENTA}" stroke-width="2" stroke-opacity="0.55" stroke-dasharray="18 12"/>

  <ellipse cx="256" cy="364" rx="105" ry="16" fill="#000" fill-opacity="0.45"/>

  <g transform="translate({tx:.2f} {ty:.2f}) scale({HEAD_SCALE})">
    {visor_glow(paths)}
    <g stroke="#080b13" stroke-width="0.9" stroke-linejoin="round">
    {paths}
    </g>
  </g>
</svg>
'''


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(build(), encoding="utf-8")
    print(f"geschrieben: {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
