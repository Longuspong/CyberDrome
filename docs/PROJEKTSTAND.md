# Projektstand und Entscheidungen

Gesammelt aus der Arbeitssitzung vom 3./4. November 2026 (PR #26 bis #30),
damit eine neue Sitzung nicht bei Null anfaengt. Was hier steht, ist
**entschieden oder gemessen**; was noch offen ist, steht ausdruecklich unter
"Offen". Kurzfassung und Arbeitsregeln: `CLAUDE.md`.

---

## 1. Richtung des Spiels

* **Autobattler in Echtzeit** (seit Nov. 2026, vorher Zuege mit
  Initiative). Die KI (`scripts/battle/ai_controller.gd`) steuert beide
  Seiten. Der Spieler entscheidet ueber Aufbau, Squad und Belohnungen -- nicht
  ueber einzelne Zuege. Den manuellen Kampf gibt es nicht mehr.
* **Mobile first, Hochformat ist die Hauptansicht** (Wunsch des Spielers,
  ausdruecklich). Querformat wird angeboten, ist zweitrangig. Ziel-Plattform
  ist das Handy, gehostet als PWA auf Vercel; Android-APK kommt spaeter.
* **Roguelike-Lauf** als zentraler Modus: "Neon City" (8 Kaempfe) und der
  Endlos-Modus. Beim Start waehlt man einen von drei Spielstaenden.

## 2. Was gebaut ist (Chronologie)

| PR | Inhalt |
|---|---|
| #26 | Autokampf (KI fuer beide Seiten), Aggro-Tabelle fuer alle, **Schild-Bug der KI behoben**, Overtime, Fairness-Test, PWA-Export + GitHub-Pages-Workflow |
| #27 | Vercel liefert das Spiel statt der SVG-Werkstatt: `vercel.json`, `tools/build_web.sh`; SVG-Werkstatt nach `werkstatt/` |
| #28 | Barrierefreiheit (erste Fassung), animierte DROMEs im Startbildschirm, **Roguelike-Lauf** (`RunState`, Lauf-Bildschirm) |
| #29 | Touch-Bedienung, dann **Umbau auf Hochformat**: Entwurfsraum 450x800, `UiKit`, Tab-Leiste, Kamera folgt im Kampf, Pinch/Ziehen; `CLAUDE.md` angelegt |
| #30 | **Hangar** statt Garage/Inventar/Werkstatt, **Halter-Formen**, Wisch-Scrollen, Schriftgroessen-Option nur fuer Text |

### Repair-Kit, Hammer, Testspielstand (27. Nov. 2026 abends, Spieler)

* **Repair-Kit** (Nimbus-Standardwaffe, `SKILLBAUM_KONZEPT.md` 5e): Angriff speichert den
  angerichteten Schild-/Integritaetsschaden, die Reparaturwelle (jeder 6. Angriff) gibt jedem
  Teammitglied Speicher x Effizienz als Schild und Reparatur. Werte selbst gewaehlt: 9 Schaden,
  1,2 s, Reichweite 4, 50/50.
* **Hammer** ohne Integritaetsschaden (`hp_scaling` entfernt). Kampfwert neu geeicht
  (`POWER_SCALE` 0,922), die Welle zaehlt als gespeicherter Schaden x Effizienz x 3.
* **Testspielstand Platz 3:** `Roster.seed_test_stock` (Startbestand + 1000 je Ware, Phase,
  Rohling, Keynode, Fraktionskern, Spezialteil, DROME-Teil, Coins; jede Waffe einmal extra).
  `GameState.refresh_test_slot` schreibt ihn beim Start neu, wenn die Versionskennung
  (`data/build.json`, schreibt `tools/build_web.sh` aus dem Commit) sich geaendert hat.
* Messung `run_bench -- 30` (Elite, mit/ohne Module): Runde 3 6/12 und 8/12, Runde 5 1/18
  und 3/18, Runde 8 1/30 und 0/30 -- schwaecher als mit Runenstab (Vortex fehlt).

### Werkblatt uebernommen: Gunship, Focuslense, neue Werte (27. Nov. 2026, Spieler)

Details und Tabelle in `docs/SKILLBAUM_KONZEPT.md` 5e.

* **Molok als Gunship:** ein Halter bis mittel, der rechte Arm spiegelt die Waffe
  (`slot_rules` `mirror`, `DromeBuild.mirror_source`/`mirror_slots`); im Kampf zwei
  Halterungen, versetzt, je eigener Takt (`Unit.init_realtime`), Arm im Bild nach
  `Unit.firing_slot`. Standardwaffe Deflektor, Hammer frei im Lager, Gegner-Moloks mit
  Hammer. Kampfwert zaehlt den zweiten Arm, `POWER_SCALE` 1,064.
* **Passiven:** Molok heisst **Safe Haven** (`passives.safe_haven`), Strix **Focuslense**
  statt Anlegen (`Unit.focuslense`, in `ActionResolver.apply_damage`), Echo-Takt
  aufgerundet (jeder 3. -> 5.).
* **Werte:** Speed Vireo 8, Molok 6, Strix 3; Schildpuls Vireo 5, Molok 2; Neon Vireo
  8 / 10, Neon Nimbus 7 / 5 mit Power und Effizienz 12.
* **Halter-Kuerzel** S/M/X, -F/-N (`SlotRules.holder_code`).
* Noch nicht gebaut: Nimbus als Supporter (Repair-Kit, Cleancode, Shieldgate), Zielregel
  „Most Damage“ fuer den Neon Nimbus, Halter M-N fuer den Neon Vireo.

### Molok-Passive Festung, Hammer, Kernwaffen (27. Nov. 2026, Spieler)

* **Passive Festung** (Arbeitsname): Heilung, Lebensraub, Regeneration, Schildladung und
  Schildgaben am Molok +20 % (`Unit.care_mult`, `passives.fortress`).
* **Hammer-Betaeubungsschlag:** +20 % der eigenen max. Integritaet als Schaden (`hp_scaling`),
  heilt um 100 % des Schadens (neues Aktionsfeld `lifesteal`), kinetisch. Kampfwert neu
  geeicht (`POWER_SCALE` 0,911), Standard-Squad wieder im Schnitt 100.
* **Eine Kernwaffe je DROME:** entfernt mit Code, Daten, Grafik und Tests: Bollwerk-Ramme,
  E-Schraubenschluessel (Drohnen-Pod), Klingenbumerang, Neon-Blaster, Moerser. Mit ihnen
  gingen Bewegungsbonus, Mindestreichweite, Schildbrecher-Faktor, Kabelbrand als
  Aktionsstatus (Kabelbrand bleibt ueber den Feuer-Charger) und die Formen Sperrfeuer,
  Wirbel, Rammstoss, Schildbrecher. Support-Sentinels tragen jetzt den Deflektor, Solar-
  und Hipstar-Sniper die Lanze, der Solar-Assault die Plasmaklinge. Alte Spielstaende laden
  weiter (unbekannte Teile werden uebersprungen).
* Die Heil-Unterstuetzung fuer Verbuendete (`support: "ally"`, Heilregel) bleibt im Code,
  hat aber keine Waffe mehr -- fuer den spaeteren Heiler.

### Kernplan, Cyberspeed, Aufraeumen (25./26. Nov. 2026, Spieler)

Leitplan seit 25. Nov.: `docs/KERNPLAN.md`. Gebaut:

* **Vireo-Passive Cyberspeed** ersetzt den Sprint: jeder 3. Angriff 1 Stapel
  (max. 3), je Stapel +10 % Angriffs- und Lauftempo, jeder Angriff haelt die
  Stapel 3 s (Effizienz streckt). `Unit.on_attack`, `config.json` ->
  `passives.cyberspeed`. Anzeige: ein Sprint-Symbol je Stapel, Booster heller.
  `run_bench -- 30` vorher/nachher praktisch gleich.
* **Aufraeumen nach dem Kernplan** (ein Commit je Thema): Molok-Praesenz und
  das ganze Locken (Lockradius, Spott-Effekt, Symbol "gelockt"); Werkstatt-
  Export, `preview_delta`, Altformate der Spielstaende (v1-Squad, Einzeldateien
  vor den drei Spielstaenden); 40 Funktionen ohne Aufrufer; alte Modul-Symbole,
  `art/arena_city/`, `tab_hangar.svg`; Kern-Halter (Kreisform) und
  Belagerungskanone im Code; zufaellige Hindernisse (`place_obstacles`) und
  tote Config-Werte (`squad_size`, `grid_*`); alte Box-Modelle im Generator
  (Ausgabe vorher/nachher byte-gleich); README, `parts/README.md`, `CLAUDE.md`.
* Der **Molok hat vorerst keine Passive**; die neue steht im Kernplan als
  Entwurf. Sein **Bunkerkopf** ist wieder ein eigenes Teil (steckte fuer die
  2D-Zeichnung im Rumpf). Das Lockfeuer der Praesenz auf dem Ruecken ist weg,
  die beiden Auspuffstapel daneben sind etwas dicker (27. Nov., Spieler).
* **26. Nov., zweite Runde (Entscheidungen des Spielers):** 16 Modul-Effekte
  ohne Modul entfernt (Gabelung, Kettensprung, Feldschuss, Wurzeln ...), der
  Zeit-Takt samt Uhr-Leiste, `MODULE_KONZEPT.md`, `BRAINSTORMING_MODULE.md`,
  `PLAYTEST_2026-11.md` geloescht (gueltige Regeln jetzt in
  `MODULE_AMP_FUSION.md` 6), `GAME_DESIGN.md`, `NEUANFANG.md`,
  `IDENTITAETEN.md` entruempelt.

### Bugfix-Runde Kampf (24. Nov. 2026, Meldung des Spielers)

Gemeldet: Elementarladung nicht zu merken, Vortex zieht kaum und betaeubt nicht,
Flaeche wirkt nur auf Mitte + einen Ring, Animationen und Blickrichtung falsch.
Selbst nachgespielt (Kampfbild per xvfb, Seeds 5003/7001/7002) und gemessen:

* **Charger bei Salven:** jede Kugel einer Salve (Doppelschuss 2 x 3) legte die volle
  Belastung und den Faehigkeits-Bonus (+100, +1 Stapel) an -- ein Doppelschuss mit zwei
  Feuer-Phasen gab ~14 Stapel statt 2. Jetzt zaehlt eine Salve als **ein** Treffer
  (je Kugel 1/salvo, Resonanz-Zuschlag mit der Kugel, die den Treffer voll macht), der
  Bonus kommt je Ziel **einmal je Einsatz** (`ActionResolver._multi_shot`, `_charge`).
  Der Beschuetzer (Praesenz) bekommt beim Abfangen keine Belastung mehr.
* **Andere Elemente als Feuer** wirken weiter noch nicht (CHARGER_KONZEPT 4) -- das
  Bau-Popup des Chargers sagt das jetzt.
* **Schildtreffer unsichtbar:** Zahlen gab es nur fuer Integritaet. Wer am Rand des
  Vortex mit Schild stand, wurde getroffen, ohne dass eine Zahl kam -- so sah die Flaeche
  wie Mitte + ein Ring aus. Logik war richtig (Radius 2 trifft). Neu:
  `EventBus.shield_damaged`, Zahl in Schildfarbe (`BattleScreen._on_shield_damaged`).
* **Vortex-Sog** (Vorgabe des Spielers, gleicher Tag -- "wie ein schwarzes Loch"): beim
  Aufprall werden alle Gegner im Radius zum Zielfeld gezogen; der Naechste kommt auf das
  Zielfeld selbst, die anderen bis zu 2 Felder so weit, wie in ihrer Richtung Platz ist.
  Bis zur Schockwelle sind alle Erfassten festgehalten (`vortex_hold`: kein Laufen, kein
  Schiessen, ohne eigenes Symbol), das Heranrutschen ist ueber die Sog-Zeit zu sehen
  (`ActionResolver.forced_seconds`). Nach dem Schaden sind sie frei und verlangsamt.
  Wer waehrend der Ausholzeit weglaeuft, entkommt weiter.
* **Blickrichtung:** Angriffe feuerten, bevor die Figur zum Ziel gedreht war (Molok bis
  0,4 s fuer eine halbe Drehung) -- beim Angriff dreht sie jetzt 5x schneller
  (`Arena3D.ATTACK_TURN_BOOST`). Wer laeuft und sein Ziel vom neuen Feld aus in
  Reichweite hat, schaut beim Laufen zum Ziel statt sich zwischen zwei Schuessen
  wegzudrehen (`AIController._walk`). Das Echo haelt den Blick ueber die ganze Ausholzeit.

### Fabrik-Logik (23. Nov. 2026, `docs/FACTORY_KONZEPT.md` Abschnitt 11)

* **`FactorySim`** (`scripts/core/factory_sim.gd`, RefCounted, deterministisch): Takt in der
  Reihenfolge des Prototyps v2 -- Verbindungen (Relais nur mit Strom), Abholen reihum,
  Strom nach Naehe (Netz 4/Rw 2, Solar mit Schatten, Ofen/Generator zuenden bei halbem Puffer und
  brennen nur bei Bedarf, Batterie), Herstellen (Anlauf 3 Durchlaeufe, Resonanz), Uplink.
  `run(n)` fuer viele Takte. Werte in **`data/factory.json`** (ohne Rohlingpresse), SPOT-Blatt
  **Fabrik** (Welt).
* **Spielstand:** `Roster.factory` (eigene Version 1) im roster.json; **Lager = Inventar**:
  `Roster.materials["res:<ware>"]`, der Charger-Rohling bleibt `"rohling"`.
  `Roster.factory_sim()` arbeitet direkt darauf.
* **Takte:** live 1 Takt alle 6 s, nur solange der Reiter Linien offen ist; nach jedem Kampf
  `run(20)` (seit 24. Nov. 2026, vorher 100; `GameState.finish_run_battle`, auch nach Niederlage), Summe in
  `RunState.factory_gain`, am Einsatzende unter "Was bleibt" ("Fabrik ins Lager").
* **Bedienung (schlicht, Optik folgt in der Design-Sitzung):** Platine zeichnen und antippen,
  Gebaeude nach Gruppen, Info mit Durchsatz/Puffer/Strom/Uplink-Menge, "Eingang X voll --
  wartet auf Y" (Playtest v2), gedimmte Leiterbahn ohne Lieferung, Feldgruppen und weitere
  Gebaeude kaufen, Abreissen (Besitz bleibt, Puffer ins Lager), Tier-2-Ziel, Lager mit
  Hochrechnung je Einsatz. Inventar zeigt "Ressourcen"; im Reiter Charger "Rohling herstellen"
  (Vorschlag 2 Legierung + 1 Plasma, `factory.json` -> `herstellen`).
* **Bedienung mit Plus und Modi (28. Nov. 2026, Entwurf des Spielers; ersetzt das Baumenue vom
  27. Nov.):** die Platine fuellt den Reiter (ohne Scrollen), unten rechts ein Plus. Es rollt nach
  links Verschieben, Abreissen (roter Hammer) und Bauen aus. Bauen zeigt die Kategorien Foerdern,
  Verarbeiten, Strom, Logistik; eine Kategorie schiebt ihre Gebaeude nach Tiers hoch (unten T1,
  hoehere Tiers dunkel). Gebaeude antippen (nochmal = Details) oder aufs Feld ziehen, Feld tippen
  = Vorschau mit kuenftigen Leiterbahnen: gruener Haken = aus dem Besitz, Einkaufswagen = kaufen
  und setzen, rot mit Warenpunkt und Menge = was fehlt; nochmal tippen bestaetigt. Abreissen ohne
  Rueckfrage. Verschieben per Ziehen oder antippen + Zielfeld; belegtes Ziel = tauschen, wenn
  beide Arten dort passen (`FactorySim.move`, `fits`, `buy_and_place`, `preview_traces`).
  Ohne Modus: Gebaeude = Details-Popup; der Netzanschluss heisst **Basis** und zeigt Strom, Lager
  und "Basis aufruesten" = naechstes Tier. Gesperrte Felder: einmal tippen = Kauf-Vorschau,
  nochmal = kaufen. Symbole sind Platzhalter aus `assets/ui_icons` (Grafik folgt mit Claude Design).
* Tests `tests/test_factory.gd`, Smoke-Test bedient die Platine, Bild:
  `tests/screenshot.gd -- res://scenes/resources.tscn <png> 60 factory=200` (dazu
  `fabrik_bau=strom:sol:1,1` = Plus, Bauen, Kategorie, Art, Feld; `fabrik_modus=move|remove`;
  `fabriktipp=0,0` tippt ein Feld).
* Offen: Rezept-Raten/Takte fuers Spiel, Tier 3/4 ueber die Story, Baukerne raus (erst mit den
  DROME-Teilen), Anzeigetexte noch ohne `tr()`.

### Werkbank (24. Nov. 2026, `docs/FACTORY_KONZEPT.md` Abschnitt 13)

* Fabrik-Tab hat zwei Reiter: **Platine** (`FactoryView`) und **Werkbank** (`WorkbenchView`,
  Kategorien Charger und DROMEs). `resources_screen.open_tab("charger"/"dromes")` fuehrt in die
  Werkbank. `DromeForge` ist entfernt.
* Logik `Workbench` (`scripts/core/workbench.gd`): Produkte `rohling`, `teil:<chassis>:<teil>`,
  `drome:<chassis>`, `faction:<variante>` (Fraktionskern statt Kern-Teil), `free:<chassis>`;
  `needs`/`missing`/`raw_shortfall`/`craft`, `battles_for` mit `FactorySim.estimate_per_tick`.
  Teile-Rezepte in `data/factory.json` -> `werkbank`, SPOT-Blatt Fabrik.
* Ziel merken: `FactorySim.goal()` im Fabrik-Spielstand; die Platine zeigt "ZIEL ... fehlt ..."
  und einen gelben Punkt an Gebaeuden, die Fehlendes herstellen.
* Tests `tests/test_workbench.gd`, Smoke-Test bedient die Werkbank, Bild:
  `screenshot.gd -- res://scenes/resources.tscn <png> 60 fabrik=dromes ziel=drome:jugg_body`.
* Spezialteile (`spezial:<variante>`, Fraktionskern + Zutaten des Kern-Teils) ersetzen bei
  Fraktions-DROMEs das Kern-Teil. Verwerten (`Roster.salvage`, `Workbench.salvage_yield`) gibt die
  Zutaten der zwei teuersten Teile zurueck, Fraktions-DROMEs dazu ihr Spezialteil. Baukerne sind
  raus (Caches, Shop, Verwerten, `craft_drome`), ohne Umrechnung alter Spielstaende.

### Level kaufen statt EP (24. Nov. 2026, `docs/SKILLBAUM_KONZEPT.md` 5d)

* Keine EP mehr (`Leveling.xp_enabled()`; `RunState.collect_xp` sammelt nichts). Level werden auf
  der DROME-Seite gekauft: Reiter **DROME** (`_level_card`) und die Klappe „Level und Skilltree der
  Waffe“ im Reiter Waffe. Kosten in `data/factory.json` -> `level` (je Chassis, Waffen je
  Gewichtsklasse), Level 5 braucht einen **Keynode-Chip** (`materials["keynode"]`).
* Waffen bis Level 5 (`config.json` -> `levels.weapon.max`, Schaden +14 % je Level).
* Keynode-Chip: erster gewonnener Einsatz garantiert (`progress.keynode_first`), danach 15 %
  (`GameState.roll_keynode`), Caches 5 % je Wurf. Raten vorlaeufig.
* Tests in `tests/test_leveling.gd`; Bild: `screenshot.gd -- res://scenes/hangar.tscn <png> 60 hangar=drome_up`.

### Ein Verb je Tab (22. Nov. 2026, Entscheidung des Spielers)

Ersetzt die Aufteilung darunter (Design-Canvas "CyberDrome Bildschirme", Reihe "Vorschlag").

* **Fabrik** (`resources_screen.gd`) = herstellen: Reiter Linien (seit 23. Nov. 2026 die
  Fabrik-Platine, `FactoryView`), Charger (`ChargerCrafter`), DROMEs (`DromeForge`); Schalter
  fest unter der Kopfzeile.
* **Inventar** (`shop_screen.gd`, `mode = "inventory"`) = lagern, eine Seite ohne Reiter:
  Bestand, freie Waffen, Charger, Energy Phases, Lootcaches oeffnen.
* **DROMEs** (`hangar_screen.gd`) = ausruesten und aufwerten: nur die Liste (Zeilen mit Bild,
  Rolle, Waffe + Charger, gelber Hinweis "Waffenplatz frei" / "Charger-Platz frei");
  antippen oeffnet die DROME-Seite. Fest oben Zurueck, Name, Kampfwert und die Reiter
  **Uebersicht** (Karte, verwerten; Umbenennen entfernt 23. Nov. -- nie gewollt, das Eingabefeld zerschoss im Browser die Anzeige), **DROME** (Level/Skilltree, Platzhalter),
  **Waffe** (fest: Bild + Werte der Waffe mit Vergleich; scrollt: Halter, Charger, Level der
  Waffe zum Aufklappen, "Aus dem Inventar" Waffen | Charger, ein Hauptknopf einbauen /
  einsetzen / entfernen). Charger lassen sich auf die Karte ziehen.
* `UiKit.segmented(..., wide)` fuer Schalter ueber die ganze Breite.
* 23. Nov.: Werte-Kasten der Waffe-Seite mit fester Hoehe (`WEAPON_BOX_HEIGHT`), damit beim
  Halterwechsel (Molok) nichts springt; Faehigkeiten ohne Balken (Deflektor-Schild) zeigen ihren
  Text. Startbestand eines neuen Spielstands: nur die vier CyberDrome-DROMEs, jede Waffe einmal
  (`config.json -> new_game.faction_dromes = false`).

### Fuenf Tabs: Shop, Fabrik, Home, DROMEs, Inventar (22. Nov. 2026, Entscheidung des Spielers)

Design-Canvas https://claude.ai/artifact/AH1kw5G3KweJxjygGuFu33 (Boards „Fuenf Tabs“).

* **Tab-Leiste** (`UiKit.TABS`, `TAB_*`): Shop · Fabrik · Home (Mitte, gelb) · DROMEs ·
  Inventar; neue Symbole `tab_factory`, `tab_dromes`, `tab_inventory`.
* **Shop** nur kaufen (`shop_screen.gd`, `mode = "shop"`). **Inventar** (`scenes/inventory.tscn`,
  gleiches Skript, `mode = "inventory"`): Reiter Inventar (Bestand, Energy Phases, Caches oeffnen)
  und Charger (Charger-Crafter).
* **Fabrik** (`resources_screen.gd`): Platzhalter fuer das Ressourcen-System.
* **DROMEs** (`hangar_screen.gd`): Reiter DROMEs (Liste, gewaehlter DROME gross, Knoepfe
  Ausruestung / Upgrade, darunter neue DROMEs bauen -- `DromeForge`, vorher im Shop) und Waffen
  (alle Waffen, Knoepfe Upgrade / Charger). Unterseiten mit Zurueck-Pfeil und Schalter in einer
  eigenen Zeile. **Ausruestung**: Bild oben links, rechts die Werte der Waffe im gewaehlten
  Halter; eine freie Waffe antippen zeigt den Vergleich als Balken mit Unterschied
  (`_set_compare`, `WeaponCard.attack_bars/ability_bars`); darunter Halter und Charger.
  **Upgrade** (DROME und Waffe) ist ein Platzhalter, bis Ressourcen-Upgrade und Skilltrees
  entschieden sind; Level durch Erfahrung entfaellt.
* Offen: Home nach dem Entwurf (Boss, Story-Stand, Missionswahl, Cyberwave) -- heute das
  bisherige Hauptmenue; Squad-Wahl bleibt in der Einsatzvorbereitung.

### Ruhige Kamera, groessere Hexfelder, Cache im Glitch-Stil, weniger Ruckeln (21. Nov. 2026, Wunsch des Spielers)

Design-Canvas „CyberDrome Cache, Kampf, Hangar“ (https://claude.ai/artifact/AH1kw5G3KweJxjygGuFu33).

* **Kamerafahrten aus** (`BattleScreen.CAMERA_MOVES = false`, Code bleibt): kein Schwenk in der
  Aufstellung, kein Zoom bei grossen Faehigkeiten, keine Kamera-Szenen (`Cinema`), Kachel
  antippen faehrt nicht mehr hin. Neue Ansicht `_frame_board`: Zoom fuellt die Breite mit dem
  Feld und bleibt fest; nur senkrecht gleitet das Bild sanft zur Mitte der lebenden DROMEs
  (ueber den Feldrand faehrt es nie); beim Aufstellen steht die eigene Zone ganz im Bild.
  Die Leisten oben/unten misst `_hud_edges`. Finger ziehen/zoomen bleibt, „Kamera“ holt die
  Ansicht zurueck.
* **Hexfeld groesser:** `IsoView.HEX_R` 26 statt 22 (Bodenplatten neu mit
  `tools/build_arena_models.py`), DROMEs gleich gross. Auf 450 px Breite ist ein Feld jetzt
  rund 60 statt 50 px breit.
* **Neon Cache wieder Zeichnung** (`CacheArt`, Shader `neon_cache.gdshader` entfernt).
  **Oeffnen im Glitch-Stil** (`CacheOpener`): Anspannen 0,45 s, drei Glitch-Spruenge
  (Cyan/Magenta-Umriss `CacheArt.flat`, Riss-Streifen), Knall bei 0,8 s (Blitz, Deckel,
  Sechseck-Ringe, Pixel-Funken, Stoss), Beute ab 1,1 s; Ergebnisfelder ploppen ueberhell auf.
  Nichts wird je Bild neu gezeichnet (Strahlen drehen als Knoten).
* **Ruckeln:** Punktraster (`Arcade.draw_dots`) und Scanlines als gekachelte Textur statt
  ~1800 Kreisen bzw. ~270 Linien -- betrifft jede Seite mit Arcade-Hintergrund (Optionen,
  Shop, Hangar ...) und den Cache-Bildschirm, der das Raster vorher JEDES Bild neu zeichnete.
* **Nachtrag (Spieler):** DROMEs kleiner (`figures.scale` 0,62 statt 0,75), Lebensbalken 6 px
  hoch nur mit schwarzem Umriss (abgeschraegt, ohne schwarzen Grund; 22. Nov.), Takt-Leiste als Kaestchen je Angriff mit pulsierendem Rahmen, wenn die Faehigkeit
  als Naechstes kommt (`UnitBadgePainter._takt`). Level durch Erfahrung entfaellt (Upgrade
  mit Ressourcen + Skilltrees kommen spaeter); Richtung fuer die Navigation: fuenf Tabs
  (Shop, Ressourcen, Home in der Mitte, DROMEs, Inventar) -- SPOT-Eckpunkte, noch in Ueberlegung.
* **Offen, im Canvas zur Wahl:** weniger Gewusel im Kampf (Balken schlanker, kurze
  Schussspuren, nur grosse Zahlen, Gegner-Schuesse gedaempft) und der **Hangar** (Vorschlag
  „ein DROME, eine Seite“, Werkbank in den Hangar, Fragen an den Spieler).

### Kampfbild mehr 3D, Paket 1-3 ohne Höhenstufen (21. Nov. 2026, Entscheidung des Spielers)

Grundlage: Design-Canvas „Kampfbild mehr 3D“
(https://claude.ai/artifact/WrHqW9gAqkfgZUfsEL3At7), Spieler: „Paket 1 und 2
direkt umsetzen, Paket 3 überlege ich mir noch“. Alles nur Bild, die Logik
läuft weiter Feld für Feld. Werte in `data/config.json` -> `motion`.

* **A1/A2 Kurven, Durchlaufen:** `Unit` trennt Führungspunkt (linear wie
  bisher, `_track`) und Figur (`position`, gedämpfte Feder, `omega` je
  Chassis). Die Figur läuft weich an, schneidet Ecken leicht, läuft über die
  Feldmitten durch und bremst erst am Ziel. Sog/Stoß rutschen wie bisher.
  `visual_velocity()`/`visual_accel()` für die Körpersprache; `held` beim
  Ziehen in der Aufstellung.
* **A3 Drehen:** `Arena3D._turn_toward` -- Blick zieht weich nach
  (`turn_time`, `turn_rate`), beim Laufen in Laufrichtung, beim Zielen genau
  aufs Ziel. `Unit.facing_at` misst jetzt auf dem Boden (vorher bis ~8 Grad
  daneben).
* **A4 Körpersprache:** `Arena3D._lean` -- nach vorn je Tempo/Anlauf, zurück
  beim Bremsen, in Kurven nach innen; Schrittlänge folgt dem Tempo; Molok
  stampft (Staub), Nimbus schwebt, Strix hüpft.
* **A5 Lockere Aufstellung:** `Unit.stand_offset()` (fest je Kennung,
  höchstens 8 % der Feldbreite), Ausweichen beim Vorbeilaufen
  (`Arena3D._update_nudges`, `Unit.nudge`).
* **B6 Stufe 1:** Blob-Schatten im `UnitRing`; vorgetäuschtes Licht über
  `glow_in`/`glow_dir` im `drome_face.gdshader` aus den Laternen
  (`Arena3D.light_spots`) und Mündungsblitzen -- kein Licht-Node.
* **B7 Teilchen:** `ParticleFx` (neu) rechnet im Raum (Boden + Höhe, Schwerkraft,
  Abprall) und zeichnet flach: Funken, Rauch ab 15 % Schaden, Trümmer beim
  Zerfallen, Staub, Dampf; Obergrenze `particles_max`. Energie- und
  Flächenringe liegen als Ellipsen am Boden (`BattleView.FloorRings`).
* **C9 Kamera:** kurzer Zoom bei großen Fähigkeiten (Fläche oder Ausholzeit
  ab 0,3 s, höchstens alle 3,5 s), Schwenk von den Gegnern zum eigenen Squad
  zu Beginn der Aufstellung (Antippen überspringt). Wackeln gab es schon.
* **D12 Ränder:** `EdgeLife` (neu): Regen in Neon City (`motion.rain`),
  Gras im Park, Dampf in Factory 5; `ArenaPainter.Lights` flackern/atmen,
  Glühwürmchen im Park.
* Mit „Bewegung reduzieren“: keine Teilchen, kein Regen, kein Zoom/Schwenk,
  keine Neigung.
* **Paket 3 ohne Höhenstufen (21. Nov. 2026, Spieler: „Paket drei auch gern,
  Höhenunterschiede erstmal weglassen“):**
  * **B8 Bodenmarken als Felder:** `AbilityPainter.area_tiles`/`_draw_cells` --
    Flächenmarken (Vortex, Sperrfeuer, Wirbel, Nahkampf-Ansage) färben genau
    die getroffenen Hexfelder, die Außenkante leuchtet (Gegner: rot), die
    Füllung wächst mit der Ausholzeit. Ringe, Runen, Pfeile bleiben obendrauf.
  * **C10 Kamera-Szenen:** `Cinema` (neu) -- perspektivische Kamera auf dieselbe
    3D-Welt, Boden dafür auf eigener Ebene (`Arena3D.build_cinema_floor`).
    Auftritt der Gegner im Elite-Kampf, Kreisfahrt beim Sieg vor dem Ergebnis;
    die Zeit steht, Antippen überspringt, höchstens 20 Grad neben der
    Iso-Richtung (die Modelle sind für sie gebaut).
  * **B6 Stufe 2 echtes Licht:** Option „Echtes Licht (Test)“ in den Optionen
    (`Accessibility.real_light`, Standard aus). Bis zu 8 Punktlichter je Bild
    (Mündungsblitze, nächste Laternen) als globale Shader-Werte
    (`project.godot` -> `shader_globals`, `arena_light_*`), Licht je Bildpunkt
    nach Abstand und Richtung im `drome_face.gdshader`. Keine Schatten.
  * **D11 Höhenstufen:** zurückgestellt, steht als offener Punkt in der SPOT.
* **Offen:** Leistung auf dem Handy messen (24 DROMEs, Ziel weiter ca. 41 B/s),
  einmal mit und einmal ohne „Echtes Licht (Test)“. Tests: `tests/test_motion.gd`.

### Englisch vorbereitet, letzte Umlaute (19. Nov. 2026, Spieler)

* Aufwand Englisch geschaetzt (rund 1.000 Anzeigetexte in `scripts/`, 750
  Namen/Beschreibungen in `data/` + `parts/`, bisher kein `tr()`): reines
  Umschreiben 2-3 Sitzungen, Sprachwahl de/en 4-6. Entschieden: erst die
  Grundlage, den Umbau spaeter.
* Gebaut: `i18n/texte.csv` (Schluessel = deutscher Text, Spalte `en`),
  in `project.godot` eingetragen, `Accessibility.language` (fest `de`,
  `set_language`), Test `test_i18n`. Regeln in `i18n/LIESMICH.md`.
* SPOT-Glossar mit Spalte **Englisch (Vorschlag)** -- z. B. Einsatz =
  Mission, Takt = Beat, Halter = Socket, Zwischenstopp = Interference, Baukern = Build Core.
  Noch nicht entschieden.
* Umlaute nachgezogen: "Mörser" und "E-Schraubenschlüssel" standen noch
  ohne (der Teile-Generator hatte sie zurueckgeschrieben).

### Begriff "Fusion", Token im Design-System (19. Nov. 2026, Spieler)

* Rezept-Module heissen im Spiel **Fusion** (mit BIOS: **BIOS-Fusion**);
  "Rezept" bleibt die Anleitung im Rezeptbuch. Im Code bleibt `recipe`.
* Token `module-fill` (#1a0b36) ins Design-System-Artefakt uebernommen.
* Offene Annahmen vom Spieler bestaetigt: Chaos-BIOS zaehlt zu den drei
  BIOS, der Booster zaehlt jeden Kampf, ohne Modul im Einsatz beliebige
  BIOS-Angebote, Luecken nach dem Verkauf bleiben. Laden bleibt oben;
  Tauschen/Kaufen per Tippen braucht es nicht.

### Zusammenfuegen beim Ablegen, BIOS-Karten schlanker (19. Nov. 2026, Spieler)

* Ablegen auf ein Modul, mit dem es ein Rezept ergibt, fuegt zusammen statt
  zu tauschen -- aus dem Lager (`place_from_storage`), aus einer Waffe
  (`move_installed`), aus dem Laden in eine Waffe (`buy_into`) und aus dem
  Laden auf ein Lager-Modul (`buy_onto_storage`). `RunState.pair_of` sagt,
  was zwei Module ergeben. Der Hinweis zeigt "Kaufen · Rezept: X" schon
  beim Ueberfahren; passende Lager-Module leuchten beim Ziehen aus dem Laden.
* BIOS-Karten ohne "sofort nutzbar / bald / angefangen".

### Chaos-Beute, Credit-Booster, BIOS-Wahl als Bildschirm (19. Nov. 2026, Spieler)

* **Chaos-Sieg:** ein Wurf aus `run.loot.chaos` -- 33 % BIOS-Wahl (zaehlt zu
  `bios_elite_wins`, sonst Cache), 33 % Cache, 33 % Credit-Booster, 1 %
  Fraktionskern (`home_queue`, `Roster.add_faction_core`, Gebiet -> Fraktion
  ueber `loot.faction_cores`).
* **Credit-Booster:** `RunState.credit_boost` Kaempfe mit `booster_mult`
  (2x) Credits, auch bei Niederlage gezaehlt; steht im Beute-Popup.
* **BIOS-Angebote** nur noch sofort/bald/angefangen (`bios_state`), sonst
  beliebige, wenn gar kein Modul im Lauf ist.
* **BIOS-Wahl als eigener Bildschirm** vor dem Zwischenstopp
  (`_show_bios_choice`): Karten "aus X wird Y" mit Wirkung und Naehe,
  antippen + NEHMEN; Lager voll -> "Zum Zwischenstopp", Wahl bleibt oben.
* `tests/screenshot.gd`: `bios=1` legt eine BIOS-Wahl aus.

### Zwischenstopp: Schrott, Kauf in die Waffe, Tauschen (19. Nov. 2026, bestaetigt vom Spieler)

* **Schrott-Feld** rechts neben dem Lager (`ScrapZone`): Module aus dem Lager
  oder aus einer Waffe hineinziehen = verkaufen (`RunState.sell_installed`);
  im Waffen-Popup zusaetzlich "Verkaufen".
* **Laden -> Waffe:** Angebot auf eine Waffe ziehen = kaufen und einsetzen
  (`RunState.buy_into`), aufs Lager = kaufen. Ein volles Lager stoert nur,
  wenn dabei getauscht wird.
* **Tauschen:** Ablegen auf einen belegten Platz tauscht
  (`place_from_storage`, `move_installed`, auch zwischen Waffen und DROMEs).
* Alle drei laufen als Probe (`apply` false) ueber `RunState._attempt` und
  `_layout_blocker`: dieselbe Funktion sagt vorher, ob und warum etwas nicht
  geht -- das Ziel leuchtet oder nennt den Grund.
* Geprueft mit echten Maus-Ereignissen im Fenster (Einsetzen, Tauschen,
  Schrott aus Waffe und Lager, Kauf in die Waffe, Umsetzen).
* **Das Gezogene zielt, nicht der Finger** (Wunsch des Spielers, wie in
  Backpack Brawl): Waehrend des Ziehens liegt eine Fangflaeche ueber dem
  Bildschirm (`_open_catcher`), das Ziel ist, was unter der Mitte des
  schwebenden Moduls liegt (`_aim()` = Finger + `DRAG_LIFT` 70 px nach
  oben). Aufstellung im Kampf ebenso: die Figur schwebt `DEPLOY_LIFT` 44 px
  ueber dem Finger, das Feld unter ihren Fuessen zaehlt.

### Feste Modulplaetze, BIOS neu, Zwischenstopp in Zeilen (18. Nov. 2026, Entscheidung des Spielers)

Entwurf als Canvas "Zwischenstopp Neu" (Variante B gewaehlt).

* **Modulplaetze fest:** keine Plaetze mehr durch Level (`module_slots_at` und
  `Leveling.extra_module_slots` entfernt) und keine durch BIOS. Vireo, Nimbus,
  Strix 3 je Waffe, Molok 2 je Waffe.
* **Chassis-BIOS entfallen** (Daten, `DromeBuild.chassis_bios/bios_slot`,
  Passiv-Verstaerkungen im Kampf). Alte Spielstaende laden ohne Fehler.
* **BIOS-Wahl fest** nach jedem gewonnenen Elite-Kampf (nie nach dem letzten),
  bis `rules.bios_elite_wins` (3) vergeben sind (`RunState.bios_given`); danach
  sicher ein Lootcache. Ein Rezept-BIOS wertet ein Rezept in einer Waffe an
  seinem Platz auf (`install_bios`, Ziehen aus dem Angebot auf die Waffe),
  beim Molok nur in einer Waffe. Chaos-Kaempfe geben keine BIOS-Wahl mehr.
* **Zwischenstopp:** DROMEs als Zeilen, Waffe (Halterform) vor ihren Plaetzen;
  Module ueberall 52 px als Kartusche (`ModuleChip`: abgeschraegt, Klassen-Ecke,
  doppelter Rahmen fuer Rezepte). Token `module-fill` jetzt `#1a0b36`.
* `tests/screenshot.gd` kennt `module=<drome>.<halter>:<id>+<id>` und `lager=<id>+<id>`.

### Flache Hexfelder, doppelte Figuren (18. Nov. 2026, Meldung des Spielers)

* **Flache Sechsecke** (Kante oben und unten): vorher hatten die Felder oben
  und unten eine Spitze, wer geradeaus auf den Gegner zuging, lief im
  Zickzack. Jetzt "odd-q": Spalten senkrecht, ungerade Spalten ein halbes
  Feld tiefer und eine Reihe kuerzer -- so bleibt die Spiegelung an der
  Mittelreihe exakt (`MapGenerator.mirror`: h - 1 - y bzw. h - 2 - y).
  Richtung i zeigt auf 30 + 60 i Grad (`Grid.AXIAL_DIRS`, `direction_angle`),
  `IsoView` mit `COL_W`/`ROW_H`, Tiefe in halben Reihen, Bodenplatten um
  30 Grad gedreht (`ArenaFloor3D`). Kartenformen neu in Spalten gerechnet
  (Bauch mit geraden Schraegkanten, Zwei Gassen als gerade Mauer in der
  Mittelspalte). Messung: `playtest.gd -- 150` 114 statt 102 Siege,
  `run_bench.gd -- 40` unveraendert.
* **Doppelte Figuren**: die Aufstellung setzte die Blickrichtung, bevor die
  Einheit an der 3D-Szene hing -- dabei entstand ein 2D-Bild, das unter dem
  3D-Modell eingefroren stehen blieb ("der Vireo steht doppelt da"). Jetzt
  raeumt `Unit._build_sprites` es weg. Dazu eine Sicherung in `Arena3D`:
  wer gefallen ist, verschwindet spaetestens nach der Zerfallszeit.

### Karten je Formation (18. Nov. 2026, Entscheidung des Spielers)

* Messlauf `tools/playtest/map_bench.gd` (Ergebnis-Seite
  https://claude.ai/artifact/GF1hrgR3G8fpBHUpa8L29e): die Groesse stellt das
  Tempo ein (erster Treffer 3,0 s bei 13 Reihen, 4,2 s bei 17, 5,6 s bei 21),
  die Form verschiebt einzelne Formationen um bis zu 30 Punkte.
* Entschieden: die Karte stuetzt den Gedanken der Formation. `config.json` ->
  `maps` (standard 9 x 15, kurz 9 x 13, lang 9 x 21, gassen 9 x 17 mit Block in
  der Mitte, bauch 11 x 17), `formations.json` -> `map` je Formation
  (Einfuehrung + Bullies kurz, Squad standard, Dachschuetzen lang, Lazarett
  gassen, Schattenrudel bauch). Chaos-Kaempfe: Standard.
* Formen: `MapGenerator.apply_shape` setzt Loecher (`Grid.holes`, gehoeren
  nicht zum Feld; Boden und Zierlinie folgen von selbst) und feste Bloecke,
  an der Mittelreihe gespiegelt, Zonen immer frei. Der Bauch waechst ab der
  Zone je Reihe um ein halbes Feld (gerade Hexkanten).
* Zufaellige Hindernisse aus (`obstacles.enabled` false, Wunsch des Spielers:
  berechenbar), Randdeko bleibt.
* Messung: `run_bench.gd -- 40` mit den Karten der Formationen wie vorher
  (Abweichungen im Rauschen). Gegen gewuerfelte Gegner (`playtest.gd -- 150`)
  auf der Standardkarte 102 statt 111 Siege, erster Treffer 4,4 statt 5,3 s.
* Lauf-Vorschau zeigt die Karte ("Karte: Bauch").

### Hangar: DROME-Wechsel ohne Ruckler (18. Nov. 2026, Meldung des Spielers)

* Jedes Antippen baute den ganzen Hangar neu auf, und jede Kachel renderte
  ihren DROME frisch in 3D (2-3 SubViewports mit MSAA je Bild). Gemessen
  (`tools/perf_hangar.gd`, Software-Rendering, 4 DROMEs): erstes Bild nach dem
  Wechsel 115-150 ms bei ~30 ms Grundlast.
* Jetzt: `UiKit.drome_view` rendert jeden Aufbau einmal und merkt sich die
  fertigen Ebenen (Bild, Signal, Neon) als Texturen
  (`DromeSprites.assemble_picture`, bis 48 Bilder); danach nur noch ein Sprite
  mit Konturshader, ohne 3D. Antippen im Squad tauscht nur die grosse Karte
  und die Markierung (`HangarScreen._select_in_squad`). Ergebnis: 30-46 ms.
  Der Kampf rendert weiter live (Drehen, Bewegung).

### Echo nacheinander, Flaechen landen am Wurfort (18. Nov. 2026, Wunsch des Spielers)

* **Echo (Nimbus)** wirkt nicht mehr im selben Augenblick, sondern
  `passives.echo.gap` (0,5 s) nach der Faehigkeit (`Unit.echoes`,
  `AIController._tick_echoes`). Mit Ausholzeit (Vortex) zeigt das Echo die
  Ansage ein zweites Mal und fliegt so lange wie der erste Wurf -- der DROME
  bleibt dafuer aber **nicht** stehen (ein zweites Stillstehen kostete in der
  Messung rund 15 % Schaden). Kann das Echo nicht wirken, verpufft es.
* **Flaechen** (Vortex, Sperrfeuer, Wirbel) folgen dem Ziel waehrend der
  Ausholzeit nicht mehr, sie landen auf dem Feld, auf das geworfen wurde
  (`AIController.lands_on_tile`, `_landing`) -- wer rechtzeitig weglaeuft,
  entkommt dem Sog und der Schockwelle. Auch ein inzwischen leeres Feld wird
  getroffen (`ActionResolver.execute(..., thrown)`).
* **Messung** (gleiche Seeds, `playtest.gd -- 200 0`, Squad Vireo/Molok/Nimbus):
  `main` 146 Siege, Nimbus 8,6 Schaden/s; neu 150 Siege, Nimbus 8,4/s.
  `run_bench.gd -- 20` unveraendert (Unterschiede je Feld +-1 bis 3). Ausholzeit
  und Salven bleiben damit wie sie sind.

### Kampf als eine 3D-Szene + Bewegung (18. Nov. 2026, Übergabe Schritt 4/5)

* `Arena3D`: alle DROMEs und Hindernisse in einer 3D-Welt, Kameras folgen der
  2D-Kamera; Einheiten ohne eigene 3D-Ansicht; Kontur je Teil, Neon,
  Farbstich und Zerfallen wie vorher. Hindernisse als 3D-Modelle
  (`tools/build_arena_models.py`, CI prüft). Die gezeichneten
  Hindernis-Bilder von Neon City werden im Kampf nicht mehr genutzt.
* Bewegung: Atmen, Wippen/Kippen/Hüpfen beim Laufen, Angriff je Waffenart
  (Ausholen um die Schulter, Rückstoß + Aufleuchten, Schildstoß).
* Boden aus 3D-Hexplatten je Region (`ArenaFloor3D`, einmal gerendert).
* Leistung nur vom Handy messbar (Leistungstest „eine Szene“ als Maßstab);
  vom Spieler am 18. Nov. als „okay“ bestätigt, ebenso die 3D-Hindernisse
  statt der gezeichneten und die schwerere Elite auf dem Hexfeld.

### Hexfeld 9 x 17 (17. Nov. 2026, Entscheidung des Spielers)

Entwurf mit drei Groessen (`docs/design/drome_entwurf/v12_hexfeld.py`, Bild
`hexfeld_optionen.png`); gewaehlt: **9 x 17 hochkant, Reichweiten 1:1,
Reihen waagerecht**. Gebaut:

* `Grid`: Feld = `Vector2i(spalte, reihe)`, ungerade Reihen ein halbes Feld
  rechts; Abstand in Hexschritten (axial), sechs Nachbarn, Richtungen
  0..5 im Bild auf 0/60/.../300 Grad, gerade Linien (Dash, Stern-Flaeche).
* `MapGenerator`: Spiegelung an der Mittelreihe (bei 17 Reihen exakt),
  Zonen 3 x 7 unten/oben ohne Abstand zum Rand, Hindernis-Formen aus
  Hexnachbarn. `config.json`: `grid_width` 9, `grid_height` 17.
* KI, Ziehen/Stossen, Dash und Vortex auf sechs Richtungen; Blickrichtung
  als Winkel (`Unit.facing_toward`, `DromeModel.angle_basis`).
* Anzeige (`IsoView`, `ArenaPainter`): Sechsecke 22 Einheiten Eckradius in
  der DROME-Projektion, Reihen waagerecht, Tiefe gestaucht (cos 45);
  Rand = Kanten ohne Nachbarn, Sockel vorn. Die Rauten-Bildkacheln fallen
  weg, bis der Boden in Schritt 4 aus dem 3D-Generator kommt.
* Gemessen: Spiegelkaempfe 96:104 (fair), Kaempfe 26 statt 32 s, erster
  Treffer 5,0 statt 7,2 s. Standard-Squad gegen Einsatz-Gegner: Leicht und
  Normal wie vorher, **Elite deutlich schwerer** (Runde 5: 7/24 statt 13/24,
  Runde 8: 7/40 statt 16/40) -- offen fuer den Spieler.

### UI-Symbole statt Sonderzeichen (15. Nov. 2026, Set des Spielers)

Bungee und Chakra Petch kennen viele Sonderzeichen nicht (▸ ◈ ⬢ ✦ ✕ ✓ ◉ ▮ ↻
◎ ○ ❚ ☰ ⏩); Godot zeichnete dann einen Kasten mit dem Zeichencode ("Umbau
25B8"). Der Spieler hat 82 SVGs geliefert: `assets/ui_icons/` (weiss, 24 px,
Import `svg/scale=4`, Fundstellen in der README dort). Baukasten `UiIcon`:
`rect` (Bild), `text` (Symbol + Text), `on_button` (Symbol im Knopf, links/
rechts/mittig/oben); InfoPopup-Aktionen nehmen `"icon"`, `Arcade.tag` ein
viertes Argument. Ersetzt sind bisher nur die fehlenden Zeichen (Popup-
Schliessen und Blaettern, Kampf-Leiste, Story "Ueberspringen", Waehrungen in
Hauptmenue, Shop und Einsatz, Rezept-Haken, Verlauf, Optionen-Ueberschriften).
`tests/test_glyphs.gd` meldet jedes Zeichen in Skripten/Daten, das eine der
Schriften nicht hat. **Rest am selben Tag umgesetzt** (Wunsch des Spielers):
`StatIcon` zeichnet die SVGs (Waffen-Karte, Squad-Kacheln), Tab-Leiste,
Stufen der Kampfkarte und Verlauf-Legende (Kreis/Raute/Stern, Chaos `unknown`),
Rollen-Symbol im Hangar, Modulklassen im `ModuleChip`, Zustaende und
Angelockt im Kampf, Credits ueberall als Symbol (kein ¢ mehr), ▶ in Knoepfen
als `play` rechts, +/− im Hangar und in der Squad-Wahl, `>>` im Hangar als
Doppelpfeil, Cache-Zeichen im Shop, Aufstieg/EP im Ergebnis. Als Text
geblieben (Zeichen sind in den Schriften): × und − in Saetzen, Ø, →, ◆ im
Titel-Laufband, Kuerzel KW/EP/SPD in Saetzen.

### Entwurf Einsatz-Bildschirme umgesetzt (15. Nov. 2026, Wunsch des Spielers)

24 Entwuerfe des Spielers (`docs/design/einsatz_arcade/`, Bilder und
Vorlagen, Abgleich im README). Abgesprochen: **nur Optik**, Navigation bleibt
(Tab Shop, Zahnrad), Credits nur im laufenden Einsatz auf der Startseite.

* **Bausteine** (`UiKit`): Kopfzeile mit Glitch-Titel, `header_slot` rechts
  daneben, Reiter als `segmented` (Hangar, Shop), Tab-Leiste mit Symbolen
  (`TabButton`), Karten mit 6-px-Schatten (`shadow_size` 1 -- 0 zeichnet in
  Godot gar keinen), `outline_button`. `InfoPopup` mit Titel in Bungee,
  `kicker` (gelbes Etikett) und `sheet` (Blatt von unten, Waffen-Karte).
* **Startseite**: Buehne im Rahmen mit Etikett DEIN SQUAD, Gebietskarte mit
  Fortschritt je Kampf (laufender Einsatz), Squad-Kaestchen, Coins (Credits
  nur im Einsatz), Infinity-Einsatz gesperrt als gestrichelter Kasten.
* **Hangar**: Squad mit grosser Karte oben (Rolle, Level, Kampfwert, Werte
  zweispaltig, Waffe), Raster 3 Spalten darunter. Umbau mit Text-Kacheln,
  Halter links / Bild / Werte rechts, Name per Tipp umbenennen.
* **Einsatz** (`run_screen.gd`): Glitch-Titel und Leiste Leben (Herzen),
  Credits, Caches, Verstaerkung. Kampfkarte mit Stufen-Etikett, Anfuehrer und
  Beute-Zeile (`RunState.loot_text`, aus run.loot statt dem alten Text).
  Zwischenstopp mit Rezeptbuch + Zur Karte unten. Ende mit Glitch-Schriftzug,
  Verlauf als Kette (`RunChart`), Was bleibt, DROME-Level, Zum Hangar.
* **Kampf**: CanvasLayer bekommt das Theme (vorher Godot-Schrift!), Kopf mit
  Ort, Uhr, Virus-Vorwarnung, Gegnerzahl; Aufstellung mit Hinweis-Karte und
  LOS; Leiste Tempo/Pause/Protokoll/Kamera. Ergebnis traegt den Kampf **gleich
  ein** (`finish_run_battle` beim Anzeigen) und zeigt Zeit, Abschuesse,
  Credits und die Beute; "Weiter" wechselt nur die Seite.
* **Shop/Caches**: Bestand, Cache-Karten mit KAUFEN, Hipstar gesperrt,
  Baukerne, Upgrades folgen. Caches-Lager mit allen vier Sorten
  (`CacheArt`), **Cache oeffnen** (`CacheOpener`) als Vorschau -- verbraucht
  nichts, bis die Inhalte entschieden sind.
* **Optionen** nach Entwurf (Karten, Schalter mit AN/AUS, Spielstand-Kachel,
  Debug). **Story-Dialog** (`StoryDialog.play`) als Baustein, noch nicht
  angebunden.
* `tests/screenshot.gd` kann jetzt Zustaende vorbereiten: `run=story
  results=SSN weiter=1`, `editing_index=0`, `caches=city:3`,
  `static=res://...gd:_tab:"caches"`, `cache_open=city[:auf]`, `karte=eq_hammer`,
  `story=links|rechts`. Bilder per `xvfb-run` ohne Web-Export.
* **Neues App-Icon** vom Spieler (Pixel-"C" in Gelb/Cyan/Magenta):
  `assets/icon/app_icon.png` (512 px) ist Projekt-Icon, Favicon und PWA-Icon.
  Das alte erzeugte SVG und `tools/build_app_icon.py` sind entfernt.
* Offene Punkte aus dem Entwurf (Erstabschluss-Bonus, Seltenheit, Hipstar,
  Lager 6/8, Mecha gesperrt, Endlos-Name, Kampf-Kacheln) im SPOT-Blatt.

### Tab Shop, Optionen am Zahnrad (15. Nov. 2026, Wunsch des Spielers)

* Tab-Leiste: Spielen, Hangar, **Shop** (`scenes/shop.tscn`,
  `shop_screen.gd`) mit den Reitern Shop (Baukerne, Caches fuer Coins;
  config `hangar_shop`, `Roster.buy_offer`), Caches (oeffnen folgt) und
  Bauen (Material, neue DROMEs -- aus dem Hangar umgezogen).
* **Optionen** am Zahnrad oben rechts jeder Hauptseite (`Arcade.GearButton`,
  `UiKit.SETTINGS_SCENE`); der Pfeil fuehrt zurueck (`UiKit.return_scene`).
* Entschieden: Bosse und Caches geben Komponenten (Fraktionskern, Baukerne)
  oder gleich einen ganzen Fraktions-DROME (Vorschlag im Blatt Lootcaches).

### Bedienung umgedreht, Verwerten (15. Nov. 2026, Wunsch des Spielers)

* **Kacheln**: tippen waehlt (gelber Rahmen), nochmal tippen zeigt das Popup,
  Doppeltipp handelt (ausruesten, kaufen, einsetzen, zusammenfuegen, Umbau).
  `Tile.on_select/on_info/on_action`; ohne ``managed`` merkt sich Tile die
  Auswahl selbst. Mit Doppeltipp-Handlung wartet das Popup 320 ms.
* **Popups blaettern**: `InfoPopup.open_pages(host, seiten, index)` -- Pfeile
  mit Zaehler und Wischen. Die Waffen-Karte ist eine Seite (`WeaponCard.page`).
* **Verwerten statt Aufloesen** (`Roster.salvage`): Baukern, bei
  Fraktions-DROMEs (`RosterEntry.variant`) dazu der Fraktionskern; Waffen
  bleiben. **Bauen**: 3 Baukerne = Standard-DROME (`craft_drome`),
  Fraktionskern + 3 = Fraktions-DROME mit festen Werten
  (`craft_faction_drome`). Werte in config `crafting`.

### Squad aus drei + Zwischenstopp nach Entwurf (16. Nov. 2026, Spieler)

* **Squad aus drei DROMEs** (`run.squad_max`, `squad_size_max` = 3):
  Hangar, Einsatz und neue Spielstaende; `Roster.trim_squad` kuerzt alte
  Staende. Gegner unveraendert -- Elite wird schwerer (offener Punkt im SPOT).
* **Zwischenstopp** (`run_screen.gd` `_show_stop`): eine Kopfzeile (Zurueck,
  Leben, Credits, Beute-Knopf mit Blaetter-Popup), Laden (3 Module + schmal
  Neu wuerfeln), Lager in zwei Reihen, drei DROME-Kaesten (Kopf oben, je
  Waffe ein Feld mit ihren Plaetzen; zwei Waffen = breiterer Kasten).
* **Ziehen** (`Tile.on_drag/can_drop/on_drop`, Godot-Drag mit eigener
  Vorschau ueber dem Finger): Ziele leuchten, Ziel unter dem Finger zeigt
  das Modul im freien Platz (`FreeSlot.show_ghost`), Modul auf Modul =
  Rezept (`RunState.pair_result`, Hinweis-Schild). Ziehbare Kacheln stehen
  in der Gruppe `cyberdrome_drag_source`; dort scrollt `Accessibility` nicht.
  Doppeltipp setzt nicht mehr automatisch ein ("Auswaehlen" im Popup).
* **Startseite**: statt der Arena mit dem Squad (`HomeStage`, bleibt im Code)
  eine Boss-Karte (Shogun Kage, `MainMenu._boss_card`) mit dem Bild des
  Spielers (`assets/story/boss_shogun_kage.jpg`, fuellt die Karte, links buendig); Inhalt noch Platzhalter.
  `GameState.battle_ready_builds` zaehlt nur noch den Squad (zeigte "4/3").
* Der Bildschirm nach "Einsatz starten" heisst **Aufstellung**
  (`_show_setup`, `SquadPicker`) -- der Spieler will ihn ueberarbeiten.

### Aufraeum-Runde Bedienung (16. Nov. 2026, Wunsch des Spielers)

"Fuehlt sich schwammig an" -- gebaut:

* **Titel ruckelte**: `Arcade.Backdrop` zeichnete jedes Bild ~1800 Punkte
  und 300 Sonnenstreifen neu, nur fuer das Wippen der Sonne. Jetzt Lagen
  (`BackdropLayer`), die nur bei Groessenaenderung zeichnen; die Sonne wird
  verschoben. Die Laufbaender laufen damit ruhig.
* **Bildschirmwechsel mit Blende**: Autoload `Fader` (`autoload/scene_fader.gd`),
  alle Wechsel ueber `Fader.go(pfad)`; 0,12 s ab, 0,22 s auf, sperrt Eingaben
  waehrenddessen, bei "Bewegung reduzieren" harter Schnitt.
* **Scrollen**: Godots eigenes Touch-Ziehen im ScrollContainer kaempfte mit
  `Accessibility._scroll_input`, sobald man in eine Luecke tippte -- jetzt
  abgeschaltet (riesige `scroll_deadzone`), nachgebildete Mausbewegungen
  waehrend des Wischens verschluckt. Neuaufbauten leeren ueber
  `UiKit.clear` (alte Kinder sofort unsichtbar) -- vorher lagen alt und neu
  ein Bild lang uebereinander, die Seite sprang (Modul waehlen).
* **Zwischenstopp auf einem Bildschirm**: Squad als 2x2-Karten, DROME
  antippen setzt das gewaehlte Modul in den ersten passenden Halter
  (Reihenfolge egal); Lager in einer Zeile ohne Namen, feste Hinweiszeile,
  Credits-Chip weg (Zuwachs steht oben bei den Credits), Preis-Knoepfe dunkel
  auf Gelb mit Symbol und Zahl mittig, ohne Geld grau mit roter Zahl.
* **Sentinels schwebten**: sie wurden um die linke obere Bildecke statt um
  die Fuesse verkleinert (`Unit._scale_about_feet`).

### Grosse Umsetzung (14. Nov. 2026, Wunsch des Spielers)

Eine Sitzung, alles aus der abgesegneten Liste (Bedienung, Arcade-Stil,
Bauschritte 1-3 und Teile von 4). Details in den SPOT-Blaettern Eckpunkte
und Offene Punkte.

* **Bedienung**: Wischen mit Schwung (`Accessibility._scroll_*`, zeitbasiert,
  Kommazahlen). Baukasten **`Tile`** (einmal tippen = Handlung, doppelt oder
  lange = Popup) und **`InfoPopup`**. Zwischenstopp passt fast auf einen
  Bildschirm (Chips, Laden als Kacheln mit Preis-Knopf, Lager als Raster,
  Squad als Zeilen mit Modulplaetzen), **Rezeptbuch als Popup-Raster** mit
  Filter. Hangar: Kacheln zuerst, Doppeltipp = Umbau, Waffe antippen baut ein.
* **Arcade-Glitch-Stil ueberall**: `UiKit` nutzt Farben, Schriften und Formen
  aus `Arcade` (abgeschraegte Ecken, harte Versatzschatten, gelbe
  Hauptknoepfe, schraege Kopf-Etiketten, Scanlines). Hauptmenue mit
  Glitch-Logo, Kampfleisten, Ergebnis mit Glitch-Schriftzug.
* **Anzeige mit Umlauten** (Werkzeug-Lauf ueber alle Texte in `scripts/`,
  `autoload/`, `data/`, `parts/`; Kommentare bleiben ohne) und Begriffe
  Einsatz / Kampf / Infinity-Einsatz.
* **Virusschaden** (`BattleManager._virus_pulse`, config `virus`): ersetzt
  Overtime und Zeitlimit; Glitch-Flackern als Vorwarnung (`Arcade.GlitchOverlay`).
* **Sentinels, Gegner-DROMEs, Formationen** (`Formations`,
  `data/formations.json`): DromeBuild kennt jetzt `stat_override`,
  `unit_kind`, `rank`, `auto_only`, `sprite_scale`, `role_override`.
  Sentinels 60 % gross, kleiner Balken, nur Auto-Angriff, keine Passive.
  Sechs Neon-Formationen als Vorschlag, Varianten Leicht/Normal/Elite,
  **Reinforcement-Level** (`RunState.reinforcement`). Die alten Teams
  (`data/encounters.json`) sind geloescht; `Encounters` haelt nur noch Helfer.
* **Kampfkarte FTL-artig** (`RunState.row/links/available_nodes`, `MapView`):
  feste Wege, anfangs Gabelungen, spaeter Korridore, letzter Kampf ein
  Elite-Knoten. Spielstand-Version 3 (alte Einsaetze werden verworfen).
* **Lootcaches und Platzhaltercoin** (config `run.loot`): Caches der Fraktion
  statt Teilen und Credits, im Einsatz gesammelt, am Ende im Hangar
  (`Roster.caches/coins`). Oeffnen und Hangar-Shop folgen.
* **Heilregel** fuer Support-Waffen (`AIController._care_choice`).
* Messung (`run_bench -- 12`): Normal bis Kampf 5 fast immer Sieg, Elite in
  Kampf 8 etwa 45-60 % -- Sentinels mit den Blattwerten sind eher leicht
  (offener Punkt im SPOT-Blatt).

### Kampf (Echtzeit, Nov. 2026)
* Alle DROMEs handeln gleichzeitig. `BattleManager.tick()` rechnet in festen
  Schritten (`realtime.tick` = 0,05 s); derselbe Seed ergibt denselben Kampf.
  Tests und `tools/playtest/` rufen `run_to_end()`.
* **Bewegung**: Feld fuer Feld, Geschwindigkeit = `move_base + SPD *
  move_per_spd` Felder/s (Molok 1,6, Strix 2,0, Vireo 2,6). MOV zaehlt nicht
  mehr. Das Feld gilt sofort, die Figur gleitet hinterher.
* **Waffen**: jede Waffe (je Teil) laedt fuer sich, `interval` an der
  Aktion (Blaster 1,4 s, Runenstab 1,2 s, Lanze 2,6 s, Hammer 1,8 s).
* **Faehigkeiten** loesen selbst aus (`trigger` an der Aktion): jeder N-te
  Angriff einer Waffe IST ihre Faehigkeit; Vortex jeder 3. Angriff (seit 9. Nov.); Orbit-Fokus wurzelt; Boost, wenn ein
  Gegner danebensteht (hoechstens alle 4 s).
* **Aufgeraeumt (5. Nov. 2026, mit dem Spieler abgesprochen)**: Energie
  (`en_max`, `en_regen`, `en_cost`), Abklingzeiten, MOV, Strombedarf,
  Leistung, Traglast und die **Mutatoren** sind komplett raus -- aus Code,
  Teildaten und Anzeige. Gewicht bleibt nur als Tempo-Preis und wird als
  "bremst um X SPD" gezeigt. Provokation zaehlt Pulse, angezeigt in
  Sekunden. Alte Balancing-Liste (`data/balancing/`, `build_balance_sheet.py`)
  geloescht.
* **Taktik-Reste entfernt (5. Nov. 2026, Wunsch des Spielers)**: das Feld
  ist ein freies Gitter -- kein Gelaende (Stufen, Pfeiler, Drift, Nebel),
  keine Sichtlinie, keine Antriebsflags, keine Provokation, keine aktiven
  Reparatur-Aktionen; Feldmarkierungen, Weg-/Schadensvorschau und
  Aktionssymbole des manuellen Kampfs geloescht. Regionen sind reine Optik
  (Boden + Kulisse). Statuseffekte laufen in Sekunden. Die Teilwerte stehen
  wieder in `tools/build_sample_parts.py` (war veraltet), die SVG-Werkstatt
  rechnet mit denselben Feldern. Der Neuentwurf steht in `docs/NEUANFANG.md`.
* **KI nach Rolle des Chassis** (`ai_role` in `build_sample_parts.py`):
  Molok rueckt vor und weicht nie aus, Vireo kitet mit Fernwaffe und bleibt
  mit Nahkampfwaffe dran, Strix haelt Abstand und weicht nur bei Kontakt aus,
  Nimbus wartet, bis die Frontlinie trifft. Ziel wird gehalten; Fokus-Bonus
  (`ai.focus_bonus`), Neuwahl nach `realtime.retarget_after`.
* **Puls** (3 s je DROME, versetzt): Schild, Drohnen-Pod, Overtime.
  Statuseffekte laufen in Sekunden ab.
* **Overtime** ab 60 s, je Puls wachsend; Zeitgrenze 180 s.
* ~~**Startzonen** 5 Felder von den Ecken eingerueckt~~ -- seit 10. Nov.
  2026 am Kartenrand (siehe "Playtest-Runde").
* **Takt-Leiste** (7. Nov. 2026) unter dem Lebensbalken je Faehigkeit:
  Treffer-Takt in Abschnitten (jeder 4. Angriff = vier Viertel), Zeit-Takt
  fuellt sich in halben Sekunden; voll = hell, als Naechstes kommt die
  Faehigkeit (`Unit.takt_bars()`).
* Bildschirm: Kacheln oben (HP, Schild, Zaehler bis zur Faehigkeit "1/3 Doppel.";
  Texte kuerzen statt die Leiste zu verbreitern),
  Zeit und Region, Kamera haelt das Geschehen im Bild, Schussspuren,
  schwebende Zahlen, Faehigkeitsname ueber der Figur. Daumenleiste: Tempo
  1x/2x, Pause, Log, Folgen. Zugleiste, Aktionsring und manueller Kampf sind
  entfernt.

### Arena und Hindernisse (7. Nov. 2026, Wunsch des Spielers)

> Ueberholt: zufaellige Hindernisse gibt es seit 18. Nov. 2026 nicht mehr
> (feste Kartenformen), der Code dazu ist seit 26. Nov. entfernt.

* **Hindernisse** sperren nur Laufwege, Schuesse gehen darueber
  (`Grid.obstacles`, `can_stand_on`). 3-5 Gruppen (einzeln, kurze Mauer,
  Ecke), punktsymmetrisch zur Feldmitte, nie in oder direkt an den Zonen,
  Feld bleibt zusammenhaengend; eigener Zufall aus dem Kampf-Seed.
  Gemessen (je 200): Spiegel 97:103, gegen gewuerfelte Gegner 143:57 --
  praktisch wie ohne.
* **Optik** (`scripts/ui/arena_painter.gd`, gezeichnet statt SVG-Kachel):
  Bodennuancen je Feld, feine helle Fugen statt schwarzer Umrisse,
  Verzierungen je Region (City: Mittelstreifen, Risse, Pfuetzen, Gullis;
  Parkanlage: Gras, Steine, Blueten; Factory 5: Gitterrost, Rost, Oel,
  Warnstreifen), dunklerer Randstreifen (3 Felder) mit Zierlinie und
  Sockel, Deko darauf (Laternen mit Lichtkegel, Container, Ruinen, Tanks),
  additive Lichtflecken, Vignette. Hindernisse als Iso-Bloecke je Region
  (Container, Kisten, Absperrung / Ruine, Fels / Tank, Rohre, Kisten).
  Die Boden-SVGs unter `assets/terrain/` werden im Kampf nicht mehr gezeichnet.
* **Neon City aus Bildern** (9. Nov. 2026, Wunsch des Spielers; **seit 20. Nov.
  2026 entfernt** -- Boden, Hindernisse und Deko kommen aus dem 3D-Generator,
  `assets/arena/` und `tools/cut_arena_city.py` sind weg, die Quelle
  `art/arena_city/` bleibt; `docs/TECHNIK_PRUEFUNG.md`): Boden,
  Hindernisse und Deko kommen aus KI-Bildern (Quelle `art/arena_city/`,
  mit `.gdignore`). `tools/cut_arena_city.py` schneidet sie zu: Bodenkacheln
  von Draufsicht auf die Spiel-Raute, Objekte per weichem Gruen-Key
  freigestellt, alles in doppelter Groesse nach `assets/arena/city/` samt
  Ankerpunkten (`sprites.json`). Boden: drei Betonplatten, 7 % Akzente
  (Luke, Gitter, Gully, Neonraster, Warnstreifen), Feld leicht, Rand stark
  abgedunkelt. Hindernisse (`config.json` -> `obstacles.kinds.city`):
  Absperrung, Kisten, Server, Automat, Generator, Poller, Holo-Saeule,
  Kabeltrommel; Deko (`obstacles.props.city`): Laden, Schuessel,
  Wartehaeuschen, Klimablock, Antenne, dazu Laternen als Bild. Die Objekte
  sind etwas flacher gezeichnet (ca. 1,8:1 statt 1,4:1) -- faellt im Spiel
  nicht auf. Gibt es zu einer Region oder Art kein Bild, wird wie bisher
  gezeichnet (Parkanlage, Factory 5).

### Lesbarkeit im Kampf (7. Nov. 2026, mit dem Spieler abgesprochen)
* **Lebensbalken** (`BattleView.UnitBadgePainter`): Abstand zur Figur in
  Welt-Einheiten, Groesse in Bildschirm-Pixeln (vorher schwebte der Balken
  beim Herauszoomen weit ueber der Figur). Detailstufen nach Zoom: nah
  Balken + Takt + Zustands-Symbole (betaeubt, verlangsamt, verwundbar,
  Sprint), mittel Balken + Takt, fern nur ein schmaler Balken. Treffer
  lassen den verlorenen Teil kurz hell stehen und nachlaufen. Unter 25 %
  pulsiert der Rand rot. Ueberlappende Balken weichen nach oben aus (fern:
  verdeckte entfallen, der Ring reicht). Angetippte Kachel: Balken 3 s
  groesser. Gegnerbalken mit abgeschraegten Enden (Form statt nur Farbe).
* **Kampf-Kacheln** (`SquadTiles`): nur Kopf, Herz + Zahl, Schild + Zahl
  (Schrift 16) und je Faehigkeit eine kleine Takt-Leiste; Name und SPD per
  langem Druck. Querformat: Kacheln als Spalte links.
* `UiKit.safe_insets()`: Raender fuer Notch/Gestenleiste, wo das System sie
  meldet (im Browser 0 -- die Seite haelt dort selbst Abstand).

### Lauf (Roguelike) -- `scripts/core/run_state.gd`
* 8 Kaempfe, 3 Leben, alles am Seed. Werte in `data/config.json` -> `run`.
* **Aufstellung vor dem Lauf** (`SquadPicker`, `scripts/ui/squad_picker.gd`):
  vorgeschlagen ist der Hangar-Squad, Plus/Minus nimmt mit oder laesst zuhause
  (max. 4).
* Der Lauf **kopiert** die mitgenommenen DROMEs. Im Lauf wird nur mit Beute
  umgebaut, nicht mit dem Inventar zuhause. Beute kann eingebaut oder **nach
  Hause geschickt** werden (`RunState.home_queue` ->
  `GameState.deliver_run_home()`: Teil = Instanz, DROME = neuer Roster-Eintrag).
  Was im Lauf eingebaut wurde, bleibt im Lauf.
* (Frueher fester Start-Squad Vireo + Nimbus -- das war der Fehler "im Lauf
  kommt ein ganz anderes Squad raus", behoben Nov. 2026.)
* **Drei Knoten je Runde** (seit 10. Nov. 2026 `RunState.row`, siehe
  "Playtest-Runde"): Stufen Leicht / Normal / Elite (`run.tiers`). Vorher
  sichtbar: Team, Gegnertyp und die gegnerischen DROMEs mit Ausruestung
  (`RunState.enemies()`, dieselben im Kampf ueber `GameState.enemy_override`).
* **Ein Lauf bleibt in seinem Gebiet** (`run.region` in `data/config.json`,
  heute `city` = Neon City; `RunState.region_id` -> `GameState.battle_region`
  -> `BattleManager.setup`). Bis 9. Nov. 2026 wuerfelte jeder Kampf die
  Region aus seinem Seed -- je Stufe ein anderes Gebiet, obwohl der Lauf in
  Neon City spielt.
* Gegnerstaerke = Startstaerke des mitgenommenen Squads * (0,85 + 0,06 *
  (Runde - 1)) * Stufenfaktor (0,7 / 1,0 / 1,3) -- **feste Kurve**; seit
  10. Nov. 2026 nur noch das Ziel fuer die gewuerfelten Chaos-Gegner.
  Gegnerzahl = Startgroesse + `enemy_offsets[runde]` (-1 bei Leicht, +1 bei
  Elite), 1..4. Elite braucht den Extra-Gegner: zwei Gegner kommen im
  Generator nicht ueber ~680 Kampfwert, bei vier ist bei ~1300 Schluss.
* **Messung** (vier Standard-DROMEs OHNE Beute, 6 Kaempfe je Feld):
  Runde 1 Leicht 6/6, Normal 6/6, Elite 2/6; Runde 4: 6/6, 2/6, 0/6;
  Runde 8: 5/6, 3/6, 0/6. Mit der alten Steigung 0,20 war ab Runde 4 auch
  Leicht nur 1/6 -- die volle Standardausstattung laesst kaum freie Halter,
  der Squad waechst durch Beute weniger als frueher.
* **Beute gewuerfelt, ohne Auswahl** (8. Nov. 2026, 6i; `RunState.roll_loot`):
  ein Hauptwurf je Sieg -- Leicht 40 % ein Teil der Gegner, sonst 4 Credits;
  Normal 60 % Teil, sonst 6 Credits, in Runde 2 und 5 ein DROME; Elite immer
  selten: 35 % neuer DROME, sonst mittleres/schweres Teil. Dazu, wenn ein
  Leben fehlt, Notstrom (Leicht 60 %, Normal 35 %). Sofort verteilt: Teil ins
  Lager (voll: nach Hause), DROME in den Squad (voll: nach Hause). Der
  Zwischenstopp zeigt oben "Beute" mit Ort. Der Belohnungsbildschirm ist weg
  (`Phase.REWARD` wird nicht mehr betreten). "Selten" ist vorlaeufig die
  Gewichtsklasse. Nebenbei behoben: die DROME-Runden griffen nie (JSON-Zahlen
  sind Gleitkomma, `2 in [2.0]` ist falsch).

### Zwischenstopp (7. Nov. 2026) -- `RunState` Phase STOP, `run_screen.gd`
* Nach JEDEM Kampf (auch nach einer Niederlage), nach der Belohnung.
* **Credits**: Sieg Leicht 6 / Normal 10 / Elite 16, Niederlage 4; Verkauf
  einer Waffe leicht 3 / mittel 5 / schwer 8 (`run.tiers.*.credits`,
  `run.loss_credits`, `run.sell_value`). Ausgeben erst mit dem Laden.
* **Lager** mit 8 Plaetzen (`run.storage_size`): Beute-Waffen landen dort
  (Lager voll: nach Hause). Bedienung: Waffe im Lager antippen, dann den
  Halter -- tauscht, die alte Waffe kommt ins Lager. Ohne Auswahl baut ein
  Halter aus. Unpassende Halter sagen warum (SlotRules).
* **Ende des Laufs** (gewonnen, verloren, aufgegeben): alles, was mehr im
  Lauf ist als beim Start (Lager oder eingebaut), geht nach Hause.
  Mitgenommene Ausruestung wird nicht verdoppelt, auch nicht beim
  vorzeitigen "Nach Hause".
* Ein neuer DROME aus der Belohnung kommt weiter in den Squad oder nach Hause.

### Module und Rezepte (7. Nov. 2026) -- `ModuleData`, `data/modules.json`
* Module gibt es **nur im Lauf**. Sie stecken im **Waffenhalter**
  (`DromeBuild.modules`: Halter -> Modul-IDs), 3 je Halter, Molok 2
  (`slots_by_body`). Sie gehoeren zum Halter, nicht zur Waffe: wer die Waffe
  tauscht, behaelt sie. Passt die Bedingung nicht (z. B. "nur Fernwaffen" =
  Angriff ab Rw 2), **ruht** das Modul (abgeblendet, mit Grund).
* Im Kampf werden die Aktionen der Waffe als **Kopie** angepasst
  (`ActionData.with_modules`), die PartDB bleibt unberuehrt. Angriffstempo,
  Schaden und Reichweite nur auf Angriffe; Takt, Statusdauer, Locken auf
  Faehigkeiten. Werte des Traegers (DEF, Schild, Stacheln, frueheres
  Schildladen) stehen in `DromeBuild.stats()`.
* Grundmodule (vorlaeufig; Stand 7. Nov., Umbau 8. Nov. unten): Angriff -- Schnellfeuer, Langer Lauf,
  Doppellauf (je Fernwaffe), Wuchtkante (Nahkampf); Abwehr -- Panzerplatte,
  Kondensator, Stachelgitter; Taktik -- Taktchip, Verstaerker, Koedersender
  (die Faehigkeit lockt ihr Ziel 3 s auf den Traeger, Status `taunt`).
* Vier Rezepte (Summe der Zutaten + eigener Effekt): **Gunslinger**
  (Schnellfeuer + Langer Lauf + Doppellauf; jeder 5. Angriff trifft dazu den
  schwaechsten anderen Gegner irgendwo), **Bollwerk** (Panzerplatte +
  Kondensator; Schild laedt nach 2 s Ruhe), **Taktgeber** (Taktchip +
  Verstaerker; nach der Faehigkeit sofort geladen), **Raufbold** (Wuchtkante
  + Stachelgitter; +15 % Angriffstempo). Zusammengefuegt wird im Lager
  (Rezeptbuch im Zwischenstopp, aufklappbar).
* ~~Beute: je Sieg ein Grundmodul~~ -- seit 8. Nov. nur noch im **Laden**
  (unten). Module teilen sich die 8 Lagerplaetze, lassen
  sich verkaufen (2 / 6 Credits), aber **nicht nach Hause** schicken; am
  Ende des Laufs verfallen sie.
* Bedienung im Zwischenstopp: Modul im Lager antippen, dann den Halter;
  ein Modul-Chip am Halter antippen nimmt es zurueck ins Lager. Chips
  (`ModuleChip`): Farbe UND Zeichen je Klasse (Spitze Angriff, Bogen Abwehr,
  Punkt Taktik), zwei Buchstaben, Rezepte mit doppeltem Rand.
* **Eigene Symbole** (Wunsch des Spielers, 7. Nov.): `assets/modules/<id>.svg`
  (64x64, transparent) ersetzt im Chip Zeichen und Buchstaben. Platzhalter
  fuer alle 14 Module liegen dort, Uebersicht `docs/modul_symbole.png`,
  Anleitung `assets/modules/README.md`. Fehlt eine Datei, bleiben die
  Buchstaben.
* Gemessen (je 100 Kaempfe, Standard-Squad gegen sich selbst ohne Module):
  ohne 56:44; Vireo mit Gunslinger 84:16, mit den drei Zutaten einzeln
  75:25; Strix Gunslinger 81:19; Molok Bollwerk + Raufbold 81:19; Nimbus
  Taktgeber 85:15; je DROME ein Grundmodul 80:20. Module machen also einen
  deutlichen Unterschied -- die Gegnerkurve ist noch nicht darauf
  eingestellt (Gegner tragen keine Module).
* **Rezepte nur einmal je Halter** (8. Nov. 2026, Gutachten): dasselbe
  Rezept-Modul passt kein zweites Mal in denselben Halter, auch nicht als
  Teil eines anderen (`RunState._recipe_twice`, `ModuleData.parts()`);
  Grundmodule stapeln weiter.
* **Umbau 8. Nov. (6i):** Taktchip ist ein Rezept (Zeiger + Schaltkreis, neue
  Grundmodule; Zeit-Takt 20 %), Taktgeber = Taktchip + Verstaerker (Rezept
  als Zutat). Raufbold: Vergeltung (`retaliation`, `Unit.retaliation_stacks`,
  aufgeladen in `ActionResolver._thorns`, entladen in
  `AIController._attack_modules`). Neues Rezept Rundumschlag (Wuchtkante +
  Koedersender, `cleave`). Symbole fuer Zeiger, Schaltkreis, Rundumschlag.
* **Messwerkzeug** `tools/playtest/module_bench.gd -- 400 "Vireo=mod_a+mod_b"`:
  Squad mit Modulen gegen sich selbst ohne, je Seed beide Seiten (400 Seeds =
  800 Kaempfe). 1000 Spiegelkaempfe ohne Module: 483:517 -- kein Seitenbias,
  die 56:44 oben waren Zufall bei nur 100 Kaempfen.
* Entscheidungen nach den Gutachten (Laden statt Modul-Beute, Gegner-Module,
  Gebietsnamen): `NEUANFANG.md` Abschnitt 6i.

### Neues Modulsystem und BIOS (9. Nov. 2026)

> Ueberholt durch die Amps (20. Nov. 2026); was weiter gilt, steht in
> `docs/MODULE_AMP_FUSION.md` Abschnitt 6.

* **Module:** 9 Grundmodule (wirken auf jede Waffe) und 18 Rezepte aus genau
  zwei verschiedenen Zutaten, jedes Grundmodul in genau 4 Rezepten, keine
  Ketten. Feste Zahlen in `modules.json` -> `rules`. Nicht stapelnde Werte:
  `ModuleData.MAX_KEYS` / `MIN_KEYS`. Markierung als Status `mark`
  (`ActionResolver.mark`), Taktchip als Zaehler 1,25 (`Unit.takt_step`,
  `takt_due`). Die Abschnitte "Module und Rezepte" und "Laden" unten sind
  damit in Teilen ueberholt (Langer Lauf, Kette, Zeiger, Schaltkreis weg).
* **Lauf:** Waffen sind fest. Beute-Teile gehen in die **Tasche**
  (`RunState.bag`), das Lager haelt nur Module und BIOS. Laden: 3 Angebote,
  Neuwuerfeln (2 Credits, +1 je Wurf), Ziel-Rezept im Rezeptbuch, ab Runde 5
  gelegentlich ein fertiges Rezept; kein Sperren.
* **Matrix-BIOS:** nach Elite-Siegen (nicht nach dem letzten Kampf) 1 aus 3
  statt des Teils (`roll_bios_offers`, `choose_bios`). Chassis-BIOS am DROME
  (`DromeBuild.chassis_bios`, `bios_slot`), Rezept-BIOS im Rezeptbuch
  (`bios_recipes`), hoechstens eins je DROME. Abweichung vom Konzept: Molok-
  BIOS lockt 1 Feld weiter statt "abgefangener Schaden zaehlt als Treffer"
  -- das tut er schon ohne BIOS. Festung-BIOS (Bollwerk) noch nicht gebaut.
* **Gemessen (9. Nov., je 200 Spiegelkaempfe, Squad mit Modul gegen sich
  ohne; Rauschen etwa +-7 Punkte):**
  * Grundmodule (Ziel: je Chassis hoechstens +-3 Punkte auseinander):
    Molok Stachelgitter **74 %**, sonst 46-54. Strix Schnellfeuer 68,5,
    Wuchtkante 67,5 (Power 15), Verstaerker 59. Nimbus Verstaerker 59,
    Schnellfeuer / Kondensator 56,5. Vireo Schnellfeuer 58,5. Doppellauf
    und Koedersender fast wirkungslos (48-53).
  * Rezepte gegen ihre zwei Zutaten lose (Ziel +5 bis +8): zu stark --
    Nimbus Taktchip 92 / 62,5, Strix Gunslinger 90 / 74, Nimbus Gabelung
    78,5 / 62, Molok Entladung 82 / 70,5, Vireo Zielsucher 71,5 / 60,5,
    Molok Raufbold 86 / 76, Brandmarke 90,5 / 82,5. Ohne Gewinn: Bollwerk
    50,5 / 50,5, Rundumschlag 51 / 51, Splitterpanzer 73 / 73,5,
    Kettenreaktion (Strix 54,5 / 54,5), Ueberladung Nimbus 62 / 62,
    Schutzimpuls Molok 52 / 50,5. Im Rahmen: Strix Zielsucher 74,5 / 69,
    Ueberspannung 73,5 / 69,5, Vireo Gunslinger 58 / 55,5, Taktchip
    61,5 / 59, Rammbock 57 / 53, Fesselkette 55 / 51, Orbit 57,5 / 55,5.
  * Werkzeug: `module_bench.gd -- 100 base` bzw. `recipes`.
  * **Balancing Runde 1** (freigegeben, 9. Nov.): Stachelgitter 1 (+2 Nah),
    Taktchip Zeit-Takt 10 %, Gunslinger jeder 6., Gabelung 35 %, Doppellauf
    35 %. Nachgemessen: Molok Stachelgitter 74 -> 64,5, Raufbold 86 -> 79,5,
    Entladung 82 -> 73,5, Brandmarke 90,5 -> 89; Strix Gunslinger 90 -> 81,5
    (Zutaten 75,5); Nimbus Gabelung 78,5 -> 74,5 (61,5); Vireo Gunslinger 59
    (54); Doppellauf Vireo 50,5, Strix 55.
  * **Messfehler des Spiegels:** Nimbus Taktchip bleibt bei 91 %. Gegenprobe:
    Zeit-Takt 0 % -> 60 %, 5 % -> 85 %. Schon ein minimal frueherer Vortex
    entscheidet den Spiegelkampf, weil beide Nimbus sonst exakt gleichzeitig
    ausloesen. Das misst den Gleichtakt, nicht die Staerke -- Abhilfe waere
    ein kleiner Zufallsversatz der Takte zu Kampfbeginn (offen, mit dem
    Spieler zu besprechen).
  * **Zufallsversatz gebaut** (freigegeben 9. Nov.): `realtime.start_jitter`
    0,5 s, Waffen und Zeit-Faehigkeiten je DROME (nicht Ereignisse wie das
    Hologramm). Nachmessung: Nimbus Taktchip bleibt 91 % (lose 64,5),
    Brandmarke 90,5 (74,5), Raufbold 84,5 (69), Stachelgitter 63, Strix
    Gunslinger 86,5. Gegenprobe mit 3 s Versatz: Taktchip 75 / 67 -- es
    entscheidet, wer den ERSTEN Vortex zuendet, nicht der Gleichtakt. Offen:
    Zeit-Takt-Module nur fuer die Wiederholungen, der erste Ausloeser zur
    Grundzeit (Vorschlag an den Spieler).

### Takt nur noch ueber Angriffe (9. Nov. 2026, Vorgabe des Spielers)
* Kein Zeit-Takt mehr: Vortex (Runenstab) jeder 3. Angriff (mit Echo jeder
  4.), Orbit-Sog jeder 4. Angriff der Waffe im Halter (`mount["extras"]`,
  `AIController._tick_extras`). Taktchip nur noch Zaehler 1,25, ohne
  Zeit-Anteil. Hintergrund: beim Zeit-Takt entschied, wer den ersten Vortex
  zuendet (Taktchip 91 %). Die Zeit-Logik im Code bleibt fuer Altdaten,
  wird aber von keinem Teil mehr genutzt.
* Gemessen danach (je 200 Kaempfe, Rezept / lose Zutaten): Nimbus
  Taktchip 90,5 / 71 -- jetzt echt stark, weil der Zaehler 1,25 den Vortex
  (staerkste Faehigkeit) gut 25 % haeufiger macht; Gabelung 82,5 / 72,5;
  Orbit 58,5 / 56,5. Molok Brandmarke 90,5 / 76, Raufbold 79,5 / 68; Strix
  Gunslinger 82,5 / 75. Entscheidung des Spielers: Taktchip bleibt,
  Balancing erst nach einem groesseren Playtest (auch nach Gefuehl).
* **Orbit-Fokus neu** (Spieler, 9. Nov.): kein Sog mehr, sondern das Ziel
  der Faehigkeit ist 2 s gewurzelt (`root`, `Unit.is_rooted`): greift an,
  laeuft aber nicht. Gravitation-BIOS wurzelt dazu den naechsten Gegner am
  Ziel. Der Orbit-Sog (`act_orbitpull`) ist entfernt.

### Playtest-Runde (10. Nov. 2026, Wunsch des Spielers) -- PR #55
Ausloeser: das Playtesten machte keinen Spass (Bedienung hakelig, Aufstellung
auf einem Haufen, Kampfwert unplausibel, gewuerfelte Gegner, kein Start mit
Spielstand). Vorschlaege zu Story, Fraktionen, Klassen und Anstieg stehen in
**`docs/VORSCHLAG_STORY.md`** -- nichts davon ist entschieden.

* **Aufstellung am Kartenrand** (`MapGenerator.deployment_zone`,
  `default_formation`): ein Streifen 3 x 8 an der Kante (Spieler unten links,
  Gegner oben rechts) statt 3 x 5 mitten im Feld; ohne Zutun nach Rolle
  gestaffelt und ueber die Breite verteilt, beide Seiten spiegelgleich.
  Ziehen greift die FIGUR unter dem Finger (vorher das Feld -- bei
  ueberlappenden Figuren die falsche), das Zielfeld leuchtet; dazu Antippen
  (Figur, dann Feld). Zone als einzelne Kaestchen (`BattleView.ZonePainter`).
  Gemessen (200 Spiegelkaempfe): 91:109, erster Treffer nach 5,6 s statt
  2,0 s, Dauer 32 s statt 23 s. Stellschraube: `deployment.inset`.
* **Kampfwert neu** (`DromeBuild.power_score/power_parts`): Wurzel aus
  Standhaftigkeit (Integritaet mal Ruestungsfaktor + 3 x Schild + Reparatur)
  mal Feuerkraft (Schaden je Sekunde mal Reichweite, dazu Betaeubung,
  Stacheln); 100 = Schnitt der Standard-DROMEs. Standard: Strix 146,
  Nimbus 109, Vireo 74, Molok 71. An 2500 Kaempfe angepasst, an 1500 und
  nochmal 3000 anderen geprueft: der hoehere Wert gewinnt in 80 % (alt 65 %),
  bei ueber 25 % Abstand in 93-94 %. Siegchance nach Verhaeltnis Gegner/eigen:
  0,6-0,8 -> 89 %, 0,8-0,95 -> 72 %, ~1 -> 50 %, 1,05-1,2 -> 25 %,
  1,2-1,4 -> 10 %. Werkzeug: `tools/playtest/power_bench.gd -- 3000`.
  Grenze: kein Zusammenspiel -- der Molok ist allein wenig wert und macht
  den Strix dahinter erst stark.
* **Gegner handverlesen** (bis 14. Nov. 2026 `data/encounters.json`, seither Formationen): kein
  Wuerfeln mehr ausser im Chaos-Kampf. Je Team feste DROMEs mit Namen, Waffen
  und Modulen (in Listenreihenfolge nach Runde/Stufe, ab Runde 5 vorn das
  Rezept) und ein **Gegnertyp** (Sturm, Schuetzen, Bollwerk, Kontrolle,
  Gemischt). Eigene Elite-Teams je Fraktion. Runde 1-2 sind **Training**
  gegen normale DROMEs (`run.training_rounds`). Die Teams sind ein Vorschlag;
  `tests/test_encounters.gd` prueft, dass jedes baubar ist.
* **Gegnerwahl** (`RunState.row`, ersetzt die Karte mit Wegen): immer ein
  Leichter, dazu zwei Normale mit verschiedenen Gegnertypen ODER ein Normaler
  und ein Elite. Elite-Chance 35 %, je gewaehltem Elite +12 Punkte (bis 85 %).
  Alle Knoten stehen zur Wahl; die Vorausschau zeigt die Reihe, die nach der
  aktuellen Wahl kaeme. Die Wege entfielen, weil "immer ein leichter Kampf"
  sonst nicht zu halten war.
* **Chaos-Virus als eigener Modus entfernt** (Bildschirm, `ChaosLoot`, Pity,
  Handicap). Chaos ist ein Knoten im **Endlos-Modus** (`mode = "endless"`):
  gewuerfelte DROMEs, Waffen und Module ohne Profil, Beute wie Elite.
* **Endlos-Modus** nach `NEUANFANG.md` 6h: kein Ende, ein Leben, eine
  Niederlage kostet die Beute, nach jeder Runde aussteigen
  (`RunState.cash_out`). Frei nach dem ersten Sieg in Neon City
  (`GameState.progress`) oder per Testschalter in den Optionen. Der Anstieg
  nach Runde 8 (`run.endless`) ist ein Platzhalter.
* **Drei Spielstaende** (`GameState.select_slot`, `scenes/saves.tscn` als
  erster Bildschirm): je Ordner `user://slotN/` Hangar, Lauf, Fortschritt;
  ein alter Spielstand zieht in Spielstand 1. Wechseln in den Optionen.
* **Touch repariert** (`Accessibility`): die Wisch-Scroll-Logik verschluckte
  nach 12 Pixeln jedes Loslassen -- ein gezogenes Teil kam nie an und blieb
  am Bildschirm haengen. Jetzt hat ein laufender Zug Vorrang, gescrollt wird
  nur entlang der Liste, und die Liste unter dem Finger wird nach ihrer Lage
  bestimmt (nicht nach dem zuletzt ueberfahrenen Control). Im Browser als
  Pixel 7 nachgestellt.
* **Optik**: gemeinsames Theme (`UiKit.theme`) fuer Standard-Knoepfe,
  Eingabefelder, Schalter, Rollbalken; rundere Karten mit Schatten, die
  Hauptaktion leuchtet, die Tab-Leiste zeigt die aktive Seite, der Umbau
  steht in einer Karte. Im Lauf sitzt die Hauptaktion fest am unteren Rand.
* **Neu im Testlauf**: `tests/test_scripts_compile.gd` laedt jedes Skript und
  jede Szene (ein Tippfehler in einem Bildschirm blieb sonst unbemerkt);
  `tests/smoke_ui.gd` baut auch Spielstaende, Menue, Gegnerwahl und Kampf.
* Gemessen (`run_bench.gd -- 60`, Standard-Squad ohne Module und Level):
  Leicht 100 %; Normal 97 / 80 / 63 % in Runde 3 / 5 / 8; Elite 55 / 32 / 41 %.
* **Noch nicht gebaut:** die Level-Struktur des Story-Modus (zehn Level,
  Training mit 2 und 3 DROMEs), eigene Fraktions-Chassis, Bosse, bessere
  Beute im Endlos-Modus. Vorschlaege dazu in `VORSCHLAG_STORY.md`.

### Komfort und Lauf (10. Nov. 2026, Wunsch des Spielers)
* **Haptik:** `Accessibility.vibrate` (gedrosselt, Schalter in den Optionen)
  bei schweren Treffern auf eigene DROMEs, Abschuessen, Kampfende, Einbauen,
  Kaufen, Verschmelzen.
* ~~**Bester Aufbau:** Knopf im Umbau und im Squad-Reiter~~ -- am selben Tag
  auf Wunsch des Spielers wieder entfernt (Knopf, `Roster.best_loadout`).
* **Umbau neu geordnet** (Wunsch des Spielers nach dem ersten Test am
  Handy): oben FEST die DROME-Auswahl und die Karte des DROME, seine Halter
  stehen in der Karte direkt unter dem Bild. Darunter eine waagerechte
  Leiste nur mit Teilen, die frei sind und in diesen DROME passen (keine
  ausgegrauten Kacheln mehr, `_parts_strip`, `_slots_taking`). Eine Kachel
  nach oben auf einen Halter ziehen baut ein -- die Seite scrollt dabei
  nicht mehr mit (waagerecht blaettert die Leiste). Das Teilebild bleibt in
  seiner Form (`SlotShape.inner_rect`; Dreieck und Fuenfeck fuellen ihr
  Feld). Die Waffen-Karte zeigt hinter jedem Symbol einen Balken mit Wert --
  Schaden, Tempo, Reichweite, Faehigkeit --, beim Einbauen im Vergleich zur
  Waffe im Halter (`WeaponCard.attack_bars`, `StatBar.custom`).
* **Halter ohne Richtung** (Wunsch des Spielers): "links" und "rechts"
  stehen nirgends mehr. Unter dem Halter steht nur seine Klasse; im Text
  heisst er "Halter", beim Molok "Halter 1" / "Halter 2"
  (`SlotRules.holder_label`).
* **Vergleichsbalken:** `StatBar` statt nackter Zahlen im Hangar, beim
  Waffentausch vorher -> nachher in einem Balken.
* ~~**Ziehen auf Halter**~~ -- **seit 15. Nov. 2026 entfernt** (Wunsch des
  Spielers): kein Drag & Drop mehr in den Menues. Hangar und Zwischenstopp
  laufen nur noch ueber Kacheln (tippen waehlt, nochmal tippen = Details,
  Doppeltipp = einbauen/ausbauen). Die Halter im Umbau werden ebenso bedient
  (`Tile.click`). Die Aufstellung vor dem Kampf (Figur ziehen) bleibt.
* **Spielstand:** `save_enabled` an; Hangar in `user://roster.json`, Lauf in
  `user://run.json` (`RunState.to_dict/from_dict`, `DromeBuild.to_save`),
  nach jeder Aenderung geschrieben. "Lauf fortsetzen" im Hauptmenue,
  "Spielstand zuruecksetzen" in den Optionen. Tests/Werkzeuge beruehren den
  Spielstand nie (`GameState._is_tool_run`).
* ~~**Karte wie bei FTL** mit Wegen (`RunState.map_layers`)~~ -- am selben
  Tag ersetzt durch die Reihe ohne Wege (`RunState.row`, siehe
  "Playtest-Runde" oben). `MapView` zeigt weiter die Reihe dieser Runde und
  die naechste als Vorausschau.

### Fraktionen und Profile (9. Nov. 2026) -- `data/regions.json` -> `faction`
* Jedes Gebiet hat eine Fraktion mit Profil: Neon City / Neon Ninja's =
  Kaempfer (Vireo, Klingen, Haemmer, Rammen; Rundumschlag, Raufbold,
  Ueberladung), Parkanlage / Solar Sentients = Rudel (Vireo, Nimbus,
  Blaster, Runenstab, Bumerang; Gabelung, Kettenreaktion, Zielsucher),
  Factory 5 / Mega Mechas = Festung (Molok, Strix; Hammer, Deflektor,
  Ramme, Moerser; Rammbock, Brandmarke, Bollwerk). Hipstar Hackers offen.
* Wirkung: Gewichte beim Wuerfeln der Gegner (`EnemyGenerator.profile`,
  `_pick_weighted`) und bei ihren Modulen (`RunState._arm_enemies`,
  `module_weight`). Die Vorschau zeigt Fraktion, Profil und einen Satz.
* Grenze: der Generator waehlt ganze Squads nach der Zielstaerke, das zieht
  bei allen Fraktionen viele Moloks (hoher Kampfwert). Gemessen ueber 25
  Laeufe: Mega Mechas 97 Molok / 80 Strix, Neon Ninja's 95 Molok / 18 Strix
  / 100 Vireo. Die Waffen unterscheiden sich deutlich. Staerker getrennt
  wird es mit eigenen DROMEs je Fraktion.
* Noch nicht: Lage-BIOS (brauchen die Profile), Endlos-Modus mit
  gewuerfelten Profilen, eigene Fraktions-DROMEs.

### Neue Waffen und freie Arme (9. Nov. 2026)
* **Bollwerk-Ramme** (`eq_bulwark_ram`, mittel, bot2): Rw 1, 10 alle 1,6 s;
  jeder 3.: Rammstoss +8 % der eigenen max. Integritaet (`hp_scaling`, ohne
  Power), stoesst 1 Feld zurueck. Bonus Integritaet 20 -> 40.
* **Moerser** (`eq_mortar`, schwer, bot4, Schultermoerser): Rw 6, mind. 2
  (`min_range`), Flaeche r1, 14 alle 2,8 s, 0,8 s Verzoegerung; jeder 3.:
  Sperrfeuer r2 mit Rueckstoss. Bonus Ruestung 2 -> 4.
* **Klingenbumerang** (`eq_boomerang`, leicht, bot1): Rw 2, 2 x 6 alle 1,3 s,
  +30 % in Bewegung (`moving_bonus`, `Unit.MOVING_WINDOW` 1 s); jeder 3.:
  Wirbelwurf r1. Bonus Speed 1 -> 2.
* Formen in `tools/build_sample_parts.py` (EQ_BULWARK_RAM, EQ_MORTAR,
  EQ_BOOMERANG), Silhouetten-Pruefung bestanden. Alle Werte Startwerte,
  noch ungemessen.
* **Freie Arme** fuer Vireo und Nimbus am rechten (nicht nutzbaren) Anker,
  fest im Chassis (SCOUT_BODY, MAGE_BODY); der Nimbus haelt einen
  Arkanfunken.
* Hinweis: der Generator ist nicht byte-gleich mit dem Stand im Repo
  (gleich tiefe Flaechen in anderer Reihenfolge, optisch gleich) -- nur die
  geaenderten Teile einchecken.

### Laden (8. Nov. 2026) -- `RunState.roll_shop/buy`, `modules.json` -> `shop`
* Im Zwischenstopp oben, unter den Credits: **2 Grundmodule** je Stopp
  (`shop.offers`), keines doppelt, Preis **6 Credits** (`shop.price.base`;
  `recipe` 16 steht fuer spaeter bereit, angeboten werden nur Grundmodule).
  Gekauft wird ins Lager; gesperrt mit Grund (zu wenig Credits, Lager voll,
  verkauft). Jedes Angebot zeigt, fuer welche Rezepte es Zutat ist.
* **Unsichtbares Mitleid**: ein Grundmodul, das einem angefangenen Rezept
  fehlt (eine Zutat liegt im Lager oder steckt im Halter), kommt dreimal so
  oft (`shop.recipe_weight`, `RunState.recipe_missing`).
* Gewuerfelt beim Betreten des Zwischenstopps aus Lauf-Seed und Runde,
  geleert beim Weitergehen. Module gibt es nicht mehr als Beute.
* Preise vorlaeufig: ein normaler Sieg (10) kauft ein Modul, ein Elite-Sieg
  (16) zwei; Verkauf bringt 2.

### Gegner mit Modulen (8. Nov. 2026, 6i) -- `RunState._arm_enemies`
* Zahl je Gegner nach Runde (`run.enemy_modules.by_round` 0,0,1,1,1,2,2,2)
  plus Stufe (Leicht -1, Elite +1), hoechstens so viele, wie der Halter
  fasst. Handverlesen: nur Module, die zur Waffe passen (keine ruhenden),
  keines doppelt; ab Runde 5 mit mindestens zwei Plaetzen ist eines ein
  passendes Rezept. Alles im Halter der ersten Waffe, am Kampf-Seed --
  Vorschau und Kampf sind dieselben. Die Vorschau zeigt "Module: ...".
* Messwerkzeug `tools/playtest/run_bench.gd -- 30`: Standard-Squad (ohne
  Beute, ohne Module) gegen die Lauf-Gegner, mit und ohne deren Module.
  Gemessen (30 Laeufe je Feld, Siege mit / ohne Gegner-Module):

  | Runde | Leicht | Normal | Elite |
  |---|---|---|---|
  | 1 | 30 / 30 | 29 / 29 | 13 / 16 |
  | 3 | 30 / 30 | 21 / 22 | 13 / 20 |
  | 5 | 30 / 30 | 17 / 20 | 2 / 10 |
  | 8 | 29 / 29 | 7 / 18 | 6 / 12 |

  Lesart: Leicht bleibt leicht, Normal wird spaet deutlich haerter -- der
  Spieler hat dann aber selbst Module (Laden) und Beute. Die feste Kurve
  (`power_growth`) gilt weiter; laut 6h soll sie spaeter durch Level/
  Waffen/Module ersetzt werden.

### Werte, Identitaeten, Level (8./9. Nov. 2026) -- `docs/IDENTITAETEN.md`
* Ein DROME hat nur noch Speed, Integritaet, Schild, Schildpuls, Ruestung,
  Halter, Power und Modulplaetze -- alles am Chassis. ATK und Gewicht sind
  gestrichen. Power skaliert den Waffenschaden (`Unit.raw_damage`),
  Schildpuls regelt Ruhezeit und Ladung (`Unit.recharge_shield`).
* Jede Waffe gibt einen DROME-Wert als Bonus, Faehigkeitsschaden ist ein
  Anteil des Waffenschadens (`damage_pct`). Hammer und Schild mittel, schwer
  nur die Schienen-Lanze; Vireo nur leicht, Molok zwei Halter bis mittel.
* Strix-Passive Anlegen (`steady`, `Unit.track_stillness`) -- seit 27. Nov. 2026 ersetzt durch Focuslense.
* Orbit-Fokus, Hologramm-Boost, Koedersender sind keine Ausruestung mehr,
  sondern Module (`gadget` in `modules.json`).
* Level (`Leveling`): DROME 0-5, Waffe 0-10, gespeichert an `RosterEntry`
  und `PartInstance`. EP (9. Nov.): DROME je Sieg 40 x Stufe x Runde, Level
  kosten 100/200/300/400/500; Waffe 0,25 je Schadenspunkt + 25 je Abschuss,
  Level 1-5 schnell, 6-8 mittel, 9-10 langsam. Gesammelt im Lauf
  (`RunState.pending_xp`), gutgeschrieben am Ende zuhause.
* Gegner-Level (Leitplanke, `run.enemy_levels`): DROME 0-2, Waffen 0-3 ueber
  die acht Runden, Leicht -1, Elite +1/+2. Messung: `run_bench.gd -- 20 0 0`
  (frisch) bzw. `-- 20 2 3` (erfahren), Tabelle in `IDENTITAETEN.md`.
* Effekte (9. Nov.): Einschlag Ring (Energie) / Funken (kinetisch),
  Nahkampf ohne Projektil, Projektil matt oder leuchtend nach Schadensart,
  Blaster gerader Schuss, Lanze Geschoss, Runenstab Energiekugel,
  E-Schraubenschluessel (frueher Drohnen-Pod) Heilstrahl und Energiekugel
  (`BattleView.show_attack`, `BattleScreen.attack_style`).

### Chaos-Virus
* ~~Eigener Modus mit Bit-Auswahl, Handicap und Pity~~ -- entfernt am
  10. Nov. 2026. Chaos ist ein Knoten im Endlos-Modus (siehe
  "Playtest-Runde").

### Startbestand
* Neuer Spielstand: jeder der vier Standard-DROMEs einmal in voller
  Standardausstattung, **alle vier im Squad** (`Roster.seed_starter`).

### Hangar -- `scripts/ui/hangar_screen.gd`
* Reiter **Squad** (7. Nov. 2026 nach Wunsch des Spielers): oben der
  gewaehlte DROME als grosse Box, darunter ALLE DROMEs genau einmal als
  Kacheln (Squad zuerst, gruen umrandet, ">>" oben links). Plus/Minus oben
  rechts in der Kachel nimmt in den Squad auf oder heraus. Vorher stand der
  Squad doppelt da (eigene Reihe oben). "Neuen DROME bauen" darunter.
* Reiter **Umbau** (7. Nov. 2026 entschlackt): DROME-Auswahl (Squad zuerst,
  ">>"), Bild + Werte, Halter als Formen mit Klasse darunter. Die lange
  Halter-Karte ist weg. Ein Waffenbild antippen -- im Halter oder als
  Kachel -- oeffnet die **Waffen-Karte** (`WeaponCard`): oben links das
  Bild, rechts die Werte als Symbole (`StatIcon`: Schwert kinetisch, Kugel
  Energie, Doppelpfeil Tempo, Pfeil Reichweite, Fadenkreuz Angriff, Blitz
  Faehigkeit, Uhr/Zahnrad Takt nach Zeit/Angriffen, Gewicht), darunter
  Faehigkeitsname und Kurzbeschreibung. Ein Symbol antippen zeigt seinen
  Klartext in der Hinweiszeile. Dazu "Einbauen" (mit Wertaenderung) bzw.
  "Ausbauen". Dieselbe Darstellung im Zwischenstopp. "DROME aufloesen" unten.
* **Halter-Formen** (`scripts/ui/slot_shape.gd`): Dreieck = leicht,
  Viereck = mittel, Fuenfeck = schwer, Kreis = Kern. Ausruestung traegt
  dieselbe Form wie ihre Klasse. Regel: leicht passt nach oben in groessere
  Halter, schwer nur in schwer -- das stand schon in `PartData.accepts()`
  (`max_class` je Halter), jetzt ist es sichtbar. Zusatzregel: die
  Molok-Schulter nimmt nur leichte **Support**-Teile.
* Halterliste und Absagegruende: `scripts/core/slot_rules.gd`.

### Oberflaeche / Barrierefreiheit -- `autoload/accessibility.gd`, `scripts/ui/ui_kit.gd`
* Entwurfsraum **450x800 hochkant**: 1 Entwurfspixel ~ 1 CSS-Pixel auf dem
  Handy. Skalierung nur noch im Querformat (mind. 0,9 CSS-px je Entwurfspixel,
  logische Flaeche mind. 360x600).
* Mindestschrift 16, Mindest-Knopfhoehe 44 (Touch).
* **Schriftgroesse** (Optionen: Normal/Gross/Sehr gross) skaliert NUR Text
  (Theme + Overrides). Frueher skalierte sie die ganze Flaeche -> Layout
  zerbrach. Gespeichert in `user://settings.json` (Schluessel `font_option`).
* "Animationen reduzieren" (folgt `prefers-reduced-motion`).
* **Wisch-Scrollen** fuer jeden ScrollContainer, mit Schwung; ein Wischer
  loest den Knopf darunter nicht aus.
* **Langes Druecken** zeigt `tooltip_text` jedes Elements (auch vom
  Elternteil); danach werden Klicks kurz verschluckt.
* `UiKit`: `page()` (Rahmen, Kopfzeile, Scroll, Tab-Leiste), `button()`,
  `card()`, `label()`, `row()`, `drome_view()`, `chassis_view()`,
  `part_texture()` (zugeschnitten). Tab-Leiste: Spielen · Hangar · Optionen.
* Startseite (neu 9. Nov. 2026, `HomeStage`): Neonschrift CYBERDROME, das
  Tor der Arena von Neon City bei Nacht (Neonbogen ARENA, Suchscheinwerfer,
  Regen, Perspektiv-Boden), davor der eigene Squad auf einem Podest; Karte
  mit Gebiet und Squad. `MenuArena` (zufaellige Kaempfe) ist geloescht.

### Hosting
* Vercel baut mit `tools/build_web.sh` (Godot 4.7 mit Pruefsumme, nur die
  zwei Web-Templates per HTTP-Range ueber `tools/fetch_web_templates.py`).
* GitHub-Workflow `.github/workflows/web.yml` baut bei PRs und deployt auf
  Pages bei `main` (Pages muss im Repo aktiviert sein).
* PWA: Ausrichtung beliebig, Service Worker; nach einem Deploy auf dem Handy
  ggf. einmal neu laden.

---

### Charger, Caches oeffnen, Hangar-Upgrade (20. Nov. 2026)

Nach dem Design-Canvas „CyberDrome Charger & Hangar“
(https://claude.ai/artifact/FJpqxTaHcbXsPTU619YC1e, vom Spieler abgesegnet) und
`docs/CHARGER_KONZEPT.md` gebaut:

* **Daten** (`Charger`, `Roster`): Energy Phases (`materials["phase:<element>"]`),
  Charger-Rohlinge (`materials["rohling"]`), Charger als Gegenstand (`roster.chargers`,
  `craft_charger`, `mount_charger` am Waffen-Exemplar), `DromeBuild.chargers`
  (bleibt im Lauf-Spielstand). Werte in `config.json -> charger`.
* **Kampf** (`ActionResolver._charge`): 20 Belastung je Phase und Treffer, ab 100 ein
  Stapel (`Unit.add_element_load`). Ueberwiegendes Element: die Faehigkeit legt einen
  Stapel direkt an. Resonanz 2/4/6 zaehlt zusammen (Spieler im Canvas): Stufe 2 Faehigkeit
  +100, 4 jeder 5. Treffer doppelt, 6 jeder 3. doppelt und Faehigkeit +200. Wirken tut
  nur Feuer (Kabelbrand); die anderen Elemente werden gezaehlt (`Unit.element_stacks`).
* **Caches oeffnen** echt: vier Wuerfe (`Roster.open_cache`), Energiebaelle fliegen in die
  Ergebnis-Felder. Caches neu als Hex-Container je Fraktion (`CacheArt`). Der **Neon Cache**
  ist eine 3D-Szene als Shader (`assets/shaders/neon_cache.gdshader`, Raymarching, Parameter
  `open` 0..1 fuer den Oeffnen-Ablauf). Farben im Shader linear (sonst wirkt es blass).
* **Shop › Bauen**: Charger-Crafter (`ChargerCrafter`) nach der Skizze des Spielers
  (`docs/design/charger/skizze_spieler.jpg`): ziehen, antippen + Feld, Doppeltipp.
* **Hangar**: Reiter Umbau | **Upgrade** (Charger in Waffen); der Squad-Reiter ist raus,
  sein Code bleibt bis zum Assembler-Modus. `HangarScreen.open_tab`, `ShopScreen.open_tab`.
* **Einsatzvorbereitung**: Aufklaerung (`EnemyIntel`) -- Formationen der Fraktion mit
  DROMEs (Sechseck) und Sentinels (Quadrat), Rollen-Bilanz, Hinweis.
* Bausteine: `PhaseGem` (Hex-Kristall), `ChargerHex`, Symbole `phase_*.svg`, `hammer.svg`,
  `charger.svg`; Farben `phase-*` im SPOT-Blatt Design.
* Offen (SPOT): Wirkung der uebrigen Elemente, Kabelbrand am Bumerang (Uebergang),
  Charger am DROME statt an der Waffe?, Amps (nur Entwurf).

### Module v3: Amps, Fusionen, Hyperfusionen (20. Nov. 2026)

`docs/MODULE_AMP_FUSION.md`, Daten in `data/modules.json`:

* **6 Amps** (`modules`): Attack +10 % Angriffstempo, Power +1, Integrity +10 % max.
  Integritaet (`hp_pct`), Shield +10 % max. Schild (`shield_pct`), Armor +3, Tech +2
  Effizienz -- in `DromeBuild.stats()`.
* **15 Fusionen** (`recipes`, jedes Paar zweier verschiedener Amps): Heilverstaerker
  (`support_power`) und Raufbold entschieden, 13 Vorschlaege; neu Lebensraub (`lifesteal`).
* **6 Hyperfusionen** (`hyperfusions`): zwei gleiche Amps + **Fusion Core** (`items`),
  dreifacher Wert; Power: 20 % **Virusschaden** (`virus_fraction`, in
  `ActionResolver.resolve_damage` an Panzerung und Schild-Faktoren vorbei, Schild zuerst).
  Hoechstens eine je DROME (`RunState.has_hyper`), jede Sorte einmal je Einsatz
  (`RunState.hyper_made`, im Spielstand). Fusion Core selten im Laden (`shop.core_chance`).
* BIOS bleibt fuer die erhaltenen Fusionen (Taktgeber, Berserker, Treibjagd, Abrissbirne,
  Phasenbruch). Gegner-Profile (`regions.json`) und Sentinel-Module (`formations.json`) auf
  Amps umgestellt.
* Kartuschen (`ModuleChip`): Fusion mit geteiltem Rahmen in den Farben der Amps, Hyperfusion
  dreifach mit Core-Sechseck, BIOS-Fusion mit Matrix-Regen. Symbole `assets/modules/amp_*.svg`.
* `run_bench 20`: Siegquoten praktisch wie vorher.
* Offene Logik: `docs/design/UEBERGABEN_DESIGN.md`, Abschnitt „Offene Logik nach dem Bau“.

### Musik (24. Nov. 2026)

* Zwei BeepBox-Stuecke des Spielers: das dunklere (D, 96 BPM) im Kampf, das hellere (A-Moll,
  128 BPM) auf allen anderen Bildschirmen. Autoload `Music` folgt der aktuellen Szene und
  blendet ueber; Intro (4 Takte) einmal, danach Schleife ab Takt 5 (`loop_offset` im Import).
  OGG statt WAV: 2,4 MB statt 33 MB. Schalter Optionen -> Ton -> Musik. Details und Tausch:
  `docs/musik/LIESMICH.md`.

## 3. Messungen und gefundene Fehler (lohnt sich zu wissen)

* **KI griff abgeschirmte Ziele nie an.** Sie bewertete nur HP-Schaden; ein
  voller Schild (32-33) schluckt jeden Einzeltreffer -> Bewertung 0. Behoben
  mit `ai.shield_damage_weight` (0,7). Vorher endeten Spiegelkaempfe ohne
  einen Punkt Schaden.
* **Seitenfairness** nach dem Fix: 20:20 in 40 Spiegelkaempfen; 0/20
  unentschieden, Schnitt 8,3 Zyklen (`tests/test_autobattle.gd`).
* **KI-Rechenzeit**: ~4 ms je Schritt, max ~13 ms (Desktop). Kein Problem fuer
  Normal/2x; im Browser grob 5-10x langsamer.
* **Start-Squad-Messung** (Runde 1, 14 Kaempfe je Paar): Vireo+Nimbus(Runenstab)
  11/14, Vireo+Nimbus(Puls) 7/14, Vireo+Vireo 1/14, Vireo+Molok(Kanone) 0/14
  -- die Belagerungskanone drueckt den Molok auf SPD 6.
* **Spaetere Runden** mit typischer Beute: 8-11 von 12 gewonnen (Kurve evtl.
  noch zu leicht; Kampfwert `power_score` ist ein grobes Mass).
* Der Gegnergenerator kommt fuer 2 Gegner nicht unter ~340 Kampfwert.
* Bekannte Glyphen-Luecken der Standardschrift: kein Pfeil "→", kein "⟳"
  (zeigt Kaestchen) -- "->" bzw. gezeichnete Formen benutzen.

## 4. Bekannte Schwaechen / Altlasten

Stand 26. Nov. 2026 (nach dem Aufraeumen):

* **2D-Zusammenbau** (`DromeSprites`) lebt nur noch fuer Tests und den
  Bench-Bildschirm; im Spiel zeichnet `Arena3D`.
* Chronik-Dokumente (`NEUANFANG.md`, `IDENTITAETEN.md`, `GAME_DESIGN.md`)
  sind entruempelt, aber Entwurfsstand; ihr Kopf sagt, was noch gilt.

## 5. Offen -- mit dem Spieler zu besprechen

**Neuentwurf (Nov. 2026): `docs/NEUANFANG.md`** -- Lauf mit verfallenden
Verbesserungen, DROMEs mit Passive und eigener KI, ein Ausruestungsplatz
(Molok zwei), neue Waffen (Plasmaklinge, Hammer), Kerne als Synergie-Teil.
Die Punkte unten gehen darin auf.

Designpunkte (bis zur Entscheidung keine groesseren Umbauten auf eigene Faust):

1. **Faehigkeiten loesen automatisch aus** -- nach Zeit oder nach Treffern,
   statt von der KI gezogen.
2. **Skill-Tiefe ueber Synergien**, nicht ueber Timing ("womit", nicht "wann").
3. **Eingreifen des Spielers** -- offen, spaeter besprechen. Entschieden ist
   nur: **kein Steuern**, es bleibt ein Autobattler. Vermutung des Spielers:
   eine selbst waehlbare Aggro-Liste, der Spieler legt fest, wer
   **Aggro-Platz 1** hat. Er will das noch selbst durchdenken. (Aelterer
   Vorschlag: eine "Overdrive"-Ladung pro Kampf.)
4. **Waffen-Slots und Gewichtsklassen** ueberarbeiten. Die Formen-Darstellung
   (Dreieck/Viereck/Fuenfeck) ist gebaut; die eigentliche Neuverteilung der
   Klassen und Halter steht aus.

Gebaut (Nov. 2026, auf Wunsch des Spielers):

* **Ein Lebensbalken ueber der Figur**: Integritaet und Schild teilen sich
  die Breite nach ihren Hoechstwerten (200/100 -> 2/3 zu 1/3). Eigene gruen
  und blau, Gegner rot und violett (`Teams.hp_color/shield_color`). Kein
  Name, keine Zahl, keine Energie mehr ueber der Figur.
* **DROME-Kacheln** oben unter der Zugreihenfolge (`SquadTiles`): Kopf, Name,
  SPD, HP und Schild mit Zahl. Aktive Kachel hervorgehoben, Antippen faehrt
  die Kamera hin. Die Statuszeile sagt nur noch, wer am Zug ist.
* **Kulissen** (`Ambience`, gezeichnet statt Bilddatei): Neon-Grossstadt
  hinter Startseite, Lauf und Chaos-Auswahl; Sci-Fi-Hangar im Hangar; im Kampf
  je Region (Neon City Neon-Stadt, Parkanlage Ruinen mit Gluehwuermchen,
  Factory 5 Schlote und Smog), mit leichter Parallaxe.
* **Teil-Info im Umbau** (`PartInfo`): "Wie funktioniert das?" am Halter und
  in jeder Teil-Vorschau -- Rolle, Werte, Besonderheiten, jede Aktion mit
  Reichweite, Wirkung, Schadensart und Einsatz.
* **KI**: Fernkaempfer laufen nach dem Angriff nicht mehr in den Gegner,
  sondern suchen ein sichereres Feld in Reichweite (`_settle_step`).

Weitere Vorschlaege aus der Sitzung (unbewertet):

* Kurze Einfuehrung beim ersten Start (drei Hinweise).
* Teile per Ziehen auf Halter (Tippen bleibt).
* Knopf "Bester Aufbau" fuer Einsteiger.
* Werte als kleine Vergleichsbalken statt nackter Zahlen.
* Spielstand speichern (Lauf uebersteht Neuladen).
* Haptik (Vibration bei Treffern/Einbauen).

## 6. Arbeitsweise (fuer die naechste Sitzung)

* **Sprache**: der Spieler schreibt Deutsch; Antworten, Commits und PRs auf
  Deutsch. Code-Kommentare im Repo auf Deutsch ohne Umlaute (ae/oe/ue).
* **Ablauf**: auf dem vorgegebenen Branch arbeiten, Draft-PR oeffnen, der
  Spieler merged selbst. Nach einem Merge den Branch von `main` neu aufsetzen.
* **Pruefen im Browser**: `bash tools/build_web.sh`, dann
  `cd build/web && python3 -m http.server 8766`, mit Playwright
  (`devices['Pixel 7']`, 412x839 CSS, Pixeldichte 2,625) Screenshots machen.
  Tipp-Koordinaten: CSS = Bildpixel / 2,625 (Bild ist 1082x2202).
  Wischen und Pinch per CDP `Input.dispatchTouchEvent`.
* **Headless-Szenentest**: kleines `extends SceneTree`-Skript, das die Szenen
  nacheinander per `change_scene_to_file` laedt (`--fixed-fps 60`) und auf
  `SCRIPT ERROR` prueft. Nach neuen `class_name` erst `--import`.
* `vercel.app` ist aus der Cloud-Sitzung gesperrt (Proxy 403) -- Vorschauen
  muss der Spieler selbst oeffnen.
