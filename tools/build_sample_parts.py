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

Eine Palette wird aber nicht mehr ueber diese acht Rollen bedient, sondern
ueber **genau vier Kategorien je Bauteiltyp** (siehe CATEGORIES). Ein Kopf
faerbt Panzerung / Mechanik / Visier / Kontur, ein Kern Gehaeuse / Kernglut /
Energieringe / Kontur. Die acht CSS-Rollen fallen daraus ab -- Kante und
Schatten der Panzerung werden aus der Grundfarbe abgeleitet, damit die
Iso-Beleuchtung gar nicht erst falsch eingestellt werden kann.
"""

from __future__ import annotations

import json
import math
import pathlib
import re
import shutil
from xml.etree import ElementTree

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

# --- Vier Kategorien je Bauteiltyp ----------------------------------------
#
# Acht flache Farbrollen sind zum Bemalen zu viele -- und drei davon (plate,
# plate_light, plate_dark) duerfen ohnehin nicht frei gewaehlt werden: sie SIND
# die Beleuchtung. Eine Palette wird deshalb ueber genau vier Kategorien je
# Bauteiltyp bedient; welche vier das sind, haengt davon ab, was der Typ
# ueberhaupt bemalt. Die acht CSS-Rollen leiten sich daraus ab.
#
#   base   unveraendert
#   light  Oberseiten -- multiplikativ aufgehellt, damit Ton und Saettigung
#          erhalten bleiben (Mischen mit Weiss wuerde ausbleichen)
#   dark   rechte Flanken / Schatten
#   hot    Emission: dieselbe Farbe, additiv Richtung Weiss gezogen
SHADES = {"base": (1.0, 0), "light": (1.62, 6), "dark": (0.56, 0), "hot": (1.0, 45)}

PALETTE_TYPES = ("body", "head", "feet", "core", "equipment")

_HULL = ("hull", "Panzerung",
         {"plate": "base", "plate_light": "light", "plate_dark": "dark"})
_MECH = ("mech", "Mechanik", {"metal": "base"})
_NEON = ("neon", "Neon", {"accent": "base", "glow": "hot", "visor": "hot"})
_LINE = ("line", "Kontur", {"outline": "base"})

# Jede Zeile deckt alle acht Rollen ab -- so bleibt keine CSS-Variable ungesetzt,
# auch wenn ein spaeter importiertes Teil eine Rolle nutzt, die der mitgelieferte
# Satz fuer diesen Typ nicht braucht.
CATEGORIES = {
    "body": [_HULL, _MECH, _NEON, _LINE],
    "feet": [_HULL, _MECH, _NEON, _LINE],
    "equipment": [_HULL, _MECH, _NEON, _LINE],
    "head": [_HULL, _MECH,
             ("visor", "Visier", {"visor": "base", "glow": "hot", "accent": "base"}),
             _LINE],
    "core": [("case", "Gehaeuse",
              {"plate": "base", "plate_light": "light", "plate_dark": "dark",
               "metal": "light"}),
             ("ember", "Kernglut", {"glow": "base", "visor": "hot"}),
             ("rings", "Energieringe", {"accent": "base"}),
             _LINE],
}


def palette_type(part_type: str) -> str:
    """equipment_left / equipment_right teilen sich die Kategorien von equipment."""
    return "equipment" if part_type.startswith("equipment") else part_type


def _shade_hex(color: str, shade: str) -> str:
    factor, offset = SHADES[shade]
    raw = color.lstrip("#")
    channels = (int(raw[i:i + 2], 16) for i in (0, 2, 4))
    return "#" + "".join(
        f"{max(0, min(255, round(c * factor + offset))):02x}" for c in channels
    )


def resolve_roles(colors: dict, part_type: str) -> dict:
    """Vier Kategoriefarben -> die acht CSS-Rollen eines Bauteiltyps."""
    roles = {}
    for key, _label, mapping in CATEGORIES[palette_type(part_type)]:
        base = colors.get(key)
        if not base:
            continue
        for role, shade in mapping.items():
            roles[role] = _shade_hex(base, shade)
    return roles


def make_palette(hull, mech, neon, visor, ember, rings, line) -> dict:
    """Set-Palette: vier Kategorien fuer jeden der fuenf Bauteiltypen."""
    armour = {"hull": hull, "mech": mech, "neon": neon, "line": line}
    return {
        "body": dict(armour),
        "feet": dict(armour),
        "equipment": dict(armour),
        "head": {"hull": hull, "mech": mech, "visor": visor, "line": line},
        "core": {"case": hull, "ember": ember, "rings": rings, "line": line},
    }


DEFAULT_PALETTE = make_palette(
    hull="#28304a", mech="#5b6785", neon="#2de2e6", visor="#7cf9ff",
    ember="#ff2d95", rings="#2de2e6", line="#080b13",
)

JUGG_PALETTE = make_palette(
    hull="#3d2b35", mech="#7d6b78", neon="#ff8a3d", visor="#ffb057",
    ember="#ffd447", rings="#ff8a3d", line="#100a0e",
)

MAGE_PALETTE = make_palette(
    hull="#2f2450", mech="#6f5f97", neon="#b06bff", visor="#d6b8ff",
    ember="#7cf9ff", rings="#ff5ec7", line="#0d0818",
)

STRIX_PALETTE = make_palette(
    hull="#1c3330", mech="#557d71", neon="#6dff9f", visor="#c2ffd7",
    ember="#6dff9f", rings="#2fbf8c", line="#060f0d",
)

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
# Montageklasse und Bauart -- die Spielregel hinter den Ausruestungsslots
# ---------------------------------------------------------------------------
# Ein Anker sagt nur, WO etwas sitzt. Fuer ein deterministisches Tactics muss
# ein Slot aber auch sagen, WAS dort sitzen darf -- sonst traegt der Sprinter
# die Belagerungskanone, und die Silhouette luegt ueber die Reichweite.
#
#   mount_class   was die Halterung tragen muss:  light < medium < heavy
#   category      Bauart:  weapon | shield | support
#
# Ein Koerper beschreibt seine Slots ueber ``slot_rules``:
#
#     "slot_rules": {
#         "equip_left":     {"max_class": "medium"},
#         "equip_shoulder": {"max_class": "light", "categories": ["support"]},
#     }
#
# Fehlt eine Regel, nimmt der Slot alles an -- importierte Teile funktionieren
# damit unveraendert weiter.
MOUNT_CLASSES = ("light", "medium", "heavy")
EQUIP_CATEGORIES = ("weapon", "shield", "support")
DEFAULT_MOUNT_CLASS = "light"
DEFAULT_CATEGORY = "weapon"


def fits_rule(mount_class: str, category: str, rule: dict | None) -> bool:
    """Darf ein Ausruestungsteil in einen Slot mit dieser Regel?"""
    if not rule:
        return True
    limit = rule.get("max_class", MOUNT_CLASSES[-1])
    if MOUNT_CLASSES.index(mount_class) > MOUNT_CLASSES.index(limit):
        return False
    allowed = rule.get("categories")
    return not allowed or category in allowed


# ---------------------------------------------------------------------------
# Spielwerte -- die einzige Balancing-Tabelle des Projekts
# ---------------------------------------------------------------------------
# Bis hierher beschreibt eine Teil-Definition nur, wie ein Teil AUSSIEHT und wo
# es sitzt. Ab hier steht, was es im Kampf TUT. Beides gehoert in dieselbe
# Datei, weil ein zweites Bauteil-Datenmodell daneben der teuerste Fehler
# waere, den dieses Projekt machen kann: die Anker liefen von den Werten weg,
# und niemand koennte sagen, welche Seite recht hat.
#
# Die Werte landen ueber ``write_part`` als Block ``stats`` in jeder der vier
# Richtungs-JSONs eines Teils. Sie sind richtungsunabhaengig -- deshalb stehen
# sie hier einmal und nicht viermal.
#
# Ein DROME hat KEINE Grundwerte. Jeder Stat ist ausschliesslich die Summe
# seiner Teile; ein Rumpf ohne Antrieb hat mov 0 und kommt nicht in den Kampf.
#
# Slots des Repos (nicht die sechs des Entwurfsdokuments):
#
#     body   Chassis   traegt HP, DEF, Traglast -- und bestimmt ueber seine
#                      equip_*-Anker, wie viele Ausruestungsslots es gibt
#     core   Kern      Energie, Regeneration, Energie-Ausstoss
#     feet   Antrieb   MOV, SPD und -- die eigentliche Kaufentscheidung --
#                      die Traversierungsflags
#     head   Sensorik  kleine Boni; hier sitzt der Blick durch Haze-Felder
#     equipment        Waffen, Schilde, Support -- gewaehren die Aktionen
#
# Reine Zahlen, keine Logik: der Kampfcode liest ``stats`` aus der JSON und
# hat keinen einzigen Balancing-Wert in sich.

# Vollstaendiger Satz mit Nullwerten. Jedes Teil ueberschreibt nur, was es
# tatsaechlich beitraegt -- so ist an der Tabelle unten auf einen Blick
# erkennbar, wofuer ein Teil da ist.
STAT_DEFAULTS = {
    # Grundwerte (additiv ueber alle Teile)
    "hp": 0, "en_max": 0, "en_regen": 0,
    "spd": 0, "mov": 0, "atk": 0, "def": 0,
    # Baukosten
    "weight": 0, "power_draw": 0,
    # Nur body: was das Chassis traegt
    "weight_capacity": 0,
    # Nur core: was der Kern liefert
    "power_output": 0,
    # Traversierung -- im Regelfall am Antrieb, technisch an jedem Teil moeglich
    "can_pass_units": False,     # durch besetzte Felder ziehen (nie darauf enden)
    "can_enter_steps": False,    # Stufen betreten
    "can_pass_blocks": False,    # Post-MVP (Tunnelbauer). Bleibt ueberall False.
    "ignores_drift": False,      # immun gegen Drift-Zonen
    "drift_modifier": 0,         # addiert auf die Gleitdistanz
    "step_cost_reduced": False,  # Stufe kostet 1 MP statt 2
    # Sensorik -- an jedem Slot moeglich, im Bestand an Koepfen
    "grants_ignore_haze": False,
    # Aggro-Generierung in Prozentpunkten. Kein Bauteil im Bestand fuehrt ihn:
    # Aufmerksamkeit entsteht aus Aktionen, nicht aus Identitaet. Ein Chassis
    # oder Kern mit einem Grundwert darauf waere genau die Abkuerzung, die das
    # System entwertet -- dann tankt, wer das richtige Teil traegt, statt wer
    # das Richtige tut. Vorgesehen ist der Wert allein fuer Support-Module
    # (Koeder, Provokationssender), die dafuer einen Ausruestungsslot kosten.
    "aggro_bonus": 0,
}

# Ausruestung gewaehrt genau eine Aktion. ``power`` > 0 ist Schaden,
# ``power`` < 0 ist Heilung. Ohne ``action`` ist ein Teil rein passiv.
#
#   category    attack | ability   -- welches Budget der Zug verbraucht
#   targeting   single | self | tile | aoe_around_target
#
# Regel aus dem Entwurf, hier hart eingehalten: jede Aktion mit Reichweite > 1
# braucht Sichtlinie. Ohne sie waere das ganze Terrainsystem Dekoration.
#
# ``aggro_coeff`` sagt, wie LAUT eine Aktion ist -- wie stark ihre Wirkung in
# die Aggro-Tabelle der Gegner eingeht (scripts/battle/aggro_table.gd). Das
# Raster, an dem sich neue Aktionen ausrichten:
#
#   1.0    normaler Angriff, die Grundlinie -- steht deshalb nirgends dabei
#   0.5    Heilung: der Techniker ist angreifbar, aber kein Aggro-Magnet
#   0.35   Praezisionswaffen: viel Schaden, wenig Krach
#
# Der Koeffizient haengt ausdruecklich NICHT an der Reichweite. Er ist der
# Hebel, mit dem sich "wie viel richtet die Waffe an" von "wie sehr provoziert
# sie" trennen laesst -- eine Ableitung aus range_tiles waere untunebar und
# eine zweite, stillschweigende Wahrheit ueber die Auffaelligkeit einer Waffe.
#
# ``aggro_flat`` ist der Pauschalwert fuer Aktionen ohne Wirkungsmenge, und
# ``taunt_turns`` macht eine Aktion zur Provokation (harter Zwang, befristet).
# Kein Bauteil im Bestand provoziert bislang.
STATS = {
    # --- CHASSIS (body) ----------------------------------------------------
    # HP, DEF, Traglast. SPD/MOV sind Auf- und Abschlaege auf den Antrieb.
    "scout_body":  {"hp":  60, "def": 1, "spd":  2, "mov":  0, "weight_capacity": 18},
    # Traglast 31 statt 28: der Molok hat DREI Anker (GDD 3b), konnte sie aber
    # mit eigenen Teilen nie alle belegen -- es gab bis zum Koedersender nur
    # zwei Ausruestungsteile im Satz, deshalb ist es nie aufgefallen. Ein
    # Chassis, das seine eigenen Anker nicht bestuecken kann, ist ein
    # Datenfehler und kein Balancing (siehe check_stock_builds).
    "jugg_body":   {"hp": 130, "def": 5, "spd": -2, "mov": -1, "weight_capacity": 31},
    "mage_body":   {"hp":  85, "def": 2, "spd":  0, "mov":  0, "weight_capacity": 20,
                    "en_max": 10},
    "strix_body":  {"hp":  70, "def": 2, "spd":  1, "mov":  0, "weight_capacity": 22},

    # --- KERN (core) -------------------------------------------------------
    # Energie und Ausstoss. Der Ausstoss deckelt, was drumherum haengen darf.
    "scout_core":  {"en_max": 40, "en_regen":  8, "power_output": 12, "weight": 3},
    "jugg_core":   {"en_max": 70, "en_regen": 12, "power_output": 16, "weight": 6},
    "mage_core":   {"en_max": 85, "en_regen": 14, "power_output": 14, "weight": 5},
    "strix_core":  {"en_max": 50, "en_regen": 10, "power_output": 13, "weight": 4,
                    "atk": 2},

    # --- ANTRIEB (feet) ----------------------------------------------------
    # Vier Antriebe, vier klar getrennte Traversierungsprofile. Die Zahlen sind
    # der Preis, die Flags sind der Grund. Lesart der Extreme:
    #
    #   Standbeine  langsam und stumpf, aber die schweren Fuesse greifen -- der
    #               einzige Antrieb im Bestand, der eine Oelspur als Deckungs-
    #               linie nutzen kann, statt darueber hinwegzuschlittern.
    #   Fahrwerk    der schnellste Antrieb, kommt aber weder ueber Stufen noch
    #               auf Drift zum Stehen: es hat nichts, womit es greifen kann.
    "scout_feet":  {"mov": 4, "spd": 11, "weight": 3, "power_draw": 4,
                    "can_pass_units": True, "can_enter_steps": True},
    "jugg_feet":   {"mov": 3, "spd":  8, "weight": 6, "power_draw": 2, "def": 2,
                    "ignores_drift": True},
    "mage_drive":  {"mov": 5, "spd": 14, "weight": 4, "power_draw": 4,
                    "drift_modifier": 1},
    "strix_feet":  {"mov": 4, "spd":  9, "weight": 5, "power_draw": 4,
                    "can_enter_steps": True, "step_cost_reduced": True},

    # --- SENSORIK (head) ---------------------------------------------------
    # Der Kopf ist der guenstige Slot fuer kleine Boni -- und der Ort, an dem
    # der Blick durch Haze-Felder sitzt. Haze ist damit kein absoluter Konter
    # gegen Fernkampf, sondern kostet einen Kopf mit schlechteren Werten.
    "scout_head":  {"spd": 2, "weight": 2, "power_draw": 2,
                    "grants_ignore_haze": True},
    "jugg_head":   {"hp": 15, "def": 2, "weight": 4, "power_draw": 1},
    "mage_head":   {"en_max": 15, "en_regen": 3, "weight": 2, "power_draw": 2},
    "strix_head":  {"atk": 4, "weight": 3, "power_draw": 3,
                    "grants_ignore_haze": True},

    # --- AUSRUESTUNG (equipment) -------------------------------------------
    "eq_pulse_blaster": {
        "weight": 5, "power_draw": 3,
        "action": {"id": "act_pulse", "display_name": "Puls-Salve",
                   "category": "attack", "targeting": "single",
                   "range_tiles": 4, "power": 12, "en_cost": 0,
                   "requires_line_of_sight": True},
    },
    # Passiv. Ein Schild ist kein Knopf, sondern eine Entscheidung beim Bauen.
    "eq_deflector": {"def": 5, "weight": 4, "power_draw": 2},

    "eq_siege_cannon": {
        "weight": 8, "power_draw": 5,
        "action": {"id": "act_siege", "display_name": "Belagerungsschlag",
                   "category": "attack", "targeting": "aoe_around_target",
                   "range_tiles": 6, "aoe_radius": 1, "power": 18, "en_cost": 5,
                   "requires_line_of_sight": True},
    },
    "eq_drone_pod": {
        "weight": 3, "power_draw": 4,
        "action": {"id": "act_dronepod", "display_name": "Reparaturdrohnen",
                   "category": "ability", "targeting": "aoe_around_target",
                   "range_tiles": 3, "aoe_radius": 1, "power": -10, "en_cost": 12,
                   "requires_line_of_sight": True, "aggro_coeff": 0.5},
    },
    # Reichweite 1 und damit ohne Sichtlinie: der Runenstab ist die einzige
    # Nahkampfwaffe im Bestand. Er ist der Grund, warum ein Haze-Feld ein
    # Korridor ist und keine Sackgasse -- wer darin steht, kann immer noch
    # zuschlagen, nur nicht mehr schiessen.
    # Das einzige Teil im Bestand mit aggro_bonus -- und das einzige, das
    # provozieren kann. Beides gehoert zusammen: wer Aufmerksamkeit auf sich
    # ziehen will, bezahlt dafuer einen Ausruestungsslot (GAME_DESIGN 6b).
    # Die Provokation ist harter Zwang und deshalb teuer und befristet.
    "eq_bait_beacon": {
        "weight": 3, "power_draw": 3, "aggro_bonus": 25,
        "action": {"id": "act_provoke", "display_name": "Stoersignal",
                   "category": "ability", "targeting": "single",
                   "range_tiles": 3, "power": 0, "en_cost": 14,
                   "requires_line_of_sight": True, "taunt_turns": 3},
    },

    "eq_rune_staff": {
        "weight": 4, "power_draw": 2,
        "action": {"id": "act_runestaff", "display_name": "Runenschlag",
                   "category": "attack", "targeting": "single",
                   "range_tiles": 1, "power": 18, "en_cost": 0,
                   "requires_line_of_sight": False},
    },
    "eq_orbit_focus": {
        "weight": 3, "power_draw": 3, "atk": 1,
        "action": {"id": "act_orbitpull", "display_name": "Orbit-Sog",
                   "category": "ability", "targeting": "single",
                   "range_tiles": 4, "power": 0, "en_cost": 8,
                   "push_tiles": -2, "requires_line_of_sight": True,
                   "aggro_flat": 8},
    },
    "eq_rail_lance": {
        "weight": 8, "power_draw": 5,
        "action": {"id": "act_raillance", "display_name": "Schienenschuss",
                   "category": "attack", "targeting": "single",
                   "range_tiles": 7, "power": 16, "en_cost": 6,
                   "requires_line_of_sight": True, "aggro_coeff": 0.35},
    },
}

ACTION_DEFAULTS = {
    "id": "", "display_name": "", "category": "attack", "targeting": "single",
    "range_tiles": 1, "aoe_radius": 0, "en_cost": 0, "power": 0,
    "requires_line_of_sight": False, "push_tiles": 0, "status_effect": None,
    "aggro_coeff": 1.0, "aggro_flat": 0, "taunt_turns": 0,
}


def part_stats(part_id: str) -> dict:
    """Vollstaendiger Statblock eines Teils: Defaults plus seine Abweichungen."""
    raw = STATS.get(part_id, {})
    unknown = set(raw) - set(STAT_DEFAULTS) - {"action"}
    if unknown:
        raise SystemExit(f"[stats] {part_id}: unbekannte Felder {sorted(unknown)}")

    stats = dict(STAT_DEFAULTS)
    stats.update({k: v for k, v in raw.items() if k != "action"})

    action = raw.get("action")
    if action is not None:
        unknown = set(action) - set(ACTION_DEFAULTS)
        if unknown:
            raise SystemExit(f"[stats] {part_id}: unbekannte Aktionsfelder {sorted(unknown)}")
        merged = dict(ACTION_DEFAULTS)
        merged.update(action)
        # Die Regel aus dem Entwurf, hier als Zusicherung statt als Kommentar.
        if merged["range_tiles"] > 1 and not merged["requires_line_of_sight"]:
            raise SystemExit(
                f"[stats] {part_id}: Reichweite {merged['range_tiles']} ohne "
                f"Sichtlinie -- ohne diese Regel ist das Terrain Dekoration"
            )
        stats["action"] = merged
    else:
        stats["action"] = None
    return stats


# ---------------------------------------------------------------------------
# Primitive: alles ist ein Quader oder eine Scheibe
# ---------------------------------------------------------------------------
def B(f, l, z, mat):
    """Quader aus (min, max)-Paaren in bot-lokalen Koordinaten."""
    return ("box", f, l, z, mat)


def D(f, l_center, z_center, radius, mat, segments=16):
    """Scheibe auf der nach vorn gerichteten Flaeche (Kern, Muendung, Linse)."""
    return ("disc", f, l_center, z_center, radius, mat, segments)


def L(center, profile, mat, axis="z", segments=14, caps=True):
    """
    Rotationskoerper -- alles Runde entsteht hier.

    ``profile`` ist ein Streckenzug aus (radius, achsposition)-Paaren, der um
    eine bot-lokale Achse gedreht wird. Damit fallen Zylinder, Kegel, Kuppeln,
    Raeder und Ringe aus einer einzigen Definition:

        [(9, 12), (9, 26)]                       Zylinder
        [(10.6, 50), (6.4, 57.5), (0, 58.6)]     Kuppel (Radius laeuft auf 0)
        [(6.2, 6), (7.4, 7.2), (6.2, 8.4), (6.2, 6)]   geschlossen -> Ring

    ``center`` sind die beiden Koordinaten quer zur Achse, in bot-lokaler
    Reihenfolge ohne die Achse selbst:

        axis="z"  center=(f, l)   Profil laeuft ueber die Hoehe   -> stehend
        axis="l"  center=(f, z)   Profil laeuft nach links        -> Rad
        axis="f"  center=(l, z)   Profil laeuft nach vorn         -> Ring/Orb

    Ein geschlossenes Profil (erster Punkt == letzter) ist ein Mantel ohne
    Deckel; ``caps=False`` unterdrueckt die Deckel auch bei offenen Profilen
    (Leuchtbaender, Rohre).
    """
    return ("lathe", tuple(center), tuple(profile), mat, axis, segments, caps)


# ---------------------------------------------------------------------------
# Lesbarkeitsregel: keine zwei Teile mit derselben Silhouette
# ---------------------------------------------------------------------------
# CyberDrome ist deterministisch. Wer eine DROME ansieht, muss ihre Funktion
# ablesen koennen -- Reichweite, Rolle, Gewicht. Das geht nur ueber die
# SILHOUETTE. Groesse taugt dafuer nicht: die Kachel ist klein, Teile
# ueberlappen, und ein Bot weiter hinten auf der Karte ist ohnehin kleiner.
# Eine Belagerungskanone, die nur ein grosser Blaster ist, ist deshalb kein
# Schoenheitsfehler, sondern ein Regelfehler.
#
# Der Test dazu: jedes Teil wird UNIFORM normiert (gemeinsamer Massstab ueber
# alle drei Achsen, um seinen eigenen Mittelpunkt) und in zwei Belegungsraster
# eingetragen -- Seitenriss (f, z) und Aufriss (l, z). Uniform, damit "gleiche
# Form, andere Groesse" identisch wird, "lang und duenn" gegen "kurz und dick"
# aber nicht. Verglichen wird ueber die Schnittmenge (IoU).
#
# Gemessen wird die GEFUELLTE UMRISSFLAECHE aus zwei Blickrichtungen -- mit
# derselben Projektion wie die Grafik. Zwei Richtungen, weil ein Teil aus einer
# einzigen Ansicht schmaler oder breiter wirken kann, als es ist.
#
# Was das Mass NICHT kann
# -----------------------
# Es sieht den Umriss, nicht die Formensprache -- und bei KOMPAKTEN Teilen
# sieht es praktisch gar nichts mehr. Normiert wird jedes gedrungene Volumen
# zu demselben Klumpen:
#
#   HED-002 Bunkerkopf   Quader        -> projiziert ein Sechseck, 64% Fuellung
#   HED-003 Flachhelm    Kuppel+Krempe -> projiziert eine Raute,   64% Fuellung
#
# Diese beiden kommen damit auf 0.88, obwohl sie einander nicht im
# Entferntesten aehnlich sehen. Fuer Rahmenteile gibt es deshalb KEINE Grenze,
# nur die Tabelle mit dem jeweils engsten Paar -- die Reihenfolge ist
# brauchbar, die absolute Zahl nicht.
#
# Bei Ausruestung ist der Abstand dagegen sauber zweigeteilt: der Pruefstein
# -- die alte, vom Blaster abgeschriebene Kanone -- liegt bei 0.91, das engste
# ehrliche Paar im Bestand bei 0.66. In diese Luecke passt eine harte Grenze,
# und nur deshalb gibt es dort ueberhaupt eine.
SIL_RES = 28
SIL_FACINGS = ("south", "east")
SIL_ERROR = 0.85      # NUR fuer Ausruestung -- Rahmenteile haben keine Grenze


def _shape_faces(shape):
    """Alle Flaechen eines Primitivs als (lokale Normale, Eckpunkte)."""
    kind = shape[0]
    if kind == "box":
        _, f, l, z, _mat = shape
        return _box_faces(f, l, z)
    if kind == "disc":
        _, f, l_center, z_center, radius, _mat, segments = shape
        return [((1, 0, 0), [
            (f, l_center + radius * math.cos(2 * math.pi * i / segments),
             z_center + radius * math.sin(2 * math.pi * i / segments))
            for i in range(segments)])]
    _, center, profile, _mat, axis, segments, caps = shape
    return _lathe_faces(center, profile, axis, segments, caps)


def _shape_polygons(shape, facing):
    """Alle Flaechen eines Primitivs als projizierte Bildschirm-Polygone."""
    # ALLE Flaechen, auch abgewandte: gesucht ist die gefuellte Umrissflaeche,
    # und dafuer ist die Rueckseite eines Koerpers deckungsgleich mit seiner
    # Vorderseite. Die Sichtbarkeitspruefung aus render() waere hier falsch --
    # sie wuerde Hohlraeume in die Silhouette schneiden, die keiner sieht.
    return [[project(point, facing) for point in points]
            for _normal, points in _shape_faces(shape)]


def _inside(polygon, x: float, y: float) -> bool:
    """Punkt-in-Polygon per Strahlenschnitt."""
    hit = False
    count = len(polygon)
    for index in range(count):
        x0, y0 = polygon[index]
        x1, y1 = polygon[(index + 1) % count]
        if (y0 > y) != (y1 > y):
            if x < x0 + (y - y0) / (y1 - y0) * (x1 - x0):
                hit = not hit
    return hit


def silhouette(shapes, facings=SIL_FACINGS) -> tuple:
    """
    Die gefuellte Umrissflaeche eines Teils, je Blickrichtung ein Raster.

    Projiziert wird mit derselben Kamera wie die Grafik -- gemessen wird also
    genau das, was der Spieler sieht, und nicht ein Ersatzmass aus
    Huellquadern. Ein Rotationskoerper ist dadurch rund und nicht eckig.

    Normiert wird UNIFORM: ein Massstab fuer beide Bildschirmachsen, um den
    eigenen Mittelpunkt. Dadurch wird "gleiche Form, andere Groesse" identisch,
    waehrend "lang und duenn" gegen "kurz und dick" verschieden bleibt.
    """
    grids = []
    for facing in facings:
        polygons = [poly for shape in shapes
                    for poly in _shape_polygons(shape, facing)]
        xs = [x for poly in polygons for x, _ in poly]
        ys = [y for poly in polygons for _, y in poly]
        span = max(max(xs) - min(xs), max(ys) - min(ys)) or 1.0
        cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2

        def to_cell(point):
            x, y = point
            return ((x - cx) / span * SIL_RES + SIL_RES / 2,
                    (y - cy) / span * SIL_RES + SIL_RES / 2)

        grid = set()
        for polygon in polygons:
            cells = [to_cell(point) for point in polygon]
            if len(cells) < 3:
                continue
            u0 = max(0, int(min(u for u, _ in cells)))
            u1 = min(SIL_RES, int(max(u for u, _ in cells)) + 1)
            v0 = max(0, int(min(v for _, v in cells)))
            v1 = min(SIL_RES, int(max(v for _, v in cells)) + 1)
            for u in range(u0, u1):
                for v in range(v0, v1):
                    if (u, v) not in grid and _inside(cells, u + 0.5, v + 0.5):
                        grid.add((u, v))
        grids.append(frozenset(grid))
    return tuple(grids)


def silhouette_distance(a, b) -> float:
    """Mittlere Deckungsgleichheit beider Risse -- 1.0 = ununterscheidbar."""
    scores = []
    for grid_a, grid_b in zip(a, b):
        union = len(grid_a | grid_b)
        scores.append(len(grid_a & grid_b) / union if union else 1.0)
    return sum(scores) / len(scores)


# ---------------------------------------------------------------------------
# Sitzregel: der Kern gehoert INS Chassis, nicht davor
# ---------------------------------------------------------------------------
# Ein Kern ist kein Anbauteil. Er sitzt in einem Schacht der Brustplatte (oder,
# wo der Rahmen es hergibt, der Rueckenplatte) und muss aussehen, als waere er
# mit dem Chassis verschmolzen.
#
# Das ist keine Geschmacksfrage, sondern faellt aus der Zeichenweise:
# der zusammengebaute Bot hat KEINEN Tiefenpuffer. Der Kern wird nach dem
# Koerper gezeichnet und deckt ihn an seiner Stelle vollstaendig ab -- steht er
# vor der Panzerung, liest sich das nicht als Tiefe, sondern als aufgeklebte
# Plakette. Und weil derselbe Kern auf jedes Chassis passen soll, kann ihm das
# Chassis diese Tiefe auch nicht nachtraeglich abnehmen.
#
# Gemessen wird deshalb in der Ebene der Sockelflaeche -- also von vorn auf die
# Brust geschaut, nicht mit der Iso-Kamera. Fuer jede Rasterzelle der
# (l, z)-Ebene, die der Kern belegt:
#
#   AUFBAU   vorderste Tiefe des Kerns minus vorderste Tiefe des Chassis
#            an derselben Stelle -- wie weit der Kern vorsteht
#   FREI     Anteil der Kernflaeche, hinter der ueberhaupt kein Chassis liegt.
#            Dort haengt der Kern buchstaeblich in der Luft; genau das war der
#            Fehler des alten Nimbus-Orbs und des alten Molok-Kreuzes.
#
# Die Richtung ergibt sich aus dem Anker: sitzt er vor der Mittelachse, zeigt
# der Sockel nach vorn, sonst nach hinten. Ein Kern am Ruecken ist damit
# ausdruecklich erlaubt -- er wird nur genauso streng gemessen.
SEAT_RES = 0.25        # Rasterweite der Sockelebene in Entwurfseinheiten
SEAT_MAX_PROUD = 1.0   # so weit darf ein Kern hoechstens vorstehen
SEAT_MAX_FREE = 0.02   # Toleranz fuer Randzellen des Rasters


def _raster(polygon, res: float):
    """Rasterzellen, deren Mittelpunkt im Polygon liegt."""
    if len(polygon) < 3:
        return
    u0 = math.floor(min(x for x, _ in polygon) / res)
    u1 = math.ceil(max(x for x, _ in polygon) / res)
    v0 = math.floor(min(y for _, y in polygon) / res)
    v1 = math.ceil(max(y for _, y in polygon) / res)
    for u in range(u0, u1 + 1):
        for v in range(v0, v1 + 1):
            if _inside(polygon, (u + 0.5) * res, (v + 0.5) * res):
                yield (u, v)


def _depth_map(shapes, sign: float, res: float = SEAT_RES) -> dict:
    """Vorderste Tiefe je Zelle der (l, z)-Ebene, entlang sign * f gemessen."""
    depth: dict = {}
    for shape in shapes:
        for _normal, points in _shape_faces(shape):
            front = max(sign * point[0] for point in points)
            for cell in _raster([(p[1], p[2]) for p in points], res):
                if front > depth.get(cell, -1e9):
                    depth[cell] = front
    return depth


def core_seat(core_shapes, body_shapes, anchor) -> tuple:
    """(Aufbau ueber der Panzerung, Anteil freihaengender Kernflaeche)."""
    sign = 1.0 if anchor[0] >= 0 else -1.0
    core = _depth_map(core_shapes, sign)
    if not core:
        return 0.0, 0.0
    body = _depth_map(body_shapes, sign)
    proud, free = 0.0, 0
    for cell, front in core.items():
        base = body.get(cell)
        if base is None:
            free += 1
        else:
            proud = max(proud, front - base)
    return proud, free / len(core)


# Basis je Achse: (Achsrichtung, u, v) in bot-lokalen Koordinaten (f, l, z).
_LATHE_AXES = {
    "z": ((0, 0, 1), (1, 0, 0), (0, 1, 0)),
    "l": ((0, 1, 0), (1, 0, 0), (0, 0, 1)),
    "f": ((1, 0, 0), (0, 1, 0), (0, 0, 1)),
}


def _lathe_faces(center, profile, axis, segments, caps):
    """Alle Flaechen eines Rotationskoerpers als (lokale Normale, Eckpunkte)."""
    a, u, v = _LATHE_AXES[axis]
    c0, c1 = center

    # Mittelpunkt in bot-lokalen Koordinaten: die beiden Nicht-Achsen-Werte
    # sitzen auf u und v.
    origin = tuple(c0 * u[i] + c1 * v[i] for i in range(3))

    def at(radius, along, angle):
        cos_a, sin_a = math.cos(angle), math.sin(angle)
        return tuple(origin[i] + along * a[i]
                     + radius * cos_a * u[i] + radius * sin_a * v[i]
                     for i in range(3))

    def normal(n_radial, n_along, angle):
        cos_a, sin_a = math.cos(angle), math.sin(angle)
        length = math.hypot(n_radial, n_along) or 1.0
        return tuple((n_along * a[i]
                      + n_radial * cos_a * u[i] + n_radial * sin_a * v[i]) / length
                     for i in range(3))

    angles = [2 * math.pi * i / segments for i in range(segments)]
    closed = profile[0] == profile[-1]
    faces = []

    for (r0, t0), (r1, t1) in zip(profile, profile[1:]):
        # Aussennormale des Profilabschnitts in der (radius, achse)-Ebene.
        n_radial, n_along = (t1 - t0), -(r1 - r0)
        for index, angle in enumerate(angles):
            nxt = angles[(index + 1) % segments]
            mid = angle + math.pi / segments
            quad = [p for p in (at(r0, t0, angle), at(r0, t0, nxt),
                                at(r1, t1, nxt), at(r1, t1, angle))]
            # Entartete Flaechen (Radius laeuft auf 0) faltet der Renderer
            # ohnehin zu einem Dreieck zusammen -- das ist gewollt.
            faces.append((normal(n_radial, n_along, mid), quad))

    if caps and not closed:
        for radius, along, sign in ((profile[-1][0], profile[-1][1], 1),
                                    (profile[0][0], profile[0][1], -1)):
            if radius <= 0:
                continue
            ring = [at(radius, along, angle) for angle in
                    (angles if sign > 0 else list(reversed(angles)))]
            faces.append((tuple(sign * a[i] for i in range(3)), ring))

    return faces


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

    Sichtbar ist eine Flaeche, wenn ihre Normale der Kamera entgegen zeigt.
    Fuer achsparallele Quader-Flaechen ist dieser Test gleichbedeutend mit
    "eine der drei Kamera-zugewandten Richtungen"; erst die vielen schraegen
    Facetten eines Rotationskoerpers brauchen ihn wirklich.
    """
    top, left, right, stroke = MATERIALS[mat]
    nx, ny, nz = world_normal
    if nx * VIEW[0] + ny * VIEW[1] + nz * VIEW[2] <= 1e-9:
        return None, stroke   # abgewandt
    if nz > 0.5:
        return top, stroke
    # Auf dem Bildschirm zeigt -px nach unten-links, -py nach unten-rechts.
    # Welche der beiden Flanken es ist, entscheidet die staerkere Komponente.
    return (left if nx <= ny else right), stroke


def _emit(points_local, world_normal, mat, facing, seam=False):
    """
    Eine Flaeche -> (Tiefe, SVG-Pfad). ``None``, wenn sie abgewandt ist.

    ``seam=True`` zieht die Kontur eines Facets in seiner EIGENEN Farbe statt
    in der Outline-Farbe. Das ist der Unterschied zwischen einem runden Koerper
    und einem Drahtgitter: ein Rotationskoerper besteht aus vielen kleinen
    Facetten, deren gemeinsame Kanten keine Kanten des Objekts sind. Der
    Eigenfarb-Strich deckt zugleich die Antialiasing-Fugen zwischen ihnen ab.
    """
    color, stroke = _shade(world_normal, mat)
    if color is None:
        return None
    world_points = [to_world(p, facing) for p in points_local]
    depth = sum(closeness(w) for w in world_points) / len(world_points)
    coords = " L".join(f"{x} {y}" for x, y in (to_screen(w) for w in world_points))
    if seam:
        extra = f' stroke="{color}" stroke-width="0.4"'
    else:
        extra = "" if stroke else ' stroke="none"'
    return (depth, f'  <path d="M{coords} Z" fill="{color}"{extra}/>')


def _convex_hull(points):
    """Monotone chain -- fuer die Silhouette eines Rotationskoerpers."""
    points = sorted(set(points))
    if len(points) < 3:
        return points

    def half(seq):
        out = []
        for p in seq:
            while len(out) >= 2:
                (ax, ay), (bx, by) = out[-2], out[-1]
                if (bx - ax) * (p[1] - ay) - (by - ay) * (p[0] - ax) > 0:
                    break
                out.pop()
            out.append(p)
        return out[:-1]

    return half(points) + half(list(reversed(points)))


def _silhouette(all_points, facing, mat):
    """
    Aussenkontur eines Rotationskoerpers, damit er zum Strichbild der
    Quader-Teile passt.

    Die konvexe Huelle der projizierten Punkte ist fuer konvexe Profile
    (Zylinder, Kegel, Kuppel, Orb) exakt die Silhouette. Gezeichnet wird sie
    HINTER den eigenen Flaechen -- sichtbar bleibt dadurch genau die aeussere
    Haelfte des Strichs, also dasselbe Bild wie bei einem Quader.
    """
    if not MATERIALS[mat][3]:
        return None          # Leuchtmaterial traegt auch sonst keine Kontur
    hull = _convex_hull([to_screen(w) for w in all_points])
    if len(hull) < 3:
        return None
    coords = " L".join(f"{x} {y}" for x, y in hull)
    return f'  <path d="M{coords} Z" fill="none"/>'


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
        elif shape[0] == "lathe":
            _, center, profile, mat, axis, segments, caps = shape
            shell = _lathe_faces(center, profile, axis, segments, caps)
            visible = []
            for local_normal, points in shell:
                wn = to_world(local_normal, facing)
                emitted = _emit(points, wn, mat, facing, seam=True)
                if emitted:
                    visible.append(emitted)
            if visible:
                world_points = [to_world(p, facing)
                                for _, quad in shell for p in quad]
                outline = _silhouette(world_points, facing, mat)
                if outline:
                    # knapp hinter die eigenen Flaechen
                    visible.append((min(d for d, _ in visible) - 0.01, outline))
            faces.extend(visible)
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
    # Brustpanel, Kernsockel, Neon -- erhaben auf der Frontflaeche.
    # Der Sockel ist groesser als der Kern, der spaeter hineingeht: er muss ihn
    # bis in die aeussersten Energiestreifen tragen, sonst haengt der Kern an
    # seinem Rand ueber der Kante.
    B((8, 8.6), (-7, 7), (43, 58), "dark"),
    B((8.6, 9.1), (-6, 6), (55.4, 57.4), "accent"),
    B((8.6, 9.2), (-6.5, 6.5), (43.4, 54.6), "dark"),
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

# Impulskern: eine Scheibe, buendig im Kernsockel der Brustplatte (Front 9.2).
# Scheiben haben keine Tiefe -- deshalb bleibt hier nur zu pruefen, dass die
# vier Energiestreifen nicht ueber den Sockel hinausragen.
SCOUT_CORE = [
    D(9.3, 0, 49, 4.4, "dark"),
    D(9.45, 0, 49, 2.6, "glow"),
    B((9.45, 9.6), (-0.5, 0.5), (52.6, 54.0), "accent"),
    B((9.45, 9.6), (-0.5, 0.5), (44.0, 45.4), "accent"),
    B((9.45, 9.6), (-5.9, -4.7), (48.5, 49.5), "accent"),
    B((9.45, 9.6), (4.7, 5.9), (48.5, 49.5), "accent"),
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

# Pruefstein, kein Teil.
#
# So sah die Belagerungskanone aus, bevor es die Lesbarkeitsregel gab: exakt
# der Aufbau des Blasters -- Stumpf am Anker, Gehaeuse, Lauf nach vorn,
# Muendungsblock, Glut, zwei Neonstreifen --, nur mit groesseren Zahlen. Genau
# der Fall, den die Regel verbietet.
#
# Die Form bleibt im Repo, damit check_silhouettes() an ihr nachweisen kann,
# dass es sie noch findet. Ein Test, der nichts mehr faengt, faellt sonst nicht
# auf -- er meldet einfach weiter "alles in Ordnung".
EQ_CANNON_V1 = [
    B((-4, 4), (-5.5, 5.5), (42, 51), "metal"),
    B((-6, 7), (-7, 7), (28, 43), "plate"),
    B((7, 18), (-5, 5), (31, 39), "plate"),
    B((18, 21), (-4, 4), (32, 38), "dark"),
    D(21.3, 0, 35, 2.5, "glow"),
    B((-5, 6), (7, 7.6), (39.5, 41.5), "accent"),
    B((-5, 6), (-7.6, -7), (39.5, 41.5), "accent"),
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

# Molok-Chassis -- ausdruecklich KEIN breiterer Vireo.
#
# Der Vireo ist ein gerader Kistenstapel mit Hals, flachen Schulterplatten
# darunter und offener Huefte. Wer daraus nur breitere Kisten macht, bekommt
# genau denselben Umriss in gross -- derselbe Fehler wie beim Blaster, nur eine
# Ebene hoeher. Drei Merkmale drehen die Umrisslinie stattdessen um:
#
#   * eine PANZERSCHUERZE, die ueber die Oberschenkel haengt und die
#     Silhouette nach unten schliesst -- beim Sprinter klafft dort eine Luecke;
#   * ein Torso als KEIL, unten schmal, oben breit, statt eines geraden Stapels;
#   * PAULDRONS, die HOEHER sitzen als der Kopfsockel, dazu zwei stehende
#     Auspuffstapel dahinter. Der Rahmen wirkt dadurch geduckt und hat keinen
#     sichtbaren Hals -- die Vireo-Silhouette hat beides umgekehrt.
JUGG_BODY = [
    # -- Huefte mit Panzerschuerze ----------------------------------------
    B((-7, 7), (-11, 11), (31, 38), "metal"),
    B((-6.5, 7), (11, 15), (26, 39), "plate"),
    B((-6.5, 7), (-15, -11), (26, 39), "plate"),
    B((7, 9.5), (-8.5, 8.5), (25, 37), "plate"),
    B((9.5, 10.1), (-5, 5), (28, 30), "accent"),
    B((-7.5, -7), (-9, 9), (27, 37), "dark"),
    # -- Torso als Keil: unten schmal, oben breit -------------------------
    B((-7, 8), (-10, 10), (38, 46), "plate"),
    B((-8, 9.5), (-13, 13), (46, 55), "plate"),
    B((-8.5, 10), (-15, 15), (55, 61), "plate"),
    # Das Deck ist SCHMALER als der Torso darunter. Der Molok hat keinen Hals
    # -- aber ohne irgendeine Luecke verschwindet der Kopf zwischen den
    # Pauldrons. Statt eines Halses macht hier die Einkerbung zwischen Deck
    # und Pauldron den Kopf als eigenes Volumen lesbar.
    B((-7.5, 9), (-11.5, 11.5), (61, 64), "light"),
    # Brustpanzer mit Kernsockel. Der Sockel sitzt auf Brustmitte und ist hoch
    # genug fuer das ganze Fusionskreuz -- der alte reichte nur bis z=54, und
    # das Kreuz hing unten ueber die Kante hinaus ins Leere.
    B((10, 10.8), (-11, 11), (46, 59), "dark"),
    B((10.8, 11.4), (-8, 8), (56.8, 58.4), "accent"),
    B((10.8, 11.5), (-7, 7), (46.6, 56.2), "dark"),
    # -- Auspuffstapel: zwei stehende Rohre ueber Schulterhoehe ------------
    L((-9.5, 10.5), [(2.6, 55), (2.6, 72), (3.3, 72), (3.3, 74)], "metal", segments=12),
    L((-9.5, -10.5), [(2.6, 55), (2.6, 72), (3.3, 72), (3.3, 74)], "metal", segments=12),
    L((-9.5, 10.5), [(3.4, 64), (3.4, 65.5)], "accent", caps=False, segments=12),
    L((-9.5, -10.5), [(3.4, 64), (3.4, 65.5)], "accent", caps=False, segments=12),
    # -- Pauldrons: sitzen HOCH und flankieren den Kopf --------------------
    B((-8, 8), (15, 26), (52, 66), "plate"),
    B((-8.5, 8.5), (14.5, 26.5), (66, 69), "light"),
    B((-8, 8), (-26, -15), (52, 66), "plate"),
    B((-8.5, 8.5), (-26.5, -14.5), (66, 69), "light"),
    B((8, 8.6), (17.5, 23.5), (59, 62), "accent"),
    B((8, 8.6), (-23.5, -17.5), (59, 62), "accent"),
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

# Standbeine, nicht "Sprintbeine in gross".
#
# Die Vireo-Beine und diese hier haben unterschiedliche Spielwerte -- also
# muessen sie unterschiedlich AUSSEHEN, und zwar an der Silhouette, nicht an
# der Groesse. Drei Merkmale tragen das: der weit nach aussen versetzte Stand
# auf Hueftauslegern, die stehenden Hydraulikzylinder vor dem Oberschenkel
# (Rotationskoerper -- am Sprintbein gibt es keinen) und der Standfuss, der
# nach vorn UND nach hinten greift. Das Sprintbein hat eine Zehe, dieses hier
# eine Ferse: daran liest man ab, dass es Rueckstoss abstuetzt statt zu rennen.
JUGG_FEET = [
    # Hueftausleger -- der breite Stand faengt schon an der Huefte an
    B((-4.5, 4.5), (5, 16), (29, 34), "metal"),
    B((-4.5, 4.5), (-16, -5), (29, 34), "metal"),
    B((-5, 5), (9, 16.5), (30.5, 32.5), "accent"),
    B((-5, 5), (-16.5, -9), (30.5, 32.5), "accent"),
    # Oberschenkel: kurz und dick
    B((-5.5, 5.5), (9, 16), (19, 30), "plate"),
    B((-5.5, 5.5), (-16, -9), (19, 30), "plate"),
    # Hydraulikzylinder vor dem Oberschenkel
    L((7, 12.5), [(2.4, 18), (2.4, 29)], "dark", segments=12),
    L((7, -12.5), [(2.4, 18), (2.4, 29)], "dark", segments=12),
    L((7, 12.5), [(3.0, 26.5), (3.0, 28)], "accent", caps=False, segments=12),
    L((7, -12.5), [(3.0, 26.5), (3.0, 28)], "accent", caps=False, segments=12),
    # Kniepanzer, kragt nach aussen aus
    B((-6.5, 6.5), (8, 17.5), (14, 19), "plate"),
    B((-6.5, 6.5), (-17.5, -8), (14, 19), "plate"),
    B((-7, 7), (7.5, 18), (19, 20.5), "light"),
    B((-7, 7), (-18, -7.5), (19, 20.5), "light"),
    # Unterschenkel: staemmig, kaum laenger als der Knie-Block hoch ist
    B((-5.5, 5.5), (9.5, 16), (6, 14), "metal"),
    B((-5.5, 5.5), (-16, -9.5), (6, 14), "metal"),
    # Standfuss mit Ferse
    B((-11, 12), (8, 17), (0, 6), "plate"),
    B((-11, 12), (-17, -8), (0, 6), "plate"),
    B((-11.5, 12.5), (7.5, 17.5), (6, 7.5), "light"),
    B((-11.5, 12.5), (-17.5, -7.5), (6, 7.5), "light"),
    # Krallen vorn, Sporn hinten
    B((12, 15), (9, 11.5), (0, 2.5), "dark"),
    B((12, 15), (13.5, 16), (0, 2.5), "dark"),
    B((12, 15), (-11.5, -9), (0, 2.5), "dark"),
    B((12, 15), (-16, -13.5), (0, 2.5), "dark"),
    B((-14, -11), (10.5, 14.5), (0, 3), "dark"),
    B((-14, -11), (-14.5, -10.5), (0, 3), "dark"),
]

# Fusionskreuz auf einer Sockelscheibe -- beides bleibt innerhalb des
# Kernsockels der Brustplatte (Front 11.5), das Kreuz kommt gerade so weit
# heraus, dass es leuchtet und nicht absteht.
JUGG_CORE = [
    # Sechseck statt Kreis: der Molok bekommt eine geschraubte Industrieplatte.
    # Zwei runde Kerne (Vireo, Nimbus) sind genug -- ab dem dritten faengt der
    # Silhouetten-Test an, sie miteinander zu verwechseln.
    D(11.2, 0, 51.4, 4.7, "dark", 6),
    B((11.5, 11.8), (-3.4, 3.4), (49.8, 53.0), "glow"),
    B((11.5, 11.8), (-1.9, 1.9), (47.6, 55.2), "glow"),
]

# Belagerungskanone -- ausdruecklich KEIN vergroesserter Blaster.
#
# Der Blaster ist ein Rohr am Arm: schmal, glatt, ein Lauf. Diese hier bekommt
# drei Merkmale, die kein Handrohr je hat, und jedes davon liegt auf der
# Silhouette statt in der Flaeche:
#
#   * eine MUENDUNGSBREMSE mit zwei Fluegeln quer zum Rohr -- sie gibt der
#     Waffe vorn eine Breite, die man auch bei halber Groesse noch erkennt;
#   * ein liegendes TROMMELMAGAZIN hinter dem Verschluss, das nach hinten
#     ueber den Bot hinausragt;
#   * eine ABSTUETZSTREBE nach unten -- das Bauteil sagt "wird abgestuetzt",
#     also "schwer, kurze Reichweite pro Zug".
#
# Der Lauf ist dabei bewusst KUERZER im Verhaeltnis zur Masse als beim
# Blaster: gedrungen liest sich als Artillerie, lang und duenn als Praezision
# (siehe eq_rail_lance).
EQ_CANNON = [
    # Halterung am Anker: kurzer Stumpf, kein ausmodellierter Arm
    B((-3.5, 3.5), (-5, 5), (45, 53), "metal"),
    # Verschlussblock -- die Masse sitzt hinten
    B((-8, 5), (-7.5, 7.5), (34, 45.5), "plate"),
    B((-8.5, 5.5), (-8, 8), (45.5, 47.5), "light"),
    B((5, 5.6), (-5.5, 5.5), (37, 43), "dark"),
    # Trommelmagazin, liegend quer zum Bot und weit hinten
    L((-10.5, 40), [(4.4, -7), (4.8, -6), (4.8, 6), (4.4, 7)],
      "dark", axis="l", segments=14),
    L((-10.5, 40), [(5.1, -3), (5.1, -2)], "accent", axis="l",
      caps=False, segments=14),
    L((-10.5, 40), [(5.1, 2), (5.1, 3)], "accent", axis="l",
      caps=False, segments=14),
    # Rohr: Ruecklaufhuelse, dann ein deutlich duenneres Stueck. Die
    # Verjuengung ist noetig, damit die Muendungsbremse davor ueberhaupt als
    # eigene Form lesbar wird -- an einem durchgehend dicken Rohr verschwindet
    # sie in der Silhouette.
    B((5.6, 11), (-4.6, 4.6), (36.5, 43.5), "plate"),
    B((11, 20), (-2.8, 2.8), (37.6, 42.4), "dark"),
    # Muendungsbremse: DAS Silhouetten-Merkmal. Die Fluegel liegen flach und
    # greifen tief nach vorn, damit sie als quer stehende Finnen lesen und
    # nicht als angeklebte Blechlaschen.
    B((20, 24), (-3.6, 3.6), (36.8, 43.2), "plate"),
    B((18.8, 24.5), (-9.5, -3.6), (38.6, 41.4), "dark"),
    B((18.8, 24.5), (3.6, 9.5), (38.6, 41.4), "dark"),
    B((24, 24.6), (-3, 3), (37.5, 42.5), "accent"),
    D(24.9, 0, 40, 2.2, "glow"),
    # Abstuetzstrebe nach unten
    B((-1, 3), (-2.6, 2.6), (26, 34), "metal"),
    B((-4, 6), (-4, 4), (23, 26.5), "dark"),
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

# Koedersender -- laut, aber ausdruecklich KEINE Waffe.
#
# Das Modul ist der einzige Weg im Bestand, Aufmerksamkeit zu erzeugen, ohne
# dafuer zu handeln (GAME_DESIGN 6b), und der einzige, der provozieren kann.
# Genau das muss die Silhouette sagen -- und zwar OHNE die Formensprache einer
# Waffe zu benutzen:
#
#   * kein Rohr, keine Muendung, nichts, was nach vorn zeigt. Jede Waffe im
#     Bestand greift nach vorn; dieses Teil tut es an keiner Stelle.
#   * ein duenner MAST nach oben, der ueber den Kopf hinausreicht -- die
#     einzige Ausruestung, die das tut;
#   * drei KREUZE aus flachen Streben am Mast, nach oben kuerzer werdend --
#     Sendeantennen, keine Laeufe, und mit deutlichem Abstand voneinander;
#   * ein GEGENGEWICHT nach hinten-unten: das Teil ist kopflastig, und man
#     sieht ihm an, dass es getragen und nicht gehalten wird.
#
# Der Runenstab ist der Nachbar, gegen den sich das abgrenzen muss -- auch er
# laeuft senkrecht nach oben. Er ist aber ein Stab AM ARM mit einer Glut obenauf
# (Rotationskoerper, rund, durchgehend schlank); der Sender hat keinen Arm,
# dafuer die Kreuztreppe und das Gewicht hinten.
#
# Zwei verworfene Anlaeufe, beide lehrreich genug, um sie aufzuschreiben:
#
# 1. Die Kreuze waren zuerst waagerechte SCHEIBEN. Ein waagerechter Kreis mit
#    Radius r projiziert unter dieser Kamera aber immer zur Ellipse mit der
#    Halbhoehe 0.5*r*SCALE -- er liest sich als praller Koerper, nie als
#    duenner Schirm. Gekreuzte Streben behalten ihre Duenne, weil zwischen
#    den Armen der Hintergrund steht.
# 2. Die Abstaende waren zu klein. Zwei waagerechte Formen trennen sich auf
#    dem Bildschirm nur um dz*COS45*SCALE, brauchen also
#
#        dz  >  0.71 * (r1 + r2)
#
#    um sich nicht zu ueberlappen. Mit dz = 4 und Radien um 8 verschmolzen die
#    drei zu einem Kegel -- das Teil sah aus wie eine Laterne.
#
# Beides hat der Silhouetten-Test NICHT gefangen, und das ist kein Mangel: er
# misst den Umriss, und eine Laterne ist ein ebenso einmaliger Umriss wie eine
# Antenne. Er haette also zu Recht bestanden. Genau der Fall, fuer den in
# GAME_DESIGN 3d steht, dass der Test das Hinsehen nicht ersetzt -- er faengt
# "abgeschrieben und groesser gezogen", nicht "sagt die falsche Funktion".
EQ_BAIT_BEACON = [
    # Halterung am Anker -- derselbe kurze Stumpf wie bei Blaster und Schild.
    B((-3, 3), (-4, 4), (46, 54), "metal"),
    # Gegengewicht nach hinten-unten: das Modul ist kopflastig, und man sieht
    # ihm an, dass es getragen und nicht gehalten wird.
    B((-10, -2.5), (-5.5, 5.5), (38.5, 46.5), "plate"),
    B((-10.5, -3), (-6, 6), (46.5, 48), "light"),
    B((-10.8, -10.2), (-3.5, 3.5), (40, 45), "accent"),
    # Mast -- laeuft ueber jede Kopfhoehe im Bestand hinaus (61 bis 72).
    L((0, 0), [(1.5, 50), (1.5, 80)], "metal", segments=10),
    # Drei KREUZE aus flachen Streben statt Scheiben. Ein waagerechter Kreis
    # projiziert unter dieser Kamera immer zur 2:1-Ellipse und liest sich als
    # praller Koerper, nie als duenner Schirm -- drei davon uebereinander
    # ergaben eine Pagode. Gekreuzte Streben behalten dagegen ihre Duenne,
    # weil zwischen den Armen der Hintergrund steht.
    B((-7.6, 7.6), (-1.1, 1.1), (56.5, 57.4), "plate"),
    B((-1.1, 1.1), (-7.6, 7.6), (56.5, 57.4), "plate"),
    B((-6.8, 6.8), (-0.5, 0.5), (57.4, 57.7), "accent"),
    B((-0.5, 0.5), (-6.8, 6.8), (57.4, 57.7), "accent"),
    B((-5.6, 5.6), (-1.0, 1.0), (67.0, 67.9), "plate"),
    B((-1.0, 1.0), (-5.6, 5.6), (67.0, 67.9), "plate"),
    B((-4.9, 4.9), (-0.5, 0.5), (67.9, 68.2), "accent"),
    B((-0.5, 0.5), (-4.9, 4.9), (67.9, 68.2), "accent"),
    B((-3.6, 3.6), (-0.9, 0.9), (76.0, 76.9), "plate"),
    B((-0.9, 0.9), (-3.6, 3.6), (76.0, 76.9), "plate"),
    # Signalspitze auf dem Mast, nicht auf dem obersten Schirm
    L((0, 0), [(0, 83.4), (1.9, 81.4), (1.9, 79.8), (0, 79.2)], "glow", segments=12),
]


# ===========================================================================
# AR-Nimbus // Technomant  (parts/bot3) -- Rundungen statt Kanten
#
# Der Gegenentwurf zu den ersten beiden Sets: die dort gestapelten Quader
# weichen Rotationskoerpern (siehe L()). Kuppeln, Orbs und Ringe geben die
# weiche, magier-hafte Silhouette; das Cyber-Setting bleibt ueber Neonbaender
# und Sensorik erhalten.
#
# Statt Beinen ein FAHRGESTELL: zwei grosse Raeder auf einer Achse quer zum
# Bot, dazu eine Stuetzrolle vorn. Ein Rad ist dabei nichts weiter als ein
# Rotationskoerper um die Bot-Links-Achse -- die Beleuchtung faellt aus der
# Projektion ab wie bei jedem anderen Teil.
#
# Hoehenprofil in Entwurfseinheiten:
#   Raeder 0..19   Wanne 11..27   Torso 27..53   Schulterkuppel 53..59
#   Hals 58..61    Flachhelm 61..72
# ===========================================================================

MAGE_BODY = [
    # -- Huefte: gerundeter Sockel auf dem Fahrgestell --------------------
    L((0, 0), [(7.0, 27), (8.6, 31), (8.8, 35)], "metal", segments=16),
    # -- Torso: EINE durchgehende Rundung statt gestapelter Kisten --------
    L((0, 0), [(8.6, 35), (10.0, 42), (10.2, 49), (9.4, 53)], "plate"),
    # Schulterkuppel laeuft auf Radius 0 aus -- daher die weiche Silhouette.
    L((0, 0), [(9.4, 53), (8.2, 56.2), (5.2, 58.4), (0, 59.2)], "light"),
    # Umlaufendes Neonband: bei einem Rotationskoerper die natuerliche Zier,
    # weil es in jeder Blickrichtung gleich gut sitzt.
    L((0, 0), [(10.4, 45.0), (10.4, 46.2)], "accent", caps=False, segments=18),
    # -- Kernflansch vorn --------------------------------------------------
    # Ein RUNDER Torso kann keinen flachen Kern tragen: zur Seite hin faellt
    # er weg, und der Kern haengt an seinem Rand in der Luft. Der Flansch ist
    # deshalb ein nach vorn liegender Zylinder mit ebener Stirn -- die Flaeche,
    # in die der Arkankern hineingeht.
    L((0, 44), [(5.0, 6.0), (5.0, 11.4)], "dark", axis="f", segments=16),
    L((0, 44), [(5.3, 10.3), (5.3, 10.9)], "light", axis="f", caps=False, segments=16),
    # -- Rueckenmodul: Reaktorwulst mit Kuehlringen -----------------------
    L((-7.2, 0), [(4.4, 40), (5.0, 46), (4.2, 52)], "dark", segments=12),
    L((-7.2, 0), [(5.3, 42.0), (5.3, 42.8)], "light", caps=False, segments=12),
    L((-7.2, 0), [(5.3, 45.2), (5.3, 46.0)], "light", caps=False, segments=12),
    L((-7.2, 0), [(5.3, 48.4), (5.3, 49.2)], "light", caps=False, segments=12),
    # -- Schulterorbs: die Rundung, die den Magier ausmacht ---------------
    L((0, 13.8), [(0, 44.6), (3.6, 46.3), (5.0, 49.6), (3.6, 52.9), (0, 54.6)], "plate"),
    L((0, -13.8), [(0, 44.6), (3.6, 46.3), (5.0, 49.6), (3.6, 52.9), (0, 54.6)], "plate"),
    L((0, 13.8), [(5.3, 49.2), (5.3, 50.0)], "accent", caps=False, segments=16),
    L((0, -13.8), [(5.3, 49.2), (5.3, 50.0)], "accent", caps=False, segments=16),
    # -- Hals: die Luecke, die den Helm lesbar macht ----------------------
    L((0, 0), [(3.6, 58.2), (3.8, 61)], "metal", segments=12),
]

# Flacher Helm.
#
# Eine breit auskragende Krempe verdeckt bei einer 45-Grad-Kamera zwangslaeufig
# alles darunter -- ein Visierschlitz an der Front waere schlicht nie zu sehen.
# Das Sensorband sitzt deshalb auf der SENKRECHTEN AUSSENKANTE der Krempe: die
# liegt in jeder Blickrichtung auf der Silhouette. Die Kuppel darueber ist
# flacher als ihr Radius breit ist, und genau diese waagerechte Flaeche zeigt
# die Kamera voll -- daraus liest sich "flach".
MAGE_HEAD = [
    L((0, 0), [(4.6, 61.0), (5.4, 62.6)], "metal", segments=12),   # Halsansatz
    L((0, 0), [(7.8, 62.6), (8.6, 66.0)], "dark", segments=16),    # Kapuze
    L((0, 0), [(8.6, 66.0), (9.4, 67.2)], "plate", segments=16),
    L((0, 0), [(9.4, 67.2), (10.6, 67.7)], "light", segments=20),  # Krempe unten
    L((0, 0), [(10.6, 67.7), (10.6, 69.0)], "visor", caps=False, segments=20),
    L((0, 0), [(10.6, 69.0), (9.4, 69.6)], "light", segments=20),  # Krempe oben
    L((0, 0), [(9.4, 69.6), (7.8, 71.0), (4.4, 72.3), (0, 72.7)], "plate"),
    L((0, 0), [(3.8, 72.2), (3.8, 72.9)], "accent", caps=False, segments=14),
]

# Fahrbarer Untersatz statt Beinen.
MAGE_DRIVE = [
    # Wanne, unten gerundet
    L((0, 0), [(5.6, 11.5), (8.8, 15), (9.4, 21), (7.8, 27)], "plate"),
    L((0, 0), [(9.5, 17.0), (9.5, 18.0)], "accent", caps=False, segments=18),
    B((-2.2, 2.2), (-14.2, 14.2), (8.6, 10.6), "metal"),          # Achse
    # Raeder: Rotationskoerper um die Bot-Links-Achse -- mehr braucht ein Rad
    # in dieser Projektion nicht.
    L((0, 9.8), [(9.8, 10.8), (9.8, 14.2)], "dark", axis="l", segments=18),
    L((0, 9.8), [(9.8, -14.2), (9.8, -10.8)], "dark", axis="l", segments=18),
    L((0, 9.8), [(5.8, 14.2), (5.8, 14.9)], "metal", axis="l", segments=16),
    L((0, 9.8), [(5.8, -14.9), (5.8, -14.2)], "metal", axis="l", segments=16),
    L((0, 9.8), [(2.4, 14.9), (2.4, 15.6)], "accent", axis="l", segments=12),
    L((0, 9.8), [(2.4, -15.6), (2.4, -14.9)], "accent", axis="l", segments=12),
    # Ausleger + Stuetzrolle vorn -- sonst stuende der Bot auf der Nase.
    B((4.0, 11.0), (-2.0, 2.0), (7.2, 9.6), "metal"),
    L((11.0, 4.6), [(4.4, -2.2), (4.4, 2.2)], "dark", axis="l", segments=14),
    L((11.0, 4.6), [(1.8, 2.2), (1.8, 2.8)], "glow", axis="l", segments=10),
]

# Arkankern: eine Linse in der Stirn des Kernflansches (Front 12.2), kein
# freischwebender Orb mehr. Der alte stand fast fuenf Einheiten vor dem Torso
# und hing seitlich ueber dessen Rundung hinaus -- aus West und Nord blieben
# davon zwei Ringe in der Luft uebrig.
MAGE_CORE = [
    D(11.5, 0, 44, 4.4, "dark"),
    D(11.75, 0, 44, 2.9, "glow"),
    L((0, 44), [(4.6, 11.5), (4.6, 11.9)], "accent", axis="f", caps=False, segments=20),
    L((0, 44), [(3.3, 11.6), (3.3, 11.9)], "accent", axis="f", caps=False, segments=20),
]

EQ_RUNE_STAFF = [
    L((0, 0), [(3.4, 41), (3.8, 47), (3.4, 50)], "metal", segments=12),   # Oberarm
    L((1.0, 0), [(3.0, 31), (3.6, 40)], "plate", segments=12),            # Unterarm
    L((1.0, 0), [(4.2, 29), (4.2, 31.6)], "dark", segments=12),           # Faust
    # Der Stab laeuft VOR dem Arm nach oben. Nach vorn gerichtet wuerde er in
    # der Iso-Ansicht mit Torso und Fahrgestell verschmelzen.
    L((7.6, 0), [(1.1, 22), (1.1, 55)], "metal", segments=10),
    L((7.6, 0), [(2.3, 33), (2.3, 34.4)], "accent", caps=False, segments=10),
    L((7.6, 0), [(2.9, 54), (3.6, 56.2), (2.9, 58.4)], "plate", segments=12),
    L((7.6, 0), [(0, 58.6), (2.2, 59.6), (3.0, 61.0), (2.2, 62.4), (0, 63.4)], "glow"),
    L((7.6, 0), [(4.4, 60.4), (4.4, 61.6)], "accent", caps=False, segments=18),
]

EQ_ORBIT_FOCUS = [
    L((0, 0), [(3.4, 41), (3.8, 47), (3.4, 50)], "metal", segments=12),
    L((1.2, 0), [(3.2, 33), (3.8, 40)], "plate", segments=12),
    L((1.2, 0), [(4.6, 30), (5.0, 32), (4.4, 33.6)], "dark", segments=12),
    # Schwebender Fokusring vor der Hand. Geschlossenes Profil (erster Punkt
    # == letzter) -> Mantel ohne Deckel, also ein echter Ring mit Loch.
    L((0, 30.5), [(6.4, 6.5), (7.6, 7.6), (6.4, 8.7), (6.4, 6.5)],
      "accent", axis="f", segments=18),
    L((0, 30.5), [(0, 6.4), (1.9, 6.9), (2.6, 7.6), (1.9, 8.3), (0, 8.8)],
      "glow", axis="f", segments=12),
]


# ===========================================================================
# LR-Strix // Marksman  (parts/bot4) -- EIN Ausruestungsanker
#
# Der Gegenentwurf zum Juggernaut auf der Slot-Seite. Molok kauft sich seine
# drei Slots mit Masse und Langsamkeit; Strix macht das Gegenteil und hat
# genau EINEN -- zentral auf der Mittelachse, dafuer voll belastbar. Das ist
# eine Balancing-Achse, die ohne eine einzige Zahl auskommt: eine Waffe, dafuer
# die schwerste im Spiel.
#
# Damit man das ansieht, traegt der Rahmen kein Armpaar, sondern ein JOCH vor
# der Brust, und dahinter einen Gegengewichts-Ausleger, der nach hinten-oben
# ueber den Kopf hinauslaeuft. Beides liegt auf der Silhouette -- man erkennt
# einen Strix an der schraegen Rueckenlinie, bevor man die Waffe sieht.
#
# Hoehenprofil in Entwurfseinheiten:
#   Beine 0..34   Torso 34..60   Joch 48..57   Ausleger 46..70   Kopf 63..78
# ===========================================================================

STRIX_BODY = [
    # -- Huefte -----------------------------------------------------------
    B((-5, 5), (-7, 7), (34, 40), "metal"),
    # -- Torso: schmal und hoch. Breite gehoert dem Juggernaut. ------------
    B((-5.5, 6), (-7.5, 7.5), (40, 58), "plate"),
    B((-6, 6.5), (-8, 8), (58, 60.5), "light"),
    B((6, 6.6), (-5.5, 5.5), (43, 57), "dark"),
    # -- Gegengewichts-Ausleger -------------------------------------------
    # Laeuft nach hinten-oben ueber den Kopf hinaus und ist das Merkmal, an
    # dem dieser Rahmen auch als reine Schattenform erkennbar bleibt.
    B((-9, -5), (-4, 4), (46, 62), "plate"),
    B((-14, -8.5), (-3.5, 3.5), (59, 68), "plate"),
    B((-14.5, -8), (-4, 4), (68, 70), "light"),
    B((-14.6, -14), (-2.5, 2.5), (61, 66), "accent"),
    # Kuehlrippen ueber und unter dem Kernschacht: sie rahmen ihn ein, statt
    # die Flaeche zu belegen, auf der er sitzt.
    B((-9.6, -9), (-3, 3), (46.6, 48.1), "light"),
    B((-9.6, -9), (-3, 3), (56.4, 57.9), "light"),
    # -- Waffenjoch vor der Brust: ein Lager statt zweier Arme -------------
    B((5.5, 10), (-9.5, -6.5), (47, 54), "metal"),
    B((5.5, 10), (6.5, 9.5), (47, 54), "metal"),
    B((5, 10.5), (-10, 10), (54, 56.5), "metal"),
    B((10.5, 11.1), (-8, -6.5), (48, 53), "accent"),
    B((10.5, 11.1), (6.5, 8), (48, 53), "accent"),
    # -- Hals --------------------------------------------------------------
    B((-3, 3), (-3.5, 3.5), (60.5, 63), "metal"),
]

# Aufklaerer-Kopf mit EINEM langen Okular statt eines breiten Visierbands --
# ein Fernrohr liest sich anders als ein Sichtschlitz, und genau das ist der
# Unterschied zwischen "sieht viel" und "sieht weit".
STRIX_HEAD = [
    B((-5, 5), (-4.5, 4.5), (63, 71), "plate"),
    B((-5.5, 5.5), (-5, 5), (71, 73), "light"),
    B((5, 9.5), (-2.2, 2.2), (65.8, 70.2), "metal"),
    D(9.8, 0, 68, 2.0, "visor"),
    # Rueckenfinne mit Antennenband
    B((-6.5, -5), (-1.2, 1.2), (66, 78), "metal"),
    B((-6.8, -5.2), (-1.7, 1.7), (72, 75.5), "accent"),
    # Seitliche Windmesser
    B((-3, 3), (4.5, 6), (67.5, 69), "metal"),
    B((-3, 3), (-6, -4.5), (67.5, 69), "metal"),
]

# Digitigrade Beine: der Knick zeigt nach HINTEN. Vireo rennt auf geraden
# Stelzen, Molok steht auf Ferse und Sporn -- Strix federt. Drei Beinformen,
# drei Bewegungsprofile, in der Silhouette unterscheidbar.
STRIX_FEET = [
    B((-4, 4), (3.5, 8), (23, 34), "plate"),
    B((-4, 4), (-8, -3.5), (23, 34), "plate"),
    # Sprunggelenk
    L((-1.5, 5.75), [(2.6, 20.5), (2.6, 23.5)], "metal", segments=12),
    L((-1.5, -5.75), [(2.6, 20.5), (2.6, 23.5)], "metal", segments=12),
    # Unterschenkel, nach hinten geknickt
    B((-9, -1), (4.2, 7.3), (13, 21), "plate"),
    B((-9, -1), (-7.3, -4.2), (13, 21), "plate"),
    B((-9.3, -8.7), (4.6, 6.9), (15, 19), "accent"),
    B((-9.3, -8.7), (-6.9, -4.6), (15, 19), "accent"),
    # Mittelfuss laeuft von hinten-oben nach vorn-unten
    B((-9, 2), (4.4, 7.1), (7, 13.5), "metal"),
    B((-9, 2), (-7.1, -4.4), (7, 13.5), "metal"),
    # Schmale Standklaue: kleine Aufstandsflaeche, dafuer eine lange Zehe
    B((-3, 9), (4, 7.5), (0, 5), "plate"),
    B((-3, 9), (-7.5, -4), (0, 5), "plate"),
    B((9, 13), (4.6, 6.9), (0, 2), "dark"),
    B((9, 13), (-6.9, -4.6), (0, 2), "dark"),
]

# Kernschacht statt Kernscheibe: ein senkrechter Leuchtspalt, eingelassen in
# den Gegengewichts-Ausleger. Ein Kern wird ueber die Glut gelesen, nicht ueber
# die Form -- aber wenn schon drei runde Kerne existieren, ist der vierte
# besser eckig.
#
# Warum am RUECKEN: die Brust dieses Rahmens gehoert dem Waffenjoch, und die
# Schienen-Lanze liegt genau davor. Ein Kern dort waere im bestueckten Bot aus
# Sued und Ost verdeckt -- also aus den beiden Richtungen, in denen man ihn
# sehen wuerde. Der Ausleger ist die einzige grosse freie Flaeche des Rahmens.
#
# Die Tiefen sind der eigentliche Entwurf: das Gehaeuse liegt hinter der
# Aussenflaeche des Auslegers (-9.0), nur der Leuchtspalt kommt eine
# Fingerbreite heraus. Zwischen den Kuehlrippen liest sich das als Schacht.
STRIX_CORE = [
    B((-9.0, -8.4), (-1.7, 1.7), (48.0, 55.2), "dark"),
    B((-9.25, -9.0), (-1.1, 1.1), (48.6, 54.6), "glow"),
    B((-9.2, -9.0), (-3.0, -1.9), (48.6, 54.6), "accent"),
    B((-9.2, -9.0), (1.9, 3.0), (48.6, 54.6), "accent"),
]

# Schienen-Lanze -- die schwerste Waffe im Bestand und der Gegenpol zur
# Belagerungskanone: dort gedrungen und breit, hier ueberlang und duenn. Zwei
# parallele Schienen mit Energiespalt statt eines Rohrs, ein weit vorn
# sitzender Zielblock, eine Stabilisatorgabel. Aus der Silhouette faellt
# "grosse Reichweite, ein Schuss" ab, ohne dass ein Tooltip es sagen muss.
EQ_RAIL_LANCE = [
    # Wiegenlager -- sitzt im Joch des Chassis, nicht an einem Arm
    B((-4, 3), (-5, 5), (47.5, 54.5), "metal"),
    B((-6, -1), (-5.5, 5.5), (45, 56), "plate"),
    # Kondensatorbank, liegend
    L((-3, 50.5), [(4.4, -6.2), (4.8, -5.2), (4.8, 5.2), (4.4, 6.2)],
      "dark", axis="l", segments=12),
    L((-3, 50.5), [(5.1, -2.6), (5.1, -1.6)], "accent", axis="l",
      caps=False, segments=12),
    L((-3, 50.5), [(5.1, 1.6), (5.1, 2.6)], "accent", axis="l",
      caps=False, segments=12),
    # Zwei Schienen mit Energiespalt: eine Linie, kein Rohr
    B((3, 26), (-2.7, -1.2), (49.4, 52.4), "metal"),
    B((3, 26), (1.2, 2.7), (49.4, 52.4), "metal"),
    B((5, 25), (-1.1, 1.1), (50.3, 51.5), "accent"),
    B((26, 29), (-2.9, 2.9), (49.1, 52.7), "dark"),
    D(29.3, 0, 50.9, 1.7, "glow"),
    # Zielblock weit vorn obenauf
    B((7, 18), (-2.3, 2.3), (52.4, 55.4), "dark"),
    B((7.5, 17.5), (-2.7, 2.7), (55.4, 56.5), "light"),
    D(18.3, 0, 53.9, 1.5, "visor"),
    # Stabilisatorgabel nach vorn-unten
    B((11, 13), (-6.8, -2.8), (41, 49.4), "metal"),
    B((11, 13), (2.8, 6.8), (41, 49.4), "metal"),
    B((9.5, 15), (-7.8, -5.8), (39.5, 41.5), "dark"),
    B((9.5, 15), (5.8, 7.8), (39.5, 41.5), "dark"),
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
                # Ein Sprinter traegt keine Artillerie. Die Grenze steht hier
                # und nicht in einer Balancing-Tabelle, weil sie sonst erst im
                # Kampf auffaellt -- und weil ein Vireo mit Belagerungskanone
                # eine Silhouette haette, die ueber seine Reichweite luegt.
                "slot_rules": {
                    "equip_left": {"max_class": "medium"},
                    "equip_right": {"max_class": "medium"},
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
                "mount_class": "light", "category": "weapon",
                "anchors": {"mount": (0, 0, 52), "muzzle": (16.8, 0, 38.5)},
            },
            {
                "id": "eq_deflector", "code": "EQP-002", "type": "equipment", "name": "Deflektor-Schild",
                "tags": ["defense"], "shapes": EQ_SHIELD,
                # Ein Schild ist sperrig, nicht schwer -- "medium" haelt es von
                # den Schulter- und Jochlagern fern, ohne es an einem
                # Standardarm einzuschraenken.
                "mount_class": "medium", "category": "shield",
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
                    "core": (11.0, 0, 51.4),
                    "equip_left": (0, 26.5, 49),
                    "equip_right": (0, -26.5, 49),
                    # Auf dem Rueckendeck zwischen den Auspuffstapeln.
                    "equip_shoulder": (-7, 0, 63),
                },
                # Der Schulteranker ist KEIN dritter Arm. Er sitzt hinter dem
                # Kopf auf der Schulterbruecke, hat keinen Gegenhalt und nichts,
                # woran sich ein Schild abstuetzen koennte -- dort gehoert
                # Sensorik und Support hin, nichts Schweres und nichts, was
                # gehalten werden muss.
                "slot_rules": {
                    "equip_left": {"max_class": "heavy"},
                    "equip_right": {"max_class": "heavy"},
                    "equip_shoulder": {"max_class": "light",
                                       "categories": ["support"]},
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
                "anchors": {"mount": (11.0, 0, 51.4)},
            },
            {
                "id": "eq_siege_cannon", "code": "EQP-003", "type": "equipment",
                "name": "Belagerungskanone", "tags": ["weapon", "heavy"],
                "shapes": EQ_CANNON,
                "mount_class": "heavy", "category": "weapon",
                "anchors": {"mount": (0, 0, 49), "muzzle": (24.9, 0, 40)},
            },
            {
                # Einziges Beispielteil mit "slots": ein Schulterpod gehoert auf
                # die Schulter, und zwar auf diesen einen Anker. "slots" ist die
                # harte Ankerliste, "mount_class"/"category" die allgemeine
                # Regel -- die meisten Teile brauchen nur letztere.
                "id": "eq_drone_pod", "code": "EQP-004", "type": "equipment", "name": "Drohnen-Pod",
                "tags": ["support", "shoulder"], "shapes": EQ_DRONE_POD,
                "slots": ["equip_shoulder"],
                "mount_class": "light", "category": "support",
                "anchors": {"mount": (0, 0, 61)},
            },
            {
                # Bewusst OHNE "slots": der Sender passt an jeden Arm und auf
                # die Molok-Schulter. Nur so kostet er auch etwas. Waere er
                # schulterfest, koennte ihn allein der Molok tragen -- und
                # zwar in einem Slot, in dem ohnehin keine Waffe sitzen darf.
                # Am Strix mit seinem einzigen Anker ist er dagegen gar nicht
                # tragbar, ohne dass der Aufbau seine Waffe verliert und damit
                # ungueltig wird. Das ist die Slot-Achse aus Abschnitt 3c, auf
                # die Aggro angewandt: eine Kaufentscheidung ohne eine Zahl.
                "id": "eq_bait_beacon", "code": "EQP-008", "type": "equipment",
                "name": "Koedersender", "tags": ["support", "beacon", "aggro"],
                "shapes": EQ_BAIT_BEACON,
                "mount_class": "light", "category": "support",
                "anchors": {"mount": (0, 0, 52)},
            },
        ],
    },
    {
        "dir": "bot3",
        "id": "bot3",
        "name": "AR-Nimbus // Technomant",
        "description": "Gerundete Support-DROME auf Fahrgestell. "
                       "Zwei Ausruestungsanker.",
        "palette": MAGE_PALETTE,
        "parts": [
            {
                "id": "mage_body", "code": "CHS-003", "type": "body",
                "name": "Nimbus Chassis", "tags": ["round", "mage", "support"],
                "shapes": MAGE_BODY,
                "anchors": {
                    "mount": (0, 0, MOUNT_Z),
                    "head": (0, 0, 61),
                    "feet": (0, 0, 27),
                    "core": (11.4, 0, 44),
                    "equip_left": (0, 13.8, 47),
                    "equip_right": (0, -13.8, 47),
                },
                "slot_rules": {
                    "equip_left": {"max_class": "medium"},
                    "equip_right": {"max_class": "medium"},
                },
            },
            {
                "id": "mage_head", "code": "HED-003", "type": "head",
                "name": "Nimbus Flachhelm", "tags": ["round", "mage", "sensor"],
                "shapes": MAGE_HEAD,
                "anchors": {"mount": (0, 0, 61), "sensor": (10.6, 0, 68.4)},
            },
            {
                "id": "mage_drive", "code": "LEG-003", "type": "feet",
                "name": "Nimbus Fahrwerk", "tags": ["wheels", "round", "fast"],
                "shapes": MAGE_DRIVE,
                "anchors": {"mount": (0, 0, 27), "ground": (1, 0, 0)},
            },
            {
                "id": "mage_core", "code": "COR-003", "type": "core",
                "name": "Nimbus Arkankern", "tags": ["core", "arcane"],
                "shapes": MAGE_CORE,
                "anchors": {"mount": (11.4, 0, 44)},
            },
            {
                "id": "eq_rune_staff", "code": "EQP-005", "type": "equipment",
                "name": "Runenstab", "tags": ["weapon", "arcane", "round"],
                "shapes": EQ_RUNE_STAFF,
                "mount_class": "light", "category": "weapon",
                "anchors": {"mount": (0, 0, 47), "muzzle": (7.6, 0, 61.0)},
            },
            {
                "id": "eq_orbit_focus", "code": "EQP-006", "type": "equipment",
                "name": "Orbit-Fokus", "tags": ["support", "arcane", "round"],
                "shapes": EQ_ORBIT_FOCUS,
                "mount_class": "light", "category": "support",
                "anchors": {"mount": (0, 0, 47), "muzzle": (7.6, 0, 30.5)},
            },
        ],
    },
    {
        "dir": "bot4",
        "id": "bot4",
        "name": "LR-Strix // Marksman",
        "description": "Schmaler Scharfschuetzen-Rahmen. EIN zentraler "
                       "Ausruestungsanker, dafuer voll belastbar.",
        "palette": STRIX_PALETTE,
        "parts": [
            {
                "id": "strix_body", "code": "CHS-004", "type": "body",
                "name": "Strix Chassis", "tags": ["marksman", "light", "sniper"],
                "shapes": STRIX_BODY,
                "anchors": {
                    "mount": (0, 0, MOUNT_Z),
                    "head": (0, 0, 63),
                    "feet": (0, 0, 34),
                    # Am Ruecken statt an der Brust -- siehe STRIX_CORE.
                    "core": (-9.0, 0, 51.6),
                    # Genau ein Anker -- und er sitzt auf der Mittelachse im
                    # Joch, nicht seitlich am Arm.
                    "equip_center": (6, 0, 51),
                },
                # Ein Slot, dafuer ohne Deckel: hier darf das Schwerste hin.
                "slot_rules": {"equip_center": {"max_class": "heavy"}},
            },
            {
                "id": "strix_head", "code": "HED-004", "type": "head",
                "name": "Strix Okularkopf", "tags": ["marksman", "sensor", "optics"],
                "shapes": STRIX_HEAD,
                "anchors": {"mount": (0, 0, 63), "sensor": (9.8, 0, 68)},
            },
            {
                "id": "strix_feet", "code": "LEG-004", "type": "feet",
                "name": "Strix Federbeine", "tags": ["marksman", "digitigrad"],
                "shapes": STRIX_FEET,
                "anchors": {"mount": (0, 0, 34), "ground": (2, 0, 0)},
            },
            {
                "id": "strix_core", "code": "COR-004", "type": "core",
                "name": "Strix Zielrechner", "tags": ["core", "optics"],
                "shapes": STRIX_CORE,
                "anchors": {"mount": (-9.0, 0, 51.6)},
            },
            {
                "id": "eq_rail_lance", "code": "EQP-007", "type": "equipment",
                "name": "Schienen-Lanze", "tags": ["weapon", "heavy", "sniper"],
                "shapes": EQ_RAIL_LANCE,
                # Schwer wie die Belagerungskanone -- an einen Sprinterarm
                # kommt sie damit ebenso wenig.
                "mount_class": "heavy", "category": "weapon",
                "anchors": {"mount": (0, 0, 51), "muzzle": (29.3, 0, 50.9)},
            },
        ],
    },
]


SVG_NOTE = """
    Isometrische Ansicht, Kamera 45 Grad von oben, Blickrichtung {direction}.
    Bodenfeld: Raute 76 x 54 px um den Mittelpunkt (64, 96).
    Projektion:  x = 64 + cos(45)*(px - py)*SCALE
                 y = 96 - (0.5*(px + py) + cos(45)*pz)*SCALE
    Erzeugt von tools/build_sample_parts.py aus einer bot-lokalen Quader-
    Definition, nicht von Hand bearbeiten, sondern dort aendern.
    Farben ausschliesslich ueber CSS Custom Properties (siehe parts/README.md).
  """

SVG_TEMPLATE = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128"
     data-part-id="{pid}" data-type="{ptype}" data-direction="{direction}">
  <title>{name} ({direction})</title>
  <!--{note}-->
{body}
</svg>
"""


def svg_comment_body(text: str) -> str:
    """
    Kommentartext, der in einem XML-Kommentar stehen DARF.

    ``--`` ist dort verboten, und ausgerechnet in diesem Projekt steht der
    Gedankenstrich in fast jedem erklaerenden Satz. Browser und Godot sind
    nachsichtig; ElementTree, lxml und jedes Werkzeug, das die Dateien strikt
    parst, brechen dagegen ab. Deshalb wird hier zusammengezogen, statt sich
    darauf zu verlassen, dass niemand einen Gedankenstrich schreibt. Ein
    Bindestrich unmittelbar vor dem Kommentarende ist aus demselben Grund
    ebenfalls unzulaessig.
    """
    return re.sub(r"-{2,}", "-", text).rstrip("-")


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
        note=svg_comment_body(SVG_NOTE.format(direction=direction)),
    )
    # Eine Datei, die sich SVG nennt, muss wohlgeformtes XML sein. Godot und
    # jeder Browser sehen darueber hinweg, ein strikter Parser nicht -- und
    # der Fehler faellt dann irgendwann in einem Werkzeug auf, das mit dem
    # Teil gar nichts zu tun hat. Hier kostet die Pruefung nichts.
    try:
        ElementTree.fromstring(svg)
    except ElementTree.ParseError as error:
        raise SystemExit(
            f"{set_id}/{stem}.svg ist kein wohlgeformtes XML: {error}"
        ) from error
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
        # Referenzfarben: die acht CSS-Rollen, wie sie sich aus den vier
        # Kategorien DIESES Bauteiltyps ergeben. Rein dokumentierend --
        # gezeichnet wird immer mit der aktiven Palette der Werkstatt.
        "color_scheme": resolve_roles(palette[palette_type(part["type"])],
                                      part["type"]),
        "tags": part.get("tags", []),
    }
    if part["type"] == "body":
        meta["slot_z"] = slot_draw_order(part, direction)
        if "slot_rules" in part:
            meta["slot_rules"] = part["slot_rules"]
    if part["type"].startswith("equipment"):
        meta["mount_class"] = part.get("mount_class", DEFAULT_MOUNT_CLASS)
        meta["category"] = part.get("category", DEFAULT_CATEGORY)
    if "slots" in part:
        meta["slots"] = part["slots"]
    # Spielwerte. Richtungsunabhaengig, deshalb in allen vier JSONs identisch --
    # gepflegt wird ausschliesslich die Tabelle STATS weiter oben.
    meta["stats"] = part_stats(pid)

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

    check_slot_rules()
    check_mounts()
    check_core_seat()
    check_silhouettes()
    check_stats()
    print_slot_matrix()

    print(f"\nIso-Kamera 45 Grad  |  Bodenfeld {2 * TILE_HALF_W:.0f} x "
          f"{2 * TILE_HALF_H:.0f} px um ({CENTER_X:.0f}, {GROUND_Y:.0f})")
    print(f"{len(seen)} Teile-Codes vergeben: {', '.join(sorted(seen))}")


def all_parts():
    for spec in SETS:
        for part in spec["parts"]:
            yield spec, part


def check_slot_rules() -> None:
    """Regeln muessen sich auf existierende Anker und bekannte Werte beziehen."""
    for spec, part in all_parts():
        where = f"{spec['id']}/{part['id']}"
        if part["type"] == "body":
            anchors = set(part["anchors"])
            for slot, rule in part.get("slot_rules", {}).items():
                if slot not in anchors:
                    raise SystemExit(f"{where}: slot_rules nennt {slot!r}, "
                                     f"aber der Anker fehlt")
                limit = rule.get("max_class", MOUNT_CLASSES[-1])
                if limit not in MOUNT_CLASSES:
                    raise SystemExit(f"{where}/{slot}: unbekannte "
                                     f"Montageklasse {limit!r}")
                for category in rule.get("categories", ()):
                    if category not in EQUIP_CATEGORIES:
                        raise SystemExit(f"{where}/{slot}: unbekannte "
                                         f"Bauart {category!r}")
        elif part["type"].startswith("equipment"):
            if part.get("mount_class", DEFAULT_MOUNT_CLASS) not in MOUNT_CLASSES:
                raise SystemExit(f"{where}: unbekannte Montageklasse")
            if part.get("category", DEFAULT_CATEGORY) not in EQUIP_CATEGORIES:
                raise SystemExit(f"{where}: unbekannte Bauart")


# Rahmenteile, deren "mount" DERSELBE bot-lokale Punkt sein muss wie der
# Sockel-Anker des Koerpers. Ausruestung gehoert bewusst nicht dazu: ihr Anker
# sitzt in ihrer eigenen Mitte, damit dasselbe Teil an den linken wie an den
# rechten Arm passt (siehe parts/README.md, Abschnitt 6).
SOCKET_SLOTS = ("head", "feet", "core")


def check_mounts() -> None:
    """Kopf, Fuesse und Kern muessen exakt auf ihrem Sockel sitzen."""
    for spec in SETS:
        body = next((p for p in spec["parts"] if p["type"] == "body"), None)
        if not body:
            continue
        for slot in SOCKET_SLOTS:
            part = next((p for p in spec["parts"] if p["type"] == slot), None)
            if not part or slot not in body["anchors"]:
                continue
            socket, mount = body["anchors"][slot], part["anchors"]["mount"]
            if tuple(socket) != tuple(mount):
                raise SystemExit(
                    f"{spec['id']}/{part['id']}: mount {mount} sitzt nicht auf "
                    f"dem Sockel {socket} von {body['id']}. Beide Anker "
                    f"beschreiben denselben Punkt am Bot -- laufen sie "
                    f"auseinander, haengt das Teil im zusammengebauten Bot "
                    f"genau um die Differenz daneben."
                )


def check_core_seat() -> None:
    """
    Die Sitzregel als Test: ein Kern steht nicht vor dem Chassis.

    Der Wert AUFBAU ist die Hoehe, mit der der Kern aus der Panzerung
    heraussteht, FREI der Anteil seiner Flaeche ohne Chassis dahinter. Beides
    hat dieselbe Ursache, wenn es schiefgeht -- der Kern wurde fuer sich
    entworfen und nicht fuer seinen Schacht -- und dieselbe Wirkung: er sieht
    aufgeklebt aus, weil die Iso-Ansicht seine Tiefe nicht zeigen kann.
    """
    rows, problems = [], []
    for spec in SETS:
        body = next((p for p in spec["parts"] if p["type"] == "body"), None)
        core = next((p for p in spec["parts"] if p["type"] == "core"), None)
        if not body or not core or "core" not in body["anchors"]:
            continue
        proud, free = core_seat(core["shapes"], body["shapes"],
                                body["anchors"]["core"])
        seat = "Ruecken" if body["anchors"]["core"][0] < 0 else "Brust"
        rows.append((f"{spec['id']}/{core['id']}", seat, proud, free))
        if proud > SEAT_MAX_PROUD or free > SEAT_MAX_FREE:
            problems.append((f"{spec['id']}/{core['id']}", proud, free))

    print(f"\nKernsitz (Aufbau bis {SEAT_MAX_PROUD:.1f} Einheiten, "
          f"freihaengend bis {SEAT_MAX_FREE:.0%}):")
    for name, seat, proud, free in rows:
        print(f"  {name:<22} {seat:<8} Aufbau {proud:4.2f}  frei {free:5.1%}")

    if problems:
        lines = "\n".join(f"  {name}: Aufbau {proud:.2f}, frei {free:.0%}"
                          for name, proud, free in problems)
        raise SystemExit(
            "Sitzregel verletzt -- ein Kern steht vor dem Chassis:\n" + lines +
            "\n\nIm zusammengebauten Bot gibt es keinen Tiefenpuffer: der Kern "
            "wird nach dem Koerper gezeichnet und deckt ihn ab. Was vorsteht, "
            "sieht deshalb nicht tief aus, sondern aufgeklebt. Kern flacher in "
            "den Schacht legen -- oder dem Chassis einen Sockel geben, der so "
            "weit vorkommt wie der Kern."
        )


def check_silhouettes() -> None:
    """
    Die Lesbarkeitsregel als Test.

    Zwei Ausruestungsteile duerfen sich nicht allein durch ihre Groesse
    unterscheiden -- im Iso-Bild ist Groesse keine verlaessliche Information.
    Fuer Ausruestung ist das ein Abbruch: an der Waffe liest der Spieler
    Reichweite und Rolle ab, und ein deterministisches Tactics darf ihm diese
    Auskunft nicht verweigern.

    Fuer RAHMENTEILE gibt es bewusst KEINE Grenze mehr, nur noch die Tabelle.
    Der Grund ist nicht Nachsicht, sondern dass das Mass dort nichts aussagt:
    jedes kompakte Teil wird normiert zu demselben Klumpen. Bunkerkopf (ein
    Quader, projiziert ein Sechseck) und Flachhelm (Kuppel mit Krempe,
    projiziert eine Raute) fuellen beide 64 Prozent des Rahmens an derselben
    Stelle und kommen damit auf 0.88 -- obwohl sie einander nicht im
    Entferntesten aehnlich sehen.

    Eine Grenze, die nur Fehlalarme produziert, ist schlimmer als keine: sie
    gewoehnt einem an, Hinweise zu ueberlesen, und dann geht auch ein echter
    unter. Was bleibt, ist die REIHENFOLGE -- welches Paar liegt am engsten --,
    und die ist als blosse Information brauchbar. Ob zwei Rahmen dieselbe
    Formensprache sprechen, entscheidet ohnehin das Auge.
    """
    # Erst nachweisen, dass der Test ueberhaupt noch etwas findet.
    probe = silhouette_distance(silhouette(EQ_BLASTER), silhouette(EQ_CANNON_V1))
    if probe < SIL_ERROR:
        raise SystemExit(
            f"Der Silhouetten-Test ist stumpf geworden: die alte, absichtlich "
            f"vom Blaster abgeschriebene Belagerungskanone kommt nur noch auf "
            f"{probe:.2f} und liegt damit unter SIL_ERROR ({SIL_ERROR:.2f}). "
            f"Erst Mass oder Grenze reparieren, dann weiter."
        )

    by_type: dict[str, list] = {}
    for spec, part in all_parts():
        key = "equipment" if part["type"].startswith("equipment") else part["type"]
        by_type.setdefault(key, []).append(
            (f"{spec['id']}/{part['id']}", silhouette(part["shapes"])))

    problems, closest = [], []
    for part_type, entries in sorted(by_type.items()):
        worst = None
        for i, (name_a, sil_a) in enumerate(entries):
            for name_b, sil_b in entries[i + 1:]:
                score = silhouette_distance(sil_a, sil_b)
                if worst is None or score > worst[0]:
                    worst = (score, name_a, name_b)
                if part_type == "equipment" and score >= SIL_ERROR:
                    problems.append((score, name_a, name_b))
        if worst:
            closest.append((part_type, worst))

    print(f"\nSilhouetten-Abstand (1.00 = ununterscheidbar; Grenze "
          f"{SIL_ERROR:.2f}, aber nur fuer Ausruestung -- Pruefstein "
          f"{probe:.2f}), engstes Paar je Typ:")
    for part_type, (score, name_a, name_b) in closest:
        print(f"  {part_type:<10} {score:.2f}  {name_a} / {name_b}")

    if problems:
        lines = "\n".join(f"  {a} und {b} decken sich zu {score:.0%}"
                          for score, a, b in problems)
        raise SystemExit(
            "Lesbarkeitsregel verletzt -- zwei Ausruestungsteile haben "
            "dieselbe Silhouette:\n" + lines +
            "\n\nGroesse allein unterscheidet im Iso-Bild nicht: die Kachel "
            "ist klein, Teile ueberlappen, ein Bot weiter hinten ist ohnehin "
            "kleiner. Wer nur skaliert, baut eine Waffe, deren Reichweite man "
            "ihr nicht ansieht. Silhouetten-Merkmal ergaenzen (Muendungsbremse, "
            "Magazin, Strebe, Klinge, ...) und erneut erzeugen."
        )


def check_stats() -> None:
    """
    Die Baubarkeitsregel als Test: jeder Bausatz muss sich selbst bauen koennen.

    Ein Chassis, das seine eigenen Anker nicht bestuecken kann, ist kein
    Balancing-Problem, sondern ein Datenfehler -- es faellt nur erst in der
    Werkstatt auf, wenn der Spieler schon klickt. Deshalb wird hier fuer jeden
    Satz der naheliegendste Aufbau durchgerechnet: eigener Kopf, eigener Kern,
    eigener Antrieb und die eigene Ausruestung in so vielen Slots, wie das
    Chassis Anker hat.

    Geprueft werden die vier Regeln, die auch die Werkstatt spaeter prueft:
    Pflichtteile, Traglast, Energie, und mov/spd mindestens 1.
    """
    for spec, part in all_parts():
        if part["id"] not in STATS:
            raise SystemExit(f"{spec['id']}/{part['id']}: kein Eintrag in STATS")

    rows = []
    for spec in SETS:
        parts = {p["type"]: p for p in spec["parts"] if not
                 p["type"].startswith("equipment")}
        body = parts.get("body")
        if not body:
            continue
        slots = sorted(a for a in body["anchors"] if a.startswith("equip_"))
        rules = body.get("slot_rules", {})

        chosen = [body] + [parts[t] for t in ("head", "feet", "core") if t in parts]
        equipment = [p for p in spec["parts"] if p["type"].startswith("equipment")]
        # Waffen zuerst -- ein Aufbau ohne Waffe ist per Regel ungueltig.
        equipment.sort(key=lambda p: p.get("category", DEFAULT_CATEGORY) != "weapon")
        for slot in slots:
            fit = next((p for p in equipment if p not in chosen and
                        fits_rule(p.get("mount_class", DEFAULT_MOUNT_CLASS),
                                  p.get("category", DEFAULT_CATEGORY),
                                  rules.get(slot))), None)
            if fit:
                chosen.append(fit)

        stats = {k: 0 for k in ("hp", "en_max", "spd", "mov", "atk", "def",
                                "weight", "power_draw")}
        capacity = output = 0
        has_weapon = False
        for p in chosen:
            s = part_stats(p["id"])
            for k in stats:
                stats[k] += s[k]
            capacity += s["weight_capacity"]
            output += s["power_output"]
            if p.get("category") == "weapon":
                has_weapon = True

        where = spec["id"]
        problems = []
        if not has_weapon:
            problems.append("keine Waffe")
        if stats["weight"] > capacity:
            problems.append(f"Traglast {stats['weight']}/{capacity}")
        if stats["power_draw"] > output:
            problems.append(f"Energie {stats['power_draw']}/{output}")
        if stats["mov"] < 1:
            problems.append(f"mov {stats['mov']}")
        if stats["spd"] < 1:
            problems.append(f"spd {stats['spd']}")
        if problems:
            raise SystemExit(
                f"{where}: der eigene Standardaufbau ist ungueltig -- "
                f"{', '.join(problems)}.\n"
                f"Ein Bausatz, der sich selbst nicht bauen kann, ist ein "
                f"Datenfehler. Traglast des Chassis, Ausstoss des Kerns oder "
                f"die Gewichte der Teile in STATS anpassen."
            )
        rows.append((where, stats, capacity, output))

    print("\nStandardaufbau je Bausatz (eigene Teile, alle Anker belegt):")
    print(f"  {'':<7}{'HP':>5}{'EN':>5}{'SPD':>5}{'MOV':>5}{'ATK':>5}{'DEF':>5}"
          f"{'  Last':>10}{'  Energie':>11}")
    for where, s, capacity, output in rows:
        print(f"  {where:<7}{s['hp']:>5}{s['en_max']:>5}{s['spd']:>5}"
              f"{s['mov']:>5}{s['atk']:>5}{s['def']:>5}"
              f"{s['weight']:>7}/{capacity:<3}{s['power_draw']:>8}/{output:<3}")


def print_slot_matrix() -> None:
    """Welche Ausruestung passt an welchen Slot -- das Ergebnis der Regeln."""
    equipment = [(spec, part) for spec, part in all_parts()
                 if part["type"].startswith("equipment")]

    print("\nAusruestung x Slot:")
    for spec, body in all_parts():
        if body["type"] != "body":
            continue
        rules = body.get("slot_rules", {})
        for slot in sorted(a for a in body["anchors"] if a.startswith("equip_")):
            rule = rules.get(slot)
            limit = (rule or {}).get("max_class", MOUNT_CLASSES[-1])
            cats = (rule or {}).get("categories") or list(EQUIP_CATEGORIES)
            allowed = [
                eq_part["code"] for _eq_spec, eq_part in equipment
                if fits_rule(eq_part.get("mount_class", DEFAULT_MOUNT_CLASS),
                             eq_part.get("category", DEFAULT_CATEGORY), rule)
                and slot in eq_part.get("slots", [slot])
            ]
            print(f"  {spec['id']}/{slot:<14} bis {limit:<7}"
                  f"{'/'.join(cats):<22} {' '.join(allowed) or '--'}")


if __name__ == "__main__":
    main()
