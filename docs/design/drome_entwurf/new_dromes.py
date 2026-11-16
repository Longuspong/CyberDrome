"""Entwuerfe fuer neue DROME-Formen -- nur Scratch, nutzt den echten Generator."""
import re, sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[3] / "tools"))
import build_sample_parts as g
B, D, L = g.B, g.D, g.L
OUT = pathlib.Path(sys.argv[1]); OUT.mkdir(parents=True, exist_ok=True)


def shift(shapes, df=0, dl=0, dz=0):
    res = []
    for s in shapes:
        if s[0] == "box":
            _, f, l, z, m = s
            res.append(("box", (f[0]+df, f[1]+df), (l[0]+dl, l[1]+dl), (z[0]+dz, z[1]+dz), m))
        elif s[0] == "disc":
            _, f, lc, zc, r, m, seg = s
            res.append(("disc", f+df, lc+dl, zc+dz, r, m, seg))
        else:
            _, c, prof, m, axis, seg, caps = s
            d = {"f": df, "l": dl, "z": dz}
            cax = {"z": ("f", "l"), "l": ("f", "z"), "f": ("l", "z")}[axis]
            c = (c[0]+d[cax[0]], c[1]+d[cax[1]])
            prof = tuple((r, p+d[axis]) for r, p in prof)
            res.append(("lathe", c, prof, m, axis, seg, caps))
    return res


def mirror(shapes):
    """Spiegelt an l=0 (nur Quader und Scheiben)."""
    res = []
    for s in shapes:
        if s[0] == "box":
            _, f, l, z, m = s
            res.append(("box", f, (-l[1], -l[0]), z, m))
        elif s[0] == "disc":
            _, f, lc, zc, r, m, seg = s
            res.append(("disc", f, -lc, zc, r, m, seg))
        else:
            _, c, prof, m, axis, seg, caps = s
            if axis == "z":
                res.append(("lathe", (c[0], -c[1]), prof, m, axis, seg, caps))
            elif axis == "f":
                res.append(("lathe", (-c[0], c[1]), prof, m, axis, seg, caps))
            else:
                res.append(("lathe", c, tuple((r, -p) for r, p in reversed(prof)), m, axis, seg, caps))
    return res


def sym(shapes):
    return shapes + mirror(shapes)


# ---------------------------------------------------------------- Paletten
def scheme(plate, light, dark, metal, accent, glow, visor, outline):
    return dict(plate=plate, plate_light=light, plate_dark=dark, metal=metal,
                accent=accent, glow=glow, visor=visor, outline=outline)

PAL = {
    "vireo": scheme("#3a4670", "#6574a6", "#212842", "#7d8bb0", "#2de2e6", "#7affff", "#7affff", "#080b13"),
    "molok": scheme("#5a4050", "#8f6c80", "#33242d", "#9a8796", "#ff8a3d", "#ffc07a", "#ffc07a", "#100a0e"),
    "nimbus": scheme("#463673", "#7860b0", "#261c44", "#8f7fbd", "#b06bff", "#e6b0ff", "#e0c8ff", "#0d0818"),
    "strix": scheme("#2a4e48", "#4f8578", "#163029", "#74a394", "#6dff9f", "#b0ffd4", "#c2ffd7", "#060f0d"),
}
OLD = {
    "vireo": scheme("#28304a", "#47547e", "#161b29", "#5b6785", "#2de2e6", "#5affff", "#5affff", "#080b13"),
    "molok": scheme("#3d2b35", "#694c5c", "#22181e", "#7d6b78", "#ff8a3d", "#ffb76a", "#ffb76a", "#100a0e"),
    "nimbus": scheme("#2f2450", "#5a4a8c", "#1a1430", "#6f5f97", "#b06bff", "#dd98ff", "#d6b8ff", "#0d0818"),
    "strix": scheme("#1c3330", "#355a52", "#0f1c1a", "#557d71", "#6dff9f", "#9affcc", "#c2ffd7", "#060f0d"),
}


# ---------------------------------------------------------------- Vireo neu
# Plaenkler mit festem Puls-Blaster im linken Unterarm (+l, zur Kamera),
# schlanke Taille, V-Torso, Schubduesen am Ruecken, Kamm statt Antenne.
V_LEG = [
    B((-3.5, 3.5), (3.5, 8), (24, 35), "plate"),        # Oberschenkel
    B((-4, 4), (3, 8.5), (20, 24), "metal"),            # Knie
    B((3.5, 5.5), (3.8, 7.7), (19, 27), "light"),       # Knieschutz
    B((-3, 3.5), (3.8, 7.7), (6, 20), "plate"),         # Schienbein
    B((-6, 7), (3.5, 8), (0, 6), "plate"),              # Fuss
    B((7, 10.5), (4.2, 7.3), (0, 3.5), "dark"),         # Spitze
    B((-8.5, -6), (4.5, 7), (1, 5), "metal"),           # Ferse
    B((7, 7.5), (4.5, 7), (3.5, 5), "accent"),
]
V_BODY = sym(V_LEG) + [
    B((-5, 5), (-8.5, 8.5), (34, 39), "metal"),          # Huefte
    B((-4.5, 5), (-6, 6), (39, 45), "dark"),             # Taille
    B((-6, 7), (-9, 9), (45, 52), "plate"),
    B((-6.5, 8), (-11, 11), (52, 60), "plate"),
    B((-6, 7.5), (-10, 10), (60, 62), "light"),
    B((8, 8.6), (-6, 6), (46, 59), "dark"),              # Brustplatte
    B((8.6, 9.1), (-6, -1.2), (56, 57.4), "accent"),
    B((8.6, 9.1), (1.2, 6), (56, 57.4), "accent"),
    D(8.7, 0, 51.5, 3.6, "dark"), D(8.9, 0, 51.5, 2.3, "glow"),
    # Schubduesen am Ruecken
    L((-9, 5), [(2.0, 42), (2.6, 50), (2.2, 59)], "metal", segments=12),
    L((-9, -5), [(2.0, 42), (2.6, 50), (2.2, 59)], "metal", segments=12),
    L((-9, 5), [(1.5, 39.5), (1.5, 42)], "glow", segments=10),
    L((-9, -5), [(1.5, 39.5), (1.5, 42)], "glow", segments=10),
    B((-7, -6.5), (-4, 4), (47, 58), "dark"),
    # Schultern
    B((-5.5, 5.5), (11, 17), (54, 62), "plate"),
    B((-6, 6), (10.5, 17.5), (62, 64), "light"),
    B((5.5, 6), (12, 16), (57, 59), "accent"),
    B((-5.5, 5.5), (-17, -11), (54, 62), "plate"),
    B((-6, 6), (-17.5, -10.5), (62, 64), "light"),
    B((5.5, 6), (-16, -12), (57, 59), "accent"),
    # Oberarme
    B((-2.5, 2.5), (12.5, 16.5), (45, 54), "metal"),
    B((-2.5, 2.5), (-16.5, -12.5), (45, 54), "metal"),
    # rechter Arm (-l): Unterarm + Faust
    B((-3, 3.5), (-17, -12), (34, 45), "plate"),
    B((-2.5, 4), (-16.5, -12.5), (29.5, 34), "dark"),
    B((3.5, 4), (-16, -13), (39, 41), "accent"),
    # linker Arm (+l): Puls-Blaster fest im Unterarm
    B((-4, 5), (11.5, 17.5), (33, 45), "plate"),
    B((5, 12), (12.3, 16.7), (35.5, 42), "plate"),
    B((5, 12), (12, 17), (42, 43), "light"),
    B((12, 14), (12.8, 16.2), (36, 41.5), "dark"),
    D(14.1, 14.5, 38.7, 1.6, "glow"),
    B((-3.5, 4.5), (17.5, 18), (39, 41.5), "accent"),
    B((6, 11), (16.7, 17.1), (38, 39.4), "accent"),
    # Hals + Kopf
    B((-2.5, 2.5), (-3, 3), (62, 65), "metal"),
    B((-5, 5.5), (-5.5, 5.5), (65, 74), "plate"),
    B((-5.5, 5), (-6, 6), (74, 76), "light"),
    B((5.5, 7), (-4.5, 4.5), (65.5, 71.5), "dark"),
    B((7, 7.5), (-4, 4), (68.2, 70.4), "visor"),
    B((-4, 2), (5.5, 6.8), (67, 75), "metal"),
    B((-4, 2), (-6.8, -5.5), (67, 75), "metal"),
    B((-1, 2), (5.6, 7), (75, 77), "accent"),
    B((-1, 2), (-7, -5.6), (75, 77), "accent"),
    B((-6, 4), (-0.8, 0.8), (76, 81), "accent"),         # Kamm
]


# ---------------------------------------------------------------- Molok neu
# Tank: Kopf tief zwischen den Schultern, zwei grosse Unterarme mit je
# einem Waffenanker (leuchtende Fassung vorn). Gezeigt: Hammer + Schild.
M_FEET = [s for s in g.JUGG_FEET]
M_ARM = [
    B((-4, 4), (15, 23), (44, 56), "metal"),             # Oberarm
    B((-5.5, 6.5), (14, 24), (28, 44), "plate"),         # Unterarm
    B((-6, 7), (13.5, 24.5), (40, 42), "light"),
    D(6.6, 19, 35, 3.0, "dark"), D(6.8, 19, 35, 1.7, "glow"),  # Anker
    B((-4.5, 5.5), (14.5, 23.5), (23, 28), "dark"),      # Faust
]
M_BODY = M_FEET + sym(M_ARM) + [
    B((-7, 7), (-11, 11), (31, 38), "metal"),
    B((-8, 9), (-12, 12), (38, 48), "plate"),
    B((-9, 10.5), (-14, 14), (48, 60), "plate"),
    B((-8, 9.5), (-13, 13), (60, 62.5), "light"),
    B((10.5, 11.5), (-10, 10), (42, 58), "dark"),        # Frontpanzer
    B((11.5, 12), (-8, 8), (44, 45.4), "accent"),
    B((11.5, 12), (-8, 8), (56, 57.4), "accent"),
    D(11.7, 0, 50.7, 4.4, "dark", 6), D(11.9, 0, 50.7, 2.4, "glow", 6),
    # Schultern hoeher als der Kopf
    B((-9, 9), (13, 25), (56, 70), "plate"),
    B((-9.5, 9.5), (12.5, 25.5), (70, 73), "light"),
    B((9, 9.6), (15, 23), (62, 65), "accent"),
    B((-9, 9), (-25, -13), (56, 70), "plate"),
    B((-9.5, 9.5), (-25.5, -12.5), (70, 73), "light"),
    B((9, 9.6), (-23, -15), (62, 65), "accent"),
    # Kopf tief
    B((-5, 7), (-7, 7), (61, 68), "plate"),
    B((-5.5, 7.5), (-7.5, 7.5), (68, 70), "light"),
    B((7, 7.6), (-5, 5), (63.5, 65.6), "visor"),
    B((7, 8.2), (-7, 7), (60.5, 62.5), "metal"),         # Kinnschutz
    # Auspuff
    L((-9.5, 8), [(2.4, 58), (2.4, 76), (3.0, 76), (3.0, 78)], "metal", segments=12),
    L((-9.5, -8), [(2.4, 58), (2.4, 76), (3.0, 76), (3.0, 78)], "metal", segments=12),
    L((-9.5, 8), [(3.1, 72), (3.1, 73.5)], "accent", caps=False, segments=12),
    L((-9.5, -8), [(3.1, 72), (3.1, 73.5)], "accent", caps=False, segments=12),
]
M_HAMMER = [                                             # am +l-Anker
    B((5, 17), (17.6, 20.4), (24, 27), "metal"),
    B((17, 26), (12, 27), (16, 35), "plate"),
    B((26, 26.8), (13, 26), (17.5, 33.5), "dark"),
    B((17, 26), (11.7, 27.3), (24.5, 26.5), "accent"),
    D(27, 19.5, 25.5, 2.2, "glow"),
]
M_SHIELD = [                                             # am -l-Anker
    B((7, 10), (-32, -16), (14, 54), "plate"),
    B((7, 10.5), (-32.5, -15.5), (54, 56), "light"),
    B((10, 10.6), (-30, -18), (17, 51), "dark"),
    B((10.6, 11.1), (-29, -19), (42, 43.6), "accent"),
    B((10.6, 11.1), (-29, -19), (23, 24.6), "accent"),
    D(10.8, -24, 33, 3.4, "dark", 6), D(11.0, -24, 33, 2.0, "glow", 6),
]


# ---------------------------------------------------------------- Nimbus neu
# Form bleibt (Hut + Rad), Stab fest in der linken Hand, dazu ein Runen-Ring
# hinter dem Kopf und schwebende Runen -- liest sich als "Zauberer".
N_RING = [
    L((0, 70), [(12.5, -7.2), (14.0, -7.2), (14.0, -6.4), (12.5, -6.4), (12.5, -7.2)],
      "accent", axis="f", segments=28),
    B((-7.3, -6.3), (-1, 1), (83, 86), "glow"),
    B((-7.3, -6.3), (12, 14), (68.8, 71.2), "glow"),
    B((-7.3, -6.3), (-14, -12), (68.8, 71.2), "glow"),
]
N_BODY = (g.MAGE_DRIVE + g.MAGE_BODY + g.MAGE_HEAD + g.MAGE_CORE + N_RING
          + shift(g.EQ_RUNE_STAFF, dl=13.8))


# ---------------------------------------------------------------- Strix A
# "Eule": geduckt, lang und flach. Kapuze mit zwei grossen Linsen, Fluegel-
# Mantel an den Seiten, Railgun quer ueber der linken Schulter.
SA_LEG = [
    B((-6, 0), (3.5, 7.5), (22, 32), "plate"),
    L((-3, 5.5), [(2.6, 18), (2.6, 24)], "metal", segments=12),
    B((-9, -4), (4, 7), (10, 22), "plate"),
    B((-8.5, -4.5), (4.2, 6.8), (5, 10), "metal"),
    B((-6, 6), (3.5, 7.5), (0, 5), "plate"),
    B((6, 9.5), (3.6, 5), (0, 2), "dark"),
    B((6, 9.5), (6, 7.4), (0, 2), "dark"),
    B((-10.5, -7), (4.8, 6.2), (0, 2), "dark"),
    B((-9.3, -8.8), (4.4, 6.6), (14, 18), "accent"),
]
SA_BODY = sym(SA_LEG) + [
    B((-6, 4), (-6, 6), (30, 36), "metal"),
    B((-7, 5), (-8, 8), (36, 44), "plate"),
    B((-5, 8), (-9, 9), (44, 52), "plate"),
    B((-4, 8.5), (-8, 8), (52, 54), "light"),
    # Fluegel-Mantel
    B((-12, 5), (9, 13), (44, 56), "plate"),
    B((-12.5, 5.5), (8.5, 13.5), (56, 59), "light"),
    B((-13, 3), (10, 15), (32, 44), "plate"),
    B((-14, 0), (11, 17), (20, 32), "plate"),
    B((-14, 0), (17, 17.5), (24, 25.3), "accent"),
    B((-13, 3), (15, 15.5), (36, 37.3), "accent"),
    B((-12, 5), (13, 13.5), (48, 49.3), "accent"),
    B((-12, 5), (-13, -9), (44, 56), "plate"),
    B((-12.5, 5.5), (-13.5, -8.5), (56, 59), "light"),
    B((-13, 3), (-15, -10), (32, 44), "plate"),
    B((-14, 0), (-17, -11), (20, 32), "plate"),
    # Kapuze
    B((3, 13), (-7.5, 7.5), (49, 60), "plate"),
    B((2.5, 13.5), (-8, 8), (60, 62), "light"),
    B((2, 6), (3, 6), (62, 67), "plate"),
    B((2, 6), (-6, -3), (62, 67), "plate"),
    B((5, 6.3), (3.5, 5.5), (63, 66), "accent"),
    B((5, 6.3), (-5.5, -3.5), (63, 66), "accent"),
    B((13, 13.6), (-5.2, 5.2), (51, 59), "dark"),
    D(13.7, 2.6, 55.5, 2.3, "dark"), D(13.8, 2.6, 55.5, 1.5, "visor"),
    D(13.7, -2.6, 55.5, 2.3, "dark"), D(13.8, -2.6, 55.5, 1.5, "visor"),
    B((13.6, 14.6), (-0.8, 0.8), (51.5, 54), "metal"),   # Schnabel
    # Kern am Ruecken
    B((-7.6, -7), (-2, 2), (38, 43), "dark"),
    B((-7.8, -7.6), (-1.2, 1.2), (38.6, 42.4), "glow"),
    # Railgun ueber der +l-Schulter
    B((-16, 26), (9.5, 11.5), (59, 62), "metal"),
    B((-12, 24), (9.7, 11.3), (62, 62.8), "accent"),
    B((-6, 4), (8.5, 12.5), (58, 63.5), "plate"),
    L((10.5, 60.5), [(2.4, 8), (2.4, 10)], "dark", axis="f", segments=12),
    L((10.5, 60.5), [(2.4, 15), (2.4, 17)], "dark", axis="f", segments=12),
    B((26, 30), (9, 12), (58.3, 62.7), "dark"),
    D(30.2, 10.5, 60.5, 1.4, "glow"),
]

# ---------------------------------------------------------------- Strix B
# "Reiher": hohe Stelzbeine mit Knie nach hinten, kleiner Rumpf oben, langer
# Lauf als Schnabel nach vorn, Sensormast.
SB_LEG = [
    B((-1, 3), (4, 6.5), (42, 50), "metal"),
    B((2, 6), (4, 6.5), (33, 42), "metal"),
    L((5, 32.5), [(2.4, 3.6), (2.4, 6.9)], "dark", axis="l", segments=12),
    B((1, 5), (4.2, 6.3), (22, 32), "plate"),
    B((-2, 2), (4.2, 6.3), (12, 22), "plate"),
    B((-4, 0), (4.2, 6.3), (4, 12), "plate"),
    B((-4.3, 0.3), (4, 6.5), (8.5, 9.8), "accent"),
    B((-4, 9), (4.5, 6), (0, 3), "plate"),
    B((9, 11), (4.7, 5.8), (0, 1.5), "dark"),
    B((-8, -4), (4.8, 5.8), (0, 2), "dark"),
]
SB_BODY = sym(SB_LEG) + [
    B((-4, 4), (-7, 7), (49, 53), "metal"),
    B((-8, 6), (-6, 6), (53, 64), "plate"),
    B((-8.5, 6.5), (-6.5, 6.5), (64, 66), "light"),
    B((6, 6.6), (-4.5, 4.5), (55, 63), "dark"),
    B((6.6, 7), (-3.5, 3.5), (60.5, 61.5), "accent"),
    # Sensorkopf
    L((1, 0), [(3.8, 66), (3.8, 72.5), (2.2, 74), (0, 74.4)], "plate"),
    L((1, 0), [(4.0, 68.6), (4.0, 70.4)], "visor", caps=False, segments=16),
    B((-5, -4), (-0.6, 0.6), (66, 86), "metal"),
    B((-5.5, -3.5), (-1, 1), (86, 88), "glow"),
    # Leitwerk
    B((-15, -8), (-1, 1), (55, 63), "plate"),
    B((-15.5, -14.9), (-1.2, 1.2), (56, 62), "accent"),
    # Kern
    B((-8.6, -8), (-2, 2), (55, 60), "dark"),
    B((-8.8, -8.6), (-1.2, 1.2), (55.6, 59.4), "glow"),
    # Lauf als Schnabel
    B((-4, 30), (-1.8, 1.8), (47, 50.5), "metal"),
    B((4, 16), (-2.6, 2.6), (46.5, 51), "plate"),
    B((4, 16), (-2.9, 2.9), (48, 49.2), "accent"),
    B((16, 30), (-1.2, 1.2), (50.5, 51.1), "accent"),
    B((30, 33), (-2.4, 2.4), (46.6, 51), "dark"),
    D(33.2, 0, 48.8, 1.4, "glow"),
]

DESIGNS = {
    "vireo_neu": (V_BODY, "vireo"),
    "molok_neu": (M_BODY + M_HAMMER + M_SHIELD, "molok"),
    "molok_anker": (M_BODY, "molok"),
    "nimbus_neu": (N_BODY, "nimbus"),
    "strix_a": (SA_BODY, "strix"),
    "strix_b": (SB_BODY, "strix"),
}


def paint(svg, cs):
    return re.sub(r"var\(--c-([a-z-]+)\)", lambda m: cs[m.group(1).replace("-", "_")], svg)


def rim(svg, color):
    """Kontur in der Signalfarbe: alle Flaechen einmal dick dahinter."""
    s = re.sub(r'fill="[^"]*"', f'fill="{color}"', svg)
    s = s.replace('stroke="none"', "")
    s = re.sub(r'stroke="[^"]*" stroke-width="0.9"', f'stroke="{color}" stroke-width="3.2"', s, count=1)
    return s


def write(name, shapes, cs, facing, with_rim=True):
    body = paint(g.render(shapes, facing), cs)
    under = rim(body, cs["accent"]) if with_rim else ""
    vb = "-14 -14 156 156"
    (OUT / f"{name}_{facing}.svg").write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}" width="624" height="624">'
        f'{under}{body}</svg>')


if __name__ == "__main__":
    for name, (shapes, pal) in DESIGNS.items():
        for facing in g.DIRECTIONS:
            write(name, shapes, PAL[pal], facing)
        write(name + "_ohnerand", shapes, PAL[pal], "south", with_rim=False)
    # alte Formen mit neuem Licht
    old = {
        "vireo": g.SCOUT_FEET + g.SCOUT_BODY + g.SCOUT_HEAD + g.SCOUT_CORE + shift(g.EQ_BLASTER, dl=14),
        "strix": g.STRIX_FEET + g.STRIX_BODY + g.STRIX_HEAD + g.STRIX_CORE,
    }
    for k, shapes in old.items():
        write(k + "_alt_licht", shapes, PAL[k], "south")
    print("ok")
