"""Runde 7 (Schritt 4b): Arme gehoeren zum Chassis, die Waffe ist nur das
Geraet in der Hand. Zwei Haltungen je Chassis: halten (Klinge, Hammer, Stab,
Schluessel, Bumerang, Schild) und zielen (Blaster, Lanze, Ramme).
Dazu: Faust / Manschette / Hand im Vergleich und Lafetten-Koepfe am Strix
(nur Kugel bzw. Schluesselkopf, ohne Griff)."""
import sys
import new_dromes as n
import v4
import v6
g, B, D, L = n.g, n.B, n.D, n.L


# ------------------------------------------------------------ Handenden
def fist(hf, hl, hz, k=1.0):
    """Faust-Block: umschliesst den Griff, zwei helle Fugen = Knoechel."""
    return [
        B((hf - 2.2 * k, hf + 2.2 * k), (hl - 2.6 * k, hl + 2.6 * k), (hz - 2.6 * k, hz + 2.6 * k), "dark"),
        B((hf + 2.2 * k, hf + 2.6 * k), (hl - 2.2 * k, hl + 2.2 * k), (hz - 1.6 * k, hz - 0.6 * k), "light"),
        B((hf + 2.2 * k, hf + 2.6 * k), (hl - 2.2 * k, hl + 2.2 * k), (hz + 0.6 * k, hz + 1.6 * k), "light"),
    ]


def hand(hf, hl, hz, k=1.0, sd=1):
    """Hand mit Fingern um den Griff: Handruecken, Daumen oben, drei Finger
    vorn als einzelne Glieder."""
    s = [B((hf - 2.4 * k, hf + 0.6 * k), (hl - 2.4 * k, hl + 2.4 * k), (hz - 2.8 * k, hz + 2.8 * k), "dark")]
    for i, z0 in enumerate((-2.6, -0.8, 1.0)):
        s.append(B((hf + 0.6 * k, hf + 2.8 * k), (hl - 2.2 * k, hl + 2.2 * k),
                   (hz + z0 * k, hz + (z0 + 1.5) * k), "light" if i % 2 else "plate"))
    s.append(B((hf - 1.0 * k, hf + 2.2 * k), (hl - sd * 3.4 * k, hl - sd * 2.2 * k),
               (hz + 1.8 * k, hz + 3.4 * k), "plate"))           # Daumen
    return s


def cuff(hf, hl, hz, k=1.0):
    """Manschette: Arm endet in einem Ring, die Waffe sitzt direkt dran."""
    return [L((hl, hz), [(2.9 * k, hf - 1.0 * k), (2.9 * k, hf + 0.6 * k)], "accent",
              axis="f", caps=True, segments=12)]


ENDS = {"faust": fist, "hand": hand, "manschette": cuff}


# ------------------------------------------------------------ Haltungen
def pose_hold(l, zs, k=1.0, end="faust"):
    """halten: Oberarm haengt, Unterarm nach vorn, Waffe steht senkrecht."""
    t = 2.0 * k
    sd = 1 if l > 0 else -1
    hf, hl, hz = 12.75 * k, l + sd * 1.0 * k, zs - 12.5 * k
    shapes = [
        B((-2.5 * k, 2.5 * k), (l - t, l + t), (zs - 11 * k, zs - 1), "metal"),
        B((-2.5 * k, 10.5 * k), (l - t - 0.3, l + t + 0.3), (zs - 16 * k, zs - 9 * k), "plate"),
        B((4 * k, 9 * k), (l + t + 0.3, l + t + 0.8), (zs - 13.5 * k, zs - 12 * k), "accent"),
    ]
    kw = {"sd": sd} if end == "hand" else {}
    return shapes + ENDS[end](hf, hl, hz, k, **kw), (hf, hl, hz)


def pose_aim_straight(l, zs, k=1.0, end="faust"):
    """zielen (Vireo, Nimbus): ganzer Arm gestreckt nach vorn, auf Schulterhoehe."""
    t = 2.1 * k
    sd = 1 if l > 0 else -1
    zc = zs - 4.5 * k
    hf, hl, hz = 19.5 * k, l, zc
    shapes = [
        B((-2.5 * k, 2.5 * k), (l - t, l + t), (zs - 7 * k, zs - 1), "metal"),     # Schultergelenk
        B((1 * k, 9 * k), (l - t, l + t), (zc - 2.0 * k, zc + 2.0 * k), "metal"),   # Oberarm
        B((8 * k, 17.2 * k), (l - t - 0.3, l + t + 0.3), (zc - 2.6 * k, zc + 2.6 * k), "plate"),
        B((11 * k, 16 * k), (l + sd * (t + 0.3), l + sd * (t + 0.8)), (zc - 0.8 * k, zc + 0.8 * k), "accent"),
    ]
    if end == "manschette":
        return shapes + cuff(17.6 * k, hl, hz, k), (17.6 * k, hl, hz)
    kw = {"sd": sd} if end == "hand" else {}
    return shapes + ENDS[end](hf, hl, hz, k, **kw), (hf, hl, hz)


def pose_aim_hip(l, zs, k=1.0, end="faust"):
    """zielen (Molok): aus der Huefte -- dieselbe Armhaltung wie halten,
    die Waffe liegt waagerecht nach vorn."""
    return pose_hold(l, zs, k, end)


# ------------------------------------------------------------ Waffen mit Griff
def gun_held(h, k=1.0, neon=False):
    """Blaster mit Pistolengriff: Griff durch die Faust, Lauf darueber."""
    f, l, z = h
    head = v6.neon_blaster if neon else v4.blaster
    return [
        B((f - 1.0 * k, f + 1.0 * k), (l - 1.0 * k, l + 1.0 * k), (z - 3.6 * k, z + 3.0 * k), "metal"),
        B((f - 1.4 * k, f + 1.4 * k), (l - 1.4 * k, l + 1.4 * k), (z - 4.6 * k, z - 3.6 * k), "dark"),
    ] + head((f - 2.5 * k, l, z + 6.2 * k), k)


def gun_mounted(h, k=1.0, neon=False):
    """Blaster direkt an der Manschette (heute: Waffe statt Hand)."""
    f, l, z = h
    head = v6.neon_blaster if neon else v4.blaster
    return head((f + 0.6 * k, l, z), k)


# ------------------------------------------------------------ Strix: Lafetten-Koepfe
LA = v6.LA


def lafette_rune():
    """Runenstab auf der Lafette: nur die Kugel mit Fassung auf kurzem Sockel."""
    f, l, z = LA
    base = z + 2
    return [
        B((f - 3, f + 3), (l - 2.6, l + 2.6), (z, z + 2), "plate"),
        L((f, l), [(1.6, base), (1.6, base + 3)], "metal", segments=10),
    ] + v4.staff((f, l, base + 3 - 18.6))[5:]


def lafette_wrench():
    """E-Schluessel auf der Lafette: nur der Kopf mit Maul nach oben."""
    f, l, z = LA
    base = z + 2
    return [
        B((f - 3, f + 3), (l - 2.6, l + 2.6), (z, z + 2), "plate"),
        B((f - 1.2, f + 1.2), (l - 1.2, l + 1.2), (base, base + 3), "plate"),
    ] + v6.wrench((f, l, base + 3 - 14))[5:]


# ------------------------------------------------------------ Entwuerfe
VA, NA = v4.V_ARM, v4.N_ARM
MR, ML, MZ, MK = v4.M_R, v4.M_L, v4.M_ZS, v4.M_K


def vireo(pose, weapon, end="faust", **kw):
    arm, h = pose(VA["l"], VA["zs"], 1.0, end)
    return v4.VIREO + arm + weapon(h, 1.0, **kw)


V_PASSIVE_HAND = [s for s in v4.V_PASSIVE_ARM if s[4] != "dark"] + \
    hand(0.3, -13.5, 31.5, 1.0, sd=-1)

ALL = list(g.DIRECTIONS)
DESIGNS = {
    # Vireo: beide Haltungen aus allen vier Richtungen
    "v7_vireo_halten": ("vireo", vireo(pose_hold, v4.blade), ALL),
    "v7_vireo_zielen": ("vireo", vireo(pose_aim_straight, gun_held, neon=True), ALL),
    "v7_vireo_schild": ("vireo", vireo(pose_hold, v4.shield, toward=-1), ["south", "east", "north"]),
    # Handenden im Vergleich (zielen)
    "v7_ende_manschette": ("vireo", vireo(pose_aim_straight, gun_mounted, end="manschette"), ["south", "east"]),
    "v7_ende_faust": ("vireo", vireo(pose_aim_straight, gun_held), ["south", "east"]),
    "v7_ende_hand": ("vireo", vireo(pose_aim_straight, gun_held, end="hand"), ["south", "east"]),
    # Passiv-Arm mit Hand (traegt nie etwas)
    "v7_vireo_passivhand": ("vireo", [s for s in v4.VIREO if s not in v4.V_PASSIVE_ARM]
                            + V_PASSIVE_HAND + pose_hold(VA["l"], VA["zs"])[0] + v4.blade(pose_hold(VA["l"], VA["zs"])[1]),
                            ["south", "west"]),
    # Molok: rechts Hammer halten, links Blaster aus der Huefte
    "v7_molok_huefte": ("molok", v4.MOLOK
                        + (lambda a: a[0] + v4.hammer(a[1], MK))(pose_hold(MR, MZ, MK))
                        + (lambda a: a[0] + gun_held(a[1], MK))(pose_aim_hip(ML, MZ, MK)),
                        ["south", "east"]),
    # Strix: Lafette ohne Griff
    "v7_strix_rune": ("strix", v6.STRIX + lafette_rune(), ["south", "east"]),
    "v7_strix_schluessel": ("strix", v6.STRIX + lafette_wrench(), ["south", "east"]),
}

if __name__ == "__main__":
    for name, (pal, shapes, dirs) in DESIGNS.items():
        for facing in dirs:
            n.write(name, shapes, n.PAL[pal], facing)
    print("ok")
