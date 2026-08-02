# Godot-Integration

Vorausschau, damit die Werkstatt nichts produziert, was spaeter nicht in die
Engine passt. Es gibt noch kein Godot-Projekt im Repo.

---

## Die entscheidende Einschraenkung

**Godot rendert SVG nicht zur Laufzeit.** Der Import rastert eine SVG-Datei
beim Einlesen einmalig zu einer Textur (`scale`-Faktor im Import-Dialog).
Zur Laufzeit ist das eine ganz normale Bitmap.

Das bedeutet:

* Modulares Zusammensetzen findet **in der Szene** statt, nicht in einer
  SVG-Datei: ein `Node2D` pro Drone, darunter ein `Sprite2D` je Teil.
* Umfaerben zur Laufzeit passiert ueber **Shader oder `modulate`**, nicht ueber
  CSS-Variablen. Die CSS-Variablen sind ein reines Autoren-Werkzeug.

Daraus ergeben sich zwei gangbare Pipelines.

---

## Pipeline A – Teile einzeln importieren (empfohlen)

Jedes Teil-SVG wandert als eigene Textur nach Godot. Die Drone wird in der
Szene zusammengesetzt.

```
Drone (Node2D)
├── Feet   (Sprite2D)
├── Body   (Sprite2D)
├── Core   (Sprite2D)
├── EquipL (Sprite2D)
├── EquipR (Sprite2D)
└── Head   (Sprite2D)
```

Die `z_index`-Werte stehen **pro Richtung** in `slot_z` des Koerper-Teils und
sind nichts anderes als die Kameratiefe des jeweiligen Ankers. Sie muessen beim
Richtungswechsel mitgesetzt werden – dann stimmt die Ueberdeckung von selbst
(in der Nordansicht rutscht die Ausruestung hinter den Koerper, ein
Schulterpod vor den Kopf).

**Vorteile**

* Jede Kombination ohne neuen Export-Lauf – genau der Punkt, wegen dem das
  Projekt auf SVG setzt.
* Teile lassen sich einzeln animieren (Rueckstoss, Trefferzucken, Wippen).
* Ein Chassis-Wechsel tauscht eine Textur, nicht eine ganze Drone.

**Zu beachten**

* Alle Teile mit **demselben Import-`scale`** importieren. Da alle Teile im
  gleichen 128×128-Raum liegen, ist jede Teil-Textur gleich gross und die
  Sprites liegen bei identischer Position automatisch korrekt uebereinander –
  Offsets aus der JSON sind dann gar nicht noetig.
* `Sprite2D.centered = false` und alle Teile auf Position `(0,0)`. Die
  Anker-Mathematik steckt bereits in der Grafik.
* `z_index` je Richtung aus `slot_z` uebernehmen (siehe oben). Wer das
  vergisst, bekommt Waffen, die in der Nordansicht vor dem Ruecken schweben.
* Die Perspektive ist isometrisch (Kamera 45 Grad, Bodenfeld als Raute im
  Verhaeltnis sqrt(2):1). Ein TileMap mit Modus *Isometric* und passendem
  Zellverhaeltnis deckt sich mit der Raute, die das Werkzeug einblendet.

### Farben zur Laufzeit

Da die CSS-Variablen beim Rastern zu festen Farben werden, gibt es zwei Wege:

1. **Maskenkanaele (robust).** Teile mit flachen, eindeutigen Palettenfarben
   exportieren; ein Shader ersetzt sie per Lookup gegen die Fraktionspalette.
   Genau dafuer ist der Farbrollen-Satz gedacht: acht klar getrennte Rollen.
2. **Pro-Palette rastern (einfach).** Fuer jede Fraktionspalette einen eigenen
   Import-Satz erzeugen. Kostet Speicher, braucht aber keinen Shader.

Fuer den ersten spielbaren Stand reicht Variante 2.

---

## Pipeline B – Fertige Bots exportieren

Der Export der Werkstatt (`builds/<name>.svg`) ist eine einzelne, standalone
SVG-Datei mit eingebetteter Palette. Sie laesst sich direkt in Godot importieren.

Sinnvoll fuer:

* NPCs und Bossgegner mit fester, nie wechselnder Bestueckung
* UI: Portraits, Loadout-Vorschau, Menue-Icons
* Marketing-Material und Mockups

Nicht sinnvoll fuer Spieler-Drones – die sollen ja frei kombinierbar sein.

Der Button **Alle 4 Richtungen** schreibt dafuer in einem Rutsch
`<name>_south.svg`, `_west`, `_east`, `_north` plus `<name>_sheet.svg`
(alle vier Frames nebeneinander, 512×128) – letzteres passt direkt auf ein
`AtlasTexture` mit 128er-Region-Schritten.

---

## Import-Einstellungen

| Ziel | Empfohlener SVG-Import-`scale` | Ergebnis pro Teil |
|---|---|---|
| Mobile, 1× | 2 | 256 × 256 px |
| Desktop / HiDPI | 4 | 512 × 512 px |

Die Werkstatt liefert zusaetzlich einen PNG-Export mit frei waehlbarer
Kantenlaenge – nuetzlich, um eine Aufloesung zu pruefen, bevor der ganze Satz
importiert wird.

---

## Loadout-JSON

Neben jedem Build-SVG liegt eine `.json`, die exakt beschreibt, wie der Bot
zusammengesetzt ist:

```jsonc
{
  "name": "demo_juggernaut",
  "set": "bot2",
  "direction": "south",
  "origin": { "x": 64, "y": 64 },
  "ground_y": 96,                  // Mittelpunkt des Bodenfeldes im Sprite
  "palette": { "plate": "#3a2a33", "accent": "#ff8a3d", "…": "…" },
  "slots": {
    "body":       { "part_id": "jugg_body",       "offset": {"x":0,"y":0}, "scale":1, "rotate":0, "flip":false, "z":null },
    "head":       { "part_id": "jugg_head",       "…": "…" },
    "equip_right":{ "part_id": "eq_siege_cannon", "flip": true, "…": "…" }
  }
}
```

`part_id` ist richtungsunabhaengig. Ein Godot-Loader kann daraus die Texturen
`res://parts/<set>/<part_id>_<direction>.png` aufloesen und die vier Ansichten
aus einer einzigen Loadout-Datei bauen. Das ist der Grund fuer die
richtungslosen IDs.

`offset`, `scale`, `rotate` und `flip` sind die in der Werkstatt vorgenommenen
Feinjustierungen und muessen beim Aufbau in der Szene mit uebernommen werden
(`Sprite2D.position`, `.scale`, `.rotation`, `.flip_h`).

---

## Empfohlene Reihenfolge

1. Teilesatz in der Werkstatt bauen und Anker sauber setzen.
2. Pipeline A aufsetzen: ein Godot-Loader, der eine Loadout-JSON liest und die
   `Sprite2D`-Kinder erzeugt. Damit ist die Kombinatorik erledigt.
3. Erst danach Kampfsystem und Map. Solange die Darstellung nicht steht, ist
   jede Regelarbeit Spekulation.
4. Farb-Shader zuletzt – bis dahin genuegt ein Import-Satz je Palette.
