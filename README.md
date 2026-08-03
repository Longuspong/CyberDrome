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

Aktueller Stand: **SVG-Werkstatt** (Schritt 1). Noch kein Godot-Projekt.

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
| **Bibliothek** | alle Teile nach Typ gruppiert, mit Live-Vorschau in der aktiven Palette und Teile-Code, Filter nach Code/Name/Tag/Typ, optional set-uebergreifend |
| **Vier Richtungen** | N / W / O / S; beim Umschalten werden alle Teile automatisch auf ihre Variante fuer diese Richtung gewechselt |
| **Anker-Montage** | Teile rasten ueber die Ankerpunkte aus der JSON ein – kein manuelles Positionieren noetig |
| **Bestuecken** | Klick in der Bibliothek (angewaehlter Slot, sonst erster freier), Drag & Drop auf die Buehne (naechstgelegener passender Anker) oder Dropdown pro Slot |
| **Feinjustierung** | Versatz, Groesse, Drehung, Spiegeln, Zeichenebene je Slot – Pfeiltasten zum Nudgen, `Shift` fuer 0,25er-Schritte |
| **Anker-Editor** | Ankerpunkte direkt auf der Buehne verschieben und in die JSON des Teils zurueckschreiben |
| **Palette** | acht Farbrollen, Presets speicherbar, optional pro Slot abweichend |
| **Import** | von Claude Code generierten SVG-Quelltext einfuegen → Tool legt SVG + JSON an |
| **Export** | SVG + JSON nach `/builds/`, alle vier Richtungen auf einmal, Spritesheet, SVG-/PNG-Download |

### Bedienung in 30 Sekunden

1. Set oben links waehlen – ein Koerper ist bereits gesetzt.
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

### Anker verschieben

Das ist der Weg fuer alles, was sich schlecht beschreiben laesst – wenn eine
Waffe zwei Pixel zu tief im Arm sitzt, ist Nachziehen schneller als jeder
Prompt:

1. Slot rechts anwaehlen
2. **Anker bearbeiten** einschalten – die Anker des Teils werden zu Griffen
3. Griff ziehen; die Vorschau aktualisiert sich live
4. **Anker speichern** schreibt die neuen Werte in die `.json` des Teils

Verschiebt man den Anker eines Koerpers, wandert alles mit, was daran haengt.

---

## Repo-Struktur

```
main.py                      Entwicklungsserver + REST-API (nur stdlib)
index.html                   Frontend, JS + CSS eingebettet, laeuft offline
parts/                       Teile-Bibliothek
  README.md                  >> Format-Spezifikation: Anker, JSON, Farben <<
  bot1/                      RX-Vireo // Scout      (2 Ausruestungsanker)
  bot2/                      HX-Molok // Juggernaut (3 Ausruestungsanker)
builds/                      Export-Ziel (Inhalt ist gitignored)
tools/
  build_sample_parts.py      Iso-Renderer + Beispielsatz; ausfuehrbare Format-Spec
docs/
  GAME_DESIGN.md             Setting, DROME-Aufbau, Teile-Codes, Asset-Strategie
  GODOT_INTEGRATION.md       wie die Exporte spaeter in die Engine kommen
```

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
* Keine Hex-Farben im SVG, nur `var(--c-plate)`, `var(--c-accent)` usw.
* Der Koerper definiert die Sockel-Anker (`head`, `feet`, `core`, `equip_*`),
  jedes andere Teil genau einen Anker `mount`. `links`/`rechts` meinen die
  Seiten des **Bots**, nicht den Bildschirm.
* Wie viele Ausruestungsslots eine DROME hat, ergibt sich allein daraus, wie
  viele `equip_*`-Anker ihr Koerper besitzt – ohne Sonderfall im Code.
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
| `GET`/`PUT` | `/api/palettes` | Farbpaletten |

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
