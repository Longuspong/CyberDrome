# Übergabe: 3D-DROMEs, Fähigkeiten, Generator (Stand 18. Nov. 2026, abends)

Für eine frische Sitzung. Erst den Abschnitt „Stand 18. Nov.“ lesen, dann
`docs/DROME_UMSETZUNG.md` (4g, 5, 6, 7). Ältere Abschnitte darunter bleiben
als Hintergrund.

## Stand 18. Nov. 2026 -- PR #83 (Draft, alles grün, Spieler merged selbst)

Gebaut in dieser Sitzung (Details und Dateien in `DROME_UMSETZUNG.md`):

* **Beine im Wechsel** (Vireo, Molok, Strix): `split_legs` im Generator,
  `Arena3D._leg_pose`.
* **Generator-Bausteine** in `tools/build_sample_parts.py`: `BP`
  Doppelpyramide, `SW` Zug (Kabel/Schläuche rund, gebogene Klingen flach),
  `EX` Profil mit Fase (`axis` l/f/z). Alle ergeben ein `poly`.
* **Redesign** (vom Spieler freigegeben): Strix mit Eulenflügeln aus
  überlappenden Tropfen-Federn, Lafette auf der Schulter mit Buchse, Kabel
  und `side_holder` (Achsel-Variante per `STRIX_MOUNT=achsel`); Molok mit
  Kabelschläuchen und Fasen; Vireo mit V-Torso; Waffen neu (Schienen-Lanze
  als Scharfschützengewehr, Plasmaklinge, Bumerang gebogen, Mörser,
  Puls-Blaster, Hammer, Ramme, E-Schlüssel).
* **Waffenfarben**: Waffenstahl, Puls-Blaster Chrom (`WEAPON_COLORS`),
  Glanzkante + Leuchten je Waffe (`WEAPON_FINISH`, Shader `drome_face` `shine`).
* **Fraktions-Paletten** für Gegner-DROMEs/Sentinels
  (`DromeModel.FACTION_PALETTES`, Mecha-Absperrstreifen im Shader `stripes`,
  kein roter Teamstich für Fraktions-DROMEs).
* **Fähigkeiten lesbar und in Abfolge**: `AbilityPainter` (Formen),
  `AbilityFx` (Optik zu `ability_cast`/`action_used`), **Ausholzeit**
  `ActionData.windup` (DROME steht still, Wirkung danach aufs Ziel, wo es
  dann steht). Würfe (Runenstab-Vortex, Bumerang) über `Arena3D.throw`,
  Loslassen mitten im Schwung. Genau zielen (`Unit.facing_at`, `aim_hold`),
  Schüsse ab Mündung (`Arena3D.weapon_tip`). Sog/Stoß rutschen sichtbar.
* **Doppelschuss** = 2 Salven × 3 Schüsse à 1/3 Schaden (Feld `salvo`,
  verzögerte Treffer `ActionResolver.salvo_time`), dreht sich zum 2. Ziel.

Werkzeuge für Bilder (ohne Web-Export, unter `docs/design/drome_entwurf/godot/`):
`render_chassis.gd` (ein Chassis, 6 Richtungen), `render_waffenfarben.gd`
(Ordner `-` = wie im Spiel), `render_fraktionen.gd`, `render_film.gd` +
`film_scene.gd` (Fähigkeit als Film, derselbe Ablauf wie im Kampf; GIFs
mit PIL bauen). Leinwand: https://claude.ai/artifact/TAngQWD17gcfUoMok2Gzx6
(Seiten „Fähigkeiten lesbar“ mit Filmen, „Durchsicht & Redesign“,
„Waffenfarben“).

### Nachtrag 18. Nov. abends (PR #84-#86)
* Erledigt: Echo nacheinander, Flächen landen am Wurfort, Balance gemessen;
  Hangar ohne Ruckler (Bild-Cache); Karten je Formation, Standard 9 x 15,
  keine zufälligen Hindernisse; flache Sechsecke (odd-q); doppelte Figuren
  behoben; DROMEs auf 75 % (`figures.scale`). Details in `PROJEKTSTAND.md`.
* Offen: Rückmeldung des Spielers zu flachen Feldern und 75 % auf dem Handy;
  "Tote bleiben stehen" ließ sich im Container nicht nachstellen (Sicherung
  in `Arena3D` eingebaut) -- nach neuem Screenshot fragen; Dachschützen
  gewinnen auf jeder Karte (Balance der Formation); Modulsystem wird
  überdacht (erst besprechen); Story-Level.

### Offen / nächste Schritte
1. ~~Balance-Messung~~ -- **erledigt 18. Nov.** (PR #84): Ausholzeit,
   Salven, Echo nacheinander und Flächen am Wurfort gegen `main` gemessen,
   neutral (Zahlen in `PROJEKTSTAND.md`). `windup` bleibt wie es ist.
2. **Shogun Kage als Boss-Chassis** -- mit `SW`/`BP` jetzt Hörner und Katana
   glatt möglich (Entwurf `v11_shogun.py`). Bosse kommen mit den Story-Leveln.
3. Story-Level (macht der Spieler separat), Android-App später.
4. Kleinkram: Nimbus-Energieleitung Kugel→Stab (optional), Fraktionsfarben
   in die SPOT-Tabelle übernehmen (stehen heute nur im Code).

### Fallstricke aus dieser Sitzung
* Nach Änderungen am Generator immer `python3 tools/build_sample_parts.py`,
  `python3 tools/bake_godot_assets.py`, `godot --headless --path . --import`.
* Blicktests mit Zeitablauf (Filme, Fähigkeiten) mit `--fixed-fps 60`, sonst
  läuft die Zeit im Container zu schnell.
* `get_shader_parameter` liefert `null` für nie gesetzte Parameter.
* Optik und Regeln müssen dieselben Zeiten nutzen (Ausholzeit, Salven) --
  Konstanten liegen in `ActionResolver`/`Arena3D`, die Anzeige liest sie.
* Molok-Passive „Präsenz“ fängt Anteile ab -- in Treffer-Tests Gegner ohne
  Molok daneben wählen.

## Älterer Stand (17. Nov. 2026)

## Was gebaut ist (PR #81, vom Spieler gemergt)

* **4b Arme am Chassis**: zwei Haltungen `hold`/`aim` (+ `guard` für den
  Schild = halten, Schild vor dem Arm), Manschette an Fernwaffen, Hand nur am
  Vireo-Passivarm, eigene Molok-Arme, Strix-Lafette nur Kugel/Schlüsselkopf.
  Arm-Bilder bringen die Schulter ihres Chassis mit (`side_shapes`).
* **Waffenfarben unabhängig**: Tabelle `WEAPON_COLORS` in
  `tools/build_sample_parts.py` (Startwerte = alte Bausatzfarben).
* **4c Echtes 3D**: Generator schreibt je Teil `parts/<set>/<id>.m3d`
  (Flächen mit Normale/Material/Art, Hüllen der Drehkörper, Varianten, Arme,
  3D-Anker, Farben); `DromeModel` (`scripts/core/drome_model.gd`) baut Meshes,
  Iso-Kamera = SVG-Projektion (Test); Shader in `assets/shaders/`
  (`drome_face`, `drome_hull`, `drome_outline`); `DromeSprites.assemble`
  rendert per SubViewport (UPDATE_ONCE, Drehen dreht nur das Modell).
* **Leistungstest**: Optionen > Zum Testen > „Leistungstest“
  (`scenes/bench.tscn`). Messung des Spielers (Handy, PWA): Einzelansichten
  bis ~12 bewegte DROMEs, **eine gemeinsame 3D-Szene auch 48** (38 B/s);
  Browser-Obergrenze ~45 B/s. Tabelle in `DROME_UMSETZUNG.md`.
* **Entwürfe** (nur Optik, nichts davon in `parts/`):
  `docs/design/drome_entwurf/v7.py` (4b), `v8_shogun.py`, `v9_shogun.py`
  (Shogun Kage nach `assets/story/boss_shogun_kage.jpg`, Farben aus den
  Pixeln gemessen), `v10_hexboden.py` (Hexboden). Rendern mit den Helfern
  unter `docs/design/drome_entwurf/godot/` (Aufruf im Kopf von
  `render_main.gd`).
* **Leinwand** (Claude Design, privat beim Spieler):
  https://claude.ai/artifact/TAngQWD17gcfUoMok2Gzx6 -- Seiten „Offene
  Punkte“, „Arme & Waffen (4b)“, „Shogun Kage (3D)“, „Hexboden (3D)“.

## Nächste Schritte (vom Spieler gewollt, in dieser Reihenfolge)

1. **ERLEDIGT (17. Nov.)** -- `g.O`/`g.OB`, Shogun in `v11_shogun.py`, siehe
   `DROME_UMSETZUNG.md` 4d. Ursprünglicher Plan: **Generator: gedrehter Quader** (Spieler: „dafür“). Neuer Baustein,
   z. B. `("obox", mitte(f,l,z), groesse(df,dl,dz), drehung(gier,nick,roll), mat)`:
   acht Ecken drehen, sechs Flächen mit gedrehten Normalen ausgeben. Stellen
   im Generator: `render` (SVG), `model_faces` (3D), `_shape_faces`/
   `_shape_polygons` (Silhouetten-Prüfung), `_mirror_l`; im Entwurf
   `new_dromes.shift`. Danach am Shogun (`v9_shogun.py`) Katana, Hörner und
   Umhang glatt statt in Stufen (`slope`, `slope_l` ersetzen).
2. **ERLEDIGT (17. Nov.)** -- siehe `DROME_UMSETZUNG.md` 4e. Ursprünglicher Plan:
   **Verlorenes aus dem 3D-Umbau nachholen**: Neon-Leuchten (`NeonGlow`) am
   3D-DROME (z. B. zweiter Durchgang nur mit glow/accent-Flächen als
   Leuchtebene) und Kontur je Teil (heute eine Kontur in Chassisfarbe; der
   Neon-Blaster hätte gern seinen magenta Rand). Beim Zerstören fällt der
   DROME als Ganzes -- in 3D wieder in Teile zerlegen.
3. **ENTSCHIEDEN und GEBAUT (17. Nov.)**: 9 x 17, Reichweiten 1:1, Reihen
   waagerecht -- Logik und 2D-Kampfbild, siehe `PROJEKTSTAND.md`. Offen:
   Elite auf dem Hexfeld schwerer (Messung dort). Ursprünglicher Plan:
   **Hexfeld als Designfrage** (Spieler: „generell dafür“): auf der Leinwand
   mit Bildern vorlegen, dann entscheiden lassen -- Feldgröße und -form
   (Sechseck Radius 5 = 91 Felder, oder hochkant fürs Handy), Reichweiten in
   Hexschritten (Nahkampf bis 2 / Fernkampf ab 3 übertragen?),
   Aufstellzonen, Hindernisse, 6 Blickrichtungen. Betroffen beim Bau: `Grid`,
   Wegfindung, `MapGenerator`, Aufstellung, `ArenaPainter`, Kamera-Ziehen, KI.
   Bodenplatten kommen aus dem 3D-Generator (`v10_hexboden.py`), die
   gezeichneten Deko-Assets bringt der Spieler später nach.
4. **ERLEDIGT (18. Nov.)** -- `Arena3D` mit Grundbewegung, siehe
   `DROME_UMSETZUNG.md` 4f und 5. Ursprünglicher Plan: **Kampf als EINE 3D-Szene** (Boden, Hindernisse, alle DROMEs, eine
   Kamera) zusammen mit **Schritt 5 Bewegung** (Idle, Wippen, Angriff je
   Waffenart; Arm/Waffe sind eigene Knoten `<slot>_arm`/`<slot>` unter
   `Ausrichtung`). Begründung: Leistungstest. Läuft auch in der PWA.
5. **Android-App (APK)**: erst nach der Design-Politur, Story und grobem
   Ablauf (Spieler). Dann Leistungstest dort wiederholen.

## Entschieden am 18. Nov. 2026

* Leistung der 3D-Kampfszene, 3D-Hindernisse statt gezeichneter, schwerere
  Elite auf dem Hexfeld: alles „okay so“.
* Story: Level-Design macht der Spieler separat; **Bosse später**, Shogun
  Kage dann als **eigenes Boss-Chassis** (Modell `v11_shogun.py`); Dialoge zu
  den Einsätzen erst einmal nicht.

## Offene Entscheidungen des Spielers

* ~~Waffenfarben~~ -- **entschieden und gebaut 18. Nov.**: Satz A „Waffenstahl“
  für alle, der Puls-Blaster aus Satz B „Chrom“ (`WEAPON_COLORS`). Oberfläche je
  Waffe in `WEAPON_FINISH`: Glanzkante je Material (Shader `drome_face`,
  `shine`), Energiewaffen leuchten (`neon`). Klingen glänzen (Material `blade`)
  oder leuchten (Plasma), Griffe und Halterungen bleiben matt. Dazu neu:
  Plasmaklinge als lange Doppelpyramide (Baustein `BP`), Bumerang als
  gebogene Klinge ohne Griff, das Flügelende steckt in der Faust (Baustein
  `SW` „Zug“: Querschnitt entlang einer Catmull-Rom-Kurve, rund = Kabel und
  Schläuche, Raute + `flat` = gebogene Klinge; beide ergeben ein `poly`). Entwurf: `v13_waffenfarben.py`, Blicktest
  `godot/render_waffenfarben.gd` (Ordner `-` = so wie im Spiel).
* ~~Fähigkeiten lesbar~~ -- Skizzen vom Spieler freigegeben, alle 11 Formen
  **gebaut 18. Nov.** (`AbilityPainter`, siehe `DROME_UMSETZUNG.md` 6).
* **Shogun Kage**: Richtung gefällt („richtig gehyped“), Feinschliff nach
  Schritt 1. Ins Spiel erst mit den Story-Bossen.
* Alles zum Hexfeld (siehe 3).

## Fallstricke (alle in dieser Sitzung getroffen)

* **Drehkörper-Profile laufen von unten nach oben** -- sonst zeigen die
  Normalen nach innen (schwarze Flächen, Hülle wird sichtbar).
* **Neue SVGs**: danach `python3 tools/set_import_scale.py` und
  `godot --headless --path . --import`, sonst rastert Godot sie grob (unscharf).
* **canvas_item-Shader**: `COLOR` im Fragment enthält schon die Textur --
  Einfärbung (modulate) über ein `varying` aus `vertex()` holen; Texturen
  nicht an Hilfsfunktionen übergeben (Compiler-Fehler), Schleife inline.
* **Rumpf im 3D-Modell nicht verschieben**: sein `mount` ist nur Bezugspunkt.
* **Bilder ohne Fenster speichern** (Projekt skaliert das Fenster):
  SubViewport mit `UPDATE_ALWAYS` und `get_texture().get_image()`, siehe
  `render_main.gd`.
* **vercel.app ist aus der Cloud-Sitzung gesperrt**: Web-Version lokal mit
  `bash tools/build_web.sh` und `python3 -m http.server` prüfen; im Container
  läuft der Browser ohne echte GPU -- Leistungszahlen nur vom Handy des Spielers.
* Kontur-/Kantenbreite hängt an der Auflösung (`DromeModel.edge_px`).
* **Keine `instance uniform` in Shadern** (Compatibility-Renderer): bei
  vielen Instanzen kamen die zuerst angelegten mit falschen Werten heraus
  (Bodenplatten schwarz), auch ausdrücklich gesetzt. Farbstich je DROME
  deshalb über eigene Materialkopien (`Arena3D._tint_mesh`).
