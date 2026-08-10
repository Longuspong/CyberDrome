#!/usr/bin/env python3
"""
Stellt ein, wie fein Godot die SVGs rastert.

Warum das noetig ist
--------------------
Godots SVG-Importer rastert ein Teil in seiner Nenngroesse: aus
``width="128"`` werden 128 Pixel, einmalig beim Import. Danach ist es eine
Bitmap wie jede andere. Die Werkstatt zeigt den DROME aber mehr als doppelt
so gross -- 128 Pixel auf 300 hochgezogen sind sichtbar verpixelt, und zwar
genau an den langen Diagonalen, aus denen die Iso-Ansicht besteht.

Das ist kein Stilmittel. Der Grafikstil dieses Projekts ist ausdruecklich
*kein* Pixelart (docs/GAME_DESIGN.md, Abschnitt 2): SVG wurde gewaehlt, damit
Teile aufloesungsfrei skalieren. Ein zu grob gerasterter Import gibt genau
diesen Vorteil wieder her.

Deshalb rastert das Projekt mit ``IMPORT_SCALE`` und rechnet in der Engine
wieder zurueck: ``IsoView.fit_sprite()`` setzt jedem Sprite die Skalierung
128 / Texturbreite. Alle Positionsrechnungen bleiben dadurch im 128er
Entwurfsraum -- Anker, Bodenraute und Zeichenreihenfolge muessen nichts von
der Rasterung wissen. Die Engine liest den Faktor NICHT aus dieser Datei; sie
misst ihn an der Textur. Wer hier eine andere Zahl einsetzt, muss deshalb
nichts im Code nachziehen.

Mipmaps kommen mit: die Kampfansicht zeigt dieselbe Textur verkleinert
(Kamerazoom 0.62), und eine 512er Textur ohne Mipmaps flimmert beim
Verkleinern staerker, als sie beim Vergroessern gewinnt.

Aufruf
------
    python3 tools/set_import_scale.py            # schreibt die .import-Dateien
    python3 tools/set_import_scale.py --check    # nur pruefen, nichts schreiben

Danach einmal importieren lassen, sonst liegt im Cache noch die alte Rasterung:

    godot --headless --path . --import
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
ASSETS_DIR = ROOT / "assets"

# Vierfach. Die Werkstatt zeigt den DROME mit Faktor 2.4, ein Retina-Desktop
# legt nochmal zu -- 4 deckt beides ab und bleibt eine Zweierpotenz, was der
# Mipmap-Kette entgegenkommt. Hoeher waere Speicher fuer nichts: mehr als
# 512 Pixel je Bauteil zeigt keine der beiden Ansichten.
IMPORT_SCALE = 4.0

SETTINGS = {
    "svg/scale": f"{IMPORT_SCALE}",
    "mipmaps/generate": "true",
}


def patch(text: str) -> str:
    """Setzt die Werte in einer .import-Datei. Fehlende Zeilen kommen dazu."""
    for key, value in SETTINGS.items():
        pattern = re.compile(rf"^{re.escape(key)}=.*$", re.MULTILINE)
        if pattern.search(text):
            text = pattern.sub(f"{key}={value}", text)
        else:
            text = text.rstrip("\n") + f"\n{key}={value}\n"
    return text


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="nur pruefen, ob alle Dateien schon so stehen")
    args = parser.parse_args()

    stale: list[pathlib.Path] = []
    for import_path in sorted(ASSETS_DIR.glob("**/*.svg.import")):
        current = import_path.read_text(encoding="utf-8")
        wanted = patch(current)
        if current == wanted:
            continue
        stale.append(import_path)
        if not args.check:
            import_path.write_text(wanted, encoding="utf-8")

    if args.check:
        if stale:
            for path in stale:
                print(f"[veraltet] {path.relative_to(ROOT)}")
            print(f"\n{len(stale)} Datei(en) veraltet -- "
                  f"tools/set_import_scale.py laufen lassen.", file=sys.stderr)
            return 1
        print(f"Alle .import-Dateien stehen auf svg/scale={IMPORT_SCALE}.")
        return 0

    print(f"[ok] svg/scale={IMPORT_SCALE} gesetzt, "
          f"{len(stale)} Datei(en) geaendert. Jetzt einmal:\n"
          f"     godot --headless --path . --import")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
