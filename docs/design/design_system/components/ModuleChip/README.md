# ModuleChip

Ein Modul als kleiner Chip: Gehaeuse mit drei Beinchen je Seite, Rand in der Farbe der Modulklasse, darin das Modul-Symbol.

## Klassen
| Klasse | Farbe | Zeichen (ohne Symbol) |
|---|---|---|
| Angriff | `module-attack` | Spitze `class_attack` |
| Abwehr | `module-defense` | Bogen `class_defense` |
| Taktik | `module-tactic` | Punkt `class_tactic` |
| BIOS | `module-bios` | `bios` |

## Varianten
- **Mit Symbol** (Gruppe Modules, `assets/modules/<id>.svg`, 64 x 64, eigene Farben): fuellt 80 % des Chips.
- **Ohne Symbol**: Klassenzeichen oben, zwei Buchstaben in der Mitte (Schnellfeuer = SF).
- **Rezept** (`cd-chip-mod--recipe`): doppelter Rand.
- **Ruhend** (`cd-chip-mod--dim`): Bedingung passt nicht zur Waffe -- abgeblendet.

## Regeln
- Groesse 48 px, an den Haltern ~36 px; Grund `module-fill`.
- Die Klasse steht immer auch als Zeichen oder Symbol da, nicht nur als Farbe.
- Name des Moduls im Popup bzw. darunter; der Chip allein ist kein Text.

Nachgebaut aus `ModuleChip` (`scripts/ui/module_chip.gd`) und `ModuleData.CLASS_COLOR`.
