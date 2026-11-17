# ResultScreen

Ergebnis nach dem Kampf und am Ende eines Einsatzes: Etikett, riesiger Glitch-Titel, drei Kennzahlen, Beute und die eine Hauptaktion.

## Aufbau
`cd-result`: `cd-tag` (NEON CITY · KAMPF 3/8), `cd-glitch` mit `cd-result__title` (SIEG / NIEDERLAGE / EINSATZ GESCHAFFT), `cd-result__stats` mit drei `cd-result__stat` (Zeit, Abschuesse, Credits), Zwischentitel BEUTE und eine hervorgehobene Karte (`cd-card--hi`) mit Cache und Text, unten der Hauptknopf WEITER.

## Regeln
- Sieg: Titel `white` mit Glitch; gewonnene Credits `cyan` mit Vorzeichen.
- Niederlage: Titel gleich gebaut, Zeile darunter sagt die Folge („−1 Leben") in `bad` mit Symbol.
- Hinter dem Ergebnis bleibt das Spielfeld abgedunkelt sichtbar.
- Genau ein Hauptknopf.

Nachgebaut aus dem Ergebnis in `battle_screen.gd` und den Einsatz-Enden in `run_screen.gd` (Entwurf Bilder 12, 15, 16).
