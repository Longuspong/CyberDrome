# CyberDrome

Rundenbasiertes 2D-Tactics-RPG im Cyberpunk-/Neon-Setting, **isometrisch**
(Kamera 45 Grad von oben auf ein gedrehtes Gitter).
Ziel-Engine: **Godot**, Ziel-Plattformen: **Android** und **Desktop**.

Gespielt wird mit **DROMEs** – *Death Robot Omni Machine Executor* –, modularen
Kampfmaschinen aus einem **Kern**, drei Hauptteilen (**Kopf**, **Koerper**,
**Fuesse**) und den **Ausruestungs­gegenstaenden**, die der Koerper ueber seine
Anker zulaesst (meist zwei, gelegentlich einer oder drei).

Die komplette Optik laeuft ueber **SVG** statt Pixelart. Der Grund ist bewusst
gewaehlt: modulare Teile lassen sich kombinieren, umfaerben und aufloesungs­frei
skalieren, ohne dass fuer jede Kombination ein eigener Sprite gezeichnet werden
muss. Siehe [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md).

Aktueller Stand: **SVG-Werkstatt** plus **spielbarer Kampf-MVP** in Godot 4.3.

```bash
python3 main.py                  # SVG-Werkstatt im Browser
godot --path .                   # Spiel (Werkstatt-Squad -> Chaos-Virus)
godot --headless --script res://tests/run_tests.gd    # Tests
node tools/check_workshop_stats.js                    # Werkstatt gegen Engine
```

Das Spiel hat ein Hauptmenue mit zwei Wegen: **Werkstatt** (Loadout bauen)
und **Chaos-Virus** (Kampf). Godot rastert die Quell-SVGs nicht direkt -- es
kennt keine CSS-Variablen --, deshalb erzeugt `tools/bake_godot_assets.py`
den Satz unter `assets/parts/`.

### Zwei Werkstaetten, zwei Aufgaben

| | |
|---|---|
| **SVG-Werkstatt** (`python3 main.py`) | Bauteile zeichnen und importieren, Anker setzen, Paletten pflegen. Das Asset-Werkzeug. |
| **Godot-Werkstatt** (im Spiel) | Loadout bauen, Stats sehen, Squad zusammenstellen und in den Kampf schicken. |

Beide schreiben denselben Squad -- die Godot-Werkstatt nach
`user://squad.json`, die SVG-Werkstatt nach `builds/squad.json`. Beim Start
gewinnt die neuere. Nur der erste Weg ueberlebt einen Export: `builds/` liegt
im Repo und nicht im Spielpaket, die SVG-Werkstatt ist ein Entwicklerwerkzeug
und laeuft ohnehin nur neben dem Quellbaum.

---

## SVG-Werkstatt

Lokales Tool zum Sichten, Zusammensetzen, Umfaerben und Feinjustieren der
modularen DROME-Teile – und zum Export fertiger DROMEs zurueck ins Repo.

### Starten

```bash
python3 main.py
```

Das war's. Keine Installation, keine Abhaengigkeiten, kein Build-Schritt –
nur die Python-Standardbibliothek. Der Browser oeffnet sich automatisch auf
<http://127.0.0.1:8000/>.

```bash
python3 main.py --port 8080          # anderer Port
python3 main.py --parts ./parts_wip  # anderer Teile-Ordner
python3 main.py --no-browser         # Browser nicht oeffnen
```

Der Server bindet nur an `127.0.0.1` und hat keinerlei Zugriffsschutz – er ist
ein Entwickler-Werkzeug und gehoert nicht ins offene Netz.

### Was das Tool kann

| | |
|---|---|
| **Bibliothek** | **immer alle Teile aus allen Sets**, nach Typ gruppiert, mit Live-Vorschau in der aktiven Palette und Teile-Code, Filter nach Code/Name/Tag/Typ/Set |
| **Vier Richtungen** | N / W / O / S; beim Umschalten werden alle Teile automatisch auf ihre Variante fuer diese Richtung gewechselt |
| **Anker-Montage** | Teile rasten ueber die Ankerpunkte aus der JSON ein – kein manuelles Positionieren noetig |
| **Bestuecken** | Klick in der Bibliothek (angewaehlter Slot, sonst erster freier), Drag & Drop auf die Buehne (naechstgelegener passender Anker) oder Dropdown pro Slot |
| **Slotregeln** | jeder Ausruestungsslot zeigt, was er annimmt (*bis mittel*, *bis leicht · Support*); unpassende Teile tauchen dort gar nicht erst auf, und beim Chassiswechsel wird gemeldet, was abfaellt |
| **Feinjustierung** | Versatz, Groesse, Drehung, Spiegeln, Zeichenebene je Slot – Pfeiltasten zum Nudgen, `Shift` fuer 0,25er-Schritte |
| **Anker-Editor** | Achsenkreuz auf dem Anker: ziehen entlang der Bot-Achsen (vor/links/hoch), stufenweise nudgen, zurueckschreiben in die JSON des Teils |
| **Palette** | **genau vier Farbkategorien je Bauteiltyp**, Paletten anlegen / sichern / loeschen, optional pro Slot abweichend |
| **Import** | von Claude Code generierten SVG-Quelltext einfuegen → Tool legt SVG + JSON an |
| **Export** | SVG + JSON nach `/builds/`, alle vier Richtungen auf einmal, Spritesheet, SVG-/PNG-Download |

### Bedienung in 30 Sekunden

1. Loslegen – ein Koerper ist bereits gesetzt, und die Bibliothek zeigt alle
   Teile aller Sets. Das Set-Dropdown oben links waehlt keinen Bausatz aus,
   sondern nur die Startpalette und das Ziel-Set beim Importieren.
2. Teile in der Bibliothek anklicken. Ausruestung landet im angewaehlten Slot,
   sonst im ersten freien; per Drag & Drop entscheidet die Fallposition. Wer
   einen belegten Slot neu bestuecken will, waehlt ihn rechts an und klickt
   dann in der Bibliothek.
3. Slot rechts anwaehlen, dann mit Pfeiltasten oder Reglern feinjustieren.
4. Namen oben eintragen, **Ins Repo speichern** → `builds/<name>.svg` + `.json`.

| Taste | Wirkung |
|---|---|
| Pfeiltasten | gewaehlten Slot um 1 verschieben |
| `Shift` + Pfeil | um 0,25 verschieben |
| `F` | gewaehlten Slot spiegeln |
| `Entf` | gewaehlten Slot leeren |

### Farben: vier Kategorien statt acht Regler

Ein Teil zeichnet mit acht CSS-Rollen, aber eingestellt werden **genau vier
Kategorien – und welche vier, haengt am Bauteiltyp**:

| Bauteiltyp | die vier Kategorien |
|---|---|
| Koerper, Fuesse, Ausruestung | Panzerung · Mechanik · Neon · Kontur |
| Kopf | Panzerung · Mechanik · **Visier** · Kontur |
| Kern | **Gehaeuse · Kernglut · Energieringe** · Kontur |

Kante und Schatten der Panzerung leitet das Tool aus der Grundfarbe ab. Das ist
kein Komfort, sondern eine Absicherung: die drei Panzerungs-Rollen *sind* die
Iso-Beleuchtung, einzeln gesetzt ergeben sie falsch beleuchtete Teile.

Den Typ waehlen die Chips im Paletten-Panel; ein angewaehlter Slot stellt ihn
automatisch mit. **Neu…** legt eine Palette an – wahlweise als vollstaendige
Kopie einer vorhandenen –, **Sichern** schreibt die aktuellen Farben hinein,
**✕** loescht sie. Paletten liegen in `palettes.json`, gehoeren keinem Bot und
lassen sich jederzeit wieder auf einen beliebigen Aufbau anwenden.

### Anker verschieben

Das ist der Weg fuer alles, was sich schlecht beschreiben laesst – wenn eine
Waffe zwei Pixel zu tief im Arm sitzt, ist Nachziehen schneller als jeder
Prompt:

1. Slot rechts anwaehlen
2. **Anker bearbeiten** einschalten – ein Achsenkreuz setzt sich auf den Anker
3. Am **Pfeil** ziehen bewegt den Anker nur auf dieser Achse **des Bots**, in
   Viertel-Einheiten; `Shift` dabei gedrueckt halten macht es stufenlos.
   Der **Punkt in der Mitte** verschiebt frei. Hat ein Teil mehrere Anker,
   uebernimmt ein Klick auf einen anderen Griff das Achsenkreuz.
4. Wer lieber abzaehlt als zielt, nimmt den **Anker-Block** rechts: Auswahl,
   genaue x/y-Werte und `±1` / `±¼` je Achse.
5. **Anker speichern** schreibt die neuen Werte in die `.json` des Teils

| Pfeil | Achse | auf dem Bildschirm |
|---|---|---|
| **V** | vor   | diagonal, Richtung Blickrichtung des Bots |
| **L** | links | diagonal, zur linken Seite des Bots |
| **H** | hoch  | senkrecht |

Das Achsenkreuz ist kein Komfort, sondern der Grund, warum sich Anker
ueberhaupt verlaesslich setzen lassen: in der Iso-Ansicht ist eine
Mausbewegung nach unten-links mehrdeutig – sie kann *vor* oder *runter*
heissen. Ohne Fuehrung trifft man den gemeinten Punkt nur zufaellig.

Verschiebt man den Anker eines Koerpers, wandert alles mit, was daran haengt –
live, waehrend man zieht. Beim `mount` eines angebauten Teils steht die
Vorschau dagegen bis zum Loslassen still: dieser Anker verschiebt nicht sich
selbst, sondern das Teil, und liefe die Vorschau mit, zoege der Griff sich
selbst davon.

---

## Repo-Struktur

```
main.py                      Entwicklungsserver + REST-API (nur stdlib)
index.html                   Frontend, JS + CSS eingebettet, laeuft offline
parts/                       Teile-Bibliothek
  README.md                  >> Format-Spezifikation: Anker, JSON, Farben <<
  bot1/                      RX-Vireo // Scout       (2 Anker, bis mittel)
  bot2/                      HX-Molok // Juggernaut  (3 Anker, Schulter nur Support)
  bot3/                      AR-Nimbus // Technomant (rund, Fahrgestell)
  bot4/                      LR-Strix // Marksman    (1 Anker, dafuer schwer)
builds/                      Export-Ziel (Inhalt ist gitignored)
tools/
  build_sample_parts.py      Iso-Renderer + Beispielsatz; ausfuehrbare Format-Spec
  export_parts_table.py      Teile-Uebersicht als Excel-Mappe (erzeugt, nicht gepflegt)
docs/
  GAME_DESIGN.md             Setting, DROME-Aufbau, Teile-Codes, Aggro, Asset-Strategie
  GODOT_INTEGRATION.md       wie die Exporte spaeter in die Engine kommen
  cyberdrome_teile.xlsx      erzeugte Teileliste -- ein Blatt je Bauteiltyp
```

## Teileliste als Excel-Mappe

```bash
python3 tools/export_parts_table.py            # -> docs/cyberdrome_teile.xlsx
```

Ein Blatt je Bauteiltyp -- **Koerperteile**, **Kopfteile**, **Fussteile**,
**Kerne** -- und zwei fuer die Ausruestung, getrennt nach **Waffe** und
**Sonstigem** (Schild, Support). Jedes Blatt zeigt nur die Werte, die sein Typ
ueberhaupt fuehrt; ein Kopf hat keine Traglast, ein Kern keine Bewegung.
Darueber liegt das Blatt **Alle Teile** mit dem vollen Wertesatz zum Filtern,
darunter **Chassis & Slots** und die **Kompatibilitaets**-Matrix.

Alle Zahlen kommen aus den Teil-JSONs. Wer einen Wert aendern will, aendert ihn
dort und laesst die Mappe neu erzeugen -- eine von Hand gefuehrte Teileliste
laeuft nach dem dritten Set auseinander.

Das Skript prueft sich beim Erzeugen selbst: es rechnet die Formeln der Mappe
nach und vergleicht sie gegen die Regeln im Code -- die Slot-Matrix gegen
`fits_rule()`, die Kampfwert-Spalten gegen `DromeBuild.power_score()`. Ein
verrutschter Zellbezug faellt beim Ansehen nicht auf, eine falsche Antwort
schon.

Die Formeln haben nach dem Lauf noch keine gespeicherten Ergebnisse -- Excel
und LibreOffice rechnen sie beim Oeffnen aus. Nur Werkzeuge, die die Datei ohne
Tabellenprogramm lesen (pandas, Vorschaubilder), sehen dort leere Zellen.

## Ein neues Teil hinzufuegen

Kurzfassung – Details in [`parts/README.md`](parts/README.md):

* **Isometrische Kamera, 45 Grad von oben.** Ein Bodenfeld ist eine Raute im
  Verhaeltnis sqrt(2):1 – im Tool 76 x 54 px um `(64, 96)`. Von jedem Quader
  sind immer drei Flaechen sichtbar: zwei Flanken und die Oberseite.
* **Das Licht haengt am Bildschirm, nicht am Bot:** Oberseiten
  `--c-plate-light`, linke Flanken `--c-plate`, rechte Flanken
  `--c-plate-dark`. Das ist keine Geschmacksfrage, sondern die Beleuchtung.
* Ein gemeinsames Koordinatensystem: `viewBox="0 0 128 128"`, Mittelachse
  `x=64`. Jedes Teil zeichnet dort, wo es am fertigen Bot sitzt.
* Keine Hex-Farben im SVG, nur `var(--c-plate)`, `var(--c-accent)` usw. Die
  acht Rollen sind aber nur die Ausgabe: eingestellt wird ueber **vier
  Kategorien je Bauteiltyp** (Kopf: Panzerung/Mechanik/Visier/Kontur, Kern:
  Gehaeuse/Kernglut/Energieringe/Kontur). Kante und Schatten der Panzerung
  leitet das Tool aus der Grundfarbe ab -- die Iso-Beleuchtung kann so gar
  nicht falsch eingestellt werden.
* Der Koerper definiert die Sockel-Anker (`head`, `feet`, `core`, `equip_*`),
  jedes andere Teil genau einen Anker `mount`. `links`/`rechts` meinen die
  Seiten des **Bots**, nicht den Bildschirm.
* Wie viele Ausruestungsslots eine DROME hat, ergibt sich allein daraus, wie
  viele `equip_*`-Anker ihr Koerper besitzt – ohne Sonderfall im Code. **Was**
  in einen Slot darf, sagen `mount_class` / `category` auf der Ausruestung und
  `slot_rules` auf dem Koerper: ein Sprinter traegt keine Belagerungskanone,
  eine Schulterbruecke kein Schild.
* **Ein Kern sitzt IM Chassis, nicht davor.** Er gehoert in einen Schacht der
  Brust- oder Rueckenplatte und darf hoechstens eine Entwurfseinheit
  heraussehen. Regelfall ist die Brust; wo sie besetzt ist, ist der Ruecken die
  bessere Wahl (der Strix traegt seinen Kern im Gegengewichts-Ausleger, weil
  vor seiner Brust die Lanze liegt). Der Grund ist die Zeichenweise: der zusammengebaute Bot hat
  keinen Tiefenpuffer, der Kern deckt den Koerper an seiner Stelle vollstaendig
  ab – was vorsteht, wirkt nicht tief, sondern aufgeklebt. Der Generator misst
  das (`parts/README.md`, Abschnitt 6b) und bricht ab.
* **Zwei Teile mit unterschiedlicher Spielfunktion muessen sich an der
  Silhouette unterscheiden** – nicht an der Groesse. Im Iso-Bild ist Groesse
  keine verlaessliche Information, und in einem deterministischen Tactics ist
  eine Waffe, der man ihre Reichweite nicht ansieht, ein Regelfehler. Der
  Generator misst das und bricht bei Ausruestung ab
  (`parts/README.md`, Abschnitt 6a).
* Jedes Teil bekommt einen **Teile-Code** (`CHS-001`, `EQP-004`) als stabile
  Kennung fuers Game Design, zusaetzlich zum Klarnamen.

**Der guenstigste Weg zu neuen Teilen** ist nicht, vier Richtungen zu zeichnen,
sondern das Teil **einmal** als Quader-Definition in `tools/build_sample_parts.py`
zu beschreiben:

```python
SCOUT_HEAD = [
    B((-6.5, 6.5), (-7.5, 7.5), (66, 76), "plate"),   # (vorn, links, hoch)
    B((-7, 7), (-8, 8), (76, 78), "light"),           # Helmdach
    B((6.5, 7.1), (-5.5, 5.5), (68.5, 73), "visor"),  # Visier vorn
]
```

Der Renderer erzeugt daraus alle vier Ansichten. Sichtbarkeit, Beleuchtung und
Zeichenreihenfolge fallen ab: das Visier verschwindet in der Nordansicht von
selbst, die Kuehlrippen auf der Rueckseite erscheinen dort.

Neben dem Quader `B` gibt es die Scheibe `D` und den Rotationskoerper `L` --
letzterer ist alles Runde: Zylinder, Kuppel, Orb, Ring und Rad sind derselbe
Aufruf mit anderem Profil. `parts/bot3` besteht fast vollstaendig daraus.

Wer stattdessen fertige SVGs einfuegen will, nutzt im Tool *Neues Teil
importieren…* und setzt die Anker anschliessend auf der Buehne.

## REST-API

| Methode | Pfad | Zweck |
|---|---|---|
| `GET` | `/api/library` | komplette Bibliothek (`?refresh=1` liest neu ein) |
| `PUT` | `/api/part/<set>/<stem>` | Teil-Metadaten ueberschreiben |
| `POST` | `/api/part` | neues Teil anlegen (SVG + Metadaten) |
| `DELETE` | `/api/part/<set>/<stem>` | Teil loeschen |
| `GET` | `/api/builds` · `/api/builds/<name>` | Builds listen / laden |
| `POST` | `/api/build` | Build speichern (`{name, svg, loadout}`) |
| `GET`/`PUT` | `/api/palettes` | Farbpaletten (Kategorien je Bauteiltyp) |
| `POST` | `/api/squad` | Squad fuer den Kampf sichern (`builds/squad.json`) |

Alle Pfadsegmente werden gegen `^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$` geprueft,
zusaetzlich wird der aufgeloeste Pfad gegen das erlaubte Verzeichnis validiert.

## Technische Entscheidungen

**Kein SVG.js, kein Framework, kein `node_modules`.** Ursprünglich war SVG.js
vorgesehen; die Manipulation beschraenkt sich am Ende aber auf `<g>`-Container
plus `transform`-Attribut, dafuer waere eine Bibliothek reiner Ballast – und
eine CDN-Einbindung wuerde das Tool offline unbrauchbar machen. Wer spaeter doch
SVG.js will, muss nur `renderBot()` in `index.html` austauschen; alles andere
haengt an den Datenstrukturen, nicht am DOM.

**Kein Flask.** `http.server` reicht fuer ein lokales Werkzeug vollstaendig und
haelt `python3 main.py` als einzigen Startbefehl aufrecht.

**Teile werden als Quader definiert, nicht als SVG gezeichnet.** Der Generator
in `tools/build_sample_parts.py` projiziert eine bot-lokale Quader-Beschreibung
in alle vier Richtungen und leitet Sichtbarkeit, Beleuchtung und
Zeichenreihenfolge daraus ab. Vier handgezeichnete Ansichten pro Teil waeren
nicht nur vierfache Arbeit, sondern wuerden bei jeder Aenderung auseinander
laufen – genau der Fehler, an dem das Vorgaengerprojekt gescheitert ist.
Fertige SVGs aus anderer Quelle funktionieren weiterhin; sie muessen sich nur
an dieselbe Projektion halten.

**Richtungsunabhaengige Teil-IDs.** Ein Loadout speichert `scout_head`, nicht
`scout_head_south`. Ein Richtungswechsel loest dieselbe ID gegen die passende
Variante auf – dieselbe Bestueckung laesst sich so mit einem Klick in allen vier
Ansichten exportieren.
