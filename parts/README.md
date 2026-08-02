# Teile-Format (`/parts/`)

Alles, was die SVG-Werkstatt zusammensetzt, liegt hier. Ein Ordner = ein
**Set** (eine Bot-Familie).

```
parts/
  bot1/                     <- Set-Ordner (Name = Set-ID, nur A-Z a-z 0-9 _ - .)
    set.json                <- optionale Set-Beschreibung + Standardpalette
    scout_body_south.svg    <- Grafik
    scout_body_south.json   <- Metadaten (gleicher Dateiname!)
    scout_body_north.svg
    scout_body_north.json
    ...
  bot2/
    ...
```

Der Server liest jede `*.json` (ausser `set.json`) als ein Teil und erwartet
daneben die gleichnamige `.svg`.

---

## 1. Die Kamera: 45 Grad von oben, isometrisch

Das Spiel schaut im 45-Grad-Winkel auf ein um 45 Grad gedrehtes Gitter. Ein
Bodenfeld wird dadurch zur **Raute im Verhaeltnis sqrt(2):1** -- im Tool
76 x 54 Pixel um den Mittelpunkt `(64, 96)`.

Weltkoordinaten (`px`, `py` = Gitterachsen, `pz` = Hoehe) projizieren so:

```
x = 64 + cos(45) * (px - py) * SCALE
y = 96 - (0.5 * (px + py) + cos(45) * pz) * SCALE
```

Daraus folgt alles, was ein Teil optisch richtig macht:

* Die Kamera steht in Richtung `(-1, -1, +1)`. Von jedem Quader sind deshalb
  **immer genau drei Flaechen sichtbar**: die `-px`-Flanke (auf dem Bildschirm
  nach unten-links), die `-py`-Flanke (unten-rechts) und die Oberseite.
* Weil der Bot 45 Grad zur Kamera steht, sieht man **zwei Flanken statt einer
  Frontflaeche**. Genau das unterscheidet Iso von einer Frontalansicht: eine
  schraeg stehende Kiste zeigt Volumen, eine frontale sieht flach aus.
* **Das Licht haengt am Bildschirm, nicht am Bot.** Oberseiten hell
  (`--c-plate-light`), linke Flanken mittel (`--c-plate`), rechte Flanken
  dunkel (`--c-plate-dark`). Dadurch wirken alle vier Richtungen wie vom
  selben Licht getroffen -- und deshalb ist Spiegeln auf dem Bildschirm
  **keine** gueltige Abkuerzung mehr (siehe Abschnitt 6).

Ein Bot ueberragt sein Bodenfeld bewusst. Der Fussabdruck bleibt im Feld, der
Rest darf darueber hinausragen -- sonst wird eine Einheit auf dem Handy zur
Briefmarke.

### Bildschirm-Koordinaten der Dateien

Alle Teile teilen sich EIN gemeinsames Bildschirm-Koordinatensystem:
`viewBox "0 0 128 128"`. Dadurch sind Anker direkt vergleichbar und das
Zusammensetzen ist eine reine Translation.

```
x = 64        -> Mittelachse
(64, 96)      -> Mittelpunkt des Bodenfeldes
```

---

## 2. Anker

```
Der BODY definiert die Sockel:      head, feet, core, equip_*
Jedes ANDERE Teil definiert:        mount   (genau einer, das Gegenstueck)
```

Zusammengesetzt wird dann stumpf:

```
verschiebung = body.anker[slotname] - teil.anker["mount"]
```

Der Body selbst wird so gelegt, dass sein `mount` auf `(64, 64)` landet.

> **`links` und `rechts` meinen die Seiten des BOTS**, nicht den Bildschirm.
> `equip_left` ist immer der linke Arm der Drone. Beim Drehen bleibt eine Waffe
> dadurch am selben Arm, statt beim Richtungswechsel die Seite zu tauschen.

### Wie viele Ausruestungsslots ein Bot hat

Ergibt sich **allein aus den Ankern des Bodys**. Jeder Anker, dessen Name mit
`equip_` beginnt, wird zu einem Slot. Kein Sonderfall im Code noetig:

| Body hat die Anker                              | Slots im Tool |
|-------------------------------------------------|---------------|
| `equip_left`, `equip_right`                     | 2 (Standard)  |
| `equip_center`                                  | 1             |
| `equip_left`, `equip_right`, `equip_shoulder`   | 3             |

`parts/bot2` (Juggernaut) zeigt den Drei-Slot-Fall.

### Zusaetzliche Anker

Weitere Anker sind erlaubt und werden vom Tool angezeigt, aber nicht
automatisch bestueckt. Nuetzlich als Marker fuer die spaetere Godot-Seite:

* `ground` – Kontaktpunkt am Boden (auf den Fuss-Teilen)
* `muzzle` – Muendung fuer Projektil-Spawn (auf den Waffen)
* `sensor` – Blickpunkt fuer Sicht-/Zielberechnung
* `fx_*` – Ankerpunkte fuer Partikeleffekte

---

## 3. Metadaten-JSON

Pflichtfelder sind fett, alles andere ist optional.

```jsonc
{
  "id": "scout_body",        // **Teil-ID, richtungsunabhaengig.**
                             // Alle vier Richtungsvarianten teilen sich diese ID --
                             // dadurch findet das Tool beim Richtungswechsel die
                             // passende Variante automatisch.
  "set": "bot1",             // wird beim Einlesen aus dem Ordnernamen gesetzt
  "type": "body",            // **core | head | body | feet |
                             //    equipment | equipment_left | equipment_right**
  "name": "Vireo Chassis",   // Anzeigename in der Bibliothek
  "direction": "south",      // **north | west | east | south**
  "svg": "scout_body_south.svg",   // Default: gleicher Dateiname wie die JSON
  "view_box": [0, 0, 128, 128],

  "anchors": [               // **Array aus { name, x, y } in Bildschirmpixeln**
    { "name": "mount",       "x": 64.0,  "y": 64.0  },
    { "name": "head",        "x": 64.0,  "y": 33.0  },
    { "name": "feet",        "x": 64.0,  "y": 61.63 },
    { "name": "core",        "x": 55.6,  "y": 55.16 },
    { "name": "equip_left",  "x": 82.61, "y": 59.52 },
    { "name": "equip_right", "x": 45.39, "y": 33.2  }
  ],

  "color_scheme": {          // Referenzfarben des Teils (dokumentierend);
    "plate": "#28304a",      // gezeichnet wird immer mit der aktiven Palette
    "accent": "#2de2e6"
  },

  "z_index": 50.0,           // Zeichenreihenfolge, klein = hinten
  "slot_z": {                // NUR auf Body-Teilen: ueberschreibt z je Slot.
    "head": 66, "feet": 36, "core": 57.8,
    "equip_left": 71.5,      // Sued: linker Arm vorn ...
    "equip_right": 32.5      // ... rechter hinter dem Torso
  },

  "slots": ["equip_left", "equip_right"],  // NUR auf Ausruestung: erlaubte Slots.
                                           // Fehlt das Feld -> passt ueberallhin.
  "auto_flip": false,        // NUR auf Ausruestung, s. Abschnitt 6
  "tags": ["light", "scout"] // frei; wird vom Bibliotheks-Filter durchsucht
}
```

### Zeichenreihenfolge = Kameratiefe

`slot_z` ist kein Bauchgefuehl, sondern die Tiefe des Ankers zur Kamera:

```
tiefe = -px - py + pz        (groesser = naeher an der Kamera)
```

Der Generator schreibt genau diesen Wert in `slot_z`. Damit stimmt die
Ueberdeckung in allen vier Richtungen von selbst:

* **Sued:** der linke Arm liegt vorn (71.5), der rechte hinter dem Torso (32.5).
* **Nord:** exakt umgekehrt -- und der Schulterpod des Juggernaut schiebt sich
  vor den Kopf, weil er dann das kameranaechste Teil ist.

Fehlt `slot_z`, greift der `z_index` des Teils, sonst dieser Standard:

| Typ | z |
|---|---|
| `feet` | 10 |
| `body` | 20 |
| `core` | 26 |
| `equipment*` | 30 |
| `head` | 40 |

---

## 4. Farben: keine Hex-Werte im SVG

Jedes Teil zeichnet ausschliesslich mit CSS Custom Properties. Nur so
funktionieren Live-Umfaerben und Fraktionsfarben, ohne die Datei anzufassen.

```xml
<path d="M64 33 L86.9 46.2 L86.9 59.9 L64 46.7 Z" fill="var(--c-plate)"/>
```

| Variable | Rolle in der Iso-Ansicht |
|---|---|
| `--c-plate-light` | **Oberseiten** (waagerechte Flaechen) |
| `--c-plate` | **linke Flanken** (auf dem Bildschirm unten-links) |
| `--c-plate-dark` | **rechte Flanken** (unten-rechts), Schatten |
| `--c-metal` | Gelenke, Rahmen, Mechanik |
| `--c-accent` | Neon-Streifen |
| `--c-glow` | Kern / Emission |
| `--c-visor` | Visier, Sensorik |
| `--c-outline` | Kontur |

Die Zuordnung der ersten drei ist keine Geschmacksfrage: sie ist die
Beleuchtung. Wer sie vertauscht, bekommt Teile, die im Verbund falsch
beleuchtet aussehen.

Beim Export schreibt das Tool die aktiven Werte als `style="--c-plate:…"` in
das Wurzel-`<svg>`. Die Datei ist damit standalone und rendert ueberall
korrekt.

---

## 5. `set.json`

```json
{
  "id": "bot1",
  "name": "RX-Vireo // Scout",
  "description": "Leichter Aufklaerer-Drone. Zwei Ausruestungsanker.",
  "palette": { "plate": "#28304a", "accent": "#2de2e6", "…": "…" }
}
```

Die `palette` wird beim Umschalten auf das Set als Standardpalette geladen.

---

## 6. Ausruestung: symmetrisch bauen statt spiegeln

Eine Waffe soll an beiden Armen sitzen koennen. In einer Frontalansicht
spiegelt man sie dafuer einfach -- **in der Iso-Ansicht geht das nicht**: die
Beleuchtung haengt am Bildschirm, eine gespiegelte Kiste bekaeme ihre
Lichtseite auf die falsche Flanke und wuerde sofort auffallen.

Der saubere Weg, den die Beispielteile gehen: **die Waffe symmetrisch um ihren
eigenen Ankerpunkt modellieren.** Ein nach vorn gerichteter Lauf, ein
mittiger Griff -- das funktioniert links wie rechts, ohne zweite Datei und
ohne Trick.

Wer trotzdem flache, frontal gezeichnete Teile einsetzt, kann das alte
Verhalten pro Teil einschalten:

```jsonc
"auto_flip": true    // spiegelt in Nord-/Suedansicht auf der Gegenseite
```

Standard ist `false`. Der Schalter **Spiegeln** in der Feinjustierung des
Tools bleibt davon unberuehrt und steht immer zur Verfuegung.

Ein zweiter Hinweis aus der Praxis: eine Waffe, die exakt nach vorn zeigt,
verschmilzt in der Iso-Ansicht schnell mit Torso und Beinen. Arme, die
seitlich herunterhaengen und den Lauf erst unten nach vorn fuehren, lesen sich
deutlich besser.

---

## 7. Neues Teil anlegen

**Variante A – ueber das Tool** (schnellster Weg fuer von Claude Code
generierte Grafiken):

1. *Neues Teil importieren…* im rechten Panel
2. SVG-Quelltext einfuegen, Set / Dateiname / Typ / Richtung setzen
3. Anlegen. Das Tool schreibt SVG + JSON mit Platzhalter-Ankern.
4. Slot anwaehlen → *Anker bearbeiten* → Griffe auf der Buehne ziehen →
   *Anker speichern*.

**Variante B – von Hand:** SVG + JSON in den Set-Ordner legen, im Tool auf
*Bibliothek neu einlesen*.

**Variante C – generiert (empfohlen fuer ganze Sets):**
`tools/build_sample_parts.py` beschreibt ein Teil **einmal** als Sammlung von
Quadern in bot-lokalen Koordinaten

```python
SCOUT_HEAD = [
    B((-6.5, 6.5), (-7.5, 7.5), (66, 76), "plate"),   # (vorn, links, hoch)
    B((-7, 7), (-8, 8), (76, 78), "light"),           # Helmdach
    B((6.5, 7.1), (-5.5, 5.5), (68.5, 73), "visor"),  # Visier vorn
]
```

und erzeugt daraus **alle vier Richtungen**. Sichtbarkeit, Beleuchtung und
Zeichenreihenfolge fallen dabei ab: Rueckseiten-Details wie Kuehlrippen
verschwinden von selbst, sobald sie von der Kamera abgewandt sind. Fuer eigene
Sets kopieren und anpassen -- das ist mit Abstand der guenstigste Weg zu vier
konsistenten Ansichten.

> Achtung: `build_sample_parts.py` loescht `parts/bot1` und `parts/bot2`
> komplett, bevor es sie neu schreibt. Eigene Teile gehoeren in einen anderen
> Set-Ordner.

---

## 8. Namenskonvention

```
<teil-id>_<richtung>.svg / .json
```

z. B. `scout_body_south.svg`. Die `id` im JSON bleibt dabei `scout_body` --
ohne Richtungssuffix. Das Tool speichert im Loadout nur diese ID, damit ein
Richtungswechsel automatisch die passende Variante zieht.
