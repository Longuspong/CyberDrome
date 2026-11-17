# LootCache

Lootcache je Fraktion: eigene Kiste in den Fraktionsfarben, Glitch-Name, Fraktion · Gebiet, darunter der sechseckige TAP-Knopf.

## Varianten (aus dem Entwurf 15. Nov. 2026, Bilder 17-22)
| Cache | Fraktion · Gebiet | Kiste | Farben |
|---|---|---|---|
| **Neon Cache** | Neon Ninja's · Neon City | Truhe mit Neon-Schriftzeichen, Ring und Schloss | `cyan` / `magenta`, Schloss `yellow` |
| **Solar Cache** | Solar Sentients · Parkanlage | Kuppel mit Blatt, Sonne in der Schale | `good` / `yellow` auf `cache-solar-fill` |
| **Mecha Cache** | Mega Mechas · Factory 5 | Stahlkiste „F5" mit Nieten, Griffen und Absperrstreifen | `cache-mecha` / `orange`, Streifen `yellow` |
| **Hipstar Cache** | Hipstar Hackers · Dachterrassen | Terminal-Kiste `> ./open cache_07_` mit HACK-Aufkleber und Pixeln | `rose` / `cyan` |

## Aufbau
`cd-cache` mit `--cache-a` (Akzent) und `--cache-b` (Zweitfarbe) fuer die Glitch-Kanaele des Namens; Grund ein weicher Schein in der Akzentfarbe (22 %). Darin `cd-cache__art` (die Zeichnung, Deckel als `cd-cache__lid` fuer die Oeffnen-Animation), `cd-cache__name` mit drei Lagen (`__ga`, `__gb`, `__ink`) und `cd-cache__sub`. Darunter `cd-tap` (`cd-tap--live` pulsiert 1,4 s) und TIPPEN ZUM OEFFNEN. Gesperrt: `cd-cache--locked` zeigt nur gestrichelte Umrisse in `empty-line`.

## Bewegung
Kiste wippt (3,2 s), Name glitcht kurz (3,8 s), Cursor und Pixel des Hipstar Cache blinken. Beim Oeffnen hebt der Deckel ab, die Kiste ruettelt, ein Blitz in der Akzentfarbe. Bei „Bewegung reduzieren" steht alles still.

## Regeln
- Fraktion und Gebiet stehen immer als Wort dabei, nicht nur als Farbe.
- Oeffnen ist heute nur eine Vorschau; Inhalt und Seltenheit sind noch nicht entschieden.

Nachgebaut aus `CacheArt` und `CacheOpener` (`scripts/ui/cache_art.gd`, `cache_opener.gd`) und den Entwurfs-Vorlagen 18-22; Farben wie im Spiel.
