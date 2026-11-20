# Technik-Prüfung: Engine, Ladezeit, „nur noch 3D“ (20. Nov. 2026)

Anlass: Frage des Spielers, ob Godot + SVG die richtige Wahl war und ob man
lieber jetzt als später etwas über den Haufen wirft. Kurzantwort: **Godot
bleibt, die Grafik wird ganz 3D, die SVG-Altlast fliegt raus.** Hier die
Messungen und der Umbauplan. Entscheidungen stehen unten unter „Offen“.

## 1. Messung Web-Build (Stand `main` nach PR #95)

`bash tools/build_web.sh`, dann ausgeliefert wie bei Vercel (Brotli) und in
Chromium mit gedrosseltem Netz und gedrosselter CPU geladen. Gemessen bis der
Ladebalken verschwindet (Titel läuft).

| Datei | roh | Brotli (übertragen) |
|---|---|---|
| `index.wasm` (Engine) | 39,5 MB | 8,0 MB |
| `index.pck` (Spieldaten) | 11,6 MB | 8,2 MB |
| Rest (js, html, Icons) | 0,3 MB | 0,1 MB |
| **Summe** | **51 MB** | **16,3 MB** |

| Szenario | Download fertig | Spiel startet |
|---|---|---|
| ungedrosselt (Container-CPU) | 1,2 s | 6,4 s |
| WLAN 50 Mbit, CPU × 4 | 3,1 s | 8,8 s |
| 4G 10 Mbit, CPU × 4 | 13,7 s | 19,2 s |

* Nach dem Download braucht der Start noch **ca. 5 s** (WASM übersetzen,
  Engine hochfahren, erste Szene). Das zahlt man auch beim zweiten Besuch,
  wenn die PWA die Dateien schon im Cache hat.
* „CPU × 4“ ist eine Schätzung für ein Mittelklasse-Handy. Echte Zahlen gibt
  nur das Handy des Spielers.
* **Bildrate** lässt sich im Container nicht messen (kein echter
  Grafikchip, Chromium rendert per Software). Bekannt ist die Messung des
  Spielers vom 17. Nov. (`UEBERGABE_3D.md`): eine gemeinsame 3D-Szene trägt
  48 bewegte DROMEs. Ein Kampf hat höchstens 8 plus Sentinels. Die Bildrate
  ist also **kein** Grund für einen Wechsel.

### Fund: drei Viertel der DROME-SVGs sind toter Ballast

Im Paket stecken 636 SVGs aus `assets/parts/` (4 Richtungen × Bild, Kontur,
Leuchten, Varianten). Seit dem 3D-Umbau (17./18. Nov.) zeichnet `DromeModel`
alle DROMEs aus `.m3d`. Zur Laufzeit wird nur noch die **Südansicht** als
Symbol gebraucht (`UiKit.part_texture`: Halter-Kacheln, Köpfe, Lager).

* ungenutzt: **4,9 MB roh / 4,3 MB übertragen**, das sind 26 % des
  Downloads,
* gebraucht: 61 Südansichten, ca. 1 MB.

Auf 4G sind das rund 3,5 s Ladezeit weniger, ohne dass sich spielerisch
etwas ändert.

## 2. Bewertung der Engine

| | Godot (heute) | web-nativ (TypeScript + Three.js, Menüs in HTML) |
|---|---|---|
| Ladegröße | 8 MB Engine fest, Start ca. 5 s | ca. 1 MB Engine, Start unter 1 s |
| Menüs | nachgebaut in `UiKit` | HTML/CSS, Design-System fast 1:1 |
| 3D-Szene, Shader | stark, Editor dabei | stark, kein Editor |
| Tests ohne Bildschirm, Determinismus | vorhanden, eingespielt | selbst aufbauen |
| Android/iOS-App | direkter Export | über eine Hülle (Capacitor) |
| Umstiegskosten | -- | alles neu: Kampf, KI, Daten, Bildschirme, Tests |

Vom leeren Blatt aus wäre es knapp gewesen. Heute spricht alles gegen einen
Wechsel: Der Wert steckt in Logik, Daten und SPOT, und genau die müsste man
neu schreiben. Der einzige echte Nachteil von Godot im Browser ist die
feste Startzeit von ca. 5 s. Das ist für ein Spiel, das man als PWA
installiert, vertretbar.

## 3. Ist-Zustand des Kampfbilds: ein Zwitter

Der Kampf ist heute eine **2D-Welt mit eingeklebtem 3D-Bild**:

* `BattleView` (2D, `Camera2D`) ist die Bühne. `ArenaPainter` zeichnet
  Rand, Deko und Licht in 2D. `ArenaFloor3D` rendert den Hexboden **einmal**
  als Bild.
* `Arena3D` rendert DROMEs und Hindernisse mit **drei** Kameras (Bild,
  Signalfarbe für die Kontur, Neon) in SubViewports und legt das Ergebnis als
  *ein* `Sprite2D` in die 2D-Welt. Die Kameras laufen der `Camera2D` nach.
* Schüsse, Einschläge, Texte (`BattleView._draw_projectile` …) und alle
  Fähigkeits-Formen (`AbilityPainter`, 856 Zeilen) sind 2D-Zeichnungen in
  Iso-Projektion. `IsoView` rechnet in 11 Skripten zwischen Feld, 2D und 3D
  um.
* Der Generator (`tools/build_sample_parts.py`) und das Backen
  (`tools/bake_godot_assets.py`) schreiben weiter SVG, Kontur- und
  Leucht-SVGs für alle Richtungen.

Das funktioniert, aber **jede neue Fähigkeit und jeder neue Effekt wird
heute in 2D gebaut** und muss die 3D-Tiefe nachahmen: Verdeckung,
Projektion, Größe je Zoom. Das ist die Schuld, die mit jedem Feature wächst.
Deshalb lohnt der Umbau eher vor Story-Leveln und Bossen als danach.

## 4. Umbauplan „nur noch 3D“ (Vorschlag)

Jeder Schritt bleibt für sich lauffähig und grün und bekommt einen eigenen PR.

**Schritt A: Ballast raus (klein, sofort möglich, ohne Designfrage)**
* Export und Backen nur noch mit der Südansicht je Teil (Symbole). Kontur,
  Leuchten und die anderen Richtungen fallen weg. `PartData.add_view` prüft
  heute schon, ob die Dateien da sind.
* Erwartung: Download 16,3 → ca. 12 MB, auf 4G ca. 3,5 s schneller.
* Später die Symbole selbst aus dem `.m3d` rendern (wie `UiKit.drome_view`),
  dann braucht der Generator gar kein SVG mehr.

**Ergebnis Schritt A (gebaut 20. Nov. 2026):** `tools/bake_godot_assets.py`
backt nur noch die Südansicht je Teil (27 SVGs statt 636) und räumt alte
Bilder weg. `index.pck` 11,6 → 6,0 MB roh, **8,2 → 3,7 MB übertragen**,
zusammen **16,3 → 11,8 MB**. Auf 4G (CPU × 4) startet das Spiel nach 14,6 s
statt 19,2 s. Im WLAN bleibt es bei ca. 9 s, dort zählt fast nur der
Engine-Start. Alle Tests und `smoke_ui` sind grün.

**Schritt B: Kampfbühne in 3D (Kern des Umbaus, ca. 3–4 Sitzungen)**
1. `Camera3D` statt `Camera2D` + drei mitlaufenden Kameras. Zoomen und
   Ziehen per Finger auf der Kamera, Antippen per Strahl auf die Bodenebene
   statt `IsoView`-Rechnung.
2. Boden (`ArenaFloor3D`), Rand, Deko und Licht direkt in der Szene statt
   als Bild bzw. 2D-Zeichnung. Aufstellzone und Bodenringe als flache Meshes.
3. Schüsse, Einschläge und Fähigkeits-Formen als 3D-Meshes und Partikel
   (`AbilityPainter` → 3D). Die Formen und Farben bleiben, sie liegen nur
   auf dem echten Boden und werden richtig verdeckt.
4. Kontur und Neon: heute über die Signal-Kamera. In 3D entweder beibehalten
   (eine Szene, zwei Durchgänge) oder als Hüllen-Kontur am Mesh. Vorher
   gegeneinander auf dem Handy messen.
5. Balken, Abzeichen und Schadenszahlen bleiben 2D-Overlay und werden über
   `Camera3D.unproject_position` angeheftet. Das ist der übliche Weg.

Gewinn: echte Verdeckung und Tiefe für alle Effekte, Licht und Schatten aus
der Szene, Kamera frei (z. B. leichtes Schwenken bei Fähigkeiten), eine
Projektion statt drei. Die Spiellogik (`BattleManager`, KI, Daten) bleibt
**unberührt**, es ist reine Darstellung.

**Schritt C: Generator ohne SVG**: `build_sample_parts.py` schreibt nur
noch `.m3d`. Entwurfsbilder kommen aus den Godot-Render-Helfern
(`docs/design/drome_entwurf/godot/`).

**Schritt D (optional, später): kleinere Engine.** Ein eigenes
Web-Template ohne ungenutzte Godot-Module kann `index.wasm` deutlich
verkleinern. Das ist aufwendig (Engine selbst bauen) und lohnt erst vor
einem öffentlichen Start.

## 5. Antworten des Spielers (20. Nov. 2026)

* **Hauptziel ist eine Android-APK**, vermutlich für eine Indie-Plattform
  (Play Store offen). Die **PWA bleibt der Testweg**: schneller Playtest
  ohne Rechner, ohne jedes Mal eine APK aufs Handy zu ziehen. Wenn die PWA
  an grafische oder technische Grenzen stößt, wechselt der Spieler auf nativ.
  Folge: Schritt A beschleunigt jede Vorschau und bleibt sinnvoll. Schritt D
  entfällt (in der APK gibt es keinen WASM-Download).
* **Leistungstest** auf dem Handy (Bilder pro Sekunde, `main` und
  Vercel-Vorschau, gleicher Code, Unterschiede sind Messrauschen):

  | DROMEs | Ruhend | Einzeln | Eine Szene |
  |---|---|---|---|
  | 3 | 45–47 | 37–40 | 44–45 |
  | 6 | 47–50 | 31 | 41–42 |
  | 12 | 48–49 | 25–26 | 40–41 |
  | 24 | 47–49 | 21 | 41 |
  | 48 | 46–47 | 15 | 34–36 |

  Schon ohne Bewegung liegt der Browser bei ca. 47 B/s, das ist die Decke
  der PWA. Eine gemeinsame 3D-Szene bleibt bis 24 DROMEs bei ca. 41 B/s.
  Ein Kampf (8 DROMEs + Sentinels) liegt also nahe an der Decke. Schritt B
  ist kein Leistungsrisiko, solange alles in **einer** Szene bleibt. Die
  Zahlen sind der Ausgangswert für B.

## 6. Schritt B nach dem Lesen des Codes (20. Nov. 2026, abends)

Der Spieler hat B und C freigegeben. Beim Lesen von `Arena3D`, `BattleView`
und `ArenaPainter` zeigte sich: der Kampf ist schon **weiter 3D als in
Abschnitt 3 beschrieben**. DROMEs, Hindernisse, Deko und Boden kommen aus dem
3D-Generator, in einer gemeinsamen Szene mit derselben Ortho-Iso-Projektion
wie die 2D-Ebene. Die Schichten liegen so:

| Ebene | Inhalt | Verdeckung |
|---|---|---|
| unten (2D) | Boden-Bild (3D, einmal gerendert), Zierlinie, Licht, Aufstellzone, Bodenringe, Bodenmarken der Fähigkeiten | liegt unter den Figuren, also richtig |
| Mitte (3D) | DROMEs, Hindernisse, Deko, Mündungsblitz, Kontur, Neon | echte Tiefe |
| oben (2D) | Geschosse, Einschläge, Zahlen, Balken, Ansagen | bleibt immer sichtbar |

Bei einer festen Ortho-Kamera ist das die übliche, günstige Aufteilung.

* **B-a gebaut:** Der tote 2D-Pfad ist raus: gezeichnete Hindernisse,
  Deko, Bodenkacheln, die Neon-City-Bilder (`assets/arena/`) und
  `tools/cut_arena_city.py`. Die Quelle `art/arena_city/` bleibt.
  `ArenaPainter` zeichnet nur noch Zierlinie und Licht. Das Kampfbild ist
  unverändert, alle Tests sind grün.
* **B-b (Geschosse in 3D): empfohlen, es zu lassen.** In 3D würden Hindernisse
  und DROMEs Schüsse verdecken. Auf dem Handy sind Treffer oben drauf
  lesbarer. Dazu kämen Kosten je Bild ohne sichtbaren Gewinn. Die
  Bodenmarken liegen schon richtig unter den Figuren.
* **Kamera frei drehen / Perspektive**: erst sinnvoll, wenn es gewollt ist
  (z. B. Kamerafahrt bei Boss-Fähigkeiten). Dann wandern Bodenmarken und
  Geschosse mit in die Szene. Bis dahin nicht nötig.

**C (Generator ohne SVG): wartet auf eine Frage an den Spieler.** Die
SVG-Werkstatt (`werkstatt/index.html`) liest alle vier Richtungsbilder aus
`parts/`. Wer sie noch benutzt, verliert sie mit C. Ohne die Werkstatt könnte
der Generator nur noch Südansicht + `.m3d` schreiben (ca. 75 % weniger
Dateien in `parts/`). Ganz ohne SVG wäre es erst, wenn die Symbole aus dem
3D-Modell gerendert werden.

## 7. Offen (Spieler)

1. Wird die SVG-Werkstatt noch gebraucht? Nein → C bauen.
2. Einverstanden, B-b (Geschosse in 3D) zu lassen?

Messwerkzeug (nicht im Repo, einfach nachzubauen): kleiner Python-Server, der
`build/web` Brotli-komprimiert ausliefert, und ein Playwright-Skript mit
`Network.emulateNetworkConditions` + `Emulation.setCPUThrottlingRate`, das bis
zum Entfernen von `#status` misst.
