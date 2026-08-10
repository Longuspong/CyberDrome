# Godot-Integration

Vorausschau, damit die Werkstatt nichts produziert, was spaeter nicht in die
Engine passt. Es gibt noch kein Godot-Projekt im Repo.

> **Engine-Version: 4.7.** Sie steht an drei Stellen und muss an allen dreien
> zusammenpassen: `project.godot` (`config/features`), der Session-Hook
> (`.claude/hooks/session-start.sh`, Version **und** SHA-256) und dieser
> Absatz. Was beim Umstieg von 4.3 auf 4.7 zu beachten war, steht unten unter
> *Engine-Wechsel*.

---

## Die entscheidende Einschraenkung

**Godot rendert SVG nicht zur Laufzeit.** Der Import rastert eine SVG-Datei
beim Einlesen einmalig zu einer Textur (`scale`-Faktor im Import-Dialog).
Zur Laufzeit ist das eine ganz normale Bitmap.

Das bedeutet:

* Modulares Zusammensetzen findet **in der Szene** statt, nicht in einer
  SVG-Datei: ein `Node2D` pro DROME, darunter ein `Sprite2D` je Teil.
* Umfaerben zur Laufzeit passiert ueber **Shader oder `modulate`**, nicht ueber
  CSS-Variablen. Die CSS-Variablen sind ein reines Autoren-Werkzeug.

Daraus ergeben sich zwei gangbare Pipelines.

---

## Pipeline A – Teile einzeln importieren (empfohlen)

Jedes Teil-SVG wandert als eigene Textur nach Godot. Die DROME wird in der
Szene zusammengesetzt.

```
DROME (Node2D)
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
* Ein Chassis-Wechsel tauscht eine Textur, nicht eine ganze DROME.

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

Nicht sinnvoll fuer Spieler-DROMEs – die sollen ja frei kombinierbar sein.

Der Button **Alle 4 Richtungen** schreibt dafuer in einem Rutsch
`<name>_south.svg`, `_west`, `_east`, `_north` plus `<name>_sheet.svg`
(alle vier Frames nebeneinander, 512×128) – letzteres passt direkt auf ein
`AtlasTexture` mit 128er-Region-Schritten.

---

## Import-Einstellungen

| Ziel | SVG-Import-`scale` | Ergebnis pro Teil |
|---|---|---|
| Mobile, 1× | 2 | 256 × 256 px |
| Desktop / HiDPI | **4 (eingestellt)** | 512 × 512 px |

Gesetzt wird das nicht von Hand in 114 `.import`-Dateien, sondern von
`tools/set_import_scale.py`; danach einmal `godot --headless --path . --import`,
sonst liegt im Cache noch die alte Rasterung.

**Warum ueberhaupt hochskaliert wird.** Godot rastert ein SVG in seiner
Nenngroesse -- aus `width="128"` werden 128 Pixel, und danach ist es eine Bitmap
wie jede andere. Die Werkstatt zeigt den DROME mit Faktor 2,4; 128 Pixel auf
ueber 300 gezogen sind sichtbar verpixelt, und zwar genau an den langen
Diagonalen, aus denen die Iso-Ansicht besteht. Der Grafikstil dieses Projekts
ist ausdruecklich *kein* Pixelart -- ein zu grob gerasterter Import gibt genau
den Vorteil wieder her, fuer den SVG gewaehlt wurde.

**Und warum das im Code nichts kostet.** Die Engine rechnet jeden Sprite ueber
`IsoView.fit_sprite()` auf den 128er Entwurfsraum zurueck, und zwar mit einem
Faktor, den sie an der Textur MISST. Damit bleiben Bodenraute, Anker und
Zeichenreihenfolge unveraendert, und die Rasterung laesst sich aendern, ohne
eine Zeile Code anzufassen. Mipmaps stehen mit an: dieselbe Textur wird im
Kampf verkleinert gezeigt (Kamerazoom 0,62), und eine 512er Textur ohne
Mipmaps flimmert beim Verkleinern mehr, als sie beim Vergroessern gewinnt.

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
    "body":       { "part_id": "jugg_body", "code": "CHS-002", "name": "Molok Chassis",
                    "offset": {"x":0,"y":0}, "scale":1, "rotate":0, "flip":false, "z":null },
    "head":       { "part_id": "jugg_head", "code": "HED-002", "…": "…" },
    "equip_right":{ "part_id": "eq_siege_cannon", "code": "EQP-003", "…": "…" }
  }
}
```

`code` ist die stabile Kennung fuers Game Design, `name` der Klarname – beide
sind redundant zur `part_id`, machen ein Loadout aber ohne die Bibliothek
lesbar. `part_id` ist richtungsunabhaengig. Ein Godot-Loader kann daraus die Texturen
`res://parts/<set>/<part_id>_<direction>.png` aufloesen und die vier Ansichten
aus einer einzigen Loadout-Datei bauen. Das ist der Grund fuer die
richtungslosen IDs.

`offset`, `scale`, `rotate` und `flip` sind die in der Werkstatt vorgenommenen
Feinjustierungen und muessen beim Aufbau in der Szene mit uebernommen werden
(`Sprite2D.position`, `.scale`, `.rotation`, `.flip_h`).

### Slotregeln gehoeren auch in die Engine

Ein Loadout sagt nur, was gesteckt *ist* -- nicht, ob es das darf. Ob ein Teil
in einen Slot gehoert, entscheiden `mount_class` / `category` der Ausruestung
gegen `slot_rules` des Koerpers (`parts/README.md`, Abschnitt 2a). Die Werkstatt
prueft das beim Bauen, aber eine Loadout-Datei kann von Hand entstehen, aus
einem aelteren Stand kommen oder spaeter aus einem Spielstand geladen werden.
Der Godot-Loader muss die Regel deshalb erneut anwenden -- sonst haelt sie nur
im Werkzeug, und genau dort braucht sie niemand.

---

## Empfohlene Reihenfolge

1. Teilesatz in der Werkstatt bauen und Anker sauber setzen.
2. Pipeline A aufsetzen: ein Godot-Loader, der eine Loadout-JSON liest und die
   `Sprite2D`-Kinder erzeugt. Damit ist die Kombinatorik erledigt.
3. Erst danach Kampfsystem und Map. Solange die Darstellung nicht steht, ist
   jede Regelarbeit Spekulation.
4. Farb-Shader zuletzt – bis dahin genuegt ein Import-Satz je Palette.

---

## Engine-Wechsel

Beim Umstieg von 4.3 auf 4.7 gemessen -- als Merkzettel fuer den naechsten:

**Was die Engine am Baum aendert.** 114 `.import`-Dateien bekommen neue
Parameter (`compress/uastc_level`, `compress/rdo_quality_loss`,
`process/channel_remap/*`), und ab 4.4 legt Godot je Skript eine `.uid` an --
41 Dateien, zusammen gut zwei Kilobyte. Beide gehoeren ins Repo: die `.uid`
sind stabile Kennungen, mit denen Szenen ihre Skripte auch nach dem
Verschieben wiederfinden.

**Was der Editor am Baum aendert.** `project.godot` wird beim Speichern neu
geschrieben, samt Ersetzen des Kopfkommentars durch den englischen
Standardtext. Der Hinweis steht jetzt in der Datei selbst.

**Was NICHT anders wurde.** Der Zufallsgenerator: `randi`, `randf` und
`randi_range` liefern bei gleichem Seed bitgleiche Folgen. Und der
SVG-Rasterizer kennt weiterhin keine CSS-Variablen -- ein Quell-SVG rastert
auch unter 4.7 zu genau einer Farbe, `#000000`. Der Bake-Schritt bleibt also.

**Was still gebrochen war und den Umstieg fast ueberlebt haette.**
`TerrainDB.pick_region()` sortierte die Region-IDs mit `Array.sort()`. Unter
4.3 waren die Schluessel `String` und wurden alphabetisch sortiert; unter 4.7
sind sie `StringName`, und deren Vergleich laeuft ueber die interne Adresse.
Ergebnis: **derselbe Seed, eine andere Karte** -- bei identischer
Zufallsfolge. Die Reproduzierbarkeits-Tests haben das nicht gesehen, weil sie
zwei Laeufe *derselben* Engine vergleichen.

Daraus die Regel: **auf `StringName` nie `sort()`**, immer
`sort_custom(func(a, b): return str(a) < str(b))`. Und ein Test, der
Reproduzierbarkeit sichern soll, muss den INHALT der Reihenfolge festhalten,
nicht die Gleichheit zweier Laeufe
(`tests/test_battle.gd`,
`test_region_choice_follows_the_alphabet_not_the_memory_layout`).
