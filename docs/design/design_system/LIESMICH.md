# Design-System „CyberDrome Arcade-Glitch“ -- Sicherung im Repo

Spiegel des Artefakts https://claude.ai/artifact/M5RC8KNDTr5psmKSuJpdS2
(Artefakt-Typ „Design System“, angelegt 17. Nov. 2026). Wie die SPOT ein
Spiegel des Spiels: es beschreibt den Stil, das Spiel bleibt die Quelle.

| Hier | Im Artefakt unter `project/` |
|---|---|
| `README.md` | Brand-Book (Regeln fuer Farbe, Schrift, Form, Aufbau, Effekte) |
| `components/<Name>/README.md`, `preview.html` | 20 Komponenten mit Regeln und Vorschau |
| `components/bundle.css` | das CSS der Vorschauen (nur Token-Variablen) |
| `assets/<Gruppe>/README.md` | Hinweise je Bildgruppe (Icons, Modules, Screens, App) |
| `design-system.json` | Index des Artefakts: Titel, Bildgruppen mit den IDs der hochgeladenen Bilder |
| -- `../tokens.json` | `tokens.json` (erzeugt von `tools/build_spot.py`, nicht doppelt abgelegt) |
| -- `assets/fonts/*.ttf`, `OFL_*.txt` | `fonts/` (nicht doppelt abgelegt) |

Die Bilder (82 UI-Symbole, 27 Modul-Symbole, 24 Entwuerfe, App-Icon) liegen
im Spiel unter `assets/ui_icons/`, `assets/modules/`,
`docs/design/einsatz_arcade/bilder/`, `assets/icon/` und sind im Artefakt
hochgeladen; die Vorschauen verweisen auf sie als `/_blob/<id>` (IDs in
`design-system.json`).

## Aendern

1. Farben und Werte: in `docs/spot/inhalte.json` (`design_farben`,
   `design_tokens`), dann `python3 tools/build_spot.py`.
2. Texte und Komponenten: hier bearbeiten.
3. Ins Artefakt uebernehmen: einen Ordner mit `project/` anlegen (diese
   Dateien, dazu `project/tokens.json` = `docs/design/tokens.json`) und mit
   dem Artifact-Werkzeug an die URL oben veroeffentlichen; den Index
   (`design-system.json`) vorher frisch lesen und nur `lastChange` bzw.
   geaenderte Bildgruppen anpassen. Die Anleitung des Typs steht im Artefakt
   unter `SKILL.md`.
4. Umgekehrt: wer im Artefakt selbst etwas aendert, liest die Dateien danach
   hierher zurueck.
