# Übergabe: 3D-DROMEs, Hexboden, nächste Schritte (Stand 17. Nov. 2026)

Für eine frische Sitzung. Erst diese Datei lesen, dann `docs/DROME_UMSETZUNG.md`
(Abschnitte 4b, 4c, Leistungstest, 5).

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

1. **Generator: gedrehter Quader** (Spieler: „dafür“). Neuer Baustein,
   z. B. `("obox", mitte(f,l,z), groesse(df,dl,dz), drehung(gier,nick,roll), mat)`:
   acht Ecken drehen, sechs Flächen mit gedrehten Normalen ausgeben. Stellen
   im Generator: `render` (SVG), `model_faces` (3D), `_shape_faces`/
   `_shape_polygons` (Silhouetten-Prüfung), `_mirror_l`; im Entwurf
   `new_dromes.shift`. Danach am Shogun (`v9_shogun.py`) Katana, Hörner und
   Umhang glatt statt in Stufen (`slope`, `slope_l` ersetzen).
2. **Verlorenes aus dem 3D-Umbau nachholen**: Neon-Leuchten (`NeonGlow`) am
   3D-DROME (z. B. zweiter Durchgang nur mit glow/accent-Flächen als
   Leuchtebene) und Kontur je Teil (heute eine Kontur in Chassisfarbe; der
   Neon-Blaster hätte gern seinen magenta Rand). Beim Zerstören fällt der
   DROME als Ganzes -- in 3D wieder in Teile zerlegen.
3. **Hexfeld als Designfrage** (Spieler: „generell dafür“): auf der Leinwand
   mit Bildern vorlegen, dann entscheiden lassen -- Feldgröße und -form
   (Sechseck Radius 5 = 91 Felder, oder hochkant fürs Handy), Reichweiten in
   Hexschritten (Nahkampf bis 2 / Fernkampf ab 3 übertragen?),
   Aufstellzonen, Hindernisse, 6 Blickrichtungen. Betroffen beim Bau: `Grid`,
   Wegfindung, `MapGenerator`, Aufstellung, `ArenaPainter`, Kamera-Ziehen, KI.
   Bodenplatten kommen aus dem 3D-Generator (`v10_hexboden.py`), die
   gezeichneten Deko-Assets bringt der Spieler später nach.
4. **Kampf als EINE 3D-Szene** (Boden, Hindernisse, alle DROMEs, eine
   Kamera) zusammen mit **Schritt 5 Bewegung** (Idle, Wippen, Angriff je
   Waffenart; Arm/Waffe sind eigene Knoten `<slot>_arm`/`<slot>` unter
   `Ausrichtung`). Begründung: Leistungstest. Läuft auch in der PWA.
5. **Android-App (APK)**: erst nach der Design-Politur, Story und grobem
   Ablauf (Spieler). Dann Leistungstest dort wiederholen.

## Offene Entscheidungen des Spielers

* **Waffenfarben**: neutraler Stahl + Leuchtfarbe nach Art (Fern Cyan, Nah
  Orange; Empfehlung) oder eigene Farbe je Waffe. Eintragen in `WEAPON_COLORS`.
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
