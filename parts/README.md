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
  bot3/
    ...
  bot4/
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
> `equip_left` ist immer der linke Arm der DROME. Beim Drehen bleibt eine Waffe
> dadurch am selben Arm, statt beim Richtungswechsel die Seite zu tauschen.

### Wie viele Ausruestungsslots ein Bot hat

Ergibt sich **allein aus den Ankern des Bodys**. Jeder Anker, dessen Name mit
`equip_` beginnt, wird zu einem Slot. Kein Sonderfall im Code noetig:

| Body hat die Anker                              | Slots im Tool |
|-------------------------------------------------|---------------|
| `equip_left`, `equip_right`                     | 2 (Standard)  |
| `equip_center`                                  | 1             |
| `equip_left`, `equip_right`, `equip_shoulder`   | 3             |

`parts/bot2` (Juggernaut) zeigt den Drei-Slot-Fall, `parts/bot4` (Marksman)
den Ein-Slot-Fall.

### Zusaetzliche Anker

Weitere Anker sind erlaubt und werden vom Tool angezeigt, aber nicht
automatisch bestueckt. Nuetzlich als Marker fuer die spaetere Godot-Seite:

* `ground` – Kontaktpunkt am Boden (auf den Fuss-Teilen)
* `muzzle` – Muendung fuer Projektil-Spawn (auf den Waffen)
* `sensor` – Blickpunkt fuer Sicht-/Zielberechnung
* `fx_*` – Ankerpunkte fuer Partikeleffekte

---

## 2a. Was in einen Slot darf: Montageklasse und Bauart

Der Anker sagt, **wo** etwas sitzt. Er sagt nichts darueber, **was** dort
sitzen darf -- und das reicht nicht. Ohne eine zweite Aussage traegt ein
Sprinter-Chassis eine Belagerungskanone, laeuft damit sechs Felder und schiesst
Leuten in den Ruecken. Nicht weil das ausbalanciert waere, sondern weil ihm
niemand widersprochen hat.

Deshalb zwei Felder auf der Ausruestung und eines auf dem Koerper:

| Feld | wo | Werte |
|---|---|---|
| `mount_class` | Ausruestung | `light` < `medium` < `heavy` |
| `category` | Ausruestung | `weapon` · `shield` · `support` |
| `slot_rules` | Koerper | je Slot `max_class` und/oder `categories` |

```jsonc
// auf dem Koerper
"slot_rules": {
  "equip_left":     { "max_class": "heavy" },
  "equip_right":    { "max_class": "heavy" },
  "equip_shoulder": { "max_class": "light", "categories": ["support"] }
}

// auf der Ausruestung
"mount_class": "heavy",
"category": "weapon"
```

Ein Teil passt, wenn seine Klasse die `max_class` des Slots nicht ueberschreitet
**und** seine `category` in `categories` steht. Fehlt `categories`, sind alle
Bauarten erlaubt; fehlt die ganze Regel, nimmt der Slot alles an.

`mount_class` ist keine reine Gewichtsangabe, sondern **was die Halterung
aushalten muss**: Masse, Rueckstoss, Hebel. Ein Schild ist `medium`, weil es
sperrig ist und gehalten werden will, nicht weil es schwer waere.

### Voreinstellungen

| fehlt | gilt | warum |
|---|---|---|
| `mount_class` | `light` | passt ueberallhin -- ein importiertes Teil ist nie gesperrt |
| `category` | `weapon` | der haeufigste Fall; hindert es an ausdruecklich engeren Slots |
| `slot_rules[slot]` | keine Einschraenkung | altes Verhalten bleibt erhalten |

Wer ein Support-Modul importiert, muss `category` also setzen, sonst kommt es
nicht auf eine Schulterbruecke. Das ist Absicht: lieber einmal ein Feld
nachtragen als stillschweigend jeden Slot aufmachen.

### `slots` oder `slot_rules`?

Beides existiert und meint Verschiedenes:

* **`slots`** auf dem Teil ist die *harte Ankerliste* -- "dieses Teil gehoert
  genau an `equip_shoulder`". Fuer Teile, die geometrisch nur an einer Stelle
  funktionieren, wie den Drohnen-Pod.
* **`slot_rules`** auf dem Koerper ist die *allgemeine Regel* -- "hier passt
  alles bis mittelschwer". Sie gilt auch fuer Teile aus Sets, die es beim
  Entwurf des Chassis noch gar nicht gab.

Die Regel ist der Normalfall, die Ankerliste die Ausnahme.

### Der aktuelle Bestand

| Slot | nimmt | daraus folgt |
|---|---|---|
| `bot1` Vireo, beide Arme | bis `medium` | Blaster, Schild, Runenstab, Orbit-Fokus |
| `bot2` Molok, beide Arme | bis `heavy` | alles, auch Kanone und Lanze |
| `bot2` Molok, Schulter | bis `light`, nur `support` | Drohnen-Pod, Orbit-Fokus |
| `bot3` Nimbus, beide Arme | bis `medium` | wie Vireo |
| `bot4` Strix, Mitte | bis `heavy` | alles -- aber nur einmal |

`tools/build_sample_parts.py` druckt diese Tabelle bei jedem Lauf aus den
Daten, statt sie hier abzuschreiben.

## 3. Metadaten-JSON

Pflichtfelder sind fett, alles andere ist optional.

```jsonc
{
  "id": "scout_body",        // **Datei-Slug, richtungsunabhaengig.**
                             // Alle vier Richtungsvarianten teilen sich diese ID --
                             // dadurch findet das Tool beim Richtungswechsel die
                             // passende Variante automatisch.
  "code": "CHS-001",         // **Teile-Code fuers Game Design** (s. Abschnitt 3a)
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
  "mount_class": "medium",   // NUR auf Ausruestung: light | medium | heavy
  "category": "shield",      // NUR auf Ausruestung: weapon | shield | support
  "slot_rules": {            // NUR auf Body-Teilen: was der Slot annimmt.
    "equip_shoulder": { "max_class": "light", "categories": ["support"] }
  },                         // Details in Abschnitt 2a.
  "auto_flip": false,        // NUR auf Ausruestung, s. Abschnitt 6
  "tags": ["light", "scout"] // frei; wird vom Bibliotheks-Filter durchsucht
}
```

### 3a. Teile-Code

Neben dem Datei-Slug traegt jedes Teil einen kurzen, stabilen **Code**. Er ist
das, was in Balancing-Tabellen, Loot-Listen und Speicherstaenden steht, und
aendert sich nie -- auch wenn Teil oder Datei umbenannt werden.

| Praefix | Teiletyp |
|---|---|
| `COR` | Kern |
| `HED` | Kopf |
| `CHS` | Koerper / Chassis |
| `LEG` | Fuesse |
| `EQP` | Ausruestung |

Format: drei Grossbuchstaben, Bindestrich, drei- bis vierstellige Nummer
(`CHS-001`, `EQP-0042`). Die Nummer laeuft je Typ durch, quer ueber alle Sets.

**Codes muessen projektweit eindeutig sein.** Der Server meldet Duplikate beim
Einlesen als Warnung, der Generator bricht bei einer Kollision ab. Die vier
Richtungsvarianten eines Teils teilen sich denselben Code -- das ist kein
Duplikat, sondern der Normalfall.

Der Code ist bewusst getrennt vom Slug: der Slug traegt die Dateinamen und soll
beim Stoebern im Ordner lesbar bleiben (`scout_body_south.svg`), der Code soll
kurz und stabil sein. Das Werkstatt-Tool zeigt beides als
`CHS-001 · Vireo Chassis`, der Filter greift auf beide zu.

Das Feld ist optional. Ein frisch importiertes Teil ohne Code funktioniert
vollstaendig, taucht in Game-Design-Tabellen aber nicht sauber auf -- der
Import-Dialog hat deshalb ein Feld dafuer.

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

## 3c. Ein SVG muss wohlgeformtes XML sein

Klingt selbstverstaendlich, ist es nicht. Browser und Godot sehen ueber
vieles hinweg, ein strikter Parser (ElementTree, lxml, jedes Werkzeug, das
die Dateien einliest statt sie anzuzeigen) bricht dagegen ab -- und der
Fehler faellt dann irgendwann an einer Stelle auf, die mit dem Teil nichts
zu tun hat.

Der haeufigste Stolperstein in genau diesem Projekt ist der **Gedankenstrich**:

```xml
<!-- Erzeugt von build_sample_parts.py -- nicht von Hand bearbeiten. -->
```

`--` ist innerhalb eines XML-Kommentars verboten, und hier steht er in fast
jedem erklaerenden Satz. Beide Generatoren ziehen ihn deshalb ueber
`svg_comment_body()` zu einem einfachen Bindestrich zusammen, und alle drei
Wege, auf denen ein SVG ins Repo kommt -- `build_sample_parts.py`,
`build_terrain_tiles.py` und der Import in der Werkstatt -- pruefen vor dem
Schreiben, dass sich die Datei parsen laesst. Ein importiertes SVG, das das
nicht tut, wird mit Begruendung abgewiesen.

Dasselbe gilt fuer alles andere, was XML verbietet: ein nacktes `&` gehoert
als `&amp;` geschrieben, ein `<` in einem Text als `&lt;`.

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

### 4a. Bedient wird ueber vier Kategorien je Bauteiltyp

Diese acht Rollen sind die Ausgabe, nicht die Eingabe. Zum Einstellen waeren
sie zu viele -- und drei davon duerfen ohnehin nicht frei gewaehlt werden, weil
sie die Beleuchtung *sind*. Eine Palette hat deshalb **genau vier Kategorien**,
und welche vier das sind, haengt am Bauteiltyp:

| Bauteiltyp | die vier Kategorien | gesetzte Rollen |
|---|---|---|
| `body`, `feet` | Panzerung · Mechanik · Neon · Kontur | alle acht |
| `equipment*` | Panzerung · Mechanik · Neon · Kontur | alle acht |
| `head` | Panzerung · Mechanik · **Visier** · Kontur | alle acht |
| `core` | **Gehaeuse · Kernglut · Energieringe** · Kontur | alle acht |

Die Ableitung:

* **Panzerung / Gehaeuse** setzt `--c-plate` und erzeugt `--c-plate-light`
  (multiplikativ aufgehellt) und `--c-plate-dark` (abgedunkelt) daraus.
  Multiplikativ statt "mit Weiss mischen", damit Ton und Saettigung erhalten
  bleiben -- eine beleuchtete Flaeche soll nach demselben Material aussehen.
* **Neon / Visier / Kernglut** setzen ihre Rolle direkt, die uebrigen
  Leuchtrollen bekommen eine aufgehellte Variante.
* Jede Kategorienliste deckt alle acht Rollen ab. Ein importiertes Teil trifft
  damit nie auf eine ungesetzte Variable, auch wenn es eine Rolle nutzt, die
  sein Typ sonst nicht braucht.

Im Werkstatt-Tool waehlt man den Bauteiltyp ueber die Chips im Paletten-Panel;
ein angewaehlter Slot stellt ihn automatisch mit. Paletten lassen sich dort
anlegen (wahlweise als Kopie einer vorhandenen), sichern und loeschen -- sie
liegen in `palettes.json` und sind nicht an einen Bot gebunden.

Beim Export bekommt **jede Teil-Gruppe ihre eigenen acht Rollen** als
`style="--c-plate:…"`, weil sie sich je nach Bauteiltyp aus anderen vier
Kategorien ergeben. Die Datei ist damit weiterhin standalone.

---

## 5. `set.json`

```json
{
  "id": "bot1",
  "name": "RX-Vireo // Scout",
  "description": "Leichte Aufklaerer-DROME. Zwei Ausruestungsanker.",
  "palette": {
    "body":      { "hull": "#28304a", "mech": "#5b6785", "neon": "#2de2e6", "line": "#080b13" },
    "feet":      { "hull": "#28304a", "mech": "#5b6785", "neon": "#2de2e6", "line": "#080b13" },
    "equipment": { "hull": "#28304a", "mech": "#5b6785", "neon": "#2de2e6", "line": "#080b13" },
    "head":      { "hull": "#28304a", "mech": "#5b6785", "visor": "#7cf9ff", "line": "#080b13" },
    "core":      { "case": "#28304a", "ember": "#ff2d95", "rings": "#2de2e6", "line": "#080b13" }
  }
}
```

Die `palette` wird beim Umschalten auf das Set als Standardpalette geladen.

Eine alte, flache Palette (`{"plate": "#…", "accent": "#…"}`) funktioniert
weiterhin: der Server uebersetzt sie beim Einlesen in Kategorien. Das gilt
ebenso fuer `palettes.json` und fuer gespeicherte Builds.

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

## 6a. Lesbarkeitsregel: keine zwei Funktionen mit derselben Silhouette

> **Zwei Teile mit unterschiedlicher Spielfunktion muessen sich an der
> SILHOUETTE unterscheiden -- nicht an der Groesse, nicht an der Farbe.**

CyberDrome ist deterministisch. Wer eine gegnerische DROME ansieht, soll vor
seinem Zug wissen, was sie kann: wie weit sie schiesst, wie weit sie laeuft, ob
sie deckt oder austeilt. Diese Auskunft gibt die Form. Groesse gibt sie nicht:

* die Kachel ist klein, auf dem Handy besonders;
* Teile ueberlappen sich im Verbund, und was hinten liegt, ist angeschnitten;
* eine Einheit weiter hinten auf der Karte ist ohnehin kleiner.

Eine Belagerungskanone, die nur ein groesser gezogener Blaster ist, ist deshalb
**kein Schoenheitsfehler, sondern ein Regelfehler** -- der Spieler kann ihre
Reichweite nicht sehen und trifft seine Entscheidung ohne die Information, die
das Spielsystem ihm verspricht. Dasselbe gilt fuer ein Energieschwert, das wie
ein Energiedolch aussieht.

### Was ein Silhouetten-Merkmal ist

Etwas, das auf der **Aussenkante** liegt und dort eine eigene Form macht --
nicht eine Struktur in der Flaeche, die bei 40 Pixeln verschwindet:

| Teil | Merkmal | liest sich als |
|---|---|---|
| `EQP-001` Puls-Blaster | ein glattes Rohr, sonst nichts | leicht, kurze Reichweite |
| `EQP-003` Belagerungskanone | Muendungsbremse mit Querfluegeln, Trommelmagazin, Abstuetzstrebe | schwer, abgestuetzt |
| `EQP-007` Schienen-Lanze | ueberlanger duenner Doppellauf, Zielblock, Gabel | Praezision, grosse Reichweite |
| `EQP-002` Deflektor-Schild | flache Wand quer zur Blickrichtung | Deckung |
| `LEG-001` Vireo | schmaler Stand, gerade Stelzen, eine Zehe | schnell |
| `LEG-002` Molok | breiter Stand auf Auslegern, Hydraulikzylinder, Ferse | langsam, standfest |
| `LEG-004` Strix | Knick nach hinten, digitigrad | federnd, mittel |
| `CHS-001` Vireo | gerader Kistenstapel, sichtbarer Hals, offene Huefte | leicht, beweglich |
| `CHS-002` Molok | Panzerschuerze, Keil-Torso, Pauldrons ueber dem Kopfsockel | schwer, geduckt |
| `CHS-004` Strix | Gegengewichts-Ausleger ueber dem Kopf | Ein-Slot-Rahmen |

Die drei Waffenbeispiele sind bewusst so verteilt, dass **Proportion** die
Aussage traegt: gedrungen und breit heisst Artillerie, lang und duenn heisst
Praezision. Das funktioniert auch als reine Schattenform.

### Der Test dazu

`tools/build_sample_parts.py` prueft die Regel bei jedem Lauf. Gemessen wird
die **gefuellte Umrissflaeche** -- mit derselben Projektion, die auch die
Grafik erzeugt, aus zwei Blickrichtungen (Sued und Ost). Es wird also genau
das verglichen, was der Spieler sieht, und nicht ein Ersatzmass aus
Huellquadern: ein Rotationskoerper ist dabei rund und nicht eckig.

Normiert wird **uniform** -- ein Massstab fuer beide Bildschirmachsen, um den
eigenen Mittelpunkt. Das ist der springende Punkt: dadurch wird "gleiche Form,
andere Groesse" identisch, waehrend "lang und duenn" gegen "kurz und dick"
verschieden bleibt.

```
Silhouetten-Abstand (1.00 = ununterscheidbar; Grenze 0.85, aber nur fuer
Ausruestung -- Pruefstein 0.91), engstes Paar je Typ:
  body       0.85  bot1/scout_body / bot2/jugg_body
  core       0.82  bot2/jugg_core / bot3/mage_core
  equipment  0.66  bot1/eq_pulse_blaster / bot2/eq_siege_cannon
  feet       0.66  bot1/scout_feet / bot4/strix_feet
  head       0.88  bot2/jugg_head / bot3/mage_head
```

* **Ausruestung: ab 0.85 bricht der Generator ab.** An der Waffe liest der
  Spieler Reichweite und Rolle ab; diese Auskunft darf nicht fehlen.
* **Rahmenteile: gar keine Grenze**, nur die Tabelle -- aus dem Grund gleich
  darunter.

Der **Pruefstein** ist die erste Belagerungskanone: exakt der Aufbau des
Blasters mit groesseren Zahlen, im Generator als `EQ_CANNON_V1` aufbewahrt. Sie
liegt bei 0.91, das engste ehrliche Ausruestungspaar bei 0.66 -- in diese
Luecke passt eine harte Grenze, und nur deshalb ist sie dort eine. Der
Generator misst den Pruefstein bei jedem Lauf mit und bricht ab, wenn er
*nicht* mehr auffaellt: ein Test, der nichts mehr faengt, meldet sonst einfach
weiter "alles in Ordnung".

### Warum Rahmenteile keine Grenze haben

**Der Test sieht den Umriss, nicht die Formensprache** -- und bei kompakten
Teilen sieht er praktisch gar nichts mehr. Normiert wird jedes gedrungene
Volumen zum selben Klumpen:

```
HED-002 Bunkerkopf          HED-003 Flachhelm
Quader -> Sechseck          Kuppel + Krempe -> Raute
64 % Fuellung, mittig       64 % Fuellung, mittig
                 Abstand 0.88
```

Diese beiden sehen einander nicht im Entferntesten aehnlich -- der eine ist
kantig mit Seitensensoren, der andere rund mit auskragender Krempe. Trotzdem
liegen sie am oberen Ende des Bereichs, weil beide ihren Rahmen gleich stark
und an derselben Stelle fuellen.

Es gab dort einmal einen Schwellwert. Er hatte im gesamten Bestand **null
Treffer und zwei Fehlalarme** (Kopf 0.88, Chassis 0.85 -- beide in Ordnung)
und ist deshalb entfernt worden. Eine Grenze, die nur Fehlalarme produziert,
ist schlimmer als keine: sie gewoehnt einem an, Hinweise zu ueberlesen, und
dann geht auch ein echter unter.

Geblieben ist die Tabelle mit dem engsten Paar je Typ. Die **Reihenfolge** ist
brauchbar -- so faellt auf, wenn ein neues Chassis verdaechtig weit oben
einsteigt --, die absolute Zahl nicht.

Bei Ausruestung ist der Abstand dagegen sauber zweigeteilt, weil Waffen sich
in der Proportion unterscheiden duerfen und muessen: Pruefstein 0.91, engstes
ehrliches Paar 0.66. Nur dort gibt es ueberhaupt eine Grenze.

Das heisst auch: **der Test ersetzt das Hinsehen nicht.** Er faengt den Fall
"abgeschrieben und groesser gezogen" zuverlaessig. Ob zwei Rahmen dieselbe
Formensprache sprechen -- gerader Kistenstapel mit Hals gegen gerade denselben
Stapel, nur breiter --, entscheidet weiterhin das Auge. Genau daran ist das
Molok-Chassis einmal vorbeigekommen, bevor es Panzerschuerze, hochsitzende
Pauldrons und Auspuffstapel bekam.

### Wenn zwei Teile dieselbe Funktion haben

Dann ist Wiederverwenden nicht nur erlaubt, sondern richtig: **dasselbe Teil
benutzen**, statt eine leicht abgewandelte Kopie zu bauen. Zwei Beinpaare mit
identischen Werten und minimal verschobenen Abstaenden sind der schlechteste
aller Faelle -- sie kosten Arbeit, verwirren beim Lesen und behaupten einen
Unterschied, den es nicht gibt. Ein Set ist eine Autoren-Schublade, kein
Bausatz; ein Chassis darf sich die Beine eines anderen ausleihen.

---

## 6b. Sitzregel: der Kern gehoert INS Chassis

> Ein Kern ist kein Anbauteil. Er sitzt in einem **Schacht der Brustplatte** --
> oder, wo der Rahmen es hergibt, der Rueckenplatte -- und soll aussehen, als
> waere er mit dem Chassis verschmolzen.

Das ist keine Geschmacksfrage, sondern faellt aus der Zeichenweise. Der
zusammengebaute Bot hat **keinen Tiefenpuffer**: Teile werden nacheinander
gezeichnet, der Kern kommt nach dem Koerper und deckt ihn an seiner Stelle
vollstaendig ab. Steht er vor der Panzerung, liest sich das deshalb nicht als
Tiefe, sondern als aufgeklebte Plakette -- und weil derselbe Kern auf jedes
Chassis passen soll, kann ihm das Chassis diese Tiefe auch nicht nachtraeglich
abnehmen.

### Der Test dazu

Gemessen wird **in der Ebene der Sockelflaeche** -- von vorn auf die Brust
geschaut, nicht mit der Iso-Kamera. Fuer jede Rasterzelle der `(l, z)`-Ebene,
die der Kern belegt:

| | |
|---|---|
| **AUFBAU** | vorderste Tiefe des Kerns minus vorderste Tiefe des Chassis an derselben Stelle -- wie weit der Kern vorsteht. Grenze: **1.0 Entwurfseinheiten** |
| **FREI**   | Anteil der Kernflaeche, hinter der ueberhaupt kein Chassis liegt. Dort haengt der Kern in der Luft. Grenze: **2 %** (Randzellen des Rasters) |

Die Richtung ergibt sich aus dem Anker: sitzt er vor der Mittelachse, zeigt
der Sockel nach vorn, sonst nach hinten. **Ein Kern am Ruecken ist also
ausdruecklich erlaubt** -- er wird nur genauso streng gemessen.

Beide Werte haben dieselbe Ursache, wenn sie ausschlagen: der Kern wurde fuer
sich entworfen und nicht fuer seinen Schacht. Der Bestand hat das einmal
komplett vorgefuehrt:

| Kern | alt | woran es lag |
|---|---|---|
| COR-004 Strix | Aufbau 1.30 | Gehaeuse lag als Platte **auf** der Brust statt darin -- und schob sich dabei vor das Waffenjoch, das eigentlich davor liegt |
| COR-001 Vireo | Aufbau 2.70 | Scheibe sass korrekt, aber der untere Energiestreifen ragte unter die Brustplatte |
| COR-002 Molok | Aufbau 3.70 | Leuchtkreuz ragte unten ueber die Kante des Kernsockels hinaus |
| COR-003 Nimbus | Aufbau 4.99 | Orb stand vor dem Torso und hing seitlich ueber dessen Rundung; aus West und Nord blieben zwei Ringe in der Luft |

### Brust oder Ruecken

Regelfall ist die Brust. Der Strix (bot4) ist der Gegenfall und zeigt, wann
sich der Ruecken lohnt: seine Brust gehoert dem Waffenjoch, und die
Schienen-Lanze liegt genau davor. Ein Kern dort waere im bestueckten Bot aus
Sued und Ost verdeckt gewesen -- also aus genau den beiden Richtungen, aus
denen man ihn sieht. Sein Zielrechner sitzt deshalb im
Gegengewichts-Ausleger, zwischen den Kuehlrippen, und ist aus West und Nord
zu sehen.

Die Frage ist also nicht "Brust oder Ruecken?", sondern: **wo hat dieser
Rahmen eine Flaeche, die gross genug ist und frei bleibt, wenn der Bot
bestueckt ist?**

### Was daraus fuer den Entwurf folgt

* **Der Koerper baut den Schacht, der Kern legt sich hinein.** Der Sockel auf
  der Brustplatte muss groesser sein als der Kern -- bis in dessen aeusserste
  Zierstreifen.
* **Ein runder Torso braucht eine ebene Stirn.** Zur Seite hin faellt eine
  Rundung weg, und ein flacher Kern haengt an seinem Rand in der Luft. Der
  Nimbus loest das mit einem nach vorn liegenden Zylinder (`axis="f"`) als
  Kernflansch.
* **Scheibe (`D`) statt Quader**, wo es geht: eine Scheibe hat keine Tiefe und
  kann deshalb gar nicht abstehen. Genau deshalb sassen Vireo und Molok schon
  vorher fast richtig.
* Ein **flach eingelassenes** Gehaeuse, dessen Stirn mit der Panzerung
  fluchtet, deckt die Platte exakt ab und verschwindet optisch in ihr -- das
  ist der billigste Weg zu "verschmolzen". Die sichtbare Kante liefert dann
  der Rahmen, den das Chassis um den Schacht zieht.

---

## 7. Neues Teil anlegen

**Variante A – ueber das Tool** (schnellster Weg fuer von Claude Code
generierte Grafiken):

1. *Neues Teil importieren…* im rechten Panel
2. SVG-Quelltext einfuegen, Set / Dateiname / Typ / Richtung setzen
3. Anlegen. Das Tool schreibt SVG + JSON mit Platzhalter-Ankern.
4. Slot anwaehlen → *Anker bearbeiten* → am Achsenkreuz ziehen (Pfeil = nur
   diese Bot-Achse, Mitte = frei) oder rechts im Anker-Block abzaehlen →
   *Anker speichern*.

**Variante B – von Hand:** SVG + JSON in den Set-Ordner legen, im Tool auf
*Bibliothek neu einlesen*.

**Variante C – generiert (empfohlen fuer ganze Sets):**
`tools/build_sample_parts.py` beschreibt ein Teil **einmal** als Sammlung von
Primitiven in bot-lokalen Koordinaten

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

Es gibt drei Primitive:

| | |
|---|---|
| `B(f, l, z, mat)` | Quader aus (min, max)-Paaren |
| `D(f, l, z, r, mat)` | nach vorn gerichtete Scheibe (Muendung, Linse) |
| `L(center, profile, mat, axis, caps)` | **Rotationskoerper** |

`L` ist alles Runde: ein Streckenzug aus `(radius, achsposition)`-Paaren wird
um eine bot-lokale Achse gedreht. Zylinder, Kegel, Kuppeln, Orbs, Ringe und
Raeder sind derselbe Aufruf mit anderem Profil (`parts/bot3` zeigt alle Faelle):

```python
L((0, 0), [(9, 12), (9, 26)], "plate")                    # Zylinder
L((0, 0), [(10, 50), (6.4, 57), (0, 58.6)], "light")      # Kuppel
L((0, 9.8), [(9.8, 10.8), (9.8, 14.2)], "dark", axis="l") # Rad
L((0, 30), [(6.4, 6.5), (7.6, 7.6), (6.4, 8.7), (6.4, 6.5)],
  "accent", axis="f")                                     # geschlossen -> Ring
```

Die Facetten eines Rotationskoerpers tragen bewusst **keine** Outline: ihre
gemeinsamen Kanten sind keine Kanten des Objekts, ein Strich dort ergaebe ein
Drahtgitter. Stattdessen zieht der Renderer eine Silhouette aus der konvexen
Huelle -- das Strichbild passt damit zu den Quader-Teilen.

> Achtung: `build_sample_parts.py` loescht `parts/bot1` bis `parts/bot4`
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
