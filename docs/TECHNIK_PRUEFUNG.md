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

## 5. Offen (Spieler)

1. **Ziel-Gerät**: Ist die Browser-PWA das Hauptziel oder die App im Store?
   Davon hängt ab, wie wichtig Schritt A/D sind. Für B ist es egal.
2. **Schritt B jetzt** (vor Story-Leveln und Bossen) oder später?
   Empfehlung: jetzt, weil sonst jede neue Fähigkeit doppelt gebaut wird.
3. Bitte auf dem Handy den **Leistungstest** (Optionen > Zum Testen) mit dem
   aktuellen Stand wiederholen, als Ausgangswert für Schritt B.

Messwerkzeug (nicht im Repo, einfach nachzubauen): kleiner Python-Server, der
`build/web` Brotli-komprimiert ausliefert, und ein Playwright-Skript mit
`Network.emulateNetworkConditions` + `Emulation.setCPUThrottlingRate`, das bis
zum Entfernen von `#status` misst.
