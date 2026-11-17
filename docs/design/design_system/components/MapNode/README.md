# MapNode

Knoten der Kampfkarte: ein Gegner-Team auf festen Pfaden (FTL-artig), mit Stufe, Kampfnummer und Namen.

## Stufen (seit 17. Nov. 2026)
| Stufe | Farbe | Symbol |
|---|---|---|
| Leicht | `tier-light` (= `cyan`) | Kreis `tier_light` |
| Normal | `tier-normal` (= `orange`) | Raute `tier_normal` |
| Elite | `tier-elite` (= `magenta`) | Stern `tier_elite` |
| Chaos (Endlos-Modus) | `tier-chaos` | Fragezeichen `unknown` |

Kalt -> warm -> heiss, alle aus der Arcade-Palette. Gelb bleibt der Auswahl vorbehalten, `good`/`bad` den Bedeutungen Sieg/Niederlage. Immer Symbol UND Wort -- nie nur Farbe (Orange und Magenta sind fast gleich hell).

## Zustaende
- **Erreichbar** (`cd-node--reach`): voller Rahmen in der Stufenfarbe.
- **Gewaehlt** (`cd-node--chosen`): Rahmen `yellow` 3 px, Schatten in der Stufenfarbe (80 %), Etikett DU BIST HIER; der Weg nach unten gelb (85 %), 3 px.
- **Gesperrt** in der aktuellen Reihe (`cd-node--locked`): 28 %.
- **Spaeter** (`cd-node--far`): die naechsten zwei Reihen, 55 %, etwas kleiner. Wege dorthin `cyan` mit 22 %.

## Aufbau
`cd-node cd-node--<stufe>` mit `cd-node__tier` (Symbol, Stufe, rechts die Kampfnummer) und `cd-node__name`. Knotenhoehe 54 px (spaetere Reihen 86 %), 40 px Abstand, hoechstens 170 px breit, drei Reihen sichtbar.

Nachgebaut aus `MapView` (`scripts/ui/map_view.gd`).
