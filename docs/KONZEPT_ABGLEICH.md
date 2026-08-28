# Konzept-Abgleich: Balancing-Tabelle ↔ Engine (Stand nach §13)

> **Zweck.** Diese Datei hält fest, was in `docs/ausruestung_stats.xlsx`
> (der kuratierten Balancing-Sicht) tatsächlich an Konzept steht, und wo die
> Engine (`tools/build_sample_parts.py` → `STATS`, plus die GDScript-Systeme)
> davon abweicht. Sie ist die Bestandsaufnahme VOR einer möglichen Umsetzung
> des vollen Klassenmodells — analog zu `MVP_M0_BESTANDSAUFNAHME.md`.

## 0. Was passiert ist (ehrlich)

Beim Umsetzen von §13 (Fähigkeiten von den Waffen) habe ich **ausschließlich aus
`STATS` in `tools/build_sample_parts.py` gearbeitet** und die im Repo liegende
Tabelle `docs/ausruestung_stats.xlsx` **nicht geöffnet**. Git-technisch war ich
aktuell (mein §13-Commit sitzt in `origin/main`), aber das **Konzept**, das in
der Tabelle steckt, habe ich übersprungen. Genau das ist der Punkt: die Tabelle
beschreibt ein deutlich breiteres Klassenmodell, von dem §13 nur eine schmale
Scheibe (aktive Fähigkeiten) umgesetzt hat — und die habe ich zudem inhaltlich
selbst erfunden, statt sie aus dem Konzept abzuleiten.

Die Tabelle war schon vor §13 im Repo (deine „Balancing-Liste", PRs #18–#20).
Die hochgeladene Version ist fast identisch; die einzige neue Änderung darin ist
die Notiz **„Ködersender erstmal streichen"** an EQP-008.

**Wichtig:** Die Tabelle ist ausdrücklich NICHT die Engine-Tabelle. Ihre Zahlen
sind gerundete, abstrahierte **Balancing-Vorschläge** (die Traglast steht dort
z. B. als 4–7, in der Engine als `weight_capacity` 18–33). Der Abgleich unten
zielt deshalb auf das **Modell** (welche Werte/Systeme es überhaupt gibt), nicht
auf 1:1-Zahlengleichheit.

---

## 1. Hülle / Chassis — der große Unterschied

**Konzept (Tabelle):** Der ganze Rahmen ist EIN Teil (§9c). Er trägt **zwei
getrennte Verteidigungen** und **genau eine Signatur-Passive je Klasse.**

| Code | Klasse | Integrität | **Energieschild** | **Panzerung** | Tempo | Move | Traglast | Slots | Signatur-Passive |
|---|---|---|---|---|---|---|---|---|---|
| CHS-001 | Vireo / Scout | 50 | 30 | 2 | 15 | 5 | 4 | 2 | **Adrenalin** |
| CHS-002 | Molok / Juggernaut | 150 | 50 | 15 | 10 | 3 | 7 | 3 | **Bollwerk** |
| CHS-003 | Nimbus / Technomant | 100 | 50 | 10 | 12 | 4 | 7 | 2 | **Energy-Junky** |
| CHS-004 | Strix / Marksman | 50 | 30 | 4 | 10 | 3 | 5 | 1 | **Straight Line** |

**Die Signatur-Passiven (je Klasse eine):**
- **Adrenalin (Vireo):** Nach einem Kill für den Zyklus +3 Tempo.
- **Bollwerk (Molok):** Fängt 50 % des Schadens ab, den verbündete DROMEs auf
  direkt angrenzenden Feldern (orthogonal ODER diagonal) nehmen würden. → eine
  **Beschützer-Aura**, ein völlig neues Kampfsystem.
- **Energy-Junky (Nimbus):** Je 10 auf Fähigkeiten ausgegebene Energie steigt der
  Schaden des nächsten Angriffs um 10 %.
- **Straight Line (Strix):** Schießt Strix auf ein Ziel, das orthogonal in einer
  Linie zu ihm steht, +50 % Schaden.

**Engine heute:**
- Chassis = Summe aus `body`+`head`+`feet`, **keine** Chassis-Ebene mit eigenem
  Statblock, **keine** Signatur-Passive.
- **Nur EINE Verteidigung** (`def`) und **eine Schadensart** (`normal`). Das
  **Energieschild** existiert nicht — das ist faktisch die Schadensordnung aus
  §11 (physisch/Energie + Panzerung/Schild), die die Tabelle **jetzt** ins
  Grundmodell zieht, während §11/§12c sie hinter den MVP gestellt hatte.
- Roh-Werte (Summe): Vireo hp60/def6/spd13/mov4 · Molok 145/9/5/2 · Nimbus
  85/2/13/5 · Strix 70/2/8/4. Andere Skala als die Tabelle — erwartbar.

**Lücke:** zwei Verteidigungen + Schild-Regeneration/-Bonus (siehe Kerne) +
vier Signatur-Passiven. Nichts davon ist in der Engine.

---

## 2. Waffen — Angriff **ohne** Fähigkeit, dafür mit Animation

**Konzept (Tabelle):** genau EINE Waffe je Klasse, zwei Kernwerte
(Schaden + Reichweite), plus **Angriffsdesign** = die visuelle Beschreibung der
Attacke. **Keine** aktive Fähigkeit an der Waffe in dieser Sicht.

| Code | Waffe | Klasse | Schaden | Reichweite | aoe | **Angriffsdesign (Animation)** |
|---|---|---|---|---|---|---|
| EQP-001 | Puls-Blaster | Vireo | 10 | 3 | nein | kleiner runder Laserpuls |
| EQP-003 | Belagerungskanone | Molok | 18 | 6 | ja (8 angrenzende Felder) | großer mörserartiger Schuss (mechanisch) |
| EQP-005 | Runenstab | Nimbus | 10 | 1 | ja (**4 angrenzende Felder orthogonal**) | kleine Clusterbombe aus Energie |
| EQP-007 | Schienen-Lanze | Strix | 22 | 8 | nein | railgunartiger Laserpuls (dreieckig, nach hinten schmaler) |

**Engine heute (nach §13):**
- Waffen tragen **Angriff + eine aktive Fähigkeit** (Streusalve, Präzisionsschuss,
  Sperrfeuer, Arkanwelle) — die Fähigkeiten habe **ich erfunden**, sie stehen
  NICHT in deinem Konzept.
- Werte weichen ab: Puls 12 (Tabelle 10), **Runenstab 18 Einzelziel** (Tabelle
  **10, AoE-Kreuz**), **Schienen-Lanze 16** (Tabelle **22**), Belagerung 18 (=).
- **Runenstab-Form:** Die Tabelle will ein **orthogonales Kreuz** (4 Felder),
  die Engine kennt nur `aoe_around_target` (voller Radius-Ring). Kreuzform =
  neue Zielform.
- **Animationen:** Die Engine hat nur generischen Rückstoß + Treffer-Blende
  (`Unit.play_attack/play_hit`). Die vier **Angriffsdesigns** (runder Laserpuls,
  Mörser, Energie-Cluster, dreieckige Railgun) sind **nicht** umgesetzt.

**Widerspruch, der zu klären ist:** Konzept-Tabelle = Waffe ist Angriff-only,
aktive Fähigkeit „kommt vom Kern" (alter §13-Text im Übersichtsblatt). Chat-
Entscheidung = aktive Fähigkeit **von der Waffe**. → Die Chat-Entscheidung gilt;
aber dann braucht die Tabelle je Waffe eine Fähigkeits-Zeile, und meine vier
erfundenen Fähigkeiten sind Platzhalter, bis du sie definierst.

---

## 3. Kerne — mehr als Energie: Schild-Werte, Passive, Loot-Kerne

**Konzept (Tabelle):**

| Code | Kern | Energie | En-Regen | **Schildregen** | **Schildbonus** | Passive | **Bonus-Stat** |
|---|---|---|---|---|---|---|---|
| COR-001 | Vireo Impulskern | 40 | 5 | 5 | 0.05 | **Hit & Run** | +5 Speed |
| COR-002 | Molok Fusionskern | 70 | 10 | 5 | 0.10 | **Overchargerepair** | +20 Integrität |
| COR-003 | Nimbus Arkankern | 65 | 15 | 10 | 0.20 | **Fast Forward** | +10 Energiepower |
| COR-004 | Strix Zielrechner | 50 | 5 | 5 | 0.10 | **Open-Scope** | +10 Power |
| COR-005 | **Effizienz-Kern** (Loot) | 50 | 7 | 10 | 0.05 | **Clean-Code** | 20 % Cooldown-Reduktion |
| COR-006 | **Verstärker-Kern** (Loot) | 80 | 5 | 10 | 0.05 | **Empowering** | +10 Energiepower |

**Die Kern-Passiven:**
- **Hit & Run (Vireo):** Trifft er im Zug zweimal (Angriff oder Fähigkeit), 2
  Felder gratis bewegen.
- **Overchargerepair (Molok):** Geht das Schild aus, 2 Züge lang 10 % Lebensregen.
- **Fast Forward (Nimbus):** Ein Zug ohne Fähigkeit → danach +50 % En-Regen bis
  zur nächsten Fähigkeit.
- **Open-Scope (Strix):** 20 % Chance, eine Schwachstelle zu treffen.
- **Clean-Code (Effizienz, Loot):** −20 % Energiekosten.
- **Empowering (Verstärker, Loot):** +40 % Energiekosten, aber +20 % Schaden auf
  Fähigkeiten.

**Engine heute:**
- Kerne tragen nur `en_max` / `en_regen` (+ `power_output`, das nichts mehr
  liest). **Keine** Schildregeneration, **kein** Schildbonus, **keine** Passive,
  **kein** Bonus-Stat, **keine** Loot-Kerne.
- Nimbus-Tank: Engine `en_max` 85 vs. Tabelle **65** (du hast ihn gesenkt).
- **Konsistent mit §13:** Der Kern trägt keine AKTIVE Fähigkeit — richtig. Aber
  er soll eine **PASSIVE** tragen (+ die beiden Loot-Kerne verändern die Kosten/
  Wirkung von Fähigkeiten). Passive ≠ Aktive: kein Widerspruch zu §13, nur eine
  weitere, unimplementierte Schicht.

---

## 4. Gadgets — ein Wert je Teil; Ködersender streichen

| Code | Gadget | Wirk-Wert | Wert | Wirkung | Engine-Abgleich |
|---|---|---|---|---|---|
| EQP-002 | Deflektor-Schild | Panzerung | 5 | passiv | ✅ passt (passiv, `def` +5) |
| EQP-004 | Drohnen-Pod | Integrität | 20 | **passive** Lebensregen 5 %/Zug zu Zugbeginn | ❌ Engine: **aktive** Heil-Fähigkeit (Reparaturdrohnen, AoE, −10) |
| EQP-006 | Orbit-Fokus | Energiepower | 5 | zieht Ziel 2 Felder heran | ✅ passt (aktiver Sog) |
| EQP-008 | Ködersender | Aggro | 25 | **erstmal streichen** | ❌ Engine: noch aktiv (Aggro-Bonus, Taunt in §13 schon entfernt) |

**Zwei Abweichungen:**
- **Drohnen-Pod:** Konzept = **passive** Selbstheilung 5 %/Zug. Engine = **aktive**
  Reparaturdrohnen-Fähigkeit. Das ist ein echter Modellwechsel (Passive statt
  Aktion).
- **Ködersender:** soll **raus** (vorerst). Engine hat ihn noch (EQP-008, mit
  `aggro_bonus`; die Provokation/Taunt ist in §13 bereits gestrichen).

---

## 5. Werkstatt / Baukasten

- **Chassis-Kachel zeigt nur das Körperteil.** Gewünscht: der **ganze Drome**
  (die Hülle = body+head+feet) in der Werkstatt-Bibliothek. → in diesem Zug
  umgesetzt (siehe `workshop_screen.gd`, `_chassis_tile_view`).

---

## 6. Zusammenfassung der Lücken (was §13 NICHT abdeckt)

| # | Konzept-Element | Engine | Größe |
|---|---|---|---|
| 1 | **Zwei Verteidigungen** (Energieschild + Panzerung) + Schildregen/-bonus | nur `def`, eine Schadensart | groß (= §11) |
| 2 | **Signatur-Passive je Chassis** (Adrenalin/Bollwerk/Energy-Junky/Straight Line) | keine | groß, neue Kampfsysteme |
| 3 | **Kern-Passive** (Hit&Run/Overchargerepair/Fast Forward/Open-Scope) | keine | mittel |
| 4 | **Loot-Kerne** (Effizienz/Verstärker) mit Kosten/Wirkungs-Modifikatoren | keine | mittel (§12a) |
| 5 | **Bonus-Stat je Kern** (+Speed/+Integrität/+Power …) | keiner | klein |
| 6 | **Angriffsdesigns/Animationen** je Waffe | generischer Rückstoß | mittel (Grafik) |
| 7 | **Runenstab als Kreuz-AoE**, revidierte Waffenwerte | Einzelziel, andere Zahlen | klein–mittel |
| 8 | **Drohnen-Pod passiv** statt aktiv | aktive Heilung | klein |
| 9 | **Ködersender streichen** | noch vorhanden | klein |
| 10 | Aktive Fähigkeiten je Waffe **benennen** (statt meiner Platzhalter) | erfunden | Design |

---

## 7. Offene Fragen (deine Entscheidung, bevor gebaut wird)

1. **Reihenfolge:** Zuerst das **Zwei-Verteidigungs-System** (§11, Punkt 1) — es
   trägt Bollwerk, Overchargerepair, Schildregen und die halbe Kern-Tabelle?
   Oder zuerst die **Passiven**?
2. **Passive-System:** Chassis- und Kern-Passiven sind sehr unterschiedliche
   Auslöser (nach Kill, bei Schild-Bruch, pro ausgegebener Energie, Positionslinie,
   Beschützer-Aura). Das ist ein eigenes kleines Trigger-/Effekt-System. In einem
   Rutsch, oder klassenweise?
3. **Aktive vs. Passive am Kern:** §13 sagt Aktive von der Waffe, die Tabelle gibt
   dem Kern eine **Passive**. Bestätige, dass beides koexistiert (Waffe = Aktive,
   Kern = Passive) — dann sind meine erfundenen Waffen-Fähigkeiten Platzhalter,
   bis du sie benennst.
4. **MOV als 4. Hüllen-Wert?** Das Übersichtsblatt fragt das ausdrücklich (Tempo
   = SPD gewählt, MOV weggelassen). Rein oder ersetzen?
5. **Drohnen-Pod:** passiv (Konzept) oder aktiv (Engine) — umstellen?
6. **Ködersender jetzt streichen** (Teil, JSONs, Tests) — ja?

> Nichts davon habe ich unaufgefordert umgebaut. Dieser Abgleich ist die
> Grundlage; welche Punkte in welcher Reihenfolge, entscheidest du.
