#!/usr/bin/env python3
"""
build_sample_parts.py -- Generator fuer den mitgelieferten Beispiel-Teilesatz.

Dieses Skript ist bewusst Teil des Repos: es dient gleichzeitig als
*ausfuehrbare Spezifikation* des Part-Formats. Wer ein neues Bot-Set
anlegen will, kann hier abschauen, wie ein Teil definiert wird, und das
Ergebnis mit

    python3 tools/build_sample_parts.py

neu erzeugen.


Isometrische Kamera, 45 Grad von oben
=====================================
Das Spiel schaut im 45-Grad-Winkel auf ein um 45 Grad gedrehtes Gitter. Ein
Bodenfeld wird dadurch zur Raute im Verhaeltnis sqrt(2):1 -- hier 76 x 54 px
mit dem Mittelpunkt (64, 96).

Weltkoordinaten (px, py = Gitterachsen, pz = Hoehe) projizieren so:

    x = 64 + cos(45) * (px - py) * SCALE
    y = 96 - (0.5 * (px + py) + cos(45) * pz) * SCALE

Daraus ergibt sich der typische Iso-Look:

  * Die Kamera steht in Richtung (-1, -1, +1). Sichtbar sind daher IMMER genau
    drei Flaechen jedes Quaders: die -px-Flanke (auf dem Bildschirm nach
    unten-links), die -py-Flanke (unten-rechts) und die Oberseite.
  * Weil der Bot 45 Grad zur Kamera steht, sieht man zwei Flanken statt nur
    einer Frontflaeche. Genau das unterscheidet die Iso- von einer
    Frontalansicht -- eine schraeg zur Kamera stehende Kiste zeigt Volumen,
    eine frontale sieht flach aus.
  * Beleuchtung liegt fest im Bildschirmraum, nicht am Bot: Oberseiten hell,
    linke Flanken mittel, rechte Flanken dunkel. Dadurch wirken alle vier
    Richtungen wie vom selben Licht getroffen.

Ein Teil wird deshalb NICHT vier Mal gezeichnet. Es wird einmal als Sammlung
von Quadern in **bot-lokalen** Koordinaten beschrieben

    f   nach vorn (Blickrichtung des Bots)
    l   nach links (aus Sicht des Bots)
    z   nach oben

und der Renderer erzeugt daraus alle vier Richtungen. Das ist der eigentliche
Gewinn: eine Definition, vier konsistente Ansichten, und Rueckseiten-Details
(Kuehlrippen, Schubduesen) verschwinden von selbst, sobald sie von der Kamera
abgewandt sind.

Sichtbarkeit und Zeichenreihenfolge ermittelt der Renderer selbst: jede
Flaeche wird gegen die Kamerarichtung geprueft und anschliessend nach Tiefe
sortiert (Maler-Algorithmus). Auch die Zeichenebene der Ausruestungsslots
(slot_z) faellt dabei ab -- ein Arm, der naeher an der Kamera liegt, wird
automatisch vor den Torso gelegt.


Teile-Codes
-----------
Jedes Teil traegt zusaetzlich zum Dateinamen-Slug (`id`) einen kurzen, stabilen
**Code** fuer das Game Design -- `CHS-001`, `HED-002`, `EQP-004`. Der Code ist
das, was in Balancing-Tabellen, Loot-Listen und Rezepten steht; er aendert sich
nie, auch wenn Teil oder Datei umbenannt werden.

    COR   Kern       (Core)
    HED   Kopf       (Head)
    CHS   Koerper    (Chassis)
    LEG   Fuesse     (Legs)
    EQP   Ausruestung (Equipment)

Die Nummer laeuft je Typ durch, quer ueber alle Sets. Codes muessen im ganzen
Projekt eindeutig sein -- der Server warnt beim Einlesen, wenn zwei Teile
denselben Code tragen.


Links und rechts
----------------
Ankernamen beziehen sich auf die Seiten des BOTS, nicht auf den Bildschirm:
`equip_left` ist immer der linke Arm der DROME. Beim Drehen bleibt eine Waffe
dadurch am selben Arm, statt beim Richtungswechsel die Seite zu tauschen.


Farben
------
Kein Teil enthaelt Hardcoded-Hex-Werte. Alles laeuft ueber CSS Custom
Properties (siehe PALETTE_ROLES). Das Werkstatt-Tool setzt diese Variablen
auf dem Container -- damit ist Umfaerben in Echtzeit moeglich, ohne die
SVG-Datei anzufassen.
"""

from __future__ import annotations

import json
import math
import pathlib
import shutil

ROOT = pathlib.Path(__file__).resolve().parent.parent
PARTS_DIR = ROOT / "parts"

# ---------------------------------------------------------------------------
# Projektion
# ---------------------------------------------------------------------------
COS45 = math.cos(math.radians(45))   # 0.70710678
CENTER_X = 64.0
GROUND_Y = 96.0

# Massstab zwischen Entwurfs- und Bildschirmeinheiten. Die Formen unten sind in
# gut lesbaren Entwurfseinheiten notiert; SCALE bringt den Bot auf eine Groesse,
# die die 128x128-Kachel ausfuellt. Ein Mech ueberragt sein Bodenfeld dabei
# bewusst -- so wird er auf dem Handy nicht zur Briefmarke.
SCALE = 1.35

TILE_HALF_W = 38.0                   # Halbbreite der Bodenraute in Pixeln
TILE_HALF_H = TILE_HALF_W * COS45    # 26.87 -- Verhaeltnis sqrt(2):1

# Hoehe, die genau auf y = 64 projiziert -- der Referenzpunkt "mount" jedes
# Koerpers, damit er im Werkzeug auf CANVAS_ORIGIN landet.
MOUNT_Z = round((GROUND_Y - 64.0) / (COS45 * SCALE), 2)

# Blickrichtung der Kamera. Sichtbar ist eine Flaeche, wenn ihre Normale
# hierhin zeigt.
VIEW = (-1.0, -1.0, 1.0)

# Bot-lokale Achsen je Blickrichtung.
#   F = Vorwaerts-Vektor in Gitterkoordinaten
#   L = Links-Vektor  (= z-Achse kreuz F)
# Auf dem Bildschirm: -px zeigt nach unten-links, -py nach unten-rechts.
FACINGS = {
    "south": ((-1, 0), (0, -1)),   # blickt nach unten-links
    "east":  ((0, -1), (1, 0)),    # blickt nach unten-rechts
    "north": ((1, 0), (0, 1)),     # blickt nach oben-rechts
    "west":  ((0, 1), (-1, 0)),    # blickt nach oben-links
}
DIRECTIONS = ["south", "west", "east", "north"]


def to_world(point, facing):
    """Bot-lokal (f, l, z) -> Gitterkoordinaten (px, py, pz)."""
    f, l, z = point
    (fx, fy), (lx, ly) = FACINGS[facing]
    return (f * fx + l * lx, f * fy + l * ly, z)


def to_screen(world):
    px, py, pz = world
    return (round(CENTER_X + COS45 * (px - py) * SCALE, 2),
            round(GROUND_Y - (0.5 * (px + py) + COS45 * pz) * SCALE, 2))


def project(point, facing):
    return to_screen(to_world(point, facing))


def closeness(world):
    """Groesser = naeher an der Kamera. Basis fuer den Maler-Algorithmus."""
    return -world[0] - world[1] + world[2]


# ---------------------------------------------------------------------------
# Palette
# ---------------------------------------------------------------------------
PALETTE_ROLES = [
    "plate",       # linke Flanken
    "plate_dark",  # rechte Flanken, Schatten
    "plate_light", # Oberseiten
    "metal",       # Gelenke, Rahmen, Mechanik
    "accent",      # Neon-Streifen
    "glow",        # Kern / Emission
    "visor",       # Visier / Sensorik
    "outline",     # Kontur
]

DEFAULT_PALETTE = {
    "plate": "#28304a",
    "plate_dark": "#161c2e",
    "plate_light": "#41507a",
    "metal": "#5b6785",
    "accent": "#2de2e6",
    "glow": "#ff2d95",
    "visor": "#7cf9ff",
    "outline": "#080b13",
}

JUGG_PALETTE = {
    "plate": "#3d2b35",
    "plate_dark": "#22161d",
    "plate_light": "#5d4551",
    "metal": "#7d6b78",
    "accent": "#ff8a3d",
    "glow": "#ffd447",
    "visor": "#ffb057",
    "outline": "#100a0e",
}

C = {role: f"var(--c-{role.replace('_', '-')})" for role in PALETTE_ROLES}

# Material = (Oberseite, linke Flanke, rechte Flanke, Kontur?)
MATERIALS = {
    "plate":  (C["plate_light"], C["plate"], C["plate_dark"], True),
    "dark":   (C["plate"], C["plate_dark"], C["plate_dark"], True),
    "light":  (C["plate_light"], C["plate_light"], C["plate"], True),
    "metal":  (C["metal"], C["metal"], C["plate_dark"], True),
    "visor":  (C["visor"], C["visor"], C["visor"], True),
    "glow":   (C["glow"], C["glow"], C["glow"], False),
    "accent": (C["accent"], C["accent"], C["accent"], False),
}

DEFAULT_Z = {
    "feet": 10, "body": 20, "core": 26,
    "equipment": 30, "equipment_left": 30, "equipment_right": 30, "head": 40,
}


# ---------------------------------------------------------------------------
# Primitive: alles ist ein Quader oder eine Scheibe
# ---------------------------------------------------------------------------
def B(f, l, z, mat):
    """Quader aus (min, max)-Paaren in bot-lokalen Koordinaten."""
    return ("box", f, l, z, mat)


def D(f, l_center, z_center, radius, mat, segments=16):
    """Scheibe auf der nach vorn gerichteten Flaeche (Kern, Muendung, Linse)."""
    return ("disc", f, l_center, z_center, radius, mat, segments)


def _box_faces(f, l, z):
    """Alle sechs Flaechen als (lokale Normale, Eckpunkte)."""
    f0, f1 = f
    l0, l1 = l
    z0, z1 = z
    return [
        ((1, 0, 0),  [(f1, l0, z0), (f1, l1, z0), (f1, l1, z1), (f1, l0, z1)]),
        ((-1, 0, 0), [(f0, l1, z0), (f0, l0, z0), (f0, l0, z1), (f0, l1, z1)]),
        ((0, 1, 0),  [(f1, l1, z0), (f0, l1, z0), (f0, l1, z1), (f1, l1, z1)]),
        ((0, -1, 0), [(f0, l0, z0), (f1, l0, z0), (f1, l0, z1), (f0, l0, z1)]),
        ((0, 0, 1),  [(f0, l0, z1), (f1, l0, z1), (f1, l1, z1), (f0, l1, z1)]),
        ((0, 0, -1), [(f0, l1, z0), (f1, l1, z0), (f1, l0, z0), (f0, l0, z0)]),
    ]


def _shade(world_normal, mat):
    """
    Ordnet einer Weltnormalen ihre Farbe zu. Das Licht haengt am Bildschirm,
    nicht am Bot -- deshalb wird hier die WELT-Normale ausgewertet.
    """
    top, left, right, stroke = MATERIALS[mat]
    nx, ny, nz = world_normal
    if nz > 0.5:
        return top, stroke
    if nx < -0.5:      # Flanke nach unten-links
        return left, stroke
    if ny < -0.5:      # Flanke nach unten-rechts
        return right, stroke
    return None, stroke   # abgewandt


def _emit(points_local, world_normal, mat, facing):
    color, stroke = _shade(world_normal, mat)
    if color is None:
        return None
    world_points = [to_world(p, facing) for p in points_local]
    depth = sum(closeness(w) for w in world_points) / len(world_points)
    coords = " L".join(f"{x} {y}" for x, y in (to_screen(w) for w in world_points))
    extra = "" if stroke else ' stroke="none"'
    return (depth, f'  <path d="M{coords} Z" fill="{color}"{extra}/>')


def render(shapes, facing):
    """Projiziert alle Formen, verwirft abgewandte Flaechen, sortiert nach Tiefe."""
    faces = []
    for shape in shapes:
        if shape[0] == "box":
            _, f, l, z, mat = shape
            for local_normal, points in _box_faces(f, l, z):
                wn = to_world(local_normal, facing)
                emitted = _emit(points, wn, mat, facing)
                if emitted:
                    faces.append(emitted)
        elif shape[0] == "disc":
            _, f, lc, zc, radius, mat, segments = shape
            points = [
                (f, lc + radius * math.cos(2 * math.pi * i / segments),
                 zc + radius * math.sin(2 * math.pi * i / segments))
                for i in range(segments)
            ]
            wn = to_world((1, 0, 0), facing)
            emitted = _emit(points, wn, mat, facing)
            if emitted:
                faces.append(emitted)
        else:
            raise ValueError(f"Unbekanntes Primitiv: {shape[0]}")

    faces.sort(key=lambda item: item[0])     # hinten zuerst
    body = "\n".join(svg for _, svg in faces)
    return (f'<g stroke="{C["outline"]}" stroke-width="0.9" stroke-linejoin="round">\n'
            f"{body}\n</g>")


# ===========================================================================
# RX-Vireo // Scout  (parts/bot1)
#
# Silhouette geht vor Detail: wenige grosse Volumen mit sichtbaren Luecken
# dazwischen. Der Hals trennt Kopf und Schultern, die Schulterpanzer stehen
# seitlich vom Torso ab, die Arme haengen herunter statt in die Kamera zu
# zeigen -- eine nach vorn gerichtete Waffe verschmilzt in der Iso-Ansicht
# sonst mit Torso und Beinen.
#
# Hoehenprofil in Entwurfseinheiten:
#   Fuesse 0..7   Beine 7..36   Hueften 34..41   Torso 41..62
#   Schultern 52..64   Hals 62..66   Kopf 66..78   Antenne bis 89
# ===========================================================================

SCOUT_BODY = [
    # -- Hueftblock -------------------------------------------------------
    B((-6.5, 6.5), (-10, 10), (34, 41), "metal"),
    # -- Torso in zwei Stufen, nach oben breiter --------------------------
    B((-6.5, 7.5), (-9, 9), (41, 49), "plate"),
    B((-7, 8), (-11, 11), (49, 60), "plate"),
    B((-6.5, 7.5), (-10, 10), (60, 62.5), "light"),      # Brustdach
    # Brustpanel, Kernsockel, Neon -- erhaben auf der Frontflaeche
    B((8, 8.6), (-7, 7), (44, 58), "dark"),
    B((8.6, 9.1), (-6, 6), (55, 57), "accent"),
    B((8.6, 9.2), (-5, 5), (45, 53), "dark"),
    # Rueckseite: Kuehlrippen, verschwinden sobald der Bot herschaut
    B((-7.6, -7), (-8, 8), (44, 58), "dark"),
    B((-8.1, -7.6), (-6, 6), (46, 47.5), "light"),
    B((-8.1, -7.6), (-6, 6), (50, 51.5), "light"),
    B((-8.1, -7.6), (-6, 6), (54, 55.5), "light"),
    # -- Schulterpanzer, deutlich vom Torso abgesetzt ---------------------
    B((-6.5, 6.5), (11.5, 19), (52, 62), "plate"),
    B((-7, 7), (11, 19.5), (62, 64.5), "light"),
    B((-6.5, 6.5), (-19, -11.5), (52, 62), "plate"),
    B((-7, 7), (-19.5, -11), (62, 64.5), "light"),
    B((6.5, 7.1), (13, 17.5), (56, 58), "accent"),
    B((6.5, 7.1), (-17.5, -13), (56, 58), "accent"),
    # -- Hals: die Luecke, die den Kopf lesbar macht ----------------------
    B((-3.5, 3.5), (-4, 4), (62.5, 66), "metal"),
]

SCOUT_HEAD = [
    B((-6.5, 6.5), (-7.5, 7.5), (66, 76), "plate"),
    B((-7, 7), (-8, 8), (76, 78), "light"),              # Helmdach
    B((6.5, 7.1), (-5.5, 5.5), (68.5, 73), "visor"),
    B((-7.1, -6.5), (-4, 4), (69, 70.5), "light"),       # Nackenrippen
    B((-7.1, -6.5), (-4, 4), (72, 73.5), "light"),
    B((-1, 1), (4, 5.5), (78, 86), "metal"),             # Antenne
    B((-2, 2), (3, 6.5), (86, 89), "glow"),
]

SCOUT_FEET = [
    B((-4.5, 4.5), (4, 9), (25, 36), "plate"),           # Oberschenkel
    B((-4.5, 4.5), (-9, -4), (25, 36), "plate"),
    B((-5, 5), (3, 9.5), (20, 25), "metal"),             # Kniegelenke
    B((-5, 5), (-9.5, -3), (20, 25), "metal"),
    B((-4, 4), (4, 8.5), (7, 22), "plate"),              # Unterschenkel
    B((-4, 4), (-8.5, -4), (7, 22), "plate"),
    B((-7, 9), (3, 10), (0, 7), "plate"),                # Fuesse
    B((-7, 9), (-10, -3), (0, 7), "plate"),
    B((9, 9.5), (4, 9), (2, 3.5), "accent"),
    B((9, 9.5), (-9, -4), (2, 3.5), "accent"),
]

SCOUT_CORE = [
    D(9.4, 0, 49, 4.2, "dark"),
    D(9.8, 0, 49, 2.6, "glow"),
    B((9.9, 10.2), (-0.5, 0.5), (53.5, 55), "accent"),
    B((9.9, 10.2), (-0.5, 0.5), (43, 44.5), "accent"),
    B((9.9, 10.2), (-6, -4.8), (48.5, 49.5), "accent"),
    B((9.9, 10.2), (4.8, 6), (48.5, 49.5), "accent"),
]

# --- Ausruestung ------------------------------------------------------------
# Waffen sind SYMMETRISCH um ihren eigenen Anker modelliert und dadurch an
# beiden Armen verwendbar. In der Iso-Ansicht waere Spiegeln auf dem Bildschirm
# geometrisch falsch -- die Beleuchtung haengt am Bildschirm, eine gespiegelte
# Kiste bekaeme ihre Lichtseite auf die falsche Flanke. Der symmetrische Aufbau
# loest das ohne zweite Datei.
EQ_BLASTER = [
    B((-3, 3), (-4, 4), (45, 54), "metal"),              # Oberarm am Anker
    B((-5, 6), (-5.5, 5.5), (33, 46), "plate"),          # Gehaeuse
    B((6, 14), (-4, 4), (35, 42), "plate"),              # Lauf nach vorn
    B((14, 16.5), (-3, 3), (36, 41), "dark"),            # Muendungsblock
    D(16.8, 0, 38.5, 2.0, "glow"),
    B((-4, 5), (5.5, 6.1), (42.5, 44), "accent"),
    B((-4, 5), (-6.1, -5.5), (42.5, 44), "accent"),
]

EQ_SHIELD = [
    B((-3, 3), (-4, 4), (45, 54), "metal"),
    B((7, 10), (-7, 7), (31, 58), "plate"),
    B((10, 10.6), (-5, 5), (35, 54), "dark"),
    B((10.6, 11.1), (-1.2, 1.2), (38, 51), "accent"),
    B((6.6, 10.2), (-7.6, -6.6), (31, 58), "light"),     # Kantenprofil
    B((6.6, 10.2), (6.6, 7.6), (31, 58), "light"),
]


# ===========================================================================
# HX-Molok // Juggernaut  (parts/bot2) -- drei Ausruestungsanker
# Breiter und gedrungener; der dritte Anker sitzt hinter dem Kopf.
# ===========================================================================

JUGG_BODY = [
    B((-8, 8), (-13, 13), (31, 39), "metal"),
    B((-8, 9), (-12, 12), (39, 47), "plate"),
    B((-8.5, 10), (-15, 15), (47, 58), "plate"),
    B((-8, 9), (-14, 14), (58, 61), "light"),
    B((10, 10.7), (-10, 10), (42, 56), "dark"),
    B((10.7, 11.3), (-8, 8), (52, 54.5), "accent"),
    B((10.7, 11.4), (-7, 7), (43, 51), "dark"),
    # Rueckseite: Reaktorblock
    B((-9.1, -8.5), (-11, 11), (42, 56), "dark"),
    B((-9.6, -9.1), (-9, 9), (44, 46), "light"),
    B((-9.6, -9.1), (-9, 9), (48, 50), "light"),
    B((-9.6, -9.1), (-9, 9), (52, 54), "light"),
    # Schulterplatten
    B((-8, 8), (15.5, 26), (48, 59), "plate"),
    B((-8.5, 8.5), (15, 26.5), (59, 62), "light"),
    B((-8, 8), (-26, -15.5), (48, 59), "plate"),
    B((-8.5, 8.5), (-26.5, -15), (59, 62), "light"),
    B((8, 8.6), (18, 23), (52, 54.5), "accent"),
    B((8, 8.6), (-23, -18), (52, 54.5), "accent"),
    B((-5, 5), (-6, 6), (61, 64), "metal"),
]

JUGG_HEAD = [
    B((-8, 8.5), (-10, 10), (64, 74), "plate"),
    B((-8.5, 9), (-10.5, 10.5), (74, 76.5), "light"),
    B((8.5, 9.2), (-8, 8), (66.5, 71), "visor"),
    B((-8.6, -8), (-6, 6), (67, 68.5), "light"),
    B((-8.6, -8), (-6, 6), (70, 71.5), "light"),
    B((-5, 5), (10, 13), (68, 74), "metal"),             # Seitensensoren
    B((-5, 5), (-13, -10), (68, 74), "metal"),
]

JUGG_FEET = [
    B((-5.5, 5.5), (5, 11.5), (24, 33), "plate"),
    B((-5.5, 5.5), (-11.5, -5), (24, 33), "plate"),
    B((-6, 6), (4, 12), (18, 24), "metal"),
    B((-6, 6), (-12, -4), (18, 24), "metal"),
    B((-5, 5), (5, 11), (7, 20), "plate"),
    B((-5, 5), (-11, -5), (7, 20), "plate"),
    B((-9, 11), (4, 13), (0, 7), "plate"),
    B((-9, 11), (-13, -4), (0, 7), "plate"),
    B((11, 11.6), (5, 12), (1.5, 3.5), "accent"),
    B((11, 11.6), (-12, -5), (1.5, 3.5), "accent"),
]

JUGG_CORE = [
    D(11.0, 0, 47, 5.5, "dark"),
    B((11.3, 11.7), (-3.6, 3.6), (43.5, 50.5), "glow"),
    B((11.3, 11.7), (-2, 2), (41.5, 52.5), "glow"),
]

EQ_CANNON = [
    B((-4, 4), (-5.5, 5.5), (42, 51), "metal"),
    B((-6, 7), (-7, 7), (28, 43), "plate"),
    B((7, 18), (-5, 5), (31, 39), "plate"),
    B((18, 21), (-4, 4), (32, 38), "dark"),
    D(21.3, 0, 35, 2.5, "glow"),
    B((-5, 6), (7, 7.6), (39.5, 41.5), "accent"),
    B((-5, 6), (-7.6, -7), (39.5, 41.5), "accent"),
]

# Der Pod sitzt hinter dem Kopf auf der Schulterbruecke und zeigt vor allem
# seine Oberseite -- das deutlichste Beispiel dafuer, wie stark die
# 45-Grad-Kamera waagerechte Flaechen betont. In der Nordansicht schiebt ihn
# die Tiefensortierung von selbst vor den Kopf.
EQ_DRONE_POD = [
    B((-8, 2), (-5, 5), (59, 62), "metal"),
    B((-10, 4), (-8, 8), (62, 69), "plate"),
    B((-10.5, 4.5), (-8.5, 8.5), (69, 71), "light"),
    B((4, 4.6), (-6, 6), (63.5, 67.5), "dark"),
    D(4.9, 0, 65.5, 1.9, "glow"),
    B((-7, -3), (-2, 2), (71, 74.5), "accent"),
]


# ===========================================================================
# Teile-Spezifikation
#
# Anker werden in bot-lokalen Koordinaten angegeben und pro Richtung mit
# derselben Projektion berechnet wie die Grafik -- Grafik und Anker koennen
# also nicht auseinanderlaufen.
# ===========================================================================

# Bezugspunkt des Torsos, gegen den die Zeichenebene der Arme bestimmt wird.
TORSO_REF = (0.0, 0.0, 50.0)

SETS = [
    {
        "dir": "bot1",
        "id": "bot1",
        "name": "RX-Vireo // Scout",
        "description": "Leichte Aufklaerer-DROME. Zwei Ausruestungsanker.",
        "palette": DEFAULT_PALETTE,
        "parts": [
            {
                "id": "scout_body", "code": "CHS-001", "type": "body", "name": "Vireo Chassis",
                "tags": ["light", "scout"], "shapes": SCOUT_BODY,
                "anchors": {
                    "mount": (0, 0, MOUNT_Z),    # projiziert exakt auf (64, 64)
                    "head": (0, 0, 66),
                    "feet": (0, 0, 36),
                    "core": (8.8, 0, 49),
                    "equip_left": (0, 19.5, 52),
                    "equip_right": (0, -19.5, 52),
                },
            },
            {
                "id": "scout_head", "code": "HED-001", "type": "head", "name": "Vireo Sensorkopf",
                "tags": ["light", "sensor"], "shapes": SCOUT_HEAD,
                "anchors": {"mount": (0, 0, 66), "sensor": (7.1, 0, 70.7)},
            },
            {
                "id": "scout_feet", "code": "LEG-001", "type": "feet", "name": "Vireo Sprintbeine",
                "tags": ["light", "fast"], "shapes": SCOUT_FEET,
                "anchors": {"mount": (0, 0, 36), "ground": (1, 0, 0)},
            },
            {
                "id": "scout_core", "code": "COR-001", "type": "core", "name": "Vireo Impulskern",
                "tags": ["core", "energy"], "shapes": SCOUT_CORE,
                "anchors": {"mount": (8.8, 0, 49)},
            },
            {
                "id": "eq_pulse_blaster", "code": "EQP-001", "type": "equipment", "name": "Puls-Blaster",
                "tags": ["weapon", "ranged"], "shapes": EQ_BLASTER,
                "slots": ["equip_left", "equip_right"],
                "anchors": {"mount": (0, 0, 52), "muzzle": (16.8, 0, 38.5)},
            },
            {
                "id": "eq_deflector", "code": "EQP-002", "type": "equipment", "name": "Deflektor-Schild",
                "tags": ["defense"], "shapes": EQ_SHIELD,
                "slots": ["equip_left", "equip_right"],
                "anchors": {"mount": (0, 0, 52)},
            },
        ],
    },
    {
        "dir": "bot2",
        "id": "bot2",
        "name": "HX-Molok // Juggernaut",
        "description": "Schwerer Rahmen. Drei Ausruestungsanker (inkl. Schulterpod).",
        "palette": JUGG_PALETTE,
        "parts": [
            {
                "id": "jugg_body", "code": "CHS-002", "type": "body", "name": "Molok Chassis",
                "tags": ["heavy"], "shapes": JUGG_BODY,
                "anchors": {
                    "mount": (0, 0, MOUNT_Z),
                    "head": (0, 0, 64),
                    "feet": (0, 0, 33),
                    "core": (10.5, 0, 47),
                    "equip_left": (0, 26.5, 49),
                    "equip_right": (0, -26.5, 49),
                    "equip_shoulder": (-5, 0, 61),
                },
            },
            {
                "id": "jugg_head", "code": "HED-002", "type": "head", "name": "Molok Bunkerkopf",
                "tags": ["heavy", "armored"], "shapes": JUGG_HEAD,
                "anchors": {"mount": (0, 0, 64), "sensor": (9.2, 0, 68.7)},
            },
            {
                "id": "jugg_feet", "code": "LEG-002", "type": "feet", "name": "Molok Standbeine",
                "tags": ["heavy", "slow"], "shapes": JUGG_FEET,
                "anchors": {"mount": (0, 0, 33), "ground": (1, 0, 0)},
            },
            {
                "id": "jugg_core", "code": "COR-002", "type": "core", "name": "Molok Fusionskern",
                "tags": ["core", "fusion"], "shapes": JUGG_CORE,
                "anchors": {"mount": (10.5, 0, 47)},
            },
            {
                "id": "eq_siege_cannon", "code": "EQP-003", "type": "equipment",
                "name": "Belagerungskanone", "tags": ["weapon", "heavy"],
                "shapes": EQ_CANNON, "slots": ["equip_left", "equip_right"],
                "anchors": {"mount": (0, 0, 49), "muzzle": (21.3, 0, 35)},
            },
            {
                "id": "eq_drone_pod", "code": "EQP-004", "type": "equipment", "name": "Drohnen-Pod",
                "tags": ["support", "shoulder"], "shapes": EQ_DRONE_POD,
                "slots": ["equip_shoulder"],
                "anchors": {"mount": (0, 0, 61)},
            },
        ],
    },
]


SVG_TEMPLATE = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128"
     data-part-id="{pid}" data-type="{ptype}" data-direction="{direction}">
  <title>{name} ({direction})</title>
  <!--
    Isometrische Ansicht, Kamera 45 Grad von oben, Blickrichtung {direction}.
    Bodenfeld: Raute 76 x 54 px um den Mittelpunkt (64, 96).
    Projektion:  x = 64 + cos(45)*(px - py)*SCALE
                 y = 96 - (0.5*(px + py) + cos(45)*pz)*SCALE
    Erzeugt von tools/build_sample_parts.py aus einer bot-lokalen Quader-
    Definition -- nicht von Hand bearbeiten, sondern dort aendern.
    Farben ausschliesslich ueber CSS Custom Properties (siehe parts/README.md).
  -->
{body}
</svg>
"""


def slot_draw_order(part: dict, direction: str) -> dict:
    """
    Zeichenebene je Slot -- direkt aus der Kameratiefe des Ankers.

    Die Tiefe IST die Zeichenreihenfolge: was naeher an der Kamera liegt, wird
    spaeter gezeichnet. Damit stimmt die Ueberdeckung in allen vier Richtungen
    von selbst, ohne handgepflegte Tabellen. Beispiele:

      * Sued: der linke Arm liegt vorn, der rechte hinter dem Torso.
      * Nord: genau umgekehrt -- und der Schulterpod schiebt sich vor den Kopf,
        weil er dann das kameranaechste Teil ist.
    """
    order = {}
    for name, local in part["anchors"].items():
        if name == "mount":
            continue
        order[name] = round(closeness(to_world(local, direction)), 1)
    return order


def write_part(set_dir: pathlib.Path, set_id: str, part: dict, direction: str,
               palette: dict) -> None:
    pid = part["id"]
    stem = f"{pid}_{direction}"

    svg = SVG_TEMPLATE.format(
        pid=pid, ptype=part["type"], direction=direction,
        name=part.get("name", pid), body=render(part["shapes"], direction),
    )
    (set_dir / f"{stem}.svg").write_text(svg, encoding="utf-8")

    meta = {
        "id": pid,
        "code": part["code"],
        "set": set_id,
        "type": part["type"],
        "name": part.get("name", pid),
        "direction": direction,
        "svg": f"{stem}.svg",
        "view_box": [0, 0, 128, 128],
        # Fuer den Koerper ist die eigene Ebene ebenfalls seine Kameratiefe --
        # so liegt er in derselben Skala wie die slot_z-Werte darunter. Alle
        # anderen Teile behalten einen Standardwert fuer die Einzelvorschau,
        # im zusammengebauten Bot gewinnt ohnehin slot_z des Koerpers.
        "z_index": (round(closeness(to_world(TORSO_REF, direction)), 1)
                    if part["type"] == "body"
                    else part.get("z_index", DEFAULT_Z.get(part["type"], 20))),
        "anchors": [
            {"name": name, **dict(zip(("x", "y"), project(local, direction)))}
            for name, local in part["anchors"].items()
        ],
        "color_scheme": dict(palette),
        "tags": part.get("tags", []),
    }
    if part["type"] == "body":
        meta["slot_z"] = slot_draw_order(part, direction)
    if "slots" in part:
        meta["slots"] = part["slots"]

    (set_dir / f"{stem}.json").write_text(
        json.dumps(meta, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )


def main() -> None:
    for spec in SETS:
        set_dir = PARTS_DIR / spec["dir"]
        if set_dir.exists():
            shutil.rmtree(set_dir)
        set_dir.mkdir(parents=True)

        (set_dir / "set.json").write_text(
            json.dumps({
                "id": spec["id"], "name": spec["name"],
                "description": spec["description"], "palette": spec["palette"],
            }, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )

        for part in spec["parts"]:
            for direction in DIRECTIONS:
                write_part(set_dir, spec["id"], part, direction, spec["palette"])

        print(f"[ok] {spec['dir']}: {len(list(set_dir.glob('*.svg')))} SVGs geschrieben")

    # Codes muessen projektweit eindeutig sein -- hier gleich mitpruefen.
    seen = {}
    for spec in SETS:
        for part in spec["parts"]:
            code = part["code"]
            if code in seen:
                raise SystemExit(f"Doppelter Teile-Code {code}: "
                                 f"{seen[code]} und {spec['id']}/{part['id']}")
            seen[code] = f"{spec['id']}/{part['id']}"

    print(f"\nIso-Kamera 45 Grad  |  Bodenfeld {2 * TILE_HALF_W:.0f} x "
          f"{2 * TILE_HALF_H:.0f} px um ({CENTER_X:.0f}, {GROUND_Y:.0f})")
    print(f"{len(seen)} Teile-Codes vergeben: {', '.join(sorted(seen))}")


if __name__ == "__main__":
    main()
