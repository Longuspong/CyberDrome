"""Runde 8: Shogun Kage (Boss der Neon Ninja's) -- nur Optik, Entwurf.

Gebaut aus denselben Bausteinen wie die DROMEs (Quader B, Scheiben D,
Drehkoerper L aus tools/build_sample_parts.py) und als 3D-Modelle
geschrieben (wie <id>.m3d), damit der echte Spiel-Renderer (DromeModel)
ihn zeigen kann. Drei Bloecke mit eigener Palette: Ruestung, Gold, Katana.

    python3 docs/design/drome_entwurf/v8_shogun.py <ausgabe-ordner>
"""
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[3] / "tools"))
import build_sample_parts as g  # noqa: E402

B, D, L = g.B, g.D, g.L


def mirror(shapes):
    return shapes + g._mirror_l(shapes)


# ------------------------------------------------------------ Beine
LEG = [
    B((-3.5, 3.5), (3.6, 8.6), (23, 33), "metal"),           # Oberschenkel
    B((-4.2, 4.2), (3.2, 9.0), (19.5, 23.5), "dark"),        # Knie
    B((4.2, 5.2), (3.6, 8.6), (19, 24.5), "light"),          # Kniebuckel
    B((-3.2, 3.8), (3.8, 8.4), (6, 19.5), "plate"),          # Schienbein
    B((3.8, 4.8), (3.4, 8.8), (8, 19), "dark"),              # Suneate (Schiene)
    B((4.8, 5.1), (5.6, 6.6), (9, 18), "accent"),
    B((-6, 8.5), (3.4, 9.0), (0, 6), "plate"),               # Fuss
    B((8.5, 10.5), (4.2, 8.2), (0, 3.5), "dark"),
]

# ------------------------------------------------------------ Kusazuri (Plattenrock)
def tasset(f0, f1, l0, l1, z_top, rows=2, step=5.0, out=0.8, axis="f"):
    """Gestufte Lamellen: jede Reihe etwas tiefer und weiter aussen."""
    s = []
    for i in range(rows):
        zt, zb = z_top - i * step, z_top - (i + 1) * step - 0.6
        if axis == "f":
            s.append(B((f0 + i * out, f1 + i * out), (l0, l1), (zb, zt), "plate"))
            s.append(B((f1 + i * out, f1 + i * out + 0.4), (l0 + 0.4, l1 - 0.4), (zb, zb + 1.0), "accent"))
        else:
            s.append(B((f0, f1), (l0 + i * out, l1 + i * out), (zb, zt), "plate"))
            s.append(B((f0 + 0.4, f1 - 0.4), (l1 + i * out, l1 + i * out + 0.4), (zb, zb + 1.0), "accent"))
    return s


KUSAZURI = (
    tasset(6.5, 8.0, -8.5, -0.4, 35) + tasset(6.5, 8.0, 0.4, 8.5, 35)        # vorn
    + tasset(-6, 6, 9.5, 11, 35, axis="l")                                    # Seite links
    + g._mirror_l(tasset(-6, 6, 9.5, 11, 35, axis="l"))                       # Seite rechts
    + [B((-8.5, -7.0), (-8.5, 8.5), (24, 35), "plate")]                        # hinten
)

# ------------------------------------------------------------ Do (Brustpanzer)
DO = [
    B((-6, 6.5), (-8.5, 8.5), (33, 39), "metal"),             # Huefte
    B((-7, 8), (-10.5, 10.5), (39, 57), "plate"),             # Rumpf
    B((-7.5, 8.5), (-11, 11), (55, 58), "light"),             # Brustrand
    B((8, 8.8), (-9, 9), (40, 55), "dark"),                   # Brustplatte
] + [
    # Odoshi: rote Schnuerung quer ueber die Brust
    B((8.8, 9.2), (-8.5, 8.5), (z, z + 0.9), "accent") for z in (42, 45.5, 49)
] + [
    D(9.25, 0, 52.3, 3.0, "dark"), D(9.45, 0, 52.3, 1.9, "glow"),   # Kern (Mon)
    B((-7.5, -7.0), (-9, 9), (40, 55), "dark"),               # Rueckenplatte
    B((-3, 3), (-3.5, 3.5), (58, 61), "metal"),               # Hals
]

# ------------------------------------------------------------ Sode (Schulterplatten)
def sode(side):
    s = []
    for i, (zt, w) in enumerate(((60.5, 0.0), (55.5, 0.9), (50.5, 1.8))):
        l0, l1 = 12.0 + w, 20.0 + w
        s.append(B((-6.5, 6.5), (l0, l1), (zt - 5.4, zt), "plate"))
        s.append(B((-6.6, 6.6), (l1 - 0.2, l1 + 0.3), (zt - 5.4, zt - 4.4), "accent"))
    s.append(B((-5, 5), (11, 15), (58, 61.5), "metal"))      # Gelenk
    return s if side > 0 else g._mirror_l(s)


# ------------------------------------------------------------ Arme
ARM_L = [                                                    # linker Arm: haelt die Saya
    B((-2.5, 2.5), (14.5, 18.5), (44, 55), "metal"),
    B((-2.8, 9.5), (14, 19), (38, 44), "dark"),               # Kote (Unterarm)
    B((1.5, 6.5), (19, 19.4), (40, 42), "accent"),
    B((9.5, 13.5), (14.2, 18.8), (37.5, 43.5), "dark"),       # Faust
]
ARM_R = [                                                    # rechter Arm: Katana nach vorn
    B((-2.5, 2.5), (-18.5, -14.5), (44, 55), "metal"),
    B((-2.8, 11), (-19, -14), (38.5, 44.5), "dark"),
    B((2, 8), (-19.4, -19), (40.5, 42.5), "accent"),
    B((11, 15), (-18.8, -14.2), (38, 44), "dark"),            # Faust um den Griff
]

# ------------------------------------------------------------ Kabuto (Helm)
KABUTO = [
    B((4.5, 8.2), (-5.2, 5.2), (59.5, 66.5), "dark"),         # Menpo (Maske)
    B((8.2, 8.6), (-4.4, 4.4), (63.2, 64.6), "visor"),        # Visierschlitz
    B((8.2, 9.2), (-3.0, 3.0), (59.5, 61.2), "metal"),        # Kinn
    B((8.6, 9.0), (-2.6, -1.6), (59.8, 61.0), "light"),       # Zaehne
    B((8.6, 9.0), (1.6, 2.6), (59.8, 61.0), "light"),
    # Shikoro: Nackenschutz in Stufen, nach unten ausgestellt -- volle
    # Scheiben (Profil bis zur Achse, von unten nach oben wie alle Profile)
    L((-3.5, 0), [(0, 64.4), (8.0, 64.4), (8.0, 65.4), (6.6, 67.2), (0, 67.2)], "plate", segments=16),
    L((-3.5, 0), [(0, 61.8), (9.6, 61.8), (9.6, 62.8), (8.4, 64.6), (0, 64.6)], "plate", segments=16),
    L((-3.5, 0), [(0, 59.0), (11.0, 59.0), (11.0, 60.0), (10.0, 62.0), (0, 62.0)], "plate", segments=16),
    L((-3.5, 0), [(11.2, 59.0), (11.2, 59.3)], "accent", caps=False, segments=16),
    # Hachi: Helmkuppel mit Rippen
    L((-0.5, 0), [(7.6, 66.5), (7.6, 69), (6.4, 72.5), (3.6, 74.6), (0, 75.4)], "plate", segments=18),
    L((-0.5, 0), [(7.9, 66.6), (7.9, 67.6)], "accent", caps=False, segments=18),
    L((-0.5, 0), [(1.2, 75.2), (1.2, 77.0), (0, 77.4)], "metal", segments=10),  # Tehen
    # Fukigaeshi: zurueckgeklappte Seitenlappen
    B((3.0, 7.5), (7.6, 9.6), (63.5, 68), "plate"),
    B((3.0, 7.5), (-9.6, -7.6), (63.5, 68), "plate"),
]

# ------------------------------------------------------------ Umhang (zerfetzt)
CAPE = [B((-11.0, -9.6), (-12, 12), (36, 58), "plate"),
        B((-11.2, -9.4), (-12.4, 12.4), (56, 58.5), "light")]
for i, (l0, l1, zb) in enumerate(((-12, -8, 18), (-8, -4, 24), (-4, 0, 15),
                                  (0, 4, 21), (4, 8, 13), (8, 12, 22))):
    CAPE.append(B((-11.0 - 0.2 * (i % 2), -9.6), (l0, l1), (zb, 36), "plate"))
    CAPE.append(B((-9.6, -9.3), (l0 + 0.3, l1 - 0.3), (zb, zb + 1.2), "accent"))

ARMOR = mirror(LEG) + KUSAZURI + DO + sode(1) + sode(-1) + ARM_L + ARM_R + KABUTO + CAPE

# ------------------------------------------------------------ Gold (Maedate, Zier)
GOLD = [
    B((8.0, 9.0), (-1.4, 1.4), (67.5, 70.5), "plate"),        # Mon an der Stirn
    D(9.05, 0, 69, 1.1, "glow"),
]
# V-Hoerner (Maedate): viele feine Stufen in leuchtendem Gold (Akzent, ohne
# Kantenstrich) -- so lesen sie sich als glatte Schraege nach oben aussen.
for i in range(11):
    lo, hi = 1.2 + i * 0.95, 2.6 + i * 0.95
    z0 = 69.0 + i * 1.55
    GOLD.append(B((7.8, 9.2), (lo, hi), (z0, z0 + 2.4), "accent"))
    GOLD.append(B((7.8, 9.2), (-hi, -lo), (z0, z0 + 2.4), "accent"))
GOLD += [B((-6.7, 6.7), (12.0 + w, 12.6 + w), (zt - 0.6, zt), "light")
         for zt, w in ((60.5, 0.0), (55.5, 0.9), (50.5, 1.8))]
GOLD += g._mirror_l(GOLD[-3:])

# ------------------------------------------------------------ Katana + Wakizashi
KATANA = [
    B((10.5, 16.0), (-17.4, -15.6), (40.1, 41.9), "dark"),    # Tsuka (Griff)
    B((11.5, 12.3), (-17.6, -15.4), (39.9, 42.1), "accent"),  # Wicklung
    B((14.0, 14.8), (-17.6, -15.4), (39.9, 42.1), "accent"),
    B((16.0, 17.0), (-19.0, -14.0), (38.5, 43.5), "metal"),   # Tsuba
    B((17.0, 18.2), (-16.9, -16.1), (40.3, 41.7), "metal"),   # Habaki
    B((18.2, 44.0), (-16.8, -16.2), (40.4, 42.0), "glow"),    # Klinge
    B((18.2, 43.0), (-16.9, -16.1), (40.0, 40.4), "accent"),  # Schneide
    B((44.0, 46.5), (-16.75, -16.25), (40.8, 41.8), "glow"),  # Spitze
    # Wakizashi in der Saya an der linken Huefte
    B((-4.0, 14.0), (12.0, 13.6), (33.0, 34.6), "plate"),
    B((14.0, 15.0), (11.6, 14.0), (32.6, 35.0), "metal"),
    B((15.0, 19.0), (12.2, 13.4), (33.2, 34.4), "dark"),
    B((2.0, 3.0), (11.9, 13.7), (32.9, 34.7), "accent"),
]


def palette(hull, mech, neon, line="#05020a"):
    return g.resolve_roles({"hull": hull, "mech": mech, "neon": neon, "line": line}, "body")


BLOCKS = {
    "ruestung": (ARMOR, palette("#3a3350", "#6b6388", "#ff2a55")),
    "gold": (GOLD, palette("#b07d22", "#e2b24a", "#ffd27a")),
    "katana": (KATANA, palette("#2a2433", "#b9b3cc", "#ff2a55")),
}

if __name__ == "__main__":
    out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/shogun")
    out.mkdir(parents=True, exist_ok=True)
    for name, (shapes, colors) in BLOCKS.items():
        faces, hulls = g.model_faces(shapes)
        (out / f"shogun_{name}.m3d").write_text(json.dumps(
            {"id": f"shogun_{name}", "colors": colors, "faces": faces,
             "hulls": hulls, "anchors": {"mount": [0, 0, 0]}},
            separators=(",", ":")))
    print("ok", out)
