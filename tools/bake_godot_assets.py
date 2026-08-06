#!/usr/bin/env python3
"""
Backt die Teile-SVGs zu Godot-tauglichen Texturen.

Warum das noetig ist
--------------------
Die Teile in ``parts/`` zeichnen ausschliesslich mit CSS-Variablen
(``fill="var(--c-plate)"``). Das ist der Grund, warum die Werkstatt umfaerben
kann, ohne ein einziges Asset neu zu erzeugen -- die Farben kommen aus dem
Stylesheet, nicht aus der Datei.

Godots SVG-Rasterizer kennt keine CSS-Variablen. Er loest sie nicht auf und
faellt auf Schwarz zurueck: importiert man ein Teil unveraendert, ist es eine
schwarze Flaeche. Nachgemessen mit Godot 4.3 -- ein Teil ergibt genau eine
Farbe, ``#000000``.

Deshalb dieser Schritt. Er ersetzt jede Variable durch den konkreten Hex-Wert
aus ``color_scheme`` der Teil-JSON -- also aus genau der Palette, die der
Generator ohnehin schon in jede Datei schreibt. Das ist die Variante, die
``docs/GODOT_INTEGRATION.md`` unter *Pro-Palette rastern* beschreibt.

Was hier NICHT passiert
-----------------------
Es wird nichts gezeichnet, nichts verschoben, nichts neu erfunden. Geometrie,
Anker und Zeichenreihenfolge bleiben Byte fuer Byte, wie der Generator sie
gelegt hat. Der einzige Unterschied zwischen Quelle und Ergebnis ist die
Farbe -- und die stammt aus derselben Datei.

Aufruf
------
    python3 tools/bake_godot_assets.py            # nach assets/parts/
    python3 tools/bake_godot_assets.py --check    # nur pruefen, nichts schreiben
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PARTS_DIR = ROOT / "parts"
OUT_DIR = ROOT / "assets" / "parts"

# fill="var(--c-plate-dark)" -> Rolle "plate_dark" in color_scheme
VAR_PATTERN = re.compile(r"var\(--c-([a-z-]+)\)")

# Faellt eine Rolle im color_scheme, wird nicht stillschweigend Schwarz
# eingesetzt, sondern Magenta -- die Fehlfarbe des Projekts. Ein fehlendes
# Teil soll auffallen, nicht heimlich dunkel werden.
MISSING_COLOR = "#ff00ff"


def bake_svg(svg_text: str, color_scheme: dict) -> tuple[str, set[str]]:
    """Ersetzt alle CSS-Variablen durch Hex-Werte. Gibt Fehlrollen zurueck."""
    missing: set[str] = set()

    def replace(match: re.Match) -> str:
        role = match.group(1).replace("-", "_")
        color = color_scheme.get(role)
        if color is None:
            missing.add(role)
            return MISSING_COLOR
        return color

    return VAR_PATTERN.sub(replace, svg_text), missing


def iter_parts():
    """Alle Teil-JSONs mit ihrem SVG, sortiert und ohne set.json."""
    for meta_path in sorted(PARTS_DIR.glob("*/*.json")):
        if meta_path.name == "set.json":
            continue
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        svg_path = meta_path.parent / meta["svg"]
        if not svg_path.exists():
            raise SystemExit(f"{meta_path}: verweist auf fehlendes {meta['svg']}")
        yield meta_path, meta, svg_path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="nur pruefen, ob das Ergebnis aktuell waere")
    args = parser.parse_args()

    written = stale = 0
    all_missing: dict[str, set[str]] = {}

    def emit(target: pathlib.Path, text: str) -> None:
        nonlocal written, stale
        current = target.read_text(encoding="utf-8") if target.exists() else None
        if current == text:
            return
        stale += 1
        if args.check:
            print(f"[veraltet] {target.relative_to(ROOT)}")
            return
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")
        written += 1

    # Der Bausatz-Kopf traegt Name und Startpalette. Er wird nicht gebacken --
    # er enthaelt keine Grafik -- aber er gehoert in denselben Baum, sonst
    # kennt die Engine die Bausaetze nicht.
    for set_meta in sorted(PARTS_DIR.glob("*/set.json")):
        emit(OUT_DIR / set_meta.parent.name / "set.json",
             set_meta.read_text(encoding="utf-8"))

    for meta_path, meta, svg_path in iter_parts():
        baked, missing = bake_svg(svg_path.read_text(encoding="utf-8"),
                                  meta.get("color_scheme", {}))
        if missing:
            all_missing[f"{meta['set']}/{meta['id']}"] = missing

        # Die Metadaten wandern unveraendert mit. Nicht, weil sie sich aendern
        # muessten, sondern damit die Engine genau EINEN Baum liest: der
        # Quellbaum parts/ traegt eine .gdignore, sonst importierte Godot 92
        # schwarze Texturen daneben -- und beim Export waere dann offen,
        # welcher der beiden Baeume mitgeht.
        emit(OUT_DIR / meta["set"] / svg_path.name, baked)
        emit(OUT_DIR / meta["set"] / meta_path.name,
             json.dumps(meta, indent=2, ensure_ascii=False) + "\n")

    if all_missing:
        print("\nFehlende Farbrollen (mit Magenta gefuellt):", file=sys.stderr)
        for where, roles in sorted(all_missing.items()):
            print(f"  {where}: {', '.join(sorted(roles))}", file=sys.stderr)

    if args.check:
        if stale:
            print(f"\n{stale} Datei(en) veraltet -- "
                  f"tools/bake_godot_assets.py laufen lassen.", file=sys.stderr)
            return 1
        print("assets/parts/ ist aktuell.")
        return 0

    total = sum(1 for _ in iter_parts())
    print(f"[ok] {total} Teile nach {OUT_DIR.relative_to(ROOT)}/ gebacken, "
          f"{written} Datei(en) neu geschrieben")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
