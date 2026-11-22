# Übergaben an Design-Sessions

Liste der Bildschirme, die erst in einer **Claude-Design-Session** entworfen werden, bevor
sie gebaut werden. Je Eintrag steht alles, was die Session braucht. Ergebnis wie bei
`einsatz_arcade/`: Bild + Vorlage je Bildschirm (450 x 800, Hochformat), danach baut eine
Code-Session nach dem Entwurf.

**Entwurf zu Ü1-Ü3 (20. Nov. 2026):** Design-Canvas „CyberDrome Charger & Hangar“
https://claude.ai/artifact/FJpqxTaHcbXsPTU619YC1e -- dazu Phasen, Amps, Caches und die
Neon-Cache-Shader-Studie. Gebaut wie in `docs/PROJEKTSTAND.md` („Charger, Caches oeffnen,
Hangar-Upgrade“) beschrieben; Amps sind nur Entwurf.

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

## Ü1 Hangar neu: Umbau besser, Waffen-Upgrade statt Squad (20. Nov. 2026, entworfen und gebaut)

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

## Ü2 Einsatzvorbereitung mit Squad-Wahl (20. Nov. 2026, entworfen und gebaut)

**Was:** Vor jedem Einsatz wählt der Spieler seinen Squad (max. 3 DROMEs). Der Bildschirm soll
zeigen, **welche Gegner zu erwarten sind** (Fraktion, Formationen, Gegner-DROMEs und Sentinels
mit Rolle), daneben die eigenen DROMEs -- damit der Squad auf die Gegner abgestimmt wird.

* Heute: `scripts/ui/squad_picker.gd` (Dabei / Bleibt zuhause) im Lauf-Bildschirm
  `scripts/ui/run_screen.gd` (Phase ohne Lauf: "Lauf starten").
* Daten: Formationen und Gegner-DROMEs in `data/formations.json`, Fraktionen in der SPOT
  (Blatt Fraktionen), Kampfkarte FTL-artig (`map_view.gd`).
* Die Gegner-Squads werden später überarbeitet -- der Entwurf soll mit wechselnden Inhalten
  zurechtkommen (1-2 Gegner-DROMEs + Sentinels je Formation).

## Ü3 Charger-Crafter im Crafting-Tab (20. Nov. 2026, entworfen und gebaut -- Skizze unter docs/design/charger/)

**Was:** Im Shop-Reiter **Bauen** (Crafting) wird aus einem **Charger-Rohling** und bis zu
**6 Energy Phases** ein Charger gebaut. Die Phasen werden per **Ziehen** in ein **Hexagon**
gelegt: sechs kleine Hexagon-Felder ergeben zusammen ein großes Hexagon, in der Mitte ein
Freiraum bzw. der Knopf **Bauen**. Doppeltipp zum Einsetzen bleibt als Ersatz.

* Phasen: Volt, Cryo, Terra, Feuer, Virus, Chaos (je eigene Farbe und eigenes Symbol nötig).
* Phasen werden beim Bauen **verbraucht**. Rohlinge droppen aus Caches oder kommen aus dem Shop.
* Anzeige im Crafter: Elementarbelastung je Element (20 je Phase) und welche Resonanz bei 2 / 4 / 6
  gleichen Phasen entsteht (Regeln in `docs/CHARGER_KONZEPT.md`).
* Skizze des Spielers: kommt als Bild, wird hier unter `docs/design/charger/` abgelegt.

---

## Offene Logik nach dem Bau (Stand 20. Nov. 2026, nach PR „Charger, Caches öffnen, Hangar-Upgrade“)

Gebaut sind Charger, Caches öffnen, Hangar-Upgrade, Einsatz-Aufklärung, Neon-Cache-Shader
und die Amps (Module v3). Was an **Regeln** noch offen ist -- erst mit dem Spieler entscheiden,
dann bauen (Stand auch in der SPOT, Blatt Offene Punkte):

**Charger und Elemente** (`docs/CHARGER_KONZEPT.md`, `config.json -> charger`)

1. **Wirkung der Stapel** von Cryo (Freeze), Volt (EMP), Terra (Säure / Stärkung), Virus und
   Chaos. Heute werden ihre Stapel nur gezählt (`Unit.element_stacks`), nur Feuer wirkt
   (Kabelbrand). Je Element: Dauer, Stärke, Höchststapel, Zusammenspiel mit Effizienz.
2. **Chaos**: „würfelt den Charger je Einsatz neu“ ist im Konzept „wird überdacht“.
3. **Virus-Element**: „etwas mit Virusschaden“ -- Form offen (fester Schaden je Stapel?
   Anteil wie bei der Power-Hyperfusion?).
4. **Anzeige im Kampf**: Stapel und Belastung am Ziel sind noch nicht sichtbar (Entwurf:
   Kristall mit Zahl über dem Lebensbalken, Leiste in 5 Segmenten).
5. **Charger-Rohling im Shop** (Konzept: „Rohlinge droppen aus Caches oder sind im Shop zu
   kaufen“) -- heute nur aus Caches; Preis offen.
6. **Phasen aus einem Ressourcen-Tab** (Konzept 5, „später“).
7. **Charger zerlegen / umbauen?** Heute ist ein gebauter Charger fest; Phasen kommen nicht
   zurück.

**Amps, Fusionen, Hyperfusionen** (`docs/MODULE_AMP_FUSION.md`, `data/modules.json`)

8. **Auswahl der Fusionen**: entschieden sind nur Heilverstärker (Integrity + Power) und
   Raufbold (Attack + Armor). Die übrigen 13 sind gebaute **Vorschläge** aus den alten Rezepten
   (Doppellauf, Lebensraub neu, Überspannung, Taktchip, Entladung, Rammbock, Peilsender,
   Bollwerk, Stachelgitter, Brandmarke, Schutzimpuls, Hologramm, Fesselkette) -- behalten,
   ändern oder leer lassen?
9. **Sondereffekte der Hyperfusionen** außer Power (20 % Virusschaden): Attack, Integrity,
   Shield, Armor, Tech haben heute nur den dreifachen Wert. Vorschläge in MODULE_AMP_FUSION 3.
10. **BIOS für Hyperfusionen** („wertet eine Fusion oder eine Hyperfusion auf“): heute nur für
    Fusionen; BIOS-Hyperfusion („Powerhouse“) fehlt.
11. **Fusion Core**: Preis (heute 14 Credits) und Häufigkeit im Laden (heute 12 % je
    Zwischenstopp) -- Startwerte.
12. **Weggefallen** mit den alten Rezepten: Gunslinger, Zielsucher als eigene Fusion,
    Überladung, Rundumschlag, Splitterpanzer, Gabelung, Kettenreaktion, Orbit-Fokus und die
    BIOS Revolverheld und Gravitation. Soll davon etwas zurückkommen?
13. **Werte prüfen**: Prozent-Amps sind beim Molok klein (Shield +10 % = +1). So gewollt laut
    Spieler; nach dem ersten Spieltest nochmal ansehen.

**Sonstiges**

14. **Squad-Code im Hangar**: der alte Squad-Reiter ist ausgeblendet, sein Code bleibt bis zum
    Assembler-Modus (DROME-Übersicht, Level, Skillbaum).
15. ~~**Neon-Cache-Shader auf schwachen Handys**~~ -- erledigt 21. Nov. 2026: Shader entfernt,
    Neon Cache wieder Zeichnung, Oeffnen im Glitch-Stil.
16. ~~**Solar-, Mecha-, Hipstar-Cache** als 3D-Shader~~ -- entfaellt (21. Nov. 2026).
