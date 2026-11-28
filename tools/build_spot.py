#!/usr/bin/env python3
"""Baut die SPOT-Tabellen docs/spot/CyberDrome_SPOT_*.xlsx.

SPOT = Single Point of Truth fuer alle inhaltlichen Daten des Spiels in vier
fuer Menschen lesbaren Excel-Dateien (seit 19. Nov. 2026, vorher eine):

  CyberDrome_SPOT_Entscheidungen.xlsx  Eckpunkte, Fragen, offene Punkte, Glossar
  CyberDrome_SPOT_Balance.xlsx         Regeln, Level, DROMEs, Waffen, Sentinels ...
  CyberDrome_SPOT_Module.xlsx          Module, Rezepte, Rezept-Matrix, BIOS
  CyberDrome_SPOT_Welt.xlsx            Fraktionen, Story, Formationen, Maps, Design ...

Formeln zeigen nie in eine andere Datei: alles, was aufeinander rechnet
(Regeln, Waffen, Einsatz, Sentinels, Gegner-DROMEs), liegt in der Balance.
Die Aufteilung steht in FILES unten.

Gelesen wird ausschliesslich, was das Spiel Gelesen wird ausschliesslich, was das Spiel
selbst liest -- so kann die Tabelle nie vom Spiel abweichen:

  parts/*/*_south.json   DROMEs (Chassis, Kopf, Kern, Antrieb) und Waffen
  data/config.json       Regeln, Lauf, Level, Passiven-Zahlen
  data/modules.json      Grundmodule, Rezepte, BIOS, Laden
  data/regions.json      Stages / Gebiete und Fraktionsprofile
  data/encounters.json   Gegnertypen, Gegnerteams, Einheiten
  docs/spot/inhalte/*.json  Texte, die nicht in den Spieldaten stehen, je Thema:
                         entscheidungen (Eckpunkte, Fragen, offene Punkte, Glossar),
                         balance (Identitaeten, Rollen, Einsatz, Sentinels),
                         welt (Fraktionen, Story, Bosse, Lootcaches, Maps),
                         design (Design-Farben und Design-Tokens)

Daneben entsteht docs/design/tokens.json: die Design-Tokens (Farben aus
design_farben, alles andere aus design_tokens) fuer das Design-System
"CyberDrome Arcade-Glitch". Auch sie prueft --check.

Aufruf:
  python3 tools/build_spot.py           # Tabellen neu schreiben
  python3 tools/build_spot.py --check   # nur pruefen, ob sie aktuell sind (CI)

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
SPOT_DIR = os.path.join(ROOT, "docs", "spot")
TOKENS_OUT = os.path.join(ROOT, "docs", "design", "tokens.json")


def load(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return json.load(f)


CONFIG = load("data/config.json")
MODULES = load("data/modules.json")
REGIONS = load("data/regions.json")
FORMATIONS = load("data/formations.json")
TEXTE_DATEIEN = ["entscheidungen", "balance", "welt", "design"]


def load_texte():
    """Fuegt docs/spot/inhalte/*.json zu einem Woerterbuch zusammen."""
    out = {}
    for name in TEXTE_DATEIEN:
        for k, v in load(f"docs/spot/inhalte/{name}.json").items():
            if k.startswith("_"):
                continue
            if k in out:
                raise SystemExit(f"Schluessel {k} steht doppelt in docs/spot/inhalte/")
            out[k] = v
    return out


TEXTE = load_texte()

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
    "shield_pulse": "Schildpuls", "power": "Power", "efficiency": "Effizienz",
    "module_slots": "Modulplaetze",
}
CLASS_NAMES = {"light": "leicht", "medium": "mittel", "heavy": "schwer"}
CATEGORY_NAMES = {"weapon": "Waffe", "shield": "Schild", "support": "Support"}
TIER_NAMES = {"easy": "Leicht", "normal": "Normal", "elite": "Elite"}
MOD_CLASS = {"attack": "Angriff", "defense": "Verteidigung", "tactic": "Taktik"}
CONDITION = {"": "jede Waffe", "ranged": "nur Fernkampf (Rw ab 2)", "melee": "nur Nahkampf (Rw 1)"}
ROLE_NAMES = {r["id"]: r["name"] for r in TEXTE["rollen"]}
ROLE_RULE = {r["id"]: r["zielregel"] for r in TEXTE["rollen"]}
RULES = MODULES["rules"]
PASSIVES = CONFIG["passives"]


def pct(x):
    return f"{round(x * 100)} %"


def num(x):
    if isinstance(x, float) and x.is_integer():
        x = int(x)
    return str(x).replace(".", ",")


PASSIVE_INFO = {
    "cyberspeed": ("Cyberspeed", lambda p: f"Jeder {p['every']}. Angriff gibt einen Stapel (hoechstens {p['max_stacks']}), "
                   f"je Stapel +{pct(p['attack_speed'])} Angriffs- und Lauftempo; jeder Angriff haelt die Stapel {num(p['seconds'])} s."),
    "safe_haven": ("Safe Haven", lambda p: f"Heilung, Regeneration und Schildgaben am Molok +{pct(p['care_mult'] - 1)}."),
    "echo": ("Echo", lambda p: f"Jede Faehigkeit wirkt doppelt, dafuer ist ihr Takt {num(p['slower'])}-mal so lang (aufgerundet)."),
    "cleancode": ("Cleancode", lambda p: f"Wer vom Nimbus Heilung oder Schild bekommt, erhaelt einen Stapel Bug-Fix ({num(p['stack_seconds'])} s, "
                  f"hoechstens {p['max_stacks']}): je Stapel +{p['def']} Ruestung und +{p['shieldgate']} Shieldgate."),
    "focuslense": ("Focuslense", lambda p: f"+{pct(p['kinetic_mult'] - 1)} kinetischer und -{pct(1 - p['energy_mult'])} Energieschaden; "
                   f"traf der letzte Schuss dasselbe Ziel (anvisiert), +{pct(p['focus_mult'] - 1)}."),
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
        "power": lambda v: f"+{num(v)} Power",
        "hp_pct": lambda v: f"+{pct(v)} max. Integritaet",
        "shield_pct": lambda v: f"+{pct(v)} max. Schild",
        "efficiency": lambda v: f"+{num(v)} Effizienz",
        "support_power": lambda v: f"Heilung und Schildgabe +{pct(v)}",
        "lifesteal": lambda v: f"Treffer heilen {pct(v)} des Schadens",
        "virus_fraction": lambda v: f"{pct(v)} des Schadens als Virusschaden",
        "ricochet_chance": lambda v: f"{pct(v)} Chance auf Zusatztreffer",
        "ricochet_share": lambda v: f"Zusatztreffer mit {pct(v)} Schaden",
        "def": lambda v: f"+{num(v)} Ruestung",
        "thorns": lambda v: f"Stacheln: {num(v)} Schaden an jedem Angreifer",
        "thorns_melee": lambda v: f"+{num(v)} Stacheln gegen Nahkampf",
        "mark": lambda v: f"Faehigkeit markiert ihr Ziel {num(v)} s (+{pct(r['mark_damage_taken'])} Schaden von allen)",
        "kinetic_to_energy": lambda v: f"solange der Schild steht: {pct(v)} des kinetischen Schadens wird Energie",
        "takt_count": lambda v: f"jeder Angriff zaehlt {num(v)} fuer den Takt",
        "bonus_vs_marked": lambda v: f"+{pct(v)} Schaden gegen markierte Ziele",
        "armor_to_damage": lambda v: f"Angriffe +{pct(v)} der eigenen Ruestung als Schaden",
        "retaliation": lambda v: f"Vergeltung: jeder Treffer am Traeger laedt den naechsten Angriff um {pct(v)} auf (max. 3x, Nahkampf doppelt)",
        "shield_delay": lambda v: f"Schild laedt schon nach {num(v)} s Ruhe",
        "ability_armor_aura": lambda v: f"Faehigkeit gibt allen DROMEs in Rw {r['aura_range']} fuer {num(r['aura_seconds'])} s +{num(v)} Ruestung",
        "shackle": lambda v: f"Faehigkeit zieht bis zu {v} Gegner (Rw 3) neben den Traeger und betaeubt sie 1 s",
        "shield_break_burst": lambda v: f"bricht der Schild: {num(v)} Energieschaden an allen Gegnern in Rw {r['burst_range']}, "
                                        f"{num(r['burst_stun'])} s betaeubt (hoechstens alle {num(r['burst_cooldown'])} s)",
        "decoy": lambda v: f"Hologramm-Sprung: wer daneben stand, ist {num(v)} s vom Koeder abgelenkt",
        "mark_on_hit_taken": lambda v: "jeder Gegner, der den Traeger trifft, wird markiert",
        "ready_after_ability": lambda v: "nach der Faehigkeit sofort wieder geladen",
        "retaliation_max": lambda v: f"Vergeltung bis zu {v} Ladungen",
        "berserk": lambda v: "volle Vergeltung trifft dazu alle Gegner daneben",
        "mark_hunt": lambda v: "stirbt ein markierter Gegner, springt die Markierung weiter",
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
    "realtime.kite_distance": "Fernkaempfer weichen aus, wenn ein Gegner so nah ist",
    "combat.physical_vs_shield": "Kinetisch am Schild",
    "combat.energy_vs_shield": "Energie am Schild",
    "combat.armor_ehp_cap": "Ruestung: Obergrenze des Zuwachses an effektiver Integritaet",
    "combat.armor_ehp_k": "Ruestung: wie schnell die Obergrenze erreicht wird",
    "combat.shield_pulse.base_delay": "Schildpuls: Ruhezeit Grundwert (s)",
    "combat.shield_pulse.delay_per_point": "Schildpuls: Ruhezeit weniger je Punkt (s)",
    "combat.shield_pulse.min_delay": "Schildpuls: kleinste Ruhezeit (s)",
    "combat.shield_pulse.gain_per_point": "Schildpuls: Ladung je Punkt und Puls",
    "run.rounds": "Kaempfe je Lauf",
    "run.lives": "Leben je Lauf",
    "run.training_rounds": "Trainingsrunden am Anfang",
    "run.storage_size": "Plaetze im Lager",
    "run.loss_credits": "Credits bei einer Niederlage",
    "run.region": "Gebiet des Laufs",
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


def build_uebersicht(ws, datei):
    ws["A1"] = f"CyberDrome -- SPOT {datei['titel']}"
    ws["A1"].font = TITLE_FONT
    lines = [
        "Die SPOT (Single Point of Truth) besteht aus vier Dateien, diese ist eine davon. Sie wird NICHT von Hand",
        "bearbeitet, sondern von tools/build_spot.py aus genau den Dateien erzeugt, die das Spiel selbst liest.",
        "Aendern: Werte in parts/ (ueber tools/build_sample_parts.py) oder data/*.json, Texte in "
        f"docs/spot/inhalte/*.json (fuer diese Datei: {datei['texte']}),",
        "dann: python3 tools/build_spot.py  -- die CI prueft mit --check, dass alle vier aktuell sind.",
        "Texte aus den Spieldaten stehen so wie im Spiel (ohne Umlaute, z. B. 'Praesenz').",
        "Hellblaue Felder: hier traegst du Werte ein und gibst die Datei zurueck -- sie werden dann nach "
        "docs/spot/inhalte/ uebertragen.",
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
    ws.cell(row=r + 1, column=1, value="Blaetter in dieser Datei").font = SUB_FONT
    rows = [(name, text) for name, text, _ in datei["blaetter"]]
    last = write_table(ws, ["Blatt", "Inhalt"], rows, start_row=r + 2)
    ws.cell(row=last + 2, column=1, value="Die anderen SPOT-Dateien").font = SUB_FONT
    rows = [(f["datei"], ", ".join(n for n, _, _ in f["blaetter"])) for f in FILES if f is not datei]
    write_table(ws, ["Datei", "Blaetter"], rows, start_row=last + 3)
    ws.column_dimensions["A"].width = 36
    ws.column_dimensions["B"].width = 110


def build_eckpunkte(ws):
    rows = [(e["bereich"], e["thema"], e["festlegung"], e["seit"], e["status"], e["quelle"]) for e in TEXTE["eckpunkte"]]
    write_table(ws, ["Bereich", "Thema", "Festlegung", "Seit", "Status", "Quelle"], rows, [14, 24, 90, 13, 13, 30])


def build_dromes(ws):
    headers = ["Code", "DROME", "Set-Titel", "Rolle", "Zielregel", "Identitaet", "Beschreibung",
               "Speed", "Lauftempo (Felder/s)", "Integritaet", "Schild", "Integritaet + Schild",
               "Schildpuls", "Ruhezeit bis Schildladung (s)", "Schild je Puls", "Ruestung", "Power",
               "Effizienz", "Halter", "Modulplaetze je Halter", "Passive", "Passive: Wirkung", "Standardwaffe",
               "Level: Hauptwerte (+10 % je Level)",
               "Kopf", "Kern", "Antrieb", "Status"]
    rows = []
    lv = CONFIG["levels"]["drome"]
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
            s["def"], s["power"], s.get("efficiency", 10), slots_text(b), s["module_slots"],
            passive_name(s["passive"]), passive_text(s["passive"]), t.get("standardwaffe", ""),
            ", ".join(STAT_NAMES[k] for k in lv["main"].get(b["id"], [])),
            by_type.get("head", ""), by_type.get("core", ""), by_type.get("feet", ""), "gebaut",
        ])
    notes = {
        "Lauftempo (Felder/s)": "Formel: max(Untergrenze, Grundwert + Speed x je Punkt) -- Zahlen aus Blatt Regeln (realtime).",
        "Ruhezeit bis Schildladung (s)": "Formel aus Blatt Regeln (combat.shield_pulse).",
        "Power": "Rohschaden = Waffenschaden x Power / 10.",
        "Effizienz": "Dauer, Stapel und Stärke der Statuseffekte, die der DROME auslöst: x Effizienz / 10. Nie Schaden.",
    }
    write_table(ws, headers, rows, [9, 10, 26, 13, 30, 36, 40, 7, 10, 10, 8, 10, 9, 11, 8, 8, 7, 9, 20, 10,
                                    11, 46, 22, 22, 16, 16, 16, 10], notes=notes)


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
    write_table(ws, ["Amp", "ID", "Kuerzel", "Klasse", "Passt zu", "Wirkung", "Steckt in Fusionen",
                     "Preis (Credits)", "Verkauf (Credits)", "Status"], rows, [16, 18, 8, 13, 22, 60, 48, 9, 9, 10])


def build_rezepte(ws):
    rows = []
    for rid, r in MODULES["recipes"].items():
        rows.append([r["name"], rid, r["short"], MOD_CLASS.get(r["class"], r["class"]), CONDITION.get(r["condition"], r["condition"]),
                     module_name(r["from"][0]), module_name(r["from"][1]), effects_text(recipe_total(rid)),
                     effects_text(r["bonus"]), "ja: " + r["gadget"] if r.get("gadget") else "--",
                     MODULES["shop"]["price"]["recipe"], MODULES["sell_value"]["recipe"],
                     "entschieden" if rid in ("mod_mender", "mod_brawler") else "Vorschlag (gebaut)"])
    # Hyperfusionen (20. Nov. 2026): zwei gleiche Amps + Fusion Core, dreifacher Wert.
    for hid, h in MODULES.get("hyperfusions", {}).items():
        amp = MODULES["modules"][h["amp"]]
        triple = {k: v * 3 for k, v in amp["effects"].items()}
        rows.append([h["name"], hid, h["short"], MOD_CLASS.get(amp["class"], amp["class"]), "--",
                     module_name(h["amp"]), module_name(h["amp"]) + " + Fusion Core", effects_text(triple),
                     effects_text(h["bonus"]) if h["bonus"] else "offen", "--", "--",
                     MODULES["sell_value"]["recipe"] * 2, "entschieden" if h["bonus"] else "Wert gebaut, Effekt offen"])
    write_table(ws, ["Fusion / Hyperfusion", "ID", "Kuerzel", "Klasse", "Passt zu", "Zutat 1", "Zutat 2", "Wirkung der Zutaten (Summe)",
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
            f"Angebot: 1 aus {RULES['bios_offers']} fest nach den ersten {RULES['bios_elite_wins']} gewonnenen "
            f"Elite-Kaempfen (danach ein Lootcache), nie nach dem letzten Kampf; Chaos-Kaempfe mit "
            f"{round(CONFIG['run']['loot']['chaos']['bios'] * 100)} %. "
            f"Hoechstens ein BIOS-Rezept je DROME, kein Extra-Modulplatz.").font = BODY_FONT


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
                     len(FORMATIONS["formations"].get(reg["id"], [])) if reg else 0,
                     f["chassis_vorschlag"], f["boss"], f["status"]])
    notes = {"Chassis-Gewichte (Chaos)": "Gewicht je Chassis beim Wuerfeln (nur Chaos-Kampf / Generator).",
             "Haltung zum Virus": "Aus VORSCHLAG_STORY 1 -- noch nicht entschieden."}
    write_table(ws, ["Fraktion", "Gebiet", "Profil", "Spielstil", "Haltung zum Virus", "Chassis-Gewichte (Chaos)",
                     "Bevorzugte Waffen", "Bevorzugte Module", "Bevorzugte Rezepte", "Formationen", "Eigener DROME (Vorschlag)",
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


RANK_NAMES = {"basic": "Basic", "elite": "Elite", "heavy": "Heavy", "heavy_elite": "Heavy Elite"}
ARCHE_NAMES = {"assault": "Assault", "sniper": "Sniper", "support": "Support"}


def unit_name(uid):
    """Name einer Einheit aus formations.json (Sentinel-Id oder DROME-Id, mit :rang)."""
    base, _, rank = uid.partition(":")
    if base in FORMATIONS["sentinels"]:
        name = FORMATIONS["sentinels"][base]["name"]
        return name.replace("Sentinel", RANK_NAMES.get(rank, "")).strip() if rank and rank != "basic" else name
    return FORMATIONS["dromes"].get(base, {}).get("name", base)


def build_einheiten(ws):
    uses = {}
    for region, forms in FORMATIONS["formations"].items():
        for f in forms:
            for step in f["steps"]:
                for uid in step["dromes"] + step["sentinels"]:
                    base = uid.split(":")[0]
                    uses.setdefault(base, [])
                    if f["name"] not in uses[base]:
                        uses[base].append(f["name"])
    rows = []
    for did, d in FORMATIONS["dromes"].items():
        rows.append([d["name"], "DROME", drome_name(d["chassis"]), " + ".join(part_name(w) for w in d["weapons"]),
                     "feste Werte" if d.get("stats") else "Standard-DROME", ", ".join(uses.get(did, [])) or "--",
                     "gebaut"])
    for sid, d in FORMATIONS["sentinels"].items():
        rows.append([d["name"], "Sentinel " + ARCHE_NAMES.get(d["archetype"], d["archetype"]),
                     drome_name(d["look"]) + " (60 %)", part_name(d["weapon"]), "feste Werte, nur Auto-Angriff",
                     ", ".join(uses.get(sid, [])) or "--", "gebaut"])
    for b in TEXTE["bosse"]:
        rows.append([b["name"] + " (Boss)", "Boss", b["drome"].split(" ")[0], b["drome"], "--", "--", b["status"]])
    write_table(ws, ["Einheit", "Art", "Aussehen", "Waffen", "Werte", "Formationen", "Status"], rows,
                [24, 18, 18, 36, 26, 50, 10])


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
    # Spalte Englisch (19. Nov. 2026): Vorschlaege fuer die englische Fassung.
    rows = [[g["begriff"], g.get("englisch", ""), g["erklaerung"]] for g in TEXTE["glossar"]]
    write_table(ws, ["Begriff", "Englisch (Vorschlag)", "Erklaerung"], rows, [20, 22, 100])


# ---------------------------------------------------------------------------
# Neues Spielprinzip (12./13. Nov. 2026, docs/GEGNERDESIGN.md) -- noch nicht
# gebaut. Daten aus docs/spot/inhalte/, hellblaue Spalten fuellt der Spieler.
# ---------------------------------------------------------------------------

VIRUS = {}  # id -> Zelle auf "Einsatz" (fuer Formeln)
ART_NAMES = ["Waffe", "DROME", "Modul", "BIOS", "Fraktionskern", "Credits", "Platzhaltercoin"]


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
    built = {"start": CONFIG["virus"]["start_seconds"], "anteil": CONFIG["virus"]["pct_of_max"],
             "puls": CONFIG["realtime"]["pulse"]}
    for v in TEXTE["virusschaden"]:
        VIRUS[v["id"]] = f"Einsatz!$C${len(rows) + 2}"
        rows.append(["Virusschaden", v["parameter"], built.get(v["id"], v["wert"]), "gebaut", v["notiz"]])
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
        rows.append([l["wann"], l["art"], l["chance"], l["anzahl"], f"=C{i}*D{i}", l["coins"], "gebaut"])
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


def build_fabrik(ws):
    fab = load("data/factory.json")
    waren = fab["waren"]
    wn = lambda w: waren.get(w, {}).get("name", w)
    amt = lambda d: " + ".join(f"{n} {wn(w)}" for w, n in d.items())
    rows = []
    for gid, g in fab["gebaeude"].items():
        rows.append([g["name"], g["kurz"], g["tier"], g.get("gruppe", ""),
                     fab["quellen_arten"].get(g.get("quelle", ""), {}).get("name", ""),
                     amt(g.get("ein", {})), amt(g.get("aus", {})), g.get("rate"), g.get("strom", 0),
                     g.get("liefert"), g.get("reichweite"), amt(g.get("preis", {})), g.get("start", 0),
                     g.get("text", "")])
    last = write_table(ws, ["Gebäude", "Kürzel", "Tier", "Gruppe", "Quelle", "Eingang", "Ausgang",
                            "Durchläufe je Takt", "Strom (Bedarf)", "Strom (liefert)", "Reichweite", "Preis",
                            "Startbestand", "Hinweis"], rows,
                       [16, 8, 6, 13, 14, 22, 24, 10, 9, 9, 9, 30, 9, 50])
    r = last + 3
    ws.cell(row=r, column=1, value="Takte und Regeln").font = SUB_FONT
    rows = [[k, v] for k, v in fab["takte"].items()]
    rows.append(["netz_strom", fab["netz"]["strom"]])
    rows.append(["netz_reichweite", fab["netz"]["reichweite"]])
    last = write_table(ws, ["Wert", "Zahl"], rows, start_row=r + 1)
    r = last + 3
    ws.cell(row=r, column=1, value="Feldgruppen").font = SUB_FONT
    rows = [[c["name"], len(c["felder"]), amt(c["preis"]), c["tier"]] for c in fab["feldgruppen"]]
    last = write_table(ws, ["Feldgruppe", "Felder", "Preis", "ab Tier"], rows, start_row=r + 1)
    r = last + 3
    ws.cell(row=r, column=1, value="Tiers").font = SUB_FONT
    rows = [[t["tier"], "Fabrik-Ziel" if t["weg"] == "fabrik" else "Story", amt(t["kosten"]), t["text"]]
            for t in fab["tiers"]]
    last = write_table(ws, ["Tier", "Freischalten über", "Kosten", "Bringt"], rows, start_row=r + 1)
    r = last + 3
    ws.cell(row=r, column=1, value="Werkbank: DROME-Teile (Spieler 24. Nov. 2026)").font = SUB_FONT
    rows = []
    for chassis, parts in fab["werkbank"]["dromes"].items():
        for part in parts:
            rows.append([chassis, part["name"], part["id"], part.get("anzahl", 1), amt(part["kosten"])])
    last = write_table(ws, ["Chassis", "Teil", "Platz", "Anzahl", "Kosten je Stück"], rows, start_row=r + 1)
    r = last + 3
    ws.cell(row=r, column=1, value="Spezialteile (Fraktions-DROMEs, Spieler 24. Nov. 2026)").font = SUB_FONT
    rows = [[v, n, "Fraktionskern + Zutaten des Kern-Teils"] for v, n in fab["werkbank"]["spezialteile"].items()
            if not v.startswith("_")]
    last = write_table(ws, ["Fraktions-DROME", "Spezialteil", "Kosten"], rows, start_row=r + 1)
    r = last + 3
    ws.cell(row=r, column=1, value="Verwerten").font = SUB_FONT
    v = fab["werkbank"]["verwerten"]
    rows = [["Teile, deren Zutaten zurückkommen", v["teile"]]] + [[f"Wert je {wn(w)}", n] for w, n in v["wert"].items()]
    last = write_table(ws, ["Regel", "Zahl"], rows, start_row=r + 1)
    r = last + 3
    ws.cell(row=r, column=1, value="Level-Kosten (Spieler 24. Nov. 2026, steil; Level 5 mit Keynode-Chip)").font = SUB_FONT
    lv = fab["level"]
    rows = []
    for group, key in (("DROME", "drome"), ("Waffe", "waffe")):
        for who, steps in lv[key].items():
            rows.append([group, who] + [amt(c) for c in steps])
    last = write_table(ws, ["Art", "Chassis / Klasse", "Level 1", "Level 2", "Level 3", "Level 4", "Level 5"], rows,
                       start_row=r + 1)
    r = last + 3
    ws.cell(row=r, column=1, value="Keynode-Chip (Raten vorläufig)").font = SUB_FONT
    rows = [["Erster gewonnener Einsatz", "garantiert" if lv["keynode"]["erster_einsatz"] else "nein"],
            ["Jeder weitere gewonnene Einsatz", f'{int(lv["keynode"]["einsatz_chance"] * 100)} %'],
            ["Je Cache-Wurf", "5 % (config.json -> charger.cache.table)"]]
    last = write_table(ws, ["Quelle", "Chance"], rows, start_row=r + 1)
    r = last + 3
    ws.cell(row=r, column=1, value="Aus dem Lager herstellen").font = SUB_FONT
    rows = [[wn(w), amt(h["kosten"]), h.get("text", "")] for w, h in fab["herstellen"].items()]
    write_table(ws, ["Ergebnis", "Kosten", "Hinweis"], rows, start_row=r + 1)


def build_sentinels(ws):
    weapons = [w["name"] for w in WEAPONS]
    headers = ["Sentinel", "Fraktion", "Archetyp", "Waffe", "Gewichtsklasse", "Speed", "Lauftempo (Felder/s)",
               "Integritaet", "Schild", "Integritaet + Schild", "Schildpuls", "Ruestung", "Power", "Modulplaetze",
               "Schaden/s roh (Waffe x Power)", "Virusschaden je Puls", "Module Elite / Heavy Elite", "Status"]
    rows = []
    # Seit 14. Nov. 2026 aus data/formations.json (gebaut), nicht mehr aus inhalte/.
    for i, (sid, s) in enumerate(FORMATIONS["sentinels"].items(), 2):
        st = s["stats"]
        rows.append([s["name"], s["faction"], ARCHE_NAMES.get(s["archetype"], s["archetype"]), part_name(s["weapon"]),
                     f'=IFERROR(INDEX(Waffen!$D:$D,MATCH(D{i},Waffen!$B:$B,0)),"--")', st["spd"],
                     f"=ROUND(MAX({REG['realtime.move_min']},{REG['realtime.move_base']}+F{i}*{REG['realtime.move_per_spd']}),2)",
                     st["hp_max"], st["shield"], f"=H{i}+I{i}", st["shield_pulse"], st["def"], st["power"],
                     st["module_slots"], f"=ROUND({weapon_dps(f'D{i}', f'M{i}')},1)",
                     f"=ROUND(J{i}*{VIRUS['anteil']},1)",
                     ", ".join(module_name(m) for m in s.get("elite_modules", [])), "gebaut"])
    notes = {"Power": "Eigene, schwächere Power-Wertung: Rohschaden = Waffenschaden x Power / 10 (DROMEs 6-15).",
             "Waffe": "Echte Waffe aus dem Blatt Waffen -- ein Waffenslot.",
             "Schaden/s roh (Waffe x Power)": "Schaden/s roh der Waffe (Blatt Waffen) x Power / 10, ohne Fähigkeit.",
             "Virusschaden je Puls": "Ab Minute 5: Anteil (Blatt Einsatz) x (Integritaet + Schild).",
             "Module Elite / Heavy Elite": "Vorschlag: Elite traegt das erste, Heavy Elite beide (nur wenn sie zur Waffe passen)."}
    inputs = ("Fraktion", "Archetyp", "Waffe", "Speed", "Integritaet", "Schild", "Schildpuls", "Ruestung", "Power",
              "Modulplaetze")
    last = write_table(ws, headers, rows, [24, 10, 10, 20, 12, 7, 10, 10, 8, 10, 9, 8, 7, 10, 12, 11, 30, 11],
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
    texts = {v["variante"]: v for v in TEXTE["sentinel_varianten"]}
    rows = [[r["name"], r["hp"], r["shield"], r["power"], r["def"], r["spd"], r["modules"],
             texts.get(r["name"], {}).get("herausforderung", ""), "gebaut"] for r in FORMATIONS["ranks"].values()]
    rows.append(["Specialist", "--", "--", "--", "--", "--", "--", "fällt weg (Blatt Fragen 5)", "fällt weg"])
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
               "Effizienz", "Schaden/s roh (Waffen x Power)", "Virusschaden je Puls", "Aufgabe in der Squad", "Status"]
    rows = []
    tasks = {g["name"]: g.get("aufgabe", "") for g in TEXTE["gegner_dromes"]}
    fixed = [(k, d) for k, d in FORMATIONS["dromes"].items() if d.get("stats")]
    for i, (gid, d) in enumerate(fixed, 2):
        st = d["stats"]
        g = {"name": d["name"], "fraktion": d["name"].split(" ")[0], "chassis": d["chassis"],
             "speed": st["spd"], "integritaet": st["hp_max"], "schild": st["shield"],
             "schildpuls": st["shield_pulse"], "ruestung": st["def"], "power": st["power"],
             "modulplaetze": st["module_slots"],
             "effizienz": st.get("efficiency", PARTS[d["chassis"]]["stats"].get("efficiency", 10)), "aufgabe": tasks.get(d["name"], ""), "status": "gebaut"}
        w = [part_name(x) for x in d["weapons"]] + [""]
        role = PARTS[g["chassis"]]["stats"]["ai_role"]
        rows.append([g["name"], g["fraktion"], drome_name(g["chassis"]), ROLE_NAMES.get(role, role), w[0], w[1],
                     g["speed"],
                     f"=ROUND(MAX({REG['realtime.move_min']},{REG['realtime.move_base']}+G{i}*{REG['realtime.move_per_spd']}),2)",
                     g["integritaet"], g["schild"], f"=I{i}+J{i}", g["schildpuls"], g["ruestung"], g["power"],
                     g["modulplaetze"], g["effizienz"], f"=ROUND({weapon_dps(f'E{i}', f'N{i}')}+{weapon_dps(f'F{i}', f'N{i}')},1)",
                     f"=ROUND(K{i}*{VIRUS['anteil']},1)", g["aufgabe"], g["status"]])
    notes = {"Speed": "Startwerte = Werte des Chassis (Blatt DROMEs) -- hier frei ausbalancieren.",
             "Waffe 2": "Nur Molok hat zwei Halter.",
             "Effizienz": "Dauer, Stapel und Stärke der Statuseffekte (10 = 100 %). Ohne eigenen Wert der des Chassis.",
             "Schaden/s roh (Waffen x Power)": "Summe Schaden/s roh beider Waffen (Blatt Waffen) x Power / 10."}
    inputs = ("Gegner-DROME", "Fraktion", "Chassis", "Waffe 1", "Waffe 2", "Speed", "Integritaet", "Schild",
              "Schildpuls", "Ruestung", "Power", "Modulplaetze", "Effizienz", "Aufgabe in der Squad")
    last = write_table(ws, headers, rows, [16, 10, 10, 13, 18, 18, 7, 10, 10, 8, 10, 9, 8, 7, 10, 9, 12, 11, 46, 11],
                       notes=notes, inputs=inputs)
    add_list(ws, weapons, f"E2:F{last + 10}")
    add_list(ws, [drome_name(b["id"]) for b in BODIES], f"C2:C{last + 10}")
    add_list(ws, [f["kurz"] for f in TEXTE["fraktionen"]], f"B2:B{last + 10}")
    ws.cell(row=last + 2, column=1, value="Der gegnerische DROME ist der taktische Mittelpunkt: eigene Waffe und "
            "Passive, aktive Bedrohung, prägt die Spielweise der Squad. Ob besiegte DROMEs freigeschaltet "
            "werden, ist bewusst offen. Standard-DROMEs in Formationen (Vireo, Molok, Nimbus, Strix) "
            "rechnen mit den Werten des Chassis (Blatt DROMEs) und dem Gegner-Level (Blatt Lauf). "
            "Module der Gegner-DROMEs würfelt der Seed: je 2 Reinforcement-Level eines, ab zwei wird ein "
            "Paar zu einem passenden Rezept.").font = BODY_FONT


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
        "Heute gebaut (18. Nov. 2026): Hexfeld, je Formation eine Karte (Blatt Formationen, Spalte Karte; config.json -> maps), keine zufälligen Hindernisse. Die Vorlagen sind 24 x 24.",
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
    regions = {r["id"]: r["name"] for r in REGIONS["regions"]}
    maps = CONFIG.get("maps", {})

    def map_text(key):
        spec = maps.get(key or maps.get("default", ""), {})
        if not isinstance(spec, dict):
            return ""
        return f'{spec.get("name", key)} ({spec.get("width")} x {spec.get("height")})'

    for i, (region, forms) in enumerate(FORMATIONS["formations"].items()):
        for f in forms:
            for n, step in enumerate(f["steps"]):
                sentinels = step["sentinels"]
                count = {a: sum(1 for x in sentinels if FORMATIONS["sentinels"][x.split(":")[0]]["archetype"] == a)
                         for a in ARCHE_NAMES}
                ranks = sorted({RANK_NAMES.get(x.split(":")[1], "") for x in sentinels if ":" in x})
                rows.append([f["name"] if n == 0 else "", regions.get(region, region), step["from"],
                             " + ".join(unit_name(d) for d in step["dromes"]),
                             count["assault"], count["sniper"], count["support"], len(sentinels),
                             len(sentinels) + len(step["dromes"]), ", ".join(ranks) or "Basic",
                             ", ".join(unit_name(x) for x in sentinels),
                             (f["idea"] + (" (Einführung)" if f.get("intro") else "")) if n == 0 else "",
                             map_text(f.get("map", "")) if n == 0 else "",
                             "Vorschlag gebaut"])
    notes = {"ab Level": "Reinforcement-Level, ab dem diese Stufe gilt (steigt nach jedem Kampf, nach Elite schneller).",
             "Einheiten gesamt": "Sentinels + DROMEs. Der Spieler hat bis zu 4 DROMEs.",
             "Karte": "Die Karte der Formation (config.json -> maps, 18. Nov. 2026): sie stützt den Grundgedanken."}
    last = write_table(ws, ["Formation", "Gebiet", "ab Level", "DROMEs", "Assault", "Sniper", "Support",
                            "Sentinels gesamt", "Einheiten gesamt", "Ränge", "Sentinels", "Grundgedanke", "Karte",
                            "Status"],
                       rows, [20, 12, 8, 30, 8, 8, 8, 10, 10, 18, 70, 60, 22, 14], notes=notes)
    r = last + 2
    ws.cell(row=r, column=1, value="Varianten: Leicht, Normal, Elite aus derselben Formation").font = SUB_FONT
    v = FORMATIONS["variants"]
    rows = [[TIER_NAMES[k], v[k].get("level_offset", 0), "ja" if v[k].get("basic_only") else "nein",
             v[k].get("drop_sentinels", 0), v[k].get("promote", 0), v[k].get("drome_modules", 0)] for k in v]
    last = write_table(ws, ["Variante", "Level +", "nur Basic", "Sentinels weniger", "Sentinels einen Rang höher",
                            "Module der DROMEs +"], rows, start_row=r + 1)
    rc = FORMATIONS["reinforcement"]
    ws.cell(row=last + 2, column=1, value=f"Reinforcement-Level = Kampf + {rc['elite_bonus']} je gewähltem Elite; "
            f"Infinity-Einsatz {rc['endless_rate']} je Kampf. Gegner-DROMEs: ein Modul je {rc['drome_modules_per']} "
            "Level. Name und Zusammensetzung zeigen schon vor dem Kampf, welche Herausforderung wartet. "
            "Quelle: data/formations.json.").font = BODY_FONT


def color_value(f):
    """Wert eines Farb-Tokens: Verweis ({token}), rgba() mit Deckkraft oder Hex."""
    if f.get("alias"):
        return "{%s}" % f["alias"]
    if "alpha" in f:
        h = f["hex"].lstrip("#")
        return "rgba(%d, %d, %d, %s)" % (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), f["alpha"])
    return f["hex"]


def design_tokens():
    """Die Design-Tokens fuer das Design-System (docs/design/tokens.json)."""
    t = TEXTE["design_tokens"]
    out = {"name": t["name"], "version": 1,
           "meta": {"source": "SPOT", "paths": {"tokens": ["docs/spot/inhalte/design.json"]},
                    "note": "Erzeugt von tools/build_spot.py -- nicht von Hand bearbeiten."},
           "color": {"themes": t["themes"],
                     "tokens": [{"name": f["token"], "value": color_value(f), "usage": f["verwendung"]}
                                for f in TEXTE["design_farben"]]}}
    for key, val in t.items():
        if key not in ("_kommentar", "name", "themes"):
            out[key] = val
    return json.dumps(out, ensure_ascii=False, indent=1) + "\n"


def build_design(ws):
    rows = [[f["name"], f["token"], f["hex"] + (" %d %%" % round(f["alpha"] * 100) if "alpha" in f else ""), "",
             f["verwendung"] + (" (= %s)" % f["alias"] if f.get("alias") else ""), "entschieden"]
            for f in TEXTE["design_farben"]]
    last = write_table(ws, ["Farbe", "Token", "Hex", "Muster", "Verwendung", "Status"], rows, [20, 16, 11, 9, 80, 12])
    for i, f in enumerate(TEXTE["design_farben"], 2):
        ws.cell(row=i, column=4).fill = PatternFill("solid", fgColor=f["hex"].lstrip("#").upper())
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
    ws.cell(row=last + 3, column=1, value="Design-Tokens: docs/design/tokens.json (aus dieser Tabelle erzeugt) -- "
            "Quelle des Design-Systems CyberDrome Arcade-Glitch.").font = BODY_FONT


# Die vier SPOT-Dateien. Formeln zeigen nur innerhalb einer Datei: Sentinels,
# Gegner-DROMEs und DROMEs rechnen mit Regeln, Waffen und Einsatz -- alle in der Balance.
FILES = [
    {"id": "entscheidungen", "titel": "Entscheidungen", "datei": "CyberDrome_SPOT_Entscheidungen.xlsx", "texte": "entscheidungen.json", "blaetter": [
        ("Eckpunkte", "Alle festgehaltenen Entscheidungen mit Datum und Status", build_eckpunkte),
        ("Fragen", "Beantwortet (14. Nov.): Detailfragen fuer die Schritte 1-3 -- umgesetzt am 14. Nov.", build_fragen),
        ("Offene Punkte", "Was noch entschieden werden muss", build_offen),
        ("Glossar", "Begriffe", build_glossar),
    ]},
    {"id": "balance", "titel": "Kampf-Balance", "datei": "CyberDrome_SPOT_Balance.xlsx", "texte": "balance.json", "blaetter": [
        ("Regeln", "Alle Stellschrauben aus config.json und modules.json", build_regeln),
        ("Level", "Level von DROMEs und Waffen", build_level),
        ("Rollen", "KI-Rollen und Zielregeln", build_rollen),
        ("DROMEs", "Die DROMEs: Rolle, Identitaet, Werte, Passive, Level, BIOS, Bauteile", build_dromes),
        ("Teile", "Alle Bauteile mit Code", build_teile),
        ("Waffen", "Alle Waffen: Angriff, Faehigkeit, Takt, Bonus-Wert (Passive), Besonderheit", build_waffen),
        ("Passiven", "Alle Passiven: DROMEs, Waffen-Bonus, Chassis-BIOS, Fraktions-Vorschlaege", build_passiven),
        ("Sentinels", "GEBAUT (14. Nov.): Gegner-Bots je Fraktion und Archetyp, Raenge -- aus data/formations.json", build_sentinels),
        ("Gegner-DROMEs", "GEBAUT (14. Nov.): die DROMEs der Gegner-Squads -- aus data/formations.json", build_gegner_dromes),
        ("Einsatz", "GEBAUT (14. Nov.): Einsatz, Virusschaden, Kampfkarte, wann ein Lootcache droppt", build_einsatz),
    ]},
    {"id": "module", "titel": "Module", "datei": "CyberDrome_SPOT_Module.xlsx", "texte": "keine, alles aus data/modules.json", "blaetter": [
        ("Module", "Die 9 Grundmodule", build_module),
        ("Rezepte", "Die Rezepte aus je zwei Grundmodulen", build_rezepte),
        ("Rezept-Matrix", "Welche zwei Grundmodule welches Rezept ergeben", build_matrix),
        ("BIOS", "Matrix-BIOS: Rezept-Upgrades", build_bios),
    ]},
    {"id": "welt", "titel": "Welt & Fortschritt", "datei": "CyberDrome_SPOT_Welt.xlsx", "texte": "welt.json, Design: design.json", "blaetter": [
        ("Fraktionen", "Fraktionen, Profile, Besonderheiten, Vorschlaege", build_fraktionen),
        ("Stages", "Gebiete / Stages mit Fraktion und Boden", build_stages),
        ("Story", "Aufhaenger, Story-Level, Bosse (Vorschlaege)", build_story),
        ("Einheiten", "Gebaut: alle Gegner-Einheiten (DROMEs und Sentinels) und in welchen Formationen sie auftreten", build_einheiten),
        ("Formationen", "GEBAUT (14. Nov., Vorschlag Neon): Formationen je Reinforcement-Level, Varianten", build_formationen),
        ("Maps", "OFFEN: Arenen zeichnen -- Frontline, Mittellinie, Backline, Umrisse (quadratische Zellen)", build_maps),
        ("Lauf", "Heute gebaut: der Lauf Runde fuer Runde, Stufen und Beute -- abgeloest durch Einsatz", build_lauf),
        ("Lootcaches", "TEILS GEBAUT: Caches droppen und landen im Hangar; Inhalt und Oeffnen folgen", build_lootcaches),
        ("Hangar-Shop", "NEU (nicht gebaut): Upgrades und Caches fuer Platzhaltercoin", build_hangar),
        ("Fabrik", "GEBAUT (23. Nov. 2026): Platine, Gebaeude, Strom, Tiers -- aus data/factory.json", build_fabrik),
        ("Design", "GEBAUT (14. Nov.): Arcade-Glitch-Stil auf allen Bildschirmen -- Farben, Schriften, Formen", build_design),
    ]},
]


def build():
    """Baut alle vier Dateien; liefert [(Dateiinfo, Workbook)]."""
    books = []
    sheets = {}
    for datei in FILES:
        wb = Workbook()
        wb.remove(wb.active)
        sheets[("Uebersicht", datei["id"])] = sheet(wb, "Uebersicht")
        for name, _, _ in datei["blaetter"]:
            sheets[name] = sheet(wb, name)
        wb.calculation.fullCalcOnLoad = True
        books.append((datei, wb))
    # Regeln und Einsatz zuerst fuellen: die Formeln der anderen Blaetter zeigen darauf.
    build_regeln(sheets["Regeln"])
    build_einsatz(sheets["Einsatz"])
    for datei, _ in books:
        build_uebersicht(sheets[("Uebersicht", datei["id"])], datei)
        for name, _, fn in datei["blaetter"]:
            if fn not in (build_regeln, build_einsatz):
                fn(sheets[name])
    return books


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
    books = build()
    if "--check" in sys.argv:
        ok = True
        for datei, wb in books:
            path = os.path.join(SPOT_DIR, datei["datei"])
            if not os.path.exists(path):
                print(f"FEHLT: docs/spot/{datei['datei']} -- bitte python3 tools/build_spot.py ausfuehren")
                ok = False
            elif snapshot(load_workbook(path)) != snapshot(wb):
                print(f"VERALTET: docs/spot/{datei['datei']} passt nicht zu den Daten -- "
                      "bitte python3 tools/build_spot.py ausfuehren und einchecken")
                ok = False
        current = open(TOKENS_OUT, encoding="utf-8").read() if os.path.exists(TOKENS_OUT) else ""
        if current != design_tokens():
            print("VERALTET: docs/design/tokens.json passt nicht zu docs/spot/inhalte/design.json -- "
                  "bitte python3 tools/build_spot.py ausfuehren und einchecken")
            ok = False
        if not ok:
            return 1
        print("SPOT-Tabellen und Design-Tokens sind aktuell.")
        return 0
    os.makedirs(SPOT_DIR, exist_ok=True)
    for datei, wb in books:
        wb.save(os.path.join(SPOT_DIR, datei["datei"]))
        print(f"geschrieben: docs/spot/{datei['datei']} ({len(wb.worksheets)} Blaetter)")
    with open(TOKENS_OUT, "w", encoding="utf-8") as f:
        f.write(design_tokens())
    return 0


if __name__ == "__main__":
    sys.exit(main())
