# CyberDrome -- Arbeitsnotizen fuer Claude

Godot 4.7 (GL Compatibility), GDScript. Ausfuehrliches Design in
`docs/GAME_DESIGN.md`, Bedienung und Struktur in `README.md`.

**Zuerst lesen: `docs/PROJEKTSTAND.md`** -- was gebaut, gemessen und
entschieden ist, bekannte Schwaechen, offene Punkte und wie man im Browser
als Handy testet. **Dann `docs/NEUANFANG.md`** -- der Neuentwurf des
Spielprinzips, der gerade mit dem Spieler besprochen wird.
**Fuer Module: `docs/MODULE_KONZEPT.md`** -- seit 9. Nov. 2026 die
festgelegte Richtung (9 Grundmodule, 18 Rezepte, Matrix-BIOS, Profile =
Fraktionen, Waffen fest im Lauf); Bauplan dort in Abschnitt 14.
**Fuer Story, Fraktionen, Gegnergruppen: `docs/VORSCHLAG_STORY.md`** --
Vorschlaege vom 10. Nov. 2026, noch NICHT entschieden; die offenen Punkte
stehen dort in Abschnitt 6.

**Neues Spielprinzip (12./13. Nov. 2026, NOCH NICHT GEBAUT):**
`docs/GEGNERDESIGN.md` (Brainstorming) und die SPOT-Blaetter Einsatz,
Lootcaches, Hangar-Shop, Sentinels, Gegner-DROMEs, Formationen. Kurz: Lauf
heisst **Einsatz**, Gegner-Squads = DROME(s) + **Sentinels** (einfache Bots,
ein Waffenslot, echte Waffe, eigene schwaechere Power; Archetypen Assault,
Sniper, Support je Fraktion), asymmetrisch. Beute = fraktionsabhaengige
**Lootcaches** (Inhalt legt der Spieler fest), sonst **Platzhaltercoin** fuer
den Hangar. Overtime war so nicht entschieden: stattdessen **Virusschaden**
ab 5 Min., je Puls 10 % von Schild + Integritaet, an der Ruestung vorbei.
Werte dazu traegt der Spieler in der Excel ein (hellblaue Felder).

## SPOT-Tabelle (Vorgabe des Spielers, 12. Nov. 2026)

`docs/spot/CyberDrome_SPOT.xlsx` ist die **Single Point of Truth** fuer alle
inhaltlichen Daten (DROMEs, Waffen, Passiven, Module, Rezepte, BIOS,
Fraktionen, Stages, Teams, Einheiten, Lauf, Level, Regeln, Eckpunkte, offene
Punkte). Sie wird **nicht von Hand** bearbeitet, sondern von
`tools/build_spot.py` aus `parts/`, `data/*.json` und
`docs/spot/inhalte.json` erzeugt.

* **Jede Aenderung** an Werten, Daten oder Entscheidungen: neue Texte
  (Eckpunkte, Story, Fraktionen, offene Punkte) in `docs/spot/inhalte.json`
  nachtragen, dann `python3 tools/build_spot.py` und die xlsx mit einchecken.
* Die CI (`.github/workflows/spot.yml`) prueft mit `--check`, dass die
  Tabelle aktuell ist.
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

## Token sparen (Vorgabe des Spielers, 10. Nov. 2026)

Die Sitzung vom 10. Nov. war gut, aber sehr teuer. Deshalb gilt:

* **Ein Thema je Sitzung.** Fuer jedes neue Thema eine frische Sitzung --
  je laenger eine Sitzung laeuft, desto teurer wird jeder Schritt. Nur
  lesen, was das Thema braucht (gezielt mit `grep`/`sed -n`, nicht ganze
  grosse Dateien).
* **Browser nur bei Touch- und Layout-Themen.** Fuer Logik (Level, Gegner,
  Balance, Daten) reichen `tests/run_tests.gd` und `tests/smoke_ui.gd`;
  kein Web-Export, keine Screenshots. Die Sichtpruefung macht der Spieler
  auf der Vercel-Vorschau. Wenn doch Browser: so wenige Builds wie moeglich,
  erst alle Aenderungen, dann einmal bauen.
* **PR nicht beobachten.** Draft-PR oeffnen und aufhoeren -- kein
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
* Erster Bildschirm ist die Wahl des Spielstands (drei Stueck,
  `scenes/saves.tscn`, `GameState.select_slot`).
* Navigation: Tab-Leiste unten (Spielen, Hangar, Optionen). Der Hangar
  vereint Squad (Karussell, max. 4) und Umbau (ein Ausruestungsplatz je
  DROME, Molok zwei -- seit 6. Nov. 2026; Halter als Formen:
  Dreieck leicht, Viereck mittel, Fuenfeck schwer, Kreis Kern; leicht passt
  nach oben in groessere Halter, schwer nur in schwer).
* Spielfeld bleibt 20x20, ohne Gelaende-Regeln und ohne Sichtlinie (seit
  5. Nov. 2026). Seit 7. Nov. 2026 gibt es **Hindernisse**, die nur Laufwege
  sperren (Schuesse gehen darueber), punktsymmetrisch je Seed, nie an den
  Zonen (`MapGenerator.place_obstacles`, `config.json` -> `obstacles`).
  Aufgestellt wird in einem Streifen 3 x 8 am Kartenrand, ohne Zutun nach
  Rolle gestaffelt und verteilt (seit 10. Nov. 2026). Die
  Arena zeichnet `ArenaPainter` (Boden, Rand, Deko, Licht je Region). Die
  Kamera folgt dem Geschehen, Zoomen und Ziehen per Finger.
* Das Spiel ist ein **Autobattler in Echtzeit** (seit Nov. 2026): alle
  DROMEs handeln gleichzeitig, keine Zuege. `BattleManager.tick()` rechnet in
  festen Schritten (0,05 s, deterministisch je Seed), die KI (`AIController`)
  steuert beide Seiten. **Gegner werden nicht gewuerfelt** (seit 10. Nov.
  2026, Vorgabe des Spielers): handverlesene Teams aus
  `data/encounters.json` (`Encounters`), gewuerfelt wird nur im Chaos-Kampf
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
2. **Skill-Tiefe ueber Synergien -- ENTSCHIEDEN (6. Nov. 2026), nicht
   gebaut.** Kerne entfallen als Gegenstand, die Synergie steckt in
   **Waffen-Varianten** und **Modulen** (nur im Lauf, Rezepte, keine Stufen).
   Alles im Halter heisst **Waffe** (Angriff + Faehigkeit), der Halter
   regelt allein, was passt. Level von DROMEs (0-5) und Waffen (0-10)
   bleiben nach dem Lauf. Alles in `docs/NEUANFANG.md` Abschnitt 6g.
3. **Eingreifen des Spielers -- offen, wird spaeter besprochen.** Fest steht:
   grundsaetzlich Autobattler, der Spieler **steuert keine DROMEs**. Er soll
   aber eingreifen koennen, vermutlich indem er einen Gegner als Ziel Nummer 1
   markiert (frueher "Aggro-Platz 1"; die Aggro-Tabelle gibt es seit 6. Nov.
   2026 nicht mehr, Zielwahl nach Regel je Rolle). Der Spieler denkt das noch durch --
   nichts davon bauen, bevor es besprochen ist.
4. **Waffen-Slots und Gewichtsklassen -- ENTSCHIEDEN.** Ein Platz je DROME,
   Molok zwei (gebaut); leicht/mittel/schwer bleibt als Halterregel, keine
   Liste "wer darf was" (6g).

Bis diese Punkte entschieden sind: keine groesseren Umbauten an
Faehigkeiten, Slots oder Gewichten auf eigene Faust.

## Todo fuer spaetere Sitzungen (Stand 10. Nov. 2026)

Je Punkt eine eigene Sitzung. Erst entscheiden (Spieler), dann bauen.
Hintergrund und Vorschlaege: `docs/VORSCHLAG_STORY.md`.

- [ ] **Aufhaenger** "Die Liga und der Virus" uebernehmen? (Abschnitt 1)
- [ ] **Level-Struktur Story-Modus** bauen: zehn Level fuer Neon City,
      Level 1 mit 2 und Level 2 mit 3 DROMEs als Training, ab Level 3 vier
      gegen vier; je Level 3 Leben, Fortschritt bleibt (Abschnitt 2,
      `NEUANFANG.md` 6h). Groesster offener Baustein, Teams sind da.
- [ ] **Wege zwischen den Reihen** zurueck? Heute stehen alle Knoten zur
      Wahl (immer ein Leichter, dazu zwei Normale oder Normal + Elite).
- [ ] **Erstes Fraktions-Chassis**, z. B. Shinobi (Jaeger) -- braucht ein
      Bild aus der Werkstatt (Abschnitt 3).
- [ ] **Hipstar Hookers = Trickser?** (Abschnitt 3)
- [ ] **Bosse** am Ende der Story-Level (Oni, Shogun Kage; Abschnitt 3).
- [ ] **Schwierigkeit** pruefen: Normal Runde 8 63 %, Elite 41 % ohne
      Module -- so lassen oder Elite-Teams anziehen? (Abschnitt 5)
- [ ] **Aufstellung**: erster Treffer nach 5,6 s statt 2,0 s -- zu lang?
      Stellschraube `deployment.inset` in `data/config.json` (1 -> 3).
- [ ] **Umlaute in der Anzeige** ("Kaempfe" -> "Kämpfe")? Die Schrift kann es.
- [ ] **Endlos-Modus** ausbauen: Sektoren je Fraktion, bessere Beute je
      Sektor (Abschnitt 5; heute Platzhalter in `run.endless`).
- [ ] Designpunkt 3 **Eingreifen des Spielers** (siehe oben) besprechen.

## Naechste Schritte (Stand 10. November 2026)

Zuletzt gebaut (PR #55, Details in `docs/PROJEKTSTAND.md` "Playtest-Runde"):
Aufstellung am Rand, Kampfwert neu (Standhaftigkeit mal Feuerkraft, 80 %
Vorhersage), handverlesene Gegnerteams mit Gegnertyp, Gegnerwahl ohne Wege
(immer ein Leichter, dazu zwei Normale oder Normal + Elite), Endlos-Modus
mit Chaos-Knoten, drei Spielstaende, Touch-Ziehen repariert, gemeinsames
Theme. Danach (gleicher Tag): Umbau mit fester Ansicht, Halter in der
DROME-Karte, nur einbaubare Teile, Vergleichsbalken in der Waffen-Karte;
"Bester Aufbau" und Halter-Richtung entfernt. Als Naechstes: die Todo-Liste
oben.

Aelterer Stand (5. November 2026):

0. **Neuentwurf umsetzen** (`docs/NEUANFANG.md`, Reihenfolge in Abschnitt 8).
   Erledigt: KI-Grundlagen (Ziel halten, Rolle je Chassis, Fokus); Nimbus
   (Runenstab Rw 3, Vortex nach Zeit, Passive Echo); ein Platz je DROME;
   Vireo (Sprint, Doppelschuss, Plasmaklinge, Neon-Blaster); Neon-Leuchten
   als Prototyp; Molok (Tank 200/10, Praesenz, Hammer); Aufstellung vor
   dem Kampf per Ziehen (Zone 3 x 5); Zielregel je Rolle statt Aggro-Tabelle,
   Locken (Molok, Koedersender). Strix bleibt wie er ist, Ausgleich spaeter
   ueber eine Jaegerklasse. Naechstes: Zwischenstopp mit Modulen, Lager,
   Laden, Credits (`docs/NEUANFANG.md` Abschnitt 7). Kopf und Antrieb bleiben
   fest am Chassis -- ein DROME wird immer als Ganzes gestaltet.
   Entschieden: 3 Modulplaetze je Waffe (Molok 2), Credits + Laden (Beute
   gleich wichtig), Ausruestung bleibt nach dem Lauf; dazu Abschnitt 6g
   (Begriffe, Module, Level, Gegnerstaerke nach Region, Karte wie bei FTL,
   Chaos-Kampf statt Chaos-Modus, Nimbus-Passive neu). Reihenfolge: Abschnitt 8.
   Gebaut (6. Nov.): das Aufraeumen nach 6g (Schild nur nach Ruhe, Kerne
   ohne Werte, Kanone raus, Gegnerstaerke fest, Nimbus/Vortex neu), am
   7. Nov. Echo sowie Deflektor und Drohnen-Pod als Waffen, dann der
   Zwischenstopp (Lager, Credits, Ausruesten), Takt-Leiste im Kampf,
   Waffen-Karte mit Symbolen und der entschlackte Hangar, dann Module und
   Rezepte (`ModuleData`, `data/modules.json`; Module im Waffenhalter,
   bleiben beim Waffentausch, verfallen nach dem Lauf), am 8. Nov. der
   Laden (2 Grundmodule je Zwischenstopp fuer Credits, Mitleid fuer
   angefangene Rezepte; Module nicht mehr als Beute) und die gewuerfelte
   Beute ohne Auswahl (Credits oder Teil, DROME-Runden, Notstrom) und
   Gegner mit Modulen (nach Runde und Stufe, passend zur Waffe). Am 9. Nov.
   neuer Werte-Satz (Speed, Integritaet, Schild, Schildpuls, Ruestung,
   Halter, Power, Modulplaetze; ATK und Gewicht weg), Identitaeten, Strix-
   Passive Anlegen, Bonus-Wert je Waffe, Gadgets als Module und Level fuer
   DROMEs/Waffen -- alles in `docs/IDENTITAETEN.md`. Als Naechstes laut
   Spieler: die Waffen. Neu entschieden (7. Nov.): Story- und
   Endlos-Modus, Lager nur fuer Module, Gegner staerker ueber Level/Waffen/
   Module statt Faktor -- `docs/NEUANFANG.md` Abschnitt 6h. Module nach den
   Gutachten entschieden (8. Nov.): Module nur im Laden, Beute zufaellig
   (Credits oder Teile), Gegner tragen Module, Gebiete Neon City /
   Parkanlage / Factory 5 / Dachterrassen -- `docs/NEUANFANG.md` 6i.
   Neu (9. Nov.): das Modulsystem nach `docs/MODULE_KONZEPT.md`
   (`NEUANFANG.md` 6j) -- wird jetzt Schritt fuer Schritt gebaut.
   Die Punkte unten gehen darin auf.

1. Echtzeit-Kampf im Spiel ausprobieren und nachjustieren (Intervalle in den
   Teildaten, Tempo und Puls in `data/config.json` -> `realtime`). Seit dem
   Vortex nach Zeit macht der Nimbus den meisten Schaden (11/s, 6g) -- bleibt
   so, bis auch der Strix ausgeglichen wird. Die Ausloesevoraussetzung einer
   Faehigkeit heisst **Takt**.
2. ~~Kern als Synergie-Teil~~ -- entfaellt (6g). Skillbaeume spaeter.
3. Eingreifen ueber Aggro-Platz 1 besprechen (Designpunkt 3) -- passt jetzt
   gut: Gegner im laufenden Kampf antippen.
4. Weitere Vorschlaege (Einfuehrung, Ziehen auf Halter, Bester Aufbau,
   Speichern, Haptik) -- unbewertet.

Playtest ohne Bildschirm: `godot --headless --path . --script
res://tools/playtest/playtest.gd -- 30 5003` (Kaempfe, Seed mit Aktionslog).
Nach Aenderungen an `parts/` immer `python3 tools/bake_godot_assets.py` --
das Spiel liest die Kopie unter `assets/parts/`.
