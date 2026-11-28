"""Grundformen der Fabrikstadt (Projektion, Prismen, Felder, Quellen, Schilder) -- von fabrikstadt.py genutzt.
Die Gebaeude-Funktion hier ist der Stand vor den Linien (v3); gueltig ist building() in fabrikstadt.py."""
import math, random, os

K = math.sqrt(3)
U, F, V = 34.0, 0.72, 0.75
CX, CY = 209.0, 205.0
NIGHT = '#0a0618'

GROUPCOL = {'foerderer': '#2ee3eb', 'verarbeitung': '#ff6a3d', 'strom': '#6dffa8', 'logistik': '#9d84ff', 'basis': '#fff7fe'}
DEF = {  # typ: (gruppe, tier, name)
    'sam': ('foerderer', 1, 'Sammler'), 'zap': ('foerderer', 1, 'Zapfer'), 'scn': ('foerderer', 1, 'Scanner'),
    'pmp': ('foerderer', 2, 'Neonpumpe'), 't3f': ('foerderer', 3, 'Tiefbohrer'),
    'smz': ('verarbeitung', 1, 'Schmelze'), 'pls': ('verarbeitung', 1, 'Plasmakammer'), 'lot': ('verarbeitung', 1, 'Löter'),
    'rec': ('verarbeitung', 1, 'Recycler'), 'vdi': ('verarbeitung', 2, 'Verdichter'), 'chp': ('verarbeitung', 2, 'Chipfabrik'),
    't3v': ('verarbeitung', 3, 'Fertigungshalle'),
    'sol': ('strom', 1, 'Solarpanel'), 'ofn': ('strom', 1, 'Schlackeofen'), 'gen': ('strom', 2, 'Generator'),
    'bat': ('strom', 2, 'Batterie'), 't3s': ('strom', 3, 'Fusionsring'),
    'rel': ('logistik', 1, 'Relais'), 't3l': ('logistik', 3, 'Transmitter'),
    'basis': ('basis', 1, 'Basis'),
}
WARE = {'schrott': '#c9b49c', 'neon': '#2ee3eb', 'daten': '#9d84ff', 'legierung': '#ff6a3d', 'plasma': '#ff2bd6',
        'schaltkreis': '#6dffa8', 'schlacke': '#86739a', 'platte': '#ffb347'}

# Paletten (oben, vorn)
DARK = ('#30244f', '#1d1538')
RUST = ('#8a7462', '#5e4c40')
TIERPAL = {1: ('#5d4c8e', '#3a2c66'), 2: ('#7d70b4', '#51458a'), 3: ('#a197d6', '#6c61a8')}
TRIM = {1: ('#46386e', '#2c2150'), 2: ('#9a8fcc', '#665b9c'), 3: ('#c9c1ee', '#8f86c4')}
GRAY = {'#': None}

ICON = {
    'jam': 'M3 12h5M16 12h5M7 7l5 5-5 5M17 7l-5 5 5 5',
    'off': 'M13 2L5 14h6l-1 8 8-12h-6zM3 3l18 18',
    'flag': 'M5 21V3M5 4h13l-3.5 4.5L18 13H5',
    'lock': 'M5 11h14v10H5zM8 11V7a4 4 0 0 1 8 0v4',
}


def gray(c):
    c = c.lstrip('#')
    r, g, b = int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16)
    v = int((0.3 * r + 0.59 * g + 0.11 * b) * 0.55 + 30)
    return '#%02x%02x%02x' % (v, v, min(255, v + 12))


def P(x, y, z):
    return (CX + x * U, CY + z * U * F - y * U * V)


def pts(seq):
    return ' '.join(f'{a:.1f},{b:.1f}' for a, b in seq)


def hexc(r, rot=0):
    return [(r * math.cos(math.radians(60 * i + rot)), r * math.sin(math.radians(60 * i + rot))) for i in range(6)]


def circ(r, step=20):
    return [(r * math.cos(math.radians(a)), r * math.sin(math.radians(a))) for a in range(0, 360, step)]


class Svg:
    def __init__(self, mono=False):
        self.under, self.over, self.mono = [], [], mono

    def c(self, col):
        return gray(col) if self.mono and col.startswith('#') and col != NIGHT else col

    def poly(self, p, fill, stroke=NIGHT, sw=1.0, extra=''):
        self.over.append(f'<polygon points="{pts(p)}" fill="{self.c(fill)}" stroke="{self.c(stroke)}" stroke-width="{sw}" stroke-linejoin="round" {extra}/>')

    def contour(self, p, col, sw=3.5):
        self.under.append(f'<polygon points="{pts(p)}" fill="{self.c(col)}" stroke="{self.c(col)}" stroke-width="{sw}" stroke-linejoin="round"/>')

    def raw(self, s):
        self.over.append(s)

    def out(self):
        return self.under + self.over


G = {'ghost': False}


def prism(s, x, z, corners, y0, h, cols, con=None):
    top = [P(x + a, y0 + h, z + b) for a, b in corners]
    bot = [P(x + a, y0, z + b) for a, b in corners]
    n = len(corners)
    cxm = sum(a for a, _ in corners) / n; czm = sum(b for _, b in corners) / n
    faces = []
    for i in range(n):
        a, b = corners[i], corners[(i + 1) % n]
        nx, nz = b[1] - a[1], -(b[0] - a[0])
        if nx * ((a[0] + b[0]) / 2 - cxm) + nz * ((a[1] + b[1]) / 2 - czm) < 0:
            nx, nz = -nx, -nz
        if nz > 0.01:
            faces.append([top[i], top[(i + 1) % n], bot[(i + 1) % n], bot[i]])
    if con:
        for f in faces + [top]:
            s.contour(f, con)
    if G['ghost']:
        for f in faces + [top]:
            s.poly(f, '#1a1430', '#ffe14d', 1.5, 'stroke-dasharray="4 3"')
        return top
    for f in faces:
        s.poly(f, cols[1])
    s.poly(top, cols[0])
    return top


def box(s, x, z, w, d, y0, h, cols, con=None):
    return prism(s, x, z, [(-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2)], y0, h, cols, con)


def hexp(s, x, z, r, y0, h, cols, con=None, rot=0):
    return prism(s, x, z, hexc(r, rot), y0, h, cols, con)


def cyl(s, x, z, r, y0, h, cols, con=None, top_fill=None, inner=0.68):
    c = circ(r)
    prism(s, x, z, c, y0, h, cols, con)
    if top_fill and not G['ghost']:
        s.poly([P(x + inner * a, y0 + h, z + inner * b) for a, b in c], top_fill, NIGHT, 1.0)


def lamp(s, x, z, w, y0, h, col):
    if G['ghost']:
        return
    s.poly([P(x - w / 2, y0 + h, z), P(x + w / 2, y0 + h, z), P(x + w / 2, y0, z), P(x - w / 2, y0, z)], col, NIGHT, 0.8)


def toplamp(s, x, z, w, d, y, col):
    if G['ghost']:
        return
    s.poly([P(x - w / 2, y, z - d / 2), P(x + w / 2, y, z - d / 2), P(x + w / 2, y, z + d / 2), P(x - w / 2, y, z + d / 2)], col, NIGHT, 0.8)


TILE_H = 0.16


def deposit(s, kind, x, z, locked=False, sc=1.0):
    y = TILE_H
    if kind == 'schrott':
        cols = RUST if not locked else ('#4a4050', '#2f2838')
        for dx, dz, w, h in [(-0.22, -0.12, 0.26, 0.14), (0.12, -0.18, 0.22, 0.1), (0.0, 0.08, 0.3, 0.18), (0.26, 0.12, 0.18, 0.12), (-0.25, 0.2, 0.2, 0.08)]:
            box(s, x + dx * sc, z + dz * sc, w * sc, w * 0.8 * sc, y, h * sc, cols)
    elif kind == 'neon':
        col = ('#7ff0f5', '#1f9aa5') if not locked else ('#3a5a6a', '#243a46')
        for dx, dz, r, h in [(0.0, -0.05, 0.16, 0.5), (-0.22, 0.12, 0.12, 0.32), (0.22, 0.14, 0.11, 0.26)]:
            prism(s, x + dx * sc, z + dz * sc, [(0, -r * sc), (r * sc, 0), (0, r * sc), (-r * sc, 0)], y, h * sc, col)
    else:
        cols = DARK if not locked else ('#22193a', '#150f28')
        box(s, x, z, 0.36 * sc, 0.3 * sc, y, 0.4 * sc, cols)
        for i in range(3):
            lamp(s, x, z + 0.15 * sc, 0.22 * sc, y + (0.06 + i * 0.11) * sc, 0.04 * sc, '#9d84ff' if not locked else '#3a2a6a')


def notches(s, x, z, tier, col):
    """1-3 Kerben an der Suedkante des Feldes: Tier ohne Farbe lesbar."""
    zz = z + 0.92 * K / 2
    for i in range(tier):
        dx = (i - (tier - 1) / 2) * 0.24
        s.poly([P(x + dx - 0.09, TILE_H, zz - 0.02), P(x + dx + 0.09, TILE_H, zz - 0.02), P(x + dx + 0.09, 0, zz), P(x + dx - 0.09, 0, zz)], col, NIGHT, 1.0)


def building(s, t, x, z, state='ok', tier=None):
    grp, tier0, _ = DEF[t]
    tier = tier or tier0
    col = GROUPCOL[grp]
    con = col
    on = state != 'off'
    L = lambda c: c if on else '#3a3450'
    B = TIERPAL[tier]
    T = TRIM[tier]
    y = TILE_H
    # Sockel nach Tier
    if tier == 2 and t != 'basis':
        hexp(s, x, z, 0.74, y, 0.1, T, con); y += 0.1
    if tier == 3 and t != 'basis':
        hexp(s, x, z, 0.8, y, 0.08, T, con); y += 0.08
        hexp(s, x, z, 0.66, y, 0.08, T, con); y += 0.08
    rust = tier == 1

    if t == 'basis':
        hexp(s, x, z, 0.74, y, 0.12, DARK, con)
        hexp(s, x, z, 0.52, y + 0.12, 0.3, B, con)
        for dx in (-0.24, 0, 0.24):
            lamp(s, x + dx, z + 0.45, 0.1, y + 0.2, 0.12, '#2ee3eb')
        top = y + 0.42
        if tier >= 2:
            hexp(s, x, z, 0.4, top, 0.26, TIERPAL[2], con)
            lamp(s, x, z + 0.35, 0.3, top + 0.08, 0.08, '#2ee3eb'); top += 0.26
        hexp(s, x, z, 0.3, top, 0.26, TIERPAL[3] if tier == 3 else TIERPAL[2], con); top += 0.26
        hexp(s, x, z, 0.33, top, 0.06, ('#ffe14d', '#b89a1c'), con); top += 0.06
        cyl(s, x, z, 0.05, top, 0.25 if tier < 3 else 0.42, DARK, con)
        top += 0.25 if tier < 3 else 0.42
        cyl(s, x, z, 0.09, top, 0.07, ('#fff7fe', '#c3b3e6'), con)
        return
    if t == 'sam':
        deposit(s, 'schrott', x + 0.15, z + 0.12, sc=0.8)
        box(s, x - 0.38, z - 0.28, 0.38, 0.32, y, 0.3, B, con)
        box(s, x - 0.46, z - 0.13, 0.12, 0.02, y + 0.05, 0.1, RUST)
        lamp(s, x - 0.32, z - 0.12, 0.14, y + 0.14, 0.08, L(col))
        cyl(s, x - 0.38, z - 0.28, 0.06, y + 0.3, 0.42, DARK, con)
        box(s, x - 0.05, z - 0.28, 0.72, 0.1, y + 0.72, 0.07, T, con)
        cyl(s, x + 0.28, z - 0.08, 0.15, y + 0.4, 0.09, DARK, con, top_fill=L(col))
    elif t == 'zap':
        deposit(s, 'neon', x + 0.22, z + 0.12, sc=0.85)
        cyl(s, x - 0.3, z - 0.18, 0.24, y, 0.38, B, con, top_fill=L(col))
        box(s, x - 0.38, z + 0.06, 0.12, 0.02, y + 0.04, 0.1, RUST)
        box(s, x - 0.02, z - 0.12, 0.42, 0.09, y + 0.28, 0.08, DARK, con)
        lamp(s, x - 0.24, z + 0.06, 0.12, y + 0.16, 0.08, L(col))
    elif t == 'scn':
        deposit(s, 'daten', x + 0.28, z + 0.15, sc=0.85)
        cyl(s, x - 0.22, z - 0.15, 0.06, y, 0.38, DARK, con)
        cyl(s, x - 0.22, z - 0.15, 0.32, y + 0.38, 0.06, T, con, top_fill=B[1])
        cyl(s, x - 0.22, z - 0.15, 0.06, y + 0.44, 0.12, DARK, con, top_fill=L(col))
    elif t == 'pmp':
        deposit(s, 'neon', x + 0.26, z + 0.16, sc=0.75)
        box(s, x - 0.18, z - 0.1, 0.62, 0.5, y, 0.26, B, con)
        for dx in (-0.36, -0.06):
            cyl(s, x + dx, z - 0.14, 0.11, y + 0.26, 0.4, T, con, top_fill=L(col))
        lamp(s, x - 0.18, z + 0.15, 0.4, y + 0.08, 0.08, L(col))
        box(s, x + 0.14, z - 0.2, 0.2, 0.08, y + 0.5, 0.06, DARK, con)
    elif t == 'smz':
        box(s, x, z + 0.02, 0.92, 0.62, y, 0.32, B, con)
        box(s, x + 0.32, z + 0.33, 0.18, 0.02, y + 0.05, 0.12, RUST)
        lamp(s, x - 0.12, z + 0.33, 0.44, y + 0.1, 0.1, L(col))
        cyl(s, x - 0.14, z - 0.02, 0.22, y + 0.32, 0.14, DARK, con, top_fill=L('#ffb347'))
        cyl(s, x + 0.3, z - 0.16, 0.09, y + 0.32, 0.46, DARK, con, top_fill='#120a26')
        cyl(s, x + 0.3, z + 0.1, 0.075, y + 0.32, 0.3, DARK, con, top_fill='#120a26')
    elif t == 'pls':
        hexp(s, x, z, 0.52, y, 0.1, DARK, con)
        cyl(s, x, z, 0.34, y + 0.1, 0.28, B, con, top_fill=L('#ff2bd6'))
        for dx in (-0.42, 0.42):
            box(s, x + dx, z + 0.05, 0.08, 0.08, y + 0.1, 0.4, T, con)
        lamp(s, x, z + 0.34, 0.2, y + 0.18, 0.06, L(col))
    elif t == 'lot':
        box(s, x, z, 0.82, 0.66, y, 0.16, B, con)
        for i in range(3):
            toplamp(s, x + 0.02, z - 0.18 + i * 0.16, 0.5, 0.04, y + 0.16, L('#6dffa8'))
        box(s, x - 0.3, z - 0.22, 0.12, 0.12, y + 0.16, 0.34, DARK, con)
        box(s, x - 0.06, z - 0.22, 0.5, 0.08, y + 0.5, 0.06, T, con)
        cyl(s, x + 0.18, z - 0.22, 0.05, y + 0.3, 0.2, DARK, con, top_fill=L(col))
    elif t == 'rec':
        box(s, x, z - 0.04, 0.86, 0.58, y, 0.14, DARK, con)
        cyl(s, x - 0.2, z - 0.1, 0.22, y + 0.14, 0.32, B, con, top_fill=L(col))
        cyl(s, x + 0.22, z - 0.12, 0.16, y + 0.14, 0.24, B, con, top_fill='#120a26')
        for dx, dy in [(-0.2, 0), (0, 0), (0.2, 0), (-0.1, 0.12), (0.1, 0.12)]:
            box(s, x + dx, z + 0.36, 0.17, 0.14, y + dy, 0.12, ('#6a5c78', '#463c54'))
    elif t == 'vdi':
        box(s, x, z - 0.05, 0.9, 0.56, y, 0.12, DARK, con)
        for dx in (-0.36, 0.36):
            box(s, x + dx, z - 0.12, 0.14, 0.14, y + 0.12, 0.62, B, con)
        box(s, x, z - 0.12, 0.9, 0.16, y + 0.74, 0.1, T, con)
        box(s, x, z - 0.12, 0.38, 0.3, y + 0.42, 0.18, B, con)
        lamp(s, x, z + 0.03, 0.22, y + 0.46, 0.06, L(col))
        for i in range(3):
            box(s, x + 0.0, z + 0.32, 0.34, 0.16, y + i * 0.06, 0.06, ('#ffb347', '#b8762a'))
    elif t == 'chp':
        box(s, x, z, 0.9, 0.7, y, 0.26, B, con)
        lamp(s, x - 0.22, z + 0.35, 0.28, y + 0.08, 0.1, L(col))
        lamp(s, x + 0.22, z + 0.35, 0.28, y + 0.08, 0.1, L(col))
        box(s, x, z - 0.06, 0.4, 0.4, y + 0.26, 0.08, ('#fff7fe', '#c3b3e6'), con)
        for i in range(4):
            toplamp(s, x - 0.15 + i * 0.1, z - 0.3, 0.04, 0.08, y + 0.26, '#d4a017')
            toplamp(s, x - 0.15 + i * 0.1, z + 0.18, 0.04, 0.08, y + 0.26, '#d4a017')
        box(s, x, z - 0.06, 0.16, 0.16, y + 0.34, 0.02, DARK)
    elif t == 'sol':
        for i in range(3):
            zz = z - 0.36 + i * 0.36
            box(s, x, zz, 0.06, 0.06, y, 0.14, DARK)
            box(s, x, zz, 0.66, 0.24, y + 0.14, 0.05, ('#3c4fa0', '#26326a'), con)
            for j in (-0.2, 0, 0.2):
                toplamp(s, x + j, zz, 0.015, 0.22, y + 0.19, '#7ccff0')
    elif t == 'ofn':
        box(s, x, z, 0.8, 0.6, y, 0.26, B, con)
        box(s, x - 0.28, z + 0.3, 0.16, 0.02, y + 0.04, 0.1, RUST)
        lamp(s, x + 0.08, z + 0.3, 0.34, y + 0.06, 0.12, L('#ff9e26'))
        cyl(s, x - 0.18, z - 0.12, 0.2, y + 0.26, 0.18, DARK, con, top_fill=L(col))
        cyl(s, x + 0.26, z - 0.14, 0.08, y + 0.26, 0.4, DARK, con, top_fill='#120a26')
    elif t == 'gen':
        hexp(s, x, z, 0.6, y, 0.16, DARK, con)
        cyl(s, x - 0.12, z - 0.05, 0.36, y + 0.16, 0.34, B, con, top_fill=L(col))
        cyl(s, x - 0.12, z - 0.05, 0.12, y + 0.5, 0.16, T, con, top_fill='#fff7fe')
        cyl(s, x + 0.42, z + 0.05, 0.14, y + 0.16, 0.3, T, con, top_fill=L('#2ee3eb'))
        lamp(s, x - 0.12, z + 0.31, 0.3, y + 0.22, 0.08, L(col))
    elif t == 'bat':
        box(s, x, z, 0.86, 0.56, y, 0.08, DARK, con)
        for dx in (-0.27, 0, 0.27):
            cyl(s, x + dx, z - 0.04, 0.13, y + 0.08, 0.46, B, con, top_fill=T[0])
            lamp(s, x + dx, z + 0.09, 0.16, y + 0.2, 0.05, L(col))
            lamp(s, x + dx, z + 0.09, 0.16, y + 0.3, 0.05, L(col))
    elif t == 'rel':
        hexp(s, x, z, 0.28, y, 0.1, DARK, con)
        box(s, x, z, 0.1, 0.1, y + 0.1, 0.62, B, con)
        box(s, x, z, 0.62, 0.08, y + 0.72, 0.06, T, con)
        for dx in (-0.3, 0.3):
            box(s, x + dx, z, 0.1, 0.1, y + 0.78, 0.08, (L(col), '#5a4a96'), con)
    # --- Tier 3: Beispiele, Inhalt offen ---
    elif t == 't3f':
        deposit(s, 'neon', x + 0.32, z + 0.2, sc=0.6)
        box(s, x - 0.1, z - 0.08, 0.6, 0.5, y, 0.16, B, con)
        for dx in (-0.32, 0.12):
            box(s, x + dx, z - 0.18, 0.08, 0.08, y + 0.16, 0.66, T, con)
        box(s, x - 0.1, z - 0.18, 0.6, 0.1, y + 0.82, 0.08, (col, '#1f9aa5'), con)
        cyl(s, x - 0.1, z - 0.18, 0.08, y + 0.16, 0.5, DARK, con, top_fill=col)
        lamp(s, x - 0.1, z + 0.17, 0.4, y + 0.04, 0.08, L(col))
    elif t == 't3v':
        box(s, x, z, 0.98, 0.74, y, 0.3, B, con)
        box(s, x, z - 0.05, 0.98, 0.5, y + 0.3, 0.06, (col, '#b84a28'), con)
        for dx in (-0.3, 0, 0.3):
            lamp(s, x + dx, z + 0.37, 0.18, y + 0.08, 0.12, L(col))
        for dx in (-0.44, 0.44):
            box(s, x + dx, z - 0.3, 0.08, 0.08, y + 0.36, 0.34, T, con)
        box(s, x, z - 0.3, 0.96, 0.08, y + 0.7, 0.06, T, con)
    elif t == 't3s':
        hexp(s, x, z, 0.62, y, 0.12, DARK, con)
        cyl(s, x, z, 0.5, y + 0.12, 0.16, T, con, top_fill='#120a26', inner=0.72)
        cyl(s, x, z, 0.18, y + 0.12, 0.42, B, con, top_fill=col)
        for dx in (-0.5, 0.5):
            box(s, x + dx, z, 0.08, 0.08, y + 0.28, 0.12, (col, '#3aa870'), con)
    elif t == 't3l':
        hexp(s, x, z, 0.34, y, 0.12, DARK, con)
        prism(s, x, z, hexc(0.16), y + 0.12, 0.8, B, con)
        hexp(s, x, z, 0.3, y + 0.92, 0.06, (col, '#5a4a96'), con)
        cyl(s, x, z, 0.05, y + 0.98, 0.2, DARK, con, top_fill='#fff7fe')
    if tier == 3 and t != 'basis':
        pass


def tile(s, x, z, kind, col=None, tier=1):
    """kind: built, free, locked"""
    top = {'locked': '#160d2e', 'built': '#2f1d5e', 'free': '#28184f'}[kind]
    hexp(s, x, z, 0.92, 0, TILE_H, (top, '#120a26' if kind == 'locked' else '#190f36'))
    inner = [P(x + a, TILE_H, z + b) for a, b in hexc(0.8)]
    if kind == 'built':
        s.raw(f'<polygon points="{pts(inner)}" fill="none" stroke="{s.c(col)}" stroke-width="1.6"/>')
        notches(s, x, z, tier, col)
    elif kind == 'free':
        s.raw(f'<polygon points="{pts(inner)}" fill="none" stroke="#4a3a80" stroke-width="1"/>')
    else:
        s.raw(f'<polygon points="{pts(inner)}" fill="none" stroke="#6a5a96" stroke-width="1.4" stroke-dasharray="5 4"/>')


def badge(s, x, z, kind, col, y=1.2):
    sx, sy = P(x, TILE_H + y, z)
    s.raw(f'<line x1="{sx:.1f}" y1="{sy + 9:.1f}" x2="{sx:.1f}" y2="{P(x, TILE_H + 0.4, z)[1]:.1f}" stroke="{col}" stroke-width="1.5"/>')
    s.raw(f'<rect x="{sx - 9:.1f}" y="{sy - 9:.1f}" width="18" height="18" fill="{NIGHT}" stroke="{col}" stroke-width="2"/>')
    s.raw(f'<g transform="translate({sx - 6.5:.1f},{sy - 6.5:.1f}) scale({13 / 24:.3f})"><path d="{ICON[kind]}" fill="none" stroke="{col}" stroke-width="2.6" stroke-linecap="square"/></g>')


def hpos(q, r):
    return 1.5 * q, K * (r + q / 2)


def dist(q, r):
    return (abs(q) + abs(r) + abs(q + r)) / 2


def parse(k):
    a, b = k.split(',')
    return int(a), int(b)


SRC = {'1,-1': 'schrott', '-1,2': 'schrott', '-2,0': 'schrott', '2,0': 'neon', '-1,-1': 'neon', '0,2': 'daten', '3,-1': 'daten',
       '3,-3': 'schrott', '-2,3': 'neon', '0,3': 'schrott', '-1,-2': 'schrott', '1,-3': 'daten', '-3,0': 'neon'}
BLD = {'0,0': ('basis', 'ok', 2), '1,-1': ('sam', 'ok'), '1,0': ('smz', 'ok'), '1,1': ('rec', 'off'), '0,1': ('lot', 'ok'),
       '0,2': ('scn', 'ok'), '-1,-1': ('zap', 'ok'), '0,-1': ('pls', 'ok'), '-1,1': ('rel', 'ok'), '-1,2': ('sam', 'ok'),
       '-2,0': ('sam', 'jam'), '-1,0': ('gen', 'ok'), '2,-1': ('vdi', 'ok'), '1,-2': ('sol', 'ok')}
TR = [('1,-1', '1,0', 'schrott', ''), ('1,0', '0,1', 'legierung', ''), ('1,0', '2,-1', 'legierung', ''), ('1,0', '1,1', 'schlacke', 'jam'),
      ('-1,-1', '0,-1', 'neon', ''), ('-1,-1', '-1,0', 'neon', ''), ('0,-1', '0,0', 'plasma', ''), ('0,2', '0,1', 'daten', ''),
      ('0,1', '0,0', 'schaltkreis', ''), ('-1,2', '-1,1', 'schrott', ''), ('-1,1', '0,0', 'schrott', '')]
GHOST = '-2,1'
LOCKS = ('3,-1', '-1,3', '-1,-2')


def board(view):
    out = []
    br = 6.55
    pc = [(br * math.cos(math.radians(30 + 60 * i)), br * math.sin(math.radians(30 + 60 * i))) for i in range(6)]
    for i in range(6):
        a, b = pc[i], pc[(i + 1) % 6]
        if (a[1] + b[1]) / 2 > 0.5:
            out.append(f'<polygon points="{pts([P(a[0],0,a[1]),P(b[0],0,b[1]),P(b[0],-0.45,b[1]),P(a[0],-0.45,a[1])])}" fill="#120a26" stroke="{NIGHT}" stroke-width="1"/>')
    out.append(f'<polygon points="{pts([P(a,0,b) for a,b in pc])}" fill="#1b0b3a" stroke="#2ee3eb" stroke-width="2"/>')
    rnd = random.Random(4)
    inside = lambda x, z, m: abs(x) <= br * K / 2 - m and abs(z) + abs(x) / K <= br - m
    for _ in range(80):
        a = rnd.random() * math.tau; rr = 5.2 + rnd.random() * 0.9
        x, z = math.cos(a) * rr, math.sin(a) * rr
        d = rnd.choice([0, math.pi / 3, 2 * math.pi / 3]); Ln = 0.3 + rnd.random() * 0.6
        x2, z2 = x + math.cos(d) * Ln, z + math.sin(d) * Ln
        if not (inside(x, z, 0.3) and inside(x2, z2, 0.3)):
            continue
        (sx, sy), (ex, ey) = P(x, 0, z), P(x2, 0, z2)
        out.append(f'<line x1="{sx:.1f}" y1="{sy:.1f}" x2="{ex:.1f}" y2="{ey:.1f}" stroke="#4a3a80" stroke-width="2"/>')
        out.append(f'<circle cx="{ex:.1f}" cy="{ey:.1f}" r="2.4" fill="#8a6a12" stroke="{NIGHT}" stroke-width="1"/>')
    comp = Svg()
    for _ in range(30):
        a = rnd.random() * math.tau; rr = 5.4 + rnd.random() * 0.7
        x, z = math.cos(a) * rr, math.sin(a) * rr
        if not inside(x, z, 0.45):
            continue
        if rnd.random() < 0.5:
            cyl(comp, x, z, 0.13, 0, 0.3, DARK, None, top_fill=rnd.choice(['#2ee3eb', '#ff2bd6', '#ffe14d']))
        else:
            box(comp, x, z, 0.44, 0.26, 0, 0.08, ('#241a3c', '#140e24'))
            for i in range(4):
                lamp(comp, x - 0.15 + i * 0.1, z + 0.14, 0.04, 0, 0.05, '#d4a017')
    out += comp.out()

    cells = sorted((hpos(q, r)[1], hpos(q, r)[0], q, r) for q in range(-3, 4) for r in range(max(-3, -q - 3), min(3, -q + 3) + 1))
    ts = Svg()
    for z, x, q, r in cells:
        k = f'{q},{r}'
        b = BLD.get(k)
        if b:
            g = DEF[b[0]][0]
            tile(ts, x, z, 'built', GROUPCOL[g], b[2] if len(b) > 2 else DEF[b[0]][1])
        else:
            tile(ts, x, z, 'locked' if dist(q, r) == 3 else 'free')
        if view == 'build' and k == GHOST:
            ts.raw(f'<polygon points="{pts([P(x+a,TILE_H,z+b) for a,b in hexc(0.9)])}" fill="none" stroke="#ffe14d" stroke-width="3"/>')
        if k in LOCKS:
            sx, sy = P(x - 0.45, TILE_H, z - 0.25)
            ts.raw(f'<rect x="{sx-9:.1f}" y="{sy-9:.1f}" width="18" height="18" fill="{NIGHT}" stroke="#6a5a96" stroke-width="1.5"/><g transform="translate({sx-6:.1f},{sy-6:.1f}) scale(0.5)"><path d="{ICON["lock"]}" fill="none" stroke="#8f80bd" stroke-width="2.4"/></g>')
    out += ts.out()
    trs = list(TR) + ([('-2,0', GHOST, 'schrott', 'new'), (GHOST, '-1,1', 'legierung', 'new')] if view == 'build' else [])
    for a, b, ware, kind in trs:
        (ax, az), (bx, bz) = hpos(*parse(a)), hpos(*parse(b))
        (sx, sy), (ex, ey) = P(ax, TILE_H, az), P(bx, TILE_H, bz)
        if kind == 'new':
            out.append(f'<line x1="{sx:.1f}" y1="{sy:.1f}" x2="{ex:.1f}" y2="{ey:.1f}" stroke="#ffe14d" stroke-width="4" stroke-dasharray="6 4"/>')
            continue
        out.append(f'<line x1="{sx:.1f}" y1="{sy:.1f}" x2="{ex:.1f}" y2="{ey:.1f}" stroke="{NIGHT}" stroke-width="8"/>')
        out.append(f'<line x1="{sx:.1f}" y1="{sy:.1f}" x2="{ex:.1f}" y2="{ey:.1f}" stroke="{"#5a4a3a" if kind == "jam" else "#8a6a12"}" stroke-width="6"/>')
        if kind != 'jam':
            col = WARE[ware]
            out.append(f'<line x1="{sx:.1f}" y1="{sy:.1f}" x2="{ex:.1f}" y2="{ey:.1f}" stroke="{col}" stroke-width="2"/>')
            for t in (0.36, 0.64):
                px, py = sx + (ex - sx) * t, sy + (ey - sy) * t
                out.append(f'<rect x="{px-3.5:.1f}" y="{py-3.5:.1f}" width="7" height="7" fill="{col}" stroke="{NIGHT}" stroke-width="1"/>')
    for z, x, q, r in cells:
        k = f'{q},{r}'
        s = Svg()
        b = BLD.get(k)
        if b:
            building(s, b[0], x, z, b[1], b[2] if len(b) > 2 else None)
        elif view == 'build' and k == GHOST:
            G['ghost'] = True; building(s, 'smz', x, z); G['ghost'] = False
        elif k in SRC:
            deposit(s, SRC[k], x, z, locked=dist(q, r) == 3)
        out += s.out()
    if view == 'look':
        s = Svg()
        x, z = hpos(1, 1); badge(s, x, z, 'off', '#ff5c7c')
        x, z = hpos(-2, 0); badge(s, x, z, 'jam', '#ff9e26', 1.15)
        x, z = hpos(1, 0); badge(s, x, z, 'flag', '#ffe14d', 1.25)
        out += s.over
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 418 380" width="418" height="380">' + ''.join(out) + '</svg>'


def item(t, mono=False):
    """Ein Gebaeude auf seinem Feld, in Platinen-Groesse (fuer die Bauleiste)."""
    global CX, CY
    CX, CY = 40, 52
    s = Svg(mono)
    g, tier, _ = DEF[t]
    tile(s, 0, 0, 'built', GROUPCOL[g], tier)
    b = Svg(mono); building(b, t, 0, 0)
    CX, CY = 209.0, 205.0
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 80 80" width="80" height="80">' + ''.join(s.out() + b.out()) + '</svg>'


def ladder():
    """Tier-Leiter: je Gruppe T1 -> T2 -> T3, dazu die Basis in drei Stufen."""
    global CX, CY
    rows = [('sam', 'pmp', 't3f'), ('smz', 'vdi', 't3v'), ('sol', 'gen', 't3s'), ('rel', None, 't3l'), ('basis1', 'basis2', 'basis3')]
    out = []
    for ri, row in enumerate(rows):
        for ci, t in enumerate(row):
            if t is None:
                continue
            CX, CY = 70 + ci * 150, 70 + ri * 110
            s = Svg()
            if t.startswith('basis'):
                tier = int(t[-1]); tile(s, 0, 0, 'built', '#fff7fe', tier); b = Svg(); building(b, 'basis', 0, 0, tier=tier)
            else:
                g, tier, _ = DEF[t]; tile(s, 0, 0, 'built', GROUPCOL[g], tier); b = Svg(); building(b, t, 0, 0)
            out += s.out() + b.out()
    CX, CY = 209.0, 205.0
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 440 560" width="440" height="560">' + ''.join(out) + '</svg>'


if __name__ == '__main__':
    os.makedirs('v3', exist_ok=True)
    open('v3/board_look.svg', 'w').write(board('look'))
    open('v3/board_build.svg', 'w').write(board('build'))
    for t in DEF:
        if t == 'basis':
            continue
        open(f'v3/item_{t}.svg', 'w').write(item(t, mono=DEF[t][1] == 3))
    open('v3/ladder.svg', 'w').write(ladder())
