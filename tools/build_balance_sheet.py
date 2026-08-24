#!/usr/bin/env python3
"""
build_balance_sheet.py -- Ausruestungs-Statistik-Liste als Excel-Mappe.

    python3 tools/build_balance_sheet.py [ziel.xlsx]

Liest die kuratierte Balancing-Quelle data/balancing/ausruestung_stats.json und
schreibt daraus eine gut lesbare Arbeitsmappe (Vorgabe: docs/ausruestung_stats.xlsx).

Zweck
-----
Die schlanke BALANCING-Sicht auf das Klassenmodell (GAME_DESIGN §9/§12): die
Huelle als EIN Teil, wenige aussagekraeftige Werte je Kategorie. Nicht zu
verwechseln mit docs/cyberdrome_teile.xlsx -- die kommt aus den Teil-JSONs und
zeigt den vollen Engine-Wertesatz. Diese Mappe hier ist zum Anfassen und Tunen.

Schema (generisch)
------------------
Die JSON beschreibt je Kategorie eine Liste ``spalten`` (key, label, kind, width)
und eine Liste ``zeilen``. ``kind`` steuert die Optik:

    id / text   normale Zelle
    stat        getunte Zahl -- hervorgehoben und zentriert
    desc        beschreibender Fliesstext -- umbrechend

Eine neue Spalte ist damit ein Eintrag in ``spalten`` plus das Feld je Zeile --
am Generator ist nichts zu aendern.
"""

from __future__ import annotations

import json
import pathlib
import sys

from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "data" / "balancing" / "ausruestung_stats.json"
DEFAULT_OUT = ROOT / "docs" / "ausruestung_stats.xlsx"

# --- Optik ------------------------------------------------------------------
HEAD_FILL = PatternFill("solid", fgColor="1F2A44")   # tiefes Nachtblau
HEAD_FONT = Font(bold=True, color="FFFFFF", size=11)
TITLE_FONT = Font(bold=True, color="1F2A44", size=15)
SUB_FONT = Font(italic=True, color="55607A", size=10)
SECTION_FONT = Font(bold=True, color="1F2A44", size=12)
STAT_FILL = PatternFill("solid", fgColor="EAF1FB")   # Werte-Spalten
ZEBRA_FILL = PatternFill("solid", fgColor="F5F7FB")
STAT_FONT = Font(bold=True, color="112233", size=11)
CENTER = Alignment(horizontal="center", vertical="center", wrap_text=True)
LEFT = Alignment(horizontal="left", vertical="center", wrap_text=True)
THIN = Side(style="thin", color="D5DBE7")
BORDER = Border(left=THIN, right=THIN, top=THIN, bottom=THIN)


def load() -> dict:
    with SOURCE.open(encoding="utf-8") as fh:
        return json.load(fh)


def _title(sheet, text: str, note: str = "") -> int:
    cell = sheet.cell(row=1, column=1, value=text)
    cell.font = TITLE_FONT
    row = 2
    if note:
        cell = sheet.cell(row=row, column=1, value=note)
        cell.font = SUB_FONT
        cell.alignment = Alignment(vertical="center", wrap_text=True)
        sheet.row_dimensions[row].height = 28
        row += 1
    return row + 1


def _row_height(item: dict, columns: list[dict]) -> int:
    """Etwas hoehere Zeilen, wenn eine Text-Spalte umbrechen muss."""
    longest = 0.0
    for col in columns:
        if col["kind"] == "stat":
            continue
        text = str(item.get(col["key"], ""))
        longest = max(longest, len(text) / max(col["width"], 1))
    return 18 + int(longest) * 13


def _category_sheet(book: Workbook, name: str, spec: dict) -> None:
    sheet = book.create_sheet(name)
    sheet.sheet_view.showGridLines = False
    columns = spec["spalten"]
    head = _title(sheet, spec["titel"], spec.get("untertitel", ""))

    for offset, col in enumerate(columns, start=1):
        cell = sheet.cell(row=head, column=offset, value=col["label"])
        cell.fill = HEAD_FILL
        cell.font = HEAD_FONT
        cell.alignment = CENTER if col["kind"] == "stat" else LEFT
        cell.border = BORDER
        sheet.column_dimensions[get_column_letter(offset)].width = col["width"]
    sheet.row_dimensions[head].height = 26

    row = head + 1
    for r_index, item in enumerate(spec["zeilen"]):
        for offset, col in enumerate(columns, start=1):
            cell = sheet.cell(row=row, column=offset, value=item.get(col["key"], ""))
            cell.border = BORDER
            if col["kind"] == "stat":
                cell.fill = STAT_FILL
                cell.font = STAT_FONT
                cell.alignment = CENTER
            else:
                if r_index % 2 == 1:
                    cell.fill = ZEBRA_FILL
                cell.alignment = LEFT
        sheet.row_dimensions[row].height = _row_height(item, columns)
        row += 1

    last = row - 1
    sheet.freeze_panes = sheet.cell(row=head + 1, column=1).coordinate
    sheet.auto_filter.ref = f"A{head}:{get_column_letter(len(columns))}{last}"


def _mini_table(sheet, row: int, headers: list[str], rows: list[tuple],
                center_cols: set[int]) -> int:
    for offset, header in enumerate(headers, start=1):
        c = sheet.cell(row=row, column=offset, value=header)
        c.fill = HEAD_FILL
        c.font = HEAD_FONT
        c.alignment = CENTER
        c.border = BORDER
    row += 1
    for values in rows:
        for offset, value in enumerate(values, start=1):
            c = sheet.cell(row=row, column=offset, value=value)
            c.border = BORDER
            c.alignment = CENTER if offset in center_cols else LEFT
        row += 1
    return row + 1


def sheet_uebersicht(book: Workbook, data: dict) -> None:
    sheet = book.create_sheet("Uebersicht")
    sheet.sheet_view.showGridLines = False
    row = _title(sheet, "Ausruestungs-Statistik-Liste",
                 "Balancing-Sicht auf das Klassenmodell (GAME_DESIGN §9/§12).")
    sheet.column_dimensions["A"].width = 22
    sheet.column_dimensions["B"].width = 16
    sheet.column_dimensions["C"].width = 74

    # Wieviele Werte je Kategorie -- direkt aus den Spalten gezaehlt.
    sheet.cell(row=row, column=1, value="Wieviele Werte je Kategorie").font = SECTION_FONT
    row += 1
    model_rows = []
    for key, spec in data["kategorien"].items():
        stat_count = sum(1 for c in spec["spalten"] if c["kind"] == "stat")
        has_passive = any(c["key"] == "passive_name" for c in spec["spalten"])
        model_rows.append((spec.get("kurzname", key.capitalize()), stat_count,
                           "ja" if has_passive else "nein"))
    row = _mini_table(sheet, row, ["Kategorie", "Werte (Zahlen)", "Passive?"],
                      model_rows, center_cols={2, 3})

    # Was die Werte bedeuten
    sheet.cell(row=row, column=1, value="Was die Werte bedeuten").font = SECTION_FONT
    row += 1
    glossar_rows = [(s["label"], s["engine"], s["beschreibung"])
                    for s in data["stat_glossar"].values()]
    row = _mini_table(sheet, row, ["Wert", "Engine-Feld", "Beschreibung"],
                      glossar_rows, center_cols=set())

    # Hinweise (der JSON-Kommentar, damit offene Punkte sichtbar bleiben)
    sheet.cell(row=row, column=1, value="Hinweise").font = SECTION_FONT
    row += 1
    for line in data.get("_kommentar", []):
        c = sheet.cell(row=row, column=1, value=line)
        c.font = SUB_FONT
        c.alignment = LEFT
        sheet.merge_cells(start_row=row, start_column=1, end_row=row, end_column=3)
        row += 1


def build(out_path: pathlib.Path) -> None:
    data = load()
    book = Workbook()
    book.remove(book.active)  # die leere Vorgabe-Seite

    sheet_uebersicht(book, data)

    # Feste, lesbare Reihenfolge der Kategorieblaetter.
    order = ["huelle", "waffe", "kern", "gadget"]
    titles = {"huelle": "Huelle", "waffe": "Waffen", "kern": "Kerne", "gadget": "Gadgets"}
    for key in order:
        if key in data["kategorien"]:
            _category_sheet(book, titles[key], data["kategorien"][key])

    out_path.parent.mkdir(parents=True, exist_ok=True)
    book.save(out_path)
    print(f"[balance] geschrieben: {out_path.relative_to(ROOT)}")


def main(argv: list[str]) -> int:
    out = pathlib.Path(argv[1]).resolve() if len(argv) > 1 else DEFAULT_OUT
    if not SOURCE.exists():
        raise SystemExit(f"Quelle fehlt: {SOURCE}")
    build(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
