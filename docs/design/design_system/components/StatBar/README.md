# StatBar

Wertzeile mit Balken fuer DROME- und Waffenwerte (SPEED, SCHILD, INTEGRITAET ...).

## Aufbau
`cd-stat` mit Name, `cd-stat__track` > `cd-stat__fill` (Breite in % des Hoechstwerts) und Zahl. Optional ein Symbol vor dem Namen.

## Regeln
- Name GROSS in Chakra Petch 700, Zahl rechtsbuendig.
- Balken `cyan` auf `deep`; Vergleich (besser/schlechter) in `good`/`bad` mit Pfeil-Symbol, nie nur Farbe.
- Zwei Spalten im Hangar, eine im Popup.

Nachgebaut aus `StatBar` (`scripts/ui/stat_bar.gd`).
