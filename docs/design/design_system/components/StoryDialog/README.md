# StoryDialog

Story-Dialog: Sprecherbild mit Namensschild ueber einem Textkasten; der Text erscheint Buchstabe fuer Buchstabe.

## Aufbau
`cd-story` (links) oder `cd-story cd-story--right`; `--speaker` setzt die Farbe des Sprechers (Fraktionsfarbe, z. B. `magenta` fuer Kage-9). Darin `cd-story__speaker` (Bild, liefert der Aufrufer) mit `cd-story__plate` (Name in Bungee, Fraktion klein) und `cd-story__box` mit Text und Seitenanzeige. Oben rechts UEBERSPRINGEN als Rahmenknopf, oben links „Antippen · weiter".

## Regeln
- Antippen zeigt den Rest der Zeile, dann die naechste; UEBERSPRINGEN beendet sofort.
- 42 Zeichen je Sekunde; bei „Bewegung reduzieren" steht die Zeile sofort ganz da.
- Text `text` auf `popup`, 17 px; Hintergrund mit `scrim` abgedunkelt.
- Sprecher wechselt die Seite je Zeile (links/rechts), damit ein Gespraech lesbar bleibt.

Nachgebaut aus `StoryDialog` (`scripts/ui/story_dialog.gd`); die Story selbst ist noch nicht angebunden.
