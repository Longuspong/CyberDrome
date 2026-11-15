# Einsatz-Entwurf im Arcade-Glitch-Stil (15. Nov. 2026)

24 Bildschirm-Entwuerfe des Spielers (Export "CyberDrome – Startseite"),
450 x 800 wie der Entwurfsraum des Spiels. Wie bei `titel_arcade` gilt:
**Referenz fuer Optik und Layout, kein Code zum Uebernehmen.**

* `bilder/*.webp` -- Bild je Bildschirm (zum Anschauen).
* `vorlagen/*.dc.html` -- die Vorlage je Bildschirm (`<x-dc>`-Markup mit den
  genauen Werten in `style="..."`; Schrift-Einbindung entfernt, ohne Laufzeit
  nicht lauffaehig).

| Nr. | Bildschirm | Spiel |
|---|---|---|
| 00/01 | Startseite (ohne / mit laufendem Einsatz) | `main_menu.gd`, `home_stage.gd` |
| 02/03/04 | Hangar Squad, Umbau, Waffen-Karte | `hangar_screen.gd`, `weapon_card.gd` |
| 05 | Kampfkarte Neon City | `run_screen.gd`, `map_view.gd` |
| 06 | Optionen | `settings_screen.gd` |
| 07/08 | Story-Dialog (Sprecher links / rechts) | `story_dialog.gd` (neu, noch ohne Story) |
| 09-12 | Aufstellung, Kampf, Virus, Ergebnis | `battle_screen.gd` |
| 13/14 | Zwischenstopp, Rezeptbuch | `run_screen.gd` |
| 15/16 | Einsatz geschafft / gescheitert | `run_screen.gd` |
| 17-22 | Caches-Lager, Cache oeffnen, Varianten je Fraktion | `shop_screen.gd`, `cache_opener.gd` |
| 23 | Shop | `shop_screen.gd` |

## Abgleich mit dem Spieler (15. Nov. 2026)

* **Navigation bleibt wie am 15. Nov. gebaut**: Tab-Leiste Spielen / Hangar /
  Shop, Optionen am Zahnrad, Shop mit den Reitern Shop / Caches / Bauen. Der
  Entwurf gilt fuer das Aussehen (Tab-Leiste mit Symbolen, Reiter als
  Segmentknopf oben rechts, Karten mit Cyan-Rahmen und Magenta-Schatten).
* **Credits** stehen nur bei laufendem Einsatz auf der Startseite.
* **Nur Optik, keine neuen Regeln**: Erstabschluss-Bonus +50 Coin, Seltenheit
  der Cache-Inhalte, Hipstar Cache und Lager mit 6 Plaetzen sind im Entwurf,
  aber nicht entschieden -- sie stehen im SPOT-Blatt Offene Punkte.
* Namen von Waffen, Modulen und Rezepten im Entwurf (Klingenarm, Nanoflicken,
  Abfangnetz ...) sind Platzhalter; das Spiel zeigt seine echten Daten.
* "Hipstar Hookers" im Entwurf heisst seit 14. Nov. **Hipstar Hackers**.
