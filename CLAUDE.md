# CyberDrome -- Arbeitsnotizen fuer Claude

Godot 4.7 (GL Compatibility), GDScript. Ausfuehrliches Design in
`docs/GAME_DESIGN.md`, Bedienung und Struktur in `README.md`.

**Zuerst lesen: `docs/PROJEKTSTAND.md`** -- was gebaut, gemessen und
entschieden ist, bekannte Schwaechen, offene Punkte und wie man im Browser
als Handy testet.

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

* Auf `main` scheitern seit laengerem 9 Pruefungen in `test_aggro`,
  `test_battle` und `test_ui_pieces` (Balancing, Vorschau). Neue Arbeit
  vergleicht gegen diesen Stand, nicht gegen "alles gruen".
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
* Spielfeld bleibt 20x20; die Kamera folgt dem Geschehen, Zoomen und Ziehen
  per Finger.
* Das Spiel ist ein **Autobattler**: die KI steuert beide Seiten
  (`AIController`), der Spieler entscheidet ueber Aufbau und Auswahl.

## Offene Designpunkte (noch zu besprechen)

1. **Faehigkeiten loesen automatisch aus.** Skills von Waffen und Kernen
   sollen nach einer bestimmten Zeit oder nach einer Anzahl Treffer von selbst
   ausloesen, statt von der KI "gezogen" zu werden.
2. **Skill-Tiefe vereinfachen.** Nicht das *Wann* soll einen Skill taktisch
   machen (das steuert der Spieler im Autokampf nicht), sondern das *Womit*:
   in Kombination mit welchen Aufbauten er wirkt. Synergien zwischen Teilen
   und DROMEs statt Timing.
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

## Naechste Schritte (Stand 4. November 2026)

1. Entscheidungen aus `docs/PLAYTEST_2026-11.md`, Abschnitt 6, mit dem
   Spieler klaeren: Bewegung (Kampfdistanz, Bewegung als Rolle), Ausloeser der
   Faehigkeiten (Waffen zaehlen Angriffe, Gadgets Zeit/Ereignis), Energie und
   Kern als Synergie-Teil, Richtungsregel.
2. Die offenen Designpunkte oben (Eingreifen ueber Aggro-Platz 1).
3. Weitere Vorschlaege (Einfuehrung, Ziehen auf Halter, Bester Aufbau,
   Speichern, Haptik) -- unbewertet.

Playtest ohne Bildschirm: `godot --headless --path . --script
res://tools/playtest/playtest.gd -- 30 5003` (Kaempfe, Seed mit Zuglog).
