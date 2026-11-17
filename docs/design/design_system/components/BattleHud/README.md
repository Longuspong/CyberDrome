# BattleHud

Die Anzeigen im Kampf: Kopf mit Uhr und Gegnerzahl, Kacheln des eigenen Squads, Balken ueber den Figuren mit Takt-Leiste.

## Kopf (`cd-battlebar`)
Links Gebiet und Kampf (`muted`), Mitte die Kampfuhr in Bungee (`white`) mit Zustand darunter (AUFSTELLUNG in `yellow`), rechts GEGNER x/y in `magenta`. Ab der Virus-Warnung (`cd-battlebar--virus`) werden Uhr und Zeile `magenta` („VIRUS IN 14 S"), das Bild flackert immer schneller.

## Squad-Kacheln (`cd-squadcard`)
Je DROME: Name in Bungee, Integritaet (Herz `hp`, `hp-player`) und Schild (`shield`, `shield-player`) als Zahl und Balken. Rahmen `cyan`; zerstoert gedaempft (`cd-squadcard--down`). Antippen = Fokus (Balken ueber der Figur 1,35-fach).

## Balken ueber den Figuren (`cd-unitbar`)
Integritaet und Schild in EINEM Balken (Fuge dazwischen), darunter die Takt-Leiste (`cd-takt`): Kaestchen je gezaehltem Angriff in `takt`, voll = `takt-ready`. Gegner (`cd-unitbar--enemy`) in `hp-enemy`/`shield-enemy` mit **abgeschraegten Enden** -- Form statt nur Farbe. Unter 25 % pulsiert der Rand in `danger`. Verlorene Integritaet laeuft hell nach.

## Offen
Der Entwurf (Bilder 10/11) zeigt Gelb/Cyan fuer das eigene Squad und Magenta fuer Gegner; das Spiel nutzt heute Gruen/Blau gegen Rot/Lila (`Teams`). Hier steht der Spielstand.

Nachgebaut aus `BattleScreen` und `BattleView` (`scripts/ui/battle_screen.gd`, `battle_view.gd`, `teams.gd`).
