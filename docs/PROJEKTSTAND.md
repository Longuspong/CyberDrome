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
  ueber einzelne Zuege. Auch der Chaos-Virus ist immer Autokampf (der
  Schalter ist weg, Nov. 2026 -- vorher stand er auf "aus" und der Spieler
  musste ungewollt selbst steuern). Den manuellen Kampf gibt es nicht mehr.
* **Mobile first, Hochformat ist die Hauptansicht** (Wunsch des Spielers,
  ausdruecklich). Querformat wird angeboten, ist zweitrangig. Ziel-Plattform
  ist das Handy, gehostet als PWA auf Vercel; Android-APK kommt spaeter.
* **Roguelike-Lauf** als zentraler Modus (Hauptknopf "Lauf starten").

## 2. Was gebaut ist (Chronologie)

| PR | Inhalt |
|---|---|
| #26 | Autokampf (KI fuer beide Seiten), Aggro-Tabelle fuer alle, **Schild-Bug der KI behoben**, Overtime, Fairness-Test, PWA-Export + GitHub-Pages-Workflow |
| #27 | Vercel liefert das Spiel statt der SVG-Werkstatt: `vercel.json`, `tools/build_web.sh`; SVG-Werkstatt nach `werkstatt/` |
| #28 | Barrierefreiheit (erste Fassung), animierte DROMEs im Startbildschirm, **Roguelike-Lauf** (`RunState`, Lauf-Bildschirm) |
| #29 | Touch-Bedienung, dann **Umbau auf Hochformat**: Entwurfsraum 450x800, `UiKit`, Tab-Leiste, Kamera folgt im Kampf, Pinch/Ziehen; `CLAUDE.md` angelegt |
| #30 | **Hangar** statt Garage/Inventar/Werkstatt, **Halter-Formen**, Wisch-Scrollen, Schriftgroessen-Option nur fuer Text |

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
  Angriff einer Waffe IST ihre Faehigkeit; Vortex alle 3 s; Orbit-Sog alle 6 s; Boost, wenn ein
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
* **Startzonen** 5 Felder von den Ecken eingerueckt (`deployment.inset`):
  erster Treffer nach rund 2 s statt nach zwei Zyklen.
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
  (max. 4). Dieselbe Ansicht vor dem Chaos-Virus.
* Der Lauf **kopiert** die mitgenommenen DROMEs. Im Lauf wird nur mit Beute
  umgebaut, nicht mit dem Inventar zuhause. Beute kann eingebaut oder **nach
  Hause geschickt** werden (`RunState.home_queue` ->
  `GameState.deliver_run_home()`: Teil = Instanz, DROME = neuer Roster-Eintrag).
  Was im Lauf eingebaut wurde, bleibt im Lauf.
* (Frueher fester Start-Squad Vireo + Nimbus -- das war der Fehler "im Lauf
  kommt ein ganz anderes Squad raus", behoben Nov. 2026.)
* **Drei Gegner je Runde**: Leicht / Normal / Elite (`run.tiers`). Vorher
  sichtbar: Region und die gegnerischen DROMEs mit Ausruestung
  (`RunState.enemies()`, dieselben im Kampf ueber `GameState.enemy_override`).
* Gegnerstaerke = Startstaerke des mitgenommenen Squads * (0,85 + 0,06 *
  (Runde - 1)) * Stufenfaktor (0,7 / 1,0 / 1,3) -- **feste Kurve**.
  Gegnerzahl = Startgroesse + `enemy_offsets[runde]` (-1 bei Leicht, +1 bei
  Elite), 1..4. Elite braucht den Extra-Gegner: zwei Gegner kommen im
  Generator nicht ueber ~680 Kampfwert, bei vier ist bei ~1300 Schluss.
* **Messung** (vier Standard-DROMEs OHNE Beute, 6 Kaempfe je Feld):
  Runde 1 Leicht 6/6, Normal 6/6, Elite 2/6; Runde 4: 6/6, 2/6, 0/6;
  Runde 8: 5/6, 3/6, 0/6. Mit der alten Steigung 0,20 war ab Runde 4 auch
  Leicht nur 1/6 -- die volle Standardausstattung laesst kaum freie Halter,
  der Squad waechst durch Beute weniger als frueher.
* Beute je Stufe: Leicht 1 aus 2 Teilen der Gegner (oft Notstrom); Normal 1
  aus 3 (Runde 2 und 5 ein DROME); Elite garantiert selten = neuer DROME oder
  mittleres/schweres Teil. Es gibt (noch) kein Geld und keine Seltenheitsstufe
  -- "selten" ist vorlaeufig die Gewichtsklasse.

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
* Zehn Grundmodule (vorlaeufig): Angriff -- Schnellfeuer, Langer Lauf,
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
* Beute: je Sieg ein Grundmodul zusaetzlich zur Auswahl, Elite mit 50 %
  gleich ein Rezept-Modul. Module teilen sich die 8 Lagerplaetze, lassen
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
  Rezept-Modul passt kein zweites Mal in denselben Halter
  (`RunState._recipe_twice`); Grundmodule stapeln weiter.
* **Messwerkzeug** `tools/playtest/module_bench.gd -- 400 "Vireo=mod_a+mod_b"`:
  Squad mit Modulen gegen sich selbst ohne, je Seed beide Seiten (400 Seeds =
  800 Kaempfe). 1000 Spiegelkaempfe ohne Module: 483:517 -- kein Seitenbias,
  die 56:44 oben waren Zufall bei nur 100 Kaempfen.
* Entscheidungen nach den Gutachten (Laden statt Modul-Beute, Gegner-Module,
  Gebietsnamen): `NEUANFANG.md` Abschnitt 6i.

### Chaos-Virus
* Gegner sieht man vorher nicht; sie sind etwas schwaecher als die volle
  eigene Mannschaft (`chaos.enemy_power_factor` 0,9). Handicap und Beute
  rechnen weiter gegen die volle Referenz.

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
* Startseite: Titel, Kulisse mit animierten DROMEs (`MenuArena`: Leerlauf je
  Bauteil, Einmarsch, Schuesse, Funken, Schildring, Auseinanderfallen).

### Hosting
* Vercel baut mit `tools/build_web.sh` (Godot 4.7 mit Pruefsumme, nur die
  zwei Web-Templates per HTTP-Range ueber `tools/fetch_web_templates.py`).
* GitHub-Workflow `.github/workflows/web.yml` baut bei PRs und deployt auf
  Pages bei `main` (Pages muss im Repo aktiviert sein).
* PWA: Ausrichtung beliebig, Service Worker; nach einem Deploy auf dem Handy
  ggf. einmal neu laden.

---

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

* Alle Tests gruen seit dem Aufraeumen (5. Nov. 2026). Die frueheren roten
  Pruefungen waren Provokation (entfernt) und Tests aus der Zeit vor dem
  Energieschild (repariert).
* KI (5. Nov. 2026 umgebaut): Ziel wird gehalten (neu gewaehlt nur bei Tod,
  > 2 s unerreichbar oder sicherem Abschuss), Verhalten haengt an der Rolle
  des Chassis (`ai_role`: vanguard/skirmisher/sniper/controller), Fokus-Bonus
  fuer Ziele der Verbuendeten. Zielwechsel 11,3 -> 5,5 je Minute. Offen: der
  Nimbus faellt in ~80 % der Kaempfe zuerst (Runenstab Rw 1) -- seit dem
  Runenstab-Umbau (6. Nov., Rw 3, Vortex, Zauberwirker) noch in 58 %.
* Seit 6. Nov. 2026: ein Ausruestungsplatz je DROME (Molok zwei), Vireo mit
  Sprint, Doppelschuss, Plasmaklinge und Neon-Blaster, Neon-Leuchten als
  Prototyp. Details und Messung: `docs/NEUANFANG.md` Abschnitt 6c.
* Ebenfalls 6. Nov.: Molok als Tank (200/10, Praesenz, Hammer mit
  Betaeubung) und die Aufstellung vor dem Kampf per Ziehen (Zone 3 x 5).
  Abschnitte 6d und 6e.
* Ebenfalls 6. Nov.: Aggro-Tabelle raus, sichtbare Zielregel je Rolle und
  Locken (Molok-Praesenz, Koedersender). Abschnitt 6f.
* Ebenfalls 6. Nov., Aufraeumen nach `docs/NEUANFANG.md` 6g: Schild laedt
  nur nach 4 s ohne Schaden (10 % je Sekunde), Ueberschuss am Schild richtig
  gerechnet, Kerne ohne Werte (fest am Chassis, kein Kern-Halter), Kanone
  entfernt, Gegnerstaerke nach fester Bezugsstaerke, Nimbus-Passive Echo
  (seit 7. Nov.: Takt +50 %, Faehigkeit wirkt zweimal), Vortex alle 3 s mit Rw 5, Angriffe heissen "Angriff". Messung in 6g.
  Am 7. Nov.: Deflektor (Stoss + Schildladung) und Drohnen-Pod (Heil-Angriff
  + Schutzdrohne) sind Waffen mit Angriff und Faehigkeit.
  Playtest kann jetzt auch Spiegelkaempfe (`... playtest.gd -- 200 0 spiegel`).
* ~~Namensschilder/Balken schweben beim Herauszoomen und ueberlappen~~ --
  behoben 7. Nov. 2026 (siehe "Lesbarkeit im Kampf").
* Im Lauf: Belohnungsbildschirm nur per Test geprueft, nie im Browser gesehen.
* Module: Gegner tragen keine, die Gegnerkurve kennt sie nicht; der
  Kampfwert (`power_score`) sieht nur DEF und Schild. Die alten Teile
  Koedersender (`eq_bait_beacon`), Hologramm-Boost und Orbit-Fokus sind
  noch Ausruestung, obwohl sie laut 6g Module werden sollen.
* Spielstand-Auswahl vor dem Hauptmenue (Wunsch des Spielers, Nov. 2026)
  ist noch nicht gebaut -- haengt an der Persistenz.
* Spielstand-Persistenz ist in der Dev-Phase aus (`save_enabled: false`) --
  ein Lauf uebersteht kein Neuladen.
* `docs/GAME_DESIGN.md` und Teile der `README.md` beschreiben noch die alte
  Querformat-Werkstatt.

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

**Playtest und Vorschlaege zu Bewegung und Faehigkeiten:**
`docs/PLAYTEST_2026-11.md` (mit `tools/playtest/playtest.gd`). Dort stehen die
offenen Fragen an den Spieler.

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
