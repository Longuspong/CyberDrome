Arcade-Glitch ist der Stil von CyberDrome, einem Autobattler fuer das Handy im Hochformat: Synthwave-Nacht, Gelb, Cyan und Magenta auf Nachtschwarz, abgeschraegte Ecken, harte Schatten, ein flackerndes Logo. Diese Regeln gelten fuer jeden Bildschirm. Im Spiel stecken sie in `Arcade` (`scripts/ui/arcade.gd`) und `UiKit` (`scripts/ui/ui_kit.gd`); die Werte stehen im SPOT-Blatt Design.

## Grundsaetze

- **Mobile first.** Entwirf fuer 450 x 800 Entwurfspixel (`design-width`), Handy hochkant. Querformat zentriert die Spalte auf hoechstens `max-column`.
- **Eine Hauptaktion je Bildschirm.** Sie ist der einzige gelbe Knopf (`yellow`, Schrift `deep`, Schatten `shadow-primary`). Alles andere ist Zweitknopf oder Kachel.
- **Nur Optik aus den Entwuerfen.** Neue Regeln, Zahlen oder Namen, die nur im Entwurf stehen, gehoeren nicht ins Spiel, bis der Spieler sie entschieden hat.
- **Bewegung reduzieren** stoppt alle Animationen (Glitch, Laufbaender, Sonne, TAP-Puls). Kein Inhalt darf nur durch Bewegung lesbar sein.

## Sprache und Ton

- Deutsch, kurz, in der Du-Form: „Antippen zeigt Details", „Irgendwo tippen", „2 Module im selben DROME = Rezept".
- Knoepfe, Etiketten und Zwischentitel GROSS: `ZUR KARTE`, `IM SQUAD`, `ALLE DROMES`. Fliesstext normal geschrieben.
- Englische Arcade-Brocken nur als Deko auf Titel und Etiketten: `PLAYER 1 · READY`, `SAVE SELECT`, Laufband `DEATH ROBOT ◆ OMNI MACHINE ◆ EXECUTOR`.
- Umlaute werden angezeigt (Ä, Ö, Ü, ß); im Code und in Kommentaren ohne Umlaute.
- Begriffe des Spiels: **DROME** (der Roboter), **Squad** (bis 3), **Einsatz** (ein Lauf), **Hangar**, **Lootcache**, **Coin**, **Credits**, **Waffe** (alles im Halter), **Modul**, **Rezept**. Die Fraktion heisst **Hipstar Hackers**.
- Keine Emoji. Trenner ist der Mittelpunkt `·`.

## Farbe

- Grund ist immer `night`. Karten, Kacheln und Slots liegen auf `violet` mit `card-alpha`, Popups auf `popup`.
- Text: `text` fuer Fliesstext, `muted` fuer Nebentext und inaktive Tabs, `white` fuer Namen (Logo, DROMEs, Slots).
- Akzente mit fester Bedeutung:
  - `yellow` = Hauptaktion, Etikett, wichtige Zahl (Kampfwert, Preis, Squad 4/4). Schrift auf Gelb immer `deep`.
  - `cyan` = Zwischentitel, aktiver Reiter/Tab, ausgewaehlte Karte, Wertbalken. Schrift auf Cyan `night`.
  - `magenta` = nur Glitch und Schatten (Hauptknopf, hervorgehobene Karte). Nie fuer Text.
  - `good` / `bad` = Sieg/Heilung bzw. Schaden/Niederlage, immer zusammen mit Wort oder Symbol (`check`, `cross`), nie nur ueber den Farbton.
- `orange`, `dots` und die Sonne sind Kulisse, keine UI-Farben.
- Fokus: Rahmen `line-focus` in `focus` auf jedem bedienbaren Element.
- Fraktionen tragen eigene Paletten (`neon-*`, `solar-*`, `mecha-*`, `hipstar-*`) — fuer DROMEs, Lootcaches und Fraktionsseiten, nicht fuer allgemeine Bedienelemente. Die Mega Mechas sind **matt**: Absperrstreifen statt Gluehen.

## Schrift

- **Bungee** (`display`) fuer Logo, Bildschirmtitel, Namen, Zahlen und Knoepfe: `logo`, `screen-title`, `name`, `slot-number`, `button`, `button-outline`.
- **Chakra Petch** 500/700 (`sans`) fuer alles andere: `body-lg` als Standard, `heading` fuer Zwischentitel in `cyan`, `label` fuer Etiketten, `tab` in der Tab-Leiste, `ticker` fuer Laufbaender.
- Grossbuchstaben bekommen Zeichenabstand (siehe `letterSpacing` der Stile); Fliesstext nicht.
- Zeichen, die die Schriften nicht haben (Pfeile, Kreuze, Waehrungen, Formen), nie als Text setzen — dafuer die Symbole aus **Icons**. Als Text erlaubt: `×`, `−`, `Ø`, `→`, `·`.

## Form

- **Abgeschraegt statt rund.** Knoepfe schneiden die Ecke oben links und unten rechts gerade ab (`chamfer-md`, gross `chamfer-lg`). Karten, Kacheln, Zweitknoepfe und Etiketten sind eckig (`square`).
- **Harte Schatten.** Karten werfen `shadow-card`, hervorgehobene Karten `shadow-card-hi` mit Rahmen `cyan`; der Hauptknopf `shadow-primary`. Keine weichen Schatten, keine Verlaeufe ausser der Sonne.
- **Schraege Etiketten.** Gelbe Etiketten (`IM SQUAD`, `ZWISCHENSTOPP`) drehen um `tilt-tag` (-3 bis +2 Grad), der Bildschirmtitel um `tilt-title`.
- **Leere Plaetze** gestrichelt in `empty-line`, Plus oder Nummer in `empty-num`.
- **Halter-Formen** stehen fuer das Gewicht: Dreieck leicht, Viereck mittel, Fuenfeck schwer, Kreis Kern.
- Rahmen `line` in `card-line` (mindestens 3:1 auf `night` und `violet`, damit Karten und Knoepfe als bedienbar erkennbar sind); Abstaende `space-pad` am Rand, `space-gap` zwischen Elementen, `space-card` in Karten.

## Bildschirmaufbau

1. **Kopfzeile**: Glitch-Titel (`screen-title`, gedreht) links, Reiter als Segmentknopf und Zahnrad (Optionen) rechts.
2. **Inhalt** als Spalte aus Karten und Kacheln, scrollt.
3. **Tab-Leiste** unten, `tab-height`: Spielen, Hangar, Shop — Symbol ueber dem Namen; aktiv in `cyan` mit Strich oben (`line-tab`) auf `tab-on`.
4. Hauptknopf unten rechts ueber der Tab-Leiste bzw. am Ende der Seite.

Bedienung: Kachel antippen waehlt, nochmal tippen zeigt Details (Popup, blaetterbar), Doppeltipp fuehrt die Handlung aus. Jedes Ziel ist mindestens `tap-min` hoch.

## Effekte

- **Glitch**: Logo dreifach — `white`, `cyan` und `magenta` versetzt; springt alle 3,2-4 s kurz und zerschneidet sich.
- **Scanlines**: dunkle Querlinien alle 3 px mit `scanline-alpha` ueber dem ganzen Bild.
- **Punktraster** in `dots` mit `dots-alpha`.
- **Sonne**: Verlauf `yellow` → `orange` → `magenta`, unten in Streifen geschnitten, ueber Bergsilhouette (`violet`) und Gitterboden (`cyan`).
- Laufbaender 22 s / 28 s je Durchlauf gegenlaeufig; TAP-Knopf pulsiert 1,4 s, Ring dreht 7 s; Slots gleiten 0,3 s von links herein.

## Ueberlagerungen

- Popups, Blaetter und der Story-Dialog liegen ueber dem Bildschirm; dahinter dunkelt `scrim` ab. Tippen daneben schliesst (ausser im Story-Dialog: dort weiter).
- **Erklaerungen** als blaetterbares Popup (InfoPopup): Titel in Bungee, eine Seite je Gedanke.
- **Details mit Handlung** als Blatt von unten (WeaponSheet): Oberkante `magenta`, Grund `popup`, genau ein Hauptknopf.
- **Story** (StoryDialog): Sprecherfarbe = Fraktionsfarbe, Text erscheint mit 42 Zeichen je Sekunde.

## Spielbausteine

- **Kopfzeile** (Header) auf jedem Bildschirm; im Einsatz mit Statuszeile Leben `magenta`, Credits `cyan`, Caches `yellow`, Verstaerkung `orange`.
- **Module** (ModuleChip): Chip mit Beinchen, Rand in der Klassenfarbe (`module-attack`, `module-defense`, `module-tactic`, `module-bios`); Rezepte mit doppeltem Rand.
- **Kampf** (BattleHud): eigenes Squad `hp-player`/`shield-player`, Gegner `hp-enemy`/`shield-enemy` mit abgeschraegten Balkenenden; Takt-Leiste in `takt`; Virus-Warnung in `magenta`.
- **Ergebnis** (ResultScreen): Etikett, riesiger Glitch-Titel, drei Kennzahlen, Beute, ein Hauptknopf.

- **Kampfkarte** (MapNode): Stufen Leicht `tier-light` (Cyan), Normal `tier-normal` (Orange), Elite `tier-elite` (Magenta), Chaos `tier-chaos` -- immer mit Symbol `tier_*` und Wort. Gelb bleibt der Auswahl.
- **Lootcaches** (LootCache) je Fraktion mit eigenem Farbpaar; die Fraktion steht immer als Wort dabei.
- **Kulisse** (Backdrop) hinter jedem Bildschirm; nie Information darauf legen.

## Symbole

Die 82 Symbole unter **Icons** sind 24 x 24, Strich 2 (Kreuze und Haken 2,6), eckige Enden. Sie sind **weiss** (`#ffffff`) auf transparent und werden beim Einsatz eingefaerbt (im Spiel `modulate`, im Web `mask-image` mit `background: var(--cyan)` o. ae.). Waehrungen: `credits` (Credits im Einsatz), `coin` (Platzhaltercoin), `kit` (Bausatz), `cache` (Lootcache). Tabs: `tab_play`, `tab_hangar`, `tab_shop`. Rollen: `role_vanguard`, `role_skirmisher`, `role_sniper`, `role_controller`.

## Herkunft der Werte

Die Tokens kommen aus der SPOT (`docs/spot/inhalte.json`: `design_farben`, `design_tokens`); `tools/build_spot.py` schreibt sie nach `docs/design/tokens.json`. Werte dort aendern, nicht hier.

## Schriften

Bungee und Chakra Petch stehen unter der SIL Open Font License 1.1 (`fonts/OFL_Bungee.txt`, `fonts/OFL_ChakraPetch.txt`); beim Weitergeben die Lizenz beilegen.

## Bilder

- **Screens**: die 24 Bildschirm-Entwuerfe vom 15. Nov. 2026 (450 x 800). Referenz fuer Optik und Layout; Namen von Waffen und Modulen darin sind Platzhalter.
- **Modules**: die 27 Modul-Symbole (farbig, fuer den ModuleChip).
- **App**: das App-Icon (512 x 512).
- Ein Logo als Bilddatei gibt es nicht: das Logo ist Satz — `CYBER` / `DROME` in `logo`, mit Glitch (siehe Komponente GlitchTitle).
