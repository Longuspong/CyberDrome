#!/usr/bin/env python3
"""
Erzeugt die Terrain-Tiles fuer den Kampf -- mit demselben Renderer wie die Bots.

Warum nicht von Hand gezeichnet
-------------------------------
Ein Bodenfeld und ein Bot muessen dieselbe Projektion benutzen, sonst steht
der Bot neben seiner Kachel statt darauf. Diese Projektion existiert bereits
in ``tools/build_sample_parts.py`` -- samt Beleuchtung, Sichtbarkeit und
Zeichenreihenfolge. Sie wird hier importiert und nicht nachgebaut.

Damit faellt die Iso-Beleuchtung von selbst richtig aus: Oberseiten hell,
linke Flanken mittel, rechte Flanken dunkel. Wer Tiles daneben von Hand malt,
bekommt Felder, die anders beleuchtet sind als die Bots darauf.

Die Geometrie
-------------
Das Bodenfeld ist die Raute, die das Werkzeug einblendet: 76 x 54 px um
(64, 96), Verhaeltnis sqrt(2):1. In Entwurfseinheiten ist das eine
quadratische Grundflaeche mit der Halbkante ``TILE_HALF`` -- unten aus
TILE_HALF_W zurueckgerechnet, damit beide Werte nicht auseinanderlaufen
koennen.

Je Region gibt es nur noch die BODENKACHEL: seit dem Umbau zum Autobattler
(Nov. 2026) hat das Kampffeld kein Gelaende mehr (keine Stufen, Pfeiler,
Drift- oder Nebelfelder).

Farben stehen hier konkret und nicht als CSS-Variable: Terrain wird zur
Laufzeit nicht umgefaerbt, und ein Bake-Schritt fuer 15 Dateien waere
Zeremonie ohne Nutzen. Die Bots gehen weiter ueber var(--c-*).

Aufruf
------
    python3 tools/build_terrain_tiles.py
"""

from __future__ import annotations

import json
import pathlib
import sys
from xml.etree import ElementTree

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from build_sample_parts import (  # noqa: E402
    COS45, SCALE, TILE_HALF_W, B, project, render, svg_comment_body, _shade_hex,
)

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "terrain"
REGION_FILE = ROOT / "data" / "regions.json"

# Halbe Kantenlaenge der Grundflaeche in Entwurfseinheiten.
# Aus der Bildschirmbreite zurueckgerechnet:
#   halbe Bildschirmbreite = COS45 * (2 * TILE_HALF) * SCALE
TILE_HALF = TILE_HALF_W / (2.0 * COS45 * SCALE)

# Hoehe der Bodenplatte -- nur eine sichtbare Kante.
HEIGHT_FLAT = 1.4


def _palette(base: str, accent: str, line: str) -> dict:
    """
    Die vier Rollen eines Terraintyps aus zwei Farben.

    Kante und Schatten werden abgeleitet und nicht einzeln gesetzt -- dieselbe
    Absicherung wie bei den Bauteilen: die drei Panzerungs-Rollen SIND die
    Iso-Beleuchtung, einzeln gesetzt ergeben sie falsch beleuchtete Flaechen.
    """
    return {
        "top": _shade_hex(base, "light"),
        "side_left": base,
        "side_right": _shade_hex(base, "dark"),
        "accent": accent,
        "line": line,
    }


# Farben je Terraintyp. Der Klarname steht in data/regions.json; hier steht
# nur, wie er aussieht.
COLORS = {
    "asphalt":   _palette("#2f333d", "#3d4350", "#0d0f14"),   # Sektor City
    "meadow":    _palette("#2f4a2a", "#4a6b3d", "#101a0e"),   # Gruenzone
    "grating":   _palette("#33383f", "#4a515c", "#0a0d11"),   # Anlage 7
}


SVG_HEAD = (
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" '
    'width="128" height="128"\n     data-terrain="{tid}">\n'
    '  <title>{name}</title>\n'
    '  <!--\n'
    '    Erzeugt von tools/build_terrain_tiles.py, nicht von Hand bearbeiten.\n'
    '    Dieselbe Projektion wie die Bauteile: Iso-Kamera 45 Grad, Bodenraute\n'
    '    {tw:.0f} x {th:.0f} px um (64, 96). Nur so steht ein Bot auf seinem Feld\n'
    '    und nicht daneben.\n'
    '  -->\n'
)


def _materials(colors: dict) -> dict:
    """Materialtabelle im Format, das render() erwartet."""
    return {
        "ground": (colors["top"], colors["side_left"], colors["side_right"], True),
        "accent": (colors["accent"], colors["accent"], colors["accent"], False),
    }


def _tile_shapes():
    """Die Bodenplatte."""
    h = TILE_HALF
    return [B((-h, h), (-h, h), (0, HEIGHT_FLAT), "ground")]


def _write(path: pathlib.Path, text: str) -> bool:
    # Wie bei den Bauteilen: eine Datei, die sich SVG nennt, muss wohlgeformtes
    # XML sein. Der haeufigste Weg, das zu verletzen, ist ein Gedankenstrich im
    # Kommentar -- "--" ist dort verboten (siehe svg_comment_body).
    if path.suffix == ".svg":
        try:
            ElementTree.fromstring(text)
        except ElementTree.ParseError as error:
            raise SystemExit(
                f"[terrain] {path.name} ist kein wohlgeformtes XML: {error}"
            ) from error
    current = path.read_text(encoding="utf-8") if path.exists() else None
    if current == text:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return True


def build_tile(region_id: str, meta: dict) -> bool:
    tid = pathlib.Path(meta["svg"]).stem
    colors = COLORS.get(tid)
    if colors is None:
        raise SystemExit(f"[terrain] {region_id}/{tid}: keine Farben definiert")

    import build_sample_parts as bsp
    saved = bsp.MATERIALS
    bsp.MATERIALS = _materials(colors)
    try:
        body = render(_tile_shapes(), "south")
    finally:
        bsp.MATERIALS = saved

    # render() setzt den Umriss ueber var(--c-outline). Godot loest CSS-
    # Variablen nicht auf und faellt auf Schwarz zurueck -- was zufaellig
    # passabel aussieht und deshalb umso leichter unbemerkt bliebe. Die
    # Konturfarbe der Region wird hier konkret eingesetzt.
    body = body.replace("var(--c-outline)", colors["line"])
    if "var(--" in body:
        raise SystemExit(
            f"[terrain] {region_id}/{tid}: unaufgeloeste CSS-Variable im SVG. "
            f"Godot wuerde sie schwarz rastern.")

    svg = SVG_HEAD.format(tid=tid, name=meta["name"],
                          tw=2 * TILE_HALF_W, th=2 * TILE_HALF_W * COS45)
    svg += body + "</svg>\n"
    return _write(OUT_DIR / region_id / meta["svg"], svg)


def build_overlay() -> int:
    """
    Eine weisse Raute -- die Szene zeigt sie magenta, wenn eine Bodenkachel
    fehlt.
    """
    h = TILE_HALF
    corners = [project((f * h, l * h, 0.0), "south")
               for f, l in ((1, 1), (1, -1), (-1, -1), (-1, 1))]
    path = "M" + " L".join(f"{x:.2f} {y:.2f}" for x, y in corners) + " Z"

    written = 0
    fill = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" '
            'width="128" height="128">\n'
            '  <title>Feldmarkierung</title>\n'
            '  <!-- Erzeugt von tools/build_terrain_tiles.py. -->\n'
            f'  <path d="{path}" fill="#ffffff"/>\n'
            '</svg>\n')
    written += int(_write(OUT_DIR / "overlay_tile.svg", fill))
    return written


def main() -> int:
    regions = json.loads(REGION_FILE.read_text(encoding="utf-8"))["regions"]
    written = 0
    total = 0
    for region in regions:
        total += 1
        written += int(build_tile(region["id"], region["floor"]))

    overlays = build_overlay()
    print(f"[ok] {total} Bodenkacheln und 1 Overlay nach "
          f"{OUT_DIR.relative_to(ROOT)}/ ({written + overlays} neu geschrieben)")
    print(f"     Bodenraute {2 * TILE_HALF_W:.0f} x {2 * TILE_HALF_W * COS45:.0f} px "
          f"um (64, 96), Halbkante {TILE_HALF:.3f} Entwurfseinheiten")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
