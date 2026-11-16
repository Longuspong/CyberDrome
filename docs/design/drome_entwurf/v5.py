"""Runde 5: Ebenen je DROME fuer die Bewegungs-Entwuerfe (Schraeg/Ost)."""
import json, re, sys, pathlib
import new_dromes as n
import v4
import v2
g, B, D, L = n.g, n.B, n.D, n.L
OUT = pathlib.Path(sys.argv[1]); OUT.mkdir(parents=True, exist_ok=True)
FACING = "east"
VB = "-14 -14 156 156"


def zr(s):
    if s[0] == "box":
        return s[3]
    if s[0] == "disc":
        return (s[3] - s[4], s[3] + s[4])
    c, prof, axis = s[1], s[2], s[4]
    if axis == "z":
        return (min(p for _, p in prof), max(p for _, p in prof))
    r = max(r for r, _ in prof)
    return (c[1] - r, c[1] + r)


def lc(s):
    if s[0] == "box":
        return sum(s[2]) / 2
    if s[0] == "disc":
        return s[2]
    c, axis = s[1], s[4]
    return c[1] if axis == "z" else (c[0] if axis == "f" else sum(p for _, p in s[2]) / len(s[2]))


def svg(shapes, pal, rim_only=False):
    body = n.paint(g.render(shapes, FACING), pal)
    inner = n.rim(body, pal["accent"]) if rim_only else body
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{VB}" width="624" height="624">{inner}</svg>'


def pct(point):
    x, y = g.project(point, FACING)
    return round((x + 14) / 156 * 100, 1), round((y + 14) / 156 * 100, 1)


def minus(a, b):
    ids = {id(x) for x in b}
    return [s for s in a if id(s) not in ids]


DROMES = {}

# ---- Vireo mit Klinge
w = v4.armed("up", v4.blade, **v4.V_ARM)
nl = len(n.V_LEG)
legA, legB = v4.VB[:nl], v4.VB[nl:2 * nl]
rest = v4.VB[2 * nl:] + v4.V_PASSIVE_ARM + v4.V_BOOSTER
head = [s for s in rest if zr(s)[0] >= 62 and abs(lc(s)) < 8]
fx = [s for s in minus(rest, head) if s[0] != "box" or s[4] != "glow"]
fx = [s for s in minus(rest, head) if s[-1] == "glow" or (s[0] in ("disc",) and s[5] == "glow") or (s[0] == "lathe" and s[3] == "glow")]
body = minus(minus(rest, head), fx)
DROMES["vireo"] = dict(pal="vireo", layers=dict(weapon=w, legA=legA, legB=legB, body=body, fx=fx, head=head),
                       pivot=pct((0, 14.5, 54)), ground=pct((0, 0, 0)), all=v4.VIREO + w)

# ---- Molok mit Hammer + Schild
wR = v4.armed("up", v4.hammer, v4.M_R, v4.M_ZS, v4.M_K)
wL = v4.armed("up", v4.shield, v4.M_L, v4.M_ZS, 1.25, toward=1)
feet = n.M_FEET
legA = [s for s in feet if lc(s) > 0]
legB = [s for s in feet if lc(s) <= 0]
mrest = v4.MREST
head = [s for s in mrest if s[0] == "box" and zr(s)[0] >= 60 and abs(lc(s)) <= 8]
body = minus(mrest, head)
DROMES["molok"] = dict(pal="molok", layers=dict(weapon=wR, legA=legA, legB=legB, body=body, fx=[], head=head, weaponL=wL),
                       pivot=pct((0, 19, 57)), pivotL=pct((0, -19, 57)), ground=pct((0, 0, 0)))
DROMES["molok"]["layers"]["fx"] = v2.M_BEACON
DROMES["molok"]["all"] = v4.MOLOK + wR + wL

# ---- Nimbus mit Stab
w = v4.armed("up", v4.staff, **v4.N_ARM)
orb = v4.N_ORB_ARM[3:]
DROMES["nimbus"] = dict(pal="nimbus", layers=dict(weapon=w, drive=g.MAGE_DRIVE, body=v4.NB + g.MAGE_CORE + v4.N_ORB_ARM[:3],
                        head=g.MAGE_HEAD, halo=v4.N_HALO, orb=orb),
                        pivot=pct((0, 13.8, 50)), ground=pct((0, 0, 0)), all=v4.NIMBUS + w)

# ---- Strix (Eule) mit Lanze
nl = len(n.SA_LEG)
core = v2.SA_CORE
legA, legB = core[:nl], core[nl:2 * nl]
rest = core[2 * nl:] + v2.SA_SOCKET[:1]
eyes = [s for s in rest if s[0] == "disc" and s[5] == "visor"]
head = [s for s in rest if zr(s)[0] >= 49 and s[0] == "box" and s[1][0] >= 2 and abs(lc(s)) < 8]
body = minus(minus(rest, head), eyes)
DROMES["strix"] = dict(pal="strix", layers=dict(weapon=v2.SA_LANCE, legA=legA, legB=legB, body=body, head=head, eyes=eyes),
                       muzzle=pct((30.2, 10.5, 60.5)), ground=pct((0, 0, 0)), all=v2.SA_CORE + v2.SA_SOCKET[:1] + v2.SA_LANCE)

meta = {}
for name, d in DROMES.items():
    pal = n.PAL[d["pal"]]
    (OUT / f"a_{name}_rim.svg").write_text(svg(d["all"], pal, rim_only=True))
    for lay, shapes in d["layers"].items():
        if shapes:
            (OUT / f"a_{name}_{lay}.svg").write_text(svg(shapes, pal))
            (OUT / f"a_{name}_{lay}_rim.svg").write_text(svg(shapes, pal, rim_only=True))
    meta[name] = {k: v for k, v in d.items() if k not in ("layers", "all", "pal")}
    meta[name]["order"] = [k for k, v in d["layers"].items() if v]
# Muendungsblitz
(OUT / "a_flash.svg").write_text('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40" width="160" height="160">'
    '<circle cx="20" cy="20" r="9" fill="#b0ffd4"/><path d="M20 2L23 17L38 20L23 23L20 38L17 23L2 20L17 17Z" fill="#6dff9f"/>'
    '<circle cx="20" cy="20" r="4" fill="#ffffff"/></svg>')
print(json.dumps(meta))
