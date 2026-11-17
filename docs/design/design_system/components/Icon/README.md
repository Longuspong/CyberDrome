# Icon

UI-Symbol aus der Gruppe Icons, eingefaerbt mit der Textfarbe.

## Aufbau
`<i class="cd-icon" style="--icon:url(<Symbol>)"></i>` -- das weisse SVG wirkt als Maske, die Farbe kommt aus `color`. Groesse ueber `width`/`height` (16-52 px; Raster `icon`).

## Regeln
- Immer ein Symbol statt Sonderzeichen, die Bungee/Chakra Petch nicht haben.
- Farben nur aus den Tokens: `yellow` fuer Waehrungen, `cyan` fuer aktive Bedienung, `muted` inaktiv, `good`/`bad` fuer Zustaende.
- Strich 2, eckige Enden; Symbole nicht skalieren auf ungerade Groessen unter 16 px.

Nachgebaut aus `UiIcon` (`scripts/ui/ui_icon.gd`).
