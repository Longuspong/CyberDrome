# Backdrop

Die Synthwave-Kulisse hinter jedem Bildschirm: Punktraster, Sonne mit Schlitzen, Bergsilhouette, Gitterboden in Cyan, darueber Scanlines.

## Varianten
- **Titel**: grosse Sonne mittig (Mitte 225/297, Radius 150 in Entwurfspixeln), schwebt sanft (5 s), Punktraster mit 35 %.
- **Menue**: kleine, blasse Sonne (35 % Deckkraft, Radius 130) am unteren Rand, Horizont 52 px ueber dem Rand, Punktraster mit `dots-alpha`.

## Aufbau
`<div class="cd-backdrop">` mit dem Punktraster (14 px Raster, Punkt 1,6 px in `dots`) als Grund, darin die SVG-Zeichnung und zuoberst `cd-scanlines`. Der Inhalt des Bildschirms liegt darueber; Karten lassen sie mit `card-alpha` durchscheinen.

## Regeln
- Sonnenverlauf `yellow` -> `orange` (55 %) -> `magenta`; unterhalb der Mitte nur in den Schlitzen sichtbar, die nach unten schmaler werden.
- Berge `violet`, Boden `deep`, Gitterlinien `cyan` mit 22-75 % Deckkraft, Strahlen 30 %.
- Scanlines alle 3 px mit `scanline-alpha`. Die Kulisse ist Deko: nie Information darauf legen.
- „Bewegung reduzieren": Sonne steht still.

Nachgebaut aus `Arcade.Backdrop`, `Arcade.Scanlines`, `Ambience`.
