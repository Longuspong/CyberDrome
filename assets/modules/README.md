# Modul-Symbole

Je Modul ein SVG: `assets/modules/<modul-id>.svg` -- die IDs stehen in
`data/modules.json` (z. B. `mod_rapid_fire.svg` fuer Schnellfeuer).
Uebersicht der aktuellen Symbole: `docs/modul_symbole.png`.

* **Format:** `width="64" height="64" viewBox="0 0 64 64"`, Hintergrund
  transparent. Das Spiel legt das Symbol in den Chip (dunkle Flaeche, Rand
  in der Klassenfarbe) und rastert es vierfach (`tools/set_import_scale.py`).
* **Farben frei.** Die Platzhalter nutzen die Klassenfarben: Angriff
  `#ff7366`, Abwehr `#66b3ff`, Taktik `#ffd159`, Akzent `#e8eef6`.
  Ruhende Module blendet das Spiel selbst ab.
* **Klein lesbar halten:** der Chip ist an den Haltern nur ~36 px gross --
  kraeftige Linien (Strich 4 bei 64er Raster), wenig Details.
* **Anderer Dateiname:** in `data/modules.json` beim Modul `"icon":
  "res://pfad/zur/datei.svg"` eintragen.
* Fehlt die Datei, zeigt der Chip zwei Buchstaben (`short`).

Nach dem Ablegen oder Austauschen einmal:

    python3 tools/set_import_scale.py
    godot --headless --path . --import
