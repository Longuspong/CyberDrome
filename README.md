# CyberDrome

**Autobattler in Echtzeit mit Roguelike-Einsatz** im Cyberpunk-/Neon-Setting,
in 3D mit fester Iso-Kamera auf ein Hexfeld (Karte je Formation, Standard
9 x 15). Engine: **Godot 4.7**, Ziel: Handy im Hochformat (PWA auf Vercel als
Testweg, Android-APK spaeter).

Gespielt wird mit **DROMEs** -- *Death Robot Omni Machine Executor* --,
Kampfmaschinen aus Chassis, Kopf, Antrieb, Kern und Waffe (Molok: zwei
Waffen). Der Spieler entscheidet ueber Aufbau, Squad und Module; im Kampf
steuert die KI beide Seiten.

Leitplan der aktuellen Phase: `docs/KERNPLAN.md`. Was gebaut, gemessen und
entschieden ist: `docs/PROJEKTSTAND.md`. Arbeitsnotizen: `CLAUDE.md`.

```bash
godot --path .                                         # Spiel
godot --headless --path . --script res://tests/run_tests.gd   # Tests
bash tools/build_web.sh                                # Web-Export nach build/web
```

Die Teile entstehen im Generator `tools/build_sample_parts.py` (Werte in der
Tabelle `STATS`): je Teil ein 3D-Modell (`<id>.m3d`) und die Suedansicht als
Symbol. `tools/bake_godot_assets.py` legt den Satz fuer Godot unter
`assets/parts/` ab.

### Kampf

* Alle DROMEs handeln **gleichzeitig**. `BattleManager.tick()` rechnet in
  festen Schritten (0,05 s), derselbe Seed ergibt denselben Kampf.
* Das Feld hat keine Gelaenderegeln und keine Sichtlinie. Feste Bloecke der
  Kartenform sperren nur Laufwege, Schuesse gehen darueber.
* Jede Waffe hat ihr **Schussintervall**, SPD ist die Laufgeschwindigkeit.
  Der N-te Angriff einer Waffe IST ihre Faehigkeit (**Takt**).
* Je **Puls** (3 s): Reparatur, Kabelbrand, ab Minute 5 der Virusschaden.
* Passiven: Vireo **Cyberspeed**, Nimbus **Echo**, Strix **Anlegen**; der
  Molok hat vorerst keine (neue im Kernplan als Entwurf).

### Einsatz (Roguelike, Code-Name "Lauf")

Eine Kampfkarte mit festen Wegen (FTL-artig), drei Leben, alles am Seed
(`scripts/core/run_state.gd`, Werte unter `run` in `data/config.json`).
Gegner sind handverlesene Formationen aus DROMEs und Sentinels
(`data/formations.json`), die mit dem Reinforcement-Level wachsen. Module
(Amps, Fusionen, Hyperfusionen, BIOS) gibt es nur im Einsatz. Beute sind
Lootcaches der Fraktion oder Platzhaltercoin.

### Bedienung (Mobile first, Hochformat)

* **Entwurfsraum 450x800**: ein Entwurfspixel ist etwa ein CSS-Pixel.
* Tab-Leiste unten mit fuenf Tabs, ein Verb je Tab: **Shop** (kaufen),
  **Fabrik** (herstellen: Platine und Werkbank), **Home** (spielen),
  **DROMEs** (ausruesten, aufwerten), **Inventar** (lagern). Optionen am
  Zahnrad oben rechts.
* Halter als Formen: Dreieck leicht, Viereck mittel, Fuenfeck schwer.
* Kacheln (`Tile`): tippen waehlt, nochmal tippen zeigt Details, Doppeltipp
  handelt. Erklaerungen als Popup (`InfoPopup`). Stil: Arcade-Glitch
  (`scripts/ui/arcade.gd`, `scripts/ui/ui_kit.gd`).

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
  bot1/                      RX-Vireo // Scout       (1 Waffe, bis mittel)
  bot2/                      HX-Molok // Juggernaut  (2 Waffen)
  bot3/                      AR-Nimbus // Technomant (rund, Fahrgestell)
  bot4/                      LR-Strix // Marksman    (1 Waffe, dafuer schwer)
tools/
  build_sample_parts.py      Generator: 3D-Modell (.m3d) + Symbol (Suedansicht) je Teil
  bake_godot_assets.py       loest die CSS-Variablen auf -> assets/parts/
  set_import_scale.py        wie fein Godot rastert (Vierfach) + Mipmaps
  build_terrain_tiles.py     Bodenkacheln der Regionen (derselbe Renderer)
  playtest/                  Kaempfe ohne Bildschirm, mit Aktionslog
tests/
  run_tests.gd               Testlauf ohne Editor
  screenshot.gd              Bild einer Szene -- Tiefensortierung, Verdeckung
  smoke_ui.gd                baut die Bildschirme headless auf
docs/
  KERNPLAN.md                Leitplan der aktuellen Phase
  PROJEKTSTAND.md            was gebaut, gemessen und entschieden ist
  spot/                      SPOT-Tabellen und Werkblaetter
data/
  config.json                Balancing-Stellschrauben ausserhalb der Bauteile
  formations.json            Gegnerteams (Formationen)
  modules.json               Amps, Fusionen, Hyperfusionen, BIOS
  factory.json               Fabrik, Werkbank, Level-Kosten
```

## Ein neues Teil hinzufuegen

Neue Teile entstehen **nur im Generator**: das Teil einmal als Koerper-
Definition in `tools/build_sample_parts.py` beschreiben, Werte in `STATS`
eintragen, dann

```bash
python3 tools/build_sample_parts.py     # Modell (.m3d) + Symbol + JSON nach parts/
python3 tools/bake_godot_assets.py      # Kopie fuer Godot nach assets/parts/
```

```python
SCOUT_HEAD = [
    B((-6.5, 6.5), (-7.5, 7.5), (66, 76), "plate"),   # (vorn, links, hoch)
    B((-7, 7), (-8, 8), (76, 78), "light"),           # Helmdach
    B((6.5, 7.1), (-5.5, 5.5), (68.5, 73), "visor"),  # Visier vorn
]
```

Neben dem Quader `B` gibt es die Scheibe `D` und den Rotationskoerper `L`
(Zylinder, Kuppel, Orb, Ring, Rad); `parts/bot3` besteht fast ganz daraus.
Gezeichnet wird im Spiel das 3D-Modell (`DromeModel`); die Render-Helfer unter
`docs/design/drome_entwurf/godot/` zeigen es ohne Spiel.

Regeln, die der Generator prueft (Details in [`parts/README.md`](parts/README.md)):

* **Lesbarkeit:** zwei Teile mit unterschiedlicher Spielfunktion muessen sich
  an der Silhouette unterscheiden, nicht an der Groesse (Abschnitt 6a).
* **Der Kern sitzt IM Chassis**, in einem Schacht von Brust oder Ruecken
  (Abschnitt 6b).
* **Halter:** wie viele Waffen ein DROME traegt, ergibt sich aus den
  `equip_*`-Ankern des Chassis; was hineinpasst, aus `mount_class` (leicht,
  mittel, schwer) auf der Waffe.
* **Teile-Code** (`CHS-001`, `EQP-004`) als stabile Kennung neben dem
  Klarnamen; Loadouts speichern richtungsunabhaengige IDs (`scout_head`).
