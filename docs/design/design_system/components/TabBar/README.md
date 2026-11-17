# TabBar

Die Tab-Leiste unten auf den Hauptseiten: Spielen, Hangar, Shop -- Symbol ueber dem Namen.

## Aufbau
`<nav class="cd-tabbar">` mit drei `cd-tab`; der aktive traegt `aria-current="page"`. Symbole `tab_play`, `tab_hangar`, `tab_shop` (22 px) als `cd-icon`.

## Regeln
- Hoehe `tab-height`, Grund `tab-bar`, Strich oben `tab-line`.
- Aktiv: Grund `tab-on`, Farbe `cyan`, Strich `line-tab` ueber 76 % der Breite. Inaktiv `muted`.
- Optionen sind kein Tab, sondern das Zahnrad (`settings`) oben rechts.

Nachgebaut aus `UiKit.tab_bar` / `TabButton`.
