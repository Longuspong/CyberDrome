# ModuleChip

Ein Modul als Kartusche: abgeschraegt wie die Knoepfe (Ecke oben links und unten rechts), Rand in der Farbe der Modulklasse, oben rechts die Klassen-Ecke mit dem Klassenzeichen, in der Mitte gross das Modul-Symbol.

## Klassen
| Klasse | Farbe | Zeichen in der Klassen-Ecke |
|---|---|---|
| Angriff | `module-attack` | Spitze `class_attack` |
| Abwehr | `module-defense` | Bogen `class_defense` |
| Taktik | `module-tactic` | Punkt `class_tactic` |
| BIOS | `module-bios` | `bios` |

## Varianten
- **Mit Symbol** (Gruppe Modules, `assets/modules/<id>.svg`, 64 x 64, eigene Farben): 62 % der Kartusche, mittig.
- **Ohne Symbol**: zwei Buchstaben in der Mitte (Schnellfeuer = SF).
- **Fusion** (`cd-chip-mod--recipe`): doppelter Rahmen. Auch die BIOS-Fusion.
- **Ruhend** (`cd-chip-mod--dim`): Bedingung passt nicht zur Waffe -- abgeblendet.

## Regeln
- Ueberall gleich gross: **52 px** im Laden, im Lager und in der Waffe. Andere Groessen nur in Popups und in der Zug-Vorschau.
- Grund `module-fill`, Rand 2 px in der Klassenfarbe, Klassen-Ecke 29 % der Kante, Zeichen darin in `night`.
- Die Klasse steht immer auch als Zeichen da, nicht nur als Farbe.
- Name des Moduls im Popup bzw. darunter; die Kartusche allein ist kein Text.
- Freier Platz: gestricheltes Quadrat gleicher Groesse in `empty-line`.

Nachgebaut aus `ModuleChip` (`scripts/ui/module_chip.gd`) und `ModuleData.CLASS_COLOR`.
