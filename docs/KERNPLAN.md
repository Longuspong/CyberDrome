# CyberDrome – Kernplan

## Ziel

Der Kernmoment: Nach dem Theorycrafting im Hangar bekommt man im Lauf die erhofften Module, der Build ist komplett und der Einsatz gelingt mit Leichtigkeit. Alles in dieser Phase dient nur dazu, diesen Moment spielbar zu machen.

## Was zum Kern gehört

- Autobattler-Kampf mit Roguelike-Lauf
- Drei DROMEs:
  - **HX-Molok**: klassischer Tank, Nahkampf
  - **RX-Vireo**: agiler Kämpfer auf mittlerer Distanz, stapelt Buffs durch Angriffe (Passive Cyberspeed, Booster auf dem Rücken), in verschiedene Richtungen skillbar
  - **LR-Strix**: fragiler Scharfschütze mit großer Reichweite, eine Variante mit direktem und eine mit indirektem Schaden
- Passiven der drei DROMEs ausformulieren und umsetzen
- **Waffen (27. Nov. 2026):** zuerst je DROME eine passende Kernwaffe -- Vireo Puls-Blaster,
  Molok Deflektor (Gunship; Hammer als Alternative), Strix Schienen-Lanze, Nimbus Repair-Kit
  (seit 27. Nov. abends, der E-Schraubenschlüssel kehrt als Heilwaffe zurück; Runenstab beim Neon Nimbus) --, die Alternativen zum
  Builden kommen danach (die Plasmaklinge des Vireo ist die erste). Entfernt als
  Brainstorming-Reste: Bollwerk-Ramme, E-Schraubenschlüssel (Drohnen-Pod), Klingenbumerang,
  Neon-Blaster, Mörser -- mit Code, Daten und Tests.
- Amps: bereits fertig, es fehlt nur noch die Grafik für den Armor Amp
- Fusions überarbeiten
- BIOS überprüfen

## Was erst mal wartet (Ideen-Branch)

- AR-Nimbus -- wird laut Werkblatt (27. Nov. 2026) ein **Supporter** (Repair-Kit, Passive Cleancode); der heutige Nimbus (Runenstab, Echo, Skill-DPS) lebt als **Neon Nimbus** weiter
- Endlos-Modus, Story, Fraktionen
- Android-Version
- Feinabstimmung von Gegnerzahl und Gegnerkurve
- Alle neuen Ideen, die während dieser Phase auftauchen: als Prototyp im Ideen-Branch, nicht auf main

## Vorgehen

1. In kleinen Runden arbeiten: eine Passive einbauen, mit den vorhandenen Amps testen, nachschärfen. DROMEs und Module abwechselnd, nicht nacheinander.
2. Mit dem Vireo und Cyberspeed anfangen, weil seine Identität am klarsten ist.
   **Stand 25. Nov. 2026:** Cyberspeed gebaut (Grundform ohne Skillknoten, ersetzt den
   alten Sprint `hit_rush`; Werte in `data/config.json` -> `passives.cyberspeed`).
   Nächster Schritt: mit den vorhandenen Amps testen und nachschärfen.
   **Stand 27. Nov. 2026:** Molok-Passive Safe Haven, Molok als Gunship und Strix-Passive
   Focuslense gebaut (Werkblatt, `SKILLBAUM_KONZEPT.md` 5e). Damit haben alle drei Kern-DROMEs
   ihre Passive; als Nächstes im Playtest nachschärfen.
3. Fusions und BIOS **überarbeiten, nicht neu bauen**. Das Modulsystem wird kein drittes Mal komplett aufgerissen.
4. Veraltete Fragmente entfernen, sobald ein System steht (zum Beispiel den Kern-Halter in der README). **Erste große Runde am 26. Nov. 2026** (Stand in `PROJEKTSTAND.md`).

## Fragmente finden und entfernen

Ein Fragment ist alles im Repo, das zu einer verworfenen Entscheidung gehört. Gesucht wird in drei Schritten: Doku, Daten, Code.

1. **Entscheidungsliste anlegen.** Aus PROJEKTSTAND.md, NEUANFANG.md und den Pull Requests alles notieren, was gestrichen oder ersetzt wurde. Bekannte Beispiele: Taktikspiel mit Zügen, Aktionsring und Energie, Kerne mit Werten und Kern-Halter, Belagerungskanone, Modulstufen und Rezeptketten, SVG-Werkstatt, Excel-Liste.
2. **Nach Begriffen suchen.** Jeden gestrichenen Begriff per Volltextsuche im ganzen Repo suchen, zum Beispiel mit `git grep -n "Kern-Halter"`. Jeder Treffer ist ein Kandidat.
3. **Doku prüfen.** README, GAME\_DESIGN.md, CLAUDE.md und parts/README.md gegen den aktuellen Stand lesen. Was veraltet ist, wird gelöscht oder klar als veraltet markiert. Ein Beispiel ist der Kreis als Kern-Halter in der README.
4. **Daten prüfen.** config.json, formations.json und die Teil-JSONs auf Schlüssel durchsehen, die kein Code mehr liest.
5. **Code prüfen.** Skripte, Szenen und Funktionen suchen, die nirgends mehr aufgerufen werden. Godot zeigt ungenutzte Dateien teilweise im Editor an, ansonsten hilft die Suche nach dem Dateinamen.
6. **Sicher entfernen.** Pro Thema ein eigener Commit, damit man jeden Schritt einzeln zurücknehmen kann. Nach jedem Commit die Tests laufen lassen.
7. **Ideen retten, nicht löschen.** Was nur verschoben und nicht verworfen ist, kommt mit einer kurzen Notiz in den Ideen-Branch statt auf main.

Danach gilt eine Regel: Wer ein System verwirft, entfernt im selben Pull Request auch seine Reste aus Doku, Daten und Code.

## Molok: Neudefinition (Stand 25. Nov. 2026)

Der Molok ist ein reiner Frontliner: Er hält vorne, macht wenig eigenen Schaden und lebt vom Team.

**Entschieden**

- **Alte Passive raus:** Präsenz (Locken und Abfangen) entfällt komplett. Sie stammt aus der Tactics-Zeit und arbeitet gegen seine Vanguard-KI.
- **Doppelwaffe (Gunship-Prinzip, GEBAUT 27. Nov. 2026):** Eine Waffe wird ausgerüstet und erscheint an beiden Armen, jeweils mit vollen Werten. Die Arme feuern versetzt im Wechsel. Jeder Arm hat seinen eigenen Takt-Zähler und löst seine Fähigkeit selbst aus. Standardwaffe ist der Deflektor (Werkblatt).
- **Gemeinsame Modulreihe:** 2 Modulplätze statt 3. In der Ansicht: Waffe, 2 Mods, Waffe. Waffenmods wirken auf beide Waffen.
- **Werte-Amps zählen einmal:** Power, Panzerung, Integrität und Schild gehen einmal aufs Chassis und nicht pro Arm.
- **Power auf 4:** Ausgleich für die doppelte Waffe. Wird bei Bedarf nach Playtests angehoben.
- **Kein Schaden aus Verteidigung:** Keine Passive, die Rüstung oder Integrität in Schaden umwandelt, damit Abwehr kein Gewinn auf beiden Seiten wird.
- **Strix-Verhalten bleibt:** Gegnerische Strix wechseln auf Damage-Dealer, sobald diese in Reichweite sind. Das ist gewollt, weil es das Risiko des Vireo und die Rolle des Strix stärkt.

**Passive (gebaut 27. Nov. 2026, Arbeitsname „Festung“)**

- Der Molok erhält alle Heilungen, Regenerationen und Schildgaben um 20 % verstärkt (`passives.fortress`).
- Die Quelle dafür sind seine Tankwaffen: Der Hammer-Betäubungsschlag (kinetisch) heilt um 100 % des Schadens (Spieler 27. Nov.; ersetzt die 50 % aus dem Entwurf). Die +20 % der eigenen max. Integrität als Schaden gab es nur wenige Stunden -- am Abend wieder entfernt (Hammer zu stark), damit gilt „Kein Schaden aus Verteidigung“ wieder ohne Ausnahme. Der Deflektor liefert Schild. So wird das Tragen der Tankwaffen belohnt; ein Molok mit anderen Waffen verzichtet bewusst darauf.
- Keine eigene Regeneration pro Puls (verworfen, die Tankwaffen übernehmen das).
- Ein richtiger Heiler oder Support kommt später.
- Virusschaden wird von der Passive nicht ausgeglichen.
- Im Playtest prüfen: Die Hammer-Heilung hängt am Schaden und wächst mit der Power mit. Testfall: Gunship-Hammer (zwei Arme) plus Lebensentzug-Fusion, damit er nicht unknackbar wird.

**Offen**

- ~~Name der Passive~~: **Safe Haven** (Werkblatt 27. Nov. 2026; Arbeitsname war Festung, verworfen: Lockdown)
- Höhe der eigenen Regeneration pro Puls
- On-Hit-Effekte lösen durch die zwei Arme doppelt aus. Bewusst als Belohnung lassen oder über einen Proc-Koeffizienten am Chassis abschwächen?
- Kontrolleffekte (Hammer-Stun) bei doppelter Frequenz und voller Dauer: Gefahr von Dauer-Stun prüfen.
- Rammbock-Fusion (Rüstung zu Schaden) im Zuge des Fusions-Umbaus prüfen.
- Fragmente entfernen: ~~Präsenz in Code, Config und Tests~~ (26. Nov.), ~~veraltete Lebenspunkte in CLAUDE.md~~ (26. Nov., Abschnitt entfernt); ~~Präsenz in NEUANFANG.md~~, ~~Bollwerkkern~~, ~~leerer Molok-Kopf als Platzhalter~~ (26. Nov., der Kopf ist wieder ein eigenes Teil).

## Fertig, wenn

- jede der drei DROMEs mindestens einen Build hat, der den Kernmoment auslöst,
- dieser Build in einem normalen Lauf spielbar erreichbar ist,
- und sich der Moment beim Testen tatsächlich gut anfühlt.

Erst danach wird über die Punkte im Ideen-Branch entschieden.
