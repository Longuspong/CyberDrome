# CyberDrome -- Arbeitsnotizen fuer Claude

Godot 4.7 (GL Compatibility), GDScript. Ausfuehrliches Design in
`docs/GAME_DESIGN.md`, Bedienung und Struktur in `README.md`.

**Leitplan seit 25. Nov. 2026: `docs/KERNPLAN.md`** -- was zum Kern gehoert (Autobattler +
Lauf, Molok/Vireo/Strix mit Passiven, Fusions und BIOS ueberarbeiten statt neu bauen), was
in den Ideen-Branch wartet (Nimbus, Endlos, Story, Fraktionen, Android, Gegnerkurve), in
kleinen Runden arbeiten, Fragmente verworfener Systeme im selben PR entfernen. Neue Ideen
nicht auf main. Stand: Vireo-Passive **Cyberspeed** (25. Nov.), Molok-Passive **Safe Haven**
(vorher Arbeitsname Festung) und Hammer mit Heilung (27. Nov.); Waffen auf eine Kernwaffe je DROME
reduziert (27. Nov., Ramme/Schraubenschluessel/Bumerang/Neon-Blaster/Moerser entfernt).
**Werkblatt vom 27. Nov. uebernommen** (`SKILLBAUM_KONZEPT.md` 5e): Molok als **Gunship**
(ein Halter, Waffe an beiden Armen, `mirror` in `slot_rules`), Strix-Passive **Focuslense**,
neue Tempo-/Schildpulswerte, Echo-Takt aufgerundet, Halter-Kuerzel S/M/X + -F/-N.
Nimbus seit 28. Nov. als Supporter gebaut (Cleancode/Bug-Fix/Shieldgate, `SKILLBAUM_KONZEPT.md` 5f)
mit dem **Repair-Kit** aus PR #114 (speichert angerichteten Schaden, Reparaturwelle als Drohnenschwarm
gibt ihn dem Team mal Effizienz als Schild + Reparatur zurueck); er wartet im Hangar (Start-Squad =
Kern-Trio). Der fruehere Nimbus lebt als Neon Nimbus (Power 15, Effizienz 5). Varianten weichen ueber
`passive`/`ai_role`/`holder` in `formations.json` vom Chassis ab (`Formations.apply_variant`, Neon Vireo
Halter M-N). Solar Nimbus, Mecha Molok, Mecha Strix bis nach dem Kernspiel entfernt (Werte im
Kernplan). Hammer ohne Integritaetsschaden (27. Nov.); **Spielstand 3 ist ein Testspielstand** (1000
von allem, jede Waffe extra), den jede neue Version neu schreibt
(`GameState.refresh_test_slot`, Versionskennung `data/build.json` aus `tools/build_web.sh`).

**Ganz zuerst (seit 17. Nov. 2026, zuletzt 18. Nov. abends): `docs/UEBERGABE_3D.md`, Abschnitt „Stand 18. Nov.“** -- 3D-DROMEs, Leistungstest, Hexfeld und die vereinbarten naechsten Schritte (erledigt: gedrehter Quader, Neon/Kontur/Zerfallen in 3D, Hexfeld 9 x 17 in der Logik und im 2D-Kampfbild; Kampf als eine 3D-Szene `Arena3D` mit Grundbewegung und 3D-Boden `ArenaFloor3D` seit 18. Nov.; sichtbare Passiven, Muendungsblitz und 3D-Deko seit 18. Nov.; Beine im Wechsel, alle Faehigkeiten lesbar (`AbilityPainter`), Waffenfarben mit Glanzkante (`WEAPON_FINISH`), Generator-Bausteine BP/SW/EX und Redesign aller Chassis seit 18. Nov. -- `DROME_UMSETZUNG.md` 4g; Fraktions-Paletten fuer Gegner und Faehigkeiten mit Ausholzeit/Abfolge (`AbilityFx`, `ActionData.windup`) seit 18. Nov.; alle Faehigkeiten animiert; Echo nacheinander und Flaechen am Wurfort seit 18. Nov., Balance gemessen; offen: Story-Level).

**Technik-Prüfung (20. Nov. 2026): `docs/TECHNIK_PRUEFUNG.md`** -- Godot bleibt;
Ziel Android-APK, PWA = Testweg; Ladezeit gemessen (16,3 MB, 26 % davon ungenutzte DROME-SVGs); Plan „nur noch 3D“
(A Ballast raus, B-a 2D-Arena raus, B-b Geschosse in 3D (`Arena3D.add_shot`), C Werkstatt
entfernt + Generator schreibt nur Modell + Suedansicht-Symbol -- alles GEBAUT 20./21. Nov.) -- Abschnitt 6.

**Zuerst lesen: `docs/PROJEKTSTAND.md`** -- was gebaut, gemessen und
entschieden ist, bekannte Schwaechen, offene Punkte und wie man im Browser
als Handy testet. `docs/NEUANFANG.md` ist Hintergrund (Neuentwurf vom Nov. 2026,
groesstenteils umgesetzt oder ueberholt; Kopf sagt, was noch gilt).
**Module (seit 20. Nov. 2026 GEBAUT): `docs/MODULE_AMP_FUSION.md`** -- Amp (Grundmodul,
ein Wert, Abwehr in Prozent), Fusion (zwei verschiedene Amps, kostenlos),
Hyperfusion (zwei gleiche + Fusion Core, 1 je DROME, je Sorte 1x je Einsatz),
BIOS darueber; Armor +3, Tech +2 **Effizienz** (versteckter Wert 10 = 100 %,
Dauer/Stapel von Statuseffekten, nie Schaden). Gebaut seit 20. Nov.: Effizienz
(`Unit.efficiency`, `apply_status(..., source)`) und **Kabelbrand** (Stapel, je
Puls max. 10, `ActionResolver.burn_cable_fire`; Ausloeser: Feuer-Charger). **Seit 20. Nov. 2026 gebaut:** 6 Amps, 15 Fusionen (2 entschieden, 13
Vorschlaege), 6 Hyperfusionen mit Fusion Core. **Offene Logik (Charger + Amps) steht in
`docs/design/UEBERGABEN_DESIGN.md`, Abschnitt „Offene Logik nach dem Bau“** -- vor neuer
Arbeit daran lesen.
**Skilltrees (22. Nov. 2026, Richtung entschieden, Schablone Entwurf): `docs/SKILLBAUM_KONZEPT.md`**
-- keine Erfahrung mehr, DROMEs und Waffen je 5 Level ueber Ressourcen, Knoten 1-4 nur Werte,
Knoten 5 aendert Passive bzw. Faehigkeit, Umskillen kostet Ressourcen, Fraktionsvarianten =
Identitaet + Twist, Charger bleiben an der Waffe. **Seit 24. Nov. 2026 gebaut:** keine EP mehr,
Level werden mit Fabrik-Waren gekauft (Waffen bis 5, Level 5 mit Keynode-Chip, Abschnitt 5d);
die Skilltree-Knoten selbst noch nicht bauen, erst absegnen. Seit 24. Nov.: Regeln sind
Leitlinie, kein Korsett; Vireo-Baum + Neon-Strang als Vorschlag; Werte im Werkblatt
`docs/spot/CyberDrome_Werkblatt_DROMEs_Waffen.xlsx`.
**Factory-Builder (23. Nov. 2026, Richtung entschieden, Prototyp v2): `docs/FACTORY_KONZEPT.md`**
-- Hex-Platine, Nachbar-Lieferung, Puffer + Uplink, Netzanschluss mit Strom nach Naehe,
nur Ressourcen (Charger/DROMEs entstehen aus dem Lager in ihren Reitern), Tiers, Baukerne fallen
weg; Takte vor allem aus dem Einsatz. Prototyp: https://claude.ai/artifact/BU9arMAXSSSC18zgFEnQsd
(Kopie `docs/design/factory_prototyp/`). **Logik seit 23. Nov. 2026 GEBAUT** (`FactorySim`,
`data/factory.json`, Reiter Linien = Platine, Lager = `Roster.materials["res:<ware>"]`, 20 Takte je
Kampf) -- Stand in `docs/PROJEKTSTAND.md`; die Optik folgt laut Abschnitt 12 in einer Design-Sitzung. **Werkbank (24. Nov. 2026, GEBAUT):**
Abschnitt 13 -- Reiter Platine | Werkbank, DROMEs aus fuenf Teilen (`Workbench`, Rezepte in
`data/factory.json` -> `werkbank`), Bauplan-Baum, Ziel merken; Fraktions-DROMEs mit Spezialteil
(aus Fraktionskern), Verwerten gibt Zutaten zurueck, Baukerne gibt es nicht mehr.
**Waffen-Upgrades (20. Nov. 2026, entschieden und GEBAUT): `docs/CHARGER_KONZEPT.md`**
-- Charger je Waffe aus Energy Phases, Elementarbelastung, Resonanz, Cache-Inhalt.
**Bildschirme fuer Design-Sessions: `docs/design/UEBERGABEN_DESIGN.md`** -- Hangar
(Umbau + Waffen-Upgrade statt Squad), Einsatzvorbereitung mit Squad-Wahl,
Charger-Crafter -- seit 20. Nov. 2026 entworfen (Design-Canvas
https://claude.ai/artifact/FJpqxTaHcbXsPTU619YC1e) und gebaut; Stand in `docs/PROJEKTSTAND.md`.
**Fuer Story, Fraktionen, Gegnergruppen: `docs/VORSCHLAG_STORY.md`** --
Vorschlaege vom 10. Nov. 2026, noch NICHT entschieden; die offenen Punkte
stehen dort in Abschnitt 6. **Story-Rahmen seit 14. Nov. 2026: `docs/STORY_LEITFADEN.md`**
(ersetzt den Aufhaenger "Die Liga und der Virus"; Hipstar Hookers heissen jetzt
Hipstar Hackers).

**Entwurf Einsatz-Bildschirme 15. Nov. 2026 (GEBAUT):** 24 Entwuerfe unter
`docs/design/einsatz_arcade/` gelten fuer die Optik aller Bildschirme
(Kopfzeile mit Glitch-Titel + Segment-Reiter, Tab-Leiste mit Symbolen,
`CacheArt`/`CacheOpener`, `StoryDialog`). Nur Optik -- neue Regeln daraus stehen
als offene Punkte im SPOT. Cache oeffnen ist bis dahin eine Vorschau.
Bilder ohne Web-Export: `xvfb-run ... tests/screenshot.gd -- <szene> <png> 90
[run=story results=SS ...]` (Optionen im Kopf der Datei).

**DROME-Designregeln (16. Nov. 2026, abgesegnet; gebaut: Licht + Kontur je Teil,
Koerperart, Nah/Fern-Tags, Strix-Lafette, Halter-Symbole, Strix als Eule):**
`docs/DROME_DESIGNREGELN.md` -- Koerperarten (humanoid / Strix als Eule mit
Lafette, nur Fernkampf), ein Waffenarm je Chassis (Molok seit 27. Nov. 2026
Gunship: eine Waffe, an beiden Armen gezeigt), Nahkampf bis 2 / Fernkampf ab 3 Felder, Posen (die Waffe bringt
den Arm mit), sichtbare Passive, Kontur je Teil, Bewegung, lesbare
Faehigkeiten, Fraktions-Paletten. Entwurfs-Skripte unter
`docs/design/drome_entwurf/`. **Stand und Plan der Umsetzung (Haken):
`docs/DROME_UMSETZUNG.md`** -- dort weitermachen (Chassis, Waffen-Posen und 4b Arme am Chassis gebaut -- zwei Haltungen halten/zielen, Manschette, Molok-Arme; **seit 17. Nov. 2026 echtes 3D**: Generator schreibt je Teil ein Modell `<id>.m3d`, `DromeModel` rendert den ganzen DROME per SubViewport mit Iso-Kamera; naechster Schritt: 5 Bewegung in 3D).

**Module und BIOS (18. Nov. 2026, entschieden und gebaut):** Modulplaetze sind
fest (3 je Waffe, Molok 2) -- kein Level und kein BIOS gibt Plaetze dazu.
Kein Chassis-BIOS mehr. BIOS-Wahl fest nach jedem gewonnenen Elite-Kampf (bis
3, eins je DROME), danach ein Lootcache; ein BIOS wertet ein Rezept in einer
Waffe auf. Zwischenstopp: DROMEs als Zeilen, Module ueberall 52 px als
Kartusche (`ModuleChip`). **Begriff (19. Nov.):** ein Rezept-Modul heisst im
Spiel **Fusion** (mit BIOS: BIOS-Fusion), "Rezept" ist nur die Anleitung im
Rezeptbuch; im Code bleibt `recipe`. Details `docs/PROJEKTSTAND.md`, `MODULE_AMP_FUSION.md` 6.

**Englisch vorbereitet (19. Nov. 2026):** neue Anzeigetexte ueber `tr("Deutscher
Text")` (statisch: `TranslationServer.translate`), Englisch in `i18n/texte.csv`
(Schluessel = deutscher Text), Begriffe nach der Spalte Englisch im SPOT-Glossar
(Vorschlaege, noch nicht entschieden). Sprache fest Deutsch
(`Accessibility.language`), kein Schalter. Der grosse Umbau der alten Texte
kommt erst, wenn Module und Story ruhiger sind. Regeln: `i18n/LIESMICH.md`.

**UI-Symbole (15. Nov. 2026):** Sonderzeichen, die die Schriften nicht haben,
nie als Text -- stattdessen SVG aus `assets/ui_icons/` ueber `UiIcon`
(`tests/test_glyphs.gd` prueft das).

**Grosse Umsetzung 14. Nov. 2026 (GEBAUT, Details `docs/PROJEKTSTAND.md`):**
Bedienung mit Kacheln + Popups (`Tile`, `InfoPopup`), Arcade-Stil auf allen
Bildschirmen, Umlaute in der Anzeige, Virusschaden, Sentinels + Gegner-DROMEs +
Formationen (`Formations`, `data/formations.json`, Reinforcement-Level),
Kampfkarte mit festen Pfaden, Lootcaches + Platzhaltercoin (noch nicht zu
oeffnen), Heilregel. Offen: Caches oeffnen + Hangar-Shop (Bauschritte 4/5),
Formationen fuer Solar/Mecha/Hipstar, Story-Einsaetze, Balance.

**Neues Spielprinzip (12./13. Nov. 2026, seit 14. Nov. groesstenteils gebaut):**
`docs/GEGNERDESIGN.md` (Brainstorming) und die SPOT-Blaetter Einsatz,
Lootcaches, Hangar-Shop, Sentinels, Gegner-DROMEs, Formationen. Kurz: Lauf
heisst **Einsatz**, Gegner-Squads = DROME(s) + **Sentinels** (einfache Bots,
ein Waffenslot, echte Waffe, eigene schwaechere Power; Archetypen Assault,
Sniper, Support je Fraktion), asymmetrisch. Beute = fraktionsabhaengige
**Lootcaches** (Inhalt legt der Spieler fest), sonst **Platzhaltercoin** fuer
den Hangar. Overtime war so nicht entschieden: stattdessen **Virusschaden**
ab 5 Min., je Puls 10 % von Schild + Integritaet, an der Ruestung vorbei.
Werte dazu traegt der Spieler in der Excel ein (hellblaue Felder).
Neuer Grafikstil **Arcade-Glitch** (Synthwave, Bungee + Chakra Petch, Gelb/
Cyan/Magenta auf Nachtschwarz) mit neuem **Titelbildschirm** vor der
Spielstand-Wahl: Entwuerfe in `docs/design/`, Werte im SPOT-Blatt Design.
Titel und Spielstand-Wahl sind GEBAUT (13. Nov.), die uebrigen Bildschirme seit 14. Nov. ueber `UiKit`.
**Bauplan:** 1 Sentinels, 2 Formationen, 3 Einsatz (Reinforcement, Virus,
Kampfkarte), 4 Lootcaches, 5 Hangar-Shop, 6 Sentinel-Designs, 7 Arcade-Stil
fuer die uebrigen Bildschirme (macht der Spieler). **Antworten des Spielers
(14. Nov.) im SPOT-Blatt Fragen, Kurzfassung in den Eckpunkten** -- vor dem
Bauen lesen. Wichtig: es gibt **keine Wellen**; gemeint ist ein
**Reinforcement-Level**, das nach jedem Kampf steigt. Sentinels: feste Waffe,
nur Auto-Angriff, Basic ohne Modul, Elite 1 festes Modul. Je Fraktion 6
Formationen (Grundgedanke) in Leicht/Normal/Elite, max. 2 DROMEs. Kampfkarte
FTL-artig mit festen Pfaden. Neue offene Punkte stehen im Blatt Offene Punkte.

## SPOT-Tabelle (Vorgabe des Spielers, 12. Nov. 2026)

Die SPOT ist die **Single Point of Truth** fuer alle inhaltlichen Daten.
Seit 19. Nov. 2026 sind es **vier Dateien** unter `docs/spot/` (vorher eine):

* `CyberDrome_SPOT_Entscheidungen.xlsx` -- Eckpunkte, Fragen, Offene Punkte, Glossar
* `CyberDrome_SPOT_Balance.xlsx` -- Regeln, Level, Rollen, DROMEs, Teile,
  Waffen, Passiven, Sentinels, Gegner-DROMEs, Einsatz
* `CyberDrome_SPOT_Module.xlsx` -- Module, Rezepte, Rezept-Matrix, BIOS
* `CyberDrome_SPOT_Welt.xlsx` -- Fraktionen, Stages, Story, Einheiten,
  Formationen, Maps, Lauf, Lootcaches, Hangar-Shop, Design

Jede hat vorn ein Blatt Uebersicht. Formeln zeigen nie in eine andere Datei
(was aufeinander rechnet, liegt in der Balance); die Aufteilung steht in
`FILES` in `tools/build_spot.py`. Die Dateien werden **nicht von Hand**
bearbeitet, sondern von `tools/build_spot.py` aus `parts/`, `data/*.json` und
den Texten unter `docs/spot/inhalte/` erzeugt (`entscheidungen.json`,
`balance.json`, `welt.json`, `design.json`).

* **SPOT nur noch auf Zuruf (Spieler 24. Nov. 2026).** Nicht mehr bei jedem PR
  nachziehen -- vieles klaert der Spieler im Chat, das Nachziehen kostet nur
  Tokens. Neu bauen (`python3 tools/build_spot.py`, Texte unter
  `docs/spot/inhalte/`) nur, wenn der Spieler es verlangt. Die CI prueft die
  SPOT nur noch beim Start von Hand (`workflow_dispatch`).
* **Fuer Entscheidungen lieber ein Werkblatt:** wenn der Spieler Werte
  vergleichen oder eintragen will, die noetigen Daten heraussuchen und als
  kompakte Excel unter `docs/spot/` ablegen (von Hand bearbeitbar, kein Teil
  der SPOT). Erstes Beispiel: `CyberDrome_Werkblatt_DROMEs_Waffen.xlsx`
  (24. Nov. 2026: Leitlinien, alle DROME- und Waffenwerte, Passiven,
  Skilltrees; hellblau = vom Spieler zu fuellen).
* **Design-System** (seit 17. Nov. 2026): Artefakt „CyberDrome Arcade-Glitch“
  (https://claude.ai/artifact/M5RC8KNDTr5psmKSuJpdS2) mit Tokens, Brand-Book,
  Komponenten und Symbolen -- ebenfalls ein Spiegel. Seine Tokens erzeugt
  `build_spot.py` aus `design_farben` + `design_tokens` in `inhalte/design.json`
  nach `docs/design/tokens.json` (nur auf Zuruf). Farben im Spiel aendern =
  dort nachtragen, neu bauen und `tokens.json` ins Design-System uebernehmen.
  Brand-Book und Komponenten liegen als Sicherung unter
  `docs/design/design_system/` (Anleitung dort in `LIESMICH.md`).
* Heute ein Spiegel: der Spieler trifft darin Designentscheidungen und gibt
  sie als Export zum Umsetzen. Vision des Spielers: spaeter ein
  Balance-Werkzeug (Werte in der Excel aendern -> ins Spiel uebernehmen).
  Noch nicht bauen, erst besprechen.

## Zusammenarbeit

* Der Spieler schreibt Deutsch -- Antworten, Commits und PRs auf Deutsch.
  Code-Kommentare auf Deutsch ohne Umlaute.
* Auf dem vorgegebenen Branch arbeiten, Draft-PR oeffnen; der Spieler merged
  selbst. Nach einem Merge den Branch von `main` neu aufsetzen.
* Designfragen, die das Spiel selbst aendern (Regeln, Balancing, Layout-
  Muster), vorher kurz mit Empfehlung vorlegen.

## Token sparen -- nur fuer Sitzungen mit Fable (Vorgabe des Spielers, 10. Nov. 2026)

**Gilt nur, wenn die Sitzung auf Fable laeuft** (seit 15. Nov. 2026, Wunsch
des Spielers). Mit anderen Modellen (Opus, Sonnet ...) entfallen diese Regeln:
dann normal arbeiten, Themen duerfen in einer Sitzung weiterlaufen, Browser
und Screenshots nach Bedarf. Im Zweifel das Modell mit `get_session`
pruefen. Das gilt auch fuers Beobachten von PRs: mit anderen Modellen den
eigenen PR beobachten und rote CI selbst reparieren (seit 15. Nov. 2026).

Die Sitzung vom 10. Nov. war gut, aber sehr teuer. Deshalb gilt (nur Fable):

* **Ein Thema je Sitzung.** Fuer jedes neue Thema eine frische Sitzung --
  je laenger eine Sitzung laeuft, desto teurer wird jeder Schritt. Nur
  lesen, was das Thema braucht (gezielt mit `grep`/`sed -n`, nicht ganze
  grosse Dateien).
* **Browser nur bei Touch- und Layout-Themen.** Fuer Logik (Level, Gegner,
  Balance, Daten) reichen `tests/run_tests.gd` und `tests/smoke_ui.gd`;
  kein Web-Export, keine Screenshots. Die Sichtpruefung macht der Spieler
  auf der Vercel-Vorschau. Wenn doch Browser: so wenige Builds wie moeglich,
  erst alle Aenderungen, dann einmal bauen.
* **PR nicht beobachten (nur Fable).** Draft-PR oeffnen und aufhoeren -- kein
  `subscribe_pr_activity`, keine Nachschau-Termine. Der Spieler meldet sich,
  wenn etwas rot ist. Nur auf ausdruecklichen Wunsch beobachten.
* **Lange Messlaeufe sparsam.** `power_bench`, `run_bench`, Spiegelkaempfe
  nur, wenn eine Aenderung die Balance trifft -- und dann mit kleinen
  Zahlen zuerst.

## Befehle

```bash
godot --headless --path . --script res://tests/run_tests.gd   # Tests
godot --headless --path . --import                            # nach neuer class_name noetig
bash tools/build_web.sh                                       # Web-Export nach build/web
python3 tools/build_spot.py                                   # SPOT-Tabelle neu bauen
```

* Seit dem Aufraeumen vom 5. Nov. 2026 sind alle Tests gruen -- neue Arbeit
  haelt das so. Der Testlauf laedt auch jedes Skript und jede Szene; die
  Bildschirme selbst baut `tests/smoke_ui.gd` (eigener Lauf, `--fixed-fps 60`).
* Messen: `tools/playtest/power_bench.gd -- 3000` (wie gut sagt der
  Kampfwert Kaempfe voraus), `run_bench.gd -- 60` (Standard-Squad gegen die
  Lauf-Gegner), `playtest.gd -- 200 0 spiegel` (Spiegelkaempfe).
* Headless-Hilfsskripte (`extends SceneTree`) duerfen Projektklassen nicht
  direkt referenzieren -- sie kompilieren vor den Autoloads. Logik in ein
  `RefCounted`-Skript legen und zur Laufzeit per `load()` holen (wie
  `tests/run_tests.gd`).
* Gehostet wird auf Vercel (`vercel.json` -> `tools/build_web.sh`).

## Ausrichtung

* **Mobile first, Hochformat ist die Hauptansicht.** Querformat wird
  angeboten, ist aber zweitrangig. Neue Bildschirme werden zuerst fuer
  ein Handy im Hochformat entworfen (ca. 400 CSS-Pixel breit).
* Erster Bildschirm ist der **Titel** (`scenes/title.tscn`, seit 13. Nov.
  2026, irgendwo tippen), dann die Wahl des Spielstands (drei Stueck,
  `scenes/saves.tscn`, `GameState.select_slot`). Beide im Arcade-Glitch-Stil
  ueber den Baukasten `Arcade` (`scripts/ui/arcade.gd`, Schriften unter
  `assets/fonts/`, OFL); die uebrigen Bildschirme ueber `UiKit`, das seit
  14. Nov. 2026 dieselben Farben, Schriften und Formen nutzt. Listen und
  Auswahl als Kacheln (`Tile`: tippen waehlt, nochmal tippen = Details,
  Doppeltipp = Handlung; seit 15. Nov. 2026), Erklaerungen als blaetterbares
  Popup (`InfoPopup.open_pages`). DROMEs werden verwertet, nicht aufgeloest
  (Zutaten + Spezialteil zurueck, `Roster.salvage`; gebaut wird in der Werkbank).
* Navigation: Tab-Leiste unten, seit 22. Nov. 2026 fuenf Tabs: Shop, Fabrik,
  Home (Mitte), DROMEs, Inventar (`UiKit.TABS`; Optionen am Zahnrad oben rechts).
  Ein Verb je Tab: Shop kaufen, Fabrik herstellen (Linien, Charger, DROMEs),
  Home spielen, DROMEs ausruesten/aufwerten (Liste -> DROME-Seite mit Uebersicht,
  DROME, Waffe), Inventar lagern -- Details `docs/PROJEKTSTAND.md`. Squad max. 3,
  ein Ausruestungsplatz je DROME (Molok als Gunship ebenso); Halter als Formen: Dreieck leicht,
  Viereck mittel, Fuenfeck schwer; leicht passt nach oben in groessere Halter,
  schwer nur in schwer. Kuerzel im Text (seit 27. Nov. 2026, sprachneutral):
  S/M/X, dahinter -F nur Fernkampf, -N nur Nahkampf (`SlotRules.holder_code`).
* Spielfeld ist seit 17. Nov. 2026 ein **Hexfeld**, seit 18. Nov. 2026 **je
  Formation eine eigene Karte** (`config.json` -> `maps`, Formation -> `map`;
  Standard 9 x 15, dazu kurz 9 x 13, lang 9 x 21, Zwei Gassen, Bauch 11 x 17;
  Formen fest und gespiegelt, `MapGenerator.apply_shape`, `Grid.holes`;
  keine zufaelligen Hindernisse mehr, Randdeko bleibt) (hochkant,
  Spieler unten, Gegner oben; seit 18. Nov. 2026 **flache Sechsecke**: Kante
  oben/unten, Spalten senkrecht -- `Grid`: `Vector2i(spalte, reihe)`,
  "odd-q": ungerade Spalten halb nach unten und eine Reihe kuerzer (exakte
  Spiegelung), Richtung i zeigt auf 30 + 60 i Grad, Abstand in Hexschritten,
  `Grid.neighbors`/`neighbor`/`direction_toward`/`line_direction`;
  Bildschirm nur ueber `IsoView`). Reichweiten 1:1 von Manhattan uebernommen.
  Blickrichtung im Kampf als Winkel `deg<grad>` (`DromeModel.facing_basis`).
  Ohne Gelaende-Regeln und ohne Sichtlinie. Feste Bloecke der Kartenform
  sperren nur Laufwege (Schuesse gehen darueber); zufaellige Hindernisse gibt
  es seit 18. Nov. 2026 nicht mehr (`config.json` -> `obstacles` nur Optik).
  Aufgestellt wird in einem Streifen 3 x 7 am Rand, ohne Zutun nach
  Rolle gestaffelt und verteilt (seit 10. Nov. 2026). Die
  Arena zeichnet `ArenaPainter` (Boden, Rand, Deko, Licht je Region). Die
  Kamera steht seit 21. Nov. 2026 fest (Zoom auf Feldbreite, gleitet nur senkrecht mit;
  Kamerafahrten aus, `BattleScreen.CAMERA_MOVES`), Zoomen und Ziehen per Finger.
* Das Spiel ist ein **Autobattler in Echtzeit** (seit Nov. 2026): alle
  DROMEs handeln gleichzeitig, keine Zuege. `BattleManager.tick()` rechnet in
  festen Schritten (0,05 s, deterministisch je Seed), die KI (`AIController`)
  steuert beide Seiten. **Gegner werden nicht gewuerfelt** (seit 10. Nov.
  2026, Vorgabe des Spielers): handverlesene Teams aus
  `data/formations.json` (`Formations`, seit 14. Nov.), gewuerfelt wird nur im Chaos-Kampf
  des Endlos-Modus. Jede Waffe hat ein Schussintervall, SPD ist die
  Laufgeschwindigkeit, MOV und Energie spielen keine Rolle mehr. Was frueher
  zu Zugbeginn lief (Schild, Reparatur, Overtime ...), laeuft je Puls (3 s).
  Der Spieler entscheidet ueber Aufbau und Auswahl.

## Offene Designpunkte (noch zu besprechen)

1. **Faehigkeiten loesen automatisch aus -- ENTSCHIEDEN und gebaut.** Nur
   Ausruestung hat Faehigkeiten. Waffen zaehlen ihre Angriffe, der N-te
   Angriff IST die Faehigkeit (Blaster, Runenstab jeder 3., Lanze jeder 4.).
   **Seit 9. Nov. 2026 kein Zeit-Takt mehr** (Vorgabe des Spielers): auch
   der Vortex zaehlt Angriffe; nur Ereignisse bleiben (Hologramm, wenn ein
   Gegner danebensteht). Der Orbit-Fokus wurzelt seitdem das Ziel einer
   Faehigkeit 2 s, statt zu ziehen. Steht als `trigger` an der Aktion.
2. **Skill-Tiefe ueber Synergien -- ENTSCHIEDEN und gebaut.** Die Synergie
   steckt in **Waffen** und **Modulen** (nur im Einsatz: Amps, Fusionen,
   Hyperfusionen, BIOS -- `docs/MODULE_AMP_FUSION.md`). Alles im Halter heisst
   **Waffe** (Angriff + Faehigkeit), der Halter regelt allein, was passt.
   Level werden mit Fabrik-Waren gekauft (`docs/SKILLBAUM_KONZEPT.md`).
3. **Eingreifen des Spielers -- offen, wird spaeter besprochen.** Fest steht:
   grundsaetzlich Autobattler, der Spieler **steuert keine DROMEs**. Er soll
   aber eingreifen koennen, vermutlich indem er einen Gegner als Ziel Nummer 1
   markiert (frueher "Aggro-Platz 1"; die Aggro-Tabelle gibt es seit 6. Nov.
   2026 nicht mehr, Zielwahl nach Regel je Rolle). Der Spieler denkt das noch durch --
   nichts davon bauen, bevor es besprochen ist.
4. **Waffen-Slots und Gewichtsklassen -- ENTSCHIEDEN.** Ein Platz je DROME,
   auch der Molok (Gunship seit 27. Nov. 2026, gebaut); leicht/mittel/schwer bleibt als Halterregel, keine
   Liste "wer darf was" (6g).

Bis diese Punkte entschieden sind: keine groesseren Umbauten an
Faehigkeiten, Slots oder Gewichten auf eigene Faust.

## Todo fuer spaetere Sitzungen

Erst entscheiden (Spieler), dann bauen. Was laut `docs/KERNPLAN.md` wartet
(Story-Modus, Endlos-Modus, Fraktionen, Bosse, Gegnerkurve, Nimbus, Android),
steht dort im Abschnitt „Was erst mal wartet“ -- nicht anfangen, bevor der
Kernplan fertig ist.

- [ ] **Werkblatt weiter ausfuellen** -- erste Runde am 27. Nov. 2026 uebernommen
      (`SKILLBAUM_KONZEPT.md` 5e, 5f). Noch offen dort: Skilltrees, Takt neu, Zielregel
      Neon Nimbus, Werte des Repair-Kit bestaetigen (9 Schaden, 1,2 s, Reichweite 4, Welle jeder 6.).
      Wenn der Spieler eine neue Sitzung beginnt, daran erinnern.
- [ ] Designpunkt 3 **Eingreifen des Spielers** (siehe oben) besprechen.

Playtest ohne Bildschirm: `godot --headless --path . --script
res://tools/playtest/playtest.gd -- 30 5003` (Kaempfe, Seed mit Aktionslog).
Nach Aenderungen an `parts/` immer `python3 tools/bake_godot_assets.py` --
das Spiel liest die Kopie unter `assets/parts/`.
