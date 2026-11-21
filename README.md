# CyberDrome

**Autobattler in Echtzeit** im Cyberpunk-/Neon-Setting, **isometrisch**
(Kamera 45 Grad von oben auf ein Hexfeld 9 x 17, seit 17. Nov. 2026). Engine: **Godot
4.7**, Ziel: Handy im Hochformat (PWA auf Vercel), Android spaeter.

Gespielt wird mit **DROMEs** -- *Death Robot Omni Machine Executor* --,
Kampfmaschinen aus Chassis, Kopf, Antrieb, Kern und der Ausruestung, die das
Chassis ueber seine Halter zulaesst. Der Spieler entscheidet ueber Aufbau,
Squad und Belohnungen; im Kampf steuert die KI beide Seiten.

Die Optik laeuft ueber **SVG** statt Pixelart (kombinierbar, umfaerbbar,
aufloesungsfrei). Arbeitsstand und Entscheidungen: `docs/PROJEKTSTAND.md`,
der laufende Neuentwurf des Spielprinzips: `docs/NEUANFANG.md`.

```bash
godot --path .                                         # Spiel
godot --headless --path . --script res://tests/run_tests.gd   # Tests
bash tools/build_web.sh                                # Web-Export nach build/web
```

Godot rastert die Quell-SVGs nicht direkt -- es kennt keine CSS-Variablen --,
deshalb erzeugt `tools/bake_godot_assets.py` den Satz unter `assets/parts/`.
Die Teilwerte stehen in `tools/build_sample_parts.py` (Tabelle `STATS`) und
landen von dort in den Teil-JSONs unter `parts/`.

### Kampf

* Alle DROMEs handeln **gleichzeitig**. `BattleManager.tick()` rechnet in
  festen Schritten (0,05 s), derselbe Seed ergibt denselben Kampf.
* Das Feld ist **frei**: kein Gelaende, keine Sichtlinie. Das Gitter traegt
  Reichweite, Bewegung, Aufstellung und die Iso-Optik; zwei DROMEs teilen
  sich nie ein Feld.
* Jede Waffe hat ihr **Schussintervall**, SPD ist die Laufgeschwindigkeit,
  Faehigkeiten loesen **von selbst** aus (jeder N-te Angriff, nach Zeit oder
  wenn ein Gegner danebensteht).
* Je **Puls** (3 s): Schildregeneration, Drohnen-Pod, Overtime (ab 60 s).
* Unten: Tempo 1x/2x, Pause, Log, Folgen. Kamera folgt dem Geschehen,
  Ziehen und Zoomen per Finger.

### Einsatz (Roguelike, Code-Name "Lauf")

Acht Kaempfe, drei Leben, alles am Seed (`scripts/core/run_state.gd`, Werte
unter `run` in `data/config.json`). Eine Kampfkarte mit festen Wegen (FTL-
artig); Gegner sind Formationen aus DROMEs und Sentinels
(`data/formations.json`), die mit dem Reinforcement-Level wachsen. Beute sind
Lootcaches der Fraktion oder Platzhaltercoin. Ab Minute 5 trifft der
Virusschaden jede Einheit.

### Mobile first (Hochformat)

* **Entwurfsraum 450x800**: ein Entwurfspixel ist etwa ein CSS-Pixel.
* **`scripts/ui/ui_kit.gd`**: Seitenrahmen, Karten, grosse Knoepfe, Tab-Leiste
  unten (Spielen, Hangar, Shop), Optionen am Zahnrad oben rechts.
* **Hangar**: Reiter *Squad* (max. 3) und *Umbau* (Halter als Formen:
  Dreieck leicht, Viereck mittel, Fuenfeck schwer, Kreis Kern).
* Wischen scrollt jede Liste mit Schwung, langes Druecken zeigt den Erklaertext.
* Kacheln (`Tile`): einmal tippen handelt, doppelt tippen oder lange druecken
  oeffnet das Popup (`InfoPopup`). Stil: Arcade-Glitch (`scripts/ui/arcade.gd`).
* Optionen (Zahnrad): Schriftgroesse (nur Text), Animationen reduzieren, Vollbild.
* **Shop** (Tab): Baukerne und Caches fuer Platzhaltercoin, Caches, neue DROMEs
  bauen (3 Baukerne; Fraktions-DROME mit Fraktionskern). DROMEs werden verwertet.

### PWA

`tools/build_web.sh` holt Godot und die zwei Web-Templates und exportiert
nach `build/web`. Vercel (`vercel.json`) und GitHub Pages
(`.github/workflows/web.yml`) benutzen dasselbe Skript.

---

## Repo-Struktur

```
vercel.json                  Hosting: baut und liefert das SPIEL (tools/build_web.sh)
parts/                       Teile-Bibliothek
  README.md                  >> Format-Spezifikation: Anker, JSON, Farben <<
  bot1/                      RX-Vireo // Scout       (2 Anker, bis mittel)
  bot2/                      HX-Molok // Juggernaut  (3 Anker, Schulter nur Support)
  bot3/                      AR-Nimbus // Technomant (rund, Fahrgestell)
  bot4/                      LR-Strix // Marksman    (1 Anker, dafuer schwer)
tools/
  build_sample_parts.py      Generator: 3D-Modell (.m3d) + Symbol (Suedansicht) je Teil
  bake_godot_assets.py       loest die CSS-Variablen auf -> assets/parts/
  set_import_scale.py        wie fein Godot rastert (Vierfach) + Mipmaps
  build_terrain_tiles.py     Bodenkacheln der Regionen (derselbe Renderer)
  playtest/                  Kaempfe ohne Bildschirm, mit Aktionslog
tests/
  run_tests.gd               Testlauf ohne Editor
  screenshot.gd              Bild einer Szene -- Tiefensortierung, Verdeckung
  smoke_ui.gd                baut den Hangar headless auf
docs/
  PROJEKTSTAND.md            was gebaut, gemessen und entschieden ist
  NEUANFANG.md               Neuentwurf des Spielprinzips (zur Besprechung)
  GAME_DESIGN.md             Setting, DROME-Aufbau, Teile-Codes, Asset-Strategie
                             (Spielregeln darin teils veraltet, siehe Kopf)
  GODOT_INTEGRATION.md       Engine-Version, Import, Export
  PLAYTEST_2026-11.md        Playtest des Echtzeit-Kampfs
data/
  config.json                Balancing-Stellschrauben ausserhalb der Bauteile
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

**Neue Teile entstehen im Generator** (seit 20. Nov. 2026 der einzige Weg, die
SVG-Werkstatt ist entfernt): das Teil **einmal** als Quader-Definition in
`tools/build_sample_parts.py` beschreiben:

```python
SCOUT_HEAD = [
    B((-6.5, 6.5), (-7.5, 7.5), (66, 76), "plate"),   # (vorn, links, hoch)
    B((-7, 7), (-8, 8), (76, 78), "light"),           # Helmdach
    B((6.5, 7.1), (-5.5, 5.5), (68.5, 73), "visor"),  # Visier vorn
]
```

Der Generator schreibt daraus das 3D-Modell (`<id>.m3d`, gezeichnet von
`DromeModel`) und die Suedansicht als Symbol fuer Kacheln und Halter.
Ansehen: die Render-Helfer unter `docs/design/drome_entwurf/godot/`.

Neben dem Quader `B` gibt es die Scheibe `D` und den Rotationskoerper `L` --
letzterer ist alles Runde: Zylinder, Kuppel, Orb, Ring und Rad sind derselbe
Aufruf mit anderem Profil. `parts/bot3` besteht fast vollstaendig daraus.

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
