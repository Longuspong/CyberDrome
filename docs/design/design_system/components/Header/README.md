# Header

Die Kopfzeile jedes Bildschirms: Zurueck-Pfeil, Glitch-Titel, rechts Reiter und Zahnrad -- im Einsatz darunter die Statuszeile.

## Aufbau
`cd-header` mit `cd-header__back` (`chevron_left` in `yellow`, nur wenn es zurueck geht), `cd-header__title` (ein `cd-glitch` in `screen-title`), rechts optional `cd-seg` (Reiter) und `cd-header__gear` (`settings`, nur auf den Hauptseiten). Im Einsatz folgt `cd-statrow`: je Spalte ein Etikett (`cd-statrow__label`) und ein Wert (`cd-statrow__value`).

## Statuszeile im Einsatz
- **Leben**: Herzen (`life`) in `magenta`.
- **Credits**: `credits` + Zahl in `cyan` -- nur bei laufendem Einsatz.
- **Caches**: `cache` + Zahl in `yellow`.
- **Verstaerkung**: steigende Balken + Stufe in `orange` (Reinforcement-Level, steigt nach jedem Kampf).

## Regeln
- Hoehe 64 px, Rand `space-pad`, sichere Raender (Notch) beachten.
- Optionen nie als Tab, immer am Zahnrad.

Nachgebaut aus `UiKit.header`, `UiKit.header_slot` und dem Einsatz-Kopf (`run_screen.gd`).
