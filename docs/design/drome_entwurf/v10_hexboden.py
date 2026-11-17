"""Runde 10: Hexboden aus dem 3D-Generator -- nur Entwurf.

Sechseck-Platten (Drehkoerper mit 6 Segmenten) in mehreren Sorten, dazu
Hindernisse und ein Plan fuer ein Hexfeld. Farben aus dem Design-System
(Arcade-Glitch): Nacht, Violett, Cyan, Magenta, Gelb; Teamfarben fuer die
Aufstellzonen. Ein Feld ist so gross wie heute ein Rautenfeld (~40 Einheiten).

    python3 docs/design/drome_entwurf/v10_hexboden.py <ausgabe-ordner>
"""
import json
import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[3] / "tools"))
import build_sample_parts as g  # noqa: E402

B, D, L = g.B, g.D, g.L
R = 22.0          # Aussenradius einer Platte (Ecke), Ecke zeigt entlang f
GAP = 0.7         # Fuge zwischen den Platten
HEX = 6


def hex_slab(r_top, z_top=0.0, depth=5.0, bevel=0.9, mat="plate"):
    """Sechseckige Platte, Oberseite auf z_top, Kante oben angefast."""
    r = r_top
    return [L((0, 0), [(0, z_top - depth), (r, z_top - depth), (r, z_top - bevel),
                       (r - bevel, z_top), (0, z_top)], mat, segments=HEX)]


def hex_ring(r_out, r_in, z, h=0.18, mat="glow"):
    return [L((0, 0), [(r_in, z), (r_out, z), (r_out, z + h), (r_in, z + h), (r_in, z)],
              mat, segments=HEX)]


def hex_inlay(r, z, depth=0.4, mat="dark"):
    """Eingelassene Sechseckflaeche (etwas tiefer als die Oberseite)."""
    return [L((0, 0), [(0, z - depth), (r, z - depth), (r, z), (0, z)], mat, segments=HEX)]


RT = R - GAP
TILES = {
    "beton": hex_slab(RT),
    "beton_b": hex_slab(RT) + [B((-3, 3), (-9, -6), (0, 0.25), "light"),
                               B((5, 7), (4, 10), (0, 0.25), "light")],
    "gitter": hex_slab(RT) + hex_inlay(RT - 5.0, 0.02, mat="dark")
              + [B((-12 + i * 4.8, -11 + i * 4.8), (-10, 10), (-0.35, 0.02), "metal") for i in range(5)],
    "fuge": hex_slab(RT) + hex_ring(RT - 2.4, RT - 3.4, 0.0),
    "warn": hex_slab(RT) + [B((-2.0 + i * 0.0, 2.0), (-14 + i * 7, -11 + i * 7), (0, 0.22), "accent")
                            for i in range(5)],
    "zone_spieler": hex_slab(RT) + hex_inlay(RT - 3.0, 0.02, mat="dark")
                    + hex_ring(RT - 3.0, RT - 4.2, 0.0),
    "zone_gegner": hex_slab(RT) + hex_inlay(RT - 3.0, 0.02, mat="dark")
                   + hex_ring(RT - 3.0, RT - 4.2, 0.0),
}

OBSTACLES = {
    # Pfeiler aus Betonbloecken mit Leuchtstreifen
    "pfeiler": [B((-8, 8), (-8, 8), (0, 26), "plate"), B((-9, 9), (-9, 9), (26, 30), "light"),
                B((8, 8.5), (-6, 6), (12, 14), "accent"), B((-6, 6), (8, 8.5), (12, 14), "accent"),
                B((-9.5, 9.5), (-9.5, 9.5), (0, 3), "dark")],
    # Kistenstapel
    "kisten": [B((-10, 4), (-9, 5), (0, 12), "plate"), B((-9, 3), (-8, 4), (12, 13), "light"),
               B((2, 11), (-2, 9), (0, 9), "plate"), B((-6, 3), (-6, 3), (13, 21), "plate"),
               B((4, 4.4), (0, 7), (3, 6), "accent"), B((-10.4, -10), (-7, 3), (4, 8), "accent")],
}


def roles(plate, light, dark, metal, accent, glow, visor, outline="#05020a"):
    return {"plate": plate, "plate_light": light, "plate_dark": dark, "metal": metal,
            "accent": accent, "glow": glow, "visor": visor, "outline": outline}


# Design-System: night #0a0618, violet #1b0b3a, card-line #6e5ab4, cyan #2ee3eb,
# magenta #ff2bd6, yellow #ffe14d; Teamfarben player #4db8f2, enemy #f26b61
FLOOR = roles("#2a2147", "#3d3166", "#140d26", "#4a3d78", "#ffe14d", "#2ee3eb", "#2ee3eb")
COLORS = {
    "beton": FLOOR,
    "beton_b": roles("#262040", "#372d5c", "#120b22", "#4a3d78", "#ffe14d", "#2ee3eb", "#2ee3eb"),
    "gitter": FLOOR,
    "fuge": roles("#2a2147", "#3d3166", "#140d26", "#4a3d78", "#ff2bd6", "#ff2bd6", "#ff2bd6"),
    "warn": FLOOR,
    "zone_spieler": roles("#22304f", "#2f4570", "#101a2c", "#4db8f2", "#4db8f2", "#4db8f2", "#4db8f2"),
    "zone_gegner": roles("#3a2140", "#55305c", "#1c0d22", "#f26b61", "#f26b61", "#f26b61", "#f26b61"),
    "pfeiler": roles("#3a3060", "#5a4a8a", "#1b1430", "#6e5ab4", "#2ee3eb", "#2ee3eb", "#2ee3eb"),
    "kisten": roles("#4a3a2a", "#6e5a40", "#251c14", "#8a7454", "#ffe14d", "#ffe14d", "#ffe14d"),
}


def axial_to_fl(q, r):
    """Hex-Mitte (Ecke entlang f): Reihen entlang f, Spalten entlang l."""
    return (1.5 * R * r, math.sqrt(3) * R * (q + r / 2.0))


def board(radius=5):
    """Ein Hexfeld mit Radius 5 (91 Felder): Zonen an zwei Raendern, ein paar
    Hindernisse punktsymmetrisch, Sorten gemischt."""
    cells = []
    for q in range(-radius, radius + 1):
        for r in range(max(-radius, -q - radius), min(radius, -q + radius) + 1):
            kind = ("beton", "beton_b", "beton", "gitter", "beton", "fuge")[(q * 7 + r * 3) % 6]
            if r >= radius - 1:
                kind = "zone_spieler"
            elif r <= -radius + 1:
                kind = "zone_gegner"
            elif r == 0 and abs(q) == 1:
                kind = "warn"
            cells.append({"q": q, "r": r, "kind": kind, "fl": axial_to_fl(q, r)})
    obstacles = []
    for q, r, kind in ((-2, 1, "pfeiler"), (2, -1, "pfeiler"), (3, 0, "kisten"), (-3, 0, "kisten")):
        obstacles.append({"q": q, "r": r, "kind": kind, "fl": axial_to_fl(q, r)})
    return {"tiles": cells, "obstacles": obstacles}


if __name__ == "__main__":
    out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/hexboden")
    out.mkdir(parents=True, exist_ok=True)
    for name, shapes in {**TILES, **OBSTACLES}.items():
        faces, hulls = g.model_faces(shapes)
        (out / f"hex_{name}.m3d").write_text(json.dumps(
            {"id": name, "colors": COLORS[name], "faces": faces, "hulls": hulls,
             "anchors": {"mount": [0, 0, 0]}}, separators=(",", ":")))
    (out / "plan.json").write_text(json.dumps(board(), indent=1))
    print("ok", out)
