#!/usr/bin/env python3
"""Baut die SPOT-Tabelle docs/spot/CyberDrome_SPOT.xlsx.

SPOT = Single Point of Truth fuer alle inhaltlichen Daten des Spiels in einer
fuer Menschen lesbaren Excel-Datei. Gelesen wird ausschliesslich, was das Spiel
selbst liest -- so kann die Tabelle nie vom Spiel abweichen:

  parts/*/*_south.json   DROMEs (Chassis, Kopf, Kern, Antrieb) und Waffen
  data/config.json       Regeln, Lauf, Level, Passiven-Zahlen
  data/modules.json      Grundmodule, Rezepte, BIOS, Laden
  data/regions.json      Stages / Gebiete und Fraktionsprofile
  data/encounters.json   Gegnertypen, Gegnerteams, Einheiten
  docs/spot/inhalte.json Texte, die nicht in den Spieldaten stehen
                         (Eckpunkte, Identitaeten, Story, Bosse, offene Punkte,
                         Entwurf: Einsatz, Lootcaches, Sentinels, Formationen)

Aufruf:
  python3 tools/build_spot.py           # Tabelle neu schreiben
  python3 tools/build_spot.py --check   # nur pruefen, ob sie aktuell ist (CI)

Nach JEDER Aenderung an den Dateien oben neu bauen und mit einchecken.
"""

import glob
import json
import os
import sys

from openpyxl import Workbook, load_workbook
from openpyxl.comments import Comment
from openpyxl.formatting.rule import CellIsRule
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation
from openpyxl.worksheet.table import Table, TableStyleInfo

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "spot", "CyberDrome_SPOT.xlsx")


def load(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return json.load(f)


CONFIG = load("data/config.json")
MODULES = load("data/modules.json")
REGIONS = load("data/regions.json")
ENCOUNTERS = load("data/encounters.json")
TEXTE = load("docs/spot/inhalte.json")

# ---------------------------------------------------------------------------
# Teile einlesen (Suedansicht genuegt, die Werte sind je Richtung gleich)
# ---------------------------------------------------------------------------

PARTS = {}
SETS = {}
for path in sorted(glob.glob(os.path.join(ROOT, "parts", "*", "*.json"))):
    name = os.path.basename(path)
    folder = os.path.basename(os.path.dirname(path))
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if name == "set.json":
        SETS[folder] = data
        continue
    pid = data["id"]
    if pid not in PARTS or data.get("direction") == "south":
        PARTS[pid] = data

BODIES = sorted([p for p in PARTS.values() if p["type"] == "body"], key=lambda p: p["code"])
WEAPONS = sorted([p for p in PARTS.values() if p["type"] == "equipment"], key=lambda p: p["code"])


def drome_name(body_id):
    return PARTS[body_id]["name"].replace(" Chassis", "") if body_id in PARTS else body_id


def set_drome(set_id):
    for b in BODIES:
        if b["set"] == set_id:
            return drome_name(b["id"])
    return set_id


def part_name(pid):
    return PARTS[pid]["name"] if pid in PARTS else pid


ALL_MODULES = {}
ALL_MODULES.update(MODULES["modules"])
ALL_MODULES.update(MODULES["recipes"])
ALL_MODULES.update(MODULES["bios_recipes"])


def module_name(mid):
    return ALL_MODULES[mid]["name"] if mid in ALL_MODULES else mid


# ---------------------------------------------------------------------------
# Lesbare Texte aus den Daten
# ---------------------------------------------------------------------------

STAT_NAMES = {
    "hp": "Integritaet", "spd": "Speed", "def": "Ruestung", "shield": "Schild",
    "shield_pulse": "Schildpuls", "power": "Power", "module_slots": "Modulplaetze",
}
CLASS_NAMES = {"light": "leicht", "medium": "mittel", "heavy": "schwer"}
CATEGORY_NAMES = {"weapon": "Waffe", "shield": "Schild", "support": "Support"}
TIER_NAMES = {"easy": "Leicht", "normal": "Normal", "elite": "Elite"}
MOD_CLASS = {"attack": "Angriff", "defense": "Verteidigung", "tactic": "Taktik"}
CONDITION = {"": "jede Waffe", "ranged": "nur Fernkampf (Rw ab 2)", "melee": "nur Nahkampf (Rw 1)"}
ROLE_NAMES = {r["id"]: r["name"] for r in TEXTE["rollen"]}
ROLE_RULE = {r["id"]: r["zielregel"] for r in TEXTE["rollen"]}
TYPES = ENCOUNTERS["types"]
RULES = MODULES["rules"]
PASSIVES = CONFIG["passives"]


def pct(x):
    return f"{round(x * 100)} %"


def num(x):
    if isinstance(x, float) and x.is_integer():
        x = int(x)
    return str(x).replace(".", ",")


PASSIVE_INFO = {
    "hit_rush": ("Sprint", lambda p: f"Jeder Treffer gibt {num(p['seconds'])} s lang +{pct(p['move_mult'] - 1)} Lauftempo."),
    "presence": ("Praesenz", lambda p: f"Gegner im Umkreis {p['lure_radius']} greifen ihn an statt ihres Ziels (Locken). "
                 f"{pct(p['guard_share'])} des Schadens an Verbuendeten im Umkreis {p['guard_radius']} gehen auf ihn."),
    "echo": ("Echo", lambda p: f"Jede Faehigkeit wirkt doppelt, dafuer ist ihr Takt {num(p['slower'])}-mal so lang."),
    "steady": ("Anlegen", lambda p: f"Nach {num(p['seconds'])} s ohne Feldwechsel +{pct(p['damage_mult'] - 1)} Schaden "
               f"und +{pct(p['range_mult'] - 1)} Reichweite (mind. +1 Feld)."),
}


def passive_name(pid):
    return PASSIVE_INFO[pid][0] if pid in PASSIVE_INFO else (pid or "--")


def passive_text(pid):
    if pid in PASSIVE_INFO:
        return PASSIVE_INFO[pid][1](PASSIVES[pid])
    return "--" if not pid else f"(ohne Beschreibung: {pid})"


def effect_text(key, val):
    r = RULES
    texts = {
        "attack_speed": lambda v: f"+{pct(v)} Angriffstempo",
        "attack_power": lambda v: f"+{pct(v)} Schaden der Angriffe",
        "ricochet_chance": lambda v: f"{pct(v)} Chance auf Zusatztreffer",
        "ricochet_share": lambda v: f"Zusatztreffer mit {pct(v)} Schaden",
        "def": lambda v: f"+{num(v)} Ruestung",
        "shield": lambda v: f"+{num(v)} Schild",
        "thorns": lambda v: f"Stacheln: {num(v)} Schaden an jedem Angreifer",
        "thorns_melee": lambda v: f"+{num(v)} Stacheln gegen Nahkampf",
        "ability_power": lambda v: f"Faehigkeit +{pct(v)} Wirkung",
        "status_time": lambda v: f"Statuseffekte {pct(v)} laenger",
        "taunt": lambda v: f"Faehigkeit lockt ihr Ziel {num(1 + v)} s auf den Traeger",
        "mark": lambda v: f"Faehigkeit markiert ihr Ziel {num(v)} s (+{pct(r['mark_damage_taken'])} Schaden von allen)",
        "field_shot_every": lambda v: f"jeder {v}. Angriff trifft dazu den schwaechsten anderen Gegner",
        "kinetic_to_energy": lambda v: f"solange der Schild steht: {pct(v)} des kinetischen Schadens wird Energie",
        "takt_count": lambda v: f"jeder Angriff zaehlt {num(v)} fuer den Takt",
        "bonus_vs_marked": lambda v: f"+{pct(v)} Schaden gegen markierte Ziele",
        "armor_to_damage": lambda v: f"Angriffe +{pct(v)} der eigenen Ruestung als Schaden",
        "retaliation": lambda v: f"Vergeltung: jeder Treffer am Traeger laedt den naechsten Angriff um {pct(v)} auf (max. 3x, Nahkampf doppelt)",
        "post_ability_power": lambda v: f"nach der Faehigkeit: die naechsten {r['overload_attacks']} Angriffe +{pct(v)}",
        "cleave": lambda v: f"jeder Angriff trifft alle anderen Gegner neben dem Traeger mit {pct(v)}",
        "thorns_true": lambda v: "Stacheln gehen am Schild vorbei und koennen Zusatztreffer ausloesen",
        "ability_fork": lambda v: f"Faehigkeit wiederholt sich auf einem zweiten Ziel (Rw {r['fork_range']}) mit {pct(v)}",
        "chain_jumps": lambda v: f"Zusatztreffer springen bis zu {v}x weiter, bevorzugt auf markierte Gegner",
        "shield_delay": lambda v: f"Schild laedt schon nach {num(v)} s Ruhe",
        "ability_armor_aura": lambda v: f"Faehigkeit gibt allen DROMEs in Rw {r['aura_range']} fuer {num(r['aura_seconds'])} s +{num(v)} Ruestung",
        "shackle": lambda v: f"Faehigkeit zieht bis zu {v} Gegner (Rw 3) neben den Traeger und betaeubt sie 1 s",
        "shield_break_burst": lambda v: f"bricht der Schild: {num(v)} Energieschaden an allen Gegnern in Rw {r['burst_range']}, "
                                        f"{num(r['burst_stun'])} s betaeubt (hoechstens alle {num(r['burst_cooldown'])} s)",
        "decoy": lambda v: f"Hologramm-Sprung: wer daneben stand, ist {num(v)} s vom Koeder abgelenkt",
        "mark_on_hit_taken": lambda v: "jeder Gegner, der den Traeger trifft, wird markiert",
        "root": lambda v: f"Ziel der Faehigkeit ist {num(v)} s gewurzelt (greift an, laeuft nicht)",
        "ready_after_ability": lambda v: "nach der Faehigkeit sofort wieder geladen",
        "field_shot_marked": lambda v: "Feldschuss bevorzugt markierte Gegner",
        "range": lambda v: f"+{num(v)} Reichweite",
        "retaliation_max": lambda v: f"Vergeltung bis zu {v} Ladungen",
        "berserk": lambda v: "volle Vergeltung trifft dazu alle Gegner daneben",
        "mark_hunt": lambda v: "stirbt ein markierter Gegner, springt die Markierung weiter",
        "gravity": lambda v: "das Wurzeln trifft dazu den naechsten Gegner am Ziel (Rw 2)",
        "knockback_every": lambda v: f"jeder {v}. Angriff stoesst das Ziel 1 Feld zurueck",
        "bonus_vs_unshielded": lambda v: f"+{pct(v)} Schaden gegen Gegner ohne Schild",
    }
    if key in texts:
        return texts[key](val)
    return f"{key}: {val}"


def effects_text(effects):
    return "; ".join(effect_text(k, v) for k, v in effects.items()) if effects else "--"


def recipe_total(rid):
    """Summe der Wirkungen der Zutaten (Zahlen addieren sich)."""
    total = {}
    for base in MODULES["recipes"][rid]["from"]:
        for k, v in MODULES["modules"][base]["effects"].items():
            total[k] = total.get(k, 0) + v
    return total


def attack_of(weapon):
    acts = weapon["stats"]["actions"]
    return next((a for a in acts if a["category"] == "attack"), None)


def ability_of(weapon):
    acts = weapon["stats"]["actions"]
    return next((a for a in acts if a["category"] == "ability"), None)


def trigger_text(a):
    t = a.get("trigger") or {}
    if t.get("kind") == "attacks":
        return f"jeder {t['every']}. Angriff"
    if t.get("kind") == "adjacent":
        return "wenn ein Gegner daneben steht"
    return "--"


def status_text(s):
    if not s:
        return ""
    if s["id"] == "vulnerable":
        return f"verwundbar {num(s['seconds'])} s (+{pct(s['damage_taken_mult'] - 1)} Schaden)"
    if s["id"] == "stun":
        return f"betaeubt {num(s['seconds'])} s"
    if s["id"] == "slow":
        return f"verlangsamt {num(s['seconds'])} s (-{pct(1 - s['move_mult'])} Tempo)"
    return f"{s['id']} {num(s.get('seconds', 0))} s"


def ability_effect(a, attack):
    parts = []
    if a.get("damage_pct") and a.get("power"):
        parts.append(f"{pct(a['damage_pct'])} des Waffenschadens ({a['power']})")
    elif a.get("power"):
        parts.append(f"Schaden {a['power']}")
    if a.get("shots", 1) > 1:
        parts.append(f"{a['shots']} Schuesse")
    if a.get("targeting") == "aoe_around_target":
        parts.append(f"Flaeche Radius {a.get('aoe_radius', 0)}")
    if a.get("hp_scaling"):
        parts.append(f"+{pct(a['hp_scaling'])} der eigenen max. Integritaet (ohne Power)")
    if a.get("shield_mult", 1.0) != 1.0:
        parts.append(f"x{num(a['shield_mult'])} gegen Schild")
    if a.get("push_tiles", 0) > 0:
        parts.append(f"stoesst {a['push_tiles']} Feld zurueck")
    if a.get("push_tiles", 0) < 0:
        parts.append(f"zieht {-a['push_tiles']} Feld heran")
    if a.get("gather"):
        parts.append("zieht zusammen")
    if a.get("delay"):
        parts.append(f"Einschlag nach {num(a['delay'])} s")
    if a.get("shield_gain"):
        who = "sich selbst" if a.get("support") == "self" else "einem Verbuendeten"
        parts.append(f"+{a['shield_gain']} Schild an {who}")
    if a.get("heal"):
        parts.append(f"heilt {a['heal']}")
    st = status_text(a.get("status"))
    if st:
        parts.append(st)
    return ", ".join(parts) if parts else "--"


def attack_extra(a):
    parts = []
    if a.get("heal"):
        parts.append(f"heilt Verbuendete um {a['heal']}")
    if a.get("moving_bonus"):
        parts.append(f"+{pct(a['moving_bonus'])} in Bewegung")
    if a.get("min_range"):
        parts.append(f"Mindestreichweite {a['min_range']}")
    if a.get("delay"):
        parts.append(f"Einschlag nach {num(a['delay'])} s")
    if a.get("targeting") == "aoe_around_target":
        parts.append(f"Flaeche Radius {a.get('aoe_radius', 0)}")
    return ", ".join(parts) if parts else "--"


def weapon_bonus(w):
    s = w["stats"]
    for k in ("hp", "spd", "def", "shield", "shield_pulse", "power"):
        if s.get(k):
            end = CONFIG["levels"]["weapon"]["bonus_at_max"].get(w["id"], {}).get(k, s[k])
            return STAT_NAMES[k], s[k], end
    return "--", None, None


def slots_text(body):
    out = []
    for slot, rule in body.get("slot_rules", {}).items():
        if rule.get("off"):
            continue
        cls = CLASS_NAMES.get(rule.get("max_class", ""), "?")
        out.append(f"bis {cls}")
    return f"{len(out)} ({', '.join(out)})"


# ---------------------------------------------------------------------------
# Optik
# ---------------------------------------------------------------------------

FONT = "Arial"
HEAD_FILL = PatternFill("solid", fgColor="1F2A44")
HEAD_FONT = Font(name=FONT, bold=True, color="FFFFFF", size=10)
BODY_FONT = Font(name=FONT, size=10)
TITLE_FONT = Font(name=FONT, bold=True, size=14, color="1F2A44")
SUB_FONT = Font(name=FONT, bold=True, size=11, color="1F2A44")
THIN = Side(style="thin", color="D0D5DD")
BORDER = Border(left=THIN, right=THIN, top=THIN, bottom=THIN)
WRAP = Alignment(wrap_text=True, vertical="top")
STATUS_FILL = {
    "gebaut": "D9F2E3", "entschieden": "DCE8FA", "Vorschlag": "FFF2CC",
    "offen": "FCE4D6", "geplant": "EDE7F6", "abgelöst": "E7E6E6",
}
INPUT_FILL = PatternFill("solid", fgColor="E3F4F8")  # Eingabefelder fuer den Spieler

TABLES = []


def sheet(wb, title):
    ws = wb.create_sheet(title)
    ws.sheet_view.showGridLines = False
    return ws


def write_table(ws, headers, rows, widths=None, start_row=1, name=None, notes=None, inputs=()):
    """Schreibt eine Tabelle mit Kopfzeile, Filter, Rahmen und Status-Farben.

    inputs: Spaltenkoepfe, die der Spieler in der Excel ausfuellt (hellblau)."""
    input_cols = {headers.index(h) + 1 for h in inputs}
    for c, h in enumerate(headers, 1):
        cell = ws.cell(row=start_row, column=c, value=h)
        cell.font = HEAD_FONT
        cell.fill = HEAD_FILL
        cell.alignment = Alignment(wrap_text=True, vertical="center")
        cell.border = BORDER
        if notes and h in notes:
            cell.comment = Comment(notes[h], "SPOT")
    status_col = headers.index("Status") + 1 if "Status" in headers else None
    for r, row in enumerate(rows, start_row + 1):
        for c, v in enumerate(row, 1):
            cell = ws.cell(row=r, column=c, value=v)
            cell.font = BODY_FONT
            cell.alignment = WRAP
            cell.border = BORDER
            if c in input_cols:
                cell.fill = INPUT_FILL
        if status_col:
            st = str(ws.cell(row=r, column=status_col).value or "")
            key = next((k for k in STATUS_FILL if st.startswith(k)), None)
            if key:
                ws.cell(row=r, column=status_col).fill = PatternFill("solid", fgColor=STATUS_FILL[key])
    if widths:
        for c, w in enumerate(widths, 1):
            ws.column_dimensions[get_column_letter(c)].width = w
    last = start_row + max(len(rows), 1)
    if start_row == 1:
        ws.freeze_panes = ws.cell(row=2, column=2 if len(headers) > 3 else 1)
        ws.auto_filter.ref = f"A1:{get_column_letter(len(headers))}{last}"
    return last


# ---------------------------------------------------------------------------
# Blaetter
# ---------------------------------------------------------------------------

REG = {}  # Pfad in config -> Zelle auf "Regeln" (fuer Formeln)

RULE_LABELS = {
    "realtime.tick": "Sekunden je Simulationsschritt",
    "realtime.move_base": "Lauftempo Grundwert (Felder/s)",
    "realtime.move_per_spd": "Lauftempo je Punkt Speed (Felder/s)",
    "realtime.move_min": "Lauftempo Untergrenze (Felder/s)",
    "realtime.pulse": "Sekunden je Puls",
    "realtime.time_limit": "Zeitlimit eines Kampfes (s)",
    "realtime.kite_distance": "Fernkaempfer weichen aus, wenn ein Gegner so nah ist",
    "combat.physical_vs_shield": "Kinetisch am Schild",
    "combat.energy_vs_shield": "Energie am Schild",
    "combat.armor_ehp_cap": "Ruestung: Obergrenze des Zuwachses an effektiver Integritaet",
    "combat.armor_ehp_k": "Ruestung: wie schnell die Obergrenze erreicht wird",
    "combat.shield_pulse.base_delay": "Schildpuls: Ruhezeit Grundwert (s)",
    "combat.shield_pulse.delay_per_point": "Schildpuls: Ruhezeit weniger je Punkt (s)",
    "combat.shield_pulse.min_delay": "Schildpuls: kleinste Ruhezeit (s)",
    "combat.shield_pulse.gain_per_point": "Schildpuls: Ladung je Punkt und Puls",
    "overtime.start_seconds": "Overtime beginnt nach (s)",
    "overtime.pct_per_cycle": "Overtime: Anteil der max. Integritaet je Puls (wachsend)",
    "run.rounds": "Kaempfe je Lauf",
    "run.lives": "Leben je Lauf",
    "run.training_rounds": "Trainingsrunden am Anfang",
    "run.storage_size": "Plaetze im Lager",
    "run.loss_credits": "Credits bei einer Niederlage",
    "run.region": "Gebiet des Laufs",
    "squad_size": "Startgroesse des Squads im Lauf",
    "squad_size_max": "Hoechstgroesse des Squads",
    "grid_width": "Spielfeld Breite",
    "grid_height": "Spielfeld Hoehe",
    "deployment.rows": "Aufstellung: Reihen",
    "deployment.columns": "Aufstellung: Breite",
    "deployment.inset": "Aufstellung: Abstand zum Rand",
}


def cell_value(v):
    if isinstance(v, bool):
        return "ja" if v else "nein"
    if isinstance(v, list):
        return ", ".join(map(str, v))
    return v


def flatten(prefix, obj, out):
    for k, v in obj.items():
        if k.startswith("_"):
            continue
        path = f"{prefix}.{k}" if prefix else k
        if isinstance(v, dict):
            flatten(path, v, out)
        else:
            out.append((path, v))


def build_regeln(ws):
    rows = []
    flat = []
    flatten("", {k: v for k, v in CONFIG.items() if k not in ("passives", "levels")}, flat)
    for path, v in flat:
        rows.append(("data/config.json", path, cell_value(v),
                     RULE_LABELS.get(path, "")))
    mflat = []
    flatten("", {k: MODULES[k] for k in ("slots", "sell_value", "shop", "rules")}, mflat)
    for path, v in mflat:
        rows.append(("data/modules.json", path, cell_value(v), ""))
    for i, (src, path, v, label) in enumerate(rows, 2):
        if src == "data/config.json":
            REG[path] = f"Regeln!$C${i}"
    write_table(ws, ["Datei", "Schluessel", "Wert", "Bedeutung"], rows, [18, 46, 22, 70])


def build_uebersicht(ws):
    ws["A1"] = "CyberDrome -- SPOT (Single Point of Truth)"
    ws["A1"].font = TITLE_FONT
    lines = [
        "Alle inhaltlich relevanten Daten des Spiels in einer Datei. Diese Tabelle wird NICHT von Hand bearbeitet,",
        "sondern von tools/build_spot.py aus genau den Dateien erzeugt, die das Spiel selbst liest -- so stimmt sie immer.",
        "Aendern: Werte in parts/ (ueber tools/build_sample_parts.py) oder data/*.json, Texte in docs/spot/inhalte.json,",
        "dann: python3 tools/build_spot.py  -- die CI prueft mit --check, dass die Tabelle aktuell ist.",
        "Texte aus den Spieldaten stehen so wie im Spiel (ohne Umlaute, z. B. 'Praesenz').",
        "Hellblaue Felder (Blaetter Einsatz, Lootcaches, Hangar-Shop, Sentinels, Gegner-DROMEs, Formationen): hier "
        "traegst du Werte ein und gibst die Datei zurueck -- sie werden dann nach docs/spot/inhalte.json uebertragen.",
    ]
    for i, t in enumerate(lines, 2):
        ws.cell(row=i, column=1, value=t).font = BODY_FONT
    ws.cell(row=8, column=1, value="Status-Farben").font = SUB_FONT
    r = 9
    c = ws.cell(row=r, column=1, value="Eingabefeld")
    c.fill = INPUT_FILL
    c.font = BODY_FONT
    c.border = BORDER
    r += 1
    for st, col in STATUS_FILL.items():
        c = ws.cell(row=r, column=1, value=st)
        c.fill = PatternFill("solid", fgColor=col)
        c.font = BODY_FONT
        c.border = BORDER
        r += 1
    ws.cell(row=r + 1, column=1, value="Blaetter").font = SUB_FONT
    rows = [(name, text) for name, text in SHEETS_INFO]
    write_table(ws, ["Blatt", "Inhalt"], rows, start_row=r + 2)
    ws.column_dimensions["A"].width = 22
    ws.column_dimensions["B"].width = 110


def build_eckpunkte(ws):
    rows = [(e["bereich"], e["thema"], e["festlegung"], e["seit"], e["status"], e["quelle"]) for e in TEXTE["eckpunkte"]]
    write_table(ws, ["Bereich", "Thema", "Festlegung", "Seit", "Status", "Quelle"], rows, [14, 24, 90, 13, 13, 30])


def build_dromes(ws):
    headers = ["Code", "DROME", "Set-Titel", "Rolle", "Zielregel", "Identitaet", "Beschreibung",
               "Speed", "Lauftempo (Felder/s)", "Integritaet", "Schild", "Integritaet + Schild",
               "Schildpuls", "Ruhezeit bis Schildladung (s)", "Schild je Puls", "Ruestung", "Power",
               "Halter", "Modulplaetze je Halter", "Passive", "Passive: Wirkung", "Standardwaffe",
               "Level: Hauptwerte (+10 % je Level)", "Level mit +1 Modulplatz", "Chassis-BIOS",
               "Kopf", "Kern", "Antrieb", "Status"]
    rows = []
    lv = CONFIG["levels"]["drome"]
    bios = {b["chassis"]: b for b in MODULES["bios"].values() if b["kind"] == "chassis"}
    for i, b in enumerate(BODIES, 2):
        s = b["stats"]
        t = TEXTE["dromes"].get(b["id"], {})
        fam = [p for p in PARTS.values() if p["set"] == b["set"]]
        by_type = {p["type"]: p["name"] for p in fam}
        rows.append([
            b["code"], drome_name(b["id"]), SETS.get(b["set"], {}).get("name", ""),
            ROLE_NAMES.get(s["ai_role"], s["ai_role"]), ROLE_RULE.get(s["ai_role"], ""),
            t.get("identitaet", ""), t.get("beschreibung", ""),
            s["spd"],
            f"=ROUND(MAX({REG['realtime.move_min']},{REG['realtime.move_base']}+H{i}*{REG['realtime.move_per_spd']}),2)",
            s["hp"], s["shield"], f"=J{i}+K{i}", s["shield_pulse"],
            f"=MAX({REG['combat.shield_pulse.min_delay']},{REG['combat.shield_pulse.base_delay']}-M{i}*{REG['combat.shield_pulse.delay_per_point']})",
            f"=M{i}*{REG['combat.shield_pulse.gain_per_point']}",
            s["def"], s["power"], slots_text(b), s["module_slots"],
            passive_name(s["passive"]), passive_text(s["passive"]), t.get("standardwaffe", ""),
            ", ".join(STAT_NAMES[k] for k in lv["main"].get(b["id"], [])),
            ", ".join(map(str, lv["module_slots_at"].get(b["id"], lv["module_slots_at"]["default"]))),
            bios[b["id"]]["text"] if b["id"] in bios else "--",
            by_type.get("head", ""), by_type.get("core", ""), by_type.get("feet", ""), "gebaut",
        ])
    notes = {
        "Lauftempo (Felder/s)": "Formel: max(Untergrenze, Grundwert + Speed x je Punkt) -- Zahlen aus Blatt Regeln (realtime).",
        "Ruhezeit bis Schildladung (s)": "Formel aus Blatt Regeln (combat.shield_pulse).",
        "Power": "Rohschaden = Waffenschaden x Power / 10.",
    }
    write_table(ws, headers, rows, [9, 10, 26, 13, 30, 36, 40, 7, 10, 10, 8, 10, 9, 11, 8, 8, 7, 20, 10,
                                    11, 46, 22, 22, 12, 46, 16, 16, 16, 10], notes=notes)


def build_waffen(ws):
    headers = ["Code", "Waffe", "ID", "Gewichtsklasse", "Kategorie", "Grafik-Set", "Schadensart",
               "Schaden", "Schuesse", "Intervall (s)", "Reichweite", "Schaden/s roh (ohne Power)",
               "Besonderheit Angriff", "Faehigkeit", "Takt", "Faehigkeit: Wirkung",
               "Bonus-Wert (Passive)", "Bonus Lv 0", "Bonus Lv 10", "Besonderheit", "Status"]
    rows = []
    for i, w in enumerate(WEAPONS, 2):
        a = attack_of(w) or {}
        ab = ability_of(w) or {}
        ef = a.get("energy_fraction", 0.0)
        if a.get("heal") and a.get("support"):
            kind = "Energie / Heilung"
        elif ef >= 1.0:
            kind = "Energie"
        elif ef <= 0.0:
            kind = "kinetisch"
        else:
            kind = f"{pct(1 - ef)} kin. + {pct(ef)} Energie"
        bname, b0, b10 = weapon_bonus(w)
        rows.append([
            w["code"], w["name"], w["id"], CLASS_NAMES.get(w.get("mount_class"), ""),
            CATEGORY_NAMES.get(w.get("category", ""), w.get("category", "")), set_drome(w["set"]), kind,
            a.get("power", 0), a.get("shots", 1), a.get("interval", 0), a.get("range_tiles", 1),
            f"=ROUND(H{i}*I{i}/J{i},1)", attack_extra(a),
            ab.get("display_name", "--"), trigger_text(ab) if ab else "--", ability_effect(ab, a) if ab else "--",
            bname, b0, b10, TEXTE["waffen"].get(w["id"], ""), "gebaut",
        ])
    notes = {
        "Schaden/s roh (ohne Power)": "Formel: Schaden x Schuesse / Intervall. Ohne Faehigkeit, ohne Power des Traegers.",
        "Bonus-Wert (Passive)": "Jede Waffe gibt dem Traeger einen DROME-Wert; er steigt linear bis Waffenlevel 10.",
        "Grafik-Set": "Aus welcher DROME-Familie die Grafik stammt -- die Waffe darf trotzdem jeder tragen.",
        "Gewichtsklasse": "leicht passt in jeden Halter, mittel in mittel/schwer, schwer nur in schwer.",
    }
    write_table(ws, headers, rows, [9, 18, 18, 12, 10, 12, 18, 8, 8, 9, 9, 11, 30, 18, 18, 48, 14, 8, 8, 50, 10],
                notes=notes)


def build_passiven(ws):
    rows = []
    for b in BODIES:
        p = b["stats"]["passive"]
        rows.append(["DROME", drome_name(b["id"]), passive_name(p), p, passive_text(p), "data/config.json -> passives", "gebaut"])
    for w in WEAPONS:
        bname, b0, b10 = weapon_bonus(w)
        rows.append(["Waffe (Bonus-Wert)", w["name"], f"+{bname}", w["id"],
                     f"Traeger erhaelt +{b0} {bname} (Waffenlevel 10: +{b10}).", "parts/ + config -> levels.weapon", "gebaut"])
    for b in MODULES["bios"].values():
        if b["kind"] == "chassis":
            rows.append(["Chassis-BIOS", drome_name(b["chassis"]), b["name"], b["chassis"], b["text"], "data/modules.json -> bios", "gebaut"])
    for f in TEXTE["fraktionen"]:
        name, _, rest = f["chassis_vorschlag"].partition(" -- ")
        rows.append(["Fraktions-DROME", name, rest.split(":")[0], "--", rest, "VORSCHLAG_STORY 3", "Vorschlag"])
    write_table(ws, ["Art", "Traeger", "Passive", "ID", "Wirkung", "Quelle", "Status"], rows, [18, 22, 18, 18, 80, 30, 11])


def build_module(ws):
    rows = []
    for mid, m in MODULES["modules"].items():
        rec = [module_name(r) for r, rv in MODULES["recipes"].items() if mid in rv["from"]]
        rows.append([m["name"], mid, m["short"], MOD_CLASS.get(m["class"], m["class"]), CONDITION.get(m["condition"], m["condition"]),
                     effects_text(m["effects"]), ", ".join(rec), MODULES["shop"]["price"]["base"], MODULES["sell_value"]["base"], "gebaut"])
    write_table(ws, ["Grundmodul", "ID", "Kuerzel", "Klasse", "Passt zu", "Wirkung", "Steckt in Rezepten",
                     "Preis (Credits)", "Verkauf (Credits)", "Status"], rows, [16, 18, 8, 13, 22, 60, 48, 9, 9, 10])


def build_rezepte(ws):
    rows = []
    for rid, r in MODULES["recipes"].items():
        rows.append([r["name"], rid, r["short"], MOD_CLASS.get(r["class"], r["class"]), CONDITION.get(r["condition"], r["condition"]),
                     module_name(r["from"][0]), module_name(r["from"][1]), effects_text(recipe_total(rid)),
                     effects_text(r["bonus"]), "ja: " + r["gadget"] if r.get("gadget") else "--",
                     MODULES["shop"]["price"]["recipe"], MODULES["sell_value"]["recipe"], "gebaut"])
    write_table(ws, ["Rezept", "ID", "Kuerzel", "Klasse", "Passt zu", "Zutat 1", "Zutat 2", "Wirkung der Zutaten (Summe)",
                     "Eigener Effekt", "Gadget", "Preis (Credits)", "Verkauf (Credits)", "Status"], rows,
                [16, 20, 8, 13, 20, 15, 15, 55, 60, 14, 9, 9, 10])


def build_matrix(ws):
    bases = list(MODULES["modules"].keys())
    lookup = {}
    for rid, r in MODULES["recipes"].items():
        a, b = r["from"]
        lookup[(a, b)] = lookup[(b, a)] = r["name"]
    ws.cell(row=1, column=1, value="Zutat \\ Zutat").font = HEAD_FONT
    ws.cell(row=1, column=1).fill = HEAD_FILL
    for j, b in enumerate(bases, 2):
        c = ws.cell(row=1, column=j, value=module_name(b))
        c.font = HEAD_FONT
        c.fill = HEAD_FILL
        c.alignment = Alignment(wrap_text=True, horizontal="center")
        ws.column_dimensions[get_column_letter(j)].width = 15
    for i, a in enumerate(bases, 2):
        c = ws.cell(row=i, column=1, value=module_name(a))
        c.font = HEAD_FONT
        c.fill = HEAD_FILL
        for j, b in enumerate(bases, 2):
            v = lookup.get((a, b), "" if a != b else "--")
            cell = ws.cell(row=i, column=j, value=v)
            cell.font = BODY_FONT
            cell.border = BORDER
            cell.alignment = Alignment(wrap_text=True, horizontal="center", vertical="center")
            if v and v != "--":
                cell.fill = PatternFill("solid", fgColor="DCE8FA")
    ws.column_dimensions["A"].width = 16
    ws.freeze_panes = "B2"


def build_bios(ws):
    rows = []
    for bid, b in MODULES["bios"].items():
        if b["kind"] == "chassis":
            rows.append([b["name"], bid, b["short"], "Chassis", drome_name(b["chassis"]), "--", b["text"], "gebaut"])
        else:
            res = MODULES["bios_recipes"][b["result"]]
            base = MODULES["recipes"][res["base"]]
            text = f"Wirkung von {base['name']} ({effects_text(base['bonus'])}) plus: {effects_text(res['bonus'])}"
            rows.append([b["name"], bid, b["short"], "Rezept", module_name(b["recipe"]), res["name"], text, "gebaut"])
    write_table(ws, ["BIOS", "ID", "Kuerzel", "Art", "Wirkt auf", "Ergebnis", "Wirkung", "Status"], rows,
                [22, 18, 8, 10, 16, 16, 90, 10])
    r = len(rows) + 3
    ws.cell(row=r, column=1, value=f"Verkauf eines BIOS: {MODULES['sell_value']['bios']} Credits. "
            f"Angebot: 1 aus {RULES['bios_offers']}, nur nach Elite-Kaempfen, nie nach dem letzten Kampf.").font = BODY_FONT


def build_fraktionen(ws):
    regions = {r["faction"]["name"]: r for r in REGIONS["regions"]}
    rows = []
    for f in TEXTE["fraktionen"]:
        reg = regions.get(f["name"])
        fac = reg["faction"] if reg else {}
        chassis = ", ".join(f"{drome_name(k)} {num(v)}" for k, v in fac.get("chassis", {}).items()) or "--"
        rows.append([f["name"], f["gebiet"], fac.get("profile", f["profil"]), fac.get("text", "--"), f["virus"], chassis,
                     ", ".join(part_name(w) for w in fac.get("weapons", [])) or "--",
                     ", ".join(module_name(m) for m in fac.get("modules", [])) or "--",
                     ", ".join(module_name(m) for m in fac.get("recipes", [])) or "--",
                     len(ENCOUNTERS["factions"].get(reg["id"], {}).get("teams", [])) if reg else 0,
                     f["chassis_vorschlag"], f["boss"], f["status"]])
    notes = {"Chassis-Gewichte (Chaos)": "Gewicht je Chassis beim Wuerfeln (nur Chaos-Kampf / Generator).",
             "Haltung zum Virus": "Aus VORSCHLAG_STORY 1 -- noch nicht entschieden."}
    write_table(ws, ["Fraktion", "Gebiet", "Profil", "Spielstil", "Haltung zum Virus", "Chassis-Gewichte (Chaos)",
                     "Bevorzugte Waffen", "Bevorzugte Module", "Bevorzugte Rezepte", "Teams", "Eigener DROME (Vorschlag)",
                     "Bosse", "Status"], rows, [16, 14, 12, 40, 34, 32, 40, 36, 34, 7, 50, 24, 22], notes=notes)


def build_stages(ws):
    rows = []
    kinds = CONFIG["obstacles"]["kinds"]
    for i, r in enumerate(REGIONS["regions"], 1):
        fac = r["faction"]
        rows.append([i, r["name"], r["id"], r["floor"]["name"], fac["name"], fac["profile"], fac["text"],
                     ", ".join(kinds.get(r["id"], [])) or "--",
                     "ja" if r["id"] == CONFIG["run"]["region"] else "nein", "gebaut"])
    for z in TEXTE["stages_zusatz"]:
        rows.append([z["stage"], z["name"], z["id"], z["boden"], z["fraktion"], z["profil"], z["text"], "--", "nein", z["status"]])
    write_table(ws, ["Stage", "Gebiet", "ID", "Boden", "Fraktion", "Profil", "Text", "Hindernisse (Optik)",
                     "Gebiet des Laufs heute", "Status"], rows, [7, 16, 9, 12, 18, 18, 50, 50, 12, 10])


def build_story(ws):
    rows = [[s["thema"], s["text"], s["status"]] for s in TEXTE["story"]]
    last = write_table(ws, ["Thema", "Text", "Status"], rows, [20, 100, 12])
    r = last + 2
    ws.cell(row=r, column=1, value="Story-Modus Neon City: zehn Level").font = SUB_FONT
    rows = [[s["level"], s["titel"], s["squad"], s["kaempfe"], s["gegner"], s["neu"], s["status"]] for s in TEXTE["story_level"]]
    last = write_table(ws, ["Level", "Titel", "Squad", "Kaempfe", "Gegner", "Neu fuer den Spieler", "Status"], rows, start_row=r + 1)
    r = last + 2
    ws.cell(row=r, column=1, value="Bosse").font = SUB_FONT
    rows = [[b["name"], b["fraktion"], b["level"], b["drome"], b["lehrt"], b["status"]] for b in TEXTE["bosse"]]
    write_table(ws, ["Boss", "Fraktion", "Level", "DROME", "Lehrt", "Status"], rows, start_row=r + 1)
    for c, w in enumerate([20, 100, 12, 12, 40, 34, 12], 1):
        ws.column_dimensions[get_column_letter(c)].width = max(w, ws.column_dimensions[get_column_letter(c)].width or 0)


def build_gegnertypen(ws):
    rows = [[t["name"], tid, t["hint"], "gebaut"] for tid, t in TYPES.items()]
    write_table(ws, ["Gegnertyp", "ID", "Was er tut / was hilft", "Status"], rows, [14, 12, 90, 10])


def team_rows():
    regions = {r["id"]: r for r in REGIONS["regions"]}
    groups = [("Training", "--", t) for t in ENCOUNTERS["training"]]
    for rid, f in ENCOUNTERS["factions"].items():
        for t in f["teams"]:
            groups.append((regions[rid]["faction"]["name"] if rid in regions else rid, regions.get(rid, {}).get("name", rid), t))
    return groups


def build_teams(ws):
    rows = []
    for fac, gebiet, t in team_rows():
        tiers = ", ".join(TIER_NAMES[x] for x in t.get("tiers", ["easy", "normal", "elite"]))
        rounds = f"{t.get('from_round', 1)} - {t.get('to_round', 'Ende')}"
        for pos, d in enumerate(t["dromes"], 1):
            rows.append([fac, gebiet, t["name"], t["id"], TYPES.get(t["type"], {}).get("name", t["type"]), tiers, rounds,
                         pos, d["name"], drome_name(d["chassis"]), " + ".join(part_name(w) for w in d["weapons"]),
                         ", ".join(module_name(m) for m in d.get("modules", [])) or "--",
                         module_name(d["recipe"]) if d.get("recipe") else "--",
                         t.get("text", "") if pos == 1 else ""])
    notes = {"Pos.": "Treten N Gegner an, sind es die ersten N.",
             "Module": "In dieser Reihenfolge kommen sie mit Runde und Stufe dazu (Blatt Lauf).",
             "Rezept": "Ersetzt ab der Rezept-Runde das erste Modul, wenn 2 Plaetze frei sind."}
    write_table(ws, ["Fraktion", "Gebiet", "Team", "Team-ID", "Gegnertyp", "Stufen", "Runden", "Pos.", "Einheit",
                     "DROME", "Waffen", "Module", "Rezept", "Beschreibung"], rows,
                [16, 12, 16, 16, 11, 20, 9, 6, 16, 9, 30, 32, 16, 50], notes=notes)


def build_einheiten(ws):
    units = {}
    order = []
    for fac, gebiet, t in team_rows():
        for d in t["dromes"]:
            key = (fac, d["name"])
            if key not in units:
                units[key] = {"chassis": set(), "weapons": set(), "teams": []}
                order.append(key)
            u = units[key]
            u["chassis"].add(drome_name(d["chassis"]))
            u["weapons"].add(" + ".join(part_name(w) for w in d["weapons"]))
            u["teams"].append(t["name"])
    rows = []
    for fac, name in order:
        u = units[(fac, name)]
        rows.append([name, fac, ", ".join(sorted(u["chassis"])), " / ".join(sorted(u["weapons"])),
                     len(u["teams"]), ", ".join(dict.fromkeys(u["teams"])), "gebaut"])
    for b in TEXTE["bosse"]:
        rows.append([b["name"] + " (Boss)", b["fraktion"], b["drome"].split(" ")[0], b["drome"], 0, "--", b["status"]])
    write_table(ws, ["Einheit", "Fraktion", "DROME", "Waffen", "Einsaetze", "Teams", "Status"], rows,
                [20, 16, 16, 50, 9, 50, 10])


def build_rollen(ws):
    rows = [[r["name"], r["id"], r["traeger"], r["zielregel"], r["fraktion"], r["status"]] for r in TEXTE["rollen"]]
    write_table(ws, ["Rolle", "ID", "Traeger", "Zielregel", "Betont von Fraktion", "Status"], rows, [14, 12, 36, 60, 18, 11])


def build_lauf(ws):
    run = CONFIG["run"]
    rows = []
    for i in range(run["rounds"]):
        rnd = i + 1
        rows.append([rnd, "ja" if rnd <= run["training_rounds"] else "nein",
                     run["enemy_offsets"][i], run["enemy_levels"]["drome"][i], run["enemy_levels"]["weapon"][i],
                     run["enemy_modules"]["by_round"][i],
                     "ja" if rnd >= run["enemy_modules"]["recipe_from_round"] else "nein",
                     "ja" if rnd in run["new_drome_rounds"] else "nein"])
    notes = {"Gegnerzahl-Versatz": "Gegnerzahl = Startgroesse des Squads + Versatz + Versatz der Stufe (1..4)."}
    last = write_table(ws, ["Runde", "Training", "Gegnerzahl-Versatz", "Gegner DROME-Level", "Gegner Waffenlevel",
                            "Module je Gegner", "Rezept moeglich", "Neuer DROME als Beute (Normal)"], rows,
                       [8, 10, 12, 12, 12, 11, 11, 16], notes=notes)
    r = last + 2
    ws.cell(row=r, column=1, value="Stufen (Leicht / Normal / Elite)").font = SUB_FONT
    rows = []
    lo = run["enemy_levels"]["tier_offset"]
    mo = run["enemy_modules"]["tier_offset"]
    for tid, t in run["tiers"].items():
        rows.append([TIER_NAMES[tid], t["count_offset"], lo[tid]["drome"], lo[tid]["weapon"], mo[tid], t["credits"],
                     t.get("part_chance", 0), t.get("loot_credits", "--"), t.get("drome_chance", "--"),
                     t.get("life_chance", run["life_chance"]), t["reward_text"]])
    write_table(ws, ["Stufe", "Gegnerzahl +", "DROME-Level +", "Waffenlevel +", "Module +", "Credits je Sieg",
                     "Chance Teil", "Credits statt Teil", "Chance neuer DROME", "Chance Notstrom", "Beute"],
                rows, start_row=r + 1)
    ws.column_dimensions["K"].width = 50


def build_level(ws):
    lv = CONFIG["levels"]
    d, w = lv["drome"], lv["weapon"]
    ws.cell(row=1, column=1, value="DROME-Level").font = SUB_FONT
    rows = []
    for i, xp in enumerate(d["xp_per_level"]):
        r = i + 3
        rows.append([i + 1, xp, f"=SUM(B$3:B{r})", f"=A{r}*{d['main_per_level']}", f"=A{r}*{d['other_per_level']}"])
    last = write_table(ws, ["Level", "EP fuer dieses Level", "EP gesamt", "Hauptwerte +", "andere Werte +"], rows, start_row=2)
    for r in range(3, last + 1):
        ws.cell(row=r, column=4).number_format = "0%"
        ws.cell(row=r, column=5).number_format = "0%"
    r = last + 1
    for t in [f"EP je Sieg = {d['win_base']} x Stufenfaktor (Leicht {d['tier_mult']['easy']}, Normal {d['tier_mult']['normal']}, "
              f"Elite {d['tier_mult']['elite']}) x (1 + {d['per_round']} x (Runde - 1)).",
              "Speed und Power steigen nie. Hauptwerte je DROME und Level mit +1 Modulplatz: Blatt DROMEs."]:
        ws.cell(row=r, column=1, value=t).font = BODY_FONT
        r += 1
    r += 1
    ws.cell(row=r, column=1, value="Waffen-Level").font = SUB_FONT
    rows = []
    for i, xp in enumerate(w["xp_per_level"]):
        rr = r + 2 + i
        rows.append([i + 1, xp, f"=SUM(B${r + 2}:B{rr})", f"=A{rr}*{w['damage_per_level']}"])
    last = write_table(ws, ["Level", "EP fuer dieses Level", "EP gesamt", "Schaden +"], rows, start_row=r + 1)
    for rr in range(r + 2, last + 1):
        ws.cell(row=rr, column=4).number_format = "0%"
    r = last + 1
    for t in [f"EP je Kampf = {w['damage_xp']} x angerichteter Schaden + {w['kill_xp']} je Abschuss mit dieser Waffe.",
              "Dazu steigt der Bonus-Wert der Waffe linear bis Level 10 (Blatt Waffen).",
              "Nur der Energieanteil waechst bei: " + ", ".join(part_name(x) for x in w["energy_only"]) + "."]:
        ws.cell(row=r, column=1, value=t).font = BODY_FONT
        r += 1
    for c, wd in enumerate([10, 20, 12, 14, 14], 1):
        ws.column_dimensions[get_column_letter(c)].width = wd


def build_teile(ws):
    type_names = {"body": "Chassis", "head": "Kopf", "core": "Kern", "feet": "Antrieb", "equipment": "Waffe"}
    rows = []
    for p in sorted(PARTS.values(), key=lambda p: (p["set"], p["code"])):
        rows.append([p["code"], p["name"], p["id"], type_names.get(p["type"], p["type"]), set_drome(p["set"]),
                     CLASS_NAMES.get(p.get("mount_class", ""), "--"), ", ".join(p.get("tags", []))])
    write_table(ws, ["Code", "Teil", "ID", "Art", "Gehoert zu", "Gewichtsklasse", "Tags"], rows, [9, 22, 18, 10, 12, 13, 40])


def build_offen(ws):
    rows = [[i, o["punkt"], o["quelle"], o["status"]] for i, o in enumerate(TEXTE["offene_punkte"], 1)]
    write_table(ws, ["Nr.", "Punkt", "Quelle", "Status"], rows, [6, 100, 26, 10])


def build_glossar(ws):
    rows = [[g["begriff"], g["erklaerung"]] for g in TEXTE["glossar"]]
    write_table(ws, ["Begriff", "Erklaerung"], rows, [20, 100])


# ---------------------------------------------------------------------------
# Neues Spielprinzip (12./13. Nov. 2026, docs/GEGNERDESIGN.md) -- noch nicht
# gebaut. Daten aus docs/spot/inhalte.json, hellblaue Spalten fuellt der Spieler.
# ---------------------------------------------------------------------------

VIRUS = {}  # id -> Zelle auf "Einsatz" (fuer Formeln)
ART_NAMES = ["Waffe", "DROME", "Modul", "BIOS", "Credits", "Platzhaltercoin"]


def item_name(pid):
    if not pid:
        return ""
    if pid in PARTS:
        return drome_name(pid) if PARTS[pid]["type"] == "body" else part_name(pid)
    return module_name(pid)


def weapon_dps(cell, power_cell):
    """Formel: Schaden/s roh der Waffe (Blatt Waffen) x Power / 10."""
    return f"IFERROR(INDEX(Waffen!$L:$L,MATCH({cell},Waffen!$B:$B,0))*{power_cell}/10,0)"


def add_list(ws, values, ref):
    dv = DataValidation(type="list", formula1='"' + ",".join(values) + '"', allow_blank=True)
    ws.add_data_validation(dv)
    dv.add(ref)


def build_einsatz(ws):
    rows = []
    for v in TEXTE["virusschaden"]:
        VIRUS[v["id"]] = f"Einsatz!$C${len(rows) + 2}"
        rows.append(["Virusschaden", v["parameter"], v["wert"], v["status"], v["notiz"]])
    r = len(rows) + 2
    rows.append(["Virusschaden", "Spätestes Kampfende (s), Bezug Höchstwerte",
                 f"={VIRUS['start']}+ROUNDUP(1/{VIRUS['anteil']},0)*{VIRUS['puls']}", "Formel",
                 "danach ist jede Einheit zerstört"])
    for e in TEXTE["einsatz"]:
        rows.append(["Einsatz", e["parameter"], e["wert"], e["status"], e["notiz"]])
    last = write_table(ws, ["Bereich", "Parameter", "Wert", "Status", "Notiz"], rows, [14, 44, 26, 13, 60],
                       inputs=("Wert",))
    ws[VIRUS["anteil"].split("!")[1].replace("$", "")].number_format = "0%"
    r = last + 2
    ws.cell(row=r, column=1, value="Lootdrop: wann gibt es einen Cache?").font = SUB_FONT
    rows = []
    for i, l in enumerate(TEXTE["lootregeln"], r + 2):
        rows.append([l["wann"], l["art"], l["chance"], l["anzahl"], f"=C{i}*D{i}", l["coins"], l["status"]])
    notes = {"Art": "sicher = deterministisch, Glück = gewürfelt mit der Chance daneben.",
             "Platzhaltercoin ohne Cache": "So viele Coins gibt es, wenn kein Cache droppt."}
    last = write_table(ws, ["Wann", "Art", "Chance auf Cache", "Caches", "Erwartete Caches",
                            "Platzhaltercoin ohne Cache", "Status"], rows, start_row=r + 1, notes=notes,
                       inputs=("Art", "Chance auf Cache", "Caches", "Platzhaltercoin ohne Cache"))
    for rr in range(r + 2, last + 1):
        ws.cell(row=rr, column=3).number_format = "0%"
    add_list(ws, ["sicher", "Glück", "--"], f"B{r + 2}:B{last + 10}")
    ws.cell(row=last + 1, column=1, value="Welcher Cache: immer der der Fraktion des Gebiets "
            "(Blatt Lootcaches). Was drin ist: Blatt Lootcaches.").font = BODY_FONT
    ws.column_dimensions["F"].width = 16
    ws.column_dimensions["G"].width = 13


def build_lootcaches(ws):
    drops = TEXTE["cache_drops"] + [{"cache": "", "art": "", "gegenstand": "", "menge": None, "gewicht": None,
                                     "status": ""}] * 20  # freie Zeilen fuer eigene Drops
    n = len(drops) + 1
    rows = []
    for i, d in enumerate(drops, 2):
        rows.append([d["cache"], d["art"], item_name(d["gegenstand"]) or d["gegenstand"], d["menge"], d["gewicht"],
                     f'=IF(E{i}="","",IFERROR(E{i}/SUMIF($A$2:$A${n},A{i},$E$2:$E${n}),""))', d["status"]])
    notes = {"Gewicht": "Je höher, desto öfter. Die Chance ergibt sich aus Gewicht / Summe der Gewichte im selben Cache.",
             "Gegenstand": "Name aus den Blättern Waffen, DROMEs, Module, BIOS -- oder Credits / Platzhaltercoin.",
             "Menge": "Stückzahl bzw. Betrag (Credits, Coins)."}
    last = write_table(ws, ["Cache", "Art", "Gegenstand", "Menge", "Gewicht", "Chance im Cache", "Status"], rows,
                       [16, 16, 26, 9, 9, 12, 12], notes=notes, inputs=("Cache", "Art", "Gegenstand", "Menge", "Gewicht"))
    for rr in range(2, n + 1):
        ws.cell(row=rr, column=6).number_format = "0%"
    caches = [c["cache"] for c in TEXTE["caches"]]
    add_list(ws, caches, f"A2:A{n}")
    add_list(ws, ART_NAMES, f"B2:B{n}")
    ws.cell(row=last + 1, column=1, value="Leere Zeilen oben: eigene Drops einfach eintragen.").font = BODY_FONT
    r = last + 3
    ws.cell(row=r, column=1, value="Caches je Fraktion").font = SUB_FONT
    rows = []
    for i, c in enumerate(TEXTE["caches"], r + 2):
        rows.append([c["cache"], c["fraktion"], c["gebiet"], c["preis_coin"],
                     f'=COUNTIFS($A$2:$A${n},A{i},$E$2:$E${n},">0")', c["status"]])
    write_table(ws, ["Cache", "Fraktion", "Gebiet", "Preis im Hangar (Coin)", "Drops mit Gewicht", "Status"], rows,
                start_row=r + 1, inputs=("Cache", "Preis im Hangar (Coin)"))


def build_hangar(ws):
    rows = [[h["angebot"], h["art"], h["preis"], h["wirkung"], h["status"]] for h in TEXTE["hangar_shop"]]
    last = write_table(ws, ["Angebot", "Art", "Preis (Platzhaltercoin)", "Wirkung", "Status"], rows,
                       [22, 12, 14, 60, 12], inputs=("Angebot", "Art", "Preis (Platzhaltercoin)", "Wirkung"))
    add_list(ws, ["Cache", "Upgrade"], f"B2:B{last + 10}")
    ws.cell(row=last + 2, column=1, value="Platzhaltercoin gibt es, wenn kein Lootcache droppt (Blatt Einsatz). "
            "Credits bleiben die Währung des Shops im Einsatz.").font = BODY_FONT


def build_sentinels(ws):
    weapons = [w["name"] for w in WEAPONS]
    headers = ["Sentinel", "Fraktion", "Archetyp", "Waffe", "Gewichtsklasse", "Speed", "Lauftempo (Felder/s)",
               "Integritaet", "Schild", "Integritaet + Schild", "Schildpuls", "Ruestung", "Power", "Modulplaetze",
               "Schaden/s roh (Waffe x Power)", "Virusschaden je Puls", "Status"]
    rows = []
    for i, s in enumerate(TEXTE["sentinels"], 2):
        rows.append([f"{s['fraktion']} {s['archetyp']} Sentinel", s["fraktion"], s["archetyp"], part_name(s["waffe"]),
                     f'=IFERROR(INDEX(Waffen!$D:$D,MATCH(D{i},Waffen!$B:$B,0)),"--")', s["speed"],
                     f"=ROUND(MAX({REG['realtime.move_min']},{REG['realtime.move_base']}+F{i}*{REG['realtime.move_per_spd']}),2)",
                     s["integritaet"], s["schild"], f"=H{i}+I{i}", s["schildpuls"], s["ruestung"], s["power"],
                     s["modulplaetze"], f"=ROUND({weapon_dps(f'D{i}', f'M{i}')},1)",
                     f"=ROUND(J{i}*{VIRUS['anteil']},1)", s["status"]])
    notes = {"Power": "Eigene, schwächere Power-Wertung: Rohschaden = Waffenschaden x Power / 10 (DROMEs 6-15).",
             "Waffe": "Echte Waffe aus dem Blatt Waffen -- ein Waffenslot.",
             "Schaden/s roh (Waffe x Power)": "Schaden/s roh der Waffe (Blatt Waffen) x Power / 10, ohne Fähigkeit.",
             "Virusschaden je Puls": "Ab Minute 5: Anteil (Blatt Einsatz) x (Integritaet + Schild)."}
    inputs = ("Fraktion", "Archetyp", "Waffe", "Speed", "Integritaet", "Schild", "Schildpuls", "Ruestung", "Power",
              "Modulplaetze")
    last = write_table(ws, headers, rows, [24, 10, 10, 20, 12, 7, 10, 10, 8, 10, 9, 8, 7, 10, 12, 11, 11],
                       notes=notes, inputs=inputs)
    add_list(ws, weapons, f"D2:D{last + 10}")
    add_list(ws, [a["archetyp"] for a in TEXTE["sentinel_archetypen"]], f"C2:C{last + 10}")
    add_list(ws, [f["kurz"] for f in TEXTE["fraktionen"]], f"B2:B{last + 10}")
    r = last + 2
    ws.cell(row=r, column=1, value="Archetypen").font = SUB_FONT
    rows = [[a["archetyp"], a["aufgabe"], a["verhalten"], a["status"]] for a in TEXTE["sentinel_archetypen"]]
    last = write_table(ws, ["Archetyp", "Aufgabe", "Verhalten (kommt aus der Waffe)", "Status"], rows, start_row=r + 1)
    ws.cell(row=last + 1, column=1, value="Tank und Plänkler gibt es bewusst nicht als Sentinel -- die Rollen "
            "decken die DROMEs ab.").font = BODY_FONT
    r = last + 3
    ws.cell(row=r, column=1, value="Varianten (wirken auf die Basic-Werte oben)").font = SUB_FONT
    rows = [[v["variante"], v["integritaet"], v["schild"], v["power"], v["ruestung"], v["speed"], v["module"],
             v["herausforderung"], v["status"]] for v in TEXTE["sentinel_varianten"]]
    write_table(ws, ["Variante", "Integritaet x", "Schild x", "Power x", "Ruestung +", "Speed +", "Modulplaetze +",
                     "Neue Herausforderung", "Status"], rows, start_row=r + 1,
                inputs=("Integritaet x", "Schild x", "Power x", "Ruestung +", "Speed +", "Modulplaetze +",
                        "Neue Herausforderung"))
    ws.cell(row=r + len(rows) + 2, column=1, value="Regel: eine höhere Variante darf nicht nur mehr Integrität und "
            "Schaden bedeuten -- jede bringt eine neue taktische Herausforderung.").font = BODY_FONT


def build_gegner_dromes(ws):
    weapons = [w["name"] for w in WEAPONS]
    headers = ["Gegner-DROME", "Fraktion", "Chassis", "Rolle", "Waffe 1", "Waffe 2", "Speed", "Lauftempo (Felder/s)",
               "Integritaet", "Schild", "Integritaet + Schild", "Schildpuls", "Ruestung", "Power", "Modulplaetze",
               "Schaden/s roh (Waffen x Power)", "Virusschaden je Puls", "Aufgabe in der Squad", "Status"]
    rows = []
    for i, g in enumerate(TEXTE["gegner_dromes"], 2):
        w = [part_name(x) for x in g["waffe"].split(" + ")] + [""]
        role = PARTS[g["chassis"]]["stats"]["ai_role"]
        rows.append([g["name"], g["fraktion"], drome_name(g["chassis"]), ROLE_NAMES.get(role, role), w[0], w[1],
                     g["speed"],
                     f"=ROUND(MAX({REG['realtime.move_min']},{REG['realtime.move_base']}+G{i}*{REG['realtime.move_per_spd']}),2)",
                     g["integritaet"], g["schild"], f"=I{i}+J{i}", g["schildpuls"], g["ruestung"], g["power"],
                     g["modulplaetze"], f"=ROUND({weapon_dps(f'E{i}', f'N{i}')}+{weapon_dps(f'F{i}', f'N{i}')},1)",
                     f"=ROUND(K{i}*{VIRUS['anteil']},1)", g["aufgabe"], g["status"]])
    notes = {"Speed": "Startwerte = Werte des Chassis (Blatt DROMEs) -- hier frei ausbalancieren.",
             "Waffe 2": "Nur Molok hat zwei Halter.",
             "Schaden/s roh (Waffen x Power)": "Summe Schaden/s roh beider Waffen (Blatt Waffen) x Power / 10."}
    inputs = ("Gegner-DROME", "Fraktion", "Chassis", "Waffe 1", "Waffe 2", "Speed", "Integritaet", "Schild",
              "Schildpuls", "Ruestung", "Power", "Modulplaetze", "Aufgabe in der Squad")
    last = write_table(ws, headers, rows, [16, 10, 10, 13, 18, 18, 7, 10, 10, 8, 10, 9, 8, 7, 10, 12, 11, 46, 11],
                       notes=notes, inputs=inputs)
    add_list(ws, weapons, f"E2:F{last + 10}")
    add_list(ws, [drome_name(b["id"]) for b in BODIES], f"C2:C{last + 10}")
    add_list(ws, [f["kurz"] for f in TEXTE["fraktionen"]], f"B2:B{last + 10}")
    ws.cell(row=last + 2, column=1, value="Der gegnerische DROME ist der taktische Mittelpunkt: eigene Waffe und "
            "Passive, aktive Bedrohung, prägt die Spielweise der Squad. Ob besiegte DROMEs freigeschaltet "
            "werden, ist bewusst offen.").font = BODY_FONT


def build_fragen(ws):
    rows = [[i, f["schritt"], f["thema"], f["frage"], f["vorschlag"], f.get("antwort", ""), f.get("notiz", "")]
            for i, f in enumerate(TEXTE["fragen"], 1)]
    notes = {"Antwort": "ok = Vorschlag übernehmen. Sonst deine Entscheidung in eigenen Worten.",
             "Vorschlag (Claude)": "Empfehlung von Claude -- nicht entschieden."}
    last = write_table(ws, ["Nr.", "Schritt", "Thema", "Frage", "Vorschlag (Claude)", "Antwort", "Notiz"], rows,
                       [6, 18, 18, 55, 60, 40, 30], notes=notes, inputs=("Antwort", "Notiz"))
    ws.cell(row=last + 2, column=1, value="Detailfragen für die Bauschritte 1 Sentinels (mit Heilstrahl), "
            "2 Formationen, 3 Einsatz. Hellblau ausfüllen: 'ok' übernimmt den Vorschlag.").font = BODY_FONT


MAP_SIZE = 24  # Raster der Vorlagen; heute gebaut sind 20 x 20
MAP_COLORS = {"X": "3A3A46", "H": "8A8FA0", "F": "F4B6B6", "M": "FFE8A3", "B": "B6E3F4"}


def build_maps(ws):
    """Quadratische Zellen zum Zeichnen von Arenen (Buchstaben, Rahmen nach Belieben)."""
    ws.sheet_view.showGridLines = True
    ws.sheet_view.zoomScale = 85
    for c in range(1, MAP_SIZE + 2):
        ws.column_dimensions[get_column_letter(c)].width = 3.0
    legend = [
        "Maps: Arenen zeichnen. Jede Zelle ist ein Feld. Buchstaben ins Feld, Umrisse gern zusätzlich als Rahmen.",
        "X = außerhalb / Wand (so entstehen nicht-rechteckige Arenen)   H = festes Hindernis (sperrt Laufwege, Schüsse gehen drüber)",
        "F = Frontline (Assault)   M = Mittellinie (Support)   B = Backline (Sniper)   leer = freies Feld",
        "Ausrichtung: Spieler LINKS, Gegner RECHTS (für die Iso-Ansicht dreht das Spiel die Karte).",
        "Gegnerseite: leer lassen = gespiegelt zur Spielerseite (um die Mitte gedreht), oder selbst eintragen.",
        "Gelesen werden nur die Buchstaben -- Rahmen und Farben sind für dich. Name, Gebiet, Notiz: hellblau.",
        "Heute gebaut: 20 x 20, Hindernisse je Seed gewürfelt. Die Vorlagen sind 24 x 24, damit Platz für andere Formen ist.",
    ]
    for r, t in enumerate(legend, 1):
        ws.cell(row=r, column=1, value=t).font = SUB_FONT if r == 1 else BODY_FONT
    row = len(legend) + 2
    cell_font = Font(name=FONT, bold=True, size=9)
    small = Font(name=FONT, size=7, color="8A8FA0")
    center = Alignment(horizontal="center", vertical="center")
    for n, m in enumerate(TEXTE["maps"], 1):
        ws.cell(row=row, column=1, value=f"Map {n}").font = SUB_FONT
        for col, label, key, span in ((4, "Name", "name", 7), (13, "Gebiet", "gebiet", 5)):
            ws.cell(row=row, column=col, value=label).font = BODY_FONT
            c = ws.cell(row=row, column=col + 2, value=m[key] or None)
            c.fill = INPUT_FILL
            c.font = BODY_FONT
            ws.merge_cells(start_row=row, start_column=col + 2, end_row=row, end_column=col + 1 + span)
        row += 1
        ws.cell(row=row, column=1, value="Notiz").font = BODY_FONT
        c = ws.cell(row=row, column=3, value=m["notiz"] or None)
        c.fill = INPUT_FILL
        c.font = BODY_FONT
        c.alignment = Alignment(wrap_text=True, vertical="top")
        ws.merge_cells(start_row=row, start_column=3, end_row=row, end_column=MAP_SIZE + 1)
        ws.row_dimensions[row].height = 30
        row += 1
        lines = m["zeilen"]
        width = len(lines[0])
        for x in range(width):
            h = ws.cell(row=row, column=x + 2, value=x + 1)
            h.font, h.alignment = small, center
        ws.row_dimensions[row].height = 12
        top = row + 1
        for y, line in enumerate(lines):
            r = top + y
            ws.row_dimensions[r].height = 19.5  # Spaltenbreite 3,0 = 26 px = 19,5 pt -> quadratisch
            h = ws.cell(row=r, column=1, value=y + 1)
            h.font, h.alignment = small, center
            for x, ch in enumerate(line):
                c = ws.cell(row=r, column=x + 2, value=None if ch == "." else ch)
                c.font, c.alignment = cell_font, center
        rng = f"B{top}:{get_column_letter(width + 1)}{top + len(lines) - 1}"
        for ch, color in MAP_COLORS.items():
            ws.conditional_formatting.add(rng, CellIsRule(operator="equal", formula=[f'"{ch}"'],
                                                          fill=PatternFill("solid", bgColor=color)))
        row = top + len(lines) + 2


def build_formationen(ws):
    rows = []
    for i, f in enumerate(TEXTE["formationen"], 2):
        rows.append([f["formation"], f["fraktion"], f["welle"], f["dromes"], f["assault"], f["sniper"], f["support"],
                     f"=SUM(E{i}:G{i})",
                     f'=H{i}+IF(D{i}="",0,LEN(D{i})-LEN(SUBSTITUTE(D{i},"+",""))+1)',
                     f["variante"], f["module"], f["text"], f["status"]])
    notes = {"DROMEs": "Namen aus Blatt Gegner-DROMEs, mehrere mit + verbinden.",
             "Einheiten gesamt": "Sentinels + DROMEs. Der Spieler hat bis zu 4 DROMEs."}
    inputs = ("Formation", "Fraktion", "Welle", "DROMEs", "Assault", "Sniper", "Support", "Variante", "Module",
              "Steigerung")
    last = write_table(ws, ["Formation", "Fraktion", "Welle", "DROMEs", "Assault", "Sniper", "Support",
                            "Sentinels gesamt", "Einheiten gesamt", "Variante", "Module", "Steigerung", "Status"],
                       rows, [20, 10, 7, 26, 8, 8, 8, 10, 10, 11, 22, 36, 11], notes=notes, inputs=inputs)
    add_list(ws, [v["variante"] for v in TEXTE["sentinel_varianten"]], f"J2:J{last + 10}")
    ws.cell(row=last + 2, column=1, value="Name und Zusammensetzung sollen schon vor dem Kampf zeigen, welche "
            "Herausforderung wartet. Stellschrauben: Zahl der Gegner, Zahl der DROMEs (stärkste Eskalation), "
            "Zusammensetzung, Module, Varianten, Synergien.").font = BODY_FONT


def build_design(ws):
    rows = [[f["name"], f["hex"], "", f["verwendung"], "entschieden"] for f in TEXTE["design_farben"]]
    last = write_table(ws, ["Farbe", "Hex", "Muster", "Verwendung", "Status"], rows, [20, 11, 9, 80, 12])
    for i, f in enumerate(TEXTE["design_farben"], 2):
        ws.cell(row=i, column=3).fill = PatternFill("solid", fgColor=f["hex"].lstrip("#").upper())
    r = last + 2
    ws.cell(row=r, column=1, value="Schriften").font = SUB_FONT
    rows = [[f["schrift"], f["einsatz"], f["groessen"], f["quelle"]] for f in TEXTE["design_schriften"]]
    last = write_table(ws, ["Schrift", "Einsatz", "Groessen (bei 450 px Breite)", "Quelle"], rows, start_row=r + 1)
    r = last + 2
    ws.cell(row=r, column=1, value="Bildschirme").font = SUB_FONT
    rows = [[b["bildschirm"], b["inhalt"], b["status"]] for b in TEXTE["design_bildschirme"]]
    last = write_table(ws, ["Bildschirm", "Inhalt", "Status"], rows, start_row=r + 1)
    r = last + 2
    ws.cell(row=r, column=1, value="Effekte und Formensprache").font = SUB_FONT
    rows = [[e["effekt"], e["wirkung"], e["status"]] for e in TEXTE["design_effekte"]]
    last = write_table(ws, ["Effekt", "Wirkung", "Status"], rows, start_row=r + 1)
    ws.cell(row=last + 2, column=1, value="Entwuerfe (450 x 800, Hochformat): docs/design/titel_arcade/TitleArcade.dc.html, "
            "docs/design/spielstand_arcade/SavesArcade.dc.html -- Ordner ausliefern (python3 -m http.server) "
            "und im Browser oeffnen. Noch nicht gebaut.").font = BODY_FONT


SHEETS = [
    ("Uebersicht", "Wie die Tabelle gepflegt wird, Legende", build_uebersicht),
    ("Eckpunkte", "Alle festgehaltenen Entscheidungen mit Datum und Status", build_eckpunkte),
    ("Fragen", "OFFEN: Detailfragen fuer die Schritte 1-3 (Sentinels, Heilstrahl, Formationen, Einsatz) -- Antwort ausfuellen", build_fragen),
    ("Einsatz", "NEU (nicht gebaut): Einsatz, Virusschaden, wann ein Lootcache droppt", build_einsatz),
    ("Lootcaches", "NEU (nicht gebaut): was in welchem Cache steckt -- vom Spieler festgelegt", build_lootcaches),
    ("Hangar-Shop", "NEU (nicht gebaut): Upgrades und Caches fuer Platzhaltercoin", build_hangar),
    ("Sentinels", "NEU (nicht gebaut): Gegner-Bots je Fraktion und Archetyp, Varianten", build_sentinels),
    ("Gegner-DROMEs", "NEU (nicht gebaut): die DROMEs der Gegner-Squads", build_gegner_dromes),
    ("Formationen", "NEU (nicht gebaut): Gegner-Squads Welle fuer Welle", build_formationen),
    ("Maps", "OFFEN: Arenen zeichnen -- Frontline, Mittellinie, Backline, Umrisse (quadratische Zellen)", build_maps),
    ("Design", "NEU (nicht gebaut): Arcade-Glitch-Stil -- Farben, Schriften, Titel und Spielstand-Wahl", build_design),
    ("DROMEs", "Die DROMEs: Rolle, Identitaet, Werte, Passive, Level, BIOS, Bauteile", build_dromes),
    ("Waffen", "Alle Waffen: Angriff, Faehigkeit, Takt, Bonus-Wert (Passive), Besonderheit", build_waffen),
    ("Passiven", "Alle Passiven: DROMEs, Waffen-Bonus, Chassis-BIOS, Fraktions-Vorschlaege", build_passiven),
    ("Module", "Die 9 Grundmodule", build_module),
    ("Rezepte", "Die Rezepte aus je zwei Grundmodulen", build_rezepte),
    ("Rezept-Matrix", "Welche zwei Grundmodule welches Rezept ergeben", build_matrix),
    ("BIOS", "Matrix-BIOS: Chassis und Rezept", build_bios),
    ("Fraktionen", "Fraktionen, Profile, Besonderheiten, Vorschlaege", build_fraktionen),
    ("Stages", "Gebiete / Stages mit Fraktion und Boden", build_stages),
    ("Story", "Aufhaenger, Story-Level, Bosse (Vorschlaege)", build_story),
    ("Gegnertypen", "Sturm, Schuetzen, Bollwerk, Kontrolle, Gemischt", build_gegnertypen),
    ("Gegnerteams", "Heute gebaut (symmetrisch): alle Teams, je DROME eine Zeile -- abgeloest durch Formationen", build_teams),
    ("Einheiten", "Heute gebaut: alle benannten Einheiten und wo sie auftreten", build_einheiten),
    ("Rollen", "KI-Rollen und Zielregeln", build_rollen),
    ("Lauf", "Heute gebaut: der Lauf Runde fuer Runde, Stufen und Beute -- abgeloest durch Einsatz", build_lauf),
    ("Level", "Level von DROMEs und Waffen", build_level),
    ("Regeln", "Alle Stellschrauben aus config.json und modules.json", build_regeln),
    ("Teile", "Alle Bauteile mit Code", build_teile),
    ("Offene Punkte", "Was noch entschieden werden muss", build_offen),
    ("Glossar", "Begriffe", build_glossar),
]
SHEETS_INFO = [(n, t) for n, t, _ in SHEETS]


def build():
    wb = Workbook()
    wb.remove(wb.active)
    sheets = {name: sheet(wb, name) for name, _, _ in SHEETS}
    # Regeln zuerst fuellen: die Formeln der anderen Blaetter zeigen darauf.
    build_regeln(sheets["Regeln"])
    build_einsatz(sheets["Einsatz"])
    for name, _, fn in SHEETS:
        if fn not in (build_regeln, build_einsatz):
            fn(sheets[name])
    wb.calculation.fullCalcOnLoad = True
    return wb


def snapshot(wb):
    out = {}
    for ws in wb.worksheets:
        rows = []
        for row in ws.iter_rows():
            vals = [None if c.value == "" else c.value for c in row]
            while vals and vals[-1] is None:
                vals.pop()
            rows.append(vals)
        while rows and not rows[-1]:
            rows.pop()
        out[ws.title] = rows
    return out


def main():
    wb = build()
    if "--check" in sys.argv:
        if not os.path.exists(OUT):
            print(f"FEHLT: {OUT} -- bitte python3 tools/build_spot.py ausfuehren")
            return 1
        if snapshot(load_workbook(OUT)) != snapshot(wb):
            print("VERALTET: docs/spot/CyberDrome_SPOT.xlsx passt nicht zu den Daten -- "
                  "bitte python3 tools/build_spot.py ausfuehren und einchecken")
            return 1
        print("SPOT-Tabelle ist aktuell.")
        return 0
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    wb.save(OUT)
    print(f"geschrieben: {os.path.relpath(OUT, ROOT)} ({len(wb.worksheets)} Blaetter)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
