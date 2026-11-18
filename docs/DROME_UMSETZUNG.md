# DROME-Umsetzung: Stand und Plan (16. Nov. 2026)

Was aus den DROME-Designregeln (`docs/DROME_DESIGNREGELN.md`) schon im Spiel
ist, was noch fehlt und in welcher Reihenfolge. Die Bilder dazu liegen in der
„DROME Design-Studie“ auf Claude Design (privat beim Spieler, Boards 1–13),
die Entwurfs-Skripte unter `docs/design/drome_entwurf/`.

**Arbeitsweise:** je Schritt ein eigener Commit (oder PR), danach immer
`python3 tools/build_sample_parts.py`, `python3 tools/bake_godot_assets.py`,
bei neuen SVG-Dateien `python3 tools/set_import_scale.py` und
`godot --headless --path . --import` (sonst rastert Godot sie grob -- 17. Nov.
waren die neuen Arme deshalb unscharf), dann
`run_tests.gd`, `smoke_ui.gd`, `build_spot.py --check` und ein Screenshot von
Hangar und Kampf (`tests/screenshot.gd`). Werte der DROMEs ändern sich in
keinem Schritt -- nur Form, Licht und Bewegung.

## Erledigt (PR #69)

- [x] Regeln abgesegnet, Entwürfe und Skripte im Repo, SPOT-Eckpunkte
- [x] Ansicht außerhalb des Kampfes bleibt **von vorn** (south)
- [x] **Licht + Kontur je Teil**: Paletten ~40 % heller; `bake_godot_assets.py`
      backt je Teil `*_rim.svg`; `DromeSprites` hängt die Kontur als Kind des
      Teils an (Konturen Ebene 0, Teile ab 1)
- [x] **Generator-Regeln**: `body_kind`; Tag `melee`/`ranged` aus der
      Reichweite (bis 2 / ab 3); Halterregel `reach`; Strix-Lafette nur
      Fernkampf; Fadenkreuz/Schwert in `SlotShape`; Modulbedingungen mit
      derselben Grenze (Bumerang zählt jetzt als Nahkampf)
- [x] **Strix als Eule** (Rumpf mit Flügelmantel und Lafette, Eulenkapuze,
      Beine mit Knie nach hinten, Kern am Rücken, Lanze und Mörser auf der
      Lafette)
- [x] Hangar: Squad-Knopf in den Kacheln wieder 38 px

## Offen -- in dieser Reihenfolge

### 1. Chassis Vireo -- erledigt (16. Nov.)
Quelle: `v4.py` (`VIREO`, `V_BOOSTER`, `V_PASSIVE_ARM`) bzw. `new_dromes.py`
(`V_BODY`, `V_LEG`).
- [x] Rumpf: V-Torso, schlanke Taille, Schultern; **großer Rücken-Booster mit
      Flügeln** und Düsen (Passive Sprint)
- [x] Kopf: Helm mit Visier, Kamm statt Antenne, **zwei Helm-Booster**
      (Kopf-Anker jetzt `z 65`)
- [x] Passiv-Arm (rechts, `-l`) liegt am Körper an -- fester Teil des Rumpfs
- [x] Waffenarm kommt weiter mit der Waffe; Anker `equip_left` an der
      Schulter (`(0, 14.5, 54)`), bis Schritt 4 hängen die alten Waffenarme
- [x] Beine schlanker, Knieschutz, spitze Füße
- Kern sitzt eine Stufe höher (`z 51`), im Sockel der neuen Brustplatte

### 2. Chassis Nimbus -- erledigt (16. Nov.)
Quelle: `v4.py` (`NIMBUS`, `N_ORB_ARM`, `N_HALO`).
- [x] Rumpf, Hut und Rad bleiben; **Orb-Arm**: Unterarm 90° nach vorn mit
      Energiekugel, Ring um die Kugel (Passive Echo) -- fester Teil des Rumpfs
- [x] **Leuchtring hinter dem Kopf** (Leuchtelement) als Teil des Kopfes
- [x] Waffenarm (rechte Hand, `+l`) kommt mit der Waffe; Anker bleibt
      `(0, 13.8, 47)`, bis Schritt 4 hängen die alten Waffenarme

### 3. Chassis Molok -- erledigt (16. Nov.)
Quelle: `v4.py` (`MOLOK`, `M_ARM`) und `v2.py` (`M_BEACON`).
- [x] Kopf tief zwischen den Schultern (Kopf-Anker `z 60.5`), Schultern
      höher, Frontpanzer mit Kernsockel
- [x] **Zwei Schulteranker** (`(0, ±19, 57)`), beide Unterarme kommen mit
      den Waffen; `equip_shoulder` bleibt Optik. Bis Schritt 4 hängen die
      alten, kleinen Waffenarme (Armmaß 1,6 kommt mit den Posen)
- [x] **Lockfeuer** auf dem Rücken zwischen den Auspuffen (Passive Präsenz)
- [x] Kopf, Auspuffe und Lockfeuer gehören zum **Rumpf** (17. Nov.): der Kopf
      sitzt tiefer als die Schultern, von hinten muss die nahe Schulter ihn
      verdecken -- als eigenes Sprite lag er immer oben. Das Kopfteil
      `jugg_head` bleibt als leerer Platzhalter

### 4. Waffen in ihre Posen -- erledigt (16. Nov.)
Quelle: `v4.py`/`v6.py`; gebaut in `tools/build_sample_parts.py` (Abschnitt
„Waffen in Posen“: `_arm_extended`, `_arm_raised`, `_head_*`, `weapon_set`).
Regel: Der Waffenarm hängt nie gerade. Jede Pose ist symmetrisch zur
Armebene gebaut -- dasselbe Bild passt an beide Molok-Arme, ohne Spiegeln.
- [x] Fernkampf gestreckt, Waffe statt Hand: Puls-Blaster, Neon-Blaster
      (mit Neonröhren und Mündungsring)
- [x] Nahkampf angewinkelt, Waffe nach oben, **mit Griff, Knauf,
      Parierstange**: Plasmaklinge, Hammer, Bollwerk-Ramme (stößt vor),
      Klingenbumerang (wurfbereit, „L“ nach oben und vorn)
- [x] Stab/Werkzeug senkrecht mit Griffwicklung: Runenstab,
      E-Schraubenschlüssel
- [x] Schild direkt vor dem Körper (eigene kurze Armhaltung, deckt die
      Körpermitte): Deflektor (17. Nov. nachgebessert)
- [x] Zeichenreihenfolge der Waffen: Tiefe nicht am Schulteranker, sondern
      vor dem Körper zur Mitte hin auf Rumpfhöhe gemessen
      (`WEAPON_DEPTH_AHEAD`/`_INWARD`) -- von hinten liegt eine Waffe, die
      vor dem Körper hängt, hinter dem Rumpf
- [x] **Varianten** je Waffe: `heavy` (Armmaß 1,6, Molok) und `lafette`
      (Fernwaffen ohne Arm auf der Strix-Schulter: Puls-/Neon-Blaster,
      Runenstab und Schlüssel liegend -- Form vorläufig, siehe Frage 1).
      Das Chassis sagt per `weapon_variant`, welche gilt; der Generator
      schreibt `*_heavy_*.svg`/`*_lafette_*.svg`, `PartData.view_for` und
      `DromeSprites` wählen sie
- [x] Molok-Klinge wächst nur bis 1,3 mit (sonst ragt sie aus dem Rahmen)
- [x] Silhouetten-Prüfung grün (engstes Paar Hammer/Schlüssel 0,66)

### 4b. Arme und Waffen trennen -- erledigt (17. Nov.)
Entwurf: `v7.py`, Leinwand „Offene Designpunkte“, Seite „Arme & Waffen (4b)“.
Entschieden (Spieler 17. Nov.): zwei Haltungen, Manschette statt Hand an
Fernwaffen, Hände nur an Armen, die nie etwas tragen, Lafette ohne Griff.
- [x] Arm gehört zum **Chassis**: Chassisfarbe, je Chassis gebaut, als
      Variante des Rumpfs `arm_<slot>_<haltung>` mit Anker `hand`
      (`arm_set`, `light_arm`, `molok_arm` in `build_sample_parts.py`)
- [x] **Zwei Haltungen**: `hold` (halten -- Klinge, Hammer, Stab, Schlüssel,
      Bumerang, Schild; Faust um den Griff) und `aim` (zielen -- Blaster,
      Ramme; Arm endet in einer **Manschette**). Vireo und Nimbus strecken
      beim Zielen den ganzen Arm, der Molok schießt aus der Hüfte. Die Waffe
      sagt per `pose`, welche Haltung sie braucht
- [x] Waffe ist nur das **Gerät**, um den Griffpunkt gebaut (`mount`), sitzt
      am Hand-Anker des Arms; `heavy`/`heavy_right` (Waffenmaß 1,6) bleiben
- [x] Arm und Waffe als **eigene Sprites** mit eigener Tiefe
      (`slot_z["<slot>@<haltung>"]`): gehalten knapp hinter der Faust,
      zielend vor der Manschette gemessen; `DromeSprites` setzt beide
- [x] Schild in „halten“, vor die Brust gerückt, deckt die Körpermitte --
      von hinten verdeckt ihn der Rumpf
- [x] **Molok**: eigene Arme unter den Schulterplatten (dicker Oberarm,
      Ellbogen, Unterarm auf Hüfthöhe, große Faust bzw. Manschette)
- [x] **Hand** nur am Vireo-Passivarm (Handrücken, Finger, Daumen); der
      Nimbus-Orb-Arm hält seine Kugel
- [x] **Strix-Lafette**: Runenstab nur als Kugel mit Fassung, Schlüssel nur
      als Kopf, jeweils auf kurzem Sockel (Frage 1 erledigt)
- [x] Nachgebessert (17. Nov., Rückmeldung Spieler): das Arm-Bild bringt die
      **Schulter seines Chassis** mit (`side_shapes`) -- sonst lag der
      Oberarm als eigenes Sprite vor der Schulterplatte. Schild wieder vor
      der Faust, eigene Tiefe `guard` (= halten, Schild vor dem Arm).
      Neue SVGs mit `set_import_scale.py` auf 4-fache Rasterung gestellt.
      Schild am Molok nur bis Maß 1,25 und seine Tiefe dort gemessen, wo er
      hängt (vor der Hand) -- sonst lag der Brustkern über dem Schild
- [x] **Waffenfarben unabhängig vom DROME**: Tabelle `WEAPON_COLORS` in
      `build_sample_parts.py`, eine Palette je Waffe (Startwerte = bisherige
      Bausatzfarben). Neue Farben: offen, Spieler entscheidet

### 4c. Echtes 3D -- erledigt (17. Nov.)
Spieler: „wir müssen einen echten 3D-Generator machen“ -- nach Überlappungen,
die sich mit Einzelbildern nicht lösen ließen (eine Tiefe je Bild).
- [x] Generator schreibt je Teil ein Modell `<id>.m3d` (Flächen in bot-lokalen
      Koordinaten mit Normale, Material, Art; Varianten; Arme; 3D-Anker;
      Farben). `bake_godot_assets.py` kopiert es, Export-Filter nimmt es mit
- [x] `DromeModel` baut daraus Meshes (eine Fläche je Material), dreht nach
      Blickrichtung; Iso-Kamera bildet exakt wie `to_screen` ab (Test)
- [x] Shader: drei Töne je Material wie `_shade`, dunkle Kanten an Quadern
      und Scheiben, Drehkörper mit Außenkontur (Hülle); Kontur in
      Signalfarbe um den ganzen DROME (`drome_outline.gdshader`)
- [x] `DromeSprites.assemble` rendert den DROME per SubViewport (einmal je
      Aufbau, Drehen dreht nur das Modell) und zeigt ihn als ein Sprite --
      Kampf, Hangar und Podest unverändert angebunden
- Bekannt: die Kontur hat jetzt die Farbe des Chassis (vorher je Teil), das
  Neon-Leuchten (NeonGlow) fehlt am DROME vorerst; beim Zerstören fällt der
  DROME als Ganzes statt in Teilen. `slot_z` und die Arm-SVGs werden noch
  erzeugt, das Spiel braucht sie für DROMEs nicht mehr

**Leistungstest** (17. Nov.): Optionen > Zum Testen > „Leistungstest“
(`scenes/bench.tscn`). Misst Bilder pro Sekunde für 3 bis 48 DROMEs in drei
Arten: ruhend (wie heute), einzeln (jede 3D-Ansicht rendert jedes Bild neu --
Schritt 5 ohne Umbau) und eine gemeinsame 3D-Szene. Der Spieler misst auf
dem Handy (PWA) und später in der App; die Zahlen entscheiden, ob Schritt 5
mit Einzelansichten geht oder eine gemeinsame Szene braucht.

Messung des Spielers (17. Nov., Handy, PWA, WebGL, Bilder/s):

| DROMEs | ruhend | einzeln | eine Szene |
|---|---|---|---|
| 3 | 46 | 39 | 41 |
| 6 | 45 | 39 | 42 |
| 12 | 44 | 38 | 42 |
| 24 | 45 | 29 | 41 |
| 48 | 44 | 25 | 38 |

Die Grenze von ~45 setzt der Browser. Einzelansichten tragen bis ~12 bewegte
DROMEs, die gemeinsame Szene auch 48. Folgerung: Bewegung (Schritt 5) und
ein Hexboden gehören in EINE 3D-Szene für den Kampf.

### 4d. Gedrehter Quader im Generator -- erledigt (17. Nov.)

Neuer Baustein in `tools/build_sample_parts.py`:
`O(mitte, groesse, (gier, nick, roll), mat)` -- ein Quader, der sich drehen
darf (gier um z, nick um l -- positiv kippt die Vorderseite nach unten --,
roll um f; Reihenfolge roll, nick, gier). Bequemer: `OB(p0, p1, breite,
hoehe, mat, roll=0)` legt einen Balken von Punkt zu Punkt. Läuft durch SVG
(`render`), 3D (`model_faces`, Flächenart „box“ mit Kante), Silhouetten- und
Sitzprüfung (`_shape_faces`), Spiegeln (`mirror_obox`, gier/roll kehren sich
um) und `side_shapes`; im Entwurf `new_dromes.shift/mirror`. Ungedreht ist er
bitgleich mit `B`. Erster Einsatz: `docs/design/drome_entwurf/v11_shogun.py`
(Katana, V-Hörner, Umhang glatt statt in Stufen; 180 statt 280 Formen).

### 4e. Kontur je Teil, Neon-Leuchten, Zerfallen in 3D -- erledigt (17. Nov.)

Was beim 3D-Umbau verloren ging, ist zurück:

* **Drei Ansichten einer 3D-Welt** (`DromeSprites.assemble`): `Ansicht3D`
  (das Bild), `Signal3D` (jedes Teil einfarbig in seiner Signalfarbe,
  Ebene `DromeModel.LAYER_SIGNAL`) und nur mit Neon-Teilen `Neon3D`
  (Röhren = Material glow/accent der Neon-Teile in ihrer Farbe, der Rest
  schwarz als Verdecker, `LAYER_NEON`). Jeder Block bekommt dazu Kinder
  „Signal“ und „Neon“ – sie gehen mit, wenn sich der Block bewegt.
  `DromeSprites.redraw(parent, always)` zeichnet alle drei neu.
* **Kontur je Teil**: `drome_outline.gdshader` nimmt die Farbe des Rings aus
  der Signalebene, vom nächstgelegenen Teil. Der Neon-Blaster hat wieder
  seinen magenta Rand, Nimbus-Orbs ihren hellen. Wie früher nur der
  Außenrand (die SVG-Konturen lagen unter allen Teilen).
* **Neon-Leuchten**: `NeonGlow.create_3d` legt die Leuchtebene mit Lichthof
  (`assets/shaders/neon_halo.gdshader`, additiv) über das Bild; Pulsieren
  und Flackern wie bisher. Der Generator markiert Neon-Teile im Modell
  (`"neon": true`).
* **Zerfallen**: `Unit._death_3d` lässt jeden Block (Füße, Rumpf, Kern, Kopf,
  Waffe, Waffenarm) in eigener Richtung wegspringen, um seine Mitte kippen
  und auf den Boden fallen; dann verblasst das Bild.
* Blicktests: `docs/design/drome_entwurf/godot/render_kontur.gd` (alle
  Bausätze in vier Richtungen + Neon-Blaster) und `render_zerfall.gd`
  (Zeitpunkt über `Engine.time_scale`, Aufruf im Dateikopf).

### 4f. Kampf als eine 3D-Szene -- erledigt (18. Nov.)

`Arena3D` (`scripts/ui/arena_3d.gd`): eine 3D-Welt mit allen DROMEs und den
Hindernissen, drei Kameras (Bild, Signal, Neon) folgen der Camera2D des
Kampfbildschirms; das Bild liegt als ein Sprite in der 2D-Welt (über Boden,
Zone, Bodenringen; unter Balken und Effekten). `Unit.arena` gesetzt =
kein eigenes Bild, das Modell folgt Position, Rig (Rückstoß, Sentinel-Größe)
und Blickrichtung. Farbstich/Trefferblende als Instanz-Parameter `tint` in
`drome_face.gdshader`. Umrechnung `Arena3D.ground()` = IsoView-Projektion
(Test). Doppelte Auflösung (`OVERSAMPLE`), Kontur-Shader mit schnellem
Ausstieg (läuft über den ganzen Bildschirm). Hindernisse als 3D-Modelle aus
`tools/build_arena_models.py` (`assets/arena3d/<art>.m3d`, CI prüft mit
`--check`); die gezeichneten Hindernis-Bilder (Neon City) nutzt der Kampf
nicht mehr, Deko am Rand bleibt 2D. **Boden seit 18. Nov. in 3D**:
Hexplatten je Region aus demselben Generator (`floor_<region>_<sorte>.m3d`,
Gewichte in `assets/arena3d/floor.json`), `ArenaFloor3D` rendert sie EINMAL
in ein Weltbild ganz unten (Zone, Ringe, Lichter bleiben darüber);
`ArenaPainter` zeichnet im Kampf nur noch Zierlinie, Lichter und Deko.
Blicktest: `docs/design/drome_entwurf/godot/render_arena.gd` (Region,
optional `angriff ZEITFAKTOR`).

### 5. Bewegung im Teile-Rig (`scripts/battle/unit.gd`, `DromeSprites`)
**Grundstufe gebaut (18. Nov.) in `Arena3D._animate`**: Atmen im Stand
(Rumpf/Kopf/Waffen wippen, Füße fest), Wippen beim Laufen, Nimbus kippt nach
vorn, Eule hüpft; Angriff je Waffenart über die Blöcke `<slot>`/`<slot>_arm`
(Nahkampf holt um die Schulter aus und schlägt zu, Fernkampf Rückstoß +
Aufleuchten der Waffe, Schild stößt vor) statt des Rucks des ganzen DROME.
Werte als Konstanten oben in `arena_3d.gd`. Offen: Passive sichtbar bewegt,
Mündungsblitz am `muzzle`-Anker, Beine im Wechsel.
Entwurf: Board 11, `v5.py` (Ebenen und Drehpunkte).
- [ ] **Idle**: Rumpf/Kopf atmen 1–2 px, Leuchtteile pulsieren, Passive
      bewegt sich mit (Booster flackert, Kugel schwebt, Lockfeuer pulsiert,
      Linsen blinzeln)
- [ ] **Laufen**: Wippen; Nimbus kippt nach vorn, Eule hüpft. Beine im
      Wechsel brauchen getrennte Bein-Sprites -- Vorschlag: `feet` in
      `feet_left`/`feet_right` teilen, erst wenn das Wippen allein nicht reicht
      (entschieden 17. Nov.: zuerst nur Wippen)
- [ ] **Angriff** nach Waffenart (seit 4c in 3D: Arm und Waffe sind eigene
      Knoten `<slot>_arm` und `<slot>` unter `Ausrichtung`, die Ansicht dann
      auf UPDATE_ALWAYS stellen): Nahkampf dreht die Waffe um den
      Schulteranker (ausholen, zuschlagen), Fernkampf Rückstoß + Mündungsblitz
      am `muzzle`-Anker, Schild stößt vor; ersetzt den heutigen Ruck des
      ganzen DROME (`play_attack`)
- [ ] Kontur geht schon mit (Kind des Teils) -- nur prüfen

### 6. Fähigkeiten lesbar (`scripts/ui/battle_view.gd`)
Entwurf: Board 12 (Vortex animiert, Tabelle für alle). Muster: **Wo**
(Bodenmarke in Iso-Perspektive), **Wer** (Signalfarbe), **Was** (eigene Form).
- [ ] **Vortex** zuerst: gestrichelter Iso-Ring während der 0,6 s
      Verzögerung, Runen drehen nach innen, Sog-Pfeile, Treffer, danach
      „verlangsamt“ (Ring am Fuß, Pfeile über dem Kopf, 2,5 s)
- [ ] Sperrfeuer, Präzisionsschuss, Betäubungsschlag, Rammstoß,
      Aufschlitzen, Wirbelwurf, Doppelschuss, Schildbrecher, Schildladung,
      Schildfeld -- je nach Tabelle auf Board 12
- [ ] Gegnerische Fähigkeiten: dieselben Formen, Ring mit rotem Außenrand

### 7. Fraktions-Paletten im Spiel
Quelle: `skins.py`. Neon fast schwarz mit grellem Neon, Solar
biologisch-blühend, Mechas sattes Rot matt mit Absperrstreifen, Hipstar
bleibt.
- [ ] Paletten für Fraktions-DROMEs und Sentinels übernehmen
- [ ] Absperrstreifen: prüfen, ob Godot das SVG-Muster zeichnet, sonst als
      Geometrie

### 8. Auf Claude Design noch offen (vor den passenden Schritten)
- [x] Eule: Linsen größer (Board 16, `v6.py` `LENS_BIG`: Ø 6,8 statt 4,6,
      Lichtpunkt, Gesichtsplatte breiter) -- freigegeben 16. Nov., im Spiel
      seit 17. Nov. (`STRIX_HEAD`)
- [x] Restliche Waffen in Pose (Boards 14/15, `v6.py`): Neon-Blaster
      gestreckt, Bumerang wurfbereit, Ramme stößt vor, E-Schlüssel senkrecht,
      Deflektor an Vireo/Nimbus, Molok mit Armmaß 1,6; Puls- und Neon-Blaster
      auf der Lafette (Mörser, Lanze wie im Spiel) -- freigegeben 16. Nov.
- [ ] Die übrigen 10 Fähigkeiten als Animation

## Offene Fragen an den Spieler

1. ~~Runenstab und E-Schraubenschlüssel am Strix~~ -- entschieden 17. Nov.:
   auf der Lafette ohne Griff, nur Kugel bzw. Schlüsselkopf (4b).
2. ~~Molok-Waffen~~ -- entschieden 16. Nov.: dieselbe Waffe mit Armmaß 1,6
   (Board 14), kein zweiter Satz.
3. ~~Beine trennen oder nur Wippen?~~ -- entschieden 17. Nov.: erst nur
   Wippen; Beine erst trennen, wenn das zu steif aussieht.
4. ~~Bumerang als Nahkampf~~ -- entschieden 16. Nov.: bleibt Nahkampf, Pose
   angewinkelt und wurfbereit (Board 14).
