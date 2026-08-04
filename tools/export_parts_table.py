#!/usr/bin/env python3
"""
export_parts_table.py -- Teile-Uebersicht als Excel-Mappe.

    python3 tools/export_parts_table.py [ziel.xlsx]

Erzeugt aus dem Inhalt von ``parts/`` eine lesbare Arbeitsmappe fuers Game
Design: welche Teile es gibt, was sie an welchen Slot laesst, und wo die
Spielwerte hingehoeren.

Warum als Skript und nicht als gepflegte Datei
----------------------------------------------
Eine von Hand gefuehrte Teileliste laeuft nach dem dritten Set auseinander --
dasselbe Argument, aus dem der Generator die Silhouetten und die Slot-Matrix
selbst ausrechnet, statt sie irgendwo abzuschreiben. Alles, was hier als
FAKT ausgewiesen ist, kommt direkt aus den Teil-JSONs.

Was das Skript NICHT kann
-------------------------
Spielwerte erfinden. HP, Schaden, Reichweite und Bewegung sind im Projekt noch
nicht entschieden (siehe ``docs/GAME_DESIGN.md``, Abschnitt 7: das Kampfsystem
ist offen). Das Blatt "Werte" ist deshalb ein vorbereitetes, leeres Formular --
gelbe Zellen sind zum Ausfuellen da. Sobald dort Zahlen stehen, gehoeren sie in
eine Datei im Repo und nicht nur in diese Mappe; bis dahin ist die Mappe der
Ort, an dem sie entstehen duerfen.
"""

from __future__ import annotations

import json
import pathlib
import sys

from openpyxl import Workbook
from openpyxl.comments import Comment
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import build_sample_parts as gen  # noqa: E402  -- fuer den Silhouetten-Abstand

ROOT = pathlib.Path(__file__).resolve().parent.parent
PARTS_DIR = ROOT / "parts"

FONT = "Arial"
HEAD_FILL = PatternFill("solid", fgColor="1F3B4D")
SUB_FILL = PatternFill("solid", fgColor="DCE6F1")
FILL_ME = PatternFill("solid", fgColor="FFFF99")     # bitte ausfuellen
HELPER_FILL = PatternFill("solid", fgColor="F2F2F2")
HEAD_FONT = Font(name=FONT, bold=True, color="FFFFFF", size=11)
SUB_FONT = Font(name=FONT, bold=True, size=10)
BODY_FONT = Font(name=FONT, size=10)
NOTE_FONT = Font(name=FONT, size=9, italic=True, color="666666")
INPUT_FONT = Font(name=FONT, size=10, color="0000FF")
THIN = Side(style="thin", color="B0B0B0")
BOX = Border(left=THIN, right=THIN, top=THIN, bottom=THIN)

TYPE_LABEL = {"core": "Kern", "head": "Kopf", "body": "Koerper",
              "feet": "Fuesse", "equipment": "Ausruestung"}
TYPE_ORDER = ["body", "head", "feet", "core", "equipment"]
CLASS_LABEL = {"light": "leicht", "medium": "mittel", "heavy": "schwer"}
CATEGORY_LABEL = {"weapon": "Waffe", "shield": "Schild", "support": "Support"}

# Rolle des Bauteiltyps im Spiel -- aus docs/GAME_DESIGN.md, Abschnitt 3.
TYPE_ROLE = {
    "core": "Identitaet der Einheit: Energie, Fertigkeitspool, Grundwerte",
    "head": "Sensorik: Sicht, Trefferchance, Statusresistenz",
    "body": "Chassis: HP, Panzerung -- bestimmt Zahl und Art der Ausruestungsslots",
    "feet": "Bewegungsreichweite, Gelaendeverhalten, Ausweichen",
    "equipment": "Waffen, Schilde, Support-Module",
}

# Welche Spielwerte ein Bauteiltyp bekommt. Leitet sich aus TYPE_ROLE ab und
# ist der Vorschlag fuers Formular -- keine beschlossene Werteliste.
TYPE_STATS = {
    "body": ["HP", "Panzerung", "Gewichtsklasse"],
    "head": ["Sichtweite", "Trefferchance %", "Statusresistenz"],
    "feet": ["Bewegung", "Ausweichen %", "Gelaende"],
    "core": ["Energie", "Fertigkeitsplaetze", "Grundwert-Bonus"],
    "equipment": ["Schaden", "Reichweite", "AP-Kosten"],
}

# Silhouetten-Merkmal und was es dem Spieler sagen soll.
# Spiegelt parts/README.md, Abschnitt 6a -- dort steht die Regel, hier nur die
# Kurzfassung je Teil, damit die Mappe ohne das Dokument lesbar bleibt.
READING = {
    "CHS-001": ("schlank, kantig, zweibeinig", "leichter Standardrahmen, zwei Arme"),
    "CHS-002": ("geduckt: Panzerschuerze, Keil-Torso, Pauldrons ueber dem "
                "Kopfsockel, Auspuffstapel",
                "schwerer Rahmen, drei Anker -- Schulter nur fuer Support"),
    "CHS-003": ("rund, Fahrgestell statt Beinen", "Support-Rahmen, weiche Formensprache"),
    "CHS-004": ("schmal und hoch, Gegengewichts-Ausleger ueber dem Kopf",
                "Ein-Slot-Rahmen, Scharfschuetze"),
    "HED-001": ("kleiner Helm mit Visierband und Antenne", "Aufklaerung"),
    "HED-002": ("wuchtiger Bunkerkopf mit Seitensensoren", "gepanzert, robust"),
    "HED-003": ("flacher Helm mit weit auskragender Krempe", "Rundumsicht, arkan"),
    "HED-004": ("ein langes Okular statt Visierband, Rueckenfinne",
                "sieht WEIT statt viel"),
    "LEG-001": ("schmaler Stand, gerade Stelzen, eine Zehe", "schnell"),
    "LEG-002": ("breiter Stand auf Auslegern, Hydraulikzylinder, Ferse",
                "langsam, standfest, stuetzt Rueckstoss ab"),
    "LEG-003": ("zwei grosse Raeder auf einer Achse", "rollend, schnell auf Ebene"),
    "LEG-004": ("Knick nach hinten, digitigrad", "federnd, mittlere Reichweite"),
    "COR-001": ("Scheibe mit vier Energiestrichen", "Impuls"),
    "COR-002": ("grosse Scheibe mit Kreuzglut", "Fusion, hohe Leistung"),
    "COR-003": ("Orb mit umlaufenden Ringen", "arkan"),
    "COR-004": ("senkrechter Leuchtspalt statt Scheibe", "Zielrechner, Optik"),
    "EQP-001": ("ein glattes Rohr, sonst nichts", "leicht, kurze Reichweite"),
    "EQP-002": ("flache Wand quer zur Blickrichtung", "Deckung"),
    "EQP-003": ("Muendungsbremse mit Querfluegeln, Trommelmagazin, Abstuetzstrebe",
                "schwer, abgestuetzt -- Artillerie"),
    "EQP-004": ("flacher Pod auf der Schulterbruecke", "Support, keine Waffe"),
    "EQP-005": ("langer duenner Stab mit Kopfglut", "arkane Waffe"),
    "EQP-006": ("schwebender Ring vor der Hand", "Support, arkan"),
    "EQP-007": ("ueberlanger duenner Doppellauf, Zielblock, Gabel",
                "Praezision, grosse Reichweite"),
}


# ---------------------------------------------------------------------------
# Daten einlesen
# ---------------------------------------------------------------------------
def load_parts() -> tuple[list[dict], dict]:
    """Ein Eintrag je Teil (Suedansicht als Vertreter) plus Set-Namen."""
    parts, set_names = [], {}
    for set_dir in sorted(p for p in PARTS_DIR.iterdir() if p.is_dir()):
        set_json = set_dir / "set.json"
        set_names[set_dir.name] = (
            json.loads(set_json.read_text(encoding="utf-8")).get("name", set_dir.name)
            if set_json.is_file() else set_dir.name
        )
        for json_path in sorted(set_dir.glob("*.json")):
            if json_path.name == "set.json":
                continue
            meta = json.loads(json_path.read_text(encoding="utf-8"))
            if meta.get("direction") != "south":
                continue          # vier Richtungen, ein Teil
            parts.append(meta)
    parts.sort(key=lambda m: (TYPE_ORDER.index(base_type(m["type"])), m.get("code", "")))
    return parts, set_names


def base_type(part_type: str) -> str:
    return "equipment" if part_type.startswith("equipment") else part_type


def equip_slots(part: dict) -> list[str]:
    return sorted(a["name"] for a in part.get("anchors", [])
                  if a["name"].startswith("equip_"))


# ---------------------------------------------------------------------------
# Bausteine
# ---------------------------------------------------------------------------
def title(sheet, row: int, text: str, note: str = "") -> int:
    cell = sheet.cell(row=row, column=1, value=text)
    cell.font = Font(name=FONT, bold=True, size=14)
    row += 1
    if note:
        cell = sheet.cell(row=row, column=1, value=note)
        cell.font = NOTE_FONT
        row += 1
    return row + 1


def header_row(sheet, row: int, labels: list[str], start: int = 1) -> int:
    for offset, label in enumerate(labels):
        cell = sheet.cell(row=row, column=start + offset, value=label)
        cell.font = HEAD_FONT
        cell.fill = HEAD_FILL
        cell.alignment = Alignment(vertical="center", wrap_text=True)
        cell.border = BOX
    sheet.row_dimensions[row].height = 30
    return row + 1


def widths(sheet, mapping: dict) -> None:
    for column, width in mapping.items():
        sheet.column_dimensions[column].width = width


# ---------------------------------------------------------------------------
# Blatt 1: Legende
# ---------------------------------------------------------------------------
def sheet_legend(book, parts, parts_range) -> None:
    sheet = book.create_sheet("Legende")
    widths(sheet, {"A": 26, "B": 88})
    row = title(sheet, 1, "CyberDrome -- Teile-Uebersicht",
                "Erzeugt aus parts/ durch tools/export_parts_table.py. "
                "Nicht von Hand pflegen, sondern neu erzeugen.")

    entries = [
        ("Blatt „Teile“",
         "Alle Teile mit Code, Set, Typ, Montageklasse, Bauart und "
         "Silhouetten-Merkmal. Alles davon steht so in den Teil-JSONs -- FAKT."),
        ("Blatt „Werte“",
         "Formular fuer die Spielwerte, je Bauteiltyp ein Block. LEER, weil im "
         "Projekt noch keine Zahlen entschieden sind. Gelbe Zellen ausfuellen."),
        ("Blatt „Chassis & Slots“",
         "Je Chassis: wie viele Ausruestungsanker, und was jeder annimmt."),
        ("Blatt „Kompatibilitaet“",
         "Lebende Matrix: welches Ausruestungsteil an welchen Slot passt. "
         "Rechnet sich aus den Spalten „Klasse“ und „Bauart“ "
         "aus -- aendert man die, aendert sich die Matrix mit."),
        ("Blatt „Silhouetten“",
         "Wie aehnlich sich zwei Teile desselben Typs sehen. 1.00 waere "
         "ununterscheidbar; ab 0.80 bricht der Generator bei Ausruestung ab."),
    ]
    row = header_row(sheet, row, ["Blatt", "Was drin steht"])
    for name, text in entries:
        sheet.cell(row=row, column=1, value=name).font = SUB_FONT
        cell = sheet.cell(row=row, column=2, value=text)
        cell.font = BODY_FONT
        cell.alignment = Alignment(wrap_text=True, vertical="top")
        sheet.row_dimensions[row].height = 30
        row += 1

    row += 1
    sheet.cell(row=row, column=1, value="Farben").font = Font(name=FONT, bold=True, size=12)
    row += 1
    for fill, font, text in [
        (FILL_ME, BODY_FONT, "gelb = hier gehoert eine Zahl hin, die es noch nicht gibt"),
        (None, INPUT_FONT, "blau = Eingabe, von Hand gesetzt"),
        (None, BODY_FONT, "schwarz = Formel oder Fakt aus den Teil-Dateien"),
        (HELPER_FILL, NOTE_FONT, "grau = Hilfsspalte, die die Matrix braucht"),
    ]:
        cell = sheet.cell(row=row, column=1, value="Beispiel")
        if fill:
            cell.fill = fill
        cell.font = font
        cell.border = BOX
        sheet.cell(row=row, column=2, value=text).font = BODY_FONT
        row += 1

    row += 1
    sheet.cell(row=row, column=1,
               value="Montageklasse und Bauart").font = Font(name=FONT, bold=True, size=12)
    row += 1
    for text in [
        "Montageklasse = was die HALTERUNG aushalten muss (Masse, Rueckstoss, "
        "Hebel), nicht das Gewicht allein. leicht < mittel < schwer.",
        "Bauart = Waffe, Schild oder Support. Manche Slots nehmen nur bestimmte "
        "Bauarten -- die Molok-Schulter zum Beispiel nur Support.",
        "Ein Slot ohne Regel nimmt alles an. Details: parts/README.md, Abschnitt 2a.",
    ]:
        cell = sheet.cell(row=row, column=1, value=text)
        cell.font = BODY_FONT
        cell.alignment = Alignment(wrap_text=True, vertical="top")
        sheet.merge_cells(start_row=row, start_column=1, end_row=row, end_column=2)
        sheet.row_dimensions[row].height = 28
        row += 1

    row += 1
    sheet.cell(row=row, column=1, value="Bestand").font = Font(name=FONT, bold=True, size=12)
    sheet.cell(row=row, column=2,
               value="zaehlt das Blatt „Teile“ -- kommt ein Teil dazu, "
                     "stimmt die Zahl von selbst").font = NOTE_FONT
    row += 1
    row = header_row(sheet, row, ["Bauteiltyp", "Anzahl", "Rolle im Spiel"])
    widths(sheet, {"B": 10, "C": 78})
    first = row
    for part_type in TYPE_ORDER:
        sheet.cell(row=row, column=1, value=TYPE_LABEL[part_type]).font = BODY_FONT
        count = sheet.cell(
            row=row, column=2,
            value=f'=COUNTIF(Teile!$D${parts_range[0]}:$D${parts_range[1]},A{row})')
        count.font = BODY_FONT
        count.alignment = Alignment(horizontal="center")
        cell = sheet.cell(row=row, column=3, value=TYPE_ROLE[part_type])
        cell.font = BODY_FONT
        cell.alignment = Alignment(wrap_text=True, vertical="top")
        for column in (1, 2, 3):
            sheet.cell(row=row, column=column).border = BOX
        row += 1
    sheet.cell(row=row, column=1, value="Summe").font = SUB_FONT
    total = sheet.cell(row=row, column=2, value=f"=SUM(B{first}:B{row - 1})")
    total.font = SUB_FONT
    total.alignment = Alignment(horizontal="center")


# ---------------------------------------------------------------------------
# Blatt 2: Teile
# ---------------------------------------------------------------------------
def sheet_parts(book, parts, set_names) -> tuple[int, int]:
    sheet = book.create_sheet("Teile")
    widths(sheet, {"A": 10, "B": 24, "C": 22, "D": 13, "E": 18, "F": 11, "G": 10,
                   "H": 18, "I": 44, "J": 34, "K": 26})
    row = title(sheet, 1, "Teile-Bestand",
                "Alles auf diesem Blatt kommt aus den Teil-JSONs. Die vier "
                "Richtungsvarianten eines Teils teilen sich eine Zeile.")

    row = header_row(sheet, row, [
        "Code", "Name", "Set", "Typ", "Datei-Slug", "Klasse", "Bauart",
        "nur an Slot", "Silhouetten-Merkmal", "sagt dem Spieler", "Tags",
    ])
    first = row

    for part in parts:
        code = part.get("code", "")
        kind = base_type(part["type"])
        merkmal, wirkung = READING.get(code, ("", ""))
        values = [
            code,
            part.get("name", part["id"]),
            set_names.get(part["set"], part["set"]),
            TYPE_LABEL[kind],
            part["id"],
            CLASS_LABEL.get(part.get("mount_class"), "") if kind == "equipment" else "",
            CATEGORY_LABEL.get(part.get("category"), "") if kind == "equipment" else "",
            ", ".join(s.replace("equip_", "") for s in part.get("slots", [])) or
            ("alle" if kind == "equipment" else ""),
            merkmal,
            wirkung,
            ", ".join(part.get("tags", [])),
        ]
        for offset, value in enumerate(values, start=1):
            cell = sheet.cell(row=row, column=offset, value=value)
            cell.font = BODY_FONT
            cell.border = BOX
            cell.alignment = Alignment(wrap_text=offset >= 9, vertical="top")
        sheet.cell(row=row, column=1).font = Font(name=FONT, size=10, bold=True)
        sheet.row_dimensions[row].height = 28
        row += 1

    sheet.freeze_panes = f"A{first}"
    sheet.auto_filter.ref = f"A{first - 1}:K{row - 1}"
    return first, row - 1


# ---------------------------------------------------------------------------
# Blatt 3: Werte (Formular)
# ---------------------------------------------------------------------------
def sheet_stats(book, parts) -> None:
    sheet = book.create_sheet("Werte")
    widths(sheet, {"A": 10, "B": 26, "C": 14, "D": 14, "E": 14, "F": 52})
    row = title(
        sheet, 1, "Spielwerte -- auszufuellen",
        "Diese Zahlen gibt es im Projekt noch nicht: das Kampfsystem ist offen "
        "(docs/GAME_DESIGN.md, Abschnitt 7). Das Blatt ist deshalb ein leeres "
        "Formular, kein Bestand. Gelbe Zellen sind zum Eintragen da.",
    )

    example = {
        "body": [120, 8, "mittel"], "head": [7, 5, 2], "feet": [6, 15, "normal"],
        "core": [10, 2, 1], "equipment": [14, 6, 2],
    }

    for part_type in TYPE_ORDER:
        group = [p for p in parts if base_type(p["type"]) == part_type]
        if not group:
            continue

        cell = sheet.cell(row=row, column=1, value=TYPE_LABEL[part_type].upper())
        cell.font = Font(name=FONT, bold=True, size=12)
        sheet.cell(row=row, column=2, value=TYPE_ROLE[part_type]).font = NOTE_FONT
        row += 1

        stats = TYPE_STATS[part_type]
        row = header_row(sheet, row, ["Code", "Name", *stats, "Notiz / Wirkung im Spiel"])

        # Beispielzeile: zeigt das erwartete Format, ist kein echtes Teil.
        cell = sheet.cell(row=row, column=1, value="(Beispiel)")
        cell.font = NOTE_FONT
        sheet.cell(row=row, column=2, value="so sieht eine gefuellte Zeile aus").font = NOTE_FONT
        for offset, value in enumerate(example[part_type], start=3):
            filled = sheet.cell(row=row, column=offset, value=value)
            filled.font = NOTE_FONT
            filled.alignment = Alignment(horizontal="center")
            filled.border = BOX
        sheet.cell(row=row, column=3 + len(stats),
                   value="Freitext -- was das Teil im Gefecht bewirkt").font = NOTE_FONT
        row += 1

        for part in group:
            sheet.cell(row=row, column=1, value=part.get("code", "")).font = \
                Font(name=FONT, size=10, bold=True)
            sheet.cell(row=row, column=2, value=part.get("name", part["id"])).font = BODY_FONT
            for offset in range(len(stats)):
                cell = sheet.cell(row=row, column=3 + offset)
                cell.fill = FILL_ME
                cell.font = INPUT_FONT
                cell.border = BOX
                cell.alignment = Alignment(horizontal="center")
            note = sheet.cell(row=row, column=3 + len(stats),
                              value=READING.get(part.get("code", ""), ("", ""))[1])
            note.font = BODY_FONT
            note.fill = FILL_ME
            note.border = BOX
            note.alignment = Alignment(wrap_text=True, vertical="top")
            row += 1
        row += 1

    comment = Comment(
        "Sobald hier Zahlen stehen, gehoeren sie in eine Datei im Repo "
        "(z. B. parts/stats.json) und nicht nur in diese Mappe -- sonst hat "
        "das Spiel sie nie.", "CyberDrome")
    sheet["A5"].comment = comment


# ---------------------------------------------------------------------------
# Blatt 4: Chassis & Slots
# ---------------------------------------------------------------------------
def rule_text(rule: dict | None) -> str:
    if not rule:
        return "alles"
    parts_ = []
    if rule.get("max_class"):
        parts_.append("bis " + CLASS_LABEL[rule["max_class"]])
    if rule.get("categories"):
        parts_.append("nur " + "/".join(CATEGORY_LABEL[c] for c in rule["categories"]))
    return " · ".join(parts_) or "alles"


def sheet_chassis(book, parts, set_names) -> None:
    sheet = book.create_sheet("Chassis & Slots")
    widths(sheet, {"A": 10, "B": 22, "C": 24, "D": 9, "E": 16, "F": 22, "G": 44})
    row = title(sheet, 1, "Chassis und ihre Ausruestungsslots",
                "Die Zahl der Slots faellt aus den equip_*-Ankern des Chassis, "
                "die Regel je Slot aus seinem Feld slot_rules.")

    row = header_row(sheet, row, [
        "Code", "Chassis", "Set", "Slots", "Slot", "nimmt an", "Anmerkung",
    ])

    notes = {
        ("CHS-002", "equip_shoulder"):
            "Bruecke hinter dem Kopf: kein Gegenhalt, keine Hand. Sensorik und "
            "Drohnen ja, Schild oder schweres Geraet nein.",
        ("CHS-004", "equip_center"):
            "Der einzige Slot -- dafuer ohne Obergrenze. Ein Slot weniger als "
            "der Standard, dafuer die schwerste Waffe.",
        ("CHS-001", "equip_left"): "Sprinter: keine Artillerie an einem Arm, "
                                   "der sechs Felder weit laufen soll.",
    }

    for part in parts:
        if base_type(part["type"]) != "body":
            continue
        slots = equip_slots(part)
        rules = part.get("slot_rules", {})
        start = row
        for index, slot in enumerate(slots):
            values = [
                part.get("code", "") if index == 0 else "",
                part.get("name", part["id"]) if index == 0 else "",
                set_names.get(part["set"], part["set"]) if index == 0 else "",
                len(slots) if index == 0 else "",
                slot,
                rule_text(rules.get(slot)),
                notes.get((part.get("code", ""), slot), ""),
            ]
            for offset, value in enumerate(values, start=1):
                cell = sheet.cell(row=row, column=offset, value=value)
                cell.font = BODY_FONT
                cell.border = BOX
                cell.alignment = Alignment(wrap_text=offset == 7, vertical="top")
            sheet.cell(row=row, column=1).font = Font(name=FONT, size=10, bold=True)
            sheet.cell(row=row, column=6).font = SUB_FONT
            sheet.row_dimensions[row].height = 28
            row += 1
        for column in (1, 2, 3, 4):
            if row - start > 1:
                sheet.merge_cells(start_row=start, start_column=column,
                                  end_row=row - 1, end_column=column)
                sheet.cell(row=start, column=column).alignment = Alignment(vertical="center")


# ---------------------------------------------------------------------------
# Blatt 5: Kompatibilitaet (lebende Matrix)
# ---------------------------------------------------------------------------
def sheet_matrix(book, parts, set_names) -> None:
    sheet = book.create_sheet("Kompatibilitaet")
    row = title(
        sheet, 1, "Was passt an welchen Slot",
        "Lebende Matrix: die Zellen rechnen aus Klasse und Bauart. Wer in den "
        "Spalten C bis F etwas aendert, sieht sofort, was daraus folgt.",
    )

    equipment = [p for p in parts if base_type(p["type"]) == "equipment"]
    bodies = [p for p in parts if base_type(p["type"]) == "body"]

    columns = []          # (Chassis-Name, Slotname, Regel)
    for body in bodies:
        rules = body.get("slot_rules", {})
        for slot in equip_slots(body):
            columns.append((body.get("name", body["id"]), slot, rules.get(slot)))

    head_chassis, head_slot, head_rule = row, row + 1, row + 2
    rank_row, cats_row = row + 3, row + 4
    header = row + 5
    first_data = header + 1

    labels = ["Code", "Teil", "Klasse", "Rang", "Bauart", "nur an Slot"]
    for index, label in enumerate(["Chassis", "Slot", "nimmt an", "Rang (Hilfe)",
                                   "Bauarten (Hilfe)"], start=0):
        cell = sheet.cell(row=row + index, column=6, value=label)
        cell.font = NOTE_FONT
        cell.alignment = Alignment(horizontal="right")

    for offset, (chassis, slot, rule) in enumerate(columns):
        column = 7 + offset
        letter = get_column_letter(column)
        sheet.column_dimensions[letter].width = 13

        cell = sheet.cell(row=head_chassis, column=column, value=chassis)
        cell.font = SUB_FONT
        cell.fill = SUB_FILL
        cell.alignment = Alignment(wrap_text=True, horizontal="center", vertical="bottom")

        cell = sheet.cell(row=head_slot, column=column, value=slot)
        cell.font = Font(name=FONT, size=9)
        cell.alignment = Alignment(horizontal="center")

        cell = sheet.cell(row=head_rule, column=column, value=rule_text(rule))
        cell.font = Font(name=FONT, size=9, italic=True)
        cell.alignment = Alignment(wrap_text=True, horizontal="center", vertical="top")

        limit = (rule or {}).get("max_class", "heavy")
        cell = sheet.cell(row=rank_row, column=column,
                          value=gen.MOUNT_CLASSES.index(limit) + 1)
        cell.font = NOTE_FONT
        cell.fill = HELPER_FILL
        cell.alignment = Alignment(horizontal="center")

        allowed = (rule or {}).get("categories") or list(gen.EQUIP_CATEGORIES)
        cell = sheet.cell(row=cats_row, column=column,
                          value=",".join(CATEGORY_LABEL[c] for c in allowed))
        cell.font = NOTE_FONT
        cell.fill = HELPER_FILL
        cell.alignment = Alignment(horizontal="center")

        cell = sheet.cell(row=header, column=column, value=slot.replace("equip_", ""))
        cell.font = HEAD_FONT
        cell.fill = HEAD_FILL
        cell.alignment = Alignment(horizontal="center")

    sheet.row_dimensions[head_chassis].height = 28
    sheet.row_dimensions[head_rule].height = 26
    header_row(sheet, header, labels)
    widths(sheet, {"A": 10, "B": 24, "C": 11, "D": 7, "E": 11, "F": 14})

    for index, part in enumerate(equipment):
        data_row = first_data + index
        # Volle Ankernamen, damit SEARCH() den Slotnamen der Spalte direkt
        # darin findet -- auch wenn ein Teil spaeter an mehrere Anker gebunden
        # wird und hier zwei Namen stehen.
        binding = ",".join(part.get("slots", [])) or "alle"
        values = [part.get("code", ""), part.get("name", part["id"]),
                  CLASS_LABEL[part.get("mount_class", "light")], None,
                  CATEGORY_LABEL[part.get("category", "weapon")], binding]
        for offset, value in enumerate(values, start=1):
            cell = sheet.cell(row=data_row, column=offset, value=value)
            cell.font = BODY_FONT if offset != 1 else Font(name=FONT, size=10, bold=True)
            cell.border = BOX
        # Rang der Montageklasse -- als Formel, damit eine geaenderte Klasse
        # in Spalte C sofort durch die ganze Matrix laeuft.
        rank = sheet.cell(row=data_row, column=4,
                          value=f'=MATCH(C{data_row},$B$1:$D$1,0)')
        rank.font = NOTE_FONT
        rank.fill = HELPER_FILL
        rank.alignment = Alignment(horizontal="center")
        rank.border = BOX

        for offset in range(len(columns)):
            column = 7 + offset
            letter = get_column_letter(column)
            cell = sheet.cell(
                row=data_row, column=column,
                value=(f'=IF(AND($D{data_row}<={letter}${rank_row},'
                       f'ISNUMBER(SEARCH($E{data_row},{letter}${cats_row})),'
                       f'OR($F{data_row}="alle",'
                       f'ISNUMBER(SEARCH({letter}${head_slot},$F{data_row})))),'
                       f'"ja","–")'))
            cell.font = BODY_FONT
            cell.border = BOX
            cell.alignment = Alignment(horizontal="center")

    # Nachschlagereihe fuer MATCH: leicht/mittel/schwer in B1:D1.
    for offset, name in enumerate(("leicht", "mittel", "schwer")):
        cell = sheet.cell(row=1, column=2 + offset, value=name)
        cell.font = NOTE_FONT
        cell.alignment = Alignment(horizontal="center")
    sheet.cell(row=1, column=5,
               value="← Rangfolge der Montageklassen, "
                     "Nachschlagereihe fuer Spalte D").font = NOTE_FONT

    sheet.freeze_panes = sheet.cell(row=first_data, column=7).coordinate


# ---------------------------------------------------------------------------
# Blatt 6: Silhouetten-Abstand
# ---------------------------------------------------------------------------
def sheet_silhouettes(book) -> None:
    sheet = book.create_sheet("Silhouetten")
    widths(sheet, {"A": 14, "B": 26, "C": 26, "D": 12, "E": 46})
    row = title(
        sheet, 1, "Silhouetten-Abstand",
        f"1.00 hiesse ununterscheidbar. Bei AUSRUESTUNG ist "
        f"{gen.SIL_ERROR:.2f} eine harte Grenze -- dort bricht der Generator "
        f"ab, weil der Spieler an der Waffe ihre Rolle abliest. Bei "
        f"RAHMENTEILEN ist es ab {gen.SIL_WARN:.2f} nur ein Hinweis: das Mass "
        f"saettigt bei kompakten Teilen, zwei Kloetze decken sich als Flaeche "
        f"auch dann, wenn sie voellig verschieden gebaut sind.",
    )
    row = header_row(sheet, row, ["Typ", "Teil A", "Teil B", "Abstand", "Bewertung"])

    by_type: dict[str, list] = {}
    for spec, part in gen.all_parts():
        kind = base_type(part["type"])
        by_type.setdefault(kind, []).append(
            (part["code"], part.get("name", part["id"]), gen.silhouette(part["shapes"])))

    for part_type in TYPE_ORDER:
        entries = by_type.get(part_type, [])
        pairs = []
        for index, (code_a, name_a, sil_a) in enumerate(entries):
            for code_b, name_b, sil_b in entries[index + 1:]:
                pairs.append((gen.silhouette_distance(sil_a, sil_b),
                              f"{code_a} {name_a}", f"{code_b} {name_b}"))
        pairs.sort(reverse=True)
        strict = part_type == "equipment"
        limit = gen.SIL_ERROR if strict else gen.SIL_WARN
        for score, name_a, name_b in pairs[:3]:      # nur die engsten drei
            if score >= limit:
                # Nur bei Ausruestung ist das ein Regelverstoss. Bei
                # Rahmenteilen ist die Grenze ein Hinweis -- die Mappe darf
                # daraus keinen Fehler machen, den es nicht gibt.
                verdict = ("VERLETZT die Lesbarkeitsregel" if strict else
                           "Hinweis -- ansehen, ob die Form wirklich traegt")
            elif score >= limit - 0.08:
                verdict = "grenzwertig -- im Auge behalten"
            else:
                verdict = "unterscheidbar"
            for offset, value in enumerate(
                    [TYPE_LABEL[part_type], name_a, name_b, round(score, 2), verdict],
                    start=1):
                cell = sheet.cell(row=row, column=offset, value=value)
                cell.font = BODY_FONT
                cell.border = BOX
            sheet.cell(row=row, column=4).number_format = "0.00"
            sheet.cell(row=row, column=4).alignment = Alignment(horizontal="center")
            row += 1

    row += 1
    cell = sheet.cell(row=row, column=1,
                      value="Pruefstein: die erste Belagerungskanone (ein Blaster "
                            "mit groesseren Zahlen) liegt bei "
                            f"{gen.silhouette_distance(gen.silhouette(gen.EQ_BLASTER), gen.silhouette(gen.EQ_CANNON_V1)):.2f}"
                            " -- genau der Fall, den die Regel verbietet.")
    cell.font = NOTE_FONT


# ---------------------------------------------------------------------------
# Selbstpruefung
# ---------------------------------------------------------------------------
# Ein winziger Formel-Rechner. Er kann genau die Funktionen, die diese Mappe
# benutzt -- mehr soll er nicht koennen. Sein Zweck ist, die geschriebene
# Formel selbst auszuwerten statt einer nachgebauten Zweitfassung: nur so
# faellt ein verrutschter Bezug auf.
_TOKEN = __import__("re").compile(
    r'\s*("(?:[^"]|"")*"|[A-Z]+\$?\d+|\$?[A-Z]+\$?\d+|[A-Za-z]+(?=\()|'
    r'<=|>=|<>|[(),=<>&:]|-?\d+(?:\.\d+)?)')


def _range(sheet, start: str, end: str) -> list:
    """Werte eines Zellbereichs, zeilenweise."""
    from openpyxl.utils import range_boundaries
    reference = f"{start}:{end}".replace("$", "")
    c0, r0, c1, r1 = range_boundaries(reference)
    return [sheet.cell(row=r, column=c).value
            for r in range(r0, r1 + 1) for c in range(c0, c1 + 1)]


def evaluate(sheet, formula: str):
    """Wertet eine Formel dieser Mappe aus. Kennt IF/AND/OR/ISNUMBER/SEARCH."""
    if not isinstance(formula, str) or not formula.startswith("="):
        return formula

    tokens, position = [], 1
    while position < len(formula):
        match = _TOKEN.match(formula, position)
        if not match:
            raise SystemExit(f"Formel nicht lesbar ab {formula[position:][:30]!r}")
        tokens.append(match.group(1))
        position = match.end()

    index = 0

    def peek():
        return tokens[index] if index < len(tokens) else None

    def take(expected=None):
        nonlocal index
        token = tokens[index]
        if expected and token != expected:
            raise SystemExit(f"Erwartet {expected!r}, gefunden {token!r}")
        index += 1
        return token

    def cell(reference: str):
        column, row = "", ""
        for char in reference.replace("$", ""):
            (column := column + char) if char.isalpha() else (row := row + char)
        from openpyxl.utils import column_index_from_string
        value = sheet.cell(row=int(row),
                           column=column_index_from_string(column)).value
        # Verweist eine Formel auf eine andere Formel, wird die mit
        # ausgerechnet -- sonst vergliche man gegen einen Formeltext.
        return evaluate(sheet, value) if isinstance(value, str) else value

    def call(name: str):
        take("(")
        args = []
        while True:
            args.append(expression())
            if peek() == ",":
                take(",")
                continue
            take(")")
            break
        if name == "IF":
            return args[1] if args[0] else args[2]
        if name == "AND":
            return all(args)
        if name == "OR":
            return any(args)
        if name == "ISNUMBER":
            return isinstance(args[0], (int, float)) and not isinstance(args[0], bool)
        if name == "SEARCH":
            needle, haystack = str(args[0]).lower(), str(args[1]).lower()
            return haystack.index(needle) + 1 if needle in haystack else "#VALUE!"
        if name == "MATCH":
            return args[1].index(args[0]) + 1 if args[0] in args[1] else "#N/A"
        if name in ("SUM", "COUNTIF"):
            raise SystemExit(f"{name} gehoert nicht in die Matrix")
        raise SystemExit(f"Funktion {name} kennt der Pruef-Rechner nicht")

    def atom():
        token = take()
        if token == "(":
            value = expression()
            take(")")
            return value
        if token.startswith('"'):
            return token[1:-1].replace('""', '"')
        if token.replace("-", "").replace(".", "").isdigit():
            return float(token) if "." in token else int(token)
        if token.isalpha():
            return call(token)
        if peek() == ":":                      # Bereich, z. B. $B$1:$D$1
            take(":")
            return _range(sheet, token, take())
        return cell(token)

    def expression():
        left = atom()
        while peek() == "&":
            take("&")
            left = f"{left}{atom()}"
        if peek() in ("<=", ">=", "<>", "=", "<", ">"):
            operator = take()
            right = expression()
            if isinstance(left, str) and "#" in str(left):
                return False
            return {"<=": lambda a, b: a <= b, ">=": lambda a, b: a >= b,
                    "=": lambda a, b: a == b, "<>": lambda a, b: a != b,
                    "<": lambda a, b: a < b, ">": lambda a, b: a > b}[operator](left, right)
        return left

    return expression()


def verify(path: pathlib.Path, parts: list[dict]) -> None:
    """
    Rechnet die Kompatibilitaetsmatrix nach -- ohne Excel.

    Die Matrix besteht aus Formeln, und eine Formel mit einem verrutschten
    Bezug faellt beim Ansehen nicht auf: sie liefert einfach eine falsche
    Antwort. Hier wird deshalb dieselbe Frage zweimal gestellt -- einmal an die
    Zellen der Mappe, einmal an fits_rule() im Generator, also an die Regel
    selbst -- und beide Antworten muessen uebereinstimmen.
    """
    from openpyxl import load_workbook

    book = load_workbook(path)
    sheet = book["Kompatibilitaet"]

    ranks = {sheet.cell(row=1, column=column).value: column - 1
             for column in (2, 3, 4)}
    if ranks != {"leicht": 1, "mittel": 2, "schwer": 3}:
        raise SystemExit(f"Nachschlagereihe B1:D1 stimmt nicht: {ranks}")

    # Kopfzeilen der Slotspalten finden
    head_slot = next(r for r in range(1, 20)
                     if sheet.cell(row=r, column=6).value == "Slot")
    rank_row = head_slot + 2
    cats_row = head_slot + 3
    first_data = head_slot + 5

    equipment = {p["code"]: p for p in parts
                 if base_type(p["type"]) == "equipment"}
    bodies = {}
    for part in parts:
        if base_type(part["type"]) == "body":
            for slot in equip_slots(part):
                bodies[(part.get("name", part["id"]), slot)] = \
                    part.get("slot_rules", {}).get(slot)

    columns = []
    column = 7
    while sheet.cell(row=head_slot, column=column).value:
        columns.append((column,
                        sheet.cell(row=head_slot - 1, column=column).value,
                        sheet.cell(row=head_slot, column=column).value))
        column += 1
    if len(columns) != len(bodies):
        raise SystemExit(f"{len(columns)} Slotspalten, aber {len(bodies)} Slots")

    checked = 0
    row = first_data
    while sheet.cell(row=row, column=1).value:
        code = sheet.cell(row=row, column=1).value
        part = equipment[code]
        for column, chassis, slot in columns:
            rule = bodies[(chassis, slot)]
            # Was die Regel sagt ...
            expected = (
                gen.fits_rule(part.get("mount_class", gen.DEFAULT_MOUNT_CLASS),
                              part.get("category", gen.DEFAULT_CATEGORY), rule)
                and (not part.get("slots") or slot in part["slots"])
            )
            # ... und was die Zellen der Mappe hergeben.
            # ... und was die FORMEL in der Zelle tatsaechlich rechnet.
            # Nicht was sie rechnen soll: eine nachgebaute Zweitfassung wuerde
            # denselben Denkfehler zweimal machen und ihn deshalb nie finden.
            actual = evaluate(sheet, sheet.cell(row=row, column=column).value)
            if actual != ("ja" if expected else "–"):
                raise SystemExit(
                    f"Matrix widerspricht der Regel: {code} an "
                    f"{chassis}/{slot} -- Regel sagt "
                    f"{'ja' if expected else 'nein'}, Formel rechnet {actual!r}")
            checked += 1
        row += 1

    # Die COUNTIF-Bereiche der Legende muessen die Datenzeilen treffen.
    legend = book["Legende"]
    for legend_row in range(1, legend.max_row + 1):
        formula = legend.cell(row=legend_row, column=2).value
        if not isinstance(formula, str) or not formula.startswith("=COUNTIF"):
            continue
        label = legend.cell(row=legend_row, column=1).value
        span = formula.split("!$D$")[1].split(",")[0]      # z. B. "5:$D$27"
        start, end = (int(x.lstrip("$D$").lstrip("$")) for x in span.split(":"))
        found = sum(1 for r in range(start, end + 1)
                    if book["Teile"].cell(row=r, column=4).value == label)
        expected = sum(1 for p in parts if TYPE_LABEL[base_type(p["type"])] == label)
        if found != expected:
            raise SystemExit(f"COUNTIF-Bereich fuer {label} trifft {found} "
                             f"statt {expected} Zeilen")

    print(f"[ok] Matrix gegen die Slotregel geprueft: {checked} Zellen, "
          f"kein Widerspruch")


# ---------------------------------------------------------------------------
def main() -> None:
    target = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else \
        ROOT / "builds" / "cyberdrome_teile.xlsx"
    target.parent.mkdir(parents=True, exist_ok=True)

    parts, set_names = load_parts()
    book = Workbook()
    book.remove(book.active)

    legend = book.create_sheet("Legende")   # Platz halten, Reihenfolge der Blaetter
    parts_range = sheet_parts(book, parts, set_names)
    book.remove(legend)
    sheet_legend(book, parts, parts_range)
    book.move_sheet("Legende", offset=-(len(book.sheetnames) - 1))
    sheet_stats(book, parts)
    sheet_chassis(book, parts, set_names)
    sheet_matrix(book, parts, set_names)
    sheet_silhouettes(book)

    book.save(target)
    print(f"[ok] {target}  ({len(parts)} Teile, {len(book.sheetnames)} Blaetter)")
    verify(target, parts)


if __name__ == "__main__":
    main()
