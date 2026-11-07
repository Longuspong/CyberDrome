# Brainstorming: Module

Stand 7. November 2026. Grundlage für die Brainstorming-Runde des Spielers.
Was gebaut ist, steht in `PROJEKTSTAND.md` (Abschnitt „Module und Rezepte“),
die Daten in `data/modules.json`. Alle Werte sind vorläufig.

---

## 1. Was heute gebaut ist

* Module gibt es **nur im Lauf**, am Ende verfallen sie.
* Sie stecken im **Waffenhalter**: 3 je Halter, beim Molok 2. Tauscht man
  die Waffe, bleiben die Module im Halter.
* Passt die Bedingung nicht zur Waffe (z. B. „nur Fernwaffen“ an einer
  Klinge), **ruht** das Modul. Es wird abgeblendet, der Grund steht daneben.
* Drei Klassen: **Angriff**, **Abwehr**, **Taktik**.
* Jedes Modul hat ein eigenes SVG-Symbol (`assets/modules/<id>.svg`).
* Beute: nach jedem Sieg ein Grundmodul zusätzlich zur Auswahl, bei Elite mit
  50 % gleich ein fertiges Rezept-Modul.
* Verkauf: 2 Credits (Grundmodul), 6 Credits (Rezept-Modul).
* Neu entschieden: Das Lager (8 Plätze) ist künftig **nur für Module**.

---

## 2. Grundmodule

| Modul | Klasse | Bedingung | Werte |
|---|---|---|---|
| Schnellfeuer | Angriff | Fernwaffe | +8 % Angriffstempo |
| Langer Lauf | Angriff | Fernwaffe | +1 Reichweite |
| Doppellauf | Angriff | Fernwaffe | 20 % Chance auf Querschläger aufs selbe Ziel, 15 % Schaden |
| Wuchtkante | Angriff | Nahkampf | +15 % Schaden der Angriffe |
| Panzerplatte | Abwehr | – | +3 Panzerung |
| Kondensator | Abwehr | – | +10 Schild |
| Stachelgitter | Abwehr | – | Nahkampf-Angreifer nehmen 3 Schaden je Treffer |
| Taktchip | Taktik | – | Fähigkeit 1 Angriff früher, Zeit-Takt 15 % kürzer |
| Verstärker | Taktik | – | Statuseffekte der Waffe 50 % länger |
| Koedersender | Taktik | – | Die Fähigkeit lockt ihr Ziel 3 s auf den Träger |

---

## 3. Rezepte mit allen Werten

Ein Rezept-Modul hat die **Summe aller Werte seiner Zutaten** und dazu einen
**eigenen Effekt**. Alle Werte müssen sichtbar sein (Vorgabe des Spielers).

**Gunslinger** (nur Fernwaffe) = Schnellfeuer + Langer Lauf + Doppellauf

* +8 % Angriffstempo
* +1 Reichweite
* 20 % Chance auf Querschläger, 15 % Schaden
* **Eigener Effekt:** jeder 5. Angriff trifft zusätzlich den schwächsten
  anderen Gegner irgendwo auf dem Feld

**Bollwerk** = Panzerplatte + Kondensator

* +3 Panzerung
* +10 Schild
* **Eigener Effekt:** der Schild lädt schon nach 2 s Ruhe (statt 4 s)

**Taktgeber** = Taktchip + Verstärker

* Fähigkeit 1 Angriff früher, Zeit-Takt 15 % kürzer
* Statuseffekte 50 % länger
* **Eigener Effekt:** nach der Fähigkeit ist die Waffe sofort wieder geladen

**Raufbold** (nur Nahkampf) = Wuchtkante + Stachelgitter

* +15 % Schaden der Angriffe
* Nahkampf-Angreifer nehmen 3 Schaden je Treffer
* **Eigener Effekt:** +15 % Angriffstempo

Im Spiel zeigen die Lagerkarte und das Rezeptbuch heute schon alle Werte
(„Summe: …“ und „Dazu: …“). An den Chips am Halter steht die volle Liste
bisher nur beim langen Drücken -- das ließe sich sichtbar machen.

---

## 4. Gemessen

Je 100 Kämpfe, Standard-Squad gegen sich selbst ohne Module:

| Aufbau | Siege : Niederlagen |
|---|---|
| ohne Module | 56:44 |
| ein Grundmodul je DROME | 80:20 |
| Vireo mit Gunslinger | 84:16 |
| Vireo mit den drei Zutaten einzeln | 75:25 |
| Strix mit Gunslinger | 81:19 |
| Molok mit Bollwerk + Raufbold | 81:19 |
| Nimbus mit Taktgeber | 85:15 |

Module machen also einen deutlichen Unterschied. Gegner tragen bisher keine.

---

## 5. Fragen für die Runde

1. **Bedingungen:** Wie viele Module sollen an Bedingungen hängen (Fern-
   oder Nahkampf)? Mehr Bedingungen geben mehr Identität, aber auch mehr
   Module, die im Lager herumliegen, weil sie nirgends passen.
2. **Rezepte:** Feste Rezepte (A + B = C), offene Kombinationen (jedes Paar
   ergibt etwas, wie bei TFT) oder beides?
3. **Rezeptgröße:** 2 oder 3 Zutaten? 3 Zutaten (Gunslinger) fühlen sich nach
   Belohnung an, fressen aber viel Lager und Zeit.
4. **Rezeptbuch:** von Anfang an bekannt oder zu entdecken? Entdecken macht
   Spaß, frustriert auf dem Handy aber schnell.
5. **Stapeln:** Dürfen drei gleiche Module (z. B. dreimal Schnellfeuer) an
   einer Waffe stecken? Heute ja.
6. **Bindung:** Gehören Module zum Halter (so gebaut) oder zur Waffe?
7. **Endlos-Modus:** Seltenere Module, die es im Story-Modus nicht gibt?
8. **Neon-Bezug:** Module, die nur an Neon-Waffen oder Neon-DROMEs wirken,
   z. B. „bezahlt mit Schild“?
9. **Gegner:** Sollen Gegner-Module in der Vorschau sichtbar sein?
   Empfehlung: ja, dann kann man kontern.
10. **Story vs. Endlos:** Gleiche Module in beiden Modi, oder eigene
    Beutetöpfe je Gebiet (Neon City -> Neon-Module)?
11. **Quests und Aufstiegswaffen:** Können bestimmte Module Teil einer Quest
    sein (z. B. „gewinne ein Level mit Gunslinger am Strix“)?

---

## 6. Anregungen für neue Module

### Angriff

* **Durchschlag:** ignoriert X % Panzerung (gut gegen die Tanks von Anlage 7)
* **Überladung:** Energietreffer springen auf einen zweiten Gegner über
* **Hinrichter:** +X % Schaden gegen Ziele unter 30 % Integrität
* **Erstschlag:** der erste Angriff im Kampf macht doppelten Schaden

### Abwehr

* **Notschild:** fällt die Integrität unter 30 %, sofort +20 Schild (einmal
  je Kampf)
* **Reflektor:** ein Teil des Energieschadens geht an den Angreifer zurück
* **Wurzeln:** kann nicht weggestoßen oder gezogen werden (gegen Orbit-Sog
  und Vortex)
* **Nanoreparatur:** heilt je Puls ein wenig

### Taktik

* **Jagdinstinkt:** ein Abschuss macht die Fähigkeit sofort bereit
* **Markierer:** die Fähigkeit macht ihr Ziel verwundbar für das ganze Team
* **Ausweichroutine:** nach einem Treffer kurz schneller (wie der
  Vireo-Sprint, für alle)
* **Echo-Splitter:** die Fähigkeit wirkt mit 30 % Stärke ein zweites Mal
  (eine kleine Nimbus-Passive für alle)

### Rezept-Ideen

* **Schildbrecher** = Überladung + Kondensator: doppelter Schaden am Schild
* **Henker** = Hinrichter + Jagdinstinkt: Abschuss lädt sofort nach, mehr
  Schaden gegen schwache Ziele
* **Festung** = Notschild + Wurzeln + Panzerplatte: der Träger wird
  unbeweglich, nimmt dafür 30 % weniger Schaden

---

## 7. Inspiration

* **Teamfight Tactics:** kleine Grundteile, die sich paarweise zu starken
  Items verbinden. Klar lesbar, gutes Handy-Vorbild.
* **FTL:** Module als Systeme, die eine Rolle verstärken. Gutes Vorbild für
  Beute nach Gebiet.
* **Slay the Spire (Relikte):** einfache Regeln mit großer Wirkung, oft
  „jeder N-te …“ -- passt zum Takt-System.
* **Hades (Daedalus-Hammer):** verändert, wie eine Waffe funktioniert, statt
  nur Zahlen. Passt zur Idee „Module verändern, wie eine Waffe
  funktioniert“.
* **Vampire Survivors (Evolutionen):** Waffe plus passendes Teil wird zu
  einer stärkeren Form. Idee für Neon-Varianten oder Aufstiegswaffen über
  Module.

---

## 8. Empfehlung als Startpunkt

* Feste Rezepte aus **2 Zutaten** als Regel, ein **sichtbares Rezeptbuch**,
  **wenige Bedingungen**. Das bleibt auf dem Handy übersichtlich.
* Seltene Rezepte aus **3 Zutaten** (wie Gunslinger) als besondere Belohnung
  behalten, z. B. für Elite, Endlos oder Quests.
* An den Chips am Halter alle Werte sichtbar machen, nicht nur beim langen
  Drücken.
