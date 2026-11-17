# Tile

Kachel fuer Auswahl-Raster (DROMEs, Caches, Teile): tippen waehlt, nochmal tippen zeigt Details, Doppeltipp fuehrt die Handlung aus.

## Wann
Fuer Listen, aus denen der Spieler etwas waehlt. Im Hangar drei Spalten.

## Aufbau
`cd-tile` mit Bild (Aufrufer), `cd-tile__name` (Bungee, `white`), `cd-tile__sub` (`muted`), optional einem `cd-tag` oben links (Status) und `cd-tile__action` oben rechts (Plus/Minus in `cyan`). `aria-selected="true"` markiert die Auswahl mit gelbem Doppelrahmen.

## Regeln
- Eine Kachel ist mindestens `tap-min` hoch; Plus/Minus-Feld 28 px mit eigener Tippflaeche.
- Doppeltipp-Fenster 320 ms, langes Druecken 0,45 s (zum Ziehen).
- Leerer Platz: `cd-card--empty` statt Kachel.

Nachgebaut aus `Tile` und `SquadTiles` (`scripts/ui/tile.gd`, `squad_tiles.gd`).
