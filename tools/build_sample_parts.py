#!/usr/bin/env python3
"""
build_sample_parts.py -- Generator fuer den mitgelieferten Beispiel-Teilesatz.

Dieses Skript ist bewusst Teil des Repos: es dient gleichzeitig als
*ausfuehrbare Spezifikation* des Part-Formats. Wer ein neues Bot-Set
anlegen will, kann hier abschauen, welche Felder erwartet werden, und
das Ergebnis mit

    python3 tools/build_sample_parts.py

neu erzeugen.

Koordinatensystem
-----------------
Alle Teile teilen sich EIN gemeinsames Koordinatensystem: viewBox "0 0 128 128".
Dadurch sind Anker direkt vergleichbar und das Zusammensetzen ist eine
reine Translation.

    x = 64   -> Mittelachse
    y = 120  -> Bodenlinie (Tile-Kontaktpunkt)

"links" / "rechts" sind immer BILDSCHIRM-seitig gemeint, nicht aus Sicht
des Bots. Das haelt die Anker ueber alle vier Richtungen hinweg eindeutig.

Farben
------
Kein Teil enthaelt Hardcoded-Hex-Werte. Alles laeuft ueber CSS Custom
Properties (siehe PALETTE_ROLES). Das Werkstatt-Tool setzt diese Variablen
auf dem Container -- damit ist Umfaerben in Echtzeit moeglich, ohne die
SVG-Datei anzufassen.
"""

from __future__ import annotations

import json
import pathlib
import shutil

ROOT = pathlib.Path(__file__).resolve().parent.parent
PARTS_DIR = ROOT / "parts"

# ---------------------------------------------------------------------------
# Palettenrollen -- jede Rolle ist eine CSS-Variable, die im SVG benutzt wird.
# ---------------------------------------------------------------------------
PALETTE_ROLES = [
    "plate",       # Haupt-Panzerung
    "plate_dark",  # Schattenseite / Untergrund
    "plate_light", # Highlight-Kante
    "metal",       # Gelenke, Rahmen, Mechanik
    "accent",      # Neon-Streifen
    "glow",        # Kern / Emission
    "visor",       # Visier / Sensorik
    "outline",     # Kontur
]

DEFAULT_PALETTE = {
    "plate": "#232a3d",
    "plate_dark": "#151a29",
    "plate_light": "#3a4560",
    "metal": "#5b6785",
    "accent": "#2de2e6",
    "glow": "#ff2d95",
    "visor": "#7cf9ff",
    "outline": "#0a0d16",
}

JUGG_PALETTE = {
    "plate": "#3a2a33",
    "plate_dark": "#20151c",
    "plate_light": "#57404c",
    "metal": "#7d6b78",
    "accent": "#ff8a3d",
    "glow": "#ffd447",
    "visor": "#ffb057",
    "outline": "#120b10",
}

C = {role: f"var(--c-{role.replace('_', '-')})" for role in PALETTE_ROLES}

# Standard-Zeichenreihenfolge pro Typ (kann pro Teil ueberschrieben werden).
DEFAULT_Z = {
    "feet": 10,
    "body": 20,
    "core": 26,
    "equipment": 30,
    "equipment_left": 30,
    "equipment_right": 30,
    "head": 40,
}

DIRECTIONS = ["south", "west", "east", "north"]


# ---------------------------------------------------------------------------
# Hilfsfunktionen
# ---------------------------------------------------------------------------
def g(content: str, extra: str = "") -> str:
    """Umschliesst Inhalt mit den gemeinsamen Stroke-Defaults."""
    return (
        f'<g fill="none" stroke="{C["outline"]}" stroke-width="1.6" '
        f'stroke-linejoin="round" stroke-linecap="round"{(" " + extra) if extra else ""}>\n'
        f"{content}\n</g>"
    )


def mirror_x(value: float) -> float:
    return round(128 - value, 2)


def mirrored_anchors(anchors: dict[str, tuple[float, float]]) -> dict:
    """Spiegelt Anker an der Mittelachse und tauscht left/right-Namen."""
    swap = {"equip_left": "equip_right", "equip_right": "equip_left"}
    return {
        swap.get(name, name): (mirror_x(x), y) for name, (x, y) in anchors.items()
    }


def mirror_svg(inner: str) -> str:
    return (
        '<!-- gespiegelt aus der east-Variante -->\n'
        '<g transform="translate(128,0) scale(-1,1)">\n' + inner + "\n</g>"
    )


# ---------------------------------------------------------------------------
# SCOUT  (parts/bot1) -- schlanker Aufklaerer
# ---------------------------------------------------------------------------

SCOUT_BODY_SOUTH = g(f"""
  <path d="M36 52 L47 46 L49 68 L38 72 Z" fill="{C['plate_dark']}"/>
  <path d="M92 52 L81 46 L79 68 L90 72 Z" fill="{C['plate_dark']}"/>
  <path d="M47 45 H81 L86 60 L81 84 H47 L42 60 Z" fill="{C['plate']}"/>
  <path d="M52 45 H76 L78 53 H50 Z" fill="{C['plate_light']}"/>
  <rect x="58" y="38" width="12" height="9" rx="2.5" fill="{C['metal']}"/>
  <path d="M54 57 H74" stroke="{C['accent']}" stroke-width="2.4"/>
  <path d="M50 76 H78" stroke="{C['accent']}" stroke-width="1.8" opacity="0.7"/>
  <circle cx="64" cy="67" r="8.5" fill="{C['plate_dark']}"/>
  <path d="M47 83 H81 L78 90 H50 Z" fill="{C['metal']}"/>
""")

SCOUT_BODY_NORTH = g(f"""
  <path d="M36 52 L47 46 L49 68 L38 72 Z" fill="{C['plate_dark']}"/>
  <path d="M92 52 L81 46 L79 68 L90 72 Z" fill="{C['plate_dark']}"/>
  <path d="M47 45 H81 L86 60 L81 84 H47 L42 60 Z" fill="{C['plate_dark']}"/>
  <rect x="53" y="50" width="22" height="26" rx="3" fill="{C['plate']}"/>
  <path d="M57 55 H71 M57 61 H71 M57 67 H71" stroke="{C['plate_light']}" stroke-width="1.6"/>
  <rect x="58" y="38" width="12" height="9" rx="2.5" fill="{C['metal']}"/>
  <circle cx="64" cy="63" r="4" fill="{C['glow']}" stroke="none"/>
  <path d="M47 83 H81 L78 90 H50 Z" fill="{C['metal']}"/>
""")

SCOUT_BODY_EAST = g(f"""
  <path d="M55 47 L74 47 L79 62 L74 84 L55 84 L52 62 Z" fill="{C['plate']}"/>
  <path d="M55 47 L74 47 L75 54 L55 54 Z" fill="{C['plate_light']}"/>
  <rect x="58" y="38" width="11" height="9" rx="2.5" fill="{C['metal']}"/>
  <path d="M58 60 H74" stroke="{C['accent']}" stroke-width="2.4"/>
  <circle cx="70" cy="67" r="7" fill="{C['plate_dark']}"/>
  <path d="M50 50 L57 47 L59 68 L51 71 Z" fill="{C['plate_dark']}"/>
  <path d="M56 83 H76 L74 90 H57 Z" fill="{C['metal']}"/>
""")

SCOUT_HEAD_SOUTH = g(f"""
  <path d="M64 12 V22" stroke="{C['metal']}" stroke-width="2"/>
  <circle cx="64" cy="11" r="2.6" fill="{C['glow']}" stroke="none"/>
  <path d="M52 24 Q64 17 76 24 L78 38 Q64 44 50 38 Z" fill="{C['plate']}"/>
  <path d="M53 27 Q64 22 75 27 L75 33 Q64 37 53 33 Z" fill="{C['visor']}" stroke="none"/>
  <path d="M53 27 Q64 22 75 27 L75 33 Q64 37 53 33 Z" fill="none"/>
  <path d="M50 38 H78 L76 43 H52 Z" fill="{C['metal']}"/>
""")

SCOUT_HEAD_NORTH = g(f"""
  <path d="M64 12 V22" stroke="{C['metal']}" stroke-width="2"/>
  <circle cx="64" cy="11" r="2.6" fill="{C['glow']}" stroke="none"/>
  <path d="M52 24 Q64 17 76 24 L78 38 Q64 44 50 38 Z" fill="{C['plate_dark']}"/>
  <path d="M58 28 H70 M58 33 H70" stroke="{C['plate_light']}" stroke-width="1.6"/>
  <path d="M50 38 H78 L76 43 H52 Z" fill="{C['metal']}"/>
""")

SCOUT_HEAD_EAST = g(f"""
  <path d="M64 12 V22" stroke="{C['metal']}" stroke-width="2"/>
  <circle cx="64" cy="11" r="2.6" fill="{C['glow']}" stroke="none"/>
  <path d="M54 25 Q64 17 74 25 L75 38 Q63 43 53 38 Z" fill="{C['plate']}"/>
  <path d="M64 26 Q71 24 74 28 L74 34 Q69 36 64 35 Z" fill="{C['visor']}" stroke="none"/>
  <path d="M64 26 Q71 24 74 28 L74 34 Q69 36 64 35 Z"/>
  <path d="M53 38 H75 L73 43 H55 Z" fill="{C['metal']}"/>
""")

SCOUT_FEET_SOUTH = g(f"""
  <path d="M52 88 H60 L59 104 L53 104 Z" fill="{C['plate']}"/>
  <path d="M68 88 H76 L75 104 L69 104 Z" fill="{C['plate']}"/>
  <circle cx="56" cy="105" r="4" fill="{C['metal']}"/>
  <circle cx="72" cy="105" r="4" fill="{C['metal']}"/>
  <path d="M50 109 H62 L64 118 H48 Z" fill="{C['plate_dark']}"/>
  <path d="M66 109 H78 L80 118 H64 Z" fill="{C['plate_dark']}"/>
  <path d="M49 116 H63 M65 116 H79" stroke="{C['accent']}" stroke-width="1.6"/>
""")

SCOUT_FEET_NORTH = g(f"""
  <path d="M52 88 H60 L59 104 L53 104 Z" fill="{C['plate_dark']}"/>
  <path d="M68 88 H76 L75 104 L69 104 Z" fill="{C['plate_dark']}"/>
  <circle cx="56" cy="105" r="4" fill="{C['metal']}"/>
  <circle cx="72" cy="105" r="4" fill="{C['metal']}"/>
  <path d="M50 109 H62 L62 118 H48 Z" fill="{C['plate']}"/>
  <path d="M66 109 H78 L80 118 H66 Z" fill="{C['plate']}"/>
""")

SCOUT_FEET_EAST = g(f"""
  <path d="M58 88 H68 L66 104 L59 104 Z" fill="{C['plate_dark']}"/>
  <path d="M62 88 H72 L71 104 L64 104 Z" fill="{C['plate']}"/>
  <circle cx="67" cy="105" r="4.2" fill="{C['metal']}"/>
  <path d="M58 110 H76 L78 118 H55 Z" fill="{C['plate']}"/>
  <path d="M56 116 H77" stroke="{C['accent']}" stroke-width="1.6"/>
""")

SCOUT_CORE_SOUTH = g(f"""
  <circle cx="64" cy="67" r="7" fill="{C['plate_dark']}"/>
  <circle cx="64" cy="67" r="4.4" fill="{C['glow']}" stroke="none"/>
  <circle cx="64" cy="67" r="4.4" opacity="0.9"/>
  <path d="M64 60 V63 M64 71 V74 M57 67 H60 M68 67 H71" stroke="{C['accent']}" stroke-width="1.6"/>
""")

SCOUT_CORE_EAST = g(f"""
  <circle cx="70" cy="67" r="5.8" fill="{C['plate_dark']}"/>
  <circle cx="70" cy="67" r="3.6" fill="{C['glow']}" stroke="none"/>
  <circle cx="70" cy="67" r="3.6" opacity="0.9"/>
""")

SCOUT_CORE_NORTH = g(f"""
  <rect x="56" y="57" width="16" height="14" rx="3" fill="{C['plate_dark']}"/>
  <path d="M59 61 H69 M59 66 H69" stroke="{C['glow']}" stroke-width="2"/>
""")

# --- Ausruestung: Puls-Blaster (Griffpunkt = mount) --------------------------
EQ_BLASTER_SOUTH = g(f"""
  <rect x="27" y="58" width="9" height="13" rx="2.5" fill="{C['metal']}"/>
  <path d="M20 62 H31 L33 74 H22 Z" fill="{C['plate']}"/>
  <rect x="17" y="65" width="6" height="5" rx="1.5" fill="{C['plate_dark']}"/>
  <circle cx="19" cy="67.5" r="2" fill="{C['glow']}" stroke="none"/>
  <path d="M22 70 H31" stroke="{C['accent']}" stroke-width="1.6"/>
""")

EQ_BLASTER_EAST = g(f"""
  <rect x="74" y="58" width="9" height="12" rx="2.5" fill="{C['metal']}"/>
  <path d="M78 60 H100 L102 68 H78 Z" fill="{C['plate']}"/>
  <rect x="100" y="61" width="8" height="6" rx="2" fill="{C['plate_dark']}"/>
  <circle cx="106" cy="64" r="2.2" fill="{C['glow']}" stroke="none"/>
  <path d="M80 65 H98" stroke="{C['accent']}" stroke-width="1.6"/>
""")

EQ_BLASTER_NORTH = g(f"""
  <rect x="27" y="58" width="9" height="13" rx="2.5" fill="{C['metal']}"/>
  <path d="M22 62 H33 L33 74 H24 Z" fill="{C['plate_dark']}"/>
  <path d="M25 66 H31" stroke="{C['accent']}" stroke-width="1.6"/>
""")

# --- Ausruestung: Deflektor-Schild ------------------------------------------
EQ_SHIELD_SOUTH = g(f"""
  <rect x="92" y="60" width="8" height="11" rx="2.5" fill="{C['metal']}"/>
  <path d="M98 48 Q114 52 114 66 Q114 80 98 84 Z" fill="{C['plate']}"/>
  <path d="M100 54 Q110 57 110 66 Q110 75 100 78 Z" fill="{C['plate_dark']}"/>
  <path d="M104 60 V72" stroke="{C['accent']}" stroke-width="2.2"/>
""")

EQ_SHIELD_EAST = g(f"""
  <rect x="72" y="60" width="8" height="11" rx="2.5" fill="{C['metal']}"/>
  <path d="M78 48 Q86 52 86 66 Q86 80 78 84 Z" fill="{C['plate']}"/>
  <path d="M82 58 V74" stroke="{C['accent']}" stroke-width="2.2"/>
""")

EQ_SHIELD_NORTH = g(f"""
  <rect x="92" y="60" width="8" height="11" rx="2.5" fill="{C['metal']}"/>
  <path d="M98 48 Q114 52 114 66 Q114 80 98 84 Z" fill="{C['plate_dark']}"/>
  <path d="M102 56 H110 M102 66 H110 M102 76 H110" stroke="{C['plate_light']}" stroke-width="1.6"/>
""")


# ---------------------------------------------------------------------------
# JUGGERNAUT (parts/bot2) -- schwerer Rahmen, 3 Ausruestungsslots
# ---------------------------------------------------------------------------

JUGG_BODY_SOUTH = g(f"""
  <path d="M28 48 L44 42 L47 70 L31 76 Z" fill="{C['plate_dark']}"/>
  <path d="M100 48 L84 42 L81 70 L97 76 Z" fill="{C['plate_dark']}"/>
  <path d="M42 42 H86 L92 60 L86 86 H42 L36 60 Z" fill="{C['plate']}"/>
  <path d="M48 42 H80 L82 52 H46 Z" fill="{C['plate_light']}"/>
  <rect x="56" y="34" width="16" height="10" rx="2.5" fill="{C['metal']}"/>
  <rect x="46" y="56" width="36" height="6" rx="2" fill="{C['plate_dark']}"/>
  <path d="M49 59 H79" stroke="{C['accent']}" stroke-width="2.2"/>
  <circle cx="64" cy="72" r="10" fill="{C['plate_dark']}"/>
  <path d="M42 85 H86 L82 93 H46 Z" fill="{C['metal']}"/>
""")

JUGG_BODY_NORTH = g(f"""
  <path d="M28 48 L44 42 L47 70 L31 76 Z" fill="{C['plate_dark']}"/>
  <path d="M100 48 L84 42 L81 70 L97 76 Z" fill="{C['plate_dark']}"/>
  <path d="M42 42 H86 L92 60 L86 86 H42 L36 60 Z" fill="{C['plate_dark']}"/>
  <rect x="48" y="46" width="32" height="34" rx="4" fill="{C['plate']}"/>
  <path d="M53 52 H75 M53 60 H75 M53 68 H75" stroke="{C['plate_light']}" stroke-width="2"/>
  <rect x="56" y="34" width="16" height="10" rx="2.5" fill="{C['metal']}"/>
  <circle cx="64" cy="74" r="4.5" fill="{C['glow']}" stroke="none"/>
  <path d="M42 85 H86 L82 93 H46 Z" fill="{C['metal']}"/>
""")

JUGG_BODY_EAST = g(f"""
  <path d="M46 48 L56 43 L58 70 L48 74 Z" fill="{C['plate_dark']}"/>
  <path d="M52 43 H82 L88 60 L82 86 H52 L48 60 Z" fill="{C['plate']}"/>
  <path d="M52 43 H82 L83 52 H52 Z" fill="{C['plate_light']}"/>
  <rect x="56" y="34" width="15" height="10" rx="2.5" fill="{C['metal']}"/>
  <path d="M55 59 H82" stroke="{C['accent']}" stroke-width="2.2"/>
  <circle cx="72" cy="72" r="8" fill="{C['plate_dark']}"/>
  <path d="M52 85 H84 L81 93 H55 Z" fill="{C['metal']}"/>
""")

JUGG_HEAD_SOUTH = g(f"""
  <path d="M48 22 H80 L82 36 L76 42 H52 L46 36 Z" fill="{C['plate']}"/>
  <rect x="50" y="26" width="28" height="8" rx="2" fill="{C['visor']}" stroke="none"/>
  <rect x="50" y="26" width="28" height="8" rx="2"/>
  <path d="M46 18 H54 V24 H46 Z" fill="{C['metal']}"/>
  <path d="M74 18 H82 V24 H74 Z" fill="{C['metal']}"/>
  <path d="M52 42 H76 L74 46 H54 Z" fill="{C['metal']}"/>
""")

JUGG_HEAD_NORTH = g(f"""
  <path d="M48 22 H80 L82 36 L76 42 H52 L46 36 Z" fill="{C['plate_dark']}"/>
  <path d="M54 28 H74 M54 34 H74" stroke="{C['plate_light']}" stroke-width="2"/>
  <path d="M46 18 H54 V24 H46 Z" fill="{C['metal']}"/>
  <path d="M74 18 H82 V24 H74 Z" fill="{C['metal']}"/>
  <path d="M52 42 H76 L74 46 H54 Z" fill="{C['metal']}"/>
""")

JUGG_HEAD_EAST = g(f"""
  <path d="M50 22 H78 L80 36 L74 42 H54 L48 36 Z" fill="{C['plate']}"/>
  <path d="M64 26 H78 L79 34 H64 Z" fill="{C['visor']}" stroke="none"/>
  <path d="M64 26 H78 L79 34 H64 Z"/>
  <path d="M48 18 H58 V24 H48 Z" fill="{C['metal']}"/>
  <path d="M54 42 H76 L74 46 H56 Z" fill="{C['metal']}"/>
""")

JUGG_FEET_SOUTH = g(f"""
  <path d="M44 91 H60 L58 106 L46 106 Z" fill="{C['plate']}"/>
  <path d="M68 91 H84 L82 106 L70 106 Z" fill="{C['plate']}"/>
  <circle cx="52" cy="107" r="5" fill="{C['metal']}"/>
  <circle cx="76" cy="107" r="5" fill="{C['metal']}"/>
  <path d="M40 111 H62 L64 121 H37 Z" fill="{C['plate_dark']}"/>
  <path d="M66 111 H88 L91 121 H64 Z" fill="{C['plate_dark']}"/>
  <path d="M39 118 H63 M65 118 H90" stroke="{C['accent']}" stroke-width="1.8"/>
""")

JUGG_FEET_NORTH = g(f"""
  <path d="M44 91 H60 L58 106 L46 106 Z" fill="{C['plate_dark']}"/>
  <path d="M68 91 H84 L82 106 L70 106 Z" fill="{C['plate_dark']}"/>
  <circle cx="52" cy="107" r="5" fill="{C['metal']}"/>
  <circle cx="76" cy="107" r="5" fill="{C['metal']}"/>
  <path d="M40 111 H62 L62 121 H38 Z" fill="{C['plate']}"/>
  <path d="M66 111 H88 L90 121 H66 Z" fill="{C['plate']}"/>
""")

JUGG_FEET_EAST = g(f"""
  <path d="M52 91 H68 L66 106 L54 106 Z" fill="{C['plate_dark']}"/>
  <path d="M58 91 H76 L74 106 L62 106 Z" fill="{C['plate']}"/>
  <circle cx="68" cy="107" r="5.2" fill="{C['metal']}"/>
  <path d="M52 112 H82 L85 121 H48 Z" fill="{C['plate']}"/>
  <path d="M49 118 H84" stroke="{C['accent']}" stroke-width="1.8"/>
""")

JUGG_CORE_SOUTH = g(f"""
  <circle cx="64" cy="72" r="8.5" fill="{C['plate_dark']}"/>
  <path d="M64 65 L70 69 V76 L64 80 L58 76 V69 Z" fill="{C['glow']}" stroke="none"/>
  <path d="M64 65 L70 69 V76 L64 80 L58 76 V69 Z" opacity="0.9"/>
""")

JUGG_CORE_EAST = g(f"""
  <circle cx="72" cy="72" r="7" fill="{C['plate_dark']}"/>
  <path d="M72 66 L77 70 V76 L72 79 L67 76 V70 Z" fill="{C['glow']}" stroke="none"/>
  <path d="M72 66 L77 70 V76 L72 79 L67 76 V70 Z" opacity="0.9"/>
""")

JUGG_CORE_NORTH = g(f"""
  <rect x="54" y="64" width="20" height="16" rx="3" fill="{C['plate_dark']}"/>
  <path d="M58 69 H70 M58 75 H70" stroke="{C['glow']}" stroke-width="2.4"/>
""")

EQ_CANNON_SOUTH = g(f"""
  <rect x="20" y="56" width="12" height="16" rx="3" fill="{C['metal']}"/>
  <path d="M8 56 H26 L28 76 H10 Z" fill="{C['plate']}"/>
  <rect x="2" y="60" width="8" height="10" rx="2" fill="{C['plate_dark']}"/>
  <circle cx="6" cy="65" r="2.6" fill="{C['glow']}" stroke="none"/>
  <path d="M12 72 H26" stroke="{C['accent']}" stroke-width="2"/>
""")

EQ_CANNON_EAST = g(f"""
  <rect x="76" y="56" width="12" height="15" rx="3" fill="{C['metal']}"/>
  <path d="M80 56 H108 L110 72 H80 Z" fill="{C['plate']}"/>
  <rect x="108" y="59" width="10" height="9" rx="2" fill="{C['plate_dark']}"/>
  <circle cx="115" cy="63.5" r="2.6" fill="{C['glow']}" stroke="none"/>
  <path d="M84 68 H106" stroke="{C['accent']}" stroke-width="2"/>
""")

EQ_CANNON_NORTH = g(f"""
  <rect x="20" y="56" width="12" height="16" rx="3" fill="{C['metal']}"/>
  <path d="M12 56 H30 L30 76 H14 Z" fill="{C['plate_dark']}"/>
  <path d="M16 62 H28 M16 70 H28" stroke="{C['accent']}" stroke-width="1.8"/>
""")

EQ_DRONEPOD_SOUTH = g(f"""
  <rect x="58" y="24" width="12" height="8" rx="2" fill="{C['metal']}"/>
  <path d="M50 8 H78 L82 20 L64 26 L46 20 Z" fill="{C['plate']}"/>
  <path d="M56 12 H72 L74 19 L64 22 L54 19 Z" fill="{C['plate_dark']}"/>
  <circle cx="64" cy="16" r="3" fill="{C['glow']}" stroke="none"/>
""")

EQ_DRONEPOD_EAST = g(f"""
  <rect x="58" y="24" width="11" height="8" rx="2" fill="{C['metal']}"/>
  <path d="M52 9 H76 L79 20 L63 25 L49 20 Z" fill="{C['plate']}"/>
  <circle cx="66" cy="16" r="3" fill="{C['glow']}" stroke="none"/>
""")

EQ_DRONEPOD_NORTH = g(f"""
  <rect x="58" y="24" width="12" height="8" rx="2" fill="{C['metal']}"/>
  <path d="M50 8 H78 L82 20 L64 26 L46 20 Z" fill="{C['plate_dark']}"/>
  <path d="M52 14 H76" stroke="{C['plate_light']}" stroke-width="2"/>
""")


# ---------------------------------------------------------------------------
# Teile-Spezifikation
#
# Jeder Eintrag: (id, type, {direction: (svg_inner, anchors)}, extras)
# "west" wird automatisch aus "east" gespiegelt, wenn nicht angegeben.
# ---------------------------------------------------------------------------

SETS = [
    {
        "dir": "bot1",
        "id": "bot1",
        "name": "RX-Vireo // Scout",
        "description": "Leichter Aufklaerer-Drone. Zwei Ausruestungsanker.",
        "palette": DEFAULT_PALETTE,
        "parts": [
            {
                "id": "scout_body",
                "type": "body",
                "name": "Vireo Chassis",
                "tags": ["light", "scout"],
                "dirs": {
                    "south": (SCOUT_BODY_SOUTH, {
                        "mount": (64, 64),
                        "head": (64, 42),
                        "feet": (64, 88),
                        "equip_left": (40, 62),
                        "equip_right": (88, 62),
                        "core": (64, 67),
                    }),
                    "north": (SCOUT_BODY_NORTH, {
                        "mount": (64, 64),
                        "head": (64, 42),
                        "feet": (64, 88),
                        "equip_left": (40, 62),
                        "equip_right": (88, 62),
                        "core": (64, 63),
                    }),
                    "east": (SCOUT_BODY_EAST, {
                        "mount": (64, 64),
                        "head": (64, 42),
                        "feet": (64, 88),
                        "equip_left": (56, 62),
                        "equip_right": (70, 62),
                        "core": (70, 67),
                    }),
                },
                "slot_z": {
                    "south": {"equip_left": 30, "equip_right": 30},
                    "north": {"equip_left": 14, "equip_right": 14},
                    "east": {"equip_left": 14, "equip_right": 32},
                    "west": {"equip_left": 32, "equip_right": 14},
                },
            },
            {
                "id": "scout_head",
                "type": "head",
                "name": "Vireo Sensorkopf",
                "tags": ["light", "sensor"],
                "dirs": {
                    "south": (SCOUT_HEAD_SOUTH, {"mount": (64, 42)}),
                    "north": (SCOUT_HEAD_NORTH, {"mount": (64, 42)}),
                    "east": (SCOUT_HEAD_EAST, {"mount": (64, 42)}),
                },
            },
            {
                "id": "scout_feet",
                "type": "feet",
                "name": "Vireo Sprintbeine",
                "tags": ["light", "fast"],
                "dirs": {
                    "south": (SCOUT_FEET_SOUTH, {"mount": (64, 88), "ground": (64, 119)}),
                    "north": (SCOUT_FEET_NORTH, {"mount": (64, 88), "ground": (64, 119)}),
                    "east": (SCOUT_FEET_EAST, {"mount": (64, 88), "ground": (66, 119)}),
                },
            },
            {
                "id": "scout_core",
                "type": "core",
                "name": "Vireo Impulskern",
                "tags": ["core", "energy"],
                "dirs": {
                    "south": (SCOUT_CORE_SOUTH, {"mount": (64, 67)}),
                    "north": (SCOUT_CORE_NORTH, {"mount": (64, 63)}),
                    "east": (SCOUT_CORE_EAST, {"mount": (70, 67)}),
                },
            },
            {
                "id": "eq_pulse_blaster",
                "type": "equipment",
                "name": "Puls-Blaster",
                "tags": ["weapon", "ranged"],
                "slots": ["equip_left", "equip_right"],
                "dirs": {
                    "south": (EQ_BLASTER_SOUTH, {"mount": (31, 64)}),
                    "north": (EQ_BLASTER_NORTH, {"mount": (31, 64)}),
                    "east": (EQ_BLASTER_EAST, {"mount": (78, 64)}),
                },
            },
            {
                "id": "eq_deflector",
                "type": "equipment",
                "name": "Deflektor-Schild",
                "tags": ["defense"],
                "slots": ["equip_left", "equip_right"],
                "dirs": {
                    "south": (EQ_SHIELD_SOUTH, {"mount": (96, 64)}),
                    "north": (EQ_SHIELD_NORTH, {"mount": (96, 64)}),
                    "east": (EQ_SHIELD_EAST, {"mount": (76, 64)}),
                },
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
                "id": "jugg_body",
                "type": "body",
                "name": "Molok Chassis",
                "tags": ["heavy"],
                "dirs": {
                    "south": (JUGG_BODY_SOUTH, {
                        "mount": (64, 64),
                        "head": (64, 44),
                        "feet": (64, 91),
                        "equip_left": (36, 62),
                        "equip_right": (92, 62),
                        "equip_shoulder": (64, 28),
                        "core": (64, 72),
                    }),
                    "north": (JUGG_BODY_NORTH, {
                        "mount": (64, 64),
                        "head": (64, 44),
                        "feet": (64, 91),
                        "equip_left": (36, 62),
                        "equip_right": (92, 62),
                        "equip_shoulder": (64, 28),
                        "core": (64, 74),
                    }),
                    "east": (JUGG_BODY_EAST, {
                        "mount": (64, 64),
                        "head": (64, 44),
                        "feet": (64, 91),
                        "equip_left": (54, 62),
                        "equip_right": (76, 62),
                        "equip_shoulder": (62, 28),
                        "core": (72, 72),
                    }),
                },
                "slot_z": {
                    "south": {"equip_left": 30, "equip_right": 30, "equip_shoulder": 18},
                    "north": {"equip_left": 14, "equip_right": 14, "equip_shoulder": 44},
                    "east": {"equip_left": 14, "equip_right": 32, "equip_shoulder": 18},
                    "west": {"equip_left": 32, "equip_right": 14, "equip_shoulder": 18},
                },
            },
            {
                "id": "jugg_head",
                "type": "head",
                "name": "Molok Bunkerkopf",
                "tags": ["heavy", "armored"],
                "dirs": {
                    "south": (JUGG_HEAD_SOUTH, {"mount": (64, 44)}),
                    "north": (JUGG_HEAD_NORTH, {"mount": (64, 44)}),
                    "east": (JUGG_HEAD_EAST, {"mount": (64, 44)}),
                },
            },
            {
                "id": "jugg_feet",
                "type": "feet",
                "name": "Molok Standbeine",
                "tags": ["heavy", "slow"],
                "dirs": {
                    "south": (JUGG_FEET_SOUTH, {"mount": (64, 91), "ground": (64, 121)}),
                    "north": (JUGG_FEET_NORTH, {"mount": (64, 91), "ground": (64, 121)}),
                    "east": (JUGG_FEET_EAST, {"mount": (64, 91), "ground": (66, 121)}),
                },
            },
            {
                "id": "jugg_core",
                "type": "core",
                "name": "Molok Fusionskern",
                "tags": ["core", "fusion"],
                "dirs": {
                    "south": (JUGG_CORE_SOUTH, {"mount": (64, 72)}),
                    "north": (JUGG_CORE_NORTH, {"mount": (64, 74)}),
                    "east": (JUGG_CORE_EAST, {"mount": (72, 72)}),
                },
            },
            {
                "id": "eq_siege_cannon",
                "type": "equipment",
                "name": "Belagerungskanone",
                "tags": ["weapon", "heavy"],
                "slots": ["equip_left", "equip_right"],
                "dirs": {
                    "south": (EQ_CANNON_SOUTH, {"mount": (26, 64)}),
                    "north": (EQ_CANNON_NORTH, {"mount": (26, 64)}),
                    "east": (EQ_CANNON_EAST, {"mount": (82, 64)}),
                },
            },
            {
                "id": "eq_drone_pod",
                "type": "equipment",
                "name": "Drohnen-Pod",
                "tags": ["support", "shoulder"],
                "slots": ["equip_shoulder"],
                "dirs": {
                    "south": (EQ_DRONEPOD_SOUTH, {"mount": (64, 28)}),
                    "north": (EQ_DRONEPOD_NORTH, {"mount": (64, 28)}),
                    "east": (EQ_DRONEPOD_EAST, {"mount": (63, 28)}),
                },
            },
        ],
    },
]


SVG_TEMPLATE = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128"
     data-part-id="{pid}" data-type="{ptype}" data-direction="{direction}">
  <title>{name} ({direction})</title>
  <!--
    Gemeinsames Koordinatensystem 128x128, Bodenlinie y=120, Mittelachse x=64.
    Farben ausschliesslich ueber CSS Custom Properties (siehe parts/README.md).
    Anker liegen in der zugehoerigen .json und werden hier NICHT gezeichnet.
  -->
{body}
</svg>
"""


def write_part(set_dir: pathlib.Path, set_id: str, part: dict, direction: str,
               inner: str, anchors: dict, palette: dict) -> None:
    pid = part["id"]
    stem = f"{pid}_{direction}"

    svg = SVG_TEMPLATE.format(
        pid=pid, ptype=part["type"], direction=direction,
        name=part.get("name", pid), body=inner,
    )
    (set_dir / f"{stem}.svg").write_text(svg, encoding="utf-8")

    meta = {
        "id": pid,
        "set": set_id,
        "type": part["type"],
        "name": part.get("name", pid),
        "direction": direction,
        "svg": f"{stem}.svg",
        "view_box": [0, 0, 128, 128],
        "z_index": part.get("z_index", DEFAULT_Z.get(part["type"], 20)),
        "anchors": [
            {"name": name, "x": x, "y": y} for name, (x, y) in anchors.items()
        ],
        "color_scheme": dict(palette),
        "tags": part.get("tags", []),
    }
    if part["type"] == "body":
        slot_z = part.get("slot_z", {}).get(direction)
        if slot_z:
            meta["slot_z"] = slot_z
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
            json.dumps(
                {
                    "id": spec["id"],
                    "name": spec["name"],
                    "description": spec["description"],
                    "palette": spec["palette"],
                },
                indent=2, ensure_ascii=False,
            ) + "\n",
            encoding="utf-8",
        )

        for part in spec["parts"]:
            dirs = dict(part["dirs"])
            if "west" not in dirs and "east" in dirs:
                east_inner, east_anchors = dirs["east"]
                dirs["west"] = (mirror_svg(east_inner), mirrored_anchors(east_anchors))
            for direction in DIRECTIONS:
                if direction not in dirs:
                    continue
                inner, anchors = dirs[direction]
                write_part(set_dir, spec["id"], part, direction, inner, anchors,
                           spec["palette"])

        print(f"[ok] {spec['dir']}: {len(list(set_dir.glob('*.svg')))} SVGs geschrieben")


if __name__ == "__main__":
    main()
