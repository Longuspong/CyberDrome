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

## 1. Koordinatensystem

**Alle Teile teilen sich genau ein Koordinatensystem.** Das ist die wichtigste
Regel; daran haengt das gesamte Anker-System.

```
viewBox = "0 0 128 128"
x = 64    Mittelachse
y = 120   Bodenlinie (Kontaktpunkt mit dem Map-Tile)
```

Ein Teil zeichnet sich also an der Stelle, an der es *am fertigen Bot* sitzt --
ein Kopf malt oben, Fuesse malen unten. Das Zusammensetzen ist dann nur noch
eine Verschiebung, keine Skalierung und kein Raten.

`links` / `rechts` sind **immer bildschirmseitig** gemeint, nicht aus Sicht des
Bots. Sonst waeren die Ankernamen in Nord- und Suedansicht vertauscht.

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
* `muzzle` – Muendung fuer Projektil-Spawn
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

  "anchors": [               // **Array aus { name, x, y }**
    { "name": "mount",       "x": 64, "y": 64 },
    { "name": "head",        "x": 64, "y": 42 },
    { "name": "feet",        "x": 64, "y": 88 },
    { "name": "equip_left",  "x": 40, "y": 62 },
    { "name": "equip_right", "x": 88, "y": 62 },
    { "name": "core",        "x": 64, "y": 67 }
  ],

  "color_scheme": {          // Referenzfarben des Teils (dokumentierend);
    "plate": "#232a3d",      // gezeichnet wird immer mit der aktiven Palette
    "accent": "#2de2e6"
  },

  "z_index": 20,             // Zeichenreihenfolge, klein = hinten
  "slot_z": {                // NUR auf Body-Teilen: ueberschreibt z je Slot.
    "equip_left": 14,        // So wandert in der Nordansicht die Ausruestung
    "equip_right": 14        // hinter den Koerper.
  },

  "slots": ["equip_left", "equip_right"],  // NUR auf Ausruestung: erlaubte Slots.
                                           // Fehlt das Feld -> passt ueberallhin.
  "no_auto_flip": false,     // NUR auf Ausruestung: automatisches Spiegeln
                             // auf der Gegenseite abschalten (s. u.)
  "tags": ["light", "scout"] // frei; wird vom Bibliotheks-Filter durchsucht
}
```

### Automatisches Spiegeln

Waffen sind meist nur fuer eine Seite gezeichnet. Landet so ein Teil im Slot der
Gegenseite, spiegelt das Tool es selbst -- das spart pro Waffe ein zweites SVG.
Gilt nur in Nord-/Suedansicht; im Profil zeigen beide Arme nach vorn, dort waere
Spiegeln falsch. Abschaltbar per `"no_auto_flip": true`.

### Standard-Zeichenreihenfolge

Wenn weder `z_index` noch `slot_z` gesetzt sind:

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
<path d="M47 45 H81 L86 60 L81 84 H47 L42 60 Z" fill="var(--c-plate)"/>
<path d="M54 57 H74" stroke="var(--c-accent)" stroke-width="2.4"/>
```

| Variable | Rolle |
|---|---|
| `--c-plate` | Haupt-Panzerung |
| `--c-plate-dark` | Schattenseite, Untergrund |
| `--c-plate-light` | Highlight-Kante |
| `--c-metal` | Gelenke, Rahmen, Mechanik |
| `--c-accent` | Neon-Streifen |
| `--c-glow` | Kern / Emission |
| `--c-visor` | Visier, Sensorik |
| `--c-outline` | Kontur |

Beim Export schreibt das Tool die aktiven Werte als `style="--c-plate:…"` in das
Wurzel-`<svg>`. Die Datei ist damit standalone und rendert ueberall korrekt.

---

## 5. `set.json`

```json
{
  "id": "bot1",
  "name": "RX-Vireo // Scout",
  "description": "Leichter Aufklaerer-Drone. Zwei Ausruestungsanker.",
  "palette": { "plate": "#232a3d", "accent": "#2de2e6", "…": "…" }
}
```

Die `palette` wird beim Umschalten auf das Set als Standardpalette geladen.

---

## 6. Neues Teil anlegen

**Variante A – ueber das Tool** (schnellster Weg fuer von Claude Code
generierte Grafiken):

1. *Neues Teil importieren…* im rechten Panel
2. SVG-Quelltext einfuegen, Set / Dateiname / Typ / Richtung setzen
3. Anlegen. Das Tool schreibt SVG + JSON mit Platzhalter-Ankern.
4. Slot anwaehlen → *Anker bearbeiten* → Griffe auf der Buehne ziehen →
   *Anker speichern*.

**Variante B – von Hand:** SVG + JSON in den Set-Ordner legen, im Tool auf
*Bibliothek neu einlesen*.

**Variante C – generiert:** `tools/build_sample_parts.py` erzeugt den
Beispielsatz. Das Skript ist gleichzeitig eine ausfuehrbare Spezifikation
dieses Formats -- fuer eigene Sets kopieren und anpassen.

> Achtung: `build_sample_parts.py` loescht `parts/bot1` und `parts/bot2`
> komplett, bevor es sie neu schreibt. Eigene Teile gehoeren in einen anderen
> Set-Ordner.

---

## 7. Namenskonvention

```
<teil-id>_<richtung>.svg / .json
```

z. B. `scout_body_south.svg`. Die `id` im JSON bleibt dabei `scout_body` --
ohne Richtungssuffix. Das Tool speichert im Loadout nur diese ID, damit ein
Richtungswechsel automatisch die passende Variante zieht.
