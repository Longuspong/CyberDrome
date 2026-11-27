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
import os
import pathlib
import re
import shutil
from xml.etree import ElementTree

# Wo die Strix-Lafette sitzt (18. Nov. 2026, Vergleich fuer den Spieler;
# Empfehlung und Standard: Schulter -- die Waffe ragt ueber die Silhouette,
# verdeckt die grossen Fluegel nicht und liest sich auf dem Handy sofort als
# Scharfschuetze; Umschalten mit STRIX_MOUNT=achsel):
# "achsel" = seitlich unter der Schulter, Halter greift quer hinein;
# "schulter" = oben auf der Schulter, Halter steckt von oben in der Buchse.
STRIX_MOUNT = os.environ.get("STRIX_MOUNT", "schulter")

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
# Die vier Blickrichtungen (fuer die Entwurfs-Skripte unter docs/design/drome_entwurf).
DIRECTIONS = ["south", "west", "east", "north"]
## Die Richtung des Symbols je Teil (die einzige, die noch als Bild entsteht).
SYMBOL_DIRECTION = "south"


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


# Rumpf und Mechanik seit 16. Nov. 2026 etwa 40 % heller (docs/DROME_DESIGNREGELN.md,
# Abschnitt 5): vorher #1c..#3d auf Nachtschwarz -- in Spielgroesse blieben nur
# die Leuchtpunkte. Signalfarben (neon, visor, ember, rings) bleiben.
DEFAULT_PALETTE = make_palette(
    hull="#3a4670", mech="#7d8bb0", neon="#2de2e6", visor="#7cf9ff",
    ember="#ff2d95", rings="#2de2e6", line="#080b13",
)

JUGG_PALETTE = make_palette(
    hull="#5a4050", mech="#9a8796", neon="#ff8a3d", visor="#ffb057",
    ember="#ffd447", rings="#ff8a3d", line="#100a0e",
)

MAGE_PALETTE = make_palette(
    hull="#463673", mech="#8f7fbd", neon="#b06bff", visor="#d6b8ff",
    ember="#7cf9ff", rings="#ff5ec7", line="#0d0818",
)

STRIX_PALETTE = make_palette(
    hull="#2a4e48", mech="#74a394", neon="#6dff9f", visor="#c2ffd7",
    ember="#6dff9f", rings="#2fbf8c", line="#060f0d",
)


# Waffenfarben, unabhaengig vom DROME (17. Nov. 2026, Wunsch des Spielers):
# jede Waffe hat hier ihre EIGENE Palette, egal an welchem Chassis sie haengt.
# Gewaehlt am 18. Nov. 2026 (siehe unten) --
# zum Umfaerben nur hier aendern, dann build_sample_parts.py und
# bake_godot_assets.py laufen lassen.
def _w(hull, mech, neon, line="#07090d"):
    return {"hull": hull, "mech": mech, "neon": neon, "line": line}


# Gewaehlt am 18. Nov. 2026 (Leinwand "Waffenfarben", v13_waffenfarben.py):
# Satz A "Waffenstahl" fuer alle, der Puls-Blaster aus Satz B "Chrom".
WEAPON_COLORS = {
    "eq_pulse_blaster": _w("#7a8494", "#d6dde6", "#2de2e6", "#0a0d12"),
    "eq_plasma_blade": _w("#2a2f3a", "#9aa3b3", "#ff5a3d"),
    "eq_deflector": _w("#39404c", "#8a93a3", "#5ad1ff"),
    "eq_hammer": _w("#4a4e56", "#a0a6b0", "#ff8a3d"),
    "eq_rune_staff": _w("#3a3550", "#a59ac8", "#b06bff"),
    "eq_rail_lance": _w("#1d2430", "#6f7d92", "#3df2ff"),
}

# Oberflaeche je Waffe (18. Nov. 2026): ``shine`` = Glanzkante je Material
# (0..1, Shader drome_face), ``neon`` = die Leuchtteile leuchten im Spiel wie
# beim Neon-Blaster (Energiewaffen). Vorgabe des Spielers: Klingen glaenzen
# oder leuchten, Griffe und Halterungen bleiben matt.
WEAPON_FINISH = {
    "eq_pulse_blaster": {"shine": {"plate": 0.7, "light": 0.7, "metal": 0.6}},
    "eq_plasma_blade": {"neon": True},
    "eq_deflector": {"shine": {"plate": 0.3, "light": 0.3}, "neon": True},
    "eq_hammer": {"shine": {"plate": 0.4, "light": 0.4}},
    "eq_rune_staff": {"shine": {"plate": 0.35}, "neon": True},
    "eq_rail_lance": {"shine": {"plate": 0.3, "light": 0.3}, "neon": True},
}

C = {role: f"var(--c-{role.replace('_', '-')})" for role in PALETTE_ROLES}

# Material = (Oberseite, linke Flanke, rechte Flanke, Kontur?)
MATERIALS = {
    "plate":  (C["plate_light"], C["plate"], C["plate_dark"], True),
    "dark":   (C["plate"], C["plate_dark"], C["plate_dark"], True),
    "light":  (C["plate_light"], C["plate_light"], C["plate"], True),
    "metal":  (C["metal"], C["metal"], C["plate_dark"], True),
    # Schneide (18. Nov. 2026): helles Metall, im Spiel mit Glanzkante.
    "blade":  (C["plate_light"], C["metal"], C["plate"], True),
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
# damit unveraendert weiter. ``{"off": True}`` macht einen Anker zur reinen
# Optik: er ist kein Halter (seit Nov. 2026 ein Platz je DROME, Molok zwei).
MOUNT_CLASSES = ("light", "medium", "heavy")
EQUIP_CATEGORIES = ("weapon", "shield", "support")
DEFAULT_MOUNT_CLASS = "light"
DEFAULT_CATEGORY = "weapon"


# Nahkampf und Fernkampf (16. Nov. 2026, docs/DROME_DESIGNREGELN.md): die
# Grundattacke entscheidet -- bis 2 Felder Nahkampf, ab 3 Felder Fernkampf.
# Der Generator schreibt daraus das Tag "melee" oder "ranged" an jede
# Ausruestung; ein Halter kann mit ``"reach"`` nur eine der beiden annehmen
# (die Lafette des Strix: nur Fernkampf).
RANGED_FROM = 3
REACH_KINDS = ("melee", "ranged")
BODY_KINDS = ("humanoid", "nonhumanoid")


def reach_kind(part_id: str) -> str:
    """'ranged' ab RANGED_FROM Feldern Reichweite der Grundattacke, sonst 'melee'."""
    actions = part_stats(part_id).get("actions", [])
    reach = int(actions[0].get("range_tiles", 1)) if actions else 1
    return "ranged" if reach >= RANGED_FROM else "melee"


def fits_rule(mount_class: str, category: str, rule: dict | None,
              reach: str | None = None) -> bool:
    """Darf ein Ausruestungsteil in einen Slot mit dieser Regel?"""
    if not rule:
        return True
    if rule.get("off"):
        return False
    limit = rule.get("max_class", MOUNT_CLASSES[-1])
    if MOUNT_CLASSES.index(mount_class) > MOUNT_CLASSES.index(limit):
        return False
    if rule.get("reach") and reach and reach != rule["reach"]:
        return False
    allowed = rule.get("categories")
    return not allowed or category in allowed


# ---------------------------------------------------------------------------
# Spielwerte -- die einzige Balancing-Tabelle des Projekts
# ---------------------------------------------------------------------------
# Bis hierher beschreibt eine Teil-Definition nur, wie ein Teil AUSSIEHT und wo
# es sitzt. Ab hier steht, was es im Kampf TUT. Beides gehoert in dieselbe
# Datei: ein zweites Bauteil-Datenmodell daneben liefe von den Ankern weg.
#
# Die Werte landen ueber ``write_part`` als Block ``stats`` in jeder der vier
# Richtungs-JSONs eines Teils. Sie sind richtungsunabhaengig.
#
# Ein DROME hat KEINE Grundwerte. Jeder Stat ist die Summe seiner Teile.
#
#     body   Chassis   HP, DEF, Schild -- und ueber seine equip_*-Anker die
#                      Zahl der Ausruestungsslots
#     core   Kern      Schildregeneration und -effizienz
#     feet   Antrieb   SPD (= Laufgeschwindigkeit im Echtzeit-Kampf)
#     head   Kopf      kleine Boni
#     equipment        Waffen, Schilde, Support -- gewaehren die Aktionen
#
# Reine Zahlen, keine Logik: der Kampfcode liest ``stats`` aus der JSON.
#
# Aufgeraeumt Nov. 2026 (Autobattler): Energie, MOV, Strom, Traglast, die
# Antriebsflags (Stufen, Drift, Durchlaufen), der Blick durch Haze und die
# Sichtlinie sind raus -- das Spielfeld hat kein Gelaende mehr.

# Vollstaendiger Satz mit Nullwerten. Jedes Teil ueberschreibt nur, was es
# tatsaechlich beitraegt.
STAT_DEFAULTS = {
    # Werte eines DROME (Entscheidung 8. Nov. 2026, docs/IDENTITAETEN.md):
    # Speed (spd), Integritaet (hp), Schild, Schildpuls, Ruestung (def),
    # Power und Modulplaetze. Sie stehen am CHASSIS; Kopf, Antrieb und Kern
    # sind Optik. Waffen geben je einen dieser Werte als Bonus.
    "hp": 0, "spd": 0, "def": 0,
    "shield": 0, "shield_regen": 0, "shield_bonus": 0.0,
    # Schildpuls: EIN Wert fuer die Ruhezeit bis zum Laden und die Ladung je
    # Puls (Formel in data/config.json -> combat.shield_pulse).
    "shield_pulse": 0,
    # Power: Schaden der Waffe x power / 10 (10 = 100 %).
    "power": 0,
    # Effizienz (20. Nov. 2026): Dauer, Stapel und Staerke der Statuseffekte,
    # die der DROME ausloest -- x efficiency / 10 (10 = 100 %). Nie Schaden.
    "efficiency": 0,
    # Modulplaetze je Waffenhalter (nur Chassis).
    "module_slots": 0,
    # Passive Selbstheilung je Puls, in Prozent der maximalen Integritaet.
    "hp_regen_pct": 0,
    # Nur body: wie die KI diesen DROME fuehrt (scripts/battle/ai_controller.gd).
    #   vanguard     Frontlinie: rueckt vor, weicht nie aus (Molok)
    #   skirmisher   wendig: mit Fernwaffe kiten, mit Nahkampfwaffe dranbleiben (Vireo)
    #   sniper       haelt Abstand, weicht nur aus, wenn jemand direkt danebensteht (Strix)
    #   controller   bleibt hinter der Frontlinie, bis sie im Kampf ist (Nimbus)
    "ai_role": "",
    # Nur body: die Passive des DROME (Unit.passive()).
    #   echo         jede Faehigkeit wirkt zweimal, ihr Takt ist 50 % laenger
    #                (Nimbus)
    #   cyberspeed   jeder 3. Angriff gibt einen Stapel Angriffs- und Lauftempo (Vireo)
    #   fortress     Festung: Heilung, Regeneration und Schildgaben am Traeger +20 % (Molok)
    #   steady       Anlegen: nach 4 s ohne Bewegung +20 % Schaden und
    #                Reichweite (Strix)
    # Die Zahlen der Passiven stehen in data/config.json unter "passives".
    "passive": "",
}

# Ausruestung gewaehrt eine LISTE von Aktionen (``actions``): eine Waffe ihren
# Angriff und ihre Faehigkeit, ein Gadget null oder eine Faehigkeit.
#
#   category    attack | ability
#   targeting   single | aoe_around_target | aoe_cross | dash
#   interval    Sekunden zwischen zwei Angriffen (nur Angriffe)
#   trigger     wann eine Faehigkeit selbst ausloest:
#               {"kind": "attacks", "every": n, "weapon": "act_..."}  jeder n-te Angriff
#               {"kind": "time", "every": s}                          alle s Sekunden
#               {"kind": "adjacent", "every": s}                      Gegner daneben


STATS = {
    # --- CHASSIS (body) ----------------------------------------------------
    # Alle Werte des DROME stehen hier (8. Nov. 2026). ATK und Gewicht
    # gibt es nicht mehr.
    # Vireo: der schnelle Allrounder, nur eine leichte Waffe.
    "scout_body":  {"spd": 12, "hp":  80, "shield": 50, "shield_pulse":  7, "def":  2,
                    "power": 10, "efficiency": 10, "module_slots": 3,
                    "ai_role": "skirmisher", "passive": "cyberspeed"},
    # Molok: der harte Zweihaender fuer die Frontlinie, wenig Power.
    "jugg_body":   {"spd": 10, "hp": 250, "shield": 50, "shield_pulse":  3, "def": 10,
                    "power":  6, "efficiency": 14, "module_slots": 2,
                    "ai_role": "vanguard", "passive": "fortress"},
    # Nimbus: fragil, schildlastig, Richtung Faehigkeiten.
    "mage_body":   {"spd": 12, "hp":  60, "shield": 60, "shield_pulse": 10, "def":  0,
                    "power": 12, "efficiency": 12, "module_slots": 3,
                    "ai_role": "controller", "passive": "echo"},
    # Strix: Langstrecke, langsam, viel Power.
    "strix_body":  {"spd":  7, "hp": 100, "shield": 30, "shield_pulse":  5, "def":  2,
                    "power": 15, "efficiency": 10, "module_slots": 3,
                    "ai_role": "sniper", "passive": "steady"},

    # --- KERN, ANTRIEB, KOPF -------------------------------------------------
    # Nur noch Optik am Chassis -- keine Werte.
    "scout_core": {}, "jugg_core": {}, "mage_core": {}, "strix_core": {},
    "scout_feet": {}, "jugg_feet": {}, "mage_drive": {}, "strix_feet": {},
    "scout_head": {}, "jugg_head": {}, "mage_head": {}, "strix_head": {},

    # --- AUSRUESTUNG (equipment) -------------------------------------------
    # Seit 8. Nov. 2026 (docs/IDENTITAETEN.md): jede Waffe gibt EINEN
    # DROME-Wert als Bonus; der Schaden ihrer Faehigkeit ist ein fester Anteil
    # des Waffenschadens (damage_pct), so steigt sie mit dem Waffenlevel mit.
    # Puls-Blaster: 5 kinetisch + 5 Energie, Bonus Speed.
    "eq_pulse_blaster": {
        "spd": 2,
        "actions": [
            # Halb physisch, halb Energie.
            {"id": "act_pulse", "display_name": "Angriff",
             "category": "attack", "targeting": "single",
             "range_tiles": 3, "power": 10, "energy_fraction": 0.5,
             "interval": 1.4},
            # Doppelschuss (Vorgabe des Spielers, Nov. 2026): ein schneller
            # Schuss auf bis zu zwei Gegner in Reichweite; ist nur einer da,
            # trifft er ihn zweimal.
            {"id": "act_pulse_double", "windup": 0.25, "display_name": "Doppelschuss",
             "category": "ability", "targeting": "single",
             "range_tiles": 3, "damage_pct": 0.7, "shots": 2,
             # Zwei Salven zu je 3 Schuessen mit je 1/3 Schaden (Spieler
             # 18. Nov. 2026): erst aufs Ziel, dann auf den naechsten Gegner.
             "salvo": 3,
             "energy_fraction": 0.5,
             "trigger": {"kind": "attacks", "every": 3, "weapon": "act_pulse"}},
        ],
    },
    # Plasmaklinge: Nahkampf, nur kinetisch, etwas mehr Schaden, schneller als
    # der Blaster. Jeder 3. Hieb macht das Ziel 5 s verwundbar (+50 % Schaden).
    # Bonus Power (+1 = +10 %) -- damit auch fuer den Molok interessant.
    "eq_plasma_blade": {
        "power": 1,
        "actions": [
            {"id": "act_plasma_slash", "display_name": "Angriff",
             "category": "attack", "targeting": "single",
             "range_tiles": 1, "power": 12, "interval": 1.0},
            {"id": "act_plasma_rend", "windup": 0.3, "display_name": "Aufschlitzen",
             "category": "ability", "targeting": "single",
             "range_tiles": 1, "damage_pct": 1.5,
             "status": {"id": "vulnerable", "seconds": 5.0, "damage_taken_mult": 1.5},
             "trigger": {"kind": "attacks", "every": 3, "weapon": "act_plasma_slash"}},
        ],
    },
    # Passiv.
    # Schutz-Waffe (7. Nov. 2026): schwacher Stoss, jeder 4. Angriff laedt
    # den eigenen Schild um 15 (auch ueber das Maximum).
    # Schild, mittel (8. Nov. 2026). Bonus Ruestung.
    "eq_deflector": {
        "def": 4,
        "actions": [
            {"id": "act_deflector_bash", "display_name": "Angriff",
             "category": "attack", "targeting": "single",
             "range_tiles": 1, "power": 6, "interval": 1.5},
            {"id": "act_deflector_charge", "windup": 0.25, "display_name": "Schildladung",
             "category": "ability", "targeting": "single",
             "range_tiles": 0, "power": 0, "shield_gain": 15, "support": "self",
             "trigger": {"kind": "attacks", "every": 4, "weapon": "act_deflector_bash"}},
        ],
    },

    # Mittel (8. Nov. 2026). Bonus Integritaet.
    "eq_hammer": {
        "hp": 20,
        "actions": [
            {"id": "act_hammer", "display_name": "Angriff",
             "category": "attack", "targeting": "single",
             "range_tiles": 1, "power": 16, "interval": 1.8},
            # Seit 27. Nov. 2026 (Spieler): +20 % der eigenen maximalen
            # Integritaet als Schaden, und der Schlag heilt den Molok um 100 %
            # des Schadens. Kinetisch wie der Angriff.
            {"id": "act_hammer_stun", "windup": 0.35, "display_name": "Betaeubungsschlag",
             "category": "ability", "targeting": "single",
             "range_tiles": 1, "damage_pct": 1.0, "hp_scaling": 0.2, "lifesteal": 1.0,
             "status": {"id": "stun", "seconds": 1.0, "stunned": True},
             "trigger": {"kind": "attacks", "every": 3, "weapon": "act_hammer"}},
        ],
    },

    # Kontrollwaffe des Nimbus: Einzelschuss auf Blaster-Reichweite, reine
    # Energie. Die Faehigkeit (Vortex) zieht die Gegner um das Ziel zusammen,
    # kurz danach schlaegt eine Schockwelle von innen nach aussen zu und
    # verlangsamt (Vorgabe des Spielers, Nov. 2026).
    # Bonus Schild.
    "eq_rune_staff": {
        "shield": 10,
        "actions": [
            {"id": "act_runestaff", "display_name": "Angriff",
             "category": "attack", "targeting": "single",
             "range_tiles": 3, "power": 9,
             "energy_fraction": 1.0, "interval": 1.2},
            {"id": "act_rune_vortex", "windup": 0.95, "display_name": "Vortex",
             "category": "ability", "targeting": "aoe_around_target",
             "range_tiles": 5, "aoe_radius": 2, "damage_pct": 1.5,
             "energy_fraction": 1.0, "gather": True, "delay": 0.6,
             "status": {"id": "slow", "seconds": 2.5, "move_mult": 0.6},
             # Seit 9. Nov. 2026 nach Angriffen statt alle 3 s (Vorgabe des
             # Spielers: Takt immer ueber Angriffe).
             "trigger": {"kind": "attacks", "every": 3, "weapon": "act_runestaff"}},
        ],
    },
    "eq_rail_lance": {
        "power": 1,
        "actions": [
            {"id": "act_raillance", "display_name": "Angriff",
             "category": "attack", "targeting": "single",
             "range_tiles": 8, "power": 22,
             "interval": 2.6},
            {"id": "act_rail_pierce", "windup": 0.55, "display_name": "Praezisionsschuss",
             "category": "ability", "targeting": "single",
             "range_tiles": 8, "damage_pct": 1.2,
             "trigger": {"kind": "attacks", "every": 4, "weapon": "act_raillance"}},
        ],
    },
}

ACTION_DEFAULTS = {
    "id": "", "display_name": "", "category": "attack", "targeting": "single",
    "range_tiles": 1, "aoe_radius": 0, "power": 0,
    # positiv = wegstossen, negativ = heranziehen
    "push_tiles": 0,
    # Anteil Energieschaden (0.0 physisch, 1.0 Energie). Energie knackt
    # Schilde (120 %), Physisch prallt ab (80 %).
    "energy_fraction": 0.0,
    "interval": 2.0,
    "trigger": None,
    # Treffer je Ausloesen: verteilt auf bis zu so viele Gegner in Reichweite,
    # der Rest geht wieder aufs Ziel (Doppelschuss).
    "shots": 1,
    # Flaeche: zieht die Gegner im Radius zuerst zum Zielfeld heran.
    "gather": False,
    # Sekunden zwischen Ausloesen und Schaden (Schockwelle nach dem Sog).
    "delay": 0.0,
    # Statuseffekt auf jeden Getroffenen: {"id", "seconds", ...Aufschlaege},
    # z. B. {"id": "slow", "seconds": 2.5, "move_mult": 0.6}.
    "status": None,
    # Unterstuetzung (7. Nov. 2026): heal repariert Integritaet, shield_gain
    # gibt Schild; support = "self" (Traeger) oder "ally" (Verbuendeter mit dem
    # geringsten Anteil Integritaet). Ein Angriff mit heal schiesst auf
    # Gegner, wenn niemand verletzt ist.
    "heal": 0,
    "shield_gain": 0,
    "support": "",
    # Faehigkeitsschaden als Anteil des Waffenschadens (8. Nov. 2026): power
    # wird daraus berechnet -- aus dem Angriff, den trigger.weapon nennt, oder
    # aus base_action (Faehigkeiten nach Zeit).
    "damage_pct": 0.0,
    "base_action": "",
    # hp_scaling   Zusatzschaden als Anteil der EIGENEN maximalen Integritaet,
    #              ohne Power (Hammer-Betaeubungsschlag)
    "hp_scaling": 0.0,
    # lifesteal    der Treffer heilt den Traeger um diesen Anteil des Schadens
    #              (Hammer-Betaeubungsschlag 1,0, 27. Nov. 2026)
    "lifesteal": 0.0,
    # Ausholzeit (18. Nov. 2026): Sekunden zwischen Ansage und Wirkung einer
    # Faehigkeit -- der DROME steht still, die Ansage ist zu sehen.
    "windup": 0.0,
    # Mehrfachschuss in Salven: so viele schnelle Schuesse je "shots", jeder
    # mit dem entsprechenden Anteil Schaden (Doppelschuss, 18. Nov. 2026).
    "salvo": 1,
}

TARGETINGS = ("single", "aoe_around_target", "aoe_cross", "dash")


def _merge_action(part_id: str, action: dict) -> dict:
    """Eine rohe Aktion auf volle Defaults bringen und die Regeln pruefen."""
    unknown = set(action) - set(ACTION_DEFAULTS)
    if unknown:
        raise SystemExit(f"[stats] {part_id}: unbekannte Aktionsfelder {sorted(unknown)}")
    merged = dict(ACTION_DEFAULTS)
    merged.update(action)
    if merged["targeting"] not in TARGETINGS:
        raise SystemExit(f"[stats] {part_id}: unbekanntes Targeting {merged['targeting']!r}")
    return merged


def part_stats(part_id: str) -> dict:
    """Vollstaendiger Statblock eines Teils: Defaults plus seine Abweichungen."""
    raw = STATS.get(part_id, {})
    unknown = set(raw) - set(STAT_DEFAULTS) - {"actions"}
    if unknown:
        raise SystemExit(f"[stats] {part_id}: unbekannte Felder {sorted(unknown)}")

    stats = dict(STAT_DEFAULTS)
    stats.update({k: v for k, v in raw.items() if k != "actions"})

    # Ein Teil gewaehrt eine LISTE von Aktionen (Angriff und/oder Faehigkeit).
    # Ohne ``actions`` ist es passiv -- die Liste bleibt leer.
    stats["actions"] = [_merge_action(part_id, a) for a in raw.get("actions", [])]
    by_id = {a["id"]: a for a in stats["actions"]}
    for action in stats["actions"]:
        if action["damage_pct"] <= 0:
            continue
        base_id = action["base_action"] or (action["trigger"] or {}).get("weapon", "")
        if base_id not in by_id:
            raise SystemExit(f"[stats] {part_id}/{action['id']}: damage_pct ohne Grundangriff")
        action["base_action"] = base_id
        action["power"] = int(round(by_id[base_id]["power"] * action["damage_pct"]))
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


def O(center, size, rot, mat):
    """
    Gedrehter Quader: Mitte (f, l, z), Kantenlaengen (df, dl, dz) und
    Drehung (gier, nick, roll) in Grad.

        gier  um die Hochachse z  (positiv: Vorderseite dreht nach links, +l)
        nick  um die Querachse l  (positiv: Vorderseite kippt nach UNTEN)
        roll  um die Laengsachse f (positiv: linke Seite kippt nach oben)

    Reihenfolge: erst roll, dann nick, dann gier. Damit fallen schraege
    Klingen, Hoerner und Umhaenge glatt statt in Stufen aus.
    """
    return ("obox", tuple(center), tuple(size), tuple(rot), mat)


def OB(p0, p1, width, height, mat, roll=0.0):
    """
    Balken von Punkt p0 nach p1 (je (f, l, z)) als gedrehter Quader:
    ``width`` quer zur Laufrichtung waagerecht, ``height`` senkrecht dazu,
    ``roll`` dreht den Balken um seine eigene Laengsachse.
    """
    d = [b - a for a, b in zip(p0, p1)]
    length = math.sqrt(sum(c * c for c in d))
    yaw = math.degrees(math.atan2(d[1], d[0]))
    pitch = -math.degrees(math.atan2(d[2], math.hypot(d[0], d[1])))
    mid = tuple((a + b) / 2.0 for a, b in zip(p0, p1))
    return O(mid, (length, width, height), (yaw, pitch, roll), mat)


def BP(back, tip, width, thick, mat, mid=0.18):
    """
    Doppelpyramide (18. Nov. 2026): zwei Pyramiden Ruecken an Ruecken -- eine
    Klinge. Von ``back`` (kurze Spitze, steckt im Heft) nach ``tip`` (lange
    Spitze); die breiteste Stelle liegt bei ``mid`` (Anteil der Laenge). Der
    Querschnitt ist eine Raute: ``width`` quer zur Klinge waagerecht (l),
    ``thick`` die Dicke senkrecht dazu. Grat und Schneide entstehen aus den
    Flaechen selbst -- keine Stufen.
    """
    d = [b - a for a, b in zip(back, tip)]
    length = math.sqrt(sum(c * c for c in d))
    axis = [c / length for c in d]
    # Querachsen: "side" moeglichst waagerecht (l), "front" senkrecht zu beiden.
    up = (0.0, 1.0, 0.0) if abs(axis[1]) < 0.9 else (1.0, 0.0, 0.0)
    side = _norm(_reject(up, axis))
    front = _norm(_cross(side, axis))
    m = [a + c * length * mid for a, c in zip(back, axis)]
    corners = [tuple(mc + sc * width / 2.0 for mc, sc in zip(m, side)),
               tuple(mc + fc * thick / 2.0 for mc, fc in zip(m, front)),
               tuple(mc - sc * width / 2.0 for mc, sc in zip(m, side)),
               tuple(mc - fc * thick / 2.0 for mc, fc in zip(m, front))]
    center = tuple(m)
    faces = []
    for apex in (tuple(tip), tuple(back)):
        for i in range(4):
            tri = [apex, corners[i], corners[(i + 1) % 4]]
            n = _norm(_cross(_sub(tri[1], tri[0]), _sub(tri[2], tri[0])))
            mid_tri = [sum(c) / 3.0 for c in zip(*tri)]
            if sum(nc * (tc - cc) for nc, tc, cc in zip(n, mid_tri, center)) < 0:
                tri = [tri[0], tri[2], tri[1]]
                n = tuple(-c for c in n)
            faces.append((tuple(n), [tuple(pt) for pt in tri]))
    return ("poly", tuple(faces), mat)


def EX(profile, l, mat, bevel=0.0, axis="l"):
    """
    Profil (18. Nov. 2026): ein Umriss in der Seitenansicht -- Punkte (f, z),
    auch eingebuchtet -- wird quer von ``l[0]`` bis ``l[1]`` gezogen. Fuer
    Schaefte, Gehaeuse, Klingen mit echtem Umriss statt Quaderstapeln.
    ``bevel`` schraegt die Kanten der beiden Deckflaechen ab (Fase).
    ``axis`` sagt, wohin gezogen wird: "l" (Standard, Umriss = Seitenansicht
    (f, z)), "f" (Umriss = Vorderansicht (l, z), z. B. ein V-Torso) oder "z"
    (Umriss = Grundriss (f, l), z. B. flache Fluegel).
    Ergibt einen Vielflach ("poly"); Seitenwaende und Fasen tragen die dunkle
    Kante wie Quader, die Deckflaechen nicht (sie sind in Dreiecke zerlegt).
    """
    pts = [(float(f), float(z)) for f, z in profile]
    area = sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(pts, pts[1:] + pts[:1]))
    if area < 0:
        pts.reverse()                       # gegen den Uhrzeigersinn
    l0, l1 = float(l[0]), float(l[1])
    b = max(0.0, min(float(bevel), (l1 - l0) / 2.0 - 1e-3))
    inner = _inset(pts, b) if b > 0 else pts
    faces = []
    ca = sum(a for a, _b in pts) / len(pts)
    cb = sum(b for _a, b in pts) / len(pts)
    cm = (l0 + l1) / 2.0

    def p3(ab, lv):
        if axis == "f":
            return (lv, ab[0], ab[1])
        if axis == "z":
            return (ab[0], ab[1], lv)
        return (ab[0], lv, ab[1])

    center = p3((ca, cb), cm)

    def add(poly, edge):
        n = _norm(_cross(_sub(poly[1], poly[0]), _sub(poly[2], poly[0])))
        mid = [sum(x) / len(poly) for x in zip(*poly)]
        if sum(nc * (mc - cc) for nc, mc, cc in zip(n, mid, center)) < 0:
            poly = list(reversed(poly))
            n = tuple(-x for x in n)
        faces.append((tuple(n), [tuple(pt) for pt in poly], edge))

    # Deckflaechen (Fase: eingerueckt)
    for lv in (l0, l1):
        for tri in _ear_clip(inner):
            add([p3(fz, lv) for fz in tri], False)
    n = len(pts)
    for i in range(n):
        a, c = pts[i], pts[(i + 1) % n]
        add([p3(a, l0 + b), p3(c, l0 + b), p3(c, l1 - b), p3(a, l1 - b)], True)
        if b > 0:
            ia, ic = inner[i], inner[(i + 1) % n]
            add([p3(ia, l0), p3(ic, l0), p3(c, l0 + b), p3(a, l0 + b)], True)
            add([p3(a, l1 - b), p3(c, l1 - b), p3(ic, l1), p3(ia, l1)], True)
    return ("poly", tuple(faces), mat)


def _inset(pts, d):
    """Umriss (gegen den Uhrzeigersinn) um ``d`` nach innen versetzt."""
    out = []
    n = len(pts)
    for i in range(n):
        a, p, c = pts[i - 1], pts[i], pts[(i + 1) % n]
        e1 = _norm((p[0] - a[0], p[1] - a[1], 0.0))
        e2 = _norm((c[0] - p[0], c[1] - p[1], 0.0))
        n1 = (-e1[1], e1[0])
        n2 = (-e2[1], e2[0])
        dot = n1[0] * n2[0] + n1[1] * n2[1]
        k = d / max(0.25, 1.0 + dot)
        out.append((p[0] + (n1[0] + n2[0]) * k, p[1] + (n1[1] + n2[1]) * k))
    return out


def _ear_clip(pts):
    """Einfaches Polygon (gegen den Uhrzeigersinn) -> Dreiecke."""
    idx = list(range(len(pts)))
    tris = []

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    def inside(pt, a, b, c):
        return cross(a, b, pt) >= 0 and cross(b, c, pt) >= 0 and cross(c, a, pt) >= 0

    guard = 0
    while len(idx) > 3 and guard < 10000:
        guard += 1
        for j in range(len(idx)):
            i0, i1, i2 = idx[j - 1], idx[j], idx[(j + 1) % len(idx)]
            a, b, c = pts[i0], pts[i1], pts[i2]
            if cross(a, b, c) <= 1e-9:
                continue
            if any(inside(pts[k], a, b, c) for k in idx if k not in (i0, i1, i2)):
                continue
            tris.append((a, b, c))
            idx.pop(j)
            break
        else:
            break
    if len(idx) == 3:
        tris.append(tuple(pts[i] for i in idx))
    return tris


def SW(points, radii, mat, sides=8, flat=1.0, steps=6, side=(0.0, 1.0, 0.0), caps=True):
    """
    Zug (18. Nov. 2026): ein Querschnitt faehrt eine glatte Kurve entlang --
    fuer Kabel, Schlaeuche und gebogene Klingen.

    ``points``  Stuetzpunkte (f, l, z); die Kurve laeuft als Catmull-Rom
                durch alle hindurch, ``steps`` Abschnitte je Stueck.
    ``radii``   Halbmesser je Stuetzpunkt (dazwischen weich verlaufen);
                0 am Ende = Spitze.
    ``sides``   Ecken des Querschnitts: 8 rund (Kabel), 4 Raute (Klinge).
    ``flat``    Stauchung des Querschnitts entlang ``side`` (Standard l):
                0,25 = flache Klinge, die in der f-z-Ebene breit ist.
    Ergibt einen Vielflach ("poly") -- Spiegeln, Rendern und 3D wie beim
    Doppelpyramiden-Baustein BP.
    """
    pts = [tuple(float(c) for c in pt) for pt in points]
    curve, rad = [], []
    for i in range(len(pts) - 1):
        p0 = pts[max(0, i - 1)]
        p1, p2 = pts[i], pts[i + 1]
        p3 = pts[min(len(pts) - 1, i + 2)]
        for j in range(steps):
            t = j / steps
            t2, t3 = t * t, t * t * t
            curve.append(tuple(0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2
                                      + (-a + 3 * b - 3 * c + d) * t3)
                               for a, b, c, d in zip(p0, p1, p2, p3)))
            r0, r1 = radii[i], radii[i + 1]
            u = t * t * (3 - 2 * t)
            rad.append(r0 + (r1 - r0) * u)
    curve.append(pts[-1])
    rad.append(radii[-1])
    rings = []
    for i, c in enumerate(curve):
        a = curve[max(0, i - 1)]
        b = curve[min(len(curve) - 1, i + 1)]
        tangent = _norm(_sub(b, a))
        n = _reject(side, tangent)
        if math.sqrt(sum(x * x for x in n)) < 1e-4:
            n = _reject((0.0, 0.0, 1.0), tangent)
        n = _norm(n)
        bi = _norm(_cross(tangent, n))
        ring = []
        for k in range(sides):
            ang = 2 * math.pi * k / sides
            ring.append(tuple(cc + rad[i] * (math.cos(ang) * flat * nc + math.sin(ang) * bc)
                              for cc, nc, bc in zip(c, n, bi)))
        rings.append(ring)
    faces = []

    def add(poly, inside):
        """Normale nach aussen (weg von ``inside``)."""
        n = _norm(_cross(_sub(poly[1], poly[0]), _sub(poly[2], poly[0])))
        mid = [sum(x) / len(poly) for x in zip(*poly)]
        if sum(nc * (mc - ic) for nc, mc, ic in zip(n, mid, inside)) < 0:
            poly = list(reversed(poly))
            n = tuple(-x for x in n)
        faces.append((tuple(n), [tuple(pt) for pt in poly]))

    for i in range(len(rings) - 1):
        inside = tuple((x + y) / 2 for x, y in zip(curve[i], curve[i + 1]))
        for k in range(sides):
            quad = [rings[i][k], rings[i][(k + 1) % sides],
                    rings[i + 1][(k + 1) % sides], rings[i + 1][k]]
            if rad[i] < 1e-6:
                quad = [quad[0], quad[2], quad[3]]
            elif rad[i + 1] < 1e-6:
                quad = quad[:3]
            add(quad, inside)
    if caps:
        for end, nxt in ((0, 1), (len(rings) - 1, len(rings) - 2)):
            if rad[end] > 1e-6:
                add(list(rings[end]), curve[nxt])
    return ("poly", tuple(faces), mat)


def _sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _norm(v):
    n = math.sqrt(sum(c * c for c in v)) or 1.0
    return tuple(c / n for c in v)


def _reject(v, axis):
    """``v`` ohne seinen Anteil entlang ``axis``."""
    dot = sum(a * b for a, b in zip(v, axis))
    return tuple(a - dot * b for a, b in zip(v, axis))


def mirror_poly(s):
    """Vielflach an l = 0 gespiegelt (Punkte und Normalen)."""
    _, faces, mat = s
    return ("poly", tuple(((f[0][0], -f[0][1], f[0][2]),
                           [(pt[0], -pt[1], pt[2]) for pt in f[1]]) + tuple(f[2:])
                          for f in faces), mat)


def _rot_matrix(rot):
    """Drehmatrix (Zeilen) aus (gier, nick, roll) in Grad: Rz * Rl * Rf."""
    gy, ni, ro = (math.radians(a) for a in rot)
    cg, sg = math.cos(gy), math.sin(gy)
    cn, sn = math.cos(ni), math.sin(ni)
    cr, sr = math.cos(ro), math.sin(ro)
    rz = ((cg, -sg, 0), (sg, cg, 0), (0, 0, 1))
    # nick positiv = Spitze nach unten: Drehung um +l mit +Winkel hebt f nach -z
    rl = ((cn, 0, sn), (0, 1, 0), (-sn, 0, cn))
    rf = ((1, 0, 0), (0, cr, -sr), (0, sr, cr))

    def mul(a, b):
        return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3))
                     for i in range(3))
    return mul(rz, mul(rl, rf))


def _apply(m, v):
    return tuple(m[i][0] * v[0] + m[i][1] * v[1] + m[i][2] * v[2] for i in range(3))


def _obox_faces(center, size, rot):
    """Sechs Flaechen eines gedrehten Quaders als (lokale Normale, Eckpunkte)."""
    m = _rot_matrix(rot)
    hf, hl, hz = (s / 2.0 for s in size)
    out = []
    for normal, points in _box_faces((-hf, hf), (-hl, hl), (-hz, hz)):
        n = _apply(m, normal)
        pts = [tuple(c + d for c, d in zip(center, _apply(m, p))) for p in points]
        out.append((n, pts))
    return out


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
    if kind == "obox":
        return _obox_faces(*shape[1:4])
    if kind == "poly":
        return [(face[0], list(face[1])) for face in shape[1]]
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
        elif shape[0] == "obox":
            for local_normal, points in _obox_faces(*shape[1:4]):
                emitted = _emit(points, to_world(local_normal, facing), shape[4], facing)
                if emitted:
                    faces.append(emitted)
        elif shape[0] == "poly":
            for face in shape[1]:
                # Ohne Kantenflag (Dreiecke, Facetten): Strich in Eigenfarbe,
                # damit keine Fugen zwischen den Teilflaechen erscheinen.
                edge = len(face) > 2 and face[2]
                emitted = _emit(list(face[1]), to_world(face[0], facing), shape[2], facing,
                                seam=not edge)
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
# Chassis nach den DROME-Designregeln (16. Nov. 2026, Entwurf
# docs/design/drome_entwurf/v4.py): V-Torso mit schlanker Taille, Helm mit
# Visier und Kamm. Die Passive Sprint ist sichtbar: grosser Ruecken-Booster
# mit Fluegeln und Duesen, dazu zwei Helm-Booster. Der freie Arm (rechts, -l)
# liegt am Koerper an und gehoert zum Rumpf; der Waffenarm kommt mit der
# Waffe und haengt an der Schulter (equip_left).
#
# Hoehenprofil in Entwurfseinheiten:
#   Fuesse 0..6   Beine 6..35   Huefte 34..39   Taille 39..45   Torso 45..62
#   Schultern 54..64   Hals 62..65   Kopf 65..77   Kamm bis 81
# ===========================================================================

def mirror_obox(s):
    """Gedrehter Quader an l = 0 gespiegelt: gier und roll kehren sich um."""
    _, (f, l, z), size, (gy, ni, ro), mat = s
    return ("obox", (f, -l, z), size, (-gy, ni, -ro), mat)


def _mirror_l(shapes):
    """Spiegelt Formen an l = 0 (fuer Beinpaare und Fluegel)."""
    out = []
    for s in shapes:
        if s[0] == "box":
            _, f, l, z, mat = s
            out.append(("box", f, (-l[1], -l[0]), z, mat))
        elif s[0] == "obox":
            out.append(mirror_obox(s))
        elif s[0] == "poly":
            out.append(mirror_poly(s))
        elif s[0] == "disc":
            _, f, lc, zc, r, mat, seg = s
            out.append(("disc", f, -lc, zc, r, mat, seg))
        else:
            _, c, prof, mat, axis, seg, caps = s
            if axis == "z":
                out.append(("lathe", (c[0], -c[1]), prof, mat, axis, seg, caps))
            elif axis == "f":
                out.append(("lathe", (-c[0], c[1]), prof, mat, axis, seg, caps))
            else:
                out.append(("lathe", c, tuple((r, -p) for r, p in reversed(prof)),
                            mat, axis, seg, caps))
    return out


_SCOUT_LEG = [
    B((-3.5, 3.5), (3.5, 8), (24, 35), "plate"),         # Oberschenkel
    B((-4, 4), (3, 8.5), (20, 24), "metal"),             # Knie
    B((3.5, 5.5), (3.8, 7.7), (19, 27), "light"),        # Knieschutz
    B((-3, 3.5), (3.8, 7.7), (6, 20), "plate"),          # Schienbein
    B((-6, 7), (3.5, 8), (0, 6), "plate"),               # Fuss
    B((7, 10.5), (4.2, 7.3), (0, 3.5), "dark"),          # spitze Kappe
    B((-8.5, -6), (4.5, 7), (1, 5), "metal"),            # Ferse
    B((7, 7.5), (4.5, 7), (3.5, 5), "accent"),
]

SCOUT_BODY = [
    # -- Huefte, schlanke Taille, V-Torso ----------------------------------
    B((-5, 5), (-8.5, 8.5), (34, 39), "metal"),
    B((-4.5, 5), (-6, 6), (39, 45), "dark"),
    # V-Torso als Profil der Vorderansicht, nach vorn gezogen, mit Fase
    # (18. Nov. 2026) -- statt zweier gestufter Quader.
    EX([(-8.6, 45), (8.6, 45), (11.2, 52), (11.4, 59), (10, 60.6), (-10, 60.6),
        (-11.4, 59), (-11.2, 52)], (-6.4, 8), "plate", bevel=0.8, axis="f"),
    EX([(-9.8, 60.4), (9.8, 60.4), (9.0, 62), (-9.0, 62)], (-6, 7.5), "light",
       bevel=0.4, axis="f"),                                          # Brustdach
    # Brustplatte mit Kernsockel -- der Sockel traegt den Kern bis in seine
    # aeussersten Energiestreifen.
    B((8, 8.6), (-6.5, 6.5), (45.5, 59), "dark"),
    B((8.6, 9.2), (-6.2, 6.2), (45.8, 56), "dark"),
    B((8.6, 9.1), (-6, -1.2), (56.4, 57.8), "accent"),
    B((8.6, 9.1), (1.2, 6), (56.4, 57.8), "accent"),
    # -- Schultern ---------------------------------------------------------
    EX([(-5.5, 54), (5.5, 54), (5.5, 60.5), (4, 62), (-5.5, 62)], (11, 17), "plate", bevel=0.6),
    EX([(-6, 62), (4.5, 62), (3.5, 64), (-6, 64)], (10.5, 17.5), "light", bevel=0.35),
    B((5.5, 6), (12, 16), (57, 59), "accent"),
    EX([(-5.5, 54), (5.5, 54), (5.5, 60.5), (4, 62), (-5.5, 62)], (-17, -11), "plate", bevel=0.6),
    EX([(-6, 62), (4.5, 62), (3.5, 64), (-6, 64)], (-17.5, -10.5), "light", bevel=0.35),
    B((5.5, 6), (-16, -12), (57, 59), "accent"),
    # -- Hals --------------------------------------------------------------
    B((-2.5, 2.5), (-3, 3), (62, 65), "metal"),
    # -- Freier Arm (-l): liegt am Koerper an, traegt nie eine Waffe -------
    B((-2.5, 2.5), (-16.5, -12.5), (45, 54), "metal"),   # Oberarm
    B((-3, 3), (-15.5, -11.5), (34, 45), "plate"),       # Unterarm
    B((3, 3.5), (-14.5, -12.5), (39, 41), "accent"),
    # Hand (nur dieser Arm hat eine: er traegt nie etwas)
    B((-2.2, 1.0), (-15.2, -12.2), (29.8, 34), "dark"),   # Handruecken
    B((1.0, 3.0), (-15.0, -12.4), (31.7, 33.2), "plate"), # Finger
    B((1.0, 3.0), (-15.0, -12.4), (30.0, 31.5), "light"),
    B((-0.8, 2.0), (-12.4, -11.3), (31.5, 33.6), "plate"), # Daumen
    # -- Passive Sprint: Ruecken-Booster mit Fluegeln und Duesen -----------
    EX([(-7, 44), (-12.5, 45.5), (-13.5, 52), (-13.5, 60), (-12, 62), (-7, 62)],
       (-6.5, 6.5), "plate", bevel=0.6),
    B((-13.5, -6.5), (-7, 7), (62, 64), "light"),
    L((-12, 4), [(2.4, 40), (2.8, 44)], "metal", segments=12),
    L((-12, -4), [(2.4, 40), (2.8, 44)], "metal", segments=12),
    L((-12, 4), [(1.9, 36.5), (1.9, 40)], "glow", segments=10),
    L((-12, -4), [(1.9, 36.5), (1.9, 40)], "glow", segments=10),
    # Fluegel nach hinten gepfeilt (Grundriss, nach oben gezogen)
    EX([(-8, 6.4), (-11.5, 6.4), (-15.5, 14.5), (-13.8, 15)], (55, 56.8), "light",
       bevel=0.3, axis="z"),
    EX([(-8, -6.4), (-11.5, -6.4), (-15.5, -14.5), (-13.8, -15)], (55, 56.8), "light",
       bevel=0.3, axis="z"),
    EX([(-11.2, 7.5), (-12, 7.5), (-15.2, 14), (-14.6, 14.3)], (56.8, 57.2), "accent", axis="z"),
    EX([(-11.2, -7.5), (-12, -7.5), (-15.2, -14), (-14.6, -14.3)], (56.8, 57.2), "accent", axis="z"),
    B((-13.6, -13), (-3, 3), (48, 58), "accent"),
]

SCOUT_HEAD = [
    B((-5, 5.5), (-5.5, 5.5), (65, 74), "plate"),        # Helm
    B((-5.5, 5), (-6, 6), (74, 76), "light"),            # Helmdach
    B((5.5, 7), (-4.5, 4.5), (65.5, 71.5), "dark"),      # Visierrahmen
    B((7, 7.5), (-4, 4), (68.2, 70.4), "visor"),
    B((-4, 2), (5.5, 6.8), (67, 75), "metal"),           # Wangen
    B((-4, 2), (-6.8, -5.5), (67, 75), "metal"),
    B((-1, 2), (5.6, 7), (75, 77), "accent"),
    B((-1, 2), (-7, -5.6), (75, 77), "accent"),
    B((-6, 4), (-0.8, 0.8), (76, 81), "accent"),         # Kamm
    # Helm-Booster (Passive Sprint)
    B((-7.5, -4.5), (2.5, 5), (68, 76), "metal"),
    B((-7.5, -4.5), (-5, -2.5), (68, 76), "metal"),
    B((-7.6, -4.4), (2.4, 5.1), (66, 68), "glow"),
    B((-7.6, -4.4), (-5.1, -2.4), (66, 68), "glow"),
]

SCOUT_FEET = _SCOUT_LEG + _mirror_l(_SCOUT_LEG)

# Impulskern: eine Scheibe, buendig im Kernsockel der Brustplatte (Front 9.2).
# Scheiben haben keine Tiefe -- deshalb bleibt hier nur zu pruefen, dass die
# vier Energiestreifen nicht ueber den Sockel hinausragen.
SCOUT_CORE = [
    D(9.3, 0, 51, 4.4, "dark"),
    D(9.45, 0, 51, 2.6, "glow"),
    B((9.45, 9.6), (-0.5, 0.5), (54.6, 55.8), "accent"),
    B((9.45, 9.6), (-0.5, 0.5), (46.2, 47.4), "accent"),
    B((9.45, 9.6), (-5.9, -4.7), (50.5, 51.5), "accent"),
    B((9.45, 9.6), (4.7, 5.9), (50.5, 51.5), "accent"),
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
# Kabelschlaeuche an den Auspuff-Leuchtfeuern (18. Nov. 2026, Wunsch des
# Spielers: passt ins Cyber-Setting). Je Seite zwei Schlaeuche (Zug): einer
# vom Stapel im Bogen hinten hinunter in den Ruecken, einer hinueber zur
# Schulterplatte; Muffen an beiden Enden.
_JUGG_HOSES = [
    SW([(-11.4, 8.6, 66.5), (-15.5, 11, 61), (-14.2, 10.5, 52), (-9.6, 8.5, 46.5)],
       [1.6, 1.6, 1.6, 1.6], "metal", sides=10, steps=6),
    SW([(-11.7, 8.6, 66.5), (-16.9, 11.4, 61), (-15.6, 10.9, 52), (-10.6, 8.5, 46.5)],
       [0.45, 0.45, 0.45, 0.45], "glow", sides=6, steps=6),
    SW([(-11.2, 6.4, 69), (-16, 5.2, 63), (-15.6, 4.5, 52), (-9.6, 4, 42)],
       [1.0, 1.0, 1.0, 1.0], "dark", sides=8, steps=6),
    SW([(-9.8, 10.4, 70), (-12.5, 13.5, 71), (-10.2, 16.5, 67)],
       [1.1, 1.1, 1.1], "dark", sides=8, steps=5),
    B((-10.8, -9), (6.6, 10.4), (44.6, 48.4), "dark"),                # Muffen
    B((-10.6, -9), (2.6, 5.4), (40.5, 43.5), "dark"),
    L((-11.4, 8.6), [(2.0, 65.4), (2.0, 67.6)], "accent", segments=10),
]

JUGG_BODY = [
    # Umbau 16. Nov. 2026 nach den DROME-Designregeln (Entwurf v4.py,
    # new_dromes.py M_BODY): Schultern HOEHER, der Kopf sitzt tief dazwischen,
    # ein Frontpanzer vor der Brust und zwei Auspuffstapel auf dem Ruecken. Arme gibt es am Rumpf keine mehr: beide Unterarme kommen mit
    # den Waffen an die Schulteranker.
    # -- Huefte und Torso als Keil ---------------------------------------
    B((-7, 7), (-11, 11), (31, 38), "metal"),
    B((-8, 9), (-12, 12), (38, 48), "plate"),
    # Oberkoerper mit abgeschraegter Brustkante (Profil mit Fase, 18. Nov.)
    EX([(-9, 48), (10.5, 48), (10.5, 57), (8.5, 60), (-9, 60)], (-14, 14), "plate", bevel=0.8),
    B((-8, 9.5), (-13, 13), (60, 62.5), "light"),
    # -- Frontpanzer mit Kernsockel ----------------------------------------
    B((10.5, 11.5), (-10, 10), (42, 58), "dark"),
    B((11.5, 12), (-8, 8), (44, 45.4), "accent"),
    B((11.5, 12), (-8, 8), (56, 57.4), "accent"),
    # -- Schultern hoeher als der Kopf -------------------------------------
    # (Profile mit Fase, vorn oben abgeschraegt -- 18. Nov. 2026)
    EX([(-9, 56), (9, 56), (9, 67), (6.5, 70), (-9, 70)], (13, 25), "plate", bevel=0.9),
    EX([(-9.5, 70), (6.5, 70), (5, 73), (-9.5, 73)], (12.5, 25.5), "light", bevel=0.5),
    B((9, 9.6), (15, 23), (62, 65), "accent"),
    EX([(-9, 56), (9, 56), (9, 67), (6.5, 70), (-9, 70)], (-25, -13), "plate", bevel=0.9),
    EX([(-9.5, 70), (6.5, 70), (5, 73), (-9.5, 73)], (-25.5, -12.5), "light", bevel=0.5),
    B((9, 9.6), (-23, -15), (62, 65), "accent"),
    # Auspuffstapel links und rechts hinter dem Kopf (seit 27. Nov. 2026 etwas
    # dicker; das Lockfeuer der Praesenz dazwischen ist weg, Wunsch des Spielers)
    L((-9.5, 8), [(2.9, 62.5), (2.9, 76), (3.5, 76), (3.5, 78)], "metal", segments=12),
    L((-9.5, -8), [(2.9, 62.5), (2.9, 76), (3.5, 76), (3.5, 78)], "metal", segments=12),
    L((-9.5, 8), [(3.6, 72), (3.6, 73.5)], "accent", caps=False, segments=12),
    L((-9.5, -8), [(3.6, 72), (3.6, 73.5)], "accent", caps=False, segments=12),
] + _JUGG_HOSES + _mirror_l(_JUGG_HOSES)

# Bunkerkopf, tief zwischen den Schultern: kein Hals, ein Kinnschutz vorn.
# Von 17. bis 26. Nov. 2026 steckte er im Rumpf, weil die 2D-Zeichnung ihn als
# eigenes Bild immer ueber die Schulter legte; in 3D sortiert die Tiefe die
# Flaechen, er ist wieder ein eigenes Teil (Wunsch des Spielers).
JUGG_HEAD = [
    B((-5, 7), (-7, 7), (61, 68), "plate"),
    B((-5.5, 7.5), (-7.5, 7.5), (68, 70), "light"),
    B((7, 7.6), (-5, 5), (63.5, 65.6), "visor"),
    B((7, 8.2), (-7, 7), (60.5, 62.5), "metal"),         # Kinnschutz
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
    D(11.7, 0, 50.7, 4.4, "dark", 6),
    B((12.0, 12.3), (-3.2, 3.2), (49.2, 52.2), "glow"),
    B((12.0, 12.3), (-1.8, 1.8), (47.2, 54.2), "glow"),
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
    # -- Freier Arm (-l): Passive Echo (16. Nov. 2026, DROME-Designregeln) --
    # Oberarm haengt, der Unterarm steht 90 Grad nach vorn, darueber schwebt
    # die Energiekugel mit einem Ring -- die sichtbare Passive. Der Arm
    # traegt nie eine Waffe; der Waffenarm (+l) kommt mit der Waffe.
    L((0, -13.8), [(3.4, 41), (3.8, 47), (3.4, 50)], "metal", segments=12),   # Oberarm
    L((-13.8, 40), [(2.6, -1), (3.0, 10)], "plate", axis="f", segments=12),   # Unterarm
    L((-13.8, 40), [(3.2, 3.5), (3.2, 4.4)], "accent", axis="f", caps=False, segments=12),
    L((-13.8, 40), [(3.4, 10), (3.4, 12.4)], "dark", axis="f", segments=12),  # Hand
]
# Die Energiekugel mit Ring -- die sichtbare Passive Echo. Im 3D-Modell ein
# eigener Block ("passive"), damit sie im Kampf schweben kann (18. Nov. 2026).
MAGE_ORB = [
    L((16.2, -13.8), [(0, 42.2), (2.6, 43.2), (3.6, 46), (2.6, 48.8), (0, 49.8)], "glow", segments=14),
    L((16.2, -13.8), [(5.0, 45.6), (5.6, 45.6), (5.6, 46.4), (5.0, 46.4), (5.0, 45.6)],
      "accent", segments=20),                                                  # Ring
    L((19.5, -10.5), [(0, 51), (1.2, 51.5), (1.6, 52.6), (1.2, 53.7), (0, 54.2)], "accent", segments=10),
]
MAGE_BODY = MAGE_BODY + MAGE_ORB

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
    # Leuchtring hinter dem Kopf (16. Nov. 2026): steht senkrecht hinter der
    # Krempe und ragt rundum ueber sie hinaus, drei Funken darauf.
    L((0, 70), [(12.6, -7.0), (13.6, -7.0), (13.6, -6.4), (12.6, -6.4), (12.6, -7.0)],
      "glow", axis="f", segments=32),
    B((-7.3, -6.1), (-1, 1), (82.6, 85.4), "glow"),
    B((-7.3, -6.1), (12, 14.4), (68.8, 71.2), "glow"),
    B((-7.3, -6.1), (-14.4, -12), (68.8, 71.2), "glow"),
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


# ===========================================================================
# LR-Strix // Marksman  (parts/bot4) -- die EULE (16. Nov. 2026)
#
# Seit den DROME-Designregeln (docs/DROME_DESIGNREGELN.md) ist der Strix
# nicht-humanoid: kein Waffenarm, sondern eine LAFETTE auf der linken
# Schulter, die nur Fernkampf nimmt. Die Silhouette ist bewusst das
# Gegenteil des Vireo -- tief und breit statt aufrecht und schmal:
# geduckter Rumpf, Fluegel-Mantel bis fast zum Boden, Kapuze mit zwei
# grossen Linsen und Federohren, Beine mit dem Knie nach hinten.
# Entwurf: docs/design/drome_entwurf/new_dromes.py (Strix A "Eule").
#
# Hoehenprofil in Entwurfseinheiten:
#   Beine 0..32   Huefte 30..36   Rumpf 36..54   Mantel 20..59
#   Kapuze 49..67   Lafette 58..61 (Waffe darauf ab 61)
# ===========================================================================


# Fluegelmantel als gestaffelte Federlagen (18. Nov. 2026, Spieler: "die
# lange Treppe ist nicht das Wahre"): je Seite drei Profile mit Fase, die
# nach aussen kleiner werden -- Deckfedern, Armschwingen, Handschwingen --
# und hinten unten in eine Spitze auslaufen.
def _feather(root, tip, width, l, mat, bend=0.0):
    """Eine Feder als Tropfen (18. Nov. 2026): spitz an der Wurzel, breit und
    rund am Ende, flach quer zur Koerperseite. ``bend`` biegt sie leicht
    nach hinten (f), damit die Reihen nicht steif wirken."""
    rf, rz = root
    tf, tz = tip
    mid = ((rf + tf) / 2 - bend, (rz + tz) / 2)
    pts = [(rf, l, rz), (mid[0], l, mid[1]), (tf, l, tz)]
    return SW(pts, [0.2, width * 0.85, width * 0.35], mat, sides=8, flat=0.22, steps=5)


def _feather_row(roots, tips, width, l, mat, dl=0.0, bend=1.0):
    """Eine Reihe Federn; jede liegt ``dl`` weiter aussen als die vorige,
    damit sie sich schuppenartig ueberlappen."""
    return [_feather(r, t, width, l + i * dl, mat, bend) for i, (r, t) in enumerate(zip(roots, tips))]


# Fluegel einer Eule (18. Nov. 2026, Wunsch des Spielers): eine Grundplatte
# schliesst die Luecken, darueber vier Reihen Tropfen-Federn, jede Reihe
# weiter aussen und hoeher, jede Feder leicht verdreht -- Handschwingen
# (lang, innen, bis zum Boden), Armschwingen, grosse und kleine Deckfedern.
_STRIX_WING = [
    EX([(6, 58), (1, 61), (-6, 61), (-12, 58), (-16, 50), (-17.5, 38), (-17, 26),
        (-15, 15), (-12, 12), (-9, 17), (-4, 28), (1, 40), (5, 50)],
       (8.6, 11.4), "dark", bevel=0.5),
] + _feather_row(                                         # Handschwingen
    [(-7, 40), (-9.5, 41), (-12, 42), (-14.5, 42)],
    [(-9.5, 13), (-12.5, 12.5), (-15.5, 14), (-17.5, 18)], 3.4, 11.6, "metal", dl=0.15, bend=0.8,
) + _feather_row(                                         # Armschwingen
    [(1, 46), (-2.5, 47), (-6, 48), (-9.5, 49), (-13, 49)],
    [(-3, 26), (-6.5, 25), (-10, 25), (-13.5, 27), (-16.5, 31)], 3.4, 12.6, "light",
    dl=0.15, bend=1.2,
) + _feather_row(                                         # grosse Deckfedern
    [(4, 54), (0, 55.5), (-4, 56), (-8, 56), (-12, 54)],
    [(1.5, 41), (-3, 40), (-7.5, 40), (-12, 41), (-15.5, 43)], 3.0, 13.6, "plate",
    dl=0.15, bend=1.0,
) + _feather_row(                                         # kleine Deckfedern
    [(5, 59.5), (1, 60.5), (-3, 61), (-7, 60.5), (-11, 58.5)],
    [(3, 51), (-1, 50), (-5, 50), (-9, 50), (-13, 50)], 2.6, 14.6, "light",
    dl=0.12, bend=0.6,
) + [
    SW([(-2, 15.6, 60.5), (-7, 15.6, 60), (-12, 15.4, 57)], [0.35, 0.35, 0.2], "accent",
       sides=6, steps=4),
]

# Buchse und Kabel der Lafette, je nach STRIX_MOUNT.
if STRIX_MOUNT == "schulter":
    _STRIX_SOCKET = [
        L((-1, 11.5), [(2.8, 59.5), (2.8, 61.2)], "dark", segments=12),
        L((-1, 11.5), [(3.1, 60.0), (3.1, 60.6)], "accent", caps=False, segments=12),
        SW([(-7.6, 1.5, 41.5), (-12.5, 5, 46), (-12, 9.5, 56), (-6, 11.5, 61),
            (-3.5, 11.5, 60.8)], [0.7] * 5, "dark", sides=8, steps=5),
        SW([(-7.6, -1.5, 40), (-13.5, 4, 44), (-13.5, 8, 55), (-7, 10, 61.3),
            (-3.4, 10.8, 60.6)], [0.55] * 5, "metal", sides=8, steps=5),
    ]
else:
    _STRIX_SOCKET = [
        L((-1, 49.5), [(2.6, 14.6), (2.6, 16.8)], "dark", axis="l", segments=12),
        L((-1, 49.5), [(2.9, 15.4), (2.9, 15.9)], "accent", axis="l", caps=False, segments=12),
        SW([(-7.6, 1.5, 41.5), (-11.5, 6, 43), (-13.5, 12, 46.5), (-7, 17.0, 49.5),
            (-3.5, 16.4, 49.5)], [0.7] * 5, "dark", sides=8, steps=5),
        SW([(-7.6, -1.5, 40), (-12.5, 5, 40.5), (-14.5, 12, 44.5), (-8, 17.4, 47.5),
            (-3.5, 16.4, 48.0)], [0.55] * 5, "metal", sides=8, steps=5),
    ]


STRIX_BODY = [
    # -- Huefte und geduckter Rumpf, nach oben nach vorn versetzt -----------
    B((-6, 4), (-6, 6), (30, 36), "metal"),
    B((-7, 5), (-8, 8), (36, 44), "plate"),
    B((-5, 8), (-9, 9), (44, 52), "plate"),
    B((-4, 8.5), (-8, 8), (52, 54), "light"),
    # -- Fluegelmantel ------------------------------------------------------
] + _STRIX_WING + _mirror_l(_STRIX_WING) + [
] + _STRIX_SOCKET


STRIX_HEAD = [
    # Kapuze, nach vorn ueber die Brust gezogen
    B((3, 13), (-7.5, 7.5), (49, 60), "plate"),
    B((2.5, 13.5), (-8, 8), (60, 62), "light"),
    # Federohren als Doppelpyramiden, leicht nach aussen und hinten
    BP((4.5, 4.4, 60.5), (2.2, 6.2, 69), 3.2, 2.6, "plate", mid=0.35),
    BP((4.5, -4.4, 60.5), (2.2, -6.2, 69), 3.2, 2.6, "plate", mid=0.35),
    BP((5.6, 4.6, 62), (4.3, 5.8, 67.2), 1.4, 0.8, "accent", mid=0.35),
    BP((5.6, -4.6, 62), (4.3, -5.8, 67.2), 1.4, 0.8, "accent", mid=0.35),
    # Gesicht: dunkle Platte, zwei grosse Linsen mit Lichtpunkt, Schnabel
    # (Linsen vergroessert 17. Nov. 2026, Board 16 / v6.py LENS_BIG)
    B((13, 13.6), (-7.0, 7.0), (50.5, 59.5), "dark"),
    D(13.7, 3.5, 55.5, 3.4, "dark"),
    D(13.8, 3.5, 55.5, 2.4, "visor"),
    D(13.9, 3.5, 55.5, 0.9, "glow"),
    D(13.7, -3.5, 55.5, 3.4, "dark"),
    D(13.8, -3.5, 55.5, 2.4, "visor"),
    D(13.9, -3.5, 55.5, 0.9, "glow"),
    B((13.6, 14.6), (-0.8, 0.8), (50.5, 53), "metal"),
]

_STRIX_LEG = [
    B((-6, 0), (3.5, 7.5), (22, 32), "plate"),                       # Oberschenkel
    L((-3, 5.5), [(2.6, 18), (2.6, 24)], "metal", segments=12),       # Knie
    B((-9, -4), (4, 7), (10, 22), "plate"),                          # nach hinten
    B((-8.5, -4.5), (4.2, 6.8), (5, 10), "metal"),                   # Ferse
    B((-6, 6), (3.5, 7.5), (0, 5), "plate"),                         # Fuss
    B((6, 9.5), (3.6, 5), (0, 2), "dark"),                           # Krallen
    B((6, 9.5), (6, 7.4), (0, 2), "dark"),
    B((-10.5, -7), (4.8, 6.2), (0, 2), "dark"),
    B((-9.3, -8.8), (4.4, 6.6), (14, 18), "accent"),
]
STRIX_FEET = _STRIX_LEG + _mirror_l(_STRIX_LEG)

# Zielrechner am Ruecken -- buendig auf der Rueckenplatte (f = -7).
STRIX_CORE = [
    B((-7.6, -7.0), (-2, 2), (38, 43), "dark"),
    B((-7.8, -7.6), (-1.2, 1.2), (38.6, 42.4), "glow"),
    B((-7.75, -7.6), (-2.0, -1.4), (38.6, 42.4), "accent"),
    B((-7.75, -7.6), (1.4, 2.0), (38.6, 42.4), "accent"),
]

# Waffen der Lafette: um ihren eigenen Anker (0, 0, 61) gebaut, liegen auf
# der Schulter statt in einer Hand.
def side_holder(z=61.0):
    """Halter einer Lafetten-Waffe (Strix, 18. Nov. 2026): ein Arm quer zur
    Waffe, der seitlich in die Buchse unter der Schulter greift (-l), mit
    Kragen an der Buchse. Die Waffe liegt um (0, 0, z) wie bisher."""
    if STRIX_MOUNT == "schulter":
        return [
            B((-2.0, 2.0), (-1.6, 1.6), (z - 3.2, z + 1.2), "metal"),
            B((-2.6, 2.6), (-2.2, 2.2), (z - 3.8, z - 2.8), "dark"),
            B((-2.1, 2.1), (-1.0, 1.0), (z - 1.6, z - 1.2), "accent"),
        ]
    return [
        B((-2.4, 2.4), (-6.2, -1.4), (z + 1.0, z + 3.4), "metal"),
        B((-2.9, 2.9), (-6.8, -5.6), (z + 0.6, z + 3.8), "dark"),
        B((-1.0, 1.0), (-5.0, -2.4), (z + 3.4, z + 3.8), "accent"),
    ]


# Schienen-Lanze als schweres Scharfschuetzengewehr (Spieler 18. Nov. 2026:
# "sieht ueberhaupt nicht nach Sniper aus"): Schaft mit Wangenauflage,
# Gehaeuse mit Kastenmagazin, langer Lauf mit Muendungsbremse, Zielfernrohr,
# eingeklapptes Zweibein. Railgun bleibt sie: Leuchtspalt im Gehaeuse,
# Spulenringe am Lauf. Liegt auf der Strix-Lafette (Wiege bei z 61).
_RL = 62.0                               # Unterkante Gehaeuse
EQ_RAIL_LANCE = side_holder() + [
    # Schaft: Kolben, Griffstueck, Wangenauflage (Profil, Fase)
    EX([(-17, _RL - 1.6), (-15.5, _RL - 2.2), (-6, _RL - 0.6), (-4, _RL + 0.2),
        (-4, _RL + 4.0), (-9, _RL + 4.6), (-15, _RL + 5.0), (-17, _RL + 4.6)],
       (-1.3, 1.3), "plate", bevel=0.35),
    EX([(-17.4, _RL - 1.8), (-16.6, _RL - 2.0), (-16.6, _RL + 4.8), (-17.4, _RL + 4.7)],
       (-1.5, 1.5), "dark", bevel=0.2),                               # Schaftkappe
    # Gehaeuse mit Oberschiene
    EX([(-4.5, _RL - 0.4), (13, _RL - 0.4), (14.5, _RL + 1.0), (14.5, _RL + 4.2),
        (-4.5, _RL + 4.2)], (-1.7, 1.7), "plate", bevel=0.4),
    B((-3, 12), (-1.0, 1.0), (_RL + 4.2, _RL + 4.9), "metal"),        # Schiene oben
    B((0, 12.5), (-1.75, -1.65), (_RL + 1.2, _RL + 2.4), "accent"),   # Leuchtspalt
    B((0, 12.5), (1.65, 1.75), (_RL + 1.2, _RL + 2.4), "accent"),
    # Kastenmagazin, leicht nach vorn geneigt
    O((5.5, 0, _RL - 2.2), (3.6, 2.2, 4.6), (0, 8, 0), "dark"),
    # Lauf mit Spulenringen und Muendungsbremse
    L((0, _RL + 2.4), [(1.0, 14.5), (1.0, 33)], "metal", axis="f", segments=12),
    L((0, _RL + 2.4), [(1.6, 17), (1.6, 18.2)], "accent", axis="f", caps=False, segments=12),
    L((0, _RL + 2.4), [(1.6, 21), (1.6, 22.2)], "accent", axis="f", caps=False, segments=12),
    L((0, _RL + 2.4), [(1.6, 25), (1.6, 26.2)], "accent", axis="f", caps=False, segments=12),
    EX([(33, _RL + 0.6), (37, _RL + 0.6), (37.5, _RL + 1.2), (37.5, _RL + 3.6),
        (37, _RL + 4.2), (33, _RL + 4.2)], (-1.9, 1.9), "dark", bevel=0.3),
    B((34, 35), (-2.0, 2.0), (_RL + 1.6, _RL + 3.2), "plate"),        # Bremsfenster
    D(37.6, 0, _RL + 2.4, 1.0, "glow"),
    # Zielfernrohr auf zwei Ringen
    B((0.5, 1.8), (-0.9, 0.9), (_RL + 4.9, _RL + 6.2), "metal"),
    B((7.5, 8.8), (-0.9, 0.9), (_RL + 4.9, _RL + 6.2), "metal"),
    L((0, _RL + 7.6), [(1.7, -2.5), (1.5, -1.0), (1.5, 7.0), (2.2, 9.0), (2.2, 11.5)], "dark",
      axis="f", segments=12),
    L((0, _RL + 7.6), [(1.65, 3.0), (1.65, 4.2)], "metal", axis="f", caps=False, segments=12),
    D(11.55, 0, _RL + 7.6, 1.7, "visor"),
    # Zweibein, eingeklappt unter dem Lauf
    OB((15.5, 1.1, _RL + 0.6), (25, 1.4, _RL + 0.9), 0.6, 0.6, "metal"),
    OB((15.5, -1.1, _RL + 0.6), (25, -1.4, _RL + 0.9), 0.6, 0.6, "metal"),
    B((14.5, 16), (-1.6, 1.6), (_RL + 0.2, _RL + 1.2), "dark"),
]

# ===========================================================================
# Waffen in Posen (DROME-Designregeln, Schritt 4; Entwurf v4.py und v6.py)
#
# Arme und Waffen getrennt (Schritt 4b, 17. Nov. 2026): Der Arm gehoert zum
# CHASSIS (Chassisfarbe, je Chassis gebaut), die Waffe ist nur das Geraet am
# Hand-Anker. Zwei Haltungen je Arm:
#
#   * "hold"  -- halten: Oberarm haengt, Unterarm nach vorn, Faust um den
#                Griff (Klinge, Hammer, Stab, Schluessel, Bumerang, Schild)
#   * "aim"   -- zielen: Arm endet in einer Manschette, die Waffe sitzt
#                direkt daran (Blaster, Ramme). Vireo und Nimbus strecken den
#                ganzen Arm, der Molok schiesst angewinkelt aus der Huefte.
#
# Haende haben nur Arme, die nie etwas tragen (Vireo rechts).
#
# Waffen sind um ihren Griffpunkt (0, 0, ARM_Z) gebaut und SYMMETRISCH zur
# Armebene (l = 0) bzw. fuer den rechten Molok-Arm in 3D gespiegelt. ``k`` ist
# das Waffenmass: 1.0 fuer Vireo und Nimbus, HEAVY_K fuer den Molok (Variante
# "heavy"). Fuer die Strix-Lafette gibt es eine eigene Variante ohne Arm, um
# den Lafettenanker (0, 0, LAFETTE_Z).
# ===========================================================================

ARM_Z = 52
HEAVY_K = 1.6
LAFETTE_Z = 61
POSES = ("hold", "aim", "guard")


def _fist(hf, hl, hz, k=1.0):
    """Faust-Block um den Griff, zwei helle Fugen = Knoechel."""
    return [
        B((hf - 2.2 * k, hf + 2.2 * k), (hl - 2.6 * k, hl + 2.6 * k), (hz - 2.6 * k, hz + 2.6 * k), "dark"),
        B((hf + 2.2 * k, hf + 2.6 * k), (hl - 2.2 * k, hl + 2.2 * k), (hz - 1.6 * k, hz - 0.6 * k), "light"),
        B((hf + 2.2 * k, hf + 2.6 * k), (hl - 2.2 * k, hl + 2.2 * k), (hz + 0.6 * k, hz + 1.6 * k), "light"),
    ]


def _cuff(hf, hl, hz, k=1.0):
    """Manschette: Ring am Handgelenk, die Waffe sitzt direkt davor."""
    return [L((hl, hz), [(2.9 * k, hf - 1.6 * k), (2.9 * k, hf)], "accent",
              axis="f", segments=12)]


def arm_hold(shoulder, k=1.0):
    """Halten (linker Arm, +l): Oberarm runter, Unterarm nach vorn, Faust
    leicht nach aussen versetzt. Gibt (Formen, Handpunkt)."""
    f0, l0, zs = shoulder
    t = 2.0 * k
    hf, hl, hz = f0 + 12.75 * k, l0 + 1.0 * k, zs - 12.5 * k
    shapes = [
        B((f0 - 2.5 * k, f0 + 2.5 * k), (l0 - t, l0 + t), (zs - 11 * k, zs), "metal"),
        B((f0 - 2.5 * k, f0 + 10.5 * k), (l0 - t - 0.3, l0 + t + 0.3), (zs - 16 * k, zs - 9 * k), "plate"),
        B((f0 + 4 * k, f0 + 9 * k), (l0 + t + 0.3, l0 + t + 0.8), (zs - 13.5 * k, zs - 12 * k), "accent"),
    ] + _fist(hf, hl, hz, k)
    return shapes, (hf, hl, hz)


def arm_aim(shoulder, k=1.0):
    """Zielen (Vireo, Nimbus): ganzer Arm gestreckt nach vorn, auf
    Schulterhoehe, am Ende die Manschette."""
    f0, l0, zs = shoulder
    t = 2.1 * k
    zc = zs - 4.5 * k
    hf = f0 + 17.6 * k
    shapes = [
        B((f0 - 2.5 * k, f0 + 2.5 * k), (l0 - t, l0 + t), (zs - 7 * k, zs - 1), "metal"),   # Gelenk
        B((f0 + 1 * k, f0 + 9 * k), (l0 - t, l0 + t), (zc - 2.0 * k, zc + 2.0 * k), "metal"),
        B((f0 + 8 * k, hf - 1.6 * k), (l0 - t - 0.3, l0 + t + 0.3), (zc - 2.6 * k, zc + 2.6 * k), "plate"),
        B((f0 + 11 * k, f0 + 15 * k), (l0 + t + 0.3, l0 + t + 0.8), (zc - 0.8 * k, zc + 0.8 * k), "accent"),
    ] + _cuff(hf, l0, zc, k)
    return shapes, (hf, l0, zc)


def molok_arm(shoulder, pose):
    """Eigener Molok-Arm: setzt UNTER der Schulterplatte an, dicker Oberarm,
    Unterarm angewinkelt nach vorn auf Hufthoehe -- halten mit grosser Faust,
    zielen aus der Huefte mit Manschette."""
    f0, l0, zs = shoulder
    hz = zs - 18
    shapes = [
        B((f0 - 3.5, f0 + 3.5), (l0 - 3.5, l0 + 3.5), (hz + 3, zs), "metal"),          # Oberarm
        B((f0 - 4, f0 + 4), (l0 - 4, l0 + 4), (hz + 1, hz + 5), "dark"),               # Ellbogen
        B((f0 - 3, f0 + 13), (l0 - 4, l0 + 4), (hz - 4, hz + 4), "plate"),             # Unterarm
        B((f0 - 3, f0 + 13), (l0 - 4.2, l0 + 4.2), (hz + 4, hz + 5), "light"),
        B((f0 + 3, f0 + 10), (l0 + 4.2, l0 + 4.7), (hz - 1.5, hz + 1.5), "accent"),
    ]
    if pose == "hold":
        hf, hl = f0 + 16.5, l0 + 1.0
        return shapes + _fist(hf, hl, hz, HEAVY_K * 0.85), (hf, hl, hz)
    hf = f0 + 14.6
    return shapes + _cuff(hf, l0, hz, HEAVY_K), (hf, l0, hz)


def arm_set(shoulder, build, cover=(), mirror=False):
    """Alle Haltungen eines Arms: {pose: (Formen, Handpunkt)}. ``build``
    baut den LINKEN Arm; der rechte wird in 3D an l = 0 gespiegelt.

    ``cover`` sind die Formen der Schulter, unter der der Arm ansetzt (fuer
    den linken Arm). Sie kommen MIT ins Arm-Bild: Arm und Rumpf sind eigene
    Sprites, und ohne die Schulter laege der Oberarm immer UEBER ihr. So
    deckt die Schulter den Oberarm im selben Bild richtig ab und liegt
    deckungsgleich ueber der des Rumpfs.

    "guard" (Schild) ist die Haltung "hold" -- nur liegt der Schild VOR der
    Faust und bekommt dafuer eine eigene Tiefe (siehe slot_draw_order)."""
    res = {}
    for pose in POSES:
        built = "hold" if pose == "guard" else pose
        if mirror:
            left = (shoulder[0], -shoulder[1], shoulder[2])
            shapes, hand = build(left, built)
            res[pose] = (_mirror_l(shapes + list(cover)), (hand[0], -hand[1], hand[2]))
        else:
            shapes, hand = build(shoulder, built)
            res[pose] = (shapes + list(cover), hand)
    return res


def side_shapes(shapes, l_min, l_max, z_min):
    """Die Formen einer Seite (Quader und Drehkoerper) ab einer Hoehe --
    fuer die Schulter, die ein Arm-Bild mitbringt."""
    out = []
    for sh in shapes:
        if sh[0] == "box" and l_min <= sh[2][0] and sh[2][1] <= l_max and sh[3][0] >= z_min:
            out.append(sh)
        elif sh[0] == "obox" and l_min <= sh[1][1] <= l_max and sh[1][2] >= z_min:
            out.append(sh)
        elif sh[0] == "lathe" and sh[4] == "z" and l_min <= sh[1][1] <= l_max \
                and abs(sh[1][0]) < 0.01 and min(p for _r, p in sh[2]) >= z_min:
            out.append(sh)
    return out


def light_arm(shoulder, pose):
    return (arm_hold if pose == "hold" else arm_aim)(shoulder)


def _head_blaster(h, k, neon=False):
    f, l, z = h
    # Gehaeuse und Laufmantel als Profile mit Fase, Kuehlrippen am Mantel
    # (18. Nov. 2026, statt Kasten mit Lauf).
    s = [
        EX([(f, z - 3.5 * k), (f + 5.5 * k, z - 3.5 * k), (f + 6.5 * k, z - 2.2 * k),
            (f + 6.5 * k, z + 2.6 * k), (f + 5 * k, z + 3.6 * k), (f + 0.6 * k, z + 3.6 * k),
            (f, z + 2.6 * k)], (l - 3 * k, l + 3 * k), "plate", bevel=0.5 * k),
        EX([(f + 6.5 * k, z - 2.2 * k), (f + 13 * k, z - 2.2 * k), (f + 14 * k, z - 1.4 * k),
            (f + 14 * k, z + 1.8 * k), (f + 13 * k, z + 2.6 * k), (f + 6.5 * k, z + 2.6 * k)],
           (l - 2 * k, l + 2 * k), "light", bevel=0.4 * k),
        B((f + 8 * k, f + 8.7 * k), (l - 2.3 * k, l + 2.3 * k), (z - 2.5 * k, z + 2.9 * k), "dark"),
        B((f + 9.7 * k, f + 10.4 * k), (l - 2.3 * k, l + 2.3 * k), (z - 2.5 * k, z + 2.9 * k), "dark"),
        B((f + 11.4 * k, f + 12.1 * k), (l - 2.3 * k, l + 2.3 * k), (z - 2.5 * k, z + 2.9 * k), "dark"),
        B((f + 14 * k, f + 15 * k), (l - 1.6 * k, l + 1.6 * k), (z - 1.6 * k, z + 1.9 * k), "dark"),
        D(f + 15.1 * k, l, z + 0.2 * k, 1.3 * k, "glow"),
        B((f + 1 * k, f + 4 * k), (l - 3.5 * k, l - 3 * k), (z - 1 * k, z + 1 * k), "accent"),
        B((f + 1 * k, f + 4 * k), (l + 3 * k, l + 3.5 * k), (z - 1 * k, z + 1 * k), "accent"),
    ]
    if neon:   # Variante: dieselbe Form, Neonroehren am Lauf, Ring vor der Muendung
        s += [
            B((f + 5.5 * k, f + 12.5 * k), (l + 2.0 * k, l + 2.7 * k), (z - 1.2 * k, z + 1.2 * k), "glow"),
            B((f + 5.5 * k, f + 12.5 * k), (l - 2.7 * k, l - 2.0 * k), (z - 1.2 * k, z + 1.2 * k), "glow"),
            L((l, z), [(2.5 * k, f + 13.4 * k), (2.5 * k, f + 14.2 * k)], "glow", axis="f",
              caps=False, segments=14),
        ]
    return s, (f + 15.1 * k, l, z + 0.2 * k)


def _head_blade(h, k):
    f, l, z = h
    # Die Klinge waechst am Molok nicht voll mit -- sonst ragt sie aus dem
    # 128er Rahmen. Griff und Parierstange tragen das Armmass.
    kb = min(k, 1.3)
    top = z + 9.0 * k + 27 * kb
    return [
        B((f - 0.9 * k, f + 0.9 * k), (l - 0.9 * k, l + 0.9 * k), (z - 6 * k, z + 4.4 * k), "metal"),
        B((f - 1.5 * k, f + 1.5 * k), (l - 1.5 * k, l + 1.5 * k), (z - 7.8 * k, z - 6 * k), "dark"),
        B((f - 0.7 * k, f + 0.7 * k), (l - 0.7 * k, l + 0.7 * k), (z - 8.6 * k, z - 7.8 * k), "glow"),
        B((f - 2.0 * k, f + 2.0 * k), (l - 5 * k, l + 5 * k), (z + 4.4 * k, z + 6.0 * k), "plate"),
        B((f - 2.1 * k, f + 2.1 * k), (l - 5.4 * k, l - 4.2 * k), (z + 4.2 * k, z + 6.4 * k), "accent"),
        B((f - 2.1 * k, f + 2.1 * k), (l + 4.2 * k, l + 5.4 * k), (z + 4.2 * k, z + 6.4 * k), "accent"),
        B((f - 1.3 * k, f + 1.3 * k), (l - 1.4 * k, l + 1.4 * k), (z + 6.0 * k, z + 9.0 * k), "metal"),
        # Plasmaklinge als lange Doppelpyramide (Spieler 18. Nov. 2026): die
        # kurze Spitze steckt im Heft, die breiteste Stelle knapp darueber.
        BP((f, l, z + 7.0 * k), (f, l, top), 3.0 * k, 1.5 * k, "glow", mid=0.12),
    ], (f, l, top)


def _head_hammer(h, k):
    f, l, z = h
    return [
        B((f - 0.9 * k, f + 0.9 * k), (l - 0.9 * k, l + 0.9 * k), (z - 8 * k, z + 17 * k), "metal"),
        B((f - 1.5 * k, f + 1.5 * k), (l - 1.5 * k, l + 1.5 * k), (z - 9.6 * k, z - 8 * k), "dark"),
        EX([(f - 5 * k, z + 16 * k), (f + 5 * k, z + 16 * k), (f + 5 * k, z + 25 * k),
            (f - 5 * k, z + 25 * k)], (l - 4.5 * k, l + 4.5 * k), "plate", bevel=1.0 * k),
        B((f - 5.1 * k, f + 5.1 * k), (l - 4.6 * k, l + 4.6 * k), (z + 19.8 * k, z + 21.2 * k), "accent"),
        # Dorn hinten
        BP((f - 4.5 * k, l, z + 20.5 * k), (f - 11 * k, l, z + 20.5 * k), 3.4 * k, 3.4 * k,
           "metal", mid=0.15),
        B((f + 5 * k, f + 5.8 * k), (l - 3.5 * k, l + 3.5 * k), (z + 17.5 * k, z + 23.5 * k), "dark"),
        D(f + 6 * k, l, z + 20.5 * k, 1.7 * k, "glow"),
    ], (f + 6 * k, l, z + 20.5 * k)


def _head_staff(h, k):
    f, l, z = h
    return [
        L((f, l), [(2.0 * k, z - 20 * k), (2.0 * k, z - 18 * k)], "dark", segments=10),
        L((f, l), [(1.4 * k, z - 18 * k), (1.4 * k, z + 20 * k)], "metal", segments=10),
        L((f, l), [(1.9 * k, z - 4.4 * k), (1.9 * k, z - 3.0 * k)], "accent", caps=False, segments=10),
        L((f, l), [(1.9 * k, z + 3.0 * k), (1.9 * k, z + 4.4 * k)], "accent", caps=False, segments=10),
        L((f, l), [(2.3 * k, z - 9 * k), (2.3 * k, z - 7.6 * k)], "accent", caps=False, segments=10),
        L((f, l), [(2.6 * k, z + 18.6 * k), (3.4 * k, z + 20.4 * k), (3.4 * k, z + 21.4 * k)], "plate", segments=12),
        B((f - 0.7 * k, f + 0.7 * k), (l - 4.4 * k, l - 3.2 * k), (z + 20.4 * k, z + 28.6 * k), "metal"),
        B((f - 0.7 * k, f + 0.7 * k), (l + 3.2 * k, l + 4.4 * k), (z + 20.4 * k, z + 28.6 * k), "metal"),
        B((f - 0.8 * k, f + 0.8 * k), (l - 4.6 * k, l - 3.0 * k), (z + 28.6 * k, z + 29.6 * k), "accent"),
        B((f - 0.8 * k, f + 0.8 * k), (l + 3.0 * k, l + 4.6 * k), (z + 28.6 * k, z + 29.6 * k), "accent"),
        L((f, l), [(0, z + 21.6 * k), (2.2 * k, z + 22.6 * k), (3.0 * k, z + 24.4 * k),
                   (2.2 * k, z + 26.2 * k), (0, z + 27.2 * k)], "glow"),
        L((f, l), [(4.9 * k, z + 23.8 * k), (4.9 * k, z + 24.9 * k)], "accent", caps=False, segments=18),
    ], (f, l, z + 24.4 * k)


def _head_shield(h, k):
    """Schild angewinkelt vor dem Koerper, zur Koerpermitte hin versetzt."""
    f, l, z = h
    # Am Molok waechst der Schild nur bis 1,25 mit (wie im Entwurf) --
    # mit vollem Waffenmass reichte er vom Knie bis an die Schulter.
    k = min(k, 1.25)
    a, b = l - 16 * k, l + 3 * k                         # deckt die Koerpermitte
    return [
        B((f + 1.5 * k, f + 3.5 * k), (a, b), (z - 14 * k, z + 15 * k), "plate"),
        B((f + 1.5 * k, f + 4 * k), (a - 0.5, b + 0.5), (z + 15 * k, z + 17 * k), "light"),
        B((f + 3.5 * k, f + 4 * k), (a + 2 * k, b - 2 * k), (z - 12 * k, z + 13 * k), "dark"),
        B((f + 4 * k, f + 4.4 * k), (a + 3 * k, b - 3 * k), (z + 6 * k, z + 7.4 * k), "accent"),
        D(f + 4.5 * k, l, z - 1 * k, 2.6 * k, "dark", 6),
        D(f + 4.7 * k, l, z - 1 * k, 1.5 * k, "glow", 6),
    ], (f + 4.7 * k, l, z - 1 * k)


def lafette_blaster(neon=False):
    """Fernwaffe ohne Arm: liegt laengs auf der Schulter, Wiege statt Hand."""
    z = LAFETTE_Z
    s = side_holder(z) + [
        B((-4, 5), (-3, 3), (z + 1.5, z + 8), "plate"),              # Gehaeuse
        B((5, 15), (-2, 2), (z + 3, z + 7.4), "plate"),              # Lauf
        B((5, 15), (-2.2, 2.2), (z + 7.4, z + 8.1), "light"),
        B((15, 17), (-1.8, 1.8), (z + 3.2, z + 7.2), "dark"),
        D(17.1, 0, z + 5.2, 1.4, "glow"),
        B((-3, 4), (3, 3.5), (z + 4, z + 6), "accent"),
        B((-3, 4), (-3.5, -3), (z + 4, z + 6), "accent"),
    ]
    if neon:
        s += [
            B((5.5, 14.5), (2.0, 2.7), (z + 4.2, z + 6.2), "glow"),
            B((5.5, 14.5), (-2.7, -2.0), (z + 4.2, z + 6.2), "glow"),
            L((0, z + 5.2), [(2.5, 15.4), (2.5, 16.2)], "glow", axis="f", caps=False, segments=14),
        ]
    return s, (17.1, 0, z + 5.2)


def lafette_staff():
    """Runenstab auf der Lafette: ohne Griff, nur die Kugel in ihrer Fassung
    auf einem kurzen Sockel (Spieler 17. Nov. 2026)."""
    z = LAFETTE_Z
    base = z + 5
    head, point = _head_staff((0, 0, base - 18.6), 1.0)
    return side_holder(z) + [
        L((0, 0), [(1.6, z + 1), (1.6, base)], "metal", segments=10),
    ] + head[5:], point


def weapon_set(pose, head, lafette=None, **kw):
    """Nur das Geraet in der Hand, um den Griffpunkt (0, 0, ARM_Z) gebaut:
    Grundform (k 1, linker Arm), Molok-Varianten fuer beide Arme und, fuer
    Fernwaffen, die Lafette. ``pose`` sagt, welche Haltung des Chassis-Arms
    die Waffe braucht.

    Fuer den rechten Molok-Arm gibt es dieselbe Waffe in 3D an der Armebene
    gespiegelt ("heavy_right") -- kein gespiegeltes Bild, der Generator
    rendert sie neu, Licht und Schatten stimmen also.
    """
    grip = (0, 0, ARM_Z)
    shapes, point = head(grip, 1.0, **kw)
    heavy, heavy_point = head(grip, HEAVY_K, **kw)
    hp_r = (heavy_point[0], -heavy_point[1], heavy_point[2])
    variants = {
        "heavy": {"shapes": heavy, "anchors": {"mount": grip, "muzzle": heavy_point}},
        "heavy_right": {"shapes": _mirror_l(heavy),
                        "anchors": {"mount": grip, "muzzle": hp_r}},
    }
    if lafette is not None:
        laf, laf_point = lafette
        variants["lafette"] = {"shapes": laf, "anchors": {"mount": (0, 0, LAFETTE_Z),
                                                          "muzzle": laf_point}}
    return {"shapes": shapes, "variants": variants, "pose": pose,
            "anchors": {"mount": grip, "muzzle": point}}


W_PULSE = weapon_set("aim", _head_blaster, lafette=lafette_blaster())
W_BLADE = weapon_set("hold", _head_blade)
W_SHIELD = weapon_set("guard", _head_shield)
W_HAMMER = weapon_set("hold", _head_hammer)
W_STAFF = weapon_set("hold", _head_staff, lafette=lafette_staff())


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
                    "head": (0, 0, 65),
                    "feet": (0, 0, 36),
                    "core": (8.8, 0, 51),
                    # Waffenarm haengt an der Schulter (DROME-Designregeln)
                    "equip_left": (0, 14.5, 54),
                    "equip_right": (0, -14.5, 54),
                },
                # Der Waffenarm gehoert zum Chassis (Schritt 4b).
                "arms": {"equip_left": arm_set((0, 14.5, 54), light_arm,
                                                cover=side_shapes(SCOUT_BODY, 10, 18, 54))},
                # Ein Sprinter traegt keine Artillerie. Die Grenze steht hier
                # und nicht in einer Balancing-Tabelle, weil sie sonst erst im
                # Kampf auffaellt -- und weil ein Vireo mit Belagerungskanone
                # eine Silhouette haette, die ueber seine Reichweite luegt.
                # Ein Ausruestungsplatz (Nov. 2026). Der rechte Anker bleibt fuer
                # die Optik, ist aber kein Halter mehr ("off"). Seit 8. Nov.
                # 2026 nur leicht (der schnelle Allrounder).
                "slot_rules": {
                    "equip_left": {"max_class": "light",
                                   "categories": ["weapon", "support"]},
                    "equip_right": {"off": True},
                },
            },
            {
                "id": "scout_head", "code": "HED-001", "type": "head", "name": "Vireo Sensorkopf",
                "tags": ["light", "sensor"], "shapes": SCOUT_HEAD,
                "anchors": {"mount": (0, 0, 65), "sensor": (7.5, 0, 69.3)},
            },
            {
                "id": "scout_feet", "code": "LEG-001", "type": "feet", "name": "Vireo Sprintbeine",
                "tags": ["light", "fast"], "shapes": SCOUT_FEET,
                "anchors": {"mount": (0, 0, 36), "ground": (1, 0, 0)},
                # Beine im Wechsel (18. Nov. 2026): Drehpunkte je Bein (links,
                # rechts gespiegelt), Teilung Ober-/Unterschenkel bei split_z.
                "legs": {"hip": (0, 5.75, 33), "knee": (0, 5.75, 22), "split_z": 21},
            },
            {
                "id": "scout_core", "code": "COR-001", "type": "core", "name": "Vireo Impulskern",
                "tags": ["core", "energy"], "shapes": SCOUT_CORE,
                "anchors": {"mount": (8.8, 0, 51)},
            },
            {
                "id": "eq_pulse_blaster", "code": "EQP-001", "type": "equipment", "name": "Puls-Blaster",
                "tags": ["weapon", "ranged"], **W_PULSE,
                "mount_class": "light", "category": "weapon",
            },
            {
                "id": "eq_plasma_blade", "code": "EQP-010", "type": "equipment",
                "name": "Plasmaklinge", "tags": ["weapon", "melee"],
                **W_BLADE,
                "mount_class": "light", "category": "weapon",
            },
            {
                "id": "eq_deflector", "code": "EQP-002", "type": "equipment", "name": "Deflektor-Schild",
                "tags": ["defense"], **W_SHIELD,
                # Ein Schild ist sperrig, nicht schwer -- "medium" haelt es von
                # den Schulter- und Jochlagern fern, ohne es an einem
                # Standardarm einzuschraenken.
                "mount_class": "medium", "category": "shield",
            },
        ],
    },
    {
        "dir": "bot2",
        "id": "bot2",
        "name": "HX-Molok // Juggernaut",
        "description": "Schwerer Rahmen. Zwei Waffen.",
        "palette": JUGG_PALETTE,
        "parts": [
            {
                "id": "jugg_body", "code": "CHS-002", "type": "body", "name": "Molok Chassis",
                "tags": ["heavy"], "shapes": JUGG_BODY,
                # Waffen in Posen: der Molok traegt dieselben Waffen, nur
                # groesser gebaut (Armmass 1,6, Spieler 16. Nov. 2026).
                "weapon_variant": "heavy",
                "anchors": {
                    "mount": (0, 0, MOUNT_Z),
                    "head": (0, 0, 60.5),
                    "feet": (0, 0, 33),
                    "core": (11.5, 0, 50.7),
                    # Zwei Schulteranker: beide Unterarme kommen mit der Waffe
                    "equip_left": (0, 19, 57),
                    "equip_right": (0, -19, 57),
                    # Auf dem Rueckendeck zwischen den Auspuffstapeln.
                    "equip_shoulder": (-7, 0, 63),
                },
                # Eigene Molok-Arme unter den Schulterplatten (Schritt 4b).
                "arms": {"equip_left": arm_set((0, 19, 57), molok_arm,
                                               cover=side_shapes(JUGG_BODY, 12, 26, 56)),
                         "equip_right": arm_set((0, -19, 57), molok_arm, mirror=True,
                                                cover=side_shapes(JUGG_BODY, 12, 26, 56))},
                # Der Schulteranker ist KEIN dritter Arm. Er sitzt hinter dem
                # Kopf auf der Schulterbruecke, hat keinen Gegenhalt und nichts,
                # woran sich ein Schild abstuetzen koennte -- dort gehoert
                # Sensorik und Support hin, nichts Schweres und nichts, was
                # gehalten werden muss.
                # Zwei Plaetze, beide bis mittel (8. Nov. 2026): schwer ist nur
                # das Scharfschuetzengewehr des Strix.
                "slot_rules": {
                    "equip_left": {"max_class": "medium"},
                    "equip_right": {"max_class": "medium"},
                    "equip_shoulder": {"off": True},
                },
            },
            {
                "id": "jugg_head", "code": "HED-002", "type": "head", "name": "Molok Bunkerkopf",
                "tags": ["heavy", "armored"], "shapes": JUGG_HEAD,
                "anchors": {"mount": (0, 0, 60.5), "sensor": (7.6, 0, 64.5)},
            },
            {
                "id": "jugg_feet", "code": "LEG-002", "type": "feet", "name": "Molok Standbeine",
                "tags": ["heavy", "slow"], "shapes": JUGG_FEET,
                "anchors": {"mount": (0, 0, 33), "ground": (1, 0, 0)},
                # Hueftausleger (ueber static_z) bleiben am Rumpf.
                "legs": {"hip": (0, 12.5, 29), "knee": (0, 12.5, 16.5),
                         "split_z": 15, "static_z": 29},
            },
            {
                "id": "jugg_core", "code": "COR-002", "type": "core", "name": "Molok Fusionskern",
                "tags": ["core", "fusion"], "shapes": JUGG_CORE,
                "anchors": {"mount": (11.5, 0, 50.7)},
            },
            {
                "id": "eq_hammer", "code": "EQP-012", "type": "equipment",
                "name": "Hammer", "tags": ["weapon", "melee", "heavy"],
                **W_HAMMER,
                "mount_class": "medium", "category": "weapon",
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
                "shapes": MAGE_BODY, "passive_shapes": MAGE_ORB,
                "anchors": {
                    "mount": (0, 0, MOUNT_Z),
                    "head": (0, 0, 61),
                    "feet": (0, 0, 27),
                    "core": (11.4, 0, 44),
                    "equip_left": (0, 13.8, 47),
                    "equip_right": (0, -13.8, 47),
                },
                "arms": {"equip_left": arm_set((0, 13.8, 47), light_arm,
                                                cover=side_shapes(MAGE_BODY, 13, 14.6, 44))},
                "slot_rules": {
                    "equip_left": {"max_class": "medium",
                                   "categories": ["weapon", "support"]},
                    "equip_right": {"off": True},
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
                **W_STAFF,
                "mount_class": "light", "category": "weapon",
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
                "name": "Strix Chassis", "tags": ["marksman", "owl", "sniper"],
                "shapes": STRIX_BODY,
                "anchors": {
                    "mount": (0, 0, MOUNT_Z),
                    "head": (8, 0, 49),
                    "feet": (0, 0, 30),
                    # Am Ruecken statt an der Brust -- siehe STRIX_CORE.
                    "core": (-7.3, 0, 40.5),
                    # Die Lafette: seitlich unter der linken Schulter, die Waffe
                    # steckt mit ihrem Halter in der Buchse (18. Nov. 2026).
                    "equip_center": (-1, 11.5, 64.5) if STRIX_MOUNT == "schulter"
                    else (-1, 21.8, 47.5),
                },
                # Ein Slot, dafuer ohne Deckel: hier darf das Schwerste hin --
                # aber als Lafette nur Fernkampf (16. Nov. 2026).
                "slot_rules": {"equip_center": {"max_class": "heavy",
                                                "categories": ["weapon", "support"],
                                                "reach": "ranged"}},
                "body_kind": "nonhumanoid",
                # Fernwaffen liegen auf der Lafette statt in einer Hand.
                "weapon_variant": "lafette",
            },
            {
                "id": "strix_head", "code": "HED-004", "type": "head",
                "name": "Strix Eulenkapuze", "tags": ["marksman", "sensor", "optics"],
                "shapes": STRIX_HEAD,
                "anchors": {"mount": (8, 0, 49), "sensor": (13.8, 0, 55.5)},
            },
            {
                "id": "strix_feet", "code": "LEG-004", "type": "feet",
                "name": "Strix Federbeine", "tags": ["marksman", "digitigrad"],
                "shapes": STRIX_FEET,
                "anchors": {"mount": (0, 0, 30), "ground": (0, 0, 0)},
                # Knie nach hinten: der Unterschenkel haengt am Gelenk bei z 21.
                "legs": {"hip": (-3, 5.5, 30), "knee": (-3, 5.5, 21), "split_z": 19},
            },
            {
                "id": "strix_core", "code": "COR-004", "type": "core",
                "name": "Strix Zielrechner", "tags": ["core", "optics"],
                "shapes": STRIX_CORE,
                "anchors": {"mount": (-7.3, 0, 40.5)},
            },
            {
                "id": "eq_rail_lance", "code": "EQP-007", "type": "equipment",
                "name": "Schienen-Lanze", "tags": ["weapon", "heavy", "sniper"],
                "shapes": EQ_RAIL_LANCE,
                # Schwer wie die Belagerungskanone -- an einen Sprinterarm
                # kommt sie damit ebenso wenig.
                "mount_class": "heavy", "category": "weapon",
                "anchors": {"mount": (0, 0, 61), "muzzle": (37.6, 0, 64.4)},
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
    humanoid = part.get("body_kind", "humanoid") == "humanoid"
    for name, local in part["anchors"].items():
        if name == "mount":
            continue
        # Waffen in Posen greifen nach VORN (Faust, Schild, Lauf). Gemessen
        # wird deshalb nicht am Schulteranker, sondern ein Stueck davor --
        # sonst laege ein Schild, der vor dem Koerper haengt, von hinten
        # gesehen ueber dem Rumpf. Die Strix-Lafette liegt obenauf, fuer
        # sie gilt der Anker selbst.
        if humanoid and name in ("equip_left", "equip_right"):
            local = (local[0] + WEAPON_DEPTH_AHEAD, local[1] * WEAPON_DEPTH_INWARD,
                     TORSO_REF[2])
        order[name] = round(closeness(to_world(local, direction)), 1)
    # Arm und Waffe sind eigene Sprites (Schritt 4b). Gehalten liegt die
    # Waffe knapp HINTER ihrem Arm -- die Faust umschliesst den Griff. Beim
    # Zielen sitzt sie vor der Manschette und wird dort gemessen, wo sie ist:
    # vorn vor der Hand (von hinten gesehen liegt sie dann hinter dem Arm).
    for slot, poses in part.get("arms", {}).items():
        for pose, (_shapes, hand) in poses.items():
            if pose == "hold":
                order[f"{slot}@{pose}"] = round(order[slot] - 0.05, 2)
            else:
                # zielen und Schild: gemessen, wo das Geraet wirklich ist --
                # vor der Hand. Am Schulteranker gemessen lag der Kern auf
                # der Brust ueber dem Schild, obwohl der Schild davor haengt.
                ahead = (hand[0] + 4, hand[1] * WEAPON_DEPTH_INWARD, TORSO_REF[2])
                order[f"{slot}@{pose}"] = round(closeness(to_world(ahead, direction)), 1)
    return order


# Wo die Tiefe einer Waffe gemessen wird: ein Stueck vor dem Schulteranker
# und naeher zur Koerpermitte, auf Rumpfhoehe -- dort liegt der Schwerpunkt
# von Faust, Schild und Lauf (die Hoehe zaehlt sonst in der Kameratiefe mit). Am Anker selbst gemessen gewinnt die Seite: ein Schild am nahen
# Arm laege von hinten gesehen ueber dem Rumpf, obwohl er davor haengt.
WEAPON_DEPTH_AHEAD = 10
WEAPON_DEPTH_INWARD = 0.4


# ===========================================================================
# 3D-Modelle (17. Nov. 2026, Wunsch des Spielers: "ein echter 3D-Generator")
#
# Neben den SVGs schreibt der Generator je Teil EIN Modell, unabhaengig von
# der Blickrichtung: alle Flaechen in bot-lokalen Koordinaten (f, l, z) mit
# Normale und Material. Das Spiel baut daraus Meshes und rendert den GANZEN
# DROME in einem Durchgang mit Tiefenpuffer -- die Verdeckung stimmt dann
# zwischen allen Teilen, nicht nur innerhalb eines Bildes.
#
# Flaechenarten (``kind``):
#   "box"   Quader-Flaeche: dunkle Kante ringsum (wie der Strich im SVG)
#   "disc"  Scheibe: dunkle Kante am Rand
#   "seam"  Facette eines Drehkoerpers: keine Kante (Strich in Eigenfarbe)
# Drehkoerper bekommen zusaetzlich eine Huelle ("hull") fuer ihre
# Aussenkontur -- im Spiel als nach aussen geschobene Rueckseite gezeichnet.
# ===========================================================================

HULL_GROW = 0.45      # halbe Strichbreite (0.9) in Entwurfseinheiten


def _r(v):
    return round(v, 3)


def model_faces(shapes):
    """Formen -> (Flaechen, Huellen) fuer das 3D-Modell."""
    faces, hulls = [], []
    for shape in shapes:
        if shape[0] == "box":
            _, f, l, z, mat = shape
            for normal, points in _box_faces(f, l, z):
                faces.append([mat, "box", list(normal), [[_r(c) for c in p] for p in points]])
        elif shape[0] == "obox":
            # Kante wie beim Quader: der Shader zieht sie ueber die UV der Ecken
            for normal, points in _obox_faces(*shape[1:4]):
                faces.append([shape[4], "box", [_r(c) for c in normal],
                              [[_r(c) for c in p] for p in points]])
        elif shape[0] == "poly":
            # Dreiecke ohne Kante: Grat und Schneide zeichnen die Flaechen selbst.
            for face in shape[1]:
                kind = "box" if len(face) > 2 and face[2] and len(face[1]) == 4 else "seam"
                faces.append([shape[2], kind, [_r(c) for c in face[0]],
                              [[_r(c) for c in p] for p in face[1]]])
        elif shape[0] == "disc":
            _, f, lc, zc, radius, mat, segments = shape
            points = [[_r(f), _r(lc + radius * math.cos(2 * math.pi * i / segments)),
                       _r(zc + radius * math.sin(2 * math.pi * i / segments))]
                      for i in range(segments)]
            faces.append([mat, "disc", [1, 0, 0], points])
        elif shape[0] == "lathe":
            _, center, profile, mat, axis, segments, caps = shape
            for normal, points in _lathe_faces(center, profile, axis, segments, caps):
                faces.append([mat, "seam", [_r(c) for c in normal],
                              [[_r(c) for c in p] for p in points]])
            if MATERIALS[mat][3]:
                grown = [(r + HULL_GROW if r > 0 else 0.0, t) for r, t in profile]
                if grown[0][0] == 0.0:
                    grown[0] = (0.0, grown[0][1] - HULL_GROW)
                if grown[-1][0] == 0.0:
                    grown[-1] = (0.0, grown[-1][1] + HULL_GROW)
                closed = profile[0] == profile[-1]
                for normal, points in _lathe_faces(center, grown, axis, segments,
                                                   caps and not closed):
                    hulls.append([[_r(c) for c in normal],
                                  [[_r(c) for c in p] for p in points]])
        else:
            raise ValueError(f"Unbekanntes Primitiv: {shape[0]}")
    return faces, hulls


def _shape_center(shape) -> tuple:
    """Grobe Mitte (l, z) einer Form -- reicht zum Zuordnen zu einem Bein."""
    kind = shape[0]
    if kind == "box":
        return (sum(shape[2]) / 2, sum(shape[3]) / 2)
    if kind == "disc":
        return (shape[2], shape[3])
    if kind == "obox":
        return (shape[1][1], shape[1][2])
    if kind == "poly":
        pts = [pt for face in shape[1] for pt in face[1]]
        return (sum(pt[1] for pt in pts) / len(pts), sum(pt[2] for pt in pts) / len(pts))
    _, c, prof, _mat, axis, _seg, _caps = shape
    ts = [t for _r, t in prof]
    if axis == "z":
        return (c[1], (min(ts) + max(ts)) / 2)
    if axis == "f":
        return (c[0], c[1])
    return ((min(ts) + max(ts)) / 2, c[1])


def split_legs(shapes, spec) -> dict:
    """
    Teilt die Formen eines Antriebs in Beine (18. Nov. 2026): je Seite
    Ober- und Unterschenkel (``leg_<seite>_upper``/``_lower``) mit den
    Drehpunkten ``mount`` (Huefte bzw. Knie). Was ueber ``static_z`` oder
    auf der Mitte liegt, bleibt am Rumpf (``static``).
    """
    hip, knee = spec["hip"], spec["knee"]
    split_z, static_z = spec["split_z"], spec.get("static_z", 999)
    out = {"static": []}
    groups = {}
    for shape in shapes:
        l, z = _shape_center(shape)
        if z >= static_z or abs(l) < 0.5:
            out["static"].append(shape)
            continue
        side = "left" if l > 0 else "right"
        seg = "upper" if z >= split_z else "lower"
        groups.setdefault((side, seg), []).append(shape)
    for side, sign in (("left", 1), ("right", -1)):
        h = (hip[0], hip[1] * sign, hip[2])
        k = (knee[0], knee[1] * sign, knee[2])
        out[f"leg_{side}_upper"] = (groups.get((side, "upper"), []),
                                    {"mount": h, "knee": k})
        out[f"leg_{side}_lower"] = (groups.get((side, "lower"), []), {"mount": k})
    return out


def write_model(set_dir: pathlib.Path, part: dict, palette: dict) -> None:
    """Das 3D-Modell eines Teils: ``<id>.m3d`` (JSON)."""
    pid = part["id"]

    def block(shapes, anchors):
        faces, hulls = model_faces(shapes)
        return {"faces": faces, "hulls": hulls,
                "anchors": {k: [_r(c) for c in v] for k, v in anchors.items()}}

    passive = part.get("passive_shapes", [])
    main = [sh for sh in part["shapes"] if sh not in passive]
    legs = split_legs(main, part["legs"]) if part.get("legs") else {}
    if legs:
        main = legs.pop("static")
    model = {
        "id": pid, "type": part["type"],
        "colors": resolve_roles(WEAPON_COLORS.get(pid, part.get(
            "palette", palette[palette_type(part["type"])])), part["type"]),
        **block(main, part["anchors"]),
    }
    variants = {}
    if passive:
        # Sichtbare Passive als eigener Block, der sich im Kampf bewegt
        # (Arena3D); im SVG bleibt sie Teil des Rumpfs.
        variants["passive"] = block(passive, {"mount": part["anchors"].get("mount", (0, 0, 0))})
    for vname, (shapes, anchors) in legs.items():
        # Beine als eigene Bloecke, die im Kampf im Wechsel schwingen.
        variants[vname] = block(shapes, anchors)
    for vname, vspec in part.get("variants", {}).items():
        variants[vname] = block(vspec["shapes"], vspec["anchors"])
    for slot, poses in part.get("arms", {}).items():
        for pose, (shapes, hand) in poses.items():
            variants[f"arm_{slot}_{pose}"] = block(
                shapes, {"mount": part["anchors"][slot], "hand": hand})
    if variants:
        model["variants"] = variants
    if part.get("pose"):
        model["pose"] = part["pose"]
    finish = WEAPON_FINISH.get(pid, {})
    if "neon" in part.get("tags", []) or finish.get("neon"):
        model["neon"] = True       # Leuchtroehren (glow/accent) leuchten im Spiel
    if finish.get("shine"):
        model["shine"] = finish["shine"]   # Glanzkante je Material (drome_face)
    (set_dir / f"{pid}.m3d").write_text(
        json.dumps(model, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8")


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
        "color_scheme": resolve_roles(WEAPON_COLORS.get(pid, part.get(
                                          "palette", palette[palette_type(part["type"])])),
                                      part["type"]),
        "tags": part.get("tags", []),
    }
    if part["type"].startswith("equipment"):
        # Nah oder fern ergibt sich aus der Reichweite, nicht aus der Hand.
        meta["tags"] = [t for t in meta["tags"] if t not in REACH_KINDS] \
            + [reach_kind(pid)]
    if part["type"] == "body":
        meta["body_kind"] = part.get("body_kind", "humanoid")
        if part.get("weapon_variant"):
            meta["weapon_variant"] = part["weapon_variant"]
        meta["slot_z"] = slot_draw_order(part, direction)
        if "slot_rules" in part:
            meta["slot_rules"] = part["slot_rules"]
    if part["type"].startswith("equipment"):
        meta["mount_class"] = part.get("mount_class", DEFAULT_MOUNT_CLASS)
        meta["category"] = part.get("category", DEFAULT_CATEGORY)
        if part.get("pose"):
            meta["pose"] = part["pose"]
    # Varianten (Molok-Waffenmass, Strix-Lafette, Arme je Haltung) gibt es
    # seit 20. Nov. 2026 nur noch im 3D-Modell (write_model) -- als Bild wurden
    # sie nur von der entfernten SVG-Werkstatt gebraucht.
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
            # Seit 20. Nov. 2026 nur die Suedansicht: sie ist das Symbol fuer
            # Kacheln und Halter (UiKit.part_texture). Gezeichnet wird im Spiel
            # das 3D-Modell; die vier Richtungen brauchte nur die entfernte
            # SVG-Werkstatt (docs/TECHNIK_PRUEFUNG.md, Schritt C).
            write_part(set_dir, spec["id"], part, SYMBOL_DIRECTION, spec["palette"])
            write_model(set_dir, part, spec["palette"])

        print(f"[ok] {spec['dir']}: {len(spec['parts'])} Teile (Modell + Symbol) geschrieben")

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
                if rule.get("reach") and rule["reach"] not in REACH_KINDS:
                    raise SystemExit(f"{where}/{slot}: unbekannte "
                                     f"Reichweite {rule['reach']!r}")
            if part.get("body_kind", "humanoid") not in BODY_KINDS:
                raise SystemExit(f"{where}: unbekannte Koerperart")
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
        if part.get("variant_of"):
            continue    # Varianten teilen die Form ihrer Grundwaffe mit Absicht
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
    Jeder Bausatz muss sich selbst bauen koennen: eigener Kopf, Kern, Antrieb
    und die eigene Ausruestung in seinen Ankern -- mit mindestens einer Waffe
    und SPD >= 1 nach Abzug des Gewichts.
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
        sockets = [body] + [parts[t] for t in ("head", "feet", "core") if t in parts]

        equipment = [p for p in spec["parts"] if p["type"].startswith("equipment")]
        equipment.sort(key=lambda p: p.get("category", DEFAULT_CATEGORY) != "weapon")
        chosen = list(sockets)
        for slot in slots:
            for p in equipment:
                if p in chosen:
                    continue
                if fits_rule(p.get("mount_class", DEFAULT_MOUNT_CLASS),
                             p.get("category", DEFAULT_CATEGORY), rules.get(slot),
                             reach_kind(p["id"])):
                    chosen.append(p)
                    break

        stats = {k: 0 for k in ("hp", "spd", "def", "power")}
        has_weapon = False
        for p in chosen:
            s = part_stats(p["id"])
            for k in stats:
                stats[k] += s[k]
            if p.get("category") == "weapon":
                has_weapon = True

        problems = []
        if not has_weapon:
            problems.append("keine Waffe")
        if stats["spd"] < 1:
            problems.append(f"spd {stats['spd']}")
        if problems:
            raise SystemExit(f"{spec['id']}: der eigene Standardaufbau ist "
                             f"ungueltig -- {', '.join(problems)}.")
        rows.append((spec["id"], stats))

    print("\nStandardaufbau je Bausatz (eigene Teile, alle Anker belegt):")
    print(f"  {'':<7}{'HP':>5}{'SPD':>5}{'DEF':>5}{'Power':>7}")
    for where, s in rows:
        print(f"  {where:<7}{s['hp']:>5}{s['spd']:>5}{s['def']:>5}{s['power']:>7}")


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
                             eq_part.get("category", DEFAULT_CATEGORY), rule,
                             reach_kind(eq_part["id"]))
                and slot in eq_part.get("slots", [slot])
            ]
            print(f"  {spec['id']}/{slot:<14} bis {limit:<7}"
                  f"{'/'.join(cats):<22} {' '.join(allowed) or '--'}")


if __name__ == "__main__":
    main()
