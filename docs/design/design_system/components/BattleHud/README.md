# BattleHud

Die Anzeigen im Kampf: Kopf mit Uhr und Gegnerzahl, Kacheln des eigenen Squads, Balken ueber den Figuren mit Takt-Leiste.

## Kopf (`cd-battlebar`)
Links Gebiet und Kampf (`muted`), Mitte die Kampfuhr in Bungee (`white`) mit Zustand darunter (AUFSTELLUNG in `yellow`), rechts GEGNER x/y in `magenta`. Ab der Virus-Warnung (`cd-battlebar--virus`) werden Uhr und Zeile `magenta` („VIRUS IN 14 S"), das Bild flackert immer schneller.

## Squad-Kacheln (`cd-squadcard`)
Je DROME: Name in Bungee, Integritaet (Herz `hp`, `hp-player`) und Schild (`shield`, `shield-player`) als Zahl und Balken. Rahmen `cyan`; zerstoert gedaempft (`cd-squadcard--down`). Antippen = Fokus (Balken ueber der Figur 1,35-fach).

## Balken ueber den Figuren (`cd-unitbar`)
Integritaet und Schild in EINEM Balken (Fuge dazwischen), **oben rechts und unten links abgeschraegt** (alle Balken, auch in den Kacheln). Darunter die Takt-Leiste (`cd-takt`): Kaestchen je gezaehltem Angriff in `takt`, voll = `takt-ready`. Unter 25 % pulsiert der Rand in `danger`. Verlorene Integritaet laeuft hell nach.

| | Integritaet | Schild |
|---|---|---|
| eigenes Squad | `hp-player` (lebendiges Gruen) | `shield-player` (Hellblau) |
| Gegner (`cd-unitbar--enemy`) | `hp-enemy` (sattes Rot) | `shield-enemy` (dunkleres Violett) |

Lesbarkeit zuerst: Gruen ist deutlich heller als Rot (3,6:1) -- so bleiben die Teams auch bei Rot-Gruen-Schwaeche getrennt; alle vier Farben mindestens 3,9:1 auf dem Balkengrund.

## Ueberschild (`cd-unitbar__over`)
Schild ueber dem Maximum (Schildgaben bis +50 %) als heller, fast weisser Rahmen in `overshield` **aussen** um den Schildteil: links immer ganz, oben und unten so weit, wie der Ueberschild gefuellt ist (Breite = Anteil an +50 %); voll (`cd-unitbar__over--full`) rundum, der Schraege folgend. Die Schildfuellung bleibt frei; die Takt-Leiste rueckt ein Stueck nach unten.

Nachgebaut aus `BattleScreen`, `BattleView` und `Teams` (`scripts/ui/battle_screen.gd`, `battle_view.gd`, `teams.gd`).
