# Card

Violette Karte mit Rahmen und hartem Versatzschatten -- der Grundbaustein jedes Bildschirms.

## Wann
- **Normal**: Abschnitte, Listenzeilen, Ladenangebote.
- **Hervorgehoben** (`cd-card--hi`): das gerade gewaehlte Objekt (aktiver DROME, gewaehltes Angebot) -- Rahmen `cyan`, Schatten `magenta`.
- **Leer** (`cd-card--empty`): freier Platz (Slot, Lager), gestrichelt mit Plus.

## Aufbau
Ein Block `cd-card` mit Innenrand `space-card` und Zeilenabstand 6 px; Inhalt liefert der Aufrufer (Name in `cd-name`, Text in `body-lg`, Zahlen in `cd-num`).

## Regeln
- Eckig (`square`), Rahmen `line`, Grund `violet` mit `card-alpha`.
- Schatten `shadow-card`, hervorgehoben `shadow-card-hi`. Keine weichen Schatten.
- Abstand zwischen Karten `space-gap`.

Nachgebaut aus `UiKit.card` / `UiKit.card_style`.
