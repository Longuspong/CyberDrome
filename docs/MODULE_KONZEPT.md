# CyberDrome – Modulsystem: Überarbeitungsvorschlag (v2)

Stand 9. Nov. 2026 · Grundlage: `BRAINSTORMING_MODULE.md`, Waffen- und DROME-Daten, `IDENTITAETEN.md`,
`config.json` · Status: **vom Spieler als Richtung festgelegt (9. Nov. 2026), noch nicht gebaut.**
Alle Zahlen sind Startwerte für den Bench. Die Entscheidungen zu den offenen Fragen stehen
direkt unten und gehen dem Text darunter vor.

## Entschieden (9. Nov. 2026)

* **Name der späten Schicht: Matrix-BIOS, kurz BIOS** (statt „Matrix“ oder „Kern“).
* **BIOS gibt es nur aus Elite-Kämpfen** im Lauf, zusätzlich zu den Credits und **statt des Teils**.
  Module und BIOS verfallen nach dem Lauf; ein BIOS nach dem letzten Kampf wäre wertlos.
  Deshalb: **kein BIOS, wenn danach kein Kampf mehr kommt** (dann gibt es Credits bzw. das Teil).
* **Bosse droppen dauerhafte Beute** (Teile, Waffen, später Aufstiegswaffen), **kein BIOS**.
  Bosse **tragen** selbst ein BIOS-Rezept. Ein Boss steht am Ende jedes Story-Levels (`NEUANFANG.md` 6h).
* **Gegner-Profile = Fraktionen** je Gebiet (`NEUANFANG.md` 6i), siehe Abschnitt 9:
  Neon Ninja's = **Kämpfer**, Solar Sentients = **Rudel** (Bio-/Virus-Cyber; später ein DROME,
  der sich aufteilt bzw. sich selbst beschwört), Mega Mechas = **Festung**, Hipstar Hookers = offen.
  Damit steht beim Start fest, welche Profile kommen (Lage-BIOS).
* **Waffen sind im Lauf fest.** Beute-Teile gehen in die Tasche und erst nach dem Lauf in den Hangar.
* **Laden:** 3 Angebote, Neuwürfeln, Ziel-Rezept. **Kein Sperren** -- bei 9 Grundmodulen reicht Neuwürfeln.
* **Neue Waffen, Reihenfolge:** Bollwerk-Ramme (Molok), Mörser (zweite schwere Waffe), Klingenbumerang (Vireo).
* **Korrekturen** gegenüber v2 (aus Code und Messungen):
  * Stachelgitter ist keine Falle, sondern gemessen das stärkste Molok-Modul (1× 59 %, 2× 80 %,
    `NEUANFANG.md` 6i). Die Fassung „gegen alle“ im Bench zuerst prüfen, eher abschwächen.
  * `push_tiles` wird schon genutzt (Orbit-Sog zieht damit, `ActionResolver._shove`); nur keine Waffe stößt.
  * Strix hat Power 15, nicht 16.

**Neu in v2** (gegenüber der ersten Fassung):

* An die echten DROMEs, Waffen, Passiven und die Schadensrechnung angepasst (Abschnitt 2 und 5).
* **Gegner sind keine Fraktionen.** Statt Fraktions-Kontern gibt es **Gegner-Profile** (Abschnitt 9).
* „Kern“ ist schon ein Körperteil der DROMEs. Die späte Schicht heißt deshalb jetzt **Matrix-BIOS** (kurz BIOS).
* Das Rezept „Echo“ heißt jetzt **Gabelung**, weil „Echo“ die Passive des Nimbus ist.
* Stachelgitter, Raufbold, Brandmarke, Überspannung, Splitterpanzer, Rammbock und Taktchip angepasst.
* **Neuer Abschnitt 11: Kritik und Lücken bei den Waffen.**

---

## 0. Kurzfassung

* **9 Grundmodule** mit eigener Rolle, alle wirken auf jede Waffe.
* **18 Rezepte aus genau zwei verschiedenen Grundmodulen.** Jedes Grundmodul ist Zutat in genau 4 Rezepten.
  Damit gibt es keinen „sicheren“ Kauf mehr.
* **Keine Rezeptketten.** Tiefe entsteht über **BIOS** (Beute aus Elite-Kämpfen).
  Es wird **nie ein BIOS angeboten, das im Lauf nicht nutzbar ist.**
* **Laden:** 3 Angebote, Neuwürfeln, Ziel-Rezept. Verkaufen bleibt.
* **Gegner-Profile** geben Kämpfen eine Handschrift, auf die der Spieler mit Modulen reagieren kann.

---

## 1. Rahmen

### Was bleibt

* Module gibt es nur im Lauf. Sie stecken im Waffenhalter, die Plätze hängen an Chassis und Level.
* Grundmodule sind Zahlen, Rezepte ändern eine Regel.
* Ein Rezept ist die Summe seiner Zutaten plus eigenem Effekt, in **einem** Platz.
* Ein Rezept nur einmal je Halter. Grundmodule dürfen sich stapeln.

### Waffen sind im Lauf fest

**Die Waffe eines DROME wird während des Laufs nicht gewechselt.** Gelootete Waffen erscheinen beim Lager,
belegen keinen Lagerplatz und wirken erst nach dem Lauf.

Folgen:

* Die Bedingung (Fern/Nah) jedes Halters ist für den Lauf bekannt. Der Laden kann sicher anzeigen,
  **in welchem Halter des Squads** ein Modul oder Rezept wirkt.
* Der Satz „Wer die Waffe tauscht, behält die Module“ in `MODULE.md` gilt nur außerhalb des Laufs.
* **Abgleich nötig:** `IDENTITAETEN.md` (Abschnitt 6) spricht noch von „Beute-Waffen, die erst im Lauf
  eingebaut werden“. Das widerspricht der Regel und sollte angepasst werden.

### Was die Daten zusätzlich festlegen

* **Neue DROMEs kommen im Lauf dazu** (Runden 2 und 5 nach `new_drome_rounds`, Elite mit 35 %).
  Module für einen noch fehlenden DROME können also im Lager warten.
* **Power skaliert den Schaden** (Rohschaden = Waffenschaden × Power / 10). Prozent-Module wirken auf einem
  Strix (Power 15) in absoluten Zahlen mehr als auf einem Molok (Power 6).
* **Panzerung hat abnehmenden Ertrag:** Teiler 1 + 0,5 × R / (R + 15). +3 Panzerung bringt dem
  Nimbus (R 0) viel, dem Molok (R 10 + Deflektor) wenig. Das gleicht sich von selbst aus.
* **Kinetisch gegen Integrität, Energie gegen Schild** (am Schild × 0,8 bzw. × 1,2). Darauf baut ein Rezept auf.
* **Die Fähigkeit ersetzt den Angriff**, und **7 von 8 Waffen haben Treffer-Takt**. Angriffstempo
  beschleunigt also fast immer auch die Fähigkeit.

---

## 2. Analyse

### 2.1 Stärken des aktuellen Systems

* Module im Halter statt in der Waffe: klar und leicht verständlich.
* Keine Stufen, Stärke nur über Rezepte.
* „Grundmodule sind Zahlen, Rezepte ändern eine Regel.“
* Unsichtbares Mitleid, Rezept-Hinweis, identische Vorschau und Kampf.
* Gegner mit Modulen und Vorschau: die Grundlage für Reaktion ist schon da.

### 2.2 Probleme des aktuellen Systems

1. **Ungleich verteilte Zutaten.** Manche Grundmodule stecken in zwei Rezepten, andere in keinem.
   Das erzeugt „sichere“ Käufe.
2. **Dominierte Grundmodule:** Kette < Panzerplatte, Zeiger < Schnellfeuer, Schaltkreis < Kondensator.
3. **Rezepte mit gleichen Zutaten** (Kette + Kette) bei einem Laden ohne Doppelangebote.
4. **Ketten verstärken die Platzersparnis:** Gunslinger sind 3 Module in einem Platz, Taktgeber 4.
5. **Wirkungslose Module ruhen nicht** (Verstärker ohne Statuswaffe).
6. **Die Messung vergleicht das Falsche.** Je DROME ein Grundmodul (80:20) liegt fast gleichauf mit
   einem fertigen Rezept (81–85). Verteilen ist fast so gut wie Bauen.
7. **Wenig Kontrolle im Laden:** zwei Angebote, kein Neuwürfeln.

### 2.3 Was die Waffen- und DROME-Daten zusätzlich zeigen

| Befund | Folge für Module |
|---|---|
| Nur 3 von 8 Waffen haben Reichweite 1, und von den Standard-Gegnern kämpft praktisch nur der Molok im Nahkampf. | **Stachelgitter** (nur gegen Nahkampf) ist meist wirkungslos, also eine Falle. → Wirkt jetzt gegen alle Angreifer. |
| **Molok fällt in 100 % der Kämpfe**, nach etwa 10 s. Präsenz zieht fast alles auf ihn, Power 6 macht ihn schadensschwach. | Molok braucht Abwehr- und „getroffen werden“-Module, die etwas zurückgeben. Schadensmodule auf Molok sind schwach. |
| **Nimbus-Echo:** jede Fähigkeit wirkt zweimal. | Alle Fähigkeits-Module (Verstärker, Peilsender, Ködersender, Überladung, Gabelung) wirken auf dem Nimbus doppelt. Er wird der stärkste Modulträger. Im Bench beobachten. |
| **Strix-Anlegen:** 4 s ohne Feldwechsel für +20 % Schaden und Reichweite. | Alles, was den Strix bewegt (Hologramm) oder Gegner zu ihm holt (Ködersender, Fesselkette, Orbit-Fokus), ist auf ihm eine Falle. |
| **Vireo** macht am wenigsten Schaden der Fernkämpfer, trägt nur leichte Waffen, Sprint belohnt Treffer. | Viele kleine Treffer (Doppellauf, Gunslinger, Schnellfeuer) passen gut. Das Chassis-BIOS sollte ihn aufwerten. |
| **Plasmaklinge:** Fähigkeit alle 3 s, „verwundbar“ hält 5 s, liegt also dauerhaft an. | Längere Statusdauer (Verstärker) bringt hier nichts. Die neue Verstärker-Wirkung (+20 % Fähigkeit) schon. |
| **Deflektor und E-Schraubenschlüssel** haben keine Fähigkeit mit Gegnerziel. | Ködersender und Peilsender brauchen eine Ersatzregel (siehe Abschnitt 4). |
| **Treffer-Takt bei 7 von 8 Waffen.** | Schnellfeuer ist Angriffstempo **und** Fähigkeitstempo, also der stärkste Allrounder. Eventuell 7 % statt 8 %. |
| **Taktchip „Takt −1“** macht aus jedem 3. Angriff jeden 2.: +50 % Fähigkeiten. | Zu stark. → Taktchip zählt jeden Angriff als 1,25 (= etwa 20 % kürzer, passend zum Zeit-Takt). |

### 2.4 Fallen-Builds

**Im aktuellen System:**

| Falle | Warum |
|---|---|
| **Fesselkette** | Zieht Gegner zum Träger, der Doppellauf darin wirkt aber nur mit Fernwaffe. Braucht dazu zwei Ketten. |
| **Hologramm-Boost auf Nahkampf** | Springt weg, wenn das Build getroffen werden will. |
| **Ködersender / Orbit-Fokus auf zerbrechlichem Fernkämpfer** | Holt Gegner zum falschen DROME. |
| **Taktgeber-Pfad** | Drei schwache Module, längste Kette, halbe Strecke wertlos. |
| **Kette, Zeiger, Schaltkreis allein** | Dominiert. |
| **Verstärker ohne Statuswaffe** | Tut nichts (5 von 8 Waffen haben keinen Status). |
| **Stachelgitter** | Fast keine Nahkampf-Gegner. |

**Im neuen System bewusst übrig gelassen** (Fehlentscheidungen, die man lernen kann, statt versteckter Fallen):

| Falle | Abhilfe |
|---|---|
| Hologramm, Ködersender, Fesselkette, Orbit-Fokus **auf dem Strix** | Hinweis im Rezeptbuch: „bricht Anlegen“ bzw. „holt Gegner zum Träger“. |
| Schadens-Rezepte auf dem **Molok** | Hinweis über Power: Laden zeigt den erwarteten Gewinn je DROME (z. B. „+0,4 Schaden/s“). |
| Rundumschlag ohne Gegner daneben (Fernkampf-lastige Gegner) | Gegner-Profile in der Vorschau. |

---

## 3. Leitprinzipien

1. **Gleicher Grad:** jedes Grundmodul in gleich vielen Rezepten (hier 4).
2. **Nur Paare** aus zwei **verschiedenen** Grundmodulen. Platzersparnis immer 2 → 1.
3. **Grundmodule wirken auf jede Waffe.** Bedingungen nur bei Rezepten, höchstens ein bedingtes je Grundmodul.
4. **Kein dominiertes Modul.**
5. **Regeln stapeln nicht, Zahlen schon.**
6. **Squad-Synergien:** einige Module wirken über den eigenen DROME hinaus (Markierung, Panzerung für Nachbarn).
7. **Tiefe über BIOS, nicht über Ketten.**
8. **Jedes Chassis hat mindestens zwei Rezepte, die gut zu seiner Passive passen** (siehe 5.4).

---

## 4. Grundmodule (9)

| Modul | Kürzel | Klasse | Wirkung | Herkunft |
|---|---|---|---|---|
| Schnellfeuer | SF | Angriff | +8 % Angriffstempo (bei Treffer-Takt auch schnellere Fähigkeit) | übernimmt Zeiger |
| Wuchtkante | WK | Angriff | +12 % Schaden der Angriffe | jetzt jede Waffe |
| Doppellauf | DL | Angriff | 20 % Chance je Angriff auf einen Zusatztreffer mit 25 % Schaden (Fern: Querschläger, Nah: Nachschlag) | jetzt jede Waffe |
| Panzerplatte | PP | Abwehr | +3 Panzerung | übernimmt Kette |
| Kondensator | KD | Abwehr | +10 Schild | übernimmt Schaltkreis |
| Stachelgitter | SG | Abwehr | Jeder Angreifer nimmt je Treffer am Träger 2 Schaden, Nahkampf-Angreifer 4 | jetzt gegen alle |
| Verstärker | VS | Taktik | Fähigkeit +20 % Wirkung (Schaden, Heilung, Schildgabe), Statuseffekte +30 % länger | jetzt immer nützlich |
| Ködersender | KS | Taktik | Die Fähigkeit lockt ihr Ziel 2 s auf den Träger. Weitere Exemplare: +1 s | angepasst |
| Peilsender | PS | Taktik | Die Fähigkeit markiert ihr Ziel 4 s. Markierte Gegner nehmen +10 % Schaden von **allen** DROMEs | neu |

**Ersatzregel für Fähigkeiten ohne Gegnerziel** (Deflektor, E-Schraubenschlüssel): Ködersender und Peilsender
wirken auf den nächsten Gegner in Rw 3 bzw. auf das Ziel des nächsten Angriffs.

**Stachelgitter, Stacheln und Panzerung** gehen nicht durch Power, sie sind Werte des Trägers. Das ist für den
Molok (Power 6) wichtig, er bekommt so einen Schadensweg, der nicht an seiner Power hängt.

Gestrichen: Langer Lauf (kommt über das Gunslinger-BIOS zurück), Kette, Zeiger, Schaltkreis.
Hologramm-Boost und Orbit-Fokus werden Rezepte.

---

## 5. Rezepte (18)

### 5.1 Rezept-Tabelle

Jede Zeile hat genau vier Einträge. Leere Felder (·) sind Reserve für Erweiterungen.

|    | SF | WK | DL | PP | KD | SG | VS | KS | PS |
|----|----|----|----|----|----|----|----|----|----|
| **SF** | – | · | GS | · | US | · | TC | · | ZS |
| **WK** | · | – | · | RM | · | RB | UL | RS | · |
| **DL** | GS | · | – | · | · | SP | GB | · | KR |
| **PP** | · | RM | · | – | BW | · | SI | FK | · |
| **KD** | US | · | · | BW | – | EN | · | HG | · |
| **SG** | · | RB | SP | · | EN | – | · | · | BM |
| **VS** | TC | UL | GB | SI | · | · | – | · | · |
| **KS** | · | RS | · | FK | HG | · | · | – | OF |
| **PS** | ZS | · | KR | · | · | BM | · | OF | – |

### 5.2 Liste

Gesamtwirkung = Wirkung beider Zutaten + eigener Effekt.

| Rezept | Kürzel | Klasse | Bedingung | Zutaten | Eigener Effekt |
|---|---|---|---|---|---|
| **Gunslinger** | GS | Angriff | Fernwaffe | SF + DL | Jeder 5. Angriff trifft dazu den schwächsten anderen Gegner irgendwo auf dem Feld |
| **Überspannung** | US | Angriff | jede | SF + KD | Solange der eigene Schild steht, wird die Hälfte des kinetischen Schadens zu Energie (gut gegen Schilde) |
| **Taktchip** | TC | Taktik | jede | SF + VS | Treffer-Takt: jeder Angriff zählt 1,25. Zeit-Takt 20 % kürzer |
| **Zielsucher** | ZS | Angriff | jede | SF + PS | Angriffe gegen markierte Ziele +40 % Schaden |
| **Rammbock** | RM | Angriff | jede | WK + PP | Angriffe verursachen zusätzlich kinetischen Schaden in Höhe von 30 % der eigenen Panzerung (ohne Power) |
| **Raufbold** | RB | Abwehr | jede | WK + SG | Vergeltung: jeder Treffer, den der Träger einsteckt, lädt den nächsten Angriff um +20 % auf (max. 3×; Nahkampftreffer zählen doppelt) |
| **Überladung** | UL | Angriff | jede | WK + VS | Nach der Fähigkeit verursachen die nächsten 3 Angriffe +30 % Schaden |
| **Rundumschlag** | RS | Angriff | Nahkampf | WK + KS | Jeder Angriff trifft dazu alle anderen Gegner direkt neben dem Träger mit 60 % Schaden |
| **Splitterpanzer** | SP | Abwehr | jede | DL + SG | Stacheln gehen am Schild vorbei direkt auf die Integrität und können den Zusatztreffer des Doppellaufs auslösen |
| **Gabelung** | GB | Taktik | jede | DL + VS | Die Fähigkeit wird auf ein zweites Ziel in Rw 3 mit 50 % Wirkung wiederholt (bei Schildgaben: zweiter Verbündeter) |
| **Kettenreaktion** | KR | Angriff | jede | DL + PS | Zusatztreffer können erneut auslösen (max. 3 Sprünge) und springen bevorzugt auf markierte Ziele |
| **Bollwerk** | BW | Abwehr | jede | PP + KD | Schild lädt schon nach 2 s Ruhe |
| **Schutzimpuls** | SI | Abwehr | jede | PP + VS | Die Fähigkeit gibt allen DROMEs in Rw 2 für 4 s +3 Panzerung |
| **Fesselkette** | FK | Taktik | jede | PP + KS | Die Fähigkeit zieht bis zu 3 Gegner in Rw 3 neben den Träger und betäubt sie 1 s |
| **Entladung** | EN | Abwehr | jede | KD + SG | Bricht der Schild, erleiden alle Gegner in Rw 2 15 Schaden (Energie) und werden 0,5 s betäubt (höchstens alle 6 s) |
| **Hologramm** | HG | Abwehr | jede | KD + KS | Steht ein Gegner direkt daneben: Sprung weg (Rw 3), am alten Platz bleibt ein Köder, der 2 s lockt; danach 4 s Pause |
| **Brandmarke** | BM | Taktik | jede | SG + PS | Jeder Gegner, der den Träger trifft, wird markiert |
| **Orbit-Fokus** | OF | Taktik | jede | KS + PS | Das Ziel der Fähigkeit ist 2 s gewurzelt: greift an, bewegt sich aber nicht (geändert 9. Nov. 2026, Spieler) |

Verteilung: 8 Angriff, 5 Abwehr, 5 Taktik. Bedingt sind nur Gunslinger und Rundumschlag.

### 5.3 Synergie-Achsen

* **Markierung:** Peilsender, Zielsucher, Kettenreaktion, Brandmarke, Orbit-Fokus.
  **Wichtigste Squad-Achse:** Molok mit Brandmarke markiert dank Präsenz fast jeden Gegner,
  Strix und Vireo mit Zielsucher oder Kettenreaktion ernten.
* **Getroffen werden:** Stachelgitter, Raufbold, Splitterpanzer, Entladung, Brandmarke. Das ist die Molok-Achse.
* **Fähigkeit:** Verstärker, Taktchip, Überladung, Gabelung, Schutzimpuls. Das ist die Nimbus-Achse (Echo verdoppelt).
* **Viele Treffer:** Schnellfeuer, Doppellauf, Gunslinger, Kettenreaktion. Das ist die Vireo-Achse (Sprint).
* **Schadensart:** Überspannung (Energie gegen Schild), Rammbock (kinetisch gegen Integrität), Entladung (Energie).
* **Kontrolle / Position:** Ködersender, Fesselkette, Hologramm, Orbit-Fokus, Rundumschlag.

### 5.4 Passt zu welchem Chassis

| DROME | Starke Rezepte | Vorsicht |
|---|---|---|
| **Vireo** | Gunslinger, Kettenreaktion, Zielsucher, Überladung | Fesselkette, Rundumschlag (nur mit Plasmaklinge) |
| **Molok** | Brandmarke, Raufbold, Rammbock, Bollwerk, Entladung, Fesselkette, Rundumschlag | Zielsucher, Überladung, Gunslinger (Power 6) |
| **Nimbus** | Gabelung, Taktchip, Überladung, Schutzimpuls, Orbit-Fokus | Raufbold, Splitterpanzer (60 Integrität, 0 Panzerung) |
| **Strix** | Zielsucher, Gunslinger, Kettenreaktion, Überspannung | Hologramm, Ködersender-Rezepte, Fesselkette, Orbit-Fokus |

### 5.5 Risiken

* **Rammbock** auf Molok mit Deflektor (Panzerung bis ~21): etwa +6 Schaden je Angriff. Wert im Bench prüfen.
* **Kettenreaktion** mit gestapeltem Doppellauf: Sprünge hart auf 3 begrenzt.
* **Markierung + verwundbar** (Plasmaklinge, ×1,5) multiplizieren sich. Markierung stapelt nicht.
* **Nimbus mit Fähigkeits-Rezepten** durch Echo. Wenn er zu stark wird, Echo nur für die Grundwirkung, nicht für Modul-Effekte.
* **Brandmarke auf Molok** könnte Pflicht werden. Dann Markierung je Gegner höchstens alle 2 s erneuern.

---

## 6. BIOS (späte Schicht)

> Voller Name **Matrix-BIOS**, kurz **BIOS** (Mehrzahl ebenfalls BIOS). Nicht „Kern“, weil der Kern schon ein Körperteil der DROMEs ist.

### 6.1 Arten

| Art | Wirkung | Wann nutzbar |
|---|---|---|
| **Rezept-BIOS** | Verwandelt ein Rezept in eine stärkere Form mit einer zusätzlichen Regel | Rezept gebaut, oder beide Zutaten vorhanden |
| **Chassis-BIOS** | +1 Modulplatz und eine Verstärkung der Passive | dieser DROME ist im Squad |
| **Lage-BIOS** | Antwort auf ein Gegner-Profil (siehe 9) | das Profil kommt im Rest des Laufs noch vor |

### 6.2 Kein Angebot ohne Nutzen

Wer den Elite-Kampf wählt und knapp gewinnt, darf kein BIOS bekommen, das er nicht einsetzen kann.

1. Nach einem Elite-Kampf: **Wahl 1 aus 3** (eventuell 1 aus 2). Kommt zu den Credits dazu und
   **ersetzt das Teil**. Bosse droppen kein BIOS, sondern dauerhafte Beute.
   **Folgt kein Kampf mehr, gibt es kein BIOS** (dann die normale Beute).
2. Jedes angebotene BIOS ist nutzbar, in dieser Rangfolge:
   * **Sofort:** Rezept steckt in einem Halter, oder Chassis-BIOS für einen DROME im Squad.
   * **Bald:** beide Zutaten liegen im Lager oder in Haltern, noch nicht verschmolzen.
   * **Angefangen** (nur Lückenfüller): eine Zutat ist vorhanden.
3. **Mindestens ein Angebot ist sofort nutzbar.** Chassis-BIOS passen immer, also ist das immer erfüllbar.
4. Nie angeboten: BIOS für DROMEs außerhalb des Squads oder für Rezepte ohne vorhandene Zutat.
5. Kommt später ein DROME dazu (Runde 2 oder 5), wird sein Chassis-BIOS ab dann möglich.

### 6.3 Bedienung

* Ein BIOS liegt im Lager (belegt einen Lagerplatz).
* Im Rezeptbuch: **Rezept + BIOS** oder direkt **Zutat + Zutat + BIOS**. Zutaten bewusst unverschmolzen
  halten und auf ein BIOS warten ist damit eine echte Entscheidung.
* Hält der Spieler ein Rezept-BIOS, kommen dessen fehlende Zutaten im Laden 3× so oft.
* Ein BIOS-Rezept lässt sich nicht wieder trennen.
* **Höchstens ein BIOS-Rezept je DROME** (nicht je Halter, sonst hätte der Molok mit zwei Haltern einen Vorteil).
* Verkauf: 8 Credits.

### 6.4 Rezept-BIOS (erste Beispiele)

| BIOS für | Ergebnis | Zusätzliche Regel |
|---|---|---|
| Taktchip | **Taktgeber** | Nach der Fähigkeit ist die Waffe sofort wieder geladen |
| Gunslinger | **Revolverheld** | Feldschuss jeder 3. Angriff, bevorzugt auf markierte Ziele; +1 Reichweite |
| Bollwerk | **Festung** | Schildladung des Trägers wirkt mit 50 % auch auf DROMEs direkt daneben |
| Raufbold | **Berserker** | Vergeltung bis 5×; bei voller Ladung trifft der Angriff alle Gegner daneben |
| Brandmarke | **Treibjagd** | Stirbt ein markierter Gegner, springt die Markierung auf den nächsten |
| Orbit-Fokus | **Gravitation** | Das Wurzeln trifft dazu den nächsten Gegner am Ziel (Rw 2) |
| Rammbock | **Abrissbirne** | Jeder 3. Angriff stößt das Ziel 1 Feld zurück (nutzt `push_tiles`) |
| Überspannung | **Phasenbruch** | Gegen Gegner ohne Schild: +15 % Schaden |

Ziel ist ein BIOS je Rezept. Für den Anfang reichen 6–8.

### 6.5 Chassis-BIOS

Jede gibt **+1 Modulplatz** (Molok: in einem Halter nach Wahl) und verstärkt die Passive:

| DROME | Verstärkung der Passive |
|---|---|
| **Vireo** | Sprint gibt zusätzlich +20 % Angriffstempo. Zusatztreffer lösen Sprint ebenfalls aus. |
| **Molok** | Präsenz fängt 40 % statt 30 % ab, und abgefangener Schaden zählt als eingesteckter Treffer (für Stachelgitter, Raufbold, Brandmarke). |
| **Nimbus** | Jede Fähigkeit gibt dem Träger Schild (6 × Power / 10). Die zweite Echo-Wirkung darf ein anderes Ziel wählen. |
| **Strix** | Anlegen schon nach 2,5 s und hält einen Feldwechsel aus. Markierungen des Strix halten doppelt so lange. |

---

## 7. Laden, Lager, Verkauf

| Punkt | Heute | Vorschlag |
|---|---|---|
| Angebote je Stopp | 2 | **3** |
| Neuwürfeln | – | **2 Credits**, je weiterem Wurf im selben Stopp +1 |
| Ziel-Rezept | – | Im Rezeptbuch ein Rezept als Ziel markieren. Nur dessen fehlende Zutaten bekommen das Mitleid (3×) |
| Mitleid ohne Ziel | 3× für jede fehlende Zutat | 2× (bei Grad 4 würde sonst fast alles gewichtet) |
| Rezept-Kauf | vorgesehen, 16 | ab Runde 5 gelegentlich ein fertiges Rezept im Angebot |
| Verkauf | Grund 2, Rezept 6 | bleibt, dazu BIOS 8 |
| Anzeige | Rezept-Hinweis | zusätzlich **in welchem Halter es wirkt** und Warnungen wie „bricht Anlegen“ |

---

## 8. Lager

* 8 Plätze reichen anfangs. Wenn BIOS und unverschmolzene Zutaten zusammen warten, wird es eng.
  Beobachten. Möglich wäre ein eigener Platz für ein BIOS.

---

## 9. Gegner: Profile = Fraktionen

Heute nutzen die Gegner dieselben vier DROMEs und Waffen. Die Fraktionen je Gebiet (`NEUANFANG.md` 6i)
bekommen ihre Handschrift über ein **Profil**: eine Zusammenstellung aus DROMEs, Waffen und bevorzugten
Rezepten. Das Profil steht in der Kampf-Vorschau. Später kommen eigene DROMEs je Fraktion dazu.

| Gebiet / Fraktion | Profil | Zusammensetzung | Bevorzugte Module | Antwort des Spielers |
|---|---|---|---|---|
| Neon City / Neon Ninja's | **Kämpfer** | Vireos mit Plasmaklinge, Molok mit Hammer | Rundumschlag, Raufbold, Überladung | Stachelgitter, Splitterpanzer, Fesselkette |
| Parkanlage / Solar Sentients | **Rudel** (Bio-/Virus-Cyber) | viele leichte DROMEs; später ein DROME, der sich aufteilt und sich selbst beschwört | Gabelung, Kettenreaktion, Doppellauf | Rundumschlag, Entladung, Orbit-Fokus |
| Factory 5 / Mega Mechas | **Festung** | Moloks, Deflektor | Rammbock, Brandmarke, Bollwerk | kinetisch, Rammbock, Kettenreaktion |
| Dachterrassen / Hipstar Hookers | offen | -- | -- | -- |

Weitere Profile, noch ohne Fraktion (Kandidaten für Hipstar Hookers oder Mischkämpfe im Endlos-Modus):

| Profil | Zusammensetzung | Bevorzugte Module | Antwort des Spielers |
|---|---|---|---|
| **Schildwall** | Nimbus, Molok, Neon-Blaster, Schraubenschlüssel | Bollwerk, Entladung, Schutzimpuls | Energie (Überspannung), Markierung |
| **Artillerie** | Strix, Nimbus mit Runenstab | Zielsucher, Gunslinger, Gabelung | Hologramm, Ködersender, Orbit-Fokus |

* Die Modulkurve bleibt: 0, 0, 1, 1, 1, 2, 2, 2; ab Runde 5 ein Rezept. Bosse tragen ein BIOS-Rezept (droppen aber keins, siehe oben).
* **Lage-BIOS** greifen die Profile auf, zum Beispiel:
  * *Schildknacker:* +30 % Schaden gegen Schild.
  * *Panzerbrecher:* ignoriert die Hälfte der gegnerischen Panzerung.
  * *Fluchtpunkt:* immun gegen Locken (Präsenz, Ködersender).
  * *Sperrfeuer:* Schaden gegen Gegner, die sich bewegen, +20 %.

  Sie werden nur angeboten, wenn das Profil im restlichen Lauf noch vorkommt. Im Story-Modus steht das
  Profil über das Gebiet fest; im Endlos-Modus würfelt der Lauf seine Profile beim Start.

---

## 10. Balance und Messung

### Kurve im Lauf

| Phase | Runden | Plätze | Typischer Inhalt |
|---|---|---|---|
| Früh | 1–2 | 2–3 | Grundmodule, reine Zahlen |
| Mitte | 3–5 | 3–4 | erste Rezepte, Platzersparnis spürbar |
| Spät | 6–8 | 4–5 | 2–3 Rezepte je DROME, 1–2 BIOS-Rezepte im Squad |

### Zielwerte (Startpunkt)

* Grundmodule allein: höchstens etwa ±3 Prozentpunkte auseinander, **gemessen je Chassis**.
* Rezept gegen seine beiden Zutaten lose: +5 bis +8 Prozentpunkte.
* Rezept gegen zwei zufällige verteilte Grundmodule: mindestens gleichauf.
* BIOS-Rezept gegen normales Rezept: +8 bis +12 Prozentpunkte.
* 3× dasselbe Grundmodul gegen ein Rezept in drei Plätzen: das Rezept liegt vorn.

### Bench

* **Gleiche Modulzahl** vergleichen, nicht gegen „ohne Module“.
* **Je Chassis** messen, wegen Power, Echo und Anlegen.
* `run_bench`: Kauf- und Siegrate je Modul und Rezept. Hohe Kauf- und niedrige Siegrate bedeutet Falle.
* Squad-Synergie messen: Molok mit Brandmarke + Strix mit Zielsucher gegen dieselben DROMEs mit Einzelrezepten.
* **Überlebenszeit des Molok** mit Bollwerk, Raufbold, Entladung (heute fällt er immer nach etwa 10 s).

---

## 11. Kritik und Lücken bei den Waffen

### 11.1 Gewichtsklassen sind sehr ungleich besetzt

| Klasse | Waffen | Folge |
|---|---|---|
| leicht | Puls-Blaster, Neon-Blaster, Plasmaklinge, Runenstab, E-Schraubenschlüssel | gut besetzt |
| mittel | Hammer, Deflektor-Schild | Molok hat praktisch keine Auswahl, Nimbus kaum einen Grund für seinen mittleren Halter |
| schwer | Schienen-Lanze | Der schwere Halter des Strix ist ein Alleinstellungsmerkmal mit genau einer Waffe |

**Vorschlag:** mindestens 2 weitere mittlere und 1 weitere schwere Waffe. Beispiele weiter unten.

### 11.2 Puls- und Neon-Blaster sind fast gleich

Gleiches Tempo, gleiche Reichweite, gleicher Takt, fast gleiche Schadensaufteilung. Der Unterschied liegt nur in der
Fähigkeit. Vorschlag: den **Puls-Blaster schneller und schwächer** machen (zum Beispiel 7 alle 1,0 s). Dann ist er die
Vireo-Waffe mit vielen Treffern (Sprint, Doppellauf, Gunslinger). Der Neon-Blaster bleibt der Schildbrecher.

### 11.3 Der Schienen-Lanze fehlt ein Moment

Intern heißt die Fähigkeit `act_rail_pierce`, sie trifft aber nur ein Ziel mit 120 %. Für das Scharfschützen-Gefühl
fehlt etwas Besonderes. Vorschläge (eins davon reicht):

* **Durchschlag:** der Präzisionsschuss trifft alle Gegner in einer Linie.
* **Hinrichtung:** +50 % gegen Ziele unter 30 % Integrität.

Beides passt zu Anlegen und zur Markierungs-Achse.

### 11.4 Wenige Statuseffekte, nur eine Flächenwirkung

Status gibt es nur bei 3 Waffen (verwundbar, betäubt, verlangsamt), Fläche nur beim Runenstab, Rückstoß (`push_tiles`)
läuft im Kampf schon (Orbit-Sog zieht damit), aber keine Waffe stößt. Was im Spielgefühl fehlt:

* **Brand** (Schaden über Zeit). Gibt Tempo-Waffen einen Grund für Statusdauer.
* **Störung / EMP:** Schildpuls des Ziels 3 s aus. Passt perfekt zur Schild-Mechanik.
* **Rückstoß:** Stellung und Positionierung (Molok vorn, Strix hinten) bekommen mehr Gewicht.
* **Kegel- oder Linienangriffe:** bisher trifft jeder Angriff ein Ziel.

### 11.5 Keine Reichweite 2

Es gibt nur 1, 3 und 8. Eine Waffe mit Reichweite 2 (Speer, Peitsche) wäre ein Zwischenschritt: zählt als Fernwaffe,
steht aber in der zweiten Reihe hinter dem Molok.

### 11.6 Vireo hat keine Waffe, die zu „lebt vom Bewegen“ passt

Sprint belohnt Treffer mit Lauftempo, aber keine Waffe belohnt das Laufen. Der Vireo macht wenig Schaden und fällt in
88 % der Kämpfe. Strix (Stillstand belohnt) und Vireo (Bewegung belohnt) wären schöne Gegenpole, aber nur eine Seite
ist gebaut.

### 11.7 Molok: Präsenz zieht alles, Power 6 gibt wenig zurück

Er ist der Tank, der stirbt, ohne etwas zu bewirken. Module helfen (Achse „getroffen werden“), aber die bereits geplante
**Waffe, die mit der maximalen Integrität skaliert**, würde das Grundproblem lösen. Ich würde sie vorziehen.

### 11.8 Waffenvorschläge

| Waffe | Klasse | Rw | Idee | Füllt Lücke |
|---|---|---|---|---|
| **Kettenpeitsche** | mittel | 2 | Fähigkeit zieht das Ziel 1 Feld heran und verlangsamt | mittel, Rw 2, Kontrolle |
| **Flammenwerfer** | mittel | 2 (Kegel) | trifft alle im Kegel, setzt Brand | mittel, Fläche, DoT |
| **Bollwerk-Ramme** | mittel | 1 | Fähigkeit: Schlag mit Schaden = 8 % max. Integrität, stößt zurück | Molok-Schaden aus Integrität |
| **Klingenbumerang** | leicht | 2 | trifft beim Hin- und Rückweg (2 Treffer), nach Bewegung +Schaden | Vireo-Identität, viele Treffer |
| **Mörser** | schwer | 6 (mind. 2) | Fläche Radius 1, Verzögerung, Rückstoß | zweite schwere Waffe, Fläche |
| **EMP-Werfer** | leicht | 3 | Fähigkeit: Störung (Schildpuls aus) | Status gegen Schild |

---

## 12. Umstellung alt → neu

| Alt | Neu |
|---|---|
| Schnellfeuer, Zeiger | Schnellfeuer |
| Wuchtkante (Nah, 15 %) | Wuchtkante (jede, 12 %) |
| Doppellauf (Fern) | Doppellauf (jede) |
| Langer Lauf | gestrichen, Reichweite in Revolverheld |
| Panzerplatte, Kette | Panzerplatte |
| Kondensator, Schaltkreis | Kondensator |
| Stachelgitter (nur Nah) | Stachelgitter (alle 2, Nah 4) |
| Verstärker | Fähigkeit +20 %, Status +30 % |
| Ködersender (3 s) | 2 s, Stapeln +1 s |
| Hologramm-Boost | Rezept Hologramm (KD + KS) |
| Orbit-Fokus | Rezept Orbit-Fokus (KS + PS) |
| – | Peilsender (neu) |
| Gunslinger (3 Zutaten) | SF + DL |
| Bollwerk | unverändert |
| Taktchip (Takt −1) | SF + VS, Zähler 1,25 |
| Taktgeber | Taktchip-BIOS |
| Raufbold (Nah) | WK + SG, jeder Treffer |
| Fesselkette (KT + KT + DL) | PP + KS |
| Rundumschlag (Cleave 100 %) | WK + KS, Cleave 60 % |

Technisch:

* Reihenfolge-Regel für Rezepte in `modules.json` entfällt (keine Ketten).
* `_recipe_twice` wird einfacher.
* Neue Wirkungs-Schlüssel (Vorschlag): `mark`, `mark_bonus`, `bonus_vs_marked`, `armor_to_damage`,
  `kinetic_to_energy`, `post_ability_power`, `thorns_all`, `thorns_true`, `ability_fork`, `chain_jumps`,
  `shield_break_burst`, `ability_armor_aura`, `mark_on_hit_taken`, `takt_count`.
* Neue Datenbereiche: `bios` in `modules.json`, `shop.reroll`, `shop.target_recipe`,
  `run.enemy_profiles`.

---

## 13. Offene Fragen -- beantwortet (9. Nov. 2026)

1. Waffen im Lauf: **fest**. `IDENTITAETEN.md` ist angepasst.
2. Bosse: **ja, am Ende jedes Story-Levels**; droppen dauerhafte Beute, tragen ein BIOS-Rezept.
3. Gegner-Profile: **über die Fraktion des Gebiets**, damit beim Start bekannt.
4. BIOS bei Elite: **statt des Teils**, zusätzlich zu den Credits; nie nach dem letzten Kampf.
5. Sperren im Laden: **nein**, Neuwürfeln reicht.
6. Waffen: zuerst **Bollwerk-Ramme, Mörser, Klingenbumerang**; Optik und Ton klärt der Spieler.

**Nachtrag 9. Nov. 2026 (Spieler):** Kein Zeit-Takt mehr -- alle Fähigkeiten zählen Angriffe.
Der Orbit-Fokus wurzelt statt zu ziehen. Balancing erst nach einem größeren Playtest
(„nicht nur die Zahlen, auch das Gefühl").

## 14. Bauplan

1. ~~Konzept festhalten~~ (dieses Dokument, 9. Nov.).
2. ~~9 Grundmodule und 18 Rezepte~~ (gebaut 9. Nov.; Messung in `PROJEKTSTAND.md`, Balancing offen).
3. ~~Laden (3 Angebote, Neuwürfeln, Ziel-Rezept), Waffen im Lauf fest~~ (gebaut 9. Nov.).
4. ~~BIOS: 4 Chassis-BIOS, 7 Rezept-BIOS~~ (gebaut 9. Nov.; Festung noch offen).
5. Profile und Fraktionen; ~~neue Waffen Bollwerk-Ramme, Moerser, Klingenbumerang~~ (gebaut 9. Nov., Startwerte).
