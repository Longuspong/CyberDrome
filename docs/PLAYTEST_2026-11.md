# Playtest November 2026 -- wo das Autobattler-Prinzip ruckelt

Gespielt mit `tools/playtest/playtest.gd`: 30 Chaos-Kaempfe, Start-Squad
(Vireo, Molok, Nimbus, Strix) gegen gewuerfelte Gegner in voller Chaos-Staerke,
KI auf beiden Seiten, Overtime an. Dazu ein Kampf Zug fuer Zug mitgelesen
(Seed 5003).

```bash
godot --headless --path . --script res://tools/playtest/playtest.gd -- 30 5003
#                                                    Kaempfe ^   ^ Seed mit Zuglog
```

## 1. Zahlen (eigene DROMEs, je Zug)

| DROME | Werte | leere Zuege | Felder gelaufen | Schaden | Abstand beim Angriff | zerstoert |
|---|---|---|---|---|---|---|
| Molok  | SPD 5, MOV 2  | **50 %** | 1,1 | 3,3  | 3,0 | 63 % |
| Nimbus | SPD 13, MOV 5 | 31 % | 3,3 | 6,3  | 1,6 | **93 %** |
| Strix  | SPD 8, MOV 4  | 17 % | 2,0 | 13,8 | 6,4 (vorher 4,4) | 63 % (vorher 83 %) |
| Vireo  | SPD 13, MOV 4 | 36 % | 2,3 | 2,2  | 2,5 | 93 % |

Ergebnis: 9 von 30 gewonnen vor der KI-Korrektur unten, 11 bis 14 von 30 danach,
im Schnitt ~10 Zyklen. Der Gegner ist laut Chaos-Auswahl "etwas schwaecher",
gewinnt aber die Mehrheit.

## 2. Was auffaellt

1. **Strix lief nach dem Schuss in den Gegner -- behoben.** Hatte ein DROME
   nichts mehr zu tun, lief er mit den restlichen Bewegungspunkten auf den
   naechsten Gegner zu. Ein Strix mit Reichweite 8 schoss und marschierte
   danach ins Handgemenge, wo ihn Orbit-Sog und Moerser erwischten. Jetzt sucht
   ein Fernkaempfer nach dem Angriff ein sichereres Feld, von dem er weiter
   schiessen kann (`AIController._settle_step`).
2. **"Strix schiesst kaum orthogonal":** Im Spiel gibt es **keine Regel**, nach
   der ein gerader Schuss mehr Schaden macht. Das Raster kennt vier Richtungen,
   die Reichweite ist eine Raute (Felder in x plus Felder in y), und der Schaden
   haengt nicht an der Richtung. Wenn du das willst, waere es eine neue Regel,
   zum Beispiel "die Lanze durchschlaegt alles in gerader Linie". Siehe 4.
3. **Molok ist kaum im Kampf.** SPD 5 und MOV 2: er kommt selten dran und
   kommt dann kaum voran. Die Startzonen liegen rund 22 Felder auseinander, er
   braucht vier bis fuenf Zyklen bis zur ersten Salve, und der Kampf dauert
   zehn. Die Haelfte seiner Zuege tut er nichts ausser laufen.
4. **Nimbus stirbt fast immer zuerst.** Schnell (SPD 13, MOV 5) und mit einer
   Nahkampfwaffe rennt er allein voraus, kommt als Erster an und wird von allen
   gleichzeitig beschossen.
5. **Die ersten zwei Zyklen sind leer.** Alle laufen nur aufeinander zu. Im
   Autokampf heisst das: zuschauen, wie nichts passiert.

## 3. Wo das Tactics-RPG noch drinsteckt

| Ueberbleibsel | Warum es im Autobattler stoert |
|---|---|
| Bewegungspunkte je Feld, Stufen, Rutschflaechen, Dampf | Im Taktik-Spiel eine Entscheidung des Spielers; hier entscheidet die KI, und der Spieler sieht nur, dass jemand stehen bleibt oder rutscht. Langsame Aufbauten verlieren dadurch ganze Kaempfe. |
| Weite Startdistanz auf 20x20 | Fuer Manoeuvrieren gedacht. Im Autokampf ist das Anlaufzeit ohne Inhalt. |
| Zug fuer Zug, mehrere Schritte je Zug | Gut lesbar fuer einen Spieler, der selbst plant; im Zuschauen langsam. |
| Faehigkeiten ueber Energie, Abklingzeit, "einmal pro Zug" | Drei Bremsen, die die KI abwaegt. Der Spieler kann nicht vorhersehen, wann etwas kommt -- genau das soll Designpunkt 1 loesen. |
| Provokation, Aggro-Gewichte, Rettungsbonus | Sehr viel Regel fuer etwas, das der Spieler nicht sieht. Wird mit "Aggro-Platz 1" vermutlich einfacher. |
| Code des manuellen Kampfs (Aktionsring, Zug beenden, Rueckgaengig) | Nicht mehr erreichbar, aber noch da. Kann raus, sobald das Eingreifen entschieden ist. |
| Overtime | Noetig, weil Kaempfe sonst haengen bleiben -- ein Symptom von oben. |

## 4. Vorschlag: Bewegung neu denken

**Empfehlung: A jetzt, B danach; C zusammen mit dem Eingreifen besprechen.**

* **A -- Kampfdistanz verkuerzen.** Startzonen naeher zusammen (etwa 8 statt
  22 Felder Abstand), Spielfeld bleibt 20x20. Der Kampf beginnt nach einem
  Zug statt nach zwei Zyklen, und Molok ist von Anfang an dabei. Kleiner
  Eingriff, sofort spuerbar.
* **B -- Bewegung als Rolle statt als Zahl.** Jeder DROME bewegt sich nach
  seiner Waffe: Nahkaempfer ruecken bis zum Kontakt vor, Fernkaempfer halten
  ihre Reichweite und weichen aus, Schwere ruecken langsam, aber stetig nach.
  MOV unterscheidet nur noch wenig (zum Beispiel 3 bis 5 statt 2 bis 5).
  Gelaende bleibt Optik plus wenige klare Wirkungen (Dampf: Deckung).
* **C -- Formation vor dem Kampf.** Der Spieler stellt vorn/hinten auf, wie in
  vielen Autobattlern. Das ist ein Hebel, der zu "der Spieler entscheidet den
  Aufbau" passt -- und mit "Aggro-Platz 1" zusammen eine gute Eingreif-Idee.

## 5. Vorschlag: Faehigkeiten loesen selbst aus

Deine Idee "nur die Ausruestung hat Faehigkeiten" ist im Code schon fast so:
Faehigkeiten haengen heute nur an Ausruestung. Die Kern-Passiven aus der
Balancing-Tabelle (`data/balancing/ausruestung_stats.json`) sind nie gebaut
worden. Kerne liefern nur Werte.

**Regel-Vorschlag:** Waffen zaehlen ihre Angriffe, Gadgets laufen auf Zeit
oder Ereignis. Die Faehigkeit **ersetzt** den faelligen Angriff (der dritte
Blaster-Schuss *ist* die Streusalve), statt zusaetzlich zu kommen -- so bleibt
das Tempo gleich und jeder kann mitzaehlen. Der Zaehler steht in der Kachel
oben ("Streusalve 2/3").

| Teil | Faehigkeit | Ausloeser (Vorschlag) |
|---|---|---|
| Puls-Blaster | Streusalve | jeder **3.** Angriff (dein Beispiel) |
| Runenstab | Arkanwelle | jeder **3.** Angriff |
| Schienen-Lanze | Praezisionsschuss | jeder **4.** Angriff (staerkster Einzeltreffer) |
| Belagerungskanone | Sperrfeuer | jeder **3.** Angriff |
| Orbit-Fokus | Orbit-Sog | alle **3** eigenen Zuege, auf das aktuelle Ziel |
| Hologramm-Boost | Boost | wenn ein Gegner direkt danebensteht, hoechstens alle 2 Zuege |
| Deflektor, Drohnen-Pod, Koedersender | -- | passiv, wie heute |

**Was du vielleicht uebersiehst:**

1. **Energie wird ueberfluessig.** Heute bremst Energie die Faehigkeiten. Mit
   festen Ausloesern braucht es sie nicht mehr -- dann verliert der Kern seine
   Hauptaufgabe. Vorschlag: der Kern wird zum **Synergie-Teil**, zum Beispiel
   "Arkankern: jede Faehigkeit einen Angriff frueher" oder "Fusionskern:
   Flaechenfaehigkeiten +1 Radius". Das ist genau Designpunkt 2 (das "Womit"
   statt des "Wann").
2. **Wer waehlt das Ziel der Faehigkeit?** Die KI wie beim normalen Angriff;
   Flaechenfaehigkeiten zielen dorthin, wo sie am meisten treffen.
3. **Was zaehlt als Angriff?** Nur ausgefuehrte Angriffe. Wer nichts in
   Reichweite hat, zaehlt nicht hoch -- sonst kommt die Faehigkeit ins Leere.
4. **Zwei gleiche Waffen:** jede zaehlt fuer sich.
5. **Kampfdauer:** Mit festen Takten haengt die Zahl der Faehigkeiten an der
   Kampflaenge. Zusammen mit Bewegung A (kuerzere Anlaufzeit) wird das
   gleichmaessiger.

## 6. Entscheidungen (4. November 2026)

Der Spieler hat entschieden: **Echtzeit statt Zuege** -- alle DROMEs
bewegen sich und greifen gleichzeitig an, jede Waffe mit eigener
Angriffsgeschwindigkeit; SPD ist die Laufgeschwindigkeit; Faehigkeiten wie in
Abschnitt 5 (die Faehigkeit ersetzt den faelligen Angriff); Energie
gestrichen; Startzonen naeher zusammen. Gebaut im selben PR. Messung danach
(30 Kaempfe, Start-Squad gegen Chaos-Gegner): 20 Siege, 10 Niederlagen, im
Schnitt 33 s, erster Treffer nach rund 3 s; Molok laeuft nur noch ein Viertel
der Zeit. Nimbus (Nahkampf) faellt weiter fast immer -- naechste
Balancing-Baustelle. Spiegelkaempfe: 61 zu 59 ueber 120 Seeds.

Urspruengliche Fragen:

1. Bewegung: A jetzt bauen? Und B als naechsten Schritt?
2. Faehigkeiten: Regel "Waffen zaehlen Angriffe, Gadgets Zeit/Ereignis,
   Faehigkeit ersetzt den Angriff" -- so? Und die Takte aus der Tabelle?
3. Energie streichen und den Kern zum Synergie-Teil machen?
4. "Orthogonal": soll es eine Richtungsregel geben (zum Beispiel Lanze
   durchschlaegt in gerader Linie), oder war das ein Eindruck?
