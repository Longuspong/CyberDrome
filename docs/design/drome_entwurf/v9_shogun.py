"""Runde 9: Shogun Kage nach dem Boss-Bild (assets/story/boss_shogun_kage.jpg)
-- so nah am Bild wie die Bausteine es erlauben, Farben aus dem Bild gemessen.

Aus dem Bild: keine Beine, er schwebt auf einer achteckigen Plattform mit
orangen Segmenten und rotem Antriebsring; glockenfoermiger Plattenrock;
kantiger Helm mit orangen V-Hoernern und breitem rotem Visier; grosse
Schulterplatten mit oranger Kante; Katana mit beiden Haenden schraeg nach
unten vorn, Klinge rot mit weissem Kern; zerfetzter Umhang mit rotem Rand,
der nach hinten weht.

    python3 docs/design/drome_entwurf/v9_shogun.py <ausgabe-ordner>
"""
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[3] / "tools"))
import build_sample_parts as g  # noqa: E402

B, D, L = g.B, g.D, g.L
OCT = 8          # Drehkoerper als Achteck -- wie die kantige Plattform im Bild


def mirror(shapes):
    return shapes + g._mirror_l(shapes)


def slope(f0, f1, l0, l1, z0, z1, n, mat, thick=1.0):
    """Schraege aus n duennen Stufen (Quader koennen sich nicht drehen):
    laeuft von (f0, z0) nach (f1, z1); l bleibt fest."""
    s = []
    for i in range(n):
        a, b = i / n, (i + 1) / n
        fa, fb = f0 + (f1 - f0) * a, f0 + (f1 - f0) * b
        z = z0 + (z1 - z0) * (a + b) / 2
        s.append(B(sorted((fa, fb + (0.15 if f1 > f0 else -0.15))), (l0, l1),
                   (z - thick / 2, z + thick / 2), mat))
    return s


# ======================================================================
# Schwebeplattform (achteckig) mit Antrieb
# ======================================================================
PLATFORM = [
    L((0, 0), [(0, 4.0), (16.5, 4.0), (18.5, 5.6), (18.5, 8.6), (15.5, 10.4), (0, 10.4)],
      "plate", segments=OCT),
    L((0, 0), [(0, 10.4), (13.0, 10.4), (13.0, 11.4), (0, 11.4)], "dark", segments=OCT),
    L((0, 0), [(0, 2.6), (11.0, 2.6), (12.5, 4.0), (0, 4.0)], "dark", segments=OCT),
]
PLATFORM_GLOW = [
    # roter Antriebsring unter der Plattform und der Kern in der Mitte
    L((0, 0), [(8.0, 2.2), (11.6, 2.2), (11.6, 2.7), (8.0, 2.7), (8.0, 2.2)], "glow", segments=24),
    L((0, 0), [(4.0, 2.0), (6.0, 2.0), (6.0, 2.5), (4.0, 2.5), (4.0, 2.0)], "accent", segments=24),
    L((0, 0), [(0, 0.6), (2.2, 1.6), (3.0, 2.4), (0, 2.4)], "glow", segments=16),
]
# orange Segmente am Rand (vier Seiten + vier Ecken)
PLATFORM_ORANGE = []
for f0, f1, l0, l1 in ((16.4, 19.2, -4, 4), (-19.2, -16.4, -4, 4),
                       (-4, 4, 16.4, 19.2), (-4, 4, -19.2, -16.4)):
    PLATFORM_ORANGE.append(B((f0, f1), (l0, l1), (5.4, 8.8), "plate"))
for sf in (1, -1):
    for sl in (1, -1):
        c = 11.6
        PLATFORM_ORANGE.append(B(sorted((sf * (c - 1.6), sf * (c + 1.6))),
                                 sorted((sl * (c - 1.6), sl * (c + 1.6))), (5.6, 8.6), "plate"))

# ======================================================================
# Plattenrock (Glocke aus gestuften Lamellen, achteckig)
# ======================================================================
SKIRT = []
for zb, zt, r0, r1 in ((11.4, 16.6, 15.5, 14.2), (16.4, 21.4, 13.6, 12.4),
                       (21.2, 26.0, 12.0, 11.0), (25.8, 29.6, 10.6, 10.0)):
    SKIRT.append(L((0, 0), [(0, zb), (r0, zb), (r1, zt), (0, zt)], "plate", segments=OCT))
    SKIRT.append(L((0, 0), [(r0 + 0.2, zb), (r0 + 0.2, zb + 0.8)], "metal", caps=False, segments=OCT))
# senkrechte Lamellenfugen vorn (Bild: Platten nebeneinander)
for l in (-7.5, -2.5, 2.5, 7.5):
    SKIRT.append(B((13.0, 14.4), (l - 0.25, l + 0.25), (12.0, 16.4), "dark"))
    SKIRT.append(B((11.2, 12.6), (l - 0.25, l + 0.25), (17.0, 21.2), "dark"))

# ======================================================================
# Rumpf
# ======================================================================
TORSO = [
    B((-7, 8), (-9.5, 9.5), (29, 33), "metal"),                 # Huefte
    B((-8, 9), (-11, 11), (33, 50), "plate"),                   # Do
    B((-8.5, 9.5), (-11.5, 11.5), (48.5, 51.5), "light"),       # Brustrand
    B((9, 9.6), (-9.5, 9.5), (34, 48), "dark"),                 # Brustplatte
    B((-8.6, -8), (-9.5, 9.5), (34, 48), "dark"),               # Rueckenplatte
    B((-3, 3), (-3.5, 3.5), (50, 54), "metal"),                 # Hals
]
# Brustlamellen quer (dunkle Fugen)
for z in (37.5, 41.0, 44.5):
    TORSO.append(B((9.6, 9.9), (-9.2, 9.2), (z, z + 0.6), "light"))
TORSO_ORANGE = [
    B((9.6, 10.4), (-5.6, -3.4), (29.5, 46.0), "plate"),        # senkrechter Gurt (Bild)
    B((9.6, 10.6), (-6.0, -3.0), (39.0, 41.5), "light"),        # Schnalle
    B((-7.6, 8.8), (-10.0, 10.0), (29.6, 31.4), "plate"),       # Guertel
    B((9.6, 10.0), (3.0, 8.5), (46.2, 47.4), "plate"),          # Zierleiste Brust
]

# ======================================================================
# Schulterplatten (kantig, mit oranger Unterkante)
# ======================================================================
def pauldron():
    s = [
        B((-6.5, 7.0), (11.5, 21.0), (46.0, 54.5), "plate"),
        B((-7.0, 7.5), (12.0, 21.5), (54.5, 56.0), "light"),
        B((-5.5, 6.0), (14.5, 22.5), (40.5, 46.5), "plate"),
        B((-5.0, 5.5), (16.5, 23.5), (36.0, 41.0), "plate"),
        B((7.0, 7.5), (13.5, 19.5), (49.0, 52.5), "metal"),     # Frontblende
    ]
    trim = [
        B((-5.6, 6.1), (22.5, 23.0), (40.5, 41.6), "plate"),
        B((-5.1, 5.6), (23.5, 24.0), (36.0, 37.1), "plate"),
        B((-6.6, 7.1), (21.0, 21.5), (46.0, 47.1), "plate"),
    ]
    return s, trim


P_L, P_L_TRIM = pauldron()
PAULDRONS = P_L + g._mirror_l(P_L)
PAULDRON_ORANGE = P_L_TRIM + g._mirror_l(P_L_TRIM)

# ======================================================================
# Arme: beide Haende am Griff vor dem Bauch; die Klinge zeigt quer zu
# seiner linken Seite (+l) schraeg nach unten -- wie im Bild
# ======================================================================
ARMS = [
    # rechter Arm (-l): Oberarm haengt, Unterarm nach vorn zur Mitte
    B((-3, 3), (-18, -13), (40, 48), "metal"),
    B((-3.5, 3.5), (-18.5, -12.5), (37, 41), "dark"),           # Ellbogen
    B((0, 9), (-17, -12), (36.5, 41.5), "plate"),               # Unterarm
    B((8, 13), (-12, -6), (36.5, 41.5), "plate"),
    B((11, 15.5), (-7.6, -3.0), (36.2, 41.8), "dark"),          # Faust (hinten am Griff)
    # linker Arm (+l): Unterarm nach vorn, Faust vorn am Griff
    B((-3, 3), (13, 18), (40, 48), "metal"),
    B((-3.5, 3.5), (12.5, 18.5), (37, 41), "dark"),
    B((0, 10), (12, 17), (35.5, 40.5), "plate"),
    B((9, 13.5), (4, 13), (35.5, 40.5), "plate"),
    B((11.5, 16), (0.4, 5.0), (35.0, 40.6), "dark"),            # Faust (vorn am Griff)
]
ARMS_ORANGE = [
    B((7.4, 8.2), (-17.4, -11.6), (36.2, 41.8), "plate"),       # Handgelenk-Ringe
    B((8.4, 9.2), (11.6, 17.4), (35.2, 40.8), "plate"),
]

# ======================================================================
# Helm (kantig), Visier, Hoerner
# ======================================================================
HELMET = [
    B((-6.5, 7.0), (-7.0, 7.0), (55.0, 64.0), "plate"),         # Helmkoerper
    B((-6.0, 6.0), (-6.0, 6.0), (64.0, 67.0), "plate"),         # Kuppel, Stufe
    B((-4.5, 4.0), (-4.5, 4.5), (67.0, 68.6), "light"),
    B((-1.0, 1.5), (-1.0, 1.0), (68.6, 70.0), "metal"),         # Tehen
    B((7.0, 9.0), (-7.0, 7.0), (60.4, 63.2), "plate"),          # Stirnschirm
    B((7.0, 8.4), (-6.0, 6.0), (54.0, 57.6), "dark"),           # Maske unten
    B((8.4, 9.0), (-3.0, 3.0), (54.2, 56.0), "metal"),
    # Shikoro: Nackenschutz in Stufen nach hinten unten
    B((-9.0, -6.0), (-8.5, 8.5), (56.0, 61.0), "plate"),
    B((-10.5, -8.6), (-9.5, 9.5), (52.5, 57.0), "plate"),
    B((-11.5, -10.2), (-10.0, 10.0), (49.5, 53.5), "plate"),
]
VISOR = [
    B((7.4, 8.6), (-6.4, 6.4), (57.6, 60.4), "dark"),           # Visierrahmen
    B((8.6, 9.0), (-5.8, 5.8), (58.2, 59.8), "accent"),         # roter Rand
    B((8.8, 9.2), (-4.8, 4.8), (58.6, 59.4), "glow"),           # weiss gluehender Kern
]
ORANGE_HEAD = [
    # Fukigaeshi: orange Seitenbloecke
    B((2.0, 8.0), (7.0, 9.6), (57.0, 63.5), "plate"),
    B((2.0, 8.0), (-9.6, -7.0), (57.0, 63.5), "plate"),
    B((8.0, 8.4), (7.4, 9.2), (58.0, 62.5), "light"),
    B((8.0, 8.4), (-9.2, -7.4), (58.0, 62.5), "light"),
    # Maedate-Fuss
    B((8.6, 10.0), (-1.6, 1.6), (62.6, 66.0), "plate"),
]
# V-Hoerner: breite flache Balken, nach oben aussen, Enden nach aussen gebogen
for i in range(12):
    lo, hi = 0.8 + i * 0.95, 3.2 + i * 0.95
    z0 = 64.5 + i * 1.45
    ORANGE_HEAD.append(B((8.6, 10.0), (lo, hi), (z0, z0 + 2.6), "accent"))
    ORANGE_HEAD.append(B((8.6, 10.0), (-hi, -lo), (z0, z0 + 2.6), "accent"))
for i in range(4):                                             # Enden biegen aus
    lo, hi = 12.2 + i * 1.3, 14.6 + i * 1.3
    z0 = 81.0 + i * 0.45
    ORANGE_HEAD.append(B((8.6, 10.0), (lo, hi), (z0, z0 + 2.4), "accent"))
    ORANGE_HEAD.append(B((8.6, 10.0), (-hi, -lo), (z0, z0 + 2.4), "accent"))

# ======================================================================
# Katana: Griff quer vor dem Bauch, Klinge zur linken Seite (+l) nach unten
# ======================================================================
def slope_l(f0, f1, l0, l1, z0, z1, n, mat, wide=1.0, thick=1.0, overlap=0.35):
    """Schraege entlang l (von l0 nach l1), f laeuft linear mit."""
    s = []
    for i in range(n):
        a, b = i / n, (i + 1) / n
        la, lb = l0 + (l1 - l0) * a, l0 + (l1 - l0) * b
        z = z0 + (z1 - z0) * (a + b) / 2
        f = f0 + (f1 - f0) * (a + b) / 2
        s.append(B((f - wide / 2, f + wide / 2), (la, lb + overlap), (z - thick / 2, z + thick / 2), mat))
    return s


KATANA_GRIP = slope_l(13.2, 13.6, -9.0, 0.6, 39.6, 38.2, 6, "plate", wide=2.0, thick=2.0)
KATANA_ORANGE = [
    B((12.0, 14.6), (-10.6, -9.0), (38.6, 40.8), "plate"),      # Kashira (Knauf)
    B((11.4, 16.0), (5.0, 6.4), (35.4, 40.0), "plate"),         # Tsuba
]
BLADE_N = 48
# Rot aussen, weiss gluehender Kern, der oben aus der Klinge schaut (Bild)
BLADE = (slope_l(13.7, 17.0, 6.4, 44.0, 37.6, 27.0, BLADE_N, "accent", wide=1.6, thick=2.6)
         + slope_l(13.7, 17.0, 6.4, 43.0, 38.1, 27.6, BLADE_N, "glow", wide=0.6, thick=2.2)
         + slope_l(17.0, 17.3, 44.0, 47.5, 27.0, 25.6, 6, "accent", wide=1.0, thick=1.6))

# ======================================================================
# Umhang: haengt hinten an den Schultern und weht nach hinten aussen
# ======================================================================
CAPE = [B((-10.0, -8.6), (-11.5, 11.5), (40.0, 55.0), "plate")]
CAPE_EDGE = []
# Bahnen, die nach hinten (-f) und zur Seite (-l) wehen, unterschiedlich lang
for k, (l0, l1, length, drop) in enumerate(((6, 11, 14, 9), (1, 6, 20, 11), (-4, 1, 26, 12),
                                            (-9, -4, 31, 14), (-14, -9, 24, 10),
                                            (-19, -14, 17, 8))):
    n = 10
    for i in range(n):
        a, b = i / n, (i + 1) / n
        fa, fb = -10.0 - length * a, -10.0 - length * b
        z = 52.0 - drop * (a + b) / 2
        side = -3.0 * (a + b) / 2                               # weht nach -l
        CAPE.append(B((fb, fa + 0.2), (l0 + side, l1 + side + 0.3),
                      (z - 1.6 * drop / n - 0.6, z + 0.8), "plate"))
    # gluehender Saum am Ende der Bahn, Fetzen
    fe = -10.0 - length
    CAPE_EDGE.append(B((fe - 1.6, fe + 0.4), (l0 - 3.0 + 0.4, l1 - 3.0 - 0.4),
                       (52.0 - drop - 0.9, 52.0 - drop + 0.3), "glow"))
    if k % 2 == 0:
        CAPE_EDGE.append(B((fe - 3.6, fe - 1.4), (l0 - 3.0 + 1.2, l0 - 3.0 + 2.6),
                           (52.0 - drop - 1.6, 52.0 - drop - 0.6), "plate"))


def roles(plate, light, dark, metal, accent, glow, visor, outline="#07020d"):
    return {"plate": plate, "plate_light": light, "plate_dark": dark, "metal": metal,
            "accent": accent, "glow": glow, "visor": visor, "outline": outline}


# Farben aus dem Bild gemessen (Rueckstrahlung der Stadt herausgerechnet)
ARMOR = roles("#2c2140", "#4a3a66", "#160f22", "#5d4f78", "#ec274a", "#fcddd7", "#fcddd7")
ORANGE = roles("#f28328", "#f6a340", "#b44d38", "#fab373", "#f6a340", "#fbe74e", "#fbe74e")
CLOTH = roles("#2a0d40", "#3c1854", "#170326", "#370c54", "#ec274a", "#ff2a4a", "#ff2a4a")
GRIP = roles("#241030", "#40142f", "#12061a", "#8d4d84", "#f28328", "#fcddd7", "#fcddd7")
BLADE_C = roles("#ec274a", "#f0186c", "#ae2d89", "#f6bce3", "#ec274a", "#fcddd7", "#fcddd7")
HOVER = roles("#2c2140", "#4a3a66", "#160f22", "#5d4f78", "#ec274a", "#ec274a", "#fdacac")

BLOCKS = {
    "ruestung": (PLATFORM + SKIRT + TORSO + PAULDRONS + ARMS + HELMET + VISOR, ARMOR),
    "antrieb": (PLATFORM_GLOW, HOVER),
    "orange": (PLATFORM_ORANGE + TORSO_ORANGE + PAULDRON_ORANGE + ARMS_ORANGE
               + ORANGE_HEAD + KATANA_ORANGE, ORANGE),
    "umhang": (CAPE + CAPE_EDGE, CLOTH),
    "griff": (KATANA_GRIP, GRIP),
    "klinge": (BLADE, BLADE_C),
}

if __name__ == "__main__":
    out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/shogun9")
    out.mkdir(parents=True, exist_ok=True)
    for name, (shapes, colors) in BLOCKS.items():
        faces, hulls = g.model_faces(shapes)
        (out / f"shogun_{name}.m3d").write_text(json.dumps(
            {"id": f"shogun_{name}", "colors": colors, "faces": faces,
             "hulls": hulls, "anchors": {"mount": [0, 0, 0]}},
            separators=(",", ":")))
    print("ok", out, {k: len(v[0]) for k, v in BLOCKS.items()})
