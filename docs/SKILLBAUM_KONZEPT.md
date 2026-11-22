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
* **Knoten 1-4: nur Werte.** Keine kleinen Regeln.
* **Knoten 5 verändert die Identität:**
  DROME -> die **Passive**, Waffe -> die **aktive Fähigkeit**.
* **Umskillen geht, kostet Ressourcen.**
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
| Baum Level 1-4 | je Level 2 Werte-Knoten zur Wahl (Vorschlag) |
| Baum Level 5 | 2 Knoten, die die Passive verändern (Spielstil A / B) |

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

* Jeder **3. Angriff** gibt Vireo **1 Stapel Cyberspeed**, höchstens **3 Stapel**.
* **Dauer 3 s** (eigener Zeitgeber, nicht der globale Puls): jeder Angriff
  innerhalb der Dauer hält die Stapel am Leben und startet die Dauer neu.
  Ablauf: 3 Angriffe -> 1. Stapel, weitere Angriffe halten ihn, der nächste
  3. Angriff -> 2. Stapel usw. Bei vollen Stapeln wird nur die Dauer neu
  gestartet -- bei Dauerbeschuss bleiben alle Stapel.
* Je Stapel **+10 % Angriffstempo** (wie der Amp) und **+10 % Lauftempo**.
* Damit hält es mit jeder Waffe (Blaster 1,4 s, Bumerang 1,3 s < 3 s).
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
| Blink | 3 Stapel | Teleport hinter das am weitesten entfernte Ziel, aber nur so weit, dass es in Reichweite der Waffe bleibt (Blaster/Bumerang: ein Feld dazwischen) |
| Kettenschlag | alle Stapel, beim Einsatz der Fähigkeit | je Stapel 1 Sprung mit 10 % Schaden je Stapel: 1 Stapel = 1 weiteres Ziel mit 10 %, 2 = 2 Ziele mit 20 %, 3 = 3 Ziele mit 30 %, 4 = 4 Ziele mit 40 %. Bei zu wenigen Zielen springt sie aufs erste zurück. Reihenfolge: erst Stapel gewinnen, dann verbrauchen. |

### Neon Vireo (Twist im Baum)

* Verstärkt den Blink, **oder** eine Keynode wird ersetzt durch
  **Schattenschritt**: 4 Stapel (braucht also den Knoten +1 Stapel) -> 3 s
  (eine Dauer) **unsichtbar**, geht zum am stärksten verwundeten Gegner und
  nimmt ihn ins Visier.
* Die Optik (Fraktionsfarben) ist nur Optik.

### Unsichtbar -- Regel (Vorschlag zum Glattziehen)

* Kann nicht als Ziel gewählt werden; wer ihn im Visier hat, sucht sich ein
  neues Ziel.
* Flächen (Vortex, Mörser) treffen ihn weiter -- so bleibt Gegenspiel.
* Der erste eigene Angriff beendet die Unsichtbarkeit vorzeitig und bekommt
  einen kleinen Bonus (Vorschlag: +30 % Schaden).
* Dieselbe Regel gilt später für jeden (Bosse, Sentinels).

### Hinweis Fähigkeiten

Der Takt der Fähigkeiten wird beim Waffen-Rework etwa verdoppelt (Spieler
22. Nov. 2026) -- dann fallen Stapel-Angriff und Fähigkeit seltener zusammen.

## 5b. Regel für alle DROMEs: eine Ressource je DROME

Jeder DROME bekommt eine eigene Ressource nach demselben Muster wie Cyberspeed:
**Gewinn** (z. B. jeder N-te Angriff), **Obergrenze**, **Dauer** (hält bei
Aktivität), **Wirkung je Stapel**. Mittlere Knoten verändern Gewinn und
Obergrenze, Keynodes **verbrauchen** die Ressource, der Fraktions-Twist ist
eine eigene Keynode oder verstärkt eine. Molok, Nimbus und Strix bekommen
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

## 6. Offen (SPOT-Blatt Offene Punkte)

1. Ressourcen: Sorten, Factory-Builder, ersetzen sie die Platzhaltercoins?
2. Form des Baums: Knoten je Level (Vorschlag 2, Level 5 Standard + 2).
   Knoten 1-4 sind Werte -- auch Werte der Passive (Stapelzahl, Gewinn-Takt).
3. Kosten fürs Umskillen.
4. Identitäten aller DROMEs und Waffen neu fassen; Twist je Fraktionsvariante.
5. Passiven Molok, Nimbus, Strix nach 5b; Unsichtbar-Regel (5) bestätigen;
   Anzeige der Effekte (5c) besprechen; Takt der Fähigkeiten beim Waffen-Rework.
6. Bestehende Level (DROME 0-5, Waffe 0-10) in alten Spielständen umrechnen.
