# Teile-Format (`/parts/`)

Alle Teile liegen hier, ein Ordner = ein **Set** (eine DROME-Familie). Die
Dateien werden **nicht von Hand** bearbeitet: der Generator
`tools/build_sample_parts.py` schreibt sie, `tools/bake_godot_assets.py` legt
die Kopie fuer Godot unter `assets/parts/` ab (das Spiel liest nur die Kopie).
Gezeichnet wird im Spiel das 3D-Modell (`DromeModel`), die SVG ist nur das
Symbol fuer Kacheln und Halter.

```
parts/
  bot1/                     RX-Vireo // Scout
    set.json                Set-Beschreibung + Standardpalette
    scout_body.m3d          3D-Modell (Flaechen, Anker, Varianten, Farben)
    scout_body_south.svg    Symbol (Suedansicht)
    scout_body_south.json   Metadaten + Spielwerte (gleicher Dateiname)
  bot2/                     HX-Molok // Juggernaut
  bot3/                     AR-Nimbus // Technomant
  bot4/                     LR-Strix // Marksman
```

Ein DROME besteht aus **Chassis** (`body`), **Kopf** (`head`), **Antrieb**
(`feet`), **Kern** (`core`) und seinen **Waffen** (`equipment`). Kopf, Antrieb
und Kern gehoeren fest zum Chassis; getauscht werden nur Waffen.

---

## 1. Metadaten-JSON (`<id>_south.json`)

| Feld | Bedeutung |
|---|---|
| `id` | Teil-ID ohne Richtung (`scout_body`) -- das speichern Loadouts |
| `code` | Teile-Code, siehe 2 |
| `set`, `type`, `name` | Set-Ordner, Teiletyp, Klarname |
| `svg`, `view_box`, `anchors`, `z_index`, `slot_z` | das Symbol und wie es zusammengesetzt wird |
| `color_scheme` | die acht Farbrollen (plate, plate_light, plate_dark, metal, accent, glow, visor, outline) |
| `tags` | Stichworte (`light`, `ranged` ...) |
| `stats` | Spielwerte (`hp`, `spd`, `def`, `shield`, `power`, `efficiency` ...), dazu `actions` (Angriff + Faehigkeit der Waffe) und am Chassis `ai_role` (KI-Rolle) und `passive` |
| nur Chassis: `body_kind`, `slot_rules` | Koerperart, Halterregeln (3) |
| nur Waffe: `mount_class`, `category`, `pose` | Klasse, Bauart, Haltung (`hold` / `aim`) |

Die Werte kommen aus der Tabelle `STATS` im Generator; die Zahlen der
Passiven stehen in `data/config.json` unter `passives`.

## 2. Teile-Code

Stabile Kennung fuers Game Design, unabhaengig vom Dateinamen:

| Praefix | Teiletyp |
|---|---|
| `CHS` | Chassis |
| `HED` | Kopf |
| `LEG` | Antrieb |
| `COR` | Kern |
| `EQP` | Waffe |

Format: drei Grossbuchstaben, Bindestrich, drei- bis vierstellige Nummer
(`CHS-001`, `EQP-0042`), je Typ fortlaufend ueber alle Sets. Codes sind
projektweit eindeutig, der Generator bricht bei einer Kollision ab.

## 3. Halter: Montageklasse und Bauart

Jeder Anker des Chassis, dessen Name mit `equip_` beginnt, ist ein Halter --
ausser die Halterregel schaltet ihn ab (`"off": true`). Was hineinpasst,
sagen zwei Felder auf der Waffe und die Regel auf dem Chassis:

| Feld | wo | Werte |
|---|---|---|
| `mount_class` | Waffe | `light` < `medium` < `heavy` (fehlt: `light`) |
| `category` | Waffe | `weapon` · `shield` · `support` (fehlt: `weapon`) |
| `slot_rules` | Chassis | je Halter `max_class`, `categories`, `reach`, `off` |

Eine Waffe passt, wenn ihre Klasse die `max_class` nicht ueberschreitet
**und** ihre `category` in `categories` steht (fehlt `categories`: alle).
`reach: "ranged"` laesst nur Fernkampf zu. Heute:

| Halter | nimmt |
|---|---|
| `bot1` Vireo | bis `light`, Waffe oder Support |
| `bot2` Molok, beide Arme (`equip_left`, `equip_right`) | bis `medium` |
| `bot3` Nimbus | bis `medium`, Waffe oder Support |
| `bot4` Strix (`equip_center`) | bis `heavy`, nur Fernkampf |

Der Generator prueft die Regeln bei jedem Lauf (`check_slot_rules`).

## 4. 3D-Modelle und Arme

Je Teil schreibt der Generator ein Modell `<id>.m3d` (JSON): `faces`
(`[Material, Art, Normale, Punkte]`, bot-lokal vorn/links/hoch; Art `box` mit
Kante, `disc` mit Randkante, `seam` ohne), `hulls` (Aussenkontur der
Drehkoerper), `anchors` (3D), `variants` (Waffenmass, Lafette, am Chassis die
Arme), `colors`, `pose`.

**Arme gehoeren zum Chassis.** Eine Waffe ist nur das Geraet in der Hand: ihr
`mount` ist der Griffpunkt. Den Arm bringt das Chassis als Variante
`arm_<slot>_<haltung>` mit den Ankern `mount` (Schultersockel) und `hand`.
Die Waffe sagt per `pose`, welche Haltung sie braucht: `hold` (Faust um den
Griff) oder `aim` (Manschette). Waffen ohne `pose` (Strix-Lafette) sitzen
direkt am Sockel.

```
arm.position    = chassis.anker[slot] - arm.anker["mount"]
waffe.position  = arm.anker["hand"]   - waffe.anker["mount"]
```

`links` und `rechts` meinen die Seiten des DROME, nicht den Bildschirm.
Waffen werden nie gespiegelt (`docs/DROME_DESIGNREGELN.md`).

## 5. Lesbarkeitsregel: keine zwei Funktionen mit derselben Silhouette

Zwei Waffen mit unterschiedlicher Spielfunktion muessen sich an der
**Silhouette** unterscheiden, nicht an der Groesse -- der Spieler muss einer
Waffe ansehen, was sie kann. Ein Merkmal liegt auf der Aussenkante und macht
dort eine eigene Form (langer duenner Lauf = Praezision, gedrungen und breit =
Artillerie), nicht eine Struktur in der Flaeche, die bei 40 Pixeln
verschwindet.

Der Generator misst die gefuellte Umrissflaeche aus Sued und Ost, uniform
normiert (gleiche Form, andere Groesse = identisch), und bricht bei Waffen ab,
wenn zwei Funktionen zu aehnlich sind (`check_silhouettes`). Als Pruefstein
bewahrt er `EQ_CANNON_V1` auf: eine Waffe, die nur ein groesser gezogener
Blaster ist -- der Test muss sie weiter finden.

## 6. Sitzregel: der Kern gehoert INS Chassis

Ein Kern ist kein Anbauteil. Er sitzt in einem Schacht der Brust- oder
Rueckenplatte und darf hoechstens eine Entwurfseinheit herausstehen -- sonst
liest er sich als aufgeklebte Plakette statt als Teil des Rahmens. Regelfall
ist die Brust; wo sie besetzt ist, der Ruecken (der Strix traegt seinen Kern
im Gegengewichts-Ausleger, weil vor seiner Brust die Lanze liegt). Der
Generator misst das und bricht ab (`check_core_seat`).

## 7. Neues Teil anlegen

1. Das Teil im Generator als Koerper-Definition beschreiben (Quader `B`,
   Scheibe `D`, Rotationskoerper `L` fuer alles Runde) und in `STATS`
   eintragen.
2. `python3 tools/build_sample_parts.py` -- schreibt Modell, Symbol und JSON
   und prueft Halter, Sitz und Silhouetten.
3. `python3 tools/bake_godot_assets.py` -- Kopie fuer Godot.
4. Tests: `godot --headless --path . --script res://tests/run_tests.gd`.

Ansehen ohne Spiel: die Render-Helfer unter `docs/design/drome_entwurf/godot/`.

## 8. Namenskonvention

`<teil-id>.m3d`, `<teil-id>_south.svg`, `<teil-id>_south.json`, z. B.
`scout_body_south.json`. Die `id` im JSON bleibt `scout_body`, ohne Richtung.
