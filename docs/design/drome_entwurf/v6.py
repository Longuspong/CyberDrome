"""Runde 6: die uebrigen Waffen in Pose, Fernwaffen auf der Lafette, Eule mit
groesseren Linsen. Baut auf v4 auf (Arm-Posen, Chassis)."""
import sys
import new_dromes as n
import v4
g, B, D, L = n.g, n.B, n.D, n.L


# ------------------------------------------------------------ Waffenkoepfe
def neon_blaster(h, k=1.0):
    """Variante des Puls-Blasters: gleiche Silhouette, dazu zwei Neonroehren
    laengs am Lauf und ein Leuchtring vor der Muendung."""
    f, l, z = h
    return v4.blaster(h, k) + [
        B((f + 5.5 * k, f + 12.5 * k), (l + 2.0 * k, l + 2.7 * k), (z - 1.2 * k, z + 1.2 * k), "glow"),
        B((f + 5.5 * k, f + 12.5 * k), (l - 2.7 * k, l - 2.0 * k), (z - 1.2 * k, z + 1.2 * k), "glow"),
        B((f + 0.5 * k, f + 4.5 * k), (l - 3.3 * k, l + 3.3 * k), (z - 3.8 * k, z - 3.2 * k), "glow"),
        L((l, z), [(2.5 * k, f + 13.4 * k), (2.5 * k, f + 14.2 * k)], "glow", axis="f",
          caps=False, segments=14),
    ]


def boomerang(h, k=1.0, out=1):
    """Klingenbumerang wurfbereit: Griff durch die Faust, Knauf unten, oben die
    Ecke des V, ein Schenkel steil nach oben, einer schraeg nach aussen."""
    f, l, z = h
    o = out
    return [
        B((f - 0.9, f + 0.9), (l - 0.9, l + 0.9), (z - 5 * k, z + 4 * k), "metal"),        # Griff
        B((f - 1.5, f + 1.5), (l - 1.5, l + 1.5), (z - 6.6 * k, z - 5 * k), "dark"),       # Knauf
        B((f - 2.2, f + 2.2), (l - 2.2, l + 2.2), (z + 4 * k, z + 7 * k), "plate"),        # Ecke
        B((f - 2.3, f + 2.3), (l - 2.3, l + 2.3), (z + 5 * k, z + 5.8 * k), "accent"),
        # Schenkel nach oben
        B((f - 0.6, f + 0.6), (l - 1.3, l + 1.3), (z + 7 * k, z + 19 * k), "glow"),
        B((f + 0.6, f + 1.0), (l - 1.3, l + 1.3), (z + 7 * k, z + 18 * k), "accent"),
        B((f - 0.9, f + 0.9), (l - 1.8, l + 1.8), (z + 19 * k, z + 21 * k), "plate"),      # Spitze
        # Schenkel nach aussen (in Stufen, liest sich als Schraege)
        B((f - 0.6, f + 0.6), sorted((l + o * 2.2 * k, l + o * 6.5 * k)), (z + 5.5 * k, z + 8.5 * k), "glow"),
        B((f - 0.6, f + 0.6), sorted((l + o * 6.5 * k, l + o * 10.5 * k)), (z + 8 * k, z + 11 * k), "glow"),
        B((f + 0.6, f + 1.0), sorted((l + o * 2.2 * k, l + o * 10.5 * k)), (z + 7.6 * k, z + 8.4 * k), "accent"),
        B((f - 0.9, f + 0.9), sorted((l + o * 10.5 * k, l + o * 12.5 * k)), (z + 9.5 * k, z + 12 * k), "plate"),
    ]


def ram(h, k=1.0):
    """Bollwerk-Ramme an der Faust: Griffbuegel durch die Faust, davor ein
    dicker Kolben mit Hydraulik und eine breite Rammplatte -- stoesst nach vorn."""
    f, l, z = h
    return [
        B((f - 0.9, f + 0.9), (l - 0.9, l + 0.9), (z - 5 * k, z + 5 * k), "metal"),        # Griff
        B((f - 1.5, f + 2.6 * k), (l - 1.5, l + 1.5), (z - 6.4 * k, z - 5 * k), "dark"),   # Buegel unten
        B((f - 1.5, f + 2.6 * k), (l - 1.5, l + 1.5), (z + 5 * k, z + 6.4 * k), "dark"),   # Buegel oben
        B((f + 2.6 * k, f + 11 * k), (l - 2.4 * k, l + 2.4 * k), (z - 2.6 * k, z + 2.6 * k), "metal"),  # Kolben
        B((f + 2.6 * k, f + 9 * k), (l - 1.0 * k, l + 1.0 * k), (z + 2.6 * k, z + 4.4 * k), "dark"),    # Hydraulik
        B((f + 2.6 * k, f + 9 * k), (l - 1.0 * k, l + 1.0 * k), (z - 4.4 * k, z - 2.6 * k), "dark"),
        B((f + 4 * k, f + 5 * k), (l - 3.2 * k, l + 3.2 * k), (z - 3.4 * k, z + 3.4 * k), "light"),    # Manschette
        B((f + 11 * k, f + 14 * k), (l - 6 * k, l + 6 * k), (z - 7 * k, z + 7 * k), "plate"),          # Rammkopf
        B((f + 11 * k, f + 14 * k), (l - 6.3 * k, l + 6.3 * k), (z - 0.6 * k, z + 0.6 * k), "accent"),
        B((f + 14 * k, f + 14.7 * k), (l - 5 * k, l + 5 * k), (z - 6 * k, z + 6 * k), "dark"),         # Stirn
        B((f + 14.7 * k, f + 15.4 * k), (l - 1.6 * k, l + 1.6 * k), (z - 1.6 * k, z + 1.6 * k), "glow"),
    ]


def wrench(h, k=1.0):
    """E-Schraubenschluessel senkrecht: Griff mit Wicklung durch die Faust,
    oben der Kopf mit offenem Maul nach oben, Kern dazwischen."""
    f, l, z = h
    return [
        B((f - 1.2, f + 1.2), (l - 1.2, l + 1.2), (z - 9 * k, z + 14 * k), "plate"),       # Griff
        B((f - 1.7, f + 1.7), (l - 1.7, l + 1.7), (z - 11 * k, z - 9 * k), "dark"),        # Endkappe
        B((f - 1.6, f + 1.6), (l - 1.6, l + 1.6), (z - 8 * k, z - 6.8 * k), "accent"),     # Wicklung
        B((f - 1.6, f + 1.6), (l - 1.6, l + 1.6), (z + 3.2 * k, z + 4.4 * k), "accent"),
        B((f - 1.6, f + 1.6), (l - 1.6, l + 1.6), (z + 6.0 * k, z + 7.2 * k), "accent"),
        B((f - 2.2, f + 2.2), (l - 4.6 * k, l + 4.6 * k), (z + 14 * k, z + 18 * k), "metal"),  # Kopf
        B((f - 2.4, f + 2.4), (l - 4.9 * k, l + 4.9 * k), (z + 15.4 * k, z + 16.6 * k), "accent"),
        B((f - 2.0, f + 2.0), (l - 4.6 * k, l - 2.0 * k), (z + 18 * k, z + 24 * k), "metal"),  # Backen
        B((f - 2.0, f + 2.0), (l + 2.0 * k, l + 4.6 * k), (z + 18 * k, z + 24 * k), "metal"),
        B((f - 1.3, f + 1.3), (l - 1.3, l + 1.3), (z + 18 * k, z + 21 * k), "glow"),           # Kern
        D(f + 2.2, l - 3.3 * k, z + 23 * k, 0.9 * k, "glow"),
        D(f + 2.2, l + 3.3 * k, z + 23 * k, 0.9 * k, "glow"),
    ]


# ------------------------------------------------------------ Lafette (Strix)
LA = (0, 10.5, 61)          # Anker der Lafette auf der linken Schulter


def lafette_blaster(neon=False):
    """Fernwaffe ohne Arm: liegt laengs auf der Schulter, Wiege statt Hand."""
    f, l, z = LA
    s = [
        B((f - 6, f + 4), (l - 2, l + 2), (z, z + 2.5), "plate"),                  # Wiege
        B((f - 4, f + 5), (l - 3, l + 3), (z + 2.5, z + 8), "plate"),              # Gehaeuse
        B((f + 5, f + 15), (l - 2, l + 2), (z + 3, z + 7.4), "plate"),             # Lauf
        B((f + 5, f + 15), (l - 2.2, l + 2.2), (z + 7.4, z + 8.1), "light"),
        B((f + 15, f + 17), (l - 1.8, l + 1.8), (z + 3.2, z + 7.2), "dark"),
        D(f + 17.1, l, z + 5.2, 1.4, "glow"),
        B((f - 3, f + 4), (l + 3, l + 3.5), (z + 4, z + 6), "accent"),
    ]
    if neon:
        s += [
            B((f + 5.5, f + 14.5), (l + 2.0, l + 2.7), (z + 4.2, z + 6.2), "glow"),
            B((f + 5.5, f + 14.5), (l - 2.7, l - 2.0), (z + 4.2, z + 6.2), "glow"),
            L((l, z + 5.2), [(2.5, f + 15.4), (2.5, f + 16.2)], "glow", axis="f", caps=False, segments=14),
        ]
    return s


S_MORTAR = n.shift(g.EQ_MORTAR, dl=10.5)
S_LANCE = n.shift(g.EQ_RAIL_LANCE, dl=10.5)

# ------------------------------------------------------------ Eule (Spiel-Stand)
_HEAD_NO_LENS = [s for s in g.STRIX_HEAD
                 if not (s[0] == "disc" or (s[0] == "box" and s[1] == (13, 13.6)))]
LENS_BIG = [
    B((13, 13.6), (-7.0, 7.0), (50.5, 59.5), "dark"),     # Gesichtsplatte breiter
    D(13.7, 3.5, 55.5, 3.4, "dark"), D(13.8, 3.5, 55.5, 2.4, "visor"),
    D(13.9, 3.5, 55.5, 0.9, "glow"),
    D(13.7, -3.5, 55.5, 3.4, "dark"), D(13.8, -3.5, 55.5, 2.4, "visor"),
    D(13.9, -3.5, 55.5, 0.9, "glow"),
    B((13.6, 14.6), (-0.8, 0.8), (50.5, 53), "metal"),    # Schnabel tiefer
]
STRIX_OLD = g.STRIX_FEET + g.STRIX_BODY + g.STRIX_HEAD + g.STRIX_CORE
STRIX = g.STRIX_FEET + g.STRIX_BODY + _HEAD_NO_LENS + LENS_BIG + g.STRIX_CORE


# ------------------------------------------------------------ Entwuerfe
def arm(pose, head, l, zs, k=1.0, **kw):
    return v4.armed(pose, head, l, zs, k, **kw)


VA, NA = v4.V_ARM, v4.N_ARM
MR, ML, MZ, MK = v4.M_R, v4.M_L, v4.M_ZS, v4.M_K

DESIGNS = {
    # Vireo (Waffenarm +l)
    "v6_vireo_neon": ("vireo", v4.VIREO + arm("ext", neon_blaster, **VA)),
    "v6_vireo_bumerang": ("vireo", v4.VIREO + arm("up", boomerang, **VA, out=1)),
    "v6_vireo_ramme": ("vireo", v4.VIREO + arm("up", ram, **VA)),
    "v6_vireo_schluessel": ("vireo", v4.VIREO + arm("up", wrench, **VA)),
    "v6_vireo_deflektor": ("vireo", v4.VIREO + arm("up", v4.shield, **VA, toward=-1)),
    # Nimbus (Waffenarm +l)
    "v6_nimbus_neon": ("nimbus", v4.NIMBUS + arm("ext", neon_blaster, **NA)),
    "v6_nimbus_bumerang": ("nimbus", v4.NIMBUS + arm("up", boomerang, **NA, out=1)),
    "v6_nimbus_ramme": ("nimbus", v4.NIMBUS + arm("up", ram, **NA)),
    "v6_nimbus_schluessel": ("nimbus", v4.NIMBUS + arm("up", wrench, **NA)),
    "v6_nimbus_deflektor": ("nimbus", v4.NIMBUS + arm("up", v4.shield, **NA, toward=-1)),
    # Molok: zwei Anker, Armmass 1,6
    "v6_molok_ramme_schluessel": ("molok", v4.MOLOK + arm("up", ram, MR, MZ, MK)
                                  + arm("up", wrench, ML, MZ, MK)),
    "v6_molok_neon_bumerang": ("molok", v4.MOLOK + arm("ext", neon_blaster, MR, MZ, MK)
                               + arm("up", boomerang, ML, MZ, MK, out=-1)),
    # Strix: Fernwaffen auf der Lafette, Eule mit grossen Linsen
    "v6_strix_puls": ("strix", STRIX + lafette_blaster()),
    "v6_strix_neon": ("strix", STRIX + lafette_blaster(neon=True)),
    "v6_strix_moerser": ("strix", STRIX + S_MORTAR),
    "v6_strix_lanze": ("strix", STRIX + S_LANCE),
    "v6_strix_linsen_alt": ("strix", STRIX_OLD + S_MORTAR),
}
if __name__ == "__main__":
    for name, (pal, shapes) in DESIGNS.items():
        for facing in ("south", "east"):
            n.write(name, shapes, n.PAL[pal], facing)
    print("ok")
