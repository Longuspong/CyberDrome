#!/usr/bin/env python3
"""Schneidet die Neon-City-Teile fuer die Arena zu (9. Nov. 2026).

Quelle: drei KI-Bilder unter art/arena_city/ (Ordner hat .gdignore, Godot
importiert sie nicht):
  boden.webp        4x4 Bodenkacheln in Draufsicht, je 256 px
  hindernisse.webp  4x2 Hindernisse auf Gruen, je Zelle 364x360
  deko.webp         3x2 Deko fuer den Randstreifen auf Gruen, Zellen mit Linien

Ziel: assets/arena/city/
  floor_<name>.png  Bodenkachel als Spiel-Raute (76x54) in doppelter Groesse
  <name>.png        Objekt freigestellt, doppelte Groesse
  sprites.json      je Objekt der Ankerpunkt (Feldmitte in Texturpixeln)

Die Objekte sind etwas flacher gezeichnet als das Spiel (etwa 1,8:1 statt
1,4:1) -- bleibt so, sieht im Spiel stimmig aus. Breiten unten in Anteilen
der Feldbreite.

Aufruf: python3 tools/cut_arena_city.py   (danach godot --import)
"""
import json
import os

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art", "arena_city")
OUT = os.path.join(ROOT, "assets", "arena", "city")

TW, TH = 76.0, 54.0       # IsoView.TILE_W / TILE_H
SCALE = 2                 # Texturen in doppelter Aufloesung

# Bodenkacheln: (Zeile, Spalte) im 4x4-Blatt
FLOOR = {
    "concrete_a": (0, 2), "concrete_b": (0, 3), "concrete_c": (1, 3),
    "grid_cyan": (1, 0), "grid_magenta": (1, 2),
    "hatch": (3, 0), "grate": (3, 1), "warning": (3, 2), "drain": (3, 3),
}

# Objekte: Datei, Spalten, Zeilen, Zelle -> Name, Breite in Feldbreiten
OBSTACLES = ("hindernisse.webp", 4, 2, {
    (0, 0): ("barrier", 0.95), (0, 1): ("crates", 0.95),
    (0, 2): ("server", 0.6), (0, 3): ("vending", 0.6),
    (1, 0): ("generator", 0.85), (1, 1): ("bollards", 0.8),
    (1, 2): ("holo", 0.65), (1, 3): ("spool", 0.75),
})
DECO = ("deko.webp", 3, 2, {
    (0, 0): ("shop", 1.5), (0, 1): ("lamp", 0.75), (0, 2): ("dish", 0.8),
    (1, 0): ("shelter", 1.4), (1, 1): ("ac", 1.3), (1, 2): ("antenna", 0.75),
})


def iso_floor(tile: Image.Image) -> Image.Image:
    """Draufsicht -> Spiel-Raute. Maske 1 px groesser, damit keine Fugen bleiben."""
    w, h = int(TW * SCALE), int(TH * SCALE)
    rot = tile.rotate(45, expand=True, resample=Image.BICUBIC).resize((w, h), Image.LANCZOS)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).polygon([(w / 2, -1), (w + 1, h / 2), (w / 2, h + 1), (-1, h / 2)], fill=255)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(rot, (0, 0), mask)
    return out


def key_green(cell: np.ndarray) -> np.ndarray:
    """Weicher Gruen-Key: halbtransparentes (Hologramm) bleibt halb sichtbar."""
    rgb = cell[..., :3].astype(float)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    greenness = g - np.maximum(r, b)
    alpha = np.clip((170.0 - greenness) / 110.0, 0.0, 1.0)
    g2 = np.minimum(g, np.maximum(r, b) + 8.0)          # Gruenstich entfernen
    out = np.dstack([r, g2, b, alpha * 255.0])
    return out.clip(0, 255).astype(np.uint8)


def cut_objects(spec, anchors: dict) -> None:
    name_file, cols, rows, cells = spec
    sheet = np.asarray(Image.open(os.path.join(SRC, name_file)).convert("RGB"))
    ch, cw = sheet.shape[0] / rows, sheet.shape[1] / cols
    inset = 8   # Trennlinien zwischen den Zellen weglassen
    for (row, col), (name, width) in cells.items():
        y0, x0 = int(row * ch) + inset, int(col * cw) + inset
        cell = key_green(sheet[y0:int((row + 1) * ch) - inset, x0:int((col + 1) * cw) - inset])
        solid = cell[..., 3] > 128
        ys, xs = np.where(solid)
        # Begrenzung ueber deckende Pixel, Rand fuer Leuchten
        pad = 4
        top, bottom = max(ys.min() - pad, 0), min(ys.max() + pad + 1, cell.shape[0])
        left, right = max(xs.min() - pad, 0), min(xs.max() + pad + 1, cell.shape[1])
        img = Image.fromarray(cell[top:bottom, left:right], "RGBA")
        # Vordere Spitze der Grundflaeche: unterste deckende Zeilen
        low = solid[top:bottom, left:right]
        last = np.where(low.any(axis=1))[0].max()
        tip_x = np.where(low[last - 2:last + 1].any(axis=0))[0].mean()
        target_w = TW * width * SCALE
        f = target_w / img.width
        img = img.resize((max(1, round(img.width * f)), max(1, round(img.height * f))), Image.LANCZOS)
        tip = (tip_x * f, last * f)
        # Feldmitte = Spitze minus halbe Rautenhoehe der Grundflaeche (Spielmass)
        center = (tip[0], tip[1] - target_w * TH / TW / 2.0)
        img.save(os.path.join(OUT, name + ".png"), optimize=True)
        anchors[name] = {"anchor": [round(center[0], 1), round(center[1], 1)],
                         "size": [img.width, img.height]}


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    sheet = Image.open(os.path.join(SRC, "boden.webp")).convert("RGB")
    inset = 10   # dunkle Raender zwischen den Kacheln
    for name, (row, col) in FLOOR.items():
        tile = sheet.crop((col * 256 + inset, row * 256 + inset,
                           col * 256 + 256 - inset, row * 256 + 256 - inset)).resize((256, 256), Image.LANCZOS)
        iso_floor(tile).save(os.path.join(OUT, "floor_" + name + ".png"), optimize=True)
    anchors: dict = {}
    cut_objects(OBSTACLES, anchors)
    cut_objects(DECO, anchors)
    with open(os.path.join(OUT, "sprites.json"), "w", encoding="utf-8") as fh:
        json.dump({"_kommentar": "erzeugt von tools/cut_arena_city.py -- nicht von Hand aendern. "
                   "anchor: Feldmitte in Texturpixeln, Texturen in doppelter Groesse.",
                   "scale": SCALE, "sprites": anchors}, fh, indent=1, ensure_ascii=False)
    print("geschrieben:", len(FLOOR), "Bodenkacheln,", len(anchors), "Objekte ->", OUT)


if __name__ == "__main__":
    main()
