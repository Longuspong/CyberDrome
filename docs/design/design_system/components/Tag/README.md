# Tag

Schraeges Etikett auf Gelb fuer Status und Abschnittsnamen (IM SQUAD, ZWISCHENSTOPP, PLAYER 1 · READY).

## Wann
Kennzeichnet einen Zustand an einer Karte oder Kachel, oder benennt einen Bildschirm ohne Kopfzeilen-Titel. Kein Knopf: nicht antippbar.

## Aufbau
`<span class="cd-tag">Im Squad</span>`; Drehung ueber `--tilt` (Standard `tilt-tag`, erlaubt -3 bis +2 Grad). Optional ein `cd-icon` vor dem Text. `cd-tag--cyan` fuer Hinweise in Cyan.

## Regeln
- Stil `label`: Chakra Petch 700, GROSS, Zeichenabstand 0,24 em; Schrift `deep` auf `yellow`.
- Hoechstens ein Etikett je Karte.

Nachgebaut aus `Arcade.tag`.
