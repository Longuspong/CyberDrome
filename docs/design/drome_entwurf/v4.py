"""Runde 4: Posen. Die Waffe bringt den Arm in ihrer Pose mit."""
import sys
import new_dromes as n
import v2
g, B, D, L = n.g, n.B, n.D, n.L


# ------------------------------------------------------------ Arm-Posen
def arm_extended(l, zs, k=1.0):
    """Fernkampf: Arm gestreckt nach vorn. Gibt (Formen, Handpunkt)."""
    t = 2.2 * k
    sd = 1 if l > 0 else -1
    lo = l + sd * 5 * k                                  # Ellbogen nach aussen
    shapes = [
        B((-2.5 * k, 2.5 * k), sorted((l - sd * t, lo + sd * t)), (zs - 7 * k, zs - 1), "metal"),
        B((-2 * k, 15 * k), (lo - t - 0.3, lo + t + 0.3), (zs - 8.5 * k, zs - 2), "plate"),
        B((8.5 * k, 14.5 * k), (lo - t - 0.4, lo + t + 0.4), (zs - 4 * k, zs - 3 * k), "accent"),
    ]
    return shapes, (15 * k, lo, zs - 5.5 * k)


def arm_raised(l, zs, k=1.0):
    """Nahkampf/Stab/Schild: Oberarm runter, Unterarm nach vorn, kleine Faust."""
    t = 2.0 * k
    sd = 1 if l > 0 else -1
    hf, hl, hz = 12.75 * k, l + sd * 1.0 * k, zs - 12.5 * k
    shapes = [
        B((-2.5 * k, 2.5 * k), (l - t, l + t), (zs - 11 * k, zs - 1), "metal"),
        B((-2.5 * k, 10.5 * k), (l - t - 0.3, l + t + 0.3), (zs - 16 * k, zs - 9 * k), "plate"),
        B((4 * k, 9 * k), (l + t + 0.3, l + t + 0.8), (zs - 13.5 * k, zs - 12 * k), "accent"),
        # Faust: schmal, umschliesst den Griff -- Griff schaut oben und unten raus
        B((hf - 2.2 * k, hf + 2.2 * k), (hl - 2.6 * k, hl + 2.6 * k), (hz - 2.6 * k, hz + 2.6 * k), "dark"),
        B((hf + 2.2 * k, hf + 2.6 * k), (hl - 2.2 * k, hl + 2.2 * k), (hz - 1.6 * k, hz - 0.6 * k), "light"),
        B((hf + 2.2 * k, hf + 2.6 * k), (hl - 2.2 * k, hl + 2.2 * k), (hz + 0.6 * k, hz + 1.6 * k), "light"),
    ]
    return shapes, (hf, hl, hz)


# ------------------------------------------------------------ Waffenkoepfe
def blaster(h, k=1.0):
    f, l, z = h
    return [
        B((f, f + 5 * k), (l - 3 * k, l + 3 * k), (z - 3.5 * k, z + 3.5 * k), "plate"),
        B((f + 5 * k, f + 13 * k), (l - 2 * k, l + 2 * k), (z - 2.3 * k, z + 2.3 * k), "plate"),
        B((f + 5 * k, f + 13 * k), (l - 2.2 * k, l + 2.2 * k), (z + 2.3 * k, z + 3 * k), "light"),
        B((f + 13 * k, f + 15 * k), (l - 1.8 * k, l + 1.8 * k), (z - 2 * k, z + 2 * k), "dark"),
        D(f + 15.1 * k, l, z, 1.4 * k, "glow"),
        B((f + 1 * k, f + 4 * k), (l + 3 * k, l + 3.5 * k), (z - 1, z + 1), "accent"),
    ]


def blade(h, k=1.0):
    """Plasmaklinge mit echtem Griff: Knauf, Griff durch die Faust, Parierstange, Emitter."""
    f, l, z = h
    return [
        B((f - 0.9, f + 0.9), (l - 0.9, l + 0.9), (z - 6 * k, z + 4.4 * k), "metal"),       # Griff
        B((f - 1.5, f + 1.5), (l - 1.5, l + 1.5), (z - 7.8 * k, z - 6 * k), "dark"),        # Knauf
        B((f - 0.7, f + 0.7), (l - 0.7, l + 0.7), (z - 8.6 * k, z - 7.8 * k), "glow"),
        B((f - 2.0, f + 2.0), (l - 5 * k, l + 5 * k), (z + 4.4 * k, z + 6.0 * k), "plate"), # Parierstange
        B((f - 2.1, f + 2.1), (l - 5.4 * k, l - 4.2 * k), (z + 4.2 * k, z + 6.4 * k), "accent"),
        B((f - 2.1, f + 2.1), (l + 4.2 * k, l + 5.4 * k), (z + 4.2 * k, z + 6.4 * k), "accent"),
        B((f - 1.3, f + 1.3), (l - 1.4, l + 1.4), (z + 6.0 * k, z + 9.0 * k), "metal"),     # Emitter
        B((f - 0.7, f + 0.7), (l - 1.1, l + 1.1), (z + 9.0 * k, z + 32 * k), "glow"),      # Klinge
        B((f - 0.5, f + 0.5), (l - 0.6, l + 0.6), (z + 32 * k, z + 36 * k), "glow"),       # Spitze
        B((f + 0.7, f + 1.1), (l - 0.9, l + 0.9), (z + 9.0 * k, z + 31 * k), "accent"),    # Schneide
    ]


def hammer(h, k=1.0):
    f, l, z = h
    return [
        B((f - 0.9 * k, f + 0.9 * k), (l - 0.9 * k, l + 0.9 * k), (z - 8 * k, z + 17 * k), "metal"),
        B((f - 5 * k, f + 5 * k), (l - 4.5 * k, l + 4.5 * k), (z + 16 * k, z + 25 * k), "plate"),
        B((f - 5.3 * k, f + 5.3 * k), (l - 4.8 * k, l + 4.8 * k), (z + 19.8 * k, z + 21.2 * k), "accent"),
        B((f + 5 * k, f + 5.8 * k), (l - 3.5 * k, l + 3.5 * k), (z + 17.5 * k, z + 23.5 * k), "dark"),
        D(f + 6 * k, l, z + 20.5 * k, 1.7 * k, "glow"),
    ]


def staff(h, k=1.0):
    """Runenstab: Schaft durch die Faust, Griffwicklungen, Fassung um die Kugel."""
    f, l, z = h
    return [
        L((f, l), [(2.0, z - 20), (2.0, z - 18)], "dark", segments=10),            # Fusskappe
        L((f, l), [(1.4, z - 18), (1.4, z + 20)], "metal", segments=10),           # Schaft
        L((f, l), [(1.9, z - 4.4), (1.9, z - 3.0)], "accent", caps=False, segments=10),
        L((f, l), [(1.9, z + 3.0), (1.9, z + 4.4)], "accent", caps=False, segments=10),
        L((f, l), [(2.3, z - 9), (2.3, z - 7.6)], "accent", caps=False, segments=10),
        L((f, l), [(2.6, z + 18.6), (3.4, z + 20.4), (3.4, z + 21.4)], "plate", segments=12),
        B((f - 0.7, f + 0.7), (l - 4.4, l - 3.2), (z + 20.4, z + 28.6), "metal"),  # Fassung
        B((f - 0.7, f + 0.7), (l + 3.2, l + 4.4), (z + 20.4, z + 28.6), "metal"),
        B((f - 0.8, f + 0.8), (l - 4.6, l - 3.0), (z + 28.6, z + 29.6), "accent"),
        B((f - 0.8, f + 0.8), (l + 3.0, l + 4.6), (z + 28.6, z + 29.6), "accent"),
        L((f, l), [(0, z + 21.6), (2.2, z + 22.6), (3.0, z + 24.4), (2.2, z + 26.2), (0, z + 27.2)], "glow"),
        L((f, l), [(4.9, z + 23.8), (4.9, z + 24.9)], "accent", caps=False, segments=18),
    ]


def shield(h, k=1.0, toward=-1):
    """Schild angewinkelt vor dem Koerper; toward = Richtung Koerpermitte (l)."""
    f, l, z = h
    a, b = sorted((l - 6 * k * toward, l + 11 * k * toward))
    return [
        B((f + 1.5 * k, f + 3.5 * k), (a, b), (z - 14 * k, z + 15 * k), "plate"),
        B((f + 1.5 * k, f + 4 * k), (a - 0.5, b + 0.5), (z + 15 * k, z + 17 * k), "light"),
        B((f + 3.5 * k, f + 4 * k), (a + 2, b - 2), (z - 12 * k, z + 13 * k), "dark"),
        B((f + 4 * k, f + 4.4 * k), (a + 3, b - 3), (z + 6 * k, z + 7.4 * k), "accent"),
        D(f + 4.5 * k, (a + b) / 2, z - 1 * k, 2.6 * k, "dark", 6),
        D(f + 4.7 * k, (a + b) / 2, z - 1 * k, 1.5 * k, "glow", 6),
    ]


def armed(pose, head, l, zs, k=1.0, **kw):
    arm, hand = (arm_extended if pose == "ext" else arm_raised)(l, zs, k)
    return arm + head(hand, k, **kw)


# ------------------------------------------------------------ Vireo
VB = [s for s in v2.V_CORE if not (s[0] == "box" and s[2] == (12.5, 16.5) and s[3] == (45, 54))]
V_PASSIVE_ARM = [                                        # liegt am Koerper an
    B((-3, 3), (-15.5, -11.5), (34, 45), "plate"),
    B((-2.5, 3.5), (-15, -12), (29.5, 34), "dark"),
    B((3, 3.5), (-14.5, -12.5), (39, 41), "accent"),
]
V_BOOSTER = [                                            # Passive Sprint
    B((-13, -7), (-6.5, 6.5), (44, 62), "plate"),
    B((-13.5, -6.5), (-7, 7), (62, 64), "light"),
    L((-12, 4), [(2.4, 40), (2.8, 44)], "metal", segments=12),
    L((-12, -4), [(2.4, 40), (2.8, 44)], "metal", segments=12),
    L((-12, 4), [(1.9, 36.5), (1.9, 40)], "glow", segments=10),
    L((-12, -4), [(1.9, 36.5), (1.9, 40)], "glow", segments=10),
    B((-12, -8), (6.5, 13), (55, 57), "light"),          # Fluegel
    B((-12, -8), (-13, -6.5), (55, 57), "light"),
    B((-12.2, -11.6), (7, 12.5), (55.5, 56.5), "accent"),
    B((-12.2, -11.6), (-12.5, -7), (55.5, 56.5), "accent"),
    B((-13.6, -13), (-3, 3), (48, 58), "accent"),
    # Helm-Booster
    B((-7.5, -4.5), (2.5, 5), (68, 76), "metal"),
    B((-7.5, -4.5), (-5, -2.5), (68, 76), "metal"),
    B((-7.6, -4.4), (2.4, 5.1), (66, 68), "glow"),
    B((-7.6, -4.4), (-5.1, -2.4), (66, 68), "glow"),
]
VIREO = VB + V_PASSIVE_ARM + V_BOOSTER
V_ARM = dict(l=14.5, zs=54)

# ------------------------------------------------------------ Nimbus
def _drop(s):
    return s[0] == "lathe" and s[4] == "z" and abs(s[1][1] + 13.8) < 0.01 and s[1][0] in (1.0, 3.4)
NB = [s for s in g.MAGE_BODY if not _drop(s) and not (s[0] == "lathe" and s[3] == "glow")]
N_ORB_ARM = [                                            # Passive Echo
    L((-13.8, 40), [(2.6, -1), (3.0, 10)], "plate", axis="f", segments=12),
    L((-13.8, 40), [(3.2, 3.5), (3.2, 4.4)], "accent", axis="f", caps=False, segments=12),
    L((-13.8, 40), [(3.4, 10), (3.4, 12.4)], "dark", axis="f", segments=12),
    L((16.2, -13.8), [(0, 42.2), (2.6, 43.2), (3.6, 46), (2.6, 48.8), (0, 49.8)], "glow", segments=14),
    L((16.2, -13.8), [(5.0, 45.6), (5.6, 45.6), (5.6, 46.4), (5.0, 46.4), (5.0, 45.6)], "accent", segments=20),
    L((19.5, -10.5), [(0, 51), (1.2, 51.5), (1.6, 52.6), (1.2, 53.7), (0, 54.2)], "accent", segments=10),
]
N_HALO = [                                               # Leucht-Ring
    L((0, 70), [(12.6, -7.0), (13.6, -7.0), (13.6, -6.4), (12.6, -6.4), (12.6, -7.0)],
      "glow", axis="f", segments=32),
    B((-7.3, -6.1), (-1, 1), (82.6, 85.4), "glow"),
    B((-7.3, -6.1), (12, 14.4), (68.8, 71.2), "glow"),
    B((-7.3, -6.1), (-14.4, -12), (68.8, 71.2), "glow"),
]
NIMBUS = g.MAGE_DRIVE + NB + g.MAGE_HEAD + g.MAGE_CORE + N_ORB_ARM + N_HALO
N_ARM = dict(l=13.8, zs=50)

# ------------------------------------------------------------ Molok
MREST = n.M_BODY[len(n.M_FEET) + 2 * len(n.M_ARM):]
MOLOK = n.M_FEET + MREST + v2.M_BEACON
M_R, M_L, M_ZS, M_K = 19, -19, 57, 1.6

# ------------------------------------------------------------ Strix (Eule)
STRIX = v2.SA_CORE + v2.SA_SOCKET[:1]
S_LANCE = v2.SA_LANCE
S_MORTAR = [
    B((-5, 3), (8, 13), (61, 64), "metal"),
    L((-1, 10.5), [(3.6, 64), (3.9, 78), (3.4, 82)], "metal", segments=14),
    L((-1, 10.5), [(4.4, 78.5), (4.4, 80)], "accent", caps=False, segments=14),
    L((-1, 10.5), [(2.4, 82), (2.4, 82.6)], "glow", segments=12),
    B((-6, -5), (9, 12), (62, 66), "dark"),
]
S_BLASTER = blaster((4, 10.5, 61.5), 1.0)

DESIGNS = {
    "v4_vireo_blaster": VIREO + armed("ext", blaster, **V_ARM),
    "v4_vireo_klinge": VIREO + armed("up", blade, **V_ARM),
    "v4_vireo_schild": VIREO + armed("up", shield, **V_ARM, toward=-1),
    "v4_vireo_stab": VIREO + armed("up", staff, **V_ARM),
    "v4_nimbus_stab": NIMBUS + armed("up", staff, **N_ARM),
    "v4_nimbus_blaster": NIMBUS + armed("ext", blaster, **N_ARM),
    "v4_nimbus_klinge": NIMBUS + armed("up", blade, **N_ARM),
    "v4_molok_hammer_schild": MOLOK + armed("up", hammer, M_R, M_ZS, M_K) + armed("up", shield, M_L, M_ZS, 1.25, toward=1),
    "v4_molok_blaster_schild": MOLOK + armed("ext", blaster, M_R, M_ZS, M_K) + armed("up", shield, M_L, M_ZS, 1.25, toward=1),
    "v4_molok_klinge_hammer": MOLOK + armed("up", blade, M_R, M_ZS, M_K) + armed("up", hammer, M_L, M_ZS, M_K),
    "v4_strix_lanze": STRIX + S_LANCE,
    "v4_strix_moerser": STRIX + S_MORTAR,
    "v4_strix_blaster": STRIX + S_BLASTER,
}
PALS = {"vireo": "vireo", "nimbus": "nimbus", "molok": "molok", "strix": "strix"}
ALLDIRS = {"v4_vireo_blaster", "v4_nimbus_stab", "v4_molok_hammer_schild", "v4_strix_lanze"}

if __name__ == "__main__":
    for name, shapes in DESIGNS.items():
        pal = n.PAL[name.split("_")[1]]
        for f in (["south", "east"]):
            n.write(name, shapes, pal, f)
    print("ok")
