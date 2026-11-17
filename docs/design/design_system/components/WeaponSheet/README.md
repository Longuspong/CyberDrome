# WeaponSheet

Waffen-Karte als Blatt von unten: Name, Halter, Schadensart, Vergleich mit der eingebauten Waffe, Faehigkeit, Bonus und die Hauptaktion EINBAUEN.

## Aufbau
`cd-sheet` am unteren Rand mit Griff (`cd-sheet__handle`), gelbem Etikett WAFFEN-KARTE, Name in `name`, Level-Anzeige (`cd-level`, gelbe Kaestchen), Chips fuer Halter (Form-Symbol + Gewicht) und Schadensart (`cd-chip--cyan`). Darunter `cd-panel` mit Vergleichsbalken (`cd-stat`: diese Waffe hell, eingebaut gedaempft) und ein Panel fuer Faehigkeit (Takt als Kaestchen + Etikett JEDER 3. ANGRIFF) und Bonus.

## Regeln
- Oberkante 3 px `magenta`, Grund `popup`; der Bildschirm dahinter dunkelt mit `scrim` ab.
- Unterschiede als Zahl mit Vorzeichen (`+4` in `cyan`, schlechter in `rose`), nie nur als Balken.
- Genau ein Hauptknopf (EINBAUEN); darunter eine Zeile, was passiert („Ersetzt Klingenarm ...").

Nachgebaut aus `WeaponCard` (`scripts/ui/weapon_card.gd`).
