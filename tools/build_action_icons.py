#!/usr/bin/env python3
"""
Erzeugt die Aktionssymbole nach assets/icons/.

    python3 tools/build_action_icons.py

Warum ein Generator und keine acht handgezeichneten Dateien: dieselbe
Begruendung wie bei tools/build_sample_parts.py. Die Symbole teilen sich ein
Raster, eine Strichstaerke und einen Rand; von Hand gezeichnet laufen genau
diese drei auseinander, und dann sitzt ein Symbol im Knopf zwei Pixel hoeher
als das daneben. Hier stehen sie einmal oben und gelten fuer alle.

### Warum einfarbig

Die Symbole werden im Spiel eingefaerbt -- weiss fuer bedienbar, grau fuer
gesperrt, gelb fuer gewaehlt. Ein mehrfarbiges Symbol laesst sich nicht
einfaerben, ohne dass seine Farben etwas anderes bedeuten als vorher. Sie sind
deshalb bewusst monochrom (currentColor-Ersatz: schlicht weiss), und die
Bedeutung traegt die FORM.

### Warum sie Platzhalter sind und trotzdem nach Regeln entstehen

Gezeichnet ist hier nichts, was bleiben muss. Die Zuordnung dagegen schon: ein
Symbol haengt an dem, was eine Aktion TUT (zieht, stoesst, provoziert,
repariert, trifft eine Flaeche), nicht an ihrer ID. Ein neues Bauteil mit einer
Zugaktion bekommt sein Symbol dadurch ohne eine Zeile Code -- und zwar
dasselbe, das der Orbit-Sog schon hat. Die Regel steht in
scripts/ui/action_icons.gd; hier stehen nur die Bilder dazu.
"""

import pathlib
import re

ICONS_DIR = pathlib.Path(__file__).resolve().parent.parent / "assets" / "icons"

SIZE = 64
STROKE = 5.0
COLOR = "#ffffff"

HEADER = (
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}" '
    'width="{size}" height="{size}">\n'
    "  <!-- {note} -->\n"
    '  <g fill="none" stroke="{color}" stroke-width="{stroke}" '
    'stroke-linecap="round" stroke-linejoin="round">\n'
)
FOOTER = "  </g>\n</svg>\n"


def comment_body(text: str) -> str:
    """
    Kommentartext, der in einem XML-Kommentar stehen DARF.

    ``--`` ist dort verboten, und der Gedankenstrich steht in diesem Projekt in
    fast jedem erklaerenden Satz. Browser und Godot sehen darueber hinweg, ein
    strikter Parser nicht. Dieselbe Vorsichtsmassnahme steht in
    tools/build_sample_parts.py und aus demselben Grund.
    """
    return re.sub(r"-{2,}", "-", text).rstrip("-")


def svg(note: str, body: str) -> str:
    return (
        HEADER.format(size=SIZE, note=comment_body(note), color=COLOR,
                      stroke=STROKE)
        + body
        + FOOTER
    )


def arrow(x1: float, y1: float, x2: float, y2: float, head: float = 9.0) -> str:
    """Linie mit Spitze am Ende (x2, y2)."""
    import math

    angle = math.atan2(y2 - y1, x2 - x1)
    left = (x2 - head * math.cos(angle - 0.5), y2 - head * math.sin(angle - 0.5))
    right = (x2 - head * math.cos(angle + 0.5), y2 - head * math.sin(angle + 0.5))
    return (
        f'    <path d="M{x1:.1f} {y1:.1f} L{x2:.1f} {y2:.1f}"/>\n'
        f'    <path d="M{left[0]:.1f} {left[1]:.1f} L{x2:.1f} {y2:.1f} '
        f'L{right[0]:.1f} {right[1]:.1f}"/>\n'
    )


# ---------------------------------------------------------------------------
# Die Symbole. Reihenfolge = Reihenfolge der Regel in action_icons.gd.
# ---------------------------------------------------------------------------

ICONS = {
    # Reparatur: das Kreuz. Die eine Form, die in diesem Genre niemand
    # missversteht.
    "heal": (
        "Reparatur -- Kreuz",
        '    <path d="M32 16 L32 48"/>\n'
        '    <path d="M16 32 L48 32"/>\n',
    ),
    # Provokation: ein Sender mit Wellen. Nicht "Ziel", sondern "hierher" --
    # der Koedersender zwingt, er trifft nicht.
    "taunt": (
        "Provokation -- Sender mit Wellen",
        '    <path d="M32 46 L32 26"/>\n'
        '    <circle cx="32" cy="20" r="5"/>\n'
        '    <path d="M18 44 A20 20 0 0 1 18 20"/>\n'
        '    <path d="M46 44 A20 20 0 0 0 46 20"/>\n',
    ),
    # Heranziehen: zwei Pfeile nach innen auf einen Punkt.
    "pull": (
        "Sog -- zwei Pfeile nach innen",
        '    <circle cx="32" cy="32" r="4"/>\n'
        + arrow(10, 32, 23, 32)
        + arrow(54, 32, 41, 32),
    ),
    # Wegstossen: dieselbe Figur, umgedreht. Beide Aktionen sind Gegenstuecke
    # und sollen auch so aussehen.
    "push": (
        "Stoss -- zwei Pfeile nach aussen",
        '    <circle cx="32" cy="32" r="4"/>\n'
        + arrow(23, 32, 10, 32)
        + arrow(41, 32, 54, 32),
    ),
    # Flaechenwirkung: konzentrische Ringe. Der Radius IST die Aussage.
    "blast": (
        "Flaechenwirkung -- konzentrische Ringe",
        '    <circle cx="32" cy="32" r="6"/>\n'
        '    <circle cx="32" cy="32" r="15"/>\n'
        '    <circle cx="32" cy="32" r="24"/>\n',
    ),
    # Nahkampf: der Hammer. Reichweite 1 ist im Bestand die Ausnahme und muss
    # sich auf einen Blick von allem Geschossenen unterscheiden.
    #
    # Erster Entwurf war eine Klinge aus einer Diagonale mit Spitze -- und die
    # las sich bei 46 Pixeln als Pfeil, also als Bewegung. Der Kopf ist deshalb
    # eine GEFUELLTE Flaeche: eine Masse am Ende eines Stiels ist die einzige
    # Form hier, die man nicht mit einer Richtung verwechseln kann.
    "melee": (
        "Nahkampf -- Hammer",
        '    <path d="M14 50 L34 30"/>\n'
        '    <path d="M32 16 L50 34 L42 42 L24 24 Z" fill="#ffffff"/>\n',
    ),
    # Fernkampf: Fadenkreuz. Die Grundlinie -- alles, was schiesst und sonst
    # nichts weiter tut.
    "shot": (
        "Fernkampf -- Fadenkreuz",
        '    <circle cx="32" cy="32" r="15"/>\n'
        '    <path d="M32 8 L32 17"/>\n'
        '    <path d="M32 47 L32 56"/>\n'
        '    <path d="M8 32 L17 32"/>\n'
        '    <path d="M47 32 L56 32"/>\n',
    ),
    # Faellt nichts anderes zu. Erscheint nur, wenn jemand eine Aktion baut,
    # die keine der Regeln oben trifft.
    #
    # Bewusst ein leerer Rahmen und nichts Gegenstaendliches: dieses Symbol
    # sagt "hier fehlt eines". Der erste Entwurf war ein Kreis mit vier
    # Strichen und damit dem Fadenkreuz zum Verwechseln aehnlich -- eine
    # unbekannte Aktion haette wie ein normaler Schuss ausgesehen, und das ist
    # schlimmer als gar kein Symbol.
    "generic": (
        "Ohne eigene Form -- leerer Rahmen",
        '    <rect x="14" y="14" width="36" height="36" rx="5"/>\n'
        '    <circle cx="32" cy="32" r="3.5" fill="#ffffff" stroke="none"/>\n',
    ),
}


def main() -> None:
    ICONS_DIR.mkdir(parents=True, exist_ok=True)
    for name, (note, body) in ICONS.items():
        path = ICONS_DIR / f"act_{name}.svg"
        path.write_text(svg(note, body), encoding="utf-8")
        print(f"  {path.relative_to(ICONS_DIR.parent.parent)}")
    print(f"{len(ICONS)} Aktionssymbole geschrieben.")


if __name__ == "__main__":
    main()
