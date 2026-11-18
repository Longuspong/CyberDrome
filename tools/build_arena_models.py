#!/usr/bin/env python3
"""
Hindernisse des Kampffelds als 3D-Modelle (18. Nov. 2026).

Seit der Kampf EINE 3D-Szene ist (docs/UEBERGABE_3D.md, Schritt 4), stehen
Hindernisse und DROMEs in derselben Welt -- wer hinter einem Hindernis steht,
wird richtig verdeckt. Die Modelle entstehen mit denselben Bausteinen wie die
DROMEs (B, L, O/OB aus tools/build_sample_parts.py) und im selben Format
(``.m3d``), das Spiel baut sie mit ``DromeModel``.

Ein Modell je Hindernisart aus data/config.json -> obstacles.kinds. Die
Vorderseite (+f) zeigt im Kampf zur Kamera. Ein Hexfeld hat 22 Einheiten
Eckradius (IsoView.HEX_R); Hindernisse bleiben unter ~36 Einheiten Hoehe,
damit sie DROMEs (~80) nicht ganz verdecken.

    python3 tools/build_arena_models.py          # schreibt assets/arena3d/
    python3 tools/build_arena_models.py --check  # prueft, ob alles aktuell ist
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import build_sample_parts as g  # noqa: E402

B, L, O, OB = g.B, g.L, g.O, g.OB
OUT = ROOT / "assets" / "arena3d"


def roles(plate, light, dark, metal, accent, glow, visor, outline):
    return {"plate": plate, "plate_light": light, "plate_dark": dark, "metal": metal,
            "accent": accent, "glow": glow, "visor": visor, "outline": outline}


# Farben je Region (Arcade-Glitch: Nacht, Violett, Cyan, Magenta).
CITY = roles("#3a3060", "#5a4a8a", "#1b1430", "#6e5ab4", "#2ee3eb", "#ff2bd6", "#2ee3eb", "#05020a")
GREEN = roles("#5b5a50", "#7d7b6c", "#34332c", "#6a7a5a", "#6fbf4a", "#c8ff7a", "#c8ff7a", "#0d0f0a")
PLANT = roles("#5a4a3a", "#8a7454", "#2a2018", "#7a8088", "#ff8a2d", "#ffc07a", "#ffc07a", "#0d0a08")


def mirror(shapes):
    return shapes + g._mirror_l(shapes)


# --------------------------------------------------------------- Neon City
BARRIER = [
    B((-6, 6), (-15, 15), (0, 4), "dark"),
    B((-4.5, 4.5), (-14, 14), (4, 14), "plate"),
    B((-3, 3), (-13.5, 13.5), (14, 17), "light"),
    B((4.5, 4.9), (-11, 11), (7.5, 9.5), "accent"),          # Leuchtstreifen vorn
]

CRATES = [
    B((-10, 4), (-9, 5), (0, 12), "plate"), B((-9, 3), (-8, 4), (12, 13), "light"),
    B((2, 11), (-2, 9), (0, 9), "plate"), B((-6, 3), (-6, 3), (13, 21), "plate"),
    B((4, 4.4), (0, 7), (3, 6), "accent"), B((-10.4, -10), (-7, 3), (4, 8), "accent"),
]

SERVER = [
    B((-7, 7), (-6, 6), (0, 32), "plate"),
    B((-7.5, 7.5), (-6.5, 6.5), (32, 34), "light"),
    B((7, 7.4), (-5, 5), (3, 30), "dark"),                   # Front
] + [B((7.4, 7.7), (-4, -1), (5 + i * 4.5, 6.2 + i * 4.5), "accent") for i in range(6)] \
  + [B((7.4, 7.7), (2.5, 4), (5 + i * 4.5, 6.2 + i * 4.5), "glow") for i in range(0, 6, 2)]

VENDING = [
    B((-7, 7), (-9, 9), (0, 30), "plate"),
    B((-7.5, 7.5), (-9.5, 9.5), (30, 32), "light"),
    B((7, 7.4), (-7, 3), (10, 27), "glow"),                  # Leuchtfront
    B((7, 7.6), (4, 8), (14, 24), "dark"),                   # Tasten
    B((7.6, 7.9), (5, 7), (20, 22), "accent"),
    B((7, 7.6), (-7, 3), (3, 7), "dark"),                    # Ausgabe
]

GENERATOR = [
    B((-9, 9), (-12, 12), (0, 12), "plate"),
    B((-9.5, 9.5), (-12.5, 12.5), (12, 13.5), "light"),
    L((0, -5), [(0, 13.5), (5, 13.5), (5, 24), (3.5, 26), (0, 26)], "metal"),
    L((0, 6), [(0, 13.5), (4, 13.5), (4, 20), (0, 20)], "metal"),
    L((0, -5), [(5.2, 18), (5.2, 19.4)], "accent", caps=False),
    B((9, 9.4), (-9, 9), (4, 6), "accent"),
]

BOLLARDS = []
for l in (-10, 0, 10):
    BOLLARDS += [
        L((0, l), [(0, 0), (3.2, 0), (3.2, 16), (2.4, 18), (0, 18)], "metal", segments=10),
        L((0, l), [(3.4, 12), (3.4, 14)], "glow", caps=False, segments=10),
    ]

HOLO = [
    L((0, 0), [(0, 0), (9, 0), (9, 3), (7, 4.5), (0, 4.5)], "plate", segments=12),
    L((0, 0), [(7.4, 4.5), (7.4, 5.2)], "accent", caps=False, segments=12),
    L((0, 0), [(0, 5), (4.5, 8), (5.5, 20), (2, 30), (0, 30)], "glow", segments=6),
]

SPOOL = [
    L((0, 13), [(0, -9), (13, -9), (13, -6), (0, -6)], "plate", axis="l", segments=16),
    L((0, 13), [(0, 6), (13, 6), (13, 9), (0, 9)], "plate", axis="l", segments=16),
    L((0, 13), [(8, -6), (8, 6)], "accent", axis="l", caps=False, segments=16),
    L((0, 13), [(0, -6), (4, -6), (4, 6), (0, 6)], "metal", axis="l", segments=10),
]

# ---------------------------------------------------------------- Parkanlage
RUIN = [
    B((-6, 2), (-14, 10), (0, 22), "plate"),
    B((-6, 2), (-14, -4), (22, 32), "plate"),
    O((-2, 5, 24), (8, 9, 6), (0, 0, 28), "plate"),          # abgebrochene Kante
    B((-7, 3), (-15, 11), (0, 3), "dark"),
    B((2, 2.5), (-12, 8), (0, 6), "accent"),                 # Moos unten
    B((-6.4, 2.4), (-14.4, -3.6), (31, 32.6), "accent"),     # Moos oben
    O((6, -10, 2.5), (6, 7, 5), (25, 0, 8), "light"),        # Brocken
]

ROCK = [
    L((0, 0), [(0, 0), (13, 0), (12, 8), (8, 15), (3, 18), (0, 18.5)], "plate", segments=7),
    O((5, 6, 6), (9, 8, 9), (20, -12, 10), "light"),
    O((-4, -7, 4), (8, 7, 8), (-30, 8, 0), "plate"),
    L((0, 0), [(0, 17), (4, 17), (3, 19.5), (0, 20)], "accent", segments=7),   # Moos
]

# --------------------------------------------------------------- Factory 5
TANK = [
    L((0, 0), [(0, 0), (11, 0), (11, 26), (9, 31), (4, 33), (0, 33.5)], "metal", segments=16),
    L((0, 0), [(11.2, 10), (11.2, 13)], "accent", caps=False, segments=16),
    L((0, 0), [(11.2, 20), (11.2, 21)], "plate", caps=False, segments=16),
    B((9, 12), (-2, 2), (14, 22), "dark"),                   # Anzeige
    L((0, 0), [(0, 33), (1.6, 33), (1.6, 37), (0, 37)], "glow", segments=8),   # Lampe
]

PIPES = []
for i, (f, l, h) in enumerate(((-4, -9, 30), (1, 0, 26), (-3, 9, 22))):
    PIPES += [
        L((f, l), [(0, 0), (4, 0), (4, h), (0, h)], "metal", segments=12),
        L((f, l), [(0, h), (5, h), (5, h + 2), (0, h + 2)], "plate", segments=12),
        L((f, l), [(4.2, h * 0.55), (4.2, h * 0.55 + 2)], "accent", caps=False, segments=12),
    ]

CRATE = [
    B((-9, 9), (-9, 9), (0, 16), "plate"),
    B((-9.4, 9.4), (-9.4, 9.4), (16, 17.5), "light"),
    B((9, 9.4), (-9, 9), (6, 9), "accent"),                  # Warnband
    B((-9, 9), (9, 9.4), (6, 9), "accent"),
    B((9, 9.3), (-1, 1), (0, 16), "dark"),
]

MODELS = {
    "barrier": (BARRIER, CITY), "crates": (CRATES, CITY), "server": (SERVER, CITY),
    "vending": (VENDING, CITY), "generator": (GENERATOR, CITY), "bollards": (BOLLARDS, CITY),
    "holo": (HOLO, CITY), "spool": (SPOOL, CITY),
    "ruin": (RUIN, GREEN), "rock": (ROCK, GREEN),
    "tank": (TANK, PLANT), "pipes": (PIPES, PLANT), "crate": (CRATE, PLANT),
    "block": (CRATE, CITY),
}


def render_all() -> dict:
    out = {}
    for kind, (shapes, colors) in MODELS.items():
        faces, hulls = g.model_faces(shapes)
        out[f"{kind}.m3d"] = json.dumps(
            {"id": kind, "type": "obstacle", "colors": colors, "faces": faces,
             "hulls": hulls, "anchors": {"mount": [0, 0, 0]}},
            ensure_ascii=False, separators=(",", ":")) + "\n"
    return out


def main() -> None:
    files = render_all()
    config = json.loads((ROOT / "data" / "config.json").read_text(encoding="utf-8"))
    kinds = {k for lst in config["obstacles"]["kinds"].values() for k in lst}
    missing = sorted(k for k in kinds if f"{k}.m3d" not in files)
    if missing:
        raise SystemExit(f"Kein 3D-Modell fuer Hindernisart(en): {', '.join(missing)}")
    if "--check" in sys.argv:
        stale = [n for n, text in files.items()
                 if not (OUT / n).exists() or (OUT / n).read_text(encoding="utf-8") != text]
        if stale:
            raise SystemExit("assets/arena3d veraltet: " + ", ".join(stale)
                             + " -- python3 tools/build_arena_models.py")
        print("assets/arena3d ist aktuell.")
        return
    OUT.mkdir(parents=True, exist_ok=True)
    for name, text in files.items():
        (OUT / name).write_text(text, encoding="utf-8")
    print(f"{len(files)} Hindernis-Modelle nach {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
