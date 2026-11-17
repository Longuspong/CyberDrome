# InfoPopup

Erklaer-Popup: blaetterbare Seiten mit Titel in Bungee, ueber abgedunkeltem Bildschirm.

## Wann
Fuer Details einer Kachel (zweites Tippen), Regeln und Hilfen. Eine Seite je Gedanke; mehrere Seiten werden geblaettert (Wischen oder Pfeile).

## Aufbau
`cd-scrim` ueber dem Bildschirm, darauf `cd-popup` (hoechstens 420 px breit): `cd-popup__title`, Text in `body-lg`, `cd-pages` als Seitenanzeige (aktive Seite `cyan`), Schliessen-Kreuz (`close`, `yellow`) oben rechts. Inhalt liefert der Aufrufer.

## Regeln
- Grund `violet` mit 98 %, Rahmen `cyan`, Schatten `shadow-card-hi`; Abdunklung `scrim`.
- Tippen neben das Popup schliesst es. Einblenden kurz (Deckkraft), bei „Bewegung reduzieren" sofort.

Nachgebaut aus `InfoPopup.open_pages` (`scripts/ui/info_popup.gd`).
