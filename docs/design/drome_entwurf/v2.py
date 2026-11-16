"""Runde 3: ein Anker (Molok zwei), freier Arm zeigt die Passive."""
import sys
import new_dromes as n
g, B, D, L = n.g, n.B, n.D, n.L

# ---------------- Vireo: +l Arm endet im Anker, -l Arm = Sprint-Duese
V_CORE = [s for s in n.V_BODY if not (s[0] == "box" and s[2][0] >= 11 and s[3][1] <= 45.5)
          and not (s[0] == "box" and s[2][1] <= -11.5 and s[3][1] <= 45.5)
          and not (s[0] == "disc" and abs(s[2] - 14.5) < 0.1)]
V_ANCHOR_ARM = [
    B((-3.5, 4), (12, 17), (34, 45), "plate"),           # Unterarm
    B((4, 4.5), (13, 16), (39, 41), "accent"),
    B((-3, 3.5), (12.5, 16.5), (30, 34), "metal"),       # Anker-Fassung
    D(3.6, 14.5, 32, 1.7, "glow"),
]
V_SPRINT_ARM = [                                         # Passive Sprint
    L((0, -14.5), [(2.4, 27.5), (3.4, 31), (3.6, 40), (3.0, 45)], "plate", segments=14),
    L((0, -14.5), [(3.7, 41.5), (3.7, 42.7)], "accent", caps=False, segments=14),
    L((0, -14.5), [(2.2, 25.5), (2.2, 27.5)], "glow", segments=12),
    B((-7.5, -3), (-15.2, -13.8), (30, 41), "light"),     # Finne nach hinten
    B((-7.6, -6.8), (-15.3, -13.7), (31, 37), "accent"),
]
V_BLASTER = [
    B((-4, 6), (11.5, 17.5), (27, 34.5), "plate"),
    B((6, 13), (12.5, 16.5), (28.5, 33.5), "plate"),
    B((13, 15), (13, 16), (29, 33), "dark"),
    D(15.1, 14.5, 31, 1.5, "glow"),
    B((-3, 5), (17.5, 18), (30, 32), "accent"),
]
V_BLADE = [
    B((-2.5, 4.5), (12, 17), (28, 34), "dark"),
    B((4.5, 6), (11, 18), (28.5, 33.5), "metal"),
    B((6, 27), (13.9, 15.1), (29.5, 32.5), "glow"),
    B((6, 27.5), (13.7, 15.3), (32.5, 33.3), "accent"),
]
VIREO = V_CORE + V_ANCHOR_ARM + V_SPRINT_ARM

# ---------------- Nimbus: +l Hand = Anker (Stab), -l Hand = Echo-Orb
MB = [s for s in g.MAGE_BODY if not (s[0] == "lathe" and s[3] == "glow")]
N_ARM = n.shift(g.EQ_RUNE_STAFF[:3], dl=13.8)            # Arm + Faust am Anker
N_SOCKET = [D(5.2, 13.8, 30.3, 1.5, "glow")]
N_STAFF = n.shift(g.EQ_RUNE_STAFF[3:], dl=13.8)
N_ORB = [                                                # Passive Echo
    L((5.5, -13.8), [(0, 19.5), (2.4, 20.5), (3.3, 23.0), (2.4, 25.5), (0, 26.5)], "glow", segments=14),
    L((-13.8, 23.0), [(4.6, 4.9), (5.3, 4.9), (5.3, 6.1), (4.6, 6.1), (4.6, 4.9)], "accent", axis="f", segments=20),
    L((1.0, -19.5), [(0, 31.5), (1.5, 32.1), (2.0, 33.5), (1.5, 34.9), (0, 35.5)], "accent", segments=10),
    L((-1.5, -9.0), [(0, 15.5), (1.1, 16.0), (1.5, 17.0), (1.1, 18.0), (0, 18.5)], "accent", segments=10),
]
NIMBUS = g.MAGE_DRIVE + MB + g.MAGE_HEAD + g.MAGE_CORE + N_ARM + N_ORB

# ---------------- Molok: zwei Anker + Lockfeuer (Passive Praesenz)
M_BEACON = [
    L((-9.5, 0), [(3.0, 60), (3.0, 64)], "metal", segments=12),
    L((-9.5, 0), [(2.6, 64), (2.6, 68), (1.6, 69.6), (0, 70.2)], "glow", segments=14),
    L((-9.5, 0), [(3.2, 66.2), (3.2, 66.9)], "accent", caps=False, segments=14),
]
MOLOK = n.M_BODY + M_BEACON

# ---------------- Strix: Anker statt fester Lanze
SA = n.SA_BODY
cut = SA.index(next(s for s in SA if s[0] == "box" and s[1] == (-16, 26)))
SA_CORE, SA_LANCE = SA[:cut], SA[cut:]
SA_SOCKET = [B((-6, 4), (8.5, 12.5), (58, 61), "metal"), D(4.1, 10.5, 59.5, 1.6, "glow")]
SB = n.SB_BODY
cut = SB.index(next(s for s in SB if s[0] == "box" and s[1] == (-4, 30)))
SB_CORE, SB_GUN = SB[:cut], SB[cut:]
SB_SOCKET = [B((-3, 3), (-2.4, 2.4), (46, 49), "metal"), D(3.1, 0, 47.5, 1.4, "glow")]

ALL = {
    "v3_vireo_blaster": (VIREO + V_BLASTER, "vireo", True),
    "v3_vireo_klinge": (VIREO + V_BLADE, "vireo", False),
    "v3_vireo_leer": (VIREO, "vireo", False),
    "v3_nimbus_stab": (NIMBUS + N_STAFF, "nimbus", True),
    "v3_nimbus_leer": (NIMBUS + N_SOCKET, "nimbus", False),
    "v3_molok": (MOLOK + n.M_HAMMER + n.M_SHIELD, "molok", True),
    "v3_molok_leer": (MOLOK, "molok", False),
    "v3_strixa_leer": (SA_CORE + SA_SOCKET, "strix", False),
    "v3_strixb_leer": (SB_CORE + SB_SOCKET, "strix", False),
}
for name, (shapes, pal, alldirs) in ALL.items():
    for f in (g.DIRECTIONS if alldirs else ["south"]):
        n.write(name, shapes, n.PAL[pal], f)
print("ok")
