# Übergaben an Design-Sessions

Liste der Bildschirme, die erst in einer **Claude-Design-Session** entworfen werden, bevor
sie gebaut werden. Je Eintrag steht alles, was die Session braucht. Ergebnis wie bei
`einsatz_arcade/`: Bild + Vorlage je Bildschirm (450 x 800, Hochformat), danach baut eine
Code-Session nach dem Entwurf.

**Für jede Design-Session gilt:**

* Stil **Arcade-Glitch**: Design-System-Artefakt https://claude.ai/artifact/M5RC8KNDTr5psmKSuJpdS2
  (Tokens, Brand-Book, Komponenten, Symbole), Sicherung unter `docs/design/design_system/`,
  Farben in `docs/design/tokens.json`. Schriften Bungee + Chakra Petch.
* Bestehende Entwürfe als Vorbild: `docs/design/einsatz_arcade/` (24 Bildschirme, Tabelle im README).
* Mobile first, Hochformat ca. 400 CSS-Pixel breit, Daumen-Bedienung. Kacheln (`Tile`: tippen
  wählt, nochmal tippen = Details, Doppeltipp = Handlung), Erklärungen als blätterbares Popup.
* Navigation bleibt: Tab-Leiste unten Spielen / Hangar / Shop, Optionen am Zahnrad oben rechts,
  Reiter als Segmentknopf oben rechts in der Kopfzeile.
* Sonderzeichen nur als SVG-Symbole (`assets/ui_icons/`), nie als Text.
* Nur Optik und Layout -- neue Regeln, die im Entwurf auftauchen, gehen als offener Punkt in die
  SPOT (`docs/spot/inhalte/entscheidungen.json`).

---

## Ü1 Hangar neu: Umbau besser, Waffen-Upgrade statt Squad (20. Nov. 2026, offen)

**Warum:** Der Reiter **Squad** im Hangar ist nutzlos, weil der Squad vor jedem Einsatz ohnehin
neu gewählt wird (Spieler, 20. Nov. 2026).

**Neu im Hangar (Reiter oben rechts):**

1. **Umbau** (bleibt, wird besser): DROME wählen, Waffe in den Halter, Werte als Balken.
   Heute: `scripts/ui/hangar_screen.gd` (Reiter `umbau`), Entwurf `einsatz_arcade` 03/04.
   Werte je DROME seit 20. Nov. 2026: Speed, Integrität, Schild, Schildpuls, Rüstung, Power,
   **Effizienz** (neu, Dauer/Stärke der Statuseffekte). Wünsche an den Entwurf: übersichtlicher,
   Vergleich vorher/nachher beim Waffentausch bleibt.
2. **Waffen-Upgrade** (neu, ersetzt Squad): je Waffe ein **Charger-Platz** (dauerhaft, bleibt
   nach dem Einsatz). Hier wird ein fertiger Charger in eine Waffe gesetzt oder getauscht.
   Zeigen: Waffe mit Angriff/Fähigkeit, ihr Charger als Hexagon mit den 6 Phasen-Feldern,
   die Elementarbelastung je Treffer und die aktiven **Resonanzen** (Regeln in `docs/CHARGER_KONZEPT.md`).
   Einsetzen per Ziehen, Doppeltipp als Ersatz.

**DROME-Übersicht** (Level, später Skillbaum): baut der Spieler in den **Assembler-Modus** ein --
nicht Teil dieser Übergabe.

## Ü2 Einsatzvorbereitung mit Squad-Wahl (20. Nov. 2026, offen)

**Was:** Vor jedem Einsatz wählt der Spieler seinen Squad (max. 3 DROMEs). Der Bildschirm soll
zeigen, **welche Gegner zu erwarten sind** (Fraktion, Formationen, Gegner-DROMEs und Sentinels
mit Rolle), daneben die eigenen DROMEs -- damit der Squad auf die Gegner abgestimmt wird.

* Heute: `scripts/ui/squad_picker.gd` (Dabei / Bleibt zuhause) im Lauf-Bildschirm
  `scripts/ui/run_screen.gd` (Phase ohne Lauf: "Lauf starten").
* Daten: Formationen und Gegner-DROMEs in `data/formations.json`, Fraktionen in der SPOT
  (Blatt Fraktionen), Kampfkarte FTL-artig (`map_view.gd`).
* Die Gegner-Squads werden später überarbeitet -- der Entwurf soll mit wechselnden Inhalten
  zurechtkommen (1-2 Gegner-DROMEs + Sentinels je Formation).

## Ü3 Charger-Crafter im Crafting-Tab (20. Nov. 2026, offen -- Bild vom Spieler folgt)

**Was:** Im Shop-Reiter **Bauen** (Crafting) wird aus einem **Charger-Rohling** und bis zu
**6 Energy Phases** ein Charger gebaut. Die Phasen werden per **Ziehen** in ein **Hexagon**
gelegt: sechs kleine Hexagon-Felder ergeben zusammen ein großes Hexagon, in der Mitte ein
Freiraum bzw. der Knopf **Bauen**. Doppeltipp zum Einsetzen bleibt als Ersatz.

* Phasen: Volt, Cryo, Terra, Feuer, Virus, Chaos (je eigene Farbe und eigenes Symbol nötig).
* Phasen werden beim Bauen **verbraucht**. Rohlinge droppen aus Caches oder kommen aus dem Shop.
* Anzeige im Crafter: Elementarbelastung je Element (20 je Phase) und welche Resonanz bei 2 / 4 / 6
  gleichen Phasen entsteht (Regeln in `docs/CHARGER_KONZEPT.md`).
* Skizze des Spielers: kommt als Bild, wird hier unter `docs/design/charger/` abgelegt.
