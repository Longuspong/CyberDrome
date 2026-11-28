"""v5: Farbe + Bauweise je Linie (Schrott, Neon, Daten), Mischung bei Herstellern; jeder Typ hat T1-T3
mit gleicher Funktion. Kamera und Massstab wie v4."""
import math, os, random
import grundformen as g
from grundformen import Svg, prism, box, cyl, hexp, lamp, toplamp, deposit, P, pts, hexc, NIGHT, K, TILE_H

g.U, g.F, g.V = 50.0, 0.86, 0.58

LINE = {'schrott': '#ff6a3d', 'neon': '#2ee3eb', 'daten': '#9d84ff', 'strom': '#6dffa8', 'logistik': '#fff7fe'}
# Blech je Linie und Tier (oben, vorn)
PAL = {
    'schrott': {1: ('#6b5466', '#45334a'), 2: ('#8c7088', '#5e4a62'), 3: ('#b49bb0', '#7e6784')},
    'neon': {1: ('#4a5a8e', '#2e3a66'), 2: ('#6478b0', '#43548a'), 3: ('#91a4d8', '#6074a8')},
    'daten': {1: ('#5d4c8e', '#3a2c66'), 2: ('#7d70b4', '#51458a'), 3: ('#a197d6', '#6c61a8')},
    'strom': {1: ('#3f5a6a', '#27404c'), 2: ('#577c8c', '#3a5866'), 3: ('#82a8b6', '#577e8c')},
    'logistik': {1: ('#5a5470', '#3a3550'), 2: ('#7a7494', '#544e6e'), 3: ('#a7a2c0', '#76708f')},
}
DARK = ('#30244f', '#1d1538')
RUST = ('#8a5a40', '#5e3c2a')
GLASS = ('#7ff0f5', '#1f9aa5')

# typ: (gruppe, linien, name, ab Basis-Tier)
TYPES = {
    'npm': ('foerdern', ['neon'], 'Neonpumpe', 1), 'sam': ('foerdern', ['schrott'], 'Sammler', 1),
    'scn': ('foerdern', ['daten'], 'Scanner', 1),
    'smz': ('veredeln', ['schrott'], 'Schmelze', 1), 'rec': ('veredeln', ['schrott'], 'Recycler', 1),
    'pls': ('veredeln', ['neon'], 'Plasmakammer', 1), 'vdi': ('veredeln', ['schrott'], 'Verdichter', 2),
    'lot': ('herstellen', ['schrott', 'daten'], 'Löter', 1), 'chp': ('herstellen', ['schrott', 'daten', 'neon'], 'Chipfabrik', 2),
    'sol': ('strom', ['strom'], 'Solarpanel', 1), 'ofn': ('strom', ['schrott'], 'Schlackeofen', 1),
    'gen': ('strom', ['neon'], 'Generator', 2), 'bat': ('strom', ['strom'], 'Batterie', 2),
    'rel': ('logistik', ['logistik'], 'Relais', 1), 'basis': ('basis', ['logistik'], 'Basis', 1),
}


def plinth(s, x, z, y, tier, line):
    T = PAL[line][min(3, tier + 1)]
    c = LINE[line]
    if tier == 2:
        hexp(s, x, z, 0.74, y, 0.1, T, c); return y + 0.1
    if tier == 3:
        hexp(s, x, z, 0.8, y, 0.08, T, c); hexp(s, x, z, 0.66, y + 0.08, 0.08, T, c); return y + 0.16
    return y


def building(s, t, x, z, tier=1, state='ok'):
    grp, lines, _, _ = TYPES[t]
    main = lines[0]
    on = state != 'off'
    L = lambda c: c if on else '#3a3450'
    C = {l: LINE[l] for l in lines}
    B = {l: PAL[l][tier] for l in lines}
    TR = {l: PAL[l][min(3, tier + 1)] for l in lines}
    y = TILE_H
    if t != 'basis':
        y = plinth(s, x, z, y, tier, main)
    roof = (lambda l: (LINE[l], PAL[l][1][1])) if tier == 3 else (lambda l: TR[l])

    if t == 'basis':
        c = LINE['logistik']
        hexp(s, x, z, 0.74, y, 0.12, DARK, c)
        hexp(s, x, z, 0.52, y + 0.12, 0.3, PAL['logistik'][1], c)
        for dx in (-0.24, 0, 0.24):
            lamp(s, x + dx, z + 0.45, 0.1, y + 0.2, 0.12, '#2ee3eb')
        top = y + 0.42
        for k in range(tier - 1):
            hexp(s, x, z, 0.42 - 0.06 * k, top, 0.24, PAL['logistik'][2 + k], c)
            lamp(s, x, z + 0.36 - 0.05 * k, 0.28, top + 0.08, 0.07, '#2ee3eb'); top += 0.24
        hexp(s, x, z, 0.3, top, 0.24, PAL['logistik'][3], c); top += 0.24
        hexp(s, x, z, 0.33, top, 0.06, ('#ffe14d', '#b89a1c'), c); top += 0.06
        h = 0.2 + 0.12 * tier
        cyl(s, x, z, 0.05, top, h, DARK, c)
        cyl(s, x, z, 0.09, top + h, 0.07, ('#fff7fe', '#c3b3e6'), c)
        return

    # ---------- Schrott: kantig, schwer, Rost, Schornsteine, Magnet ----------
    if t == 'sam':
        c, b = C['schrott'], B['schrott']
        deposit(s, 'schrott', x + 0.16, z + 0.14, sc=0.8)
        box(s, x - 0.38, z - 0.28, 0.4, 0.34, y, 0.3, b, c)
        if tier == 1: box(s, x - 0.48, z - 0.12, 0.12, 0.02, y + 0.05, 0.1, RUST)
        lamp(s, x - 0.32, z - 0.11, 0.14, y + 0.14, 0.08, L(c))
        box(s, x - 0.38, z - 0.28, 0.1, 0.1, y + 0.3, 0.42 + 0.06 * tier, TR['schrott'], c)
        top = y + 0.72 + 0.06 * tier
        box(s, x - 0.05, z - 0.28, 0.74, 0.1, top, 0.07, roof('schrott'), c)
        if tier >= 2: box(s, x - 0.48, z - 0.28, 0.16, 0.14, top - 0.04, 0.1, DARK, c)
        box(s, x + 0.28, z - 0.06, 0.3, 0.2, y + 0.38, 0.08, DARK, c)
        lamp(s, x + 0.28, z + 0.04, 0.22, y + 0.38, 0.04, L(c))
    elif t == 'smz':
        c, b = C['schrott'], B['schrott']
        box(s, x, z + 0.02, 0.92, 0.62, y, 0.32, b, c)
        if tier == 1: box(s, x + 0.32, z + 0.33, 0.18, 0.02, y + 0.05, 0.12, RUST)
        lamp(s, x - 0.12, z + 0.33, 0.44, y + 0.1, 0.1, L(c))
        box(s, x - 0.14, z - 0.02, 0.44, 0.38, y + 0.32, 0.12, roof('schrott'), c)
        box(s, x - 0.14, z - 0.02, 0.28, 0.24, y + 0.44, 0.02, (L('#ffb347'), '#b8762a'))
        for i in range(tier):
            cz = z - 0.18 + i * 0.16
            box(s, x + 0.32, cz, 0.14, 0.12, y + 0.32, 0.5 - 0.08 * i, DARK, c)
    elif t == 'rec':
        c, b = C['schrott'], B['schrott']
        box(s, x, z - 0.06, 0.88, 0.56, y, 0.16, b, c)
        for i in range(1 + (tier >= 2)):
            box(s, x - 0.22 + i * 0.4, z - 0.14, 0.32, 0.3, y + 0.16, 0.26, TR['schrott'], c)
            lamp(s, x - 0.22 + i * 0.4, z + 0.01, 0.18, y + 0.24, 0.06, L(c))
        if tier == 3: box(s, x, z - 0.14, 0.86, 0.12, y + 0.42, 0.05, roof('schrott'), c)
        for dx, dy in [(-0.2, 0), (0, 0), (0.2, 0), (-0.1, 0.12), (0.1, 0.12)]:
            box(s, x + dx, z + 0.34, 0.17, 0.14, y + dy, 0.12, ('#6a5c78', '#463c54'))
    elif t == 'vdi':
        c, b = C['schrott'], B['schrott']
        box(s, x, z - 0.05, 0.9, 0.56, y, 0.12, DARK, c)
        for dx in (-0.36, 0.36):
            box(s, x + dx, z - 0.12, 0.14, 0.14, y + 0.12, 0.6, b, c)
        box(s, x, z - 0.12, 0.9, 0.16, y + 0.72, 0.1, roof('schrott'), c)
        box(s, x, z - 0.12, 0.38, 0.3, y + 0.42, 0.18, TR['schrott'], c)
        lamp(s, x, z + 0.03, 0.22, y + 0.46, 0.06, L(c))
        for i in range(tier + 1):
            box(s, x, z + 0.32, 0.34, 0.16, y + i * 0.06, 0.06, ('#ffb347', '#b8762a'))
    elif t == 'ofn':
        c, b = C['schrott'], B['schrott']
        box(s, x, z, 0.8, 0.6, y, 0.26, b, c)
        if tier == 1: box(s, x - 0.28, z + 0.3, 0.16, 0.02, y + 0.04, 0.1, RUST)
        lamp(s, x + 0.08, z + 0.3, 0.3, y + 0.06, 0.1, L('#ff9e26'))
        box(s, x - 0.16, z - 0.1, 0.36, 0.32, y + 0.26, 0.16, roof('schrott'), c)
        for i in range(tier):
            box(s, x + 0.28, z - 0.2 + i * 0.14, 0.12, 0.1, y + 0.26, 0.36 - 0.06 * i, DARK, c)
        box(s, x - 0.16, z + 0.07, 0.14, 0.02, y + 0.3, 0.08, (L('#6dffa8'), '#3aa870'))
    # ---------- Neon: rund, Tanks, Glas, Kristalle, Ringe ----------
    elif t == 'npm':
        c, b = C['neon'], B['neon']
        deposit(s, 'neon', x + 0.26, z + 0.16, sc=0.75)
        cyl(s, x - 0.18, z - 0.08, 0.3, y, 0.26, b, c, top_fill=L(c))
        for i in range(tier):
            cyl(s, x - 0.4 + i * 0.2, z - 0.3, 0.07, y + 0.08, 0.36 + 0.04 * i, TR['neon'], c, top_fill=DARK[0])
        cyl(s, x + 0.2, z - 0.24, 0.1, y, 0.22, roof('neon'), c, top_fill=L(c))
    elif t == 'pls':
        c, b = C['neon'], B['neon']
        cyl(s, x, z, 0.5, y, 0.1, DARK, c)
        cyl(s, x, z, 0.34, y + 0.1, 0.26, b, c, top_fill=L('#ff2bd6'))
        n = 2 if tier < 3 else 4
        for i in range(n):
            a = math.pi * (0.15 + i / n * 2)
            cyl(s, x + 0.42 * math.cos(a), z + 0.42 * math.sin(a) * 0.8, 0.06, y + 0.1, 0.34 + 0.06 * tier, TR['neon'], c, top_fill=L(c))
        if tier >= 2: cyl(s, x, z, 0.12, y + 0.36, 0.1, roof('neon'), c, top_fill='#fff7fe')
    elif t == 'gen':
        c, b = C['neon'], B['neon']
        cyl(s, x, z, 0.58, y, 0.14, DARK, c)
        cyl(s, x - 0.1, z - 0.04, 0.36, y + 0.14, 0.3, b, c, top_fill=L(c))
        for i in range(tier):
            cyl(s, x - 0.1, z - 0.04, 0.38, y + 0.18 + i * 0.08, 0.03, TR['neon'], c)
        cyl(s, x - 0.1, z - 0.04, 0.12, y + 0.44, 0.14, roof('neon'), c, top_fill='#fff7fe')
        cyl(s, x + 0.42, z + 0.08, 0.13, y + 0.14, 0.26, TR['neon'], c, top_fill=L('#6dffa8'))
    # ---------- Daten: schlank, Masten, Schuesseln, Lamellen ----------
    elif t == 'scn':
        c, b = C['daten'], B['daten']
        deposit(s, 'daten', x + 0.3, z + 0.16, sc=0.85)
        box(s, x - 0.22, z - 0.14, 0.12, 0.12, y, 0.36 + 0.06 * tier, b, c)
        r = 0.26 + 0.05 * tier
        top = y + 0.36 + 0.06 * tier
        prism(s, x - 0.22, z - 0.14, hexc(r, 30), top, 0.06, TR['daten'], c)
        prism(s, x - 0.22, z - 0.14, hexc(r * 0.6, 30), top + 0.06, 0.02, roof('daten') if tier == 3 else DARK, None)
        box(s, x - 0.22, z - 0.14, 0.04, 0.04, top + 0.06, 0.14, DARK, c)
        if tier >= 2:
            box(s, x - 0.5, z + 0.18, 0.08, 0.08, y, 0.4, b, c)
            lamp(s, x - 0.5, z + 0.22, 0.06, y + 0.3, 0.06, L(c))
    # ---------- Herstellen: Mischung ----------
    elif t == 'lot':
        cs, cd = C['schrott'], C['daten']
        box(s, x + 0.06, z + 0.02, 0.74, 0.6, y, 0.18, B['schrott'], cs)
        for i in range(3):
            toplamp(s, x + 0.1, z - 0.16 + i * 0.16, 0.46, 0.04, y + 0.18, L('#6dffa8'))
        box(s, x - 0.38, z - 0.22, 0.12, 0.12, y, 0.56 + 0.06 * tier, B['daten'], cd)
        top = y + 0.56 + 0.06 * tier
        box(s, x - 0.12, z - 0.22, 0.56, 0.08, top, 0.06, roof('daten') if tier == 3 else TR['daten'], cd)
        box(s, x + 0.14, z - 0.22, 0.05, 0.05, top - 0.22, 0.22, DARK, cd)
        for i in range(tier):
            lamp(s, x - 0.38, z - 0.16, 0.06, y + 0.12 + i * 0.12, 0.06, L(cd))
    elif t == 'chp':
        cs, cd, cn = C['schrott'], C['daten'], C['neon']
        box(s, x - 0.06, z + 0.02, 0.78, 0.66, y, 0.26, B['schrott'], cs)
        for i in range(tier):
            lamp(s, x - 0.3 + i * 0.22, z + 0.35, 0.16, y + 0.08, 0.1, L(cs))
        box(s, x - 0.1, z - 0.04, 0.36, 0.36, y + 0.26, 0.08, ('#fff7fe', '#c3b3e6'), cd)
        for i in range(4):
            toplamp(s, x - 0.25 + i * 0.1, z - 0.27, 0.04, 0.08, y + 0.26, '#d4a017')
            toplamp(s, x - 0.25 + i * 0.1, z + 0.19, 0.04, 0.08, y + 0.26, '#d4a017')
        cyl(s, x + 0.42, z - 0.14, 0.14, y, 0.42, B['neon'], cn, top_fill=L('#ff2bd6'))
    # ---------- Strom (gruen) ----------
    elif t == 'sol':
        c, b = C['strom'], B['strom']
        rows = 2 + (tier >= 2)
        for i in range(rows):
            zz = z - 0.3 + i * (0.6 / max(1, rows - 1)) if rows > 1 else z
            box(s, x, zz, 0.06, 0.06, y, 0.14, DARK)
            box(s, x, zz, 0.7, 0.22, y + 0.14, 0.05, b, c)
            for j in (-0.22, 0, 0.22):
                toplamp(s, x + j, zz, 0.02, 0.2, y + 0.19, '#7ccff0' if tier < 3 else c)
        if tier == 3: box(s, x - 0.42, z, 0.06, 0.06, y, 0.4, TR['strom'], c)
    elif t == 'bat':
        c, b = C['strom'], B['strom']
        n = tier + 1
        box(s, x, z, 0.88, 0.56, y, 0.08, DARK, c)
        for i in range(n):
            dx = (i - (n - 1) / 2) * (0.7 / max(1, n - 1)) if n > 1 else 0
            box(s, x + dx, z - 0.04, 0.18, 0.18, y + 0.08, 0.44, b, c)
            lamp(s, x + dx, z + 0.05, 0.12, y + 0.2, 0.05, L(c))
            lamp(s, x + dx, z + 0.05, 0.12, y + 0.3, 0.05, L(c))
            box(s, x + dx, z - 0.04, 0.08, 0.08, y + 0.52, 0.04, roof('strom'), None)
    # ---------- Logistik (weiss) ----------
    elif t == 'rel':
        c, b = C['logistik'], B['logistik']
        hexp(s, x, z, 0.28, y, 0.1, DARK, c)
        h = 0.5 + 0.12 * tier
        box(s, x, z, 0.1, 0.1, y + 0.1, h, b, c)
        box(s, x, z, 0.62, 0.08, y + 0.1 + h, 0.06, roof('logistik') if tier == 3 else TR['logistik'], c)
        for dx in (-0.3, 0.3):
            box(s, x + dx, z, 0.1, 0.1, y + 0.16 + h, 0.08, (L('#2ee3eb'), '#1f9aa5'), c)


def tile(s, x, z, kind, lines=None, tier=1):
    top = {'locked': '#160d2e', 'built': '#2f1d5e', 'free': '#28184f'}[kind]
    hexp(s, x, z, 0.92, 0, TILE_H, (top, '#120a26' if kind == 'locked' else '#190f36'))
    inner = [P(x + a, TILE_H, z + b) for a, b in hexc(0.8)]
    if kind == 'built':
        cols = [LINE[l] for l in lines]
        for i in range(6):
            col = cols[i % len(cols)]
            a, b = inner[i], inner[(i + 1) % 6]
            s.raw(f'<line x1="{a[0]:.1f}" y1="{a[1]:.1f}" x2="{b[0]:.1f}" y2="{b[1]:.1f}" stroke="{s.c(col)}" stroke-width="1.8" stroke-linecap="round"/>')
        zz = z + 0.92 * K / 2
        for i in range(tier):
            dx = (i - (tier - 1) / 2) * 0.24
            s.poly([P(x + dx - 0.09, TILE_H, zz - 0.02), P(x + dx + 0.09, TILE_H, zz - 0.02), P(x + dx + 0.09, 0, zz), P(x + dx - 0.09, 0, zz)], cols[0], NIGHT, 1.0)
    elif kind == 'free':
        s.raw(f'<polygon points="{pts(inner)}" fill="none" stroke="#4a3a80" stroke-width="1"/>')
    else:
        s.raw(f'<polygon points="{pts(inner)}" fill="none" stroke="#6a5a96" stroke-width="1.4" stroke-dasharray="5 4"/>')


# ---------------- Platine ----------------
BLD = {'0,0': ('basis', 1, 'ok'), '1,-1': ('sam', 1, 'ok'), '1,0': ('smz', 1, 'ok'), '1,1': ('rec', 1, 'off'), '0,1': ('lot', 1, 'ok'),
       '0,2': ('scn', 1, 'ok'), '-1,-1': ('npm', 1, 'ok'), '0,-1': ('pls', 1, 'ok'), '-1,1': ('rel', 1, 'ok'), '-1,2': ('sam', 1, 'ok'),
       '-2,0': ('sam', 1, 'jam'), '-1,0': ('sol', 1, 'ok'), '1,-2': ('sol', 1, 'ok')}
g.TR = [('1,-1', '1,0', 'schrott', ''), ('1,0', '0,1', 'legierung', ''), ('1,0', '0,0', 'legierung', ''), ('1,0', '1,1', 'schlacke', 'jam'),
        ('-1,-1', '0,-1', 'neon', ''), ('0,-1', '0,0', 'plasma', ''), ('0,2', '0,1', 'daten', ''),
        ('0,1', '0,0', 'schaltkreis', ''), ('-1,2', '-1,1', 'schrott', ''), ('-1,1', '0,0', 'schrott', '')]


def board(view, ghost=None):
    """Wie gen2.board, aber mit den neuen Gebaeuden."""
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
    cells = sorted((g.hpos(q, r)[1], g.hpos(q, r)[0], q, r) for q in range(-3, 4) for r in range(max(-3, -q - 3), min(3, -q + 3) + 1))
    ts = Svg()
    for z, x, q, r in cells:
        k = f'{q},{r}'
        b = BLD.get(k)
        if b:
            tile(ts, x, z, 'built', TYPES[b[0]][1], b[1])
        else:
            tile(ts, x, z, 'locked' if g.dist(q, r) == 3 else 'free')
        if ghost and k == ghost[0]:
            ts.raw(f'<polygon points="{pts([P(x+a,TILE_H,z+b) for a,b in hexc(0.9)])}" fill="none" stroke="#ffe14d" stroke-width="3"/>')
        if k in g.LOCKS:
            sx, sy = P(x - 0.45, TILE_H, z - 0.25)
            ts.raw(f'<rect x="{sx-9:.1f}" y="{sy-9:.1f}" width="18" height="18" fill="{NIGHT}" stroke="#6a5a96" stroke-width="1.5"/><g transform="translate({sx-6:.1f},{sy-6:.1f}) scale(0.5)"><path d="{g.ICON["lock"]}" fill="none" stroke="#8f80bd" stroke-width="2.4"/></g>')
    out += ts.out()
    for a, b, ware, kind in g.TR:
        (ax, az), (bx, bz) = g.hpos(*g.parse(a)), g.hpos(*g.parse(b))
        (sx, sy), (ex, ey) = P(ax, TILE_H, az), P(bx, TILE_H, bz)
        out.append(f'<line x1="{sx:.1f}" y1="{sy:.1f}" x2="{ex:.1f}" y2="{ey:.1f}" stroke="{NIGHT}" stroke-width="8"/>')
        out.append(f'<line x1="{sx:.1f}" y1="{sy:.1f}" x2="{ex:.1f}" y2="{ey:.1f}" stroke="{"#5a4a3a" if kind == "jam" else "#8a6a12"}" stroke-width="6"/>')
        if kind != 'jam':
            col = g.WARE[ware]
            out.append(f'<line x1="{sx:.1f}" y1="{sy:.1f}" x2="{ex:.1f}" y2="{ey:.1f}" stroke="{col}" stroke-width="2"/>')
            for tt in (0.36, 0.64):
                px, py = sx + (ex - sx) * tt, sy + (ey - sy) * tt
                out.append(f'<rect x="{px-3.5:.1f}" y="{py-3.5:.1f}" width="7" height="7" fill="{col}" stroke="{NIGHT}" stroke-width="1"/>')
    for z, x, q, r in cells:
        k = f'{q},{r}'
        s = Svg()
        b = BLD.get(k)
        if b:
            building(s, b[0], x, z, b[1], b[2])
        elif ghost and k == ghost[0]:
            g.G['ghost'] = True; building(s, ghost[1], x, z, 1); g.G['ghost'] = False
        elif k in g.SRC:
            deposit(s, g.SRC[k], x, z, locked=g.dist(q, r) == 3)
        out += s.out()
    if view == 'look':
        s = Svg()
        x, z = g.hpos(1, 1); g.badge(s, x, z, 'off', '#ff5c7c')
        x, z = g.hpos(-2, 0); g.badge(s, x, z, 'jam', '#ff9e26', 1.15)
        out += s.over
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 600" width="600" height="600">' + ''.join(out) + '</svg>'


def item(t, tier, mono=False):
    g.CX, g.CY = 52.0, 66.0
    lines = TYPES[t][1]
    s = Svg(mono); tile(s, 0, 0, 'built', lines, tier)
    b = Svg(mono); building(b, t, 0, 0, tier)
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 104 104" width="104" height="104">' + ''.join(s.out() + b.out()) + '</svg>'


def ladder():
    rows = ['npm', 'sam', 'scn', 'smz', 'rec', 'pls', 'vdi', 'lot', 'chp', 'sol', 'ofn', 'gen', 'bat', 'rel', 'basis']
    out = []
    for ri, t in enumerate(rows):
        for ti in (1, 2, 3):
            g.CX, g.CY = 60 + (ti - 1) * 120, 66 + ri * 104
            lines = TYPES[t][1]
            s = Svg(); tile(s, 0, 0, 'built', lines, ti)
            b = Svg(); building(b, t, 0, 0, ti)
            out += s.out() + b.out()
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 {len(rows) * 104 + 20}" width="360" height="{len(rows) * 104 + 20}">' + ''.join(out) + '</svg>'


if __name__ == '__main__':
    os.makedirs('v5', exist_ok=True)  # Ausgabe neben dem Skript
    g.CX, g.CY = 300.0, 312.0
    open('v5/board_look.svg', 'w').write(board('look'))
    g.CX, g.CY = 300.0, 312.0
    open('v5/board_build.svg', 'w').write(board('build', ('-2,1', 'smz')))
    for t in TYPES:
        if t == 'basis':
            continue
        open(f'v5/item_{t}_1.svg', 'w').write(item(t, 1))
        open(f'v5/item_{t}_1g.svg', 'w').write(item(t, 1, True))
        open(f'v5/item_{t}_2g.svg', 'w').write(item(t, 2, True))
    open('v5/ladder.svg', 'w').write(ladder())
