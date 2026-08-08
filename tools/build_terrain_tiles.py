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

Die fuenf Klassen unterscheiden sich in der HOEHE, nicht in der Grundflaeche:

    NORMAL   flache Platte, nur eine Kante sichtbar
    DRIFT    ebenso flach -- man laeuft ungehindert darueber
    HAZE     ebenso flach; die Sichtsperre ist ein Overlay, kein Volumen
    STEP     erhoehtes Podest mit sichtbarer Seitenflaeche. Man muss der
             Kachel ansehen, warum der Rad-Antrieb aussenrum muss.
    BLOCK    hohe Saeule. Undurchdringlich, und das sieht man.

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

# Hoehen der fuenf Klassen in Entwurfseinheiten.
#
# Die Zahlen sind am Blicktest nachgezogen, nicht geschaetzt. Eine Einheit
# projiziert auf COS45 * SCALE = 0.95 px, die Kachel ist 54 px hoch:
#
#   STEP  bei 7.5 war die Seitenflaeche 7 px hoch und las sich als flache,
#         nur hellere Kachel. Bei 14 ist sie ein Viertel der Kachelhoehe --
#         man sieht der Stufe an, warum der Rad-Antrieb aussenrum muss.
#   BLOCK bei 30 reichte die Saeule dem Bot bis zur Huefte und wirkte wie
#         eine Kiste zum Drueberklettern. Sie muss ihn ueberragen, sonst
#         luegt die Silhouette ueber die Regel.
HEIGHT_FLAT = 1.4       # NORMAL / DRIFT / HAZE -- nur eine sichtbare Kante
HEIGHT_STEP = 14.0      # STEP -- deutliche Seitenflaeche
HEIGHT_BLOCK = 52.0     # BLOCK -- ueberragt einen DROME

# BLOCK und STEP ziehen sich leicht ein, damit die Fugen sichtbar bleiben.
INSET_STEP = 0.94
INSET_BLOCK = 0.80


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
    # --- Sektor City: Beton, Neon, Oel ---
    "asphalt":   _palette("#2f333d", "#3d4350", "#0d0f14"),
    "kerb":      _palette("#4a4e58", "#6d727e", "#0d0f14"),
    "pillar":    _palette("#3a3e48", "#575c68", "#0d0f14"),
    "oilfilm":   _palette("#1f2430", "#2de2e6", "#0d0f14"),
    "steam":     _palette("#464e5e", "#8b96ab", "#0d0f14"),

    # --- Gruenzone: Wiese, Wurzel, Schlamm ---
    "meadow":    _palette("#2f4a2a", "#4a6b3d", "#101a0e"),
    "rootbase":  _palette("#4a3a24", "#6b5433", "#101a0e"),
    "boulder":   _palette("#4a4a44", "#666660", "#101a0e"),
    "mudrun":    _palette("#3a2f22", "#5c4a33", "#101a0e"),
    "tallgrass": _palette("#3d5c33", "#6b8f52", "#101a0e"),

    # --- Anlage 7: Stahl, Reaktor, Magnetschiene ---
    "grating":   _palette("#33383f", "#4a515c", "#0a0d11"),
    "catwalk":   _palette("#454c56", "#6b7480", "#0a0d11"),
    "reactor":   _palette("#4a2a2a", "#8f3d3d", "#0a0d11"),
    "magrail":   _palette("#243040", "#3d8fd6", "#0a0d11"),
    "jamfield":  _palette("#3a2f4a", "#8f6bd6", "#0a0d11"),
}


SVG_HEAD = (
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" '
    'width="128" height="128"\n     data-terrain="{tid}" data-class="{tclass}">\n'
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


def _tile_shapes(terrain_class: str, tid: str):
    """Die Volumen eines Tiles. Grundflaeche gleich, Hoehe je Klasse."""
    h = TILE_HALF
    if terrain_class == "block":
        e = h * INSET_BLOCK
        return [B((-e, e), (-e, e), (0, HEIGHT_BLOCK), "ground")]
    if terrain_class == "step":
        e = h * INSET_STEP
        return [B((-e, e), (-e, e), (0, HEIGHT_STEP), "ground")]

    shapes = [B((-h, h), (-h, h), (0, HEIGHT_FLAT), "ground")]
    if terrain_class == "drift":
        # Eine Schliere quer ueber das Feld. Unsichtbares Rutschen ist die
        # schnellste Art, ein Taktikspiel unfair wirken zu lassen -- die
        # Drift-Zone muss man erkennen, BEVOR man hineinlaeuft.
        shapes.append(B((-h * 0.72, h * 0.72), (-h * 0.16, h * 0.16),
                        (HEIGHT_FLAT, HEIGHT_FLAT + 0.35), "accent"))
    elif terrain_class == "haze":
        # Drei versetzte Schwaden. Das eigentliche Halbtransparenz-Overlay
        # legt die Szene darueber; das hier macht das Feld schon am Boden
        # erkennbar -- auch dann, wenn nichts darauf steht.
        for i, offset in enumerate((-h * 0.44, 0.0, h * 0.44)):
            reach = h * (0.34 if i == 1 else 0.24)
            shapes.append(B((offset - h * 0.10, offset + h * 0.10),
                            (-reach, reach),
                            (HEIGHT_FLAT, HEIGHT_FLAT + 0.4), "accent"))
    return shapes


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


def build_tile(region_id: str, terrain_class: str, meta: dict) -> bool:
    tid = meta["id"]
    colors = COLORS.get(tid)
    if colors is None:
        raise SystemExit(f"[terrain] {region_id}/{tid}: keine Farben definiert")

    import build_sample_parts as bsp
    saved = bsp.MATERIALS
    bsp.MATERIALS = _materials(colors)
    try:
        body = render(_tile_shapes(terrain_class, tid), "south")
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

    svg = SVG_HEAD.format(tid=tid, tclass=terrain_class, name=meta["name"],
                          tw=2 * TILE_HALF_W, th=2 * TILE_HALF_W * COS45)
    svg += body + "</svg>\n"
    return _write(OUT_DIR / region_id / meta["svg"], svg)


def build_overlay() -> int:
    """
    Ein einziges Rauten-Overlay fuer alle Feldmarkierungen.

    Blau fuer Bewegung, rot fuer Angriff, grau fuer ungueltige Ziele, gelb
    fuer die Auswahl -- das sind vier Farben, nicht vier Grafiken. Die Szene
    faerbt dieselbe Raute ueber ``modulate``. Ein Overlay je Zustand waere
    vierfache Pflege fuer dieselbe Form.
    """
    h = TILE_HALF
    corners = [project((f * h, l * h, 0.0), "south")
               for f, l in ((1, 1), (1, -1), (-1, -1), (-1, 1))]
    path = "M" + " L".join(f"{x:.2f} {y:.2f}" for x, y in corners) + " Z"

    written = 0
    fill = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" '
            'width="128" height="128">\n'
            '  <title>Feldmarkierung</title>\n'
            '  <!-- Erzeugt von tools/build_terrain_tiles.py. Weiss, damit die\n'
            '       Szene per modulate einfaerben kann: blau = erreichbar,\n'
            '       rot = Ziel, grau = keine Sichtlinie, gelb = ausgewaehlt. -->\n'
            f'  <path d="{path}" fill="#ffffff"/>\n'
            '</svg>\n')
    written += int(_write(OUT_DIR / "overlay_tile.svg", fill))

    outline = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" '
               'width="128" height="128">\n'
               '  <title>Feldumriss</title>\n'
               f'  <path d="{path}" fill="none" stroke="#ffffff" '
               'stroke-width="2" stroke-linejoin="round"/>\n'
               '</svg>\n')
    written += int(_write(OUT_DIR / "overlay_outline.svg", outline))

    # Richtungspfeil fuer gerichtete Drift. Zeigt nach Bildschirm-rechts-unten
    # (Gitterrichtung +x); die Szene dreht ihn um Vielfache von 90 Grad.
    tip = project((h * 0.62, 0.0, HEIGHT_FLAT + 0.4), "south")
    left = project((-h * 0.20, h * 0.34, HEIGHT_FLAT + 0.4), "south")
    right = project((-h * 0.20, -h * 0.34, HEIGHT_FLAT + 0.4), "south")
    arrow = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" '
             'width="128" height="128">\n'
             '  <title>Drift-Richtung</title>\n'
             '  <!-- Nur fuer gerichtete Drift (Magnetschiene). Ungerichtete\n'
             '       Drift traegt stattdessen die Schliere im Tile selbst. -->\n'
             f'  <path d="M{tip[0]:.2f} {tip[1]:.2f} L{left[0]:.2f} {left[1]:.2f} '
             f'L{right[0]:.2f} {right[1]:.2f} Z" fill="#ffffff" opacity="0.85"/>\n'
             '</svg>\n')
    written += int(_write(OUT_DIR / "overlay_drift_arrow.svg", arrow))
    return written


def main() -> int:
    regions = json.loads(REGION_FILE.read_text(encoding="utf-8"))["regions"]
    written = 0
    total = 0
    for region in regions:
        region_id = region["id"]
        for terrain_class in ("normal", "step", "block", "drift", "haze"):
            meta = region.get(terrain_class)
            if meta is None:
                raise SystemExit(
                    f"[terrain] Region {region_id} belegt {terrain_class} nicht")
            total += 1
            written += int(build_tile(region_id, terrain_class, meta))

    overlays = build_overlay()
    print(f"[ok] {total} Terrain-Tiles und 3 Overlays nach "
          f"{OUT_DIR.relative_to(ROOT)}/ ({written + overlays} neu geschrieben)")
    print(f"     Bodenraute {2 * TILE_HALF_W:.0f} x {2 * TILE_HALF_W * COS45:.0f} px "
          f"um (64, 96), Halbkante {TILE_HALF:.3f} Entwurfseinheiten")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
