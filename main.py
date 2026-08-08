#!/usr/bin/env python3
"""
CyberDrome SVG-Werkstatt -- lokaler Entwicklungsserver
======================================================

Startet einen kleinen HTTP-Server auf http://127.0.0.1:8000, der

  * das Frontend (index.html) ausliefert,
  * die Teile-Bibliothek aus PARTS_DIR einliest und als JSON bereitstellt
    (inklusive Pruefung auf doppelt vergebene Teile-Codes),
  * Aenderungen an Teil-Metadaten (Anker, Farben) zurueckschreibt,
  * fertig zusammengesetzte Bots als SVG + JSON nach BUILDS_DIR exportiert.

Bewusst OHNE externe Abhaengigkeiten (nur Python-Standardbibliothek), damit
das Tool ohne venv/pip auf jedem Rechner sofort laeuft:

    python3 main.py

Optionen
--------
    python3 main.py --port 8080 --parts ./parts --builds ./builds
    python3 main.py --no-browser        # Browser nicht automatisch oeffnen

Sicherheitshinweis
------------------
Der Server bindet standardmaessig NUR an 127.0.0.1 und ist ein reines
Entwickler-Werkzeug -- er hat keine Authentifizierung und gehoert nicht ins
offene Netz. Schreibende Endpunkte validieren alle Pfadsegmente gegen
SAFE_NAME und pruefen zusaetzlich, dass der aufgeloeste Pfad innerhalb des
erlaubten Verzeichnisses liegt (Schutz gegen Path Traversal).

REST-API
--------
    GET    /api/library                  -> komplette Bibliothek (Sets, Teile, SVG-Inline)
    GET    /api/library?refresh=1        -> Cache verwerfen und neu einlesen
    PUT    /api/part/<set>/<stem>        -> Teil-Metadaten (JSON) ueberschreiben
    POST   /api/part                     -> neues Teil anlegen (SVG + Metadaten)
    DELETE /api/part/<set>/<stem>        -> Teil (SVG + JSON) loeschen
    GET    /api/builds                   -> Liste gespeicherter Bots
    GET    /api/builds/<name>            -> gespeicherten Bot laden
    POST   /api/build                    -> Bot speichern {name, svg, loadout}
    GET    /api/palettes                 -> Farbpaletten + Kategorien je Bauteiltyp
    PUT    /api/palettes                 -> Farbpaletten ueberschreiben (anlegen,
                                            umbenennen und loeschen laufen
                                            ebenfalls hierueber)

    GET    /parts/...                    -> statische Teil-Dateien
    GET    /builds/...                   -> statische Build-Dateien
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import shutil
import sys
import threading
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from xml.etree import ElementTree
from urllib.parse import unquote, urlparse, parse_qs

ROOT = pathlib.Path(__file__).resolve().parent

# Werden in main() aus den CLI-Argumenten gesetzt.
PARTS_DIR = ROOT / "parts"
BUILDS_DIR = ROOT / "builds"
PALETTE_FILE = ROOT / "palettes.json"

SAFE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$")
# Game-Design-Code eines Teils: COR/HED/CHS/LEG/EQP + laufende Nummer.
CODE_RE = re.compile(r"^[A-Z]{3}-[0-9]{3,4}$")
DIRECTIONS = ("north", "west", "east", "south")
PART_TYPES = ("core", "head", "body", "feet",
              "equipment", "equipment_left", "equipment_right")

# Montageklasse und Bauart -- die Regel hinter den Ausruestungsslots.
# Ein Anker sagt nur, WO etwas sitzt; erst diese beiden Felder sagen, WAS dort
# sitzen darf. Details in parts/README.md, Abschnitt 2a.
MOUNT_CLASSES = ("light", "medium", "heavy")
EQUIP_CATEGORIES = ("weapon", "shield", "support")
DEFAULT_MOUNT_CLASS = "light"     # importierte Teile passen ueberallhin ...
DEFAULT_CATEGORY = "weapon"       # ... ausser auf ausdruecklich engere Slots

MAX_BODY_BYTES = 8 * 1024 * 1024  # 8 MB -- reicht fuer sehr grosse SVGs

# ---------------------------------------------------------------------------
# Farbpaletten: vier Kategorien je Bauteiltyp
#
# Eine Palette wird nicht mehr ueber die acht CSS-Rollen bedient, sondern ueber
# genau VIER Kategorien -- und welche vier das sind, haengt am Bauteiltyp. Ein
# Kopf faerbt etwas anderes als ein Kern. Die acht Rollen leiten sich daraus im
# Frontend ab (Kante und Schatten der Panzerung aus der Grundfarbe), damit die
# Iso-Beleuchtung gar nicht erst falsch eingestellt werden kann.
#
# Der Server kennt die Kategorien nur, um Paletten zu pruefen und alte, flache
# Paletten zu uebersetzen -- gerechnet wird im Frontend.
# ---------------------------------------------------------------------------
PALETTE_TYPES = ("body", "head", "feet", "core", "equipment")

PALETTE_CATEGORIES = {
    "body": ("hull", "mech", "neon", "line"),
    "feet": ("hull", "mech", "neon", "line"),
    "equipment": ("hull", "mech", "neon", "line"),
    "head": ("hull", "mech", "visor", "line"),
    "core": ("case", "ember", "rings", "line"),
}

# Welche der alten acht Rollen eine Kategorie ersetzt. Nur fuer die Migration
# von Paletten aus der Zeit vor den Kategorien.
LEGACY_ROLE = {
    "hull": "plate", "case": "plate", "mech": "metal", "neon": "accent",
    "visor": "visor", "ember": "glow", "rings": "accent", "line": "outline",
}

HEX_COLOR = re.compile(r"^#[0-9A-Fa-f]{6}$")


def _palette(hull: str, mech: str, neon: str, visor: str,
             ember: str, rings: str, line: str) -> dict:
    armour = {"hull": hull, "mech": mech, "neon": neon, "line": line}
    return {
        "body": dict(armour), "feet": dict(armour), "equipment": dict(armour),
        "head": {"hull": hull, "mech": mech, "visor": visor, "line": line},
        "core": {"case": hull, "ember": ember, "rings": rings, "line": line},
    }


DEFAULT_PALETTES = {
    "Neon Cyan": _palette("#232a3d", "#5b6785", "#2de2e6", "#7cf9ff",
                          "#ff2d95", "#2de2e6", "#0a0d16"),
    "Ember Rust": _palette("#3a2a33", "#7d6b78", "#ff8a3d", "#ffb057",
                           "#ffd447", "#ff8a3d", "#120b10"),
    "Toxic Lime": _palette("#1e2b22", "#5f7a5c", "#9dff4d", "#c8ff8a",
                           "#d4ff2b", "#9dff4d", "#08120b"),
    "Void Violet": _palette("#2a2140", "#6f5f97", "#a76bff", "#d3b6ff",
                            "#ff5ec7", "#a76bff", "#0d0818"),
    "Ghost Mono": _palette("#2b2f36", "#7b828e", "#dfe6f0", "#c3ccd9",
                           "#ffffff", "#dfe6f0", "#0c0e12"),
}

FALLBACK_PALETTE = DEFAULT_PALETTES["Neon Cyan"]


def normalize_palette(value, fallback: dict = None) -> dict:
    """
    Bringt eine Palette in die Kategorie-Form -- egal, woher sie kommt.

    Akzeptiert sowohl die aktuelle Form ``{typ: {kategorie: farbe}}`` als auch
    eine alte flache Palette ``{rolle: farbe}``; letztere wird ueber
    LEGACY_ROLE uebersetzt. Fehlende oder unsinnige Werte fallen auf
    ``fallback`` zurueck, damit nie eine halbe Palette ins Frontend geraet.
    """
    fallback = fallback or FALLBACK_PALETTE
    if not isinstance(value, dict):
        return {t: dict(colors) for t, colors in fallback.items()}

    flat = {k: v for k, v in value.items()
            if isinstance(v, str) and HEX_COLOR.match(v)}
    per_type = {t: value.get(t) for t in PALETTE_TYPES
                if isinstance(value.get(t), dict)}

    result = {}
    for part_type, keys in PALETTE_CATEGORIES.items():
        source = per_type.get(part_type, {})
        colors = {}
        for key in keys:
            candidate = source.get(key) or flat.get(LEGACY_ROLE[key])
            colors[key] = (candidate if isinstance(candidate, str)
                           and HEX_COLOR.match(candidate)
                           else fallback[part_type][key])
        result[part_type] = colors
    return result


class ApiError(Exception):
    """Fehler mit HTTP-Statuscode, wird sauber als JSON zurueckgegeben."""

    def __init__(self, status: int, message: str):
        super().__init__(message)
        self.status = status
        self.message = message


# ---------------------------------------------------------------------------
# Pfad-Absicherung
# ---------------------------------------------------------------------------
def safe_segment(value: str, label: str) -> str:
    if not isinstance(value, str) or not SAFE_NAME.match(value):
        raise ApiError(400, f"Ungueltiger {label}: {value!r}")
    if value in (".", ".."):
        raise ApiError(400, f"Ungueltiger {label}: {value!r}")
    return value


def resolve_within(base: pathlib.Path, *segments: str) -> pathlib.Path:
    """Baut einen Pfad und stellt sicher, dass er unterhalb von base bleibt."""
    target = base.joinpath(*segments).resolve()
    base_resolved = base.resolve()
    if target != base_resolved and base_resolved not in target.parents:
        raise ApiError(400, "Pfad liegt ausserhalb des erlaubten Verzeichnisses")
    return target


# ---------------------------------------------------------------------------
# Bibliothek einlesen
# ---------------------------------------------------------------------------
_library_cache: dict | None = None
_library_lock = threading.Lock()


COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)
TITLE_RE = re.compile(r"<title>.*?</title>\s*", re.DOTALL | re.IGNORECASE)


def read_svg_inner(path: pathlib.Path) -> str:
    """
    Liefert den Inhalt des <svg>-Wurzelelements ohne den Wrapper selbst.

    Das Frontend setzt die Teile in EIN gemeinsames <svg> ein; verschachtelte
    <svg>-Elemente wuerden eigene Viewports aufmachen und das Anker-Rechnen
    kaputt machen.

    Kommentare und <title> werden entfernt: sie blaehen jeden Export auf und
    das Tool setzt beim Zusammensetzen einen eigenen <title> pro Gruppe.
    """
    raw = path.read_text(encoding="utf-8")
    start = raw.find(">", raw.find("<svg"))
    end = raw.rfind("</svg>")
    if start == -1 or end == -1:
        raise ApiError(500, f"{path.name}: kein gueltiges <svg>-Wurzelelement")
    inner = raw[start + 1:end]
    inner = COMMENT_RE.sub("", inner)
    inner = TITLE_RE.sub("", inner, count=1)
    return inner.strip()


def load_part(json_path: pathlib.Path, set_id: str) -> dict:
    try:
        meta = json.loads(json_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ApiError(500, f"{json_path.name}: kaputtes JSON ({exc})") from exc

    stem = json_path.stem
    svg_name = meta.get("svg") or f"{stem}.svg"
    svg_path = json_path.parent / svg_name
    if not svg_path.is_file():
        raise ApiError(500, f"{json_path.name}: SVG {svg_name} fehlt")

    meta.setdefault("id", stem)
    meta.setdefault("code", "")          # Game-Design-Code, s. parts/README.md
    meta.setdefault("name", meta["id"])
    meta.setdefault("type", "body")
    meta.setdefault("direction", "south")
    meta.setdefault("anchors", [])
    meta.setdefault("view_box", [0, 0, 128, 128])
    # Ausruestung bekommt Montageklasse und Bauart auch dann, wenn die Datei
    # sie nicht nennt -- das Frontend soll die Slotregel nicht mit Sonderfaellen
    # fuer alte Teile auswerten muessen.
    if str(meta["type"]).startswith("equipment"):
        meta.setdefault("mount_class", DEFAULT_MOUNT_CLASS)
        meta.setdefault("category", DEFAULT_CATEGORY)
    meta["set"] = set_id
    meta["stem"] = stem
    meta["svg"] = svg_name
    meta["uid"] = f"{set_id}/{stem}"
    meta["svg_inner"] = read_svg_inner(svg_path)
    return meta


def scan_library() -> dict:
    sets: list[dict] = []
    warnings: list[str] = []

    if not PARTS_DIR.is_dir():
        return {"sets": [], "warnings": [f"Parts-Ordner fehlt: {PARTS_DIR}"],
                "parts_dir": str(PARTS_DIR)}

    for set_dir in sorted(p for p in PARTS_DIR.iterdir() if p.is_dir()):
        if not SAFE_NAME.match(set_dir.name):
            warnings.append(f"Ordner uebersprungen (unsicherer Name): {set_dir.name}")
            continue

        set_meta = {"id": set_dir.name, "name": set_dir.name, "description": "",
                    "palette": None}
        set_json = set_dir / "set.json"
        if set_json.is_file():
            try:
                set_meta.update(json.loads(set_json.read_text(encoding="utf-8")))
                set_meta["id"] = set_dir.name  # Ordnername gewinnt immer
            except json.JSONDecodeError as exc:
                warnings.append(f"{set_dir.name}/set.json ist kaputt: {exc}")

        # Set-Paletten koennen noch die alte flache Form haben -- das Frontend
        # bekommt grundsaetzlich Kategorien.
        if set_meta.get("palette"):
            set_meta["palette"] = normalize_palette(set_meta["palette"])

        parts = []
        for json_path in sorted(set_dir.glob("*.json")):
            if json_path.name == "set.json":
                continue
            try:
                parts.append(load_part(json_path, set_dir.name))
            except ApiError as exc:
                warnings.append(exc.message)

        set_meta["parts"] = parts
        sets.append(set_meta)

    warnings.extend(duplicate_code_warnings(sets))
    warnings.extend(slot_rule_warnings(sets))

    return {"sets": sets, "warnings": warnings, "parts_dir": str(PARTS_DIR),
            "directions": list(DIRECTIONS), "part_types": list(PART_TYPES),
            "mount_classes": list(MOUNT_CLASSES),
            "equip_categories": list(EQUIP_CATEGORIES)}


def duplicate_code_warnings(sets: list[dict]) -> list[str]:
    """
    Teile-Codes (CHS-001, EQP-004, ...) muessen projektweit eindeutig sein --
    sie sind der Schluessel, unter dem das Game Design ein Teil referenziert.
    Ein Duplikat faellt sonst erst in der Balancing-Tabelle auf.

    Die vier Richtungsvarianten eines Teils teilen sich Code und id; erst wenn
    zwei UNTERSCHIEDLICHE Teile denselben Code tragen, ist es ein Fehler.
    """
    owners: dict[str, set[str]] = {}
    for set_meta in sets:
        for part in set_meta["parts"]:
            code = part.get("code")
            if code:
                owners.setdefault(code, set()).add(f"{part['set']}/{part['id']}")

    return [
        f"Teile-Code {code} doppelt vergeben: {', '.join(sorted(ids))}"
        for code, ids in sorted(owners.items()) if len(ids) > 1
    ]


def slot_rule_warnings(sets: list[dict]) -> list[str]:
    """
    Eine Slotregel ohne zugehoerigen Anker ist wirkungslos -- und wirkungslos
    heisst hier: der Slot nimmt wieder alles an. Genau der Fall, in dem der
    Sprinter doch die Belagerungskanone traegt, deshalb wird er gemeldet.
    """
    messages = []
    for set_meta in sets:
        for part in set_meta["parts"]:
            rules = part.get("slot_rules")
            if not isinstance(rules, dict):
                continue
            anchors = {a.get("name") for a in part.get("anchors", [])
                       if isinstance(a, dict)}
            for slot in sorted(set(rules) - anchors):
                messages.append(
                    f"{part['set']}/{part['stem']}: slot_rules nennt {slot}, "
                    f"aber der Anker fehlt -- die Regel greift nicht"
                )
    return messages


def get_library(refresh: bool = False) -> dict:
    global _library_cache
    with _library_lock:
        if refresh or _library_cache is None:
            _library_cache = scan_library()
        return _library_cache


def invalidate_library() -> None:
    global _library_cache
    with _library_lock:
        _library_cache = None


# ---------------------------------------------------------------------------
# Validierung eingehender Metadaten
# ---------------------------------------------------------------------------
def validate_meta(meta: dict) -> dict:
    if not isinstance(meta, dict):
        raise ApiError(400, "Metadaten muessen ein Objekt sein")

    direction = meta.get("direction", "south")
    if direction not in DIRECTIONS:
        raise ApiError(400, f"Unbekannte Richtung: {direction!r}")

    code = meta.get("code", "")
    if code and not CODE_RE.match(str(code)):
        raise ApiError(400, f"Ungueltiger Teile-Code {code!r} "
                            f"(erwartet z. B. CHS-001, EQP-042)")

    anchors = meta.get("anchors", [])
    if not isinstance(anchors, list):
        raise ApiError(400, "'anchors' muss ein Array sein")

    clean_anchors = []
    anchor_names = set()
    for anchor in anchors:
        if not isinstance(anchor, dict) or "name" not in anchor:
            raise ApiError(400, "Jeder Anker braucht mindestens 'name', 'x', 'y'")
        name = str(anchor["name"])
        if name in anchor_names:
            raise ApiError(400, f"Doppelter Ankername: {name!r}")
        anchor_names.add(name)
        try:
            x = round(float(anchor.get("x", 0)), 3)
            y = round(float(anchor.get("y", 0)), 3)
        except (TypeError, ValueError) as exc:
            raise ApiError(400, f"Anker {name!r}: x/y muessen Zahlen sein") from exc
        clean_anchors.append({"name": name, "x": x, "y": y})

    meta["anchors"] = clean_anchors
    validate_slot_fields(meta, anchor_names)
    # Ableitbare/serverseitige Felder nie aus dem Client uebernehmen.
    for key in ("svg_inner", "uid", "stem"):
        meta.pop(key, None)
    return meta


def validate_slot_fields(meta: dict, anchor_names: set) -> None:
    """
    Montageklasse / Bauart auf der Ausruestung, ``slot_rules`` auf dem Koerper.

    Zusammen sind das die Regel, die verhindert, dass ein Sprinter eine
    Belagerungskanone traegt oder ein Schild auf einer Schulterbruecke landet.
    Ein Slot ohne Regel nimmt weiterhin alles an -- wer nichts angibt, bekommt
    das alte Verhalten.
    """
    if str(meta.get("type", "")).startswith("equipment"):
        mount_class = meta.get("mount_class", DEFAULT_MOUNT_CLASS)
        if mount_class not in MOUNT_CLASSES:
            raise ApiError(400, f"Unbekannte Montageklasse {mount_class!r} "
                                f"(erlaubt: {', '.join(MOUNT_CLASSES)})")
        category = meta.get("category", DEFAULT_CATEGORY)
        if category not in EQUIP_CATEGORIES:
            raise ApiError(400, f"Unbekannte Bauart {category!r} "
                                f"(erlaubt: {', '.join(EQUIP_CATEGORIES)})")
        meta["mount_class"] = mount_class
        meta["category"] = category

    rules = meta.get("slot_rules")
    if rules is None:
        return
    if not isinstance(rules, dict):
        raise ApiError(400, "'slot_rules' muss ein Objekt sein")

    clean = {}
    for slot, rule in rules.items():
        slot = str(slot)
        if not slot.startswith("equip_"):
            raise ApiError(400, f"slot_rules: {slot!r} ist kein Ausruestungsslot")
        if anchor_names and slot not in anchor_names:
            raise ApiError(400, f"slot_rules nennt {slot!r}, "
                                f"aber das Teil hat keinen solchen Anker")
        if not isinstance(rule, dict):
            raise ApiError(400, f"slot_rules[{slot!r}] muss ein Objekt sein")

        entry = {}
        if "max_class" in rule:
            if rule["max_class"] not in MOUNT_CLASSES:
                raise ApiError(400, f"slot_rules[{slot!r}]: unbekannte "
                                    f"Montageklasse {rule['max_class']!r}")
            entry["max_class"] = rule["max_class"]
        if "categories" in rule:
            categories = rule["categories"]
            if not isinstance(categories, list) or not categories:
                raise ApiError(400, f"slot_rules[{slot!r}]: 'categories' muss "
                                    f"eine nicht leere Liste sein")
            for category in categories:
                if category not in EQUIP_CATEGORIES:
                    raise ApiError(400, f"slot_rules[{slot!r}]: unbekannte "
                                        f"Bauart {category!r}")
            entry["categories"] = list(categories)
        clean[slot] = entry

    meta["slot_rules"] = clean


def looks_like_svg(text: str) -> bool:
    return "<svg" in text[:2000].lower() and "</svg>" in text.lower()


def check_well_formed(text: str) -> None:
    """
    Ein importiertes SVG muss wohlgeformtes XML sein.

    Browser und Godot sehen ueber vieles hinweg, ein strikter Parser nicht --
    und dann faellt der Fehler irgendwann in einem Werkzeug auf, das mit dem
    Teil nichts zu tun hat. Der haeufigste Stolperstein ist ausgerechnet ein
    Gedankenstrich: "--" ist innerhalb eines XML-Kommentars verboten.

    Die beiden Generatoren pruefen dasselbe, bevor sie schreiben. Der Import
    ist der dritte und letzte Weg, auf dem ein SVG ins Repo kommt.
    """
    try:
        ElementTree.fromstring(text)
    except ElementTree.ParseError as error:
        hint = ""
        if "--" in text:
            hint = (" Haeufigste Ursache: ein doppelter Bindestrich in einem "
                    "<!-- Kommentar -->, dort ist er nicht erlaubt.")
        raise ApiError(400, f"'svg' ist kein wohlgeformtes XML: {error}.{hint}")


# ---------------------------------------------------------------------------
# API-Endpunkte
# ---------------------------------------------------------------------------
def api_save_part_meta(set_id: str, stem: str, payload: dict) -> dict:
    set_id = safe_segment(set_id, "Set")
    stem = safe_segment(stem, "Teil")
    json_path = resolve_within(PARTS_DIR, set_id, f"{stem}.json")
    if not json_path.is_file():
        raise ApiError(404, f"Teil nicht gefunden: {set_id}/{stem}")

    meta = validate_meta(payload)
    meta["set"] = set_id
    meta.setdefault("svg", f"{stem}.svg")

    write_json(json_path, meta)
    invalidate_library()
    return {"ok": True, "saved": f"{set_id}/{stem}.json"}


def api_create_part(payload: dict) -> dict:
    set_id = safe_segment(str(payload.get("set", "")), "Set")
    stem = safe_segment(str(payload.get("stem", "")), "Dateiname")
    svg_text = payload.get("svg", "")

    if not isinstance(svg_text, str) or not looks_like_svg(svg_text):
        raise ApiError(400, "'svg' enthaelt kein gueltiges <svg>-Dokument")
    check_well_formed(svg_text)

    set_dir = resolve_within(PARTS_DIR, set_id)
    set_dir.mkdir(parents=True, exist_ok=True)

    svg_path = resolve_within(PARTS_DIR, set_id, f"{stem}.svg")
    json_path = resolve_within(PARTS_DIR, set_id, f"{stem}.json")
    if (svg_path.exists() or json_path.exists()) and not payload.get("overwrite"):
        raise ApiError(409, f"{set_id}/{stem} existiert bereits "
                            f"(overwrite=true zum Ueberschreiben)")

    meta = validate_meta(payload.get("meta", {}))
    meta.update({"set": set_id, "svg": f"{stem}.svg"})
    meta.setdefault("id", stem)
    meta.setdefault("name", stem)

    svg_path.write_text(svg_text, encoding="utf-8")
    write_json(json_path, meta)
    invalidate_library()
    return {"ok": True, "created": f"{set_id}/{stem}"}


def api_delete_part(set_id: str, stem: str) -> dict:
    set_id = safe_segment(set_id, "Set")
    stem = safe_segment(stem, "Teil")
    removed = []
    for suffix in (".json", ".svg"):
        path = resolve_within(PARTS_DIR, set_id, f"{stem}{suffix}")
        if path.is_file():
            path.unlink()
            removed.append(path.name)
    if not removed:
        raise ApiError(404, f"Teil nicht gefunden: {set_id}/{stem}")
    invalidate_library()
    return {"ok": True, "removed": removed}


def api_save_build(payload: dict) -> dict:
    name = safe_segment(str(payload.get("name", "")), "Build-Name")
    svg_text = payload.get("svg", "")
    loadout = payload.get("loadout")

    if not isinstance(svg_text, str) or not looks_like_svg(svg_text):
        raise ApiError(400, "'svg' enthaelt kein gueltiges <svg>-Dokument")
    check_well_formed(svg_text)
    if not isinstance(loadout, dict):
        raise ApiError(400, "'loadout' muss ein Objekt sein")

    BUILDS_DIR.mkdir(parents=True, exist_ok=True)
    svg_path = resolve_within(BUILDS_DIR, f"{name}.svg")
    json_path = resolve_within(BUILDS_DIR, f"{name}.json")

    svg_path.write_text(svg_text, encoding="utf-8")
    write_json(json_path, loadout)
    return {"ok": True, "svg": f"builds/{name}.svg", "json": f"builds/{name}.json"}


def api_save_squad(payload: dict) -> dict:
    """
    Schreibt den Squad, mit dem die Kampfszene startet.

    Bewusst EINE Datei statt mehrerer Builds: der Kampf braucht die Gruppe,
    nicht die einzelnen Bots, und ein Squad aus Dateien zusammenzusuchen waere
    eine zweite Stelle, an der die Reihenfolge stehen muesste.

    Der Inhalt ist dasselbe Loadout-Format wie in builds/<name>.json -- nur als
    Liste. Es stehen ausschliesslich Teile-IDs darin, keine Werte: die Engine
    rechnet die Stats beim Laden aus den Bauteilen neu aus. Ein Squad kann
    deshalb nicht veralten, wenn sich das Balancing aendert.
    """
    members = payload.get("squad")
    if not isinstance(members, list) or not members:
        raise ApiError(400, "'squad' muss eine nicht-leere Liste sein")
    if len(members) > 4:
        raise ApiError(400, "Ein Squad hat hoechstens 4 DROMEs")

    for index, member in enumerate(members):
        if not isinstance(member, dict):
            raise ApiError(400, f"Squad-Eintrag {index} ist kein Objekt")
        if not isinstance(member.get("slots"), dict) or not member["slots"]:
            raise ApiError(400, f"Squad-Eintrag {index} hat keine Slots")

    size = payload.get("squad_size", len(members))
    if not isinstance(size, int) or not 1 <= size <= 4:
        raise ApiError(400, "'squad_size' muss zwischen 1 und 4 liegen")

    BUILDS_DIR.mkdir(parents=True, exist_ok=True)
    target = resolve_within(BUILDS_DIR, "squad.json")
    write_json(target, {"squad_size": size, "squad": members})
    return {"ok": True, "path": "builds/squad.json", "count": len(members)}


def api_list_builds() -> dict:
    if not BUILDS_DIR.is_dir():
        return {"builds": []}
    builds = []
    for json_path in sorted(BUILDS_DIR.glob("*.json")):
        stat = json_path.stat()
        builds.append({
            "name": json_path.stem,
            "modified": int(stat.st_mtime),
            "has_svg": (json_path.with_suffix(".svg")).is_file(),
        })
    return {"builds": builds}


def api_get_build(name: str) -> dict:
    name = safe_segment(name, "Build-Name")
    json_path = resolve_within(BUILDS_DIR, f"{name}.json")
    if not json_path.is_file():
        raise ApiError(404, f"Build nicht gefunden: {name}")
    return {"name": name, "loadout": json.loads(json_path.read_text(encoding="utf-8"))}


def api_get_palettes() -> dict:
    stored = None
    if PALETTE_FILE.is_file():
        try:
            stored = json.loads(PALETTE_FILE.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            stored = None
    if not isinstance(stored, dict) or not stored:
        stored = DEFAULT_PALETTES

    # Alte, flache Paletten werden beim Lesen uebersetzt statt beim Schreiben:
    # eine palettes.json aus einer frueheren Version bleibt so brauchbar, ohne
    # dass jemand eine Migration anstossen muss.
    return {
        "palettes": {name: normalize_palette(value)
                     for name, value in stored.items()},
        "categories": {t: list(keys) for t, keys in PALETTE_CATEGORIES.items()},
    }


def api_put_palettes(payload: dict) -> dict:
    palettes = payload.get("palettes")
    if not isinstance(palettes, dict) or not palettes:
        raise ApiError(400, "'palettes' muss ein nicht-leeres Objekt sein")
    for pname, colors in palettes.items():
        if not isinstance(colors, dict):
            raise ApiError(400, f"Palette {pname!r}: Farbwerte muessen ein Objekt sein")
        if not str(pname).strip():
            raise ApiError(400, "Paletten brauchen einen Namen")
    clean = {name: normalize_palette(colors) for name, colors in palettes.items()}
    write_json(PALETTE_FILE, clean)
    return {"ok": True, "count": len(clean)}


def write_json(path: pathlib.Path, data) -> None:
    """Atomarer Schreibvorgang -- ein Absturz laesst keine halbe Datei zurueck."""
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n",
                   encoding="utf-8")
    os.replace(tmp, path)


# ---------------------------------------------------------------------------
# HTTP-Handler
# ---------------------------------------------------------------------------
STATIC_TYPES = {
    ".html": "text/html; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".svg": "image/svg+xml; charset=utf-8",
    ".json": "application/json; charset=utf-8",
    ".png": "image/png",
    ".md": "text/markdown; charset=utf-8",
}


class WorkshopHandler(BaseHTTPRequestHandler):
    server_version = "CyberDromeWorkshop/1.0"
    protocol_version = "HTTP/1.1"

    # -- Antwort-Helfer ----------------------------------------------------
    def send_json(self, data, status: int = 200) -> None:
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def send_bytes(self, body: bytes, content_type: str, status: int = 200) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def read_json_body(self) -> dict:
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError as exc:
            raise ApiError(400, "Ungueltiger Content-Length-Header") from exc
        if length <= 0:
            raise ApiError(400, "Leerer Request-Body")
        if length > MAX_BODY_BYTES:
            raise ApiError(413, "Request-Body zu gross")
        raw = self.rfile.read(length)
        try:
            return json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise ApiError(400, f"Body ist kein gueltiges JSON: {exc}") from exc

    # -- Statische Dateien -------------------------------------------------
    def serve_static(self, rel_path: str) -> bool:
        rel = rel_path.lstrip("/") or "index.html"
        try:
            target = (ROOT / rel).resolve()
        except OSError:
            return False
        if ROOT not in target.parents and target != ROOT:
            return False
        if not target.is_file():
            return False
        ctype = STATIC_TYPES.get(target.suffix.lower(), "application/octet-stream")
        self.send_bytes(target.read_bytes(), ctype)
        return True

    # -- Routing -----------------------------------------------------------
    def route(self, method: str, path: str, query: dict):
        segments = [unquote(s) for s in path.strip("/").split("/") if s]

        if not segments or segments[0] != "api":
            return None  # kein API-Aufruf

        rest = segments[1:]

        if method == "GET" and rest == ["library"]:
            return get_library(refresh=query.get("refresh", ["0"])[0] not in ("0", ""))

        if method == "GET" and rest == ["builds"]:
            return api_list_builds()

        if method == "GET" and len(rest) == 2 and rest[0] == "builds":
            return api_get_build(rest[1])

        if method == "POST" and rest == ["build"]:
            return api_save_build(self.read_json_body())

        if method == "POST" and rest == ["squad"]:
            return api_save_squad(self.read_json_body())

        if method == "POST" and rest == ["part"]:
            return api_create_part(self.read_json_body())

        if method == "PUT" and len(rest) == 3 and rest[0] == "part":
            return api_save_part_meta(rest[1], rest[2], self.read_json_body())

        if method == "DELETE" and len(rest) == 3 and rest[0] == "part":
            return api_delete_part(rest[1], rest[2])

        if method == "GET" and rest == ["palettes"]:
            return api_get_palettes()

        if method == "PUT" and rest == ["palettes"]:
            return api_put_palettes(self.read_json_body())

        raise ApiError(404, f"Unbekannter Endpunkt: {method} {path}")

    def handle_request(self, method: str) -> None:
        parsed = urlparse(self.path)
        query = parse_qs(parsed.query)
        try:
            result = self.route(method, parsed.path, query)
            if result is not None:
                self.send_json(result)
                return
            if method == "GET" and self.serve_static(parsed.path):
                return
            self.send_json({"error": "Nicht gefunden", "path": parsed.path}, 404)
        except ApiError as exc:
            self.send_json({"error": exc.message}, exc.status)
        except BrokenPipeError:
            pass
        except Exception as exc:  # noqa: BLE001 -- lokales Tool: Fehler sichtbar machen
            import traceback
            traceback.print_exc()
            self.send_json({"error": f"{type(exc).__name__}: {exc}"}, 500)

    def do_GET(self):  # noqa: N802
        self.handle_request("GET")

    def do_POST(self):  # noqa: N802
        self.handle_request("POST")

    def do_PUT(self):  # noqa: N802
        self.handle_request("PUT")

    def do_DELETE(self):  # noqa: N802
        self.handle_request("DELETE")

    def log_message(self, fmt, *args):
        sys.stderr.write(f"  {self.address_string()} -- {fmt % args}\n")


# ---------------------------------------------------------------------------
# Einstiegspunkt
# ---------------------------------------------------------------------------
def main() -> int:
    global PARTS_DIR, BUILDS_DIR, PALETTE_FILE

    parser = argparse.ArgumentParser(description="CyberDrome SVG-Werkstatt")
    parser.add_argument("--host", default="127.0.0.1",
                        help="Bind-Adresse (Default: 127.0.0.1 -- nur lokal)")
    parser.add_argument("--port", type=int, default=8000, help="Port (Default: 8000)")
    parser.add_argument("--parts", default=str(ROOT / "parts"),
                        help="Ordner mit den Teile-Sets")
    parser.add_argument("--builds", default=str(ROOT / "builds"),
                        help="Zielordner fuer exportierte Bots")
    parser.add_argument("--no-browser", action="store_true",
                        help="Browser nicht automatisch oeffnen")
    args = parser.parse_args()

    PARTS_DIR = pathlib.Path(args.parts).resolve()
    BUILDS_DIR = pathlib.Path(args.builds).resolve()
    PALETTE_FILE = ROOT / "palettes.json"
    BUILDS_DIR.mkdir(parents=True, exist_ok=True)

    library = get_library(refresh=True)
    part_count = sum(len(s["parts"]) for s in library["sets"])

    term_width = shutil.get_terminal_size((72, 24)).columns
    line = "=" * min(72, term_width)
    url = f"http://{args.host}:{args.port}/"

    print(line)
    print("  CyberDrome // SVG-Werkstatt")
    print(line)
    print(f"  Parts   : {PARTS_DIR}")
    print(f"  Builds  : {BUILDS_DIR}")
    coded = sum(1 for s in library["sets"] for p in s["parts"] if p.get("code"))
    print(f"  Sets    : {len(library['sets'])}  |  Teile: {part_count}"
          f"  |  mit Code: {coded}")
    for warning in library["warnings"]:
        print(f"  ! {warning}")
    print(f"\n  -> {url}\n")
    print("  Beenden mit Strg+C")
    print(line)

    if args.host not in ("127.0.0.1", "localhost", "::1"):
        print("\n  ACHTUNG: Der Server ist im Netzwerk erreichbar und hat keinerlei\n"
              "  Zugriffsschutz. Nur in vertrauenswuerdigen Netzen verwenden.\n")

    httpd = ThreadingHTTPServer((args.host, args.port), WorkshopHandler)
    httpd.daemon_threads = True

    if not args.no_browser:
        threading.Timer(0.6, lambda: webbrowser.open(url)).start()

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n  Server beendet.")
    finally:
        httpd.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
