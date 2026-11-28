# Factory-Builder -- Konzept (22./23. Nov. 2026)

Stand: **Richtung entschieden (Spieler 22./23. Nov. 2026), Prototyp v2 gebaut,
Logik seit 23. Nov. 2026 im Spiel** (`FactorySim`, `data/factory.json`, Reiter Linien --
Abschnitt 11); die Optik folgt in der Design-Sitzung (Abschnitt 12). Prototyp als Artefakt:
https://claude.ai/artifact/BU9arMAXSSSC18zgFEnQsd (Kopie:
`docs/design/factory_prototyp/factory_v2.html`). Plan: Prototyp v2 testen,
evtl. v3, dann ins Spiel (Godot/PWA).

## 1. Grundgedanke

Die Fabrik ist das **Rückgrat des Fortschritts**, kein eigenes Hauptspiel
(Richtung „B“ aus den Reviews): eine kleine Hex-Platine, wenig Platz, knapper
Strom. Clever anordnen wird belohnt, der Spieler baut immer auf das um, was er
**gerade braucht** (Bedarf). Kämpfen treibt die Fabrik an.

## 2. Platine

* Hex-Platine (flache Sechsecke wie das Kampffeld), am Anfang 19 Felder, weitere
  Feldgruppen werden mit Ressourcen gekauft und bringen **neue Quellen**.
* Quellen (Schrott S, Neon N, Daten D) liegen fest; Förderer nur auf passende Quellen.
* **Keine Bänder:** Gebäude holen ihre Zutaten bei direkten Nachbarn ab, verteilt
  wird **reihum** (keiner wird bevorzugt).
* **Puffer:** Eingang = 10 × Rezeptmenge, Ausgang = 10.
* **Anlauf** (Spieler 23. Nov.): ein Verarbeiter startet erst, wenn Vorrat für
  3 Durchläufe im Eingangspuffer liegt, läuft dann durch, bis ihm etwas ausgeht,
  und sammelt danach wieder an -- die Kette stottert nicht. Wie beim Generator
  (zündet bei halbem Puffer).
* **Uplink** = der Weg ins Lager (kein Gebäude): was kein verbundenes Gebäude braucht
  oder über den Ausgangspuffer hinausgeht, verschwindet ins Lager.
* **Relais:** verbinden Gebäude an ihren Rändern (auch als Kette), kosten kein Geld,
  aber **1 Strom** -- ohne Strom leiten sie nichts. (Mehr Laufzeit hätte nichts
  gebracht: im Dauerlauf kommt hinten gleich viel an.)
* **Resonanz:** gleiche Verarbeiter nebeneinander +25 % je Nachbar, höchstens +50 %.

## 3. Strom

* **Ein Netzanschluss** in der Mitte (Story: der Strom läuft über die Platine):
  4 Strom, Reichweite 2.
* Jede Quelle hat **Leistung und Reichweite** und versorgt zuerst die **nächsten**
  Gebäude voll, dann die weiteren. Wer nur einen Teil bekommt, läuft anteilig
  (1 von 3 Strom = 33 % Tempo), ohne Strom steht er. Wer nichts zu tun hat, zieht
  keinen Strom.
* **Solarpanel** (Tier 1): 1 Strom, Reichweite 1; direkt neben einem anderen Panel
  nur 0,5 (Schatten, Gegen-Resonanz).
* **Schlackeofen** (Tier 1): 1 Schlacke → 2 Strom, Reichweite 1 -- Konkurrenz zum
  Recycler (Schlacke → Schrott).
* **Generator** (Tier 2): 1 Neon → 4 Strom, Reichweite 2. Neon ist anfangs zu
  wertvoll -- lohnt erst mit der Neonpumpe (Tier 2, 3 Neon je Takt, 2 Strom).
* Öfen/Generatoren **zünden erst bei halb vollem Puffer** und verbrennen nur, wenn
  Strom gebraucht wird.
* **Batterie** (Tier 2) als eigenes Gebäude: lädt sich mit übrigem Strom der Quellen
  in Reichweite (bis 20), gibt bei Mangel bis 2 je Takt ab (Reichweite 1).
  Tag/Nacht für Solar wäre ein Thema für später.
* Tier-1-Förderer brauchen **keinen Strom** (wie in Mindustry). Später: Stromknoten
  für mehr Reichweite.

## 4. Gebäude besitzen

* Startgebäude sind kostenlos. Ein gekauftes Gebäude gehört dem Spieler und lässt
  sich **beliebig oft umsetzen** (Abreißen legt es ins Inventar, Pufferinhalt ins
  Lager). Mehr Exemplare und spätere Gebäude kosten Ressourcen.
* Später: große Gebäude über mehrere Felder (mit dem Fortschritt).

## 5. Takte: live und im Einsatz

* **Live** im Factory-Tab sieht man die Kette laufen (im Spiel 1 Takt alle 6 s;
  im Prototyp 1 je Sekunde, beschleunigbar). Bis zum ersten Produkt höchstens
  etwa eine Minute -- passt (Spieler 23. Nov.).
* **Im Einsatz** läuft die Fabrik die meisten Takte: Vorschlag 100 je Kampf =
  800 je Einsatz (8 Kämpfe, `config.json` → `rounds`). Live in 7 Min. Spielzeit
  ca. 70 Takte → der Einsatz bringt etwa 11-mal so viel. Später eine Tabelle
  Takte je Einsatzlänge (8, 12 ... Kämpfe).
* **Messung (23. Nov. 2026, `map_bench -- 12`):** ein Kampf dauert im Schnitt
  **22 s** (20-23 s je Karte, Standard-Squad gegen Neon City, normal, 97 % Siege),
  8 Kämpfe ≈ 3 Min. reine Kampfzeit, ein Einsatz geschätzt 6-8 Min.
* Lager-Obergrenze: sinnvoll, später festlegen. Wer trotzdem viel hortet, macht
  sich den Fortschritt leichter -- das ist in Ordnung.
* **Rezepte müssen fürs Spiel langsamer/teurer werden:** mit den Prototyp-Raten
  gäbe ein Einsatz ca. 200 Energy Phases.

## 6. Stufen statt Riesenzahlen

Verdichten als echter Bauschritt (Gebäude), **etwa 10 : 1** (10 Legierung →
1 Panzerplatte). 100 : 1 wäre zu steil (ein Teil = 12 Einsätze). Ziel: ein Teil
≈ 1 Einsatz, ein DROME ≈ 5-8 Einsätze. Zahlen später genauer.

## 7. Tiers -- was damit herstellbar wird

**Wichtig (Spieler 23. Nov. 2026):** Die Fabrik stellt **nur Ressourcen** her
(Rohstoffe, Zwischenprodukte wie Legierung, Plasma, Schaltkreis, Panzerplatte,
Upgrade-Chip). Was im Spiel landet -- Charger-Rohlinge, DROME-Teile, DROMEs,
später Phasen -- wird **aus dem Lager** im jeweiligen Bereich hergestellt
(Charger-Bereich bzw. DROME-Bau, heute Reiter Charger/DROMEs im Fabrik-Tab:
`ChargerCrafter`, `DromeForge`). Die **Rohlingpresse** im Prototyp war ein
Missverständnis und fällt weg. Ein Tier schaltet dort die Rezepte frei und in
der Fabrik die Gebäude für die nötigen Ressourcen.

| Tier | Herstellbar | Freigeschaltet durch |
|---|---|---|
| 1 | Charger-Rohlinge (Phasen weiter nur aus Caches) | Start |
| 2 | CyberDromes aus Teilen | Fabrik-Ziel im Factory-Tab |
| 3 | Fraktions-DROMEs, Aufträge für Platzhaltercoins | Story-Fortschritt |
| 4 | Phasen | Story-Fortschritt (Ende Neon City: alles frei) |

Im Prototyp schalten alle Tiers über Fabrik-Ziele frei.

## 8. DROMEs bauen (Richtung, v3)

Im Menü „DROME bauen“ stellt man per Tipp aus Lager-Ressourcen **Teile** her
(Molok z. B.: Kopf, Leuchtfeuerreaktor, Brustharnisch, zwei Waffenhalter,
gepanzerter Unterbau). Die Teile werden verschmolzen und ergeben den DROME.
**Baukerne fallen weg**, Fraktionskerne bleiben (für Fraktions-DROMEs).
Die Fabrik soll möglichst alle Ressourcen liefern, auch Platzhaltercoins (über
Aufträge). Wie weit die Fabrik erzwungen wird, ist offen.

Folgen fürs Spiel (beim Umsetzen): Baukerne raus aus Caches, `Roster.craft_drome`,
Shop und SPOT, alte Spielstände umstellen; Skilltree-Level und Umskillen bezahlen
mit Fabrik-Ressourcen (`SKILLBAUM_KONZEPT.md`); Teile je Chassis festlegen; Platz
in der Navigation (Richtung fünf Tabs, Reiter Ressourcen).

## 9. Prototyp v2 (gebaut 23. Nov. 2026)

Netzanschluss, Strom nach Nähe mit Reichweite, Solar mit Schatten, Schlackeofen,
Relais mit Strom, Puffer + Uplink, Verteilung reihum, Kaufen/Umsetzen, Feldgruppen
kaufen, Tier 1 + 2 (Generator, Batterie, Neonpumpe, Verdichter, Chipfabrik),
Tier 3/4 als Ziel ohne Inhalt, Bedarf selbst wählen, Durchsatz je Gebäude
(braucht/kommt/Puffer/Strom), Hochrechnung je Einsatz im Lager, Knopf
„Einsatz simulieren“ (800 Takte).

**Kein v3 als Prototyp** (Spieler 23. Nov.): weiter geht es direkt im Spiel --
eine Sitzung für die Logik, eine Design-Sitzung für die Optik (Übergaben in 11 und 12).
Später: Tier 3/4 mit Inhalt, große Gebäude, Lager-Obergrenze, Rezept-Zahlen nach 5/6.

## 10. Kleinkram vor dem Go-live (aus den Reviews, 22. Nov. 2026)

* Generator/Strom: Zustand aus dem Vortakt wirkt einen Takt verzögert.
* Verarbeitung nach Bau-Reihenfolge statt Flussrichtung (ein Takt Versatz).
* Resonanz-Anzeige mit `Math.round` (in v2 erledigt).
* `relayCount` nutzte die globale Auswahl (in v2 entfallen).
* Bedarfe: „im Lager“ und „reserviert“ trennen, falls mehrere Bedarfe parallel
  oder Teillieferungen kommen.
* Speicherstand mit Version und Umstellung (Prototyp: `cd-factory-v2`).
* Fabrik-Stand muss in den echten Spielstand (`GameState`).

## 11. Übergabe Logik (nächste Sitzung: ins Spiel bauen)

**GEBAUT (23. Nov. 2026)** -- Details in `docs/PROJEKTSTAND.md` („Fabrik-Logik“). Abweichungen
und Ergänzungen zum Vorschlag unten:
* Lager = `Roster.materials` mit Schlüssel `"res:<ware>"`; der Charger-Rohling bleibt `"rohling"`
  und entsteht im Reiter Charger aus dem Lager (Vorschlag 2 Legierung + 1 Plasma).
* **Spieler 24. Nov. 2026:** **20 Takte je Kampf** (160 je Einsatz mit 8 Kämpfen). Das
  **Tier-2-Ziel braucht nur Fabrikwaren**, so viel wie ein starker Tier-1-Aufbau in 3-4
  Kämpfen schafft: gemessen je Takt ca. 1,6 Legierung, 1,5 Plasma, 0,45 Schaltkreis (Strom
  ist der Engpass) → 70 Takte = **110 Legierung + 100 Plasma + 35 Schaltkreis**.
* Tier 3/4 stehen als Story-Ziel in den Daten, ohne Weg zum Freischalten (kommt mit der Story).
* Bedarfe aus dem Prototyp sind nicht übernommen (der Bedarf kommt aus den anderen Reitern).
* Playtest 1 umgesetzt: „Eingang X voll -- wartet auf Y“ im Gebäude-Info, Leiterbahn gedimmt,
  wenn im letzten Takt nichts ankam. Playtest 2: Uplink-Menge je Takt im Gebäude-Info; Pulse
  nach Menge zeichnen bleibt für die Design-Sitzung.
* Abschnitt 10 (Verzögerung Strom/Bau-Reihenfolge) bewusst wie im Prototyp gelassen.
* Neue Anzeigetexte noch ohne `tr()` -- mit der Design-Sitzung nachziehen.

**Ort:** Fabrik-Tab (`resources_screen.gd`), Reiter **Linien** (heute Platzhalter) =
die Platine. Charger und DROMEs bleiben eigene Reiter und verbrauchen Lager-Ressourcen.

**Vorschlag Aufbau:**
* `data/factory.json`: Waren, Gebäude (Rezept, Rate, Strom, Tier, Preis, Startbestand),
  Quellen, Feldgruppen, Tier-Ziele, Netzanschluss -- Werte aus dem Prototyp
  (`docs/design/factory_prototyp/factory_v2.html`, `DEF`, `SOURCES`, `CHUNKS`, `TIERS`)
  **ohne Rohlingpresse**. In die SPOT (Blatt Fabrik o. ä.) übernehmen.
* `FactorySim` (RefCounted, reine Logik, deterministisch): `tick()` in der Reihenfolge
  des Prototyps -- Verbindungen, Abholen reihum, Strom (Bedarf, Quellen nach Nähe,
  Batterie, Brennstoff nur bei Verbrauch), Herstellen (Anlauf 3 Durchläufe, Resonanz,
  Schatten), Uplink. `run(n)` für viele Takte ohne Anzeige.
* Fabrik-Stand im Spielstand (`GameState`, mit Versionsnummer), Lager = Inventar.
* Takte: live 1 Takt alle 6 s, nur solange der Reiter offen ist; nach jedem Kampf
  `run(100)` (Vorschlag, Tabelle nach Einsatzlänge später). Ertrag am Einsatzende anzeigen.
* Tests in `tests/run_tests.gd`: Nachbar-Lieferung, Relais ohne Strom, Strom nach Nähe,
  Schatten, Anlauf, Uplink, Kaufen/Umsetzen, `run(800)` deterministisch.
* Baukerne entfernen (Caches, Shop, `Roster.craft_drome`, SPOT, alte Spielstände umstellen)
  erst, wenn die DROME-Teile stehen.

**Aus dem Playtest v2 (Spieler 23. Nov.):**
1. *„Eine Schmelze schickt keine Legierung an die Fabrik daneben.“* Nachgemessen: die
   Übergabe selbst klappt an allen Seiten (Löter, Presse, Verdichter). Was passiert: der
   Nachbar hat seinen Eingang für Legierung voll (10 × Rezept), weil ihm die **andere**
   Zutat fehlt (z. B. Daten) -- dann holt er nichts mehr, die Schmelze staut und der Rest
   geht per Uplink ins Lager. Das ist im Prototyp unsichtbar. Muss sichtbar werden:
   „Eingang voll -- wartet auf Daten“, Leiterbahn gedimmt. (Zweite mögliche Ursache:
   ein Relais ohne Strom -- gestrichelter Rand.)
2. *„Einheiten produzieren schneller, als sie weitergeben.“* Zwei Gründe: (a) mehr
   Herstellung als Verbrauch, der Überschuss geht über den Ausgangspuffer ins Lager;
   (b) die Anzeige zeigt höchstens einen Puls je Paar und Takt (und max. 80 Pulse) --
   bei 3 Neon je Takt sieht man nur einen Punkt. **Entschieden (Spieler 23. Nov. 2026):** der Überschuss
   geht weiter **per Uplink ins Lager**, Gebäude pausieren nicht. Die Anzeige muss ihn
   aber zeigen (z. B. „+0,5 Legierung/Takt → Lager“) und Pulse nach Menge zeichnen.

## 12. Übergabe Design (eigene Design-Sitzung)

Wünsche des Spielers (23. Nov.) zum Prototyp v2:
* **Gebäude in Gruppen** statt einer langen Liste: Förderer, Verarbeitung, Strom,
  Logistik (Relais), je Tier gesperrt sichtbar.
* **Bauen, Abreißen und Ansehen als getrennte Modi** (z. B. Schalter über der Platine),
  damit ein Tipp nie versehentlich baut oder abreißt.
* Ansicht polieren: Platine größer und klarer, Symbole statt Kürzeln (SAM, SMZ ...),
  Info als Blatt von unten, Strom-Reichweite und Engpässe lesbar, Fluss sichtbar
  (Menge je Puls, gedimmte Bahn bei Stau), Ertrag nach dem Einsatz.
* Stil: Arcade-Glitch über `UiKit`, Design-System-Tokens (`docs/design/tokens.json`),
  Hochformat 400 px. Grundlage: Prototyp v2 (Artefakt und Kopie im Repo).

## 13. Werkbank (Richtung entschieden, Spieler 24. Nov. 2026)

Alles, was aus dem Lager entsteht, bekommt **einen** Ort: die **Werkbank** im Fabrik-Tab.
Die Fabrik hat dann zwei Reiter: **Platine** (heute „Linien“) und **Werkbank** (ersetzt die
Reiter Charger und DROMEs).

* **Kategorien** oben: Charger, DROME-Teile, DROMEs, später Waffen. Darunter Kacheln (`Tile`).
* **Bauplan als Baum** beim Antippen: Produkt ← Teile ← Ressourcen, je Zeile „habe / brauche“.
  Fehlt etwas: welches Gebäude es herstellt und wie viele Kämpfe das mit der aktuellen
  Platine dauert (`FactorySim.projection`).
* **„Als Ziel merken“**: die Platine hebt die nötigen Waren und Gebäude hervor -- das ist der
  echte „Bedarf“ aus dem Prototyp (Abschnitt 1).
* **Höchstens zwei Stufen** (Ressource → Teil → Produkt), lesbar auf dem Handy.
* **Herstellen sofort per Tipp** -- die Zeit steckt in der Fabrik, keine zweite Wartezeit.
* **Charger** behält seinen Bildschirm (Phasen ins Hexagon legen ist das Spiel); die
  Werkbank führt dorthin. Der Charger-Rohling ist ein Rezept der Werkbank.
* **Baupläne** für Waffen, DROME-Teile und Fraktions-DROMEs: einmal aus Lootcache oder Story,
  danach beliebig oft aus Ressourcen. Caches bleiben das Entdecken, die Fabrik die Menge.
* **Nicht** in die Werkbank: Aufwerten (Skilltree-Level, Umskillen) bleibt auf der DROME-Seite
  (ein Verb je Tab).

**Teile je Chassis (Spieler 24. Nov. 2026, abgesegnet):** fünf Teile für alle -- Kopf, Kern,
Rumpf, Waffenhalter (Molok 2×, Strix: Lafette), Antrieb --, je Teil zwei Zutaten. Der Charakter
steckt in der Waren-Mischung: Vireo Plasma (Sprint), Molok Platten + Legierung (der teuerste),
Nimbus Chips + Plasma, Strix Chips + Platten. Zahlen in `data/factory.json` → `werkbank` und im
SPOT-Blatt Fabrik. Gerechnet mit einer gut ausgebauten Tier-2-Platine (je Einsatz ca. 250
Legierung, 240 Plasma, 70 Schaltkreis, je Verdichter 16 Platten, je Chipfabrik 30 Chips): reine
Produktion Vireo/Nimbus ca. 2, Strix 2,5, Molok 4 Einsätze; mit Skilltrees und Ausbau nebenher
4-5 / 5-6 / 7-8. Baupläne zu Beginn: die vier Standard-DROMEs und der Rohling. Fraktions-DROME =
Standard-Bauplan, der Fraktionskern ersetzt das Kern-Teil. Waffen später über Baupläne aus Caches,
aus Tier-1-Waren.

**GEBAUT (24. Nov. 2026):** `Workbench` (Logik auf `Roster.materials`: Teile als
`teil:<chassis>:<teil>`, Baupläne als `bauplan:<produkt>`), Reiter **Platine | Werkbank** im
Fabrik-Tab (`WorkbenchView`, ersetzt Charger und DROMEs; `DromeForge` entfernt), Bauplan-Baum mit
habe/brauche, Herkunft fehlender Waren, Schätzung in Kämpfen (`FactorySim.estimate_per_tick`),
„Als Ziel“ (im Spielstand der Fabrik) mit Markierung auf der Platine, Teile im Inventar. Freie
Chassis aus alter Beute bauen weiter kostenlos.

**Spezialteile, Verwerten, Baukerne raus (Spieler 24. Nov. 2026, GEBAUT):**
* Der **Fraktionskern** bleibt allgemeine Beute je Fraktion. In der Werkbank wird daraus mit den
  Zutaten des Kern-Teils ein **Spezialteil** für genau einen Fraktions-DROME (Neon Vireo:
  Neon-Booster, Neon Nimbus: Neon-Fokuslinse, Solar Nimbus: Solar-Prisma, Mecha Molok:
  Mecha-Reaktor, Mecha Strix: Mecha-Zielrechner). Es ersetzt im Bauplan das Kern-Teil -- der
  DROME ist damit einmalig in eine Richtung „geschweißt“.
* **Verwerten** gibt die Zutaten der zwei teuersten Teile zurück (Wert: Platte 10, Chip 2, sonst 1),
  ein Fraktions-DROME dazu sein Spezialteil. Zutaten statt Teile, weil Teile an ihr Chassis
  gebunden sind -- die Zutaten passen in jeden DROME.
* **Umskillen = verwerten und neu bauen** (relativ großer Einsatz), kein eigener Preis.
* **Baukerne entfallen** (Caches: ihre 7 % gehen an die Energy Phases; Shop; Verwerten). Alte
  Baukerne werden nicht umgerechnet -- Spielstände vor dem Android-Release werden gelöscht.

**Offen:** weitere Baupläne (Cache-Inhalt, Story), Waffen, Level-Material (Skilltrees).

**Ursprünglich offen (vor dem Bau):** Teile je Chassis und ihre Rezepte (Abschnitt 8, Ziel: ein Teil ≈
ein Einsatz, ein DROME ≈ 5-8 Einsätze); welche Baupläne es zu Beginn gibt und wo die übrigen
herkommen (Cache-Inhalt, Story); ob Waffen schon mit der ersten Werkbank kommen; Baukerne raus
(Caches, Shop, `Roster.craft_drome`, alte Spielstände), sobald DROMEs aus Teilen entstehen.

## 14. Fabrikstadt -- Design und neue Tier-Logik (Design-Sitzung 28. Nov. 2026, Richtung entschieden)

Entwürfe, Prototyp und Zeichen-Skript: `docs/design/fabrik_stadt/` (LIESMICH dort), Canvas
https://claude.ai/artifact/RdYTr9e3QabvCAVY9Q3Ct1. **Noch nicht gebaut** -- Optik und Menü
sind abgesegnet, die Regel-Änderungen unten müssen ins Spiel (`data/factory.json`, `FactorySim`,
`FactoryView`).

**Ansicht**
* Die Platine ist eine kleine **Fabrikstadt in 3D**: Kamera steil von Süden (wie der Kampf, nur
  steiler), Gebäude stehen sichtbar, schneiden aber höchstens den Rand des Feldes dahinter an.
* Stil wie die DROMEs: matte Platten, oben heller als vorn, **Kontur je Teil** in der Linienfarbe,
  Leuchtteile nur als flache Farbflächen -- kein Glühen, keine Transparenz.
* **Näher dran**: ein Feld ca. 92 px breit, die Platine scrollt (lieber scrollen als fummeln).
* Ohne Strom werden die Leuchtflächen grau; Schilder nur bei Problemen (Stau, kein Strom) und Ziel.
  Gesperrte Felder gestrichelt, ein Schloss je Feldgruppe.

**Linien: Farbe und Bauweise**
* **Schrott** rostrot, kantig, Schornsteine, Magnet: Sammler, Schmelze, Recycler, Verdichter,
  Schlackeofen. **Neon** cyan, runde Tanks, Glas, Ringe: Neonpumpe, Plasmakammer, Generator.
  **Daten** violett, schlanke Masten, Schüsseln: Scanner.
* **Hersteller mischen** Teile und Farben ihrer Linien (Feldrand wechselt die Farben): Löter
  (Schrott + Daten), Chipfabrik (Schrott + Daten + Neon).
* Ohne Linie: Strom grün (Solarpanel, Batterie), Logistik und Basis weiß. Öfen/Generatoren tragen
  die Farbe ihres Brennstoffs.

**Gruppen (neu)**: Fördern · **Veredeln** (eine Linie rein, dieselbe Linie besser raus: Schmelze,
Recycler, Plasmakammer, Verdichter) · **Herstellen** (mehrere Linien rein, etwas Neues raus: Löter,
Chipfabrik) · Strom · Logistik.

**Tiers (neu, ändert die Logik)**
* **Jeder Typ hat T1-T3 mit gleicher Funktion**, nur besser/effizienter. Ein Solarpanel wird nie
  zum Generator. Am Gebäude lesbar: T1 ohne Sockel mit Rost, T2 auf Sockel mit hellerem Blech,
  T3 auf Doppelsockel mit Dach in Linienfarbe; dazu 1-3 Kerben an der Südkante; je Stufe ein
  Detail mehr (Schornstein, Kolben, Paneel ...).
* **Zapfer entfällt**: die Neonpumpe ist der Neon-Förderer (T1 = heutiger Zapfer).
* Neue Typen werden über die **Basis-Stufe** freigeschaltet (Generator, Batterie, Verdichter,
  Chipfabrik ab Basis T2) und kommen dann als T1.
* Neu gebaut wird immer **T1**; T2/T3 entstehen durch **Aufrüsten auf der Platine**, sobald die
  Basis die Stufe hat. Kosten und Werte je Stufe: offen ("Logik später verfeinern").
* Die Basis wächst mit ihrer Stufe um ein Stockwerk.

**Bau-Menü**
* Untere Leiste fest: Plus · **Bauen** (Sechseck, Symbol Kran) · **Abreißen** (Fünfeck, roter
  Hammer) · **Verschieben** (Viereck).
* Bauen klappt **nach oben** eine waagerechte Reihe mit den fünf Gruppen aus (Sechsecke).
* Eine Gruppe klappt darüber eine **waagerechte Reihe ihrer Typen** aus -- ohne Kacheln, nur die
  Gebäude in Platinengröße mit Name und Stand. **Freigeschaltete stehen nah am Gruppenknopf**,
  gesperrte grau weiter außen ("AB BASIS T2"). Über jedem T1 ist T2 klein und grau angedeutet.
* T1 antippen wählt (gelbe Kontur), Feld antippen = Vorschau, nochmal = bauen (wie heute).

**Offen**: Werte und Kosten je Tier, Aufrüsten (Preis, Dauer), Inhalte für T3, ob Gebäude-Blatt,
Werkbank und Ertrag-Popup aus den älteren Canvas-Reihen übernommen werden.
