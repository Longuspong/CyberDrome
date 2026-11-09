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
* **Neon City aus Bildern** (9. Nov. 2026, Wunsch des Spielers): Boden,
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
* **Ein Lauf bleibt in seinem Gebiet** (`run.region` in `data/config.json`,
  heute `city` = Neon City; `RunState.region_id` -> `GameState.battle_region`
  -> `BattleManager.setup`). Bis 9. Nov. 2026 wuerfelte jeder Kampf die
  Region aus seinem Seed -- je Stufe ein anderes Gebiet, obwohl der Lauf in
  Neon City spielt. Nur der Chaos-Virus wuerfelt noch.
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

### Neues Modulsystem und BIOS (9. Nov. 2026) -- `docs/MODULE_KONZEPT.md`
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

### Fraktionen und Profile (9. Nov. 2026) -- `data/regions.json` -> `faction`
* Jedes Gebiet hat eine Fraktion mit Profil: Neon City / Neon Ninja's =
  Kaempfer (Vireo, Klingen, Haemmer, Rammen; Rundumschlag, Raufbold,
  Ueberladung), Parkanlage / Solar Sentients = Rudel (Vireo, Nimbus,
  Blaster, Runenstab, Bumerang; Gabelung, Kettenreaktion, Zielsucher),
  Factory 5 / Mega Mechas = Festung (Molok, Strix; Hammer, Deflektor,
  Ramme, Moerser; Rammbock, Brandmarke, Bollwerk). Hipstar Hookers offen.
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
* Strix-Passive Anlegen (`steady`, `Unit.track_stillness`).
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
