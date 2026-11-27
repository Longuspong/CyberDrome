# Skilltrees und Identitäten -- Entwurf (22. Nov. 2026)

Stand: **Richtung entschieden (Spieler 21./22. Nov. 2026), Schablone ist ein
Entwurf zum Absegnen, nichts davon gebaut.** Ziel: feste Regeln, nach denen
jeder DROME und jede Waffe gemacht wird -- wer etwas Neues entwirft, füllt
immer dieselbe Schablone aus.

## 1. Entschieden

* **Keine Erfahrung mehr.** Level kommen nur noch über Ressourcen
  (Factory-Builder / Ressourcen-Sammeln, Form noch offen).
* **DROMEs und Waffen: je 5 Level** (Waffen bisher 10 -- sonst wird der Baum zu groß).
* **Je Level ein Punkt im Skilltree.** Der Baum hat mehr Knoten als Punkte:
  man wählt, nicht alles ist zu haben.
* **Leitlinie, kein Korsett (Spieler 24. Nov. 2026).** Die Regeln hier sind
  Rahmen und Inspiration; die Form bleibt einheitlich, im Einzelfall darf man
  abweichen. Keine Regel, die im Kampf nichts aendert.
* **Knoten 1, 2, 4: Werte** -- duerfen sich auf die Ressource beziehen (je Stapel,
  ab 2 Stapeln). **Knoten 3 ist ein bedeutender Knoten** und darf eine kleine
  Regel sein, die den Strang festigt (24. Nov. 2026).
* **Knoten 5 verändert die Identität:**
  DROME -> die **Passive**, Waffe -> die **aktive Fähigkeit**.
* **Umskillen geht, kostet Ressourcen.** Spieler 24. Nov. 2026: Umskillen = den DROME **verwerten
  und neu bauen** (relativ großer Einsatz; Verwerten gibt Zutaten zurück, Fraktions-DROMEs ihr
  Spezialteil -- `FACTORY_KONZEPT.md` 13). Kein eigener Umskillen-Preis.
* **Fraktionsvarianten** haben die Identität des Standard-DROME **plus einen Twist**
  (z. B. Neon Vireo = Vireo mit Ninja-Einschlag).
* **Charger bleiben** das individuelle Upgrade einer Waffe -- an der Waffe, wie heute.
  Der Skilltree ist die dauerhafte Ebene, Amps/Fusionen bleiben im Einsatz.

## 2. Schablone DROME

| Feld | Inhalt |
|---|---|
| Name, Untertitel | z. B. Vireo · CyberDrome |
| Rolle | Plänkler, Tank, Schütze, Unterstützer ... |
| Werte (Level 0) | Speed, Integrität, Schild, Schildpuls, Rüstung, Power, Effizienz, Modulplätze |
| Passive | eine Regel, die den Spielstil trägt |
| Twist (nur Variante) | fester Zusatz zur Passive, z. B. Ninja-Einschlag |
| Baum | 2 Stränge (Spielstil A / B), je Level 1 Knoten je Strang; L1, 2, 4 Werte, L3 bedeutend, L5 Keynode |
| Nische | jeder Strang lohnt sich gegen eine andere Gegnerart (Einzelziel / Schwarm / Tank) |

## 3. Schablone Waffe

| Feld | Inhalt |
|---|---|
| Name, Halter | leicht / mittel / schwer |
| Angriff | Reichweite, Schaden, Intervall |
| Fähigkeit | was sie tut, Takt (jeder N-te Angriff) |
| Baum Level 1-4 | je Level 2 Werte-Knoten zur Wahl (Schaden, Intervall, Reichweite, Takt ...) |
| Baum Level 5 | Modifikator der Fähigkeit: Standard + 2 Varianten |
| Charger | 6 Phasen, wie heute (CHARGER_KONZEPT.md) |

## 4. Beispiel Blaster (Spieler 22. Nov. 2026)

Fähigkeit heute: Doppelschuss, jeder 3. Angriff, 3 Salven à 2 Schüsse.

Ohne Knoten 5 schießt der Blaster **Standard**: 6 Schüsse in 3 Salven à 2.
Auf Level 5 stehen **3 Knoten** zur Wahl (Spieler 22. Nov. 2026):

| Knoten 5 | Wirkung | wogegen |
|---|---|---|
| **Fokus** | 1 Salve, alle Schüsse auf ein Ziel, dafür nur 5 | einen Gegner herausnehmen (Elite-DROME) |
| **Streuung** | alle Schüsse gleich verteilt auf alle Ziele in Reichweite | viele Gegner (Sentinel-Schwarm) |
| **Trippel** | 2 Salven à 3 Schüsse statt 3 à 2 | gleichmäßiger Druck |

## 5. Beispiel Vireo / Neon Vireo (Spieler 22. Nov. 2026, Richtung entschieden)

### Passive Cyberspeed

**Gebaut 25. Nov. 2026** (Grundform, `Unit.on_attack`, `config.json` -> `passives.cyberspeed`;
ersetzt den Sprint `hit_rush`). Die Faehigkeit zaehlt als Angriff; laeuft die Dauer ab,
fallen Stapel und Zaehler. Im Kampf: ein Sprint-Symbol je Stapel, Booster heller.

* Jeder **3. Angriff** gibt Vireo **1 Stapel Cyberspeed**, höchstens **3 Stapel**.
* **Dauer 3 s** (eigener Zeitgeber, nicht der globale Puls): jeder Angriff
  innerhalb der Dauer hält die Stapel am Leben und startet die Dauer neu.
  Ablauf: 3 Angriffe -> 1. Stapel, weitere Angriffe halten ihn, der nächste
  3. Angriff -> 2. Stapel usw. Bei vollen Stapeln wird nur die Dauer neu
  gestartet -- bei Dauerbeschuss bleiben alle Stapel.
* Je Stapel **+10 % Angriffstempo** (wie der Amp) und **+10 % Lauftempo**.
* Damit hält es mit jeder Waffe (Blaster 1,4 s, Plasmaklinge 1,0 s < 3 s).
* **Effizienz verlängert die Dauer** (wie bei allen Statuseffekten).
  Neon Vireo als Tech-Plänkler: Angriffstempo + Effizienz, die Schwächung der
  Plasmaklinge hält länger und schwächt stärker.

### Mittlere Knoten (Level 1-4)

Werte -- dazu zählen auch die Werte der Passive, z. B.:
* **+1 höchste Stapelzahl** (4 statt 3),
* **Stapel schon nach 2 Angriffen** statt 3.

### Keynodes (Level 5) -- verbrauchen Stapel

| Keynode | Kosten | Wirkung |
|---|---|---|
| Überladung | 2 Stapel | 10 s lang **+3 Power** (fester Wert statt Prozent, damit es mit Power-Amps nicht aufschaukelt) |
| Blink | 3 Stapel | Teleport hinter das am weitesten entfernte Ziel, aber nur so weit, dass es in Reichweite der Waffe bleibt (Blaster/Klingeang: ein Feld dazwischen) |
| Kettenschlag | alle Stapel, beim Einsatz der Fähigkeit | je Stapel 1 Sprung mit 10 % Schaden je Stapel: 1 Stapel = 1 weiteres Ziel mit 10 %, 2 = 2 Ziele mit 20 %, 3 = 3 Ziele mit 30 %, 4 = 4 Ziele mit 40 %. Bei zu wenigen Zielen springt sie aufs erste zurück. Reihenfolge: erst Stapel gewinnen, dann verbrauchen. |

### Vireo-Baum (Vorschlag 24. Nov. 2026, nicht entschieden)

Ersetzt die Mittleren Knoten und Keynodes oben. Zwei Stränge: **Halten** (zäh,
konstant) und **Ausgeben** (Burst). Mischen erlaubt.

| Level | Halten | Ausgeben |
| --- | --- | --- |
| 1 | +1 Rüstung je Stapel | Stapel schon nach 2 Angriffen |
| 2 | Lauftempo je Stapel 20 % statt 10 % | Angriffstempo je Stapel 15 % statt 10 % |
| 3 ★ | Obergrenze 4, Stapel verfallen einzeln statt alle | +10 % Schaden je Stapel |
| 4 | +X Schild je Stapel (X offen) | ab 2 Stapeln +1 Power, fest |
| 5 | **Doppelschlag:** ab 3 Stapeln trifft jeder Grundangriff ein zweites Mal mit 40 %; der zweite Treffer zählt nicht für Takt, Stapel oder Effekte. Stapel bleiben. | **Schnitt:** bei vollem Stapel verbraucht der nächste Angriff alle, +25 % je Stapel; Vireo läuft durch das Ziel aufs Feld dahinter (belegt: bleibt stehen), der Treffer springt mit 50 % auf einen Nachbarn. |

Gestrichen gegenüber dem ersten Entwurf: Dauer 4 s (wirkungslos, jede Waffe ist
schneller als 3 s) und „Treffer aus maximaler Reichweite“ (Regel statt Wert,
bei der Plasmaklinge immer aktiv). „Doppelpuls“ heißt Doppelschlag, weil Puls
der 3-s-Takt ist.

### Neon Vireo: Neon-Strang ersetzt Halten (Vorschlag 24. Nov. 2026)

Neon heißt „Ehrkodex, kein Kiten, kein Zurückweichen“, der Neon Vireo hat mehr
Energieschaden und Schild (STORY_LEITFADEN). Halten (Lauftempo, Rüstung) passt
eher zu Mecha, also ersetzt der Neon-Strang Halten; Ausgeben bleibt.

| Level | Neon |
| --- | --- |
| 1 | +X Schild je Stapel |
| 2 | +8 % Energieschaden je Stapel |
| 3 ★ | Obergrenze 4. **Ehrkodex:** kitet nicht, wechselt das Ziel nicht, bis es fällt; gegen dieses Ziel +5 % je Stapel |
| 4 | +2 Effizienz |
| 5 | **Schattenschritt:** 4 Stapel verbrauchen, 3 s unsichtbar, zum am stärksten verwundeten Gegner; erster Treffer +30 % als Energieschaden. Fällt das Ziel, kommen 2 Stapel zurück. |

**Warum dann noch zwei Stränge?** Weil jeder Strang eine Nische über die
Gegnerart hat, nicht über den DROME: Neon ist Einzelziel (Elite, Boss) und hängt
an Tanks fest, Ausgeben/Schnitt springt und taugt gegen Schwärme. Wäre Neon
immer besser, wäre es ein Fehler und nur eine Keynode wert. Mit nur einem
Strang gäbe es auf Level 1-4 keine Wahl mehr.

Werte zum Vergleichen und Eintragen: `docs/spot/CyberDrome_Werkblatt_DROMEs_Waffen.xlsx`.

### Neon Vireo (Twist im Baum) -- älterer Gedanke (22. Nov.)

* Verstärkt den Blink, **oder** eine Keynode wird ersetzt durch
  **Schattenschritt**: 4 Stapel (braucht also den Knoten +1 Stapel) -> 3 s
  (eine Dauer) **unsichtbar**, geht zum am stärksten verwundeten Gegner und
  nimmt ihn ins Visier.
* Die Optik (Fraktionsfarben) ist nur Optik.

### Unsichtbar -- Regel (Vorschlag zum Glattziehen)

* Kann nicht als Ziel gewählt werden; wer ihn im Visier hat, sucht sich ein
  neues Ziel.
* Flächen (Vortex) treffen ihn weiter -- so bleibt Gegenspiel.
* Der erste eigene Angriff beendet die Unsichtbarkeit vorzeitig und bekommt
  einen kleinen Bonus (Vorschlag: +30 % Schaden).
* Dieselbe Regel gilt später für jeden (Bosse, Sentinels).

### Hinweis Fähigkeiten

Der Takt der Fähigkeiten wird beim Waffen-Rework etwa verdoppelt (Spieler
22. Nov. 2026) -- dann fallen Stapel-Angriff und Fähigkeit seltener zusammen.

## 5b. Leitlinie für alle DROMEs: eine Ressource je DROME (wo es passt)

Jeder DROME bekommt eine eigene Ressource nach demselben Muster wie Cyberspeed:
**Gewinn** (z. B. jeder N-te Angriff), **Obergrenze**, **Dauer** (hält bei
Aktivität), **Wirkung je Stapel**. Mittlere Knoten verändern Gewinn und
Obergrenze, Keynodes **dürfen** die Ressource verbrauchen (kein Muss, 24. Nov.).
Der Fraktions-Twist ersetzt einen Strang (bei schwächerer Identität nur eine
Keynode). Nicht jeder DROME braucht eine komplexe Ressource: der Molok steht
ohnehin vorn (Locken läuft ins Leere), seine Passive soll ihn mehr aushalten
lassen (Vorschlag „Standfest“ im Werkblatt). Molok, Nimbus und Strix bekommen
neue, wirksamere Passiven nach diesem Muster (noch zu besprechen).

## 5c. Anzeige von Effekten im Kampf (erster Gedanke des Spielers, noch zu besprechen)

* **Buffs:** Dreieck, Spitze nach oben, **links** neben der Lebensleiste.
* **Debuffs** (Slow, Schwäche ...): Dreieck, Spitze nach unten, **rechts**.
* Je Wert eine Farbe, z. B. Tempo hellblau: hellblau nach oben = schneller,
  nach unten = verlangsamt. Die Stapelzahl steht im Dreieck.
* **Elementar-Stapel** über der Lebensleiste als Sechsecke, die Zahl unten
  rechts in einer Box (auf jedem Hintergrund lesbar).
* Später: Elemente, die miteinander reagieren, ziehen sich wie magnetisch an
  und verschmelzen zum Effekt.

## 5d. Level-Material (Spieler 24. Nov. 2026, entschieden; Zahlen Vorschlag)

* **Bezahlt wird mit Fabrik-Waren, steil ansteigend:** Level 1-2 machbar (Tier-1-Waren:
  Legierung, Plasma, Schaltkreis), Level 3 ein deutlicher Sprung (Tier 2: Panzerplatten,
  Upgrade-Chips), Level 4-5 „nochmal eine Schippe drauf“ -- man soll sich überlegen, welchen
  DROME man zuerst hochzieht und wie viele man braucht.
* **Mischung wie beim Bauen** (`FACTORY_KONZEPT.md` 13): Molok vor allem Platten + Legierung,
  Nimbus Chips + Plasma, Vireo Plasma, Strix Chips + Platten. Waffen etwa die Hälfte, nach
  Gewichtsklasse (leicht Schaltkreis/Plasma, schwer Legierung/Platten).
* **Level 5 braucht zusätzlich einen Keynode-Chip** -- seltene Belohnung:
  * nach einem **Einsatz**: beim ersten Abschluss eines Einsatzes garantiert einer, danach je
    Einsatz eine Chance von 10-20 % (Vorschlag 15 %);
  * aus **Caches**: häufiger als der Fraktionskern (2,5 %), seltener als Rohlinge (12 %) --
    Vorschlag 5 % je Wurf.
* **Zahlen-Vorschlag Vireo** (Faktor je Level etwa 1 / 1,5 / 4 / 9 / 16):

  | Level | Kosten |
  |---|---|
  | 1 | 40 Plasma + 20 Schaltkreis |
  | 2 | 60 Plasma + 40 Legierung |
  | 3 | 15 Panzerplatten + 15 Upgrade-Chips |
  | 4 | 35 Panzerplatten + 35 Upgrade-Chips |
  | 5 | 60 Panzerplatten + 60 Upgrade-Chips + 1 Keynode-Chip |

  Level 3-5 zusammen ≈ 2,5 × die Platten eines ganzen Vireo -- mit einem Verdichter rund
  7 Einsätze, mit gut ausgebauter Platine 3-4.
* **Umskillen = verwerten und neu bauen** (Abschnitt 1): der DROME beginnt wieder bei Level 0.
* **GEBAUT (24. Nov. 2026):** keine EP mehr (`Leveling.xp_enabled()` = false), Level kaufen auf der
  DROME-Seite (Reiter DROME und die Klappe „Level und Skilltree der Waffe“, `Workbench.level_up_*`),
  Waffen bis Level 5 (Schaden +14 % je Level, Endwerte wie vorher auf Level 10). Kosten für alle vier
  Chassis und je Gewichtsklasse in `data/factory.json` → `level`, SPOT-Blatt Fabrik. Jedes Level
  wirkt vorerst wie bisher auf die Werte; die Skilltree-Knoten folgen.
* **Keynode-Chip-Raten vorläufig** (Spieler: „zu häufig“ bei jedem ersten Abschluss, später
  besprechen): nur der **allererste** gewonnene Einsatz gibt sicher einen, danach 15 % je
  gewonnenem Einsatz, Caches 5 % je Wurf.

## 6. Offen (SPOT-Blatt Offene Punkte)

1. Ressourcen: Sorten und Zahlen je DROME/Waffe nach 5d festlegen (Platzhaltercoins bleiben vorerst).
2. Form des Baums: Knoten je Level (Vorschlag 2, Level 5 Standard + 2).
   Knoten 1-4 sind Werte -- auch Werte der Passive (Stapelzahl, Gewinn-Takt).
3. ~~Kosten fürs Umskillen~~ -- verwerten und neu bauen (24. Nov. 2026).
4. Identitäten aller DROMEs und Waffen neu fassen; Twist je Fraktionsvariante.
5. Passiven Molok, Nimbus, Strix nach 5b; Unsichtbar-Regel (5) bestätigen;
   Anzeige der Effekte (5c) besprechen; Takt der Fähigkeiten beim Waffen-Rework.
6. Bestehende Level (DROME 0-5, Waffe 0-10) in alten Spielständen umrechnen.
