# Segmented

Segmentknopf fuer Reiter innerhalb eines Bildschirms (SQUAD / UMBAU, SHOP / CACHES / BAUEN), oben rechts in der Kopfzeile.

## Aufbau
`<div class="cd-seg" role="tablist">` mit `cd-seg__item`-Knoepfen; der aktive traegt `aria-selected="true"`. Der Aufrufer liefert die Reiter und reagiert auf die Wahl.

## Regeln
- Schiene `rail` mit `chamfer-sm`, Reiter `chamfer-xs`; aktiv `cyan` mit Schrift `night`, inaktiv `deep` mit Schrift `muted`.
- Stil `label` (13 px bei zwei Reitern, 12 px bei drei). Hoehe `tap-min`.
- Hoechstens drei Reiter.

Nachgebaut aus `UiKit.segmented`.
