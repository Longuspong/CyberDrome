# Musik

Zwei BeepBox-Stuecke des Spielers (24. Nov. 2026). Abspielen und Wechsel:
`autoload/music.gd` (Autoload `Music`), abschaltbar unter Optionen -> Ton.

| Datei | Quelle | Wo | Tempo | Intro | Schleife |
|---|---|---|---|---|---|
| `assets/music/kampf.ogg` | `kampf.beepbox.json` (D, expert) | Kampf (`battle.tscn`) | 96 BPM, Takt 2,5 s | Takt 1-4 = 10 s | Takt 5-32 (10-80 s) |
| `assets/music/menue.ogg` | `menue.beepbox.json` (A, Moll) | alle anderen Bildschirme | 128 BPM, Takt 1,875 s | Takt 1-4 = 7,5 s | Takt 5-48 (7,5-90 s) |

Warum diese Punkte: kampf Takt 32 -> 5 ist dieselbe Folge wie 12 -> 13
(Melodie und Akkorde). menue Takt 48 (nur Kick + Hi-Hat) fuehrt ins Thema wie
16 -> 17. Der leere Takt 49 von menue ist abgeschnitten.

## Ein Stueck tauschen

1. In BeepBox als WAV exportieren (einmal, ohne Wiederholung) und die JSON hier ablegen.
2. In OGG wandeln und **genau am Loop-Ende abschneiden** (Ogg loopt vom Dateiende
   zurueck auf `loop_offset`):
   `ffmpeg -i song.wav -t <ende_in_s> -c:a libvorbis -q:a 4 assets/music/<name>.ogg`
3. In `assets/music/<name>.ogg.import` unter `[params]`: `loop=true`,
   `loop_offset=<intro_in_s>` (Taktlaenge = 4 * 60 / BPM), dann
   `godot --headless --path . --import`.
4. `tests/test_music.gd` an Takte und Tempo anpassen.
