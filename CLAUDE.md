# CyberDrome -- Arbeitsnotizen fuer Claude

Godot 4.7 (GL Compatibility), GDScript. Ausfuehrliches Design in
`docs/GAME_DESIGN.md`, Bedienung und Struktur in `README.md`.

**Zuerst lesen: `docs/PROJEKTSTAND.md`** -- was gebaut, gemessen und
entschieden ist, bekannte Schwaechen, offene Punkte und wie man im Browser
als Handy testet. **Dann `docs/NEUANFANG.md`** -- der Neuentwurf des
Spielprinzips, der gerade mit dem Spieler besprochen wird.

## Zusammenarbeit

* Der Spieler schreibt Deutsch -- Antworten, Commits und PRs auf Deutsch.
  Code-Kommentare auf Deutsch ohne Umlaute.
* Auf dem vorgegebenen Branch arbeiten, Draft-PR oeffnen; der Spieler merged
  selbst. Nach einem Merge den Branch von `main` neu aufsetzen.
* Designfragen, die das Spiel selbst aendern (Regeln, Balancing, Layout-
  Muster), vorher kurz mit Empfehlung vorlegen.

## Befehle

```bash
godot --headless --path . --script res://tests/run_tests.gd   # Tests
godot --headless --path . --import                            # nach neuer class_name noetig
bash tools/build_web.sh                                       # Web-Export nach build/web
```

* Seit dem Aufraeumen vom 5. Nov. 2026 sind alle Tests gruen -- neue Arbeit
  haelt das so.
* Headless-Hilfsskripte (`extends SceneTree`) duerfen Projektklassen nicht
  direkt referenzieren -- sie kompilieren vor den Autoloads. Logik in ein
  `RefCounted`-Skript legen und zur Laufzeit per `load()` holen (wie
  `tests/run_tests.gd`).
* Gehostet wird auf Vercel (`vercel.json` -> `tools/build_web.sh`).

## Ausrichtung

* **Mobile first, Hochformat ist die Hauptansicht.** Querformat wird
  angeboten, ist aber zweitrangig. Neue Bildschirme werden zuerst fuer
  ein Handy im Hochformat entworfen (ca. 400 CSS-Pixel breit).
* Navigation: Tab-Leiste unten (Spielen, Hangar, Optionen). Der Hangar
  vereint Squad (Karussell, max. 4) und Umbau (Halter als Formen:
  Dreieck leicht, Viereck mittel, Fuenfeck schwer, Kreis Kern; leicht passt
  nach oben in groessere Halter, schwer nur in schwer).
* Spielfeld bleibt 20x20 und ist **frei** (kein Gelaende, keine Sichtlinie
  -- seit 5. Nov. 2026); die Kamera folgt dem Geschehen, Zoomen und Ziehen
  per Finger.
* Das Spiel ist ein **Autobattler in Echtzeit** (seit Nov. 2026): alle
  DROMEs handeln gleichzeitig, keine Zuege. `BattleManager.tick()` rechnet in
  festen Schritten (0,05 s, deterministisch je Seed), die KI (`AIController`)
  steuert beide Seiten. Jede Waffe hat ein Schussintervall, SPD ist die
  Laufgeschwindigkeit, MOV und Energie spielen keine Rolle mehr. Was frueher
  zu Zugbeginn lief (Schild, Reparatur, Overtime ...), laeuft je Puls (3 s).
  Der Spieler entscheidet ueber Aufbau und Auswahl.

## Offene Designpunkte (noch zu besprechen)

1. **Faehigkeiten loesen automatisch aus -- ENTSCHIEDEN und gebaut.** Nur
   Ausruestung hat Faehigkeiten. Waffen zaehlen ihre Angriffe, der N-te
   Angriff IST die Faehigkeit (Blaster, Runenstab, Kanone jeder 3., Lanze
   jeder 4.); Gadgets nach Zeit (Orbit-Sog alle 6 s) oder Ereignis (Boost,
   wenn ein Gegner danebensteht). Steht als `trigger` an der Aktion.
2. **Skill-Tiefe ueber Synergien.** Nicht das *Wann*, sondern das *Womit*.
   Offen: der Kern hat mit dem Wegfall der Energie seine Hauptaufgabe
   verloren -- Vorschlag "Kern als Synergie-Teil" (z. B. Faehigkeit einen
   Angriff frueher) ist noch nicht ausgearbeitet.
3. **Eingreifen des Spielers -- offen, wird spaeter besprochen.** Fest steht:
   grundsaetzlich Autobattler, der Spieler **steuert keine DROMEs**. Er soll
   aber eingreifen koennen, vermutlich indem er festlegt, wer **Aggro-Platz 1**
   hat (eine selbst waehlbare Aggro-Liste). Der Spieler denkt das noch durch --
   nichts davon bauen, bevor es besprochen ist.
4. **Waffen-Slots und Gewichtsklassen ueberarbeiten.** Die Halter der
   Chassis (welche Waffe passt wohin) und die Gewichtsklassen der
   Ausruestungsteile selbst muessen angepasst werden.

Bis diese Punkte entschieden sind: keine groesseren Umbauten an
Faehigkeiten, Slots oder Gewichten auf eigene Faust.

## Naechste Schritte (Stand 5. November 2026)

0. **Neuentwurf umsetzen** (`docs/NEUANFANG.md`, Reihenfolge in Abschnitt 8).
   Erledigt: KI-Grundlagen (Ziel halten, Rolle je Chassis, Fokus); Nimbus
   (Runenstab Rw 3, Vortex, Passive Zauberwirker). Kopf und Antrieb bleiben
   fest am Chassis -- ein DROME wird immer als Ganzes gestaltet.
   Entschieden: 3 Module je DROME, Credits + Laden (Beute gleich wichtig),
   Ausruestung bleibt nach dem Lauf. Offen: Fragen in Abschnitt 6.
   Die Punkte unten gehen darin auf.

1. Echtzeit-Kampf im Spiel ausprobieren und nachjustieren (Intervalle in den
   Teildaten, Tempo und Puls in `data/config.json` -> `realtime`). Nimbus
   faellt noch in 58 % der Kaempfe zuerst, der Strix macht den meisten Schaden.
2. Kern als Synergie-Teil ausarbeiten (Designpunkt 2).
3. Eingreifen ueber Aggro-Platz 1 besprechen (Designpunkt 3) -- passt jetzt
   gut: Gegner im laufenden Kampf antippen.
4. Waffen-Slots und Gewichtsklassen (Designpunkt 4).
5. Weitere Vorschlaege (Einfuehrung, Ziehen auf Halter, Bester Aufbau,
   Speichern, Haptik) -- unbewertet.

Playtest ohne Bildschirm: `godot --headless --path . --script
res://tools/playtest/playtest.gd -- 30 5003` (Kaempfe, Seed mit Aktionslog).
Nach Aenderungen an `parts/` immer `python3 tools/bake_godot_assets.py` --
das Spiel liest die Kopie unter `assets/parts/`.
