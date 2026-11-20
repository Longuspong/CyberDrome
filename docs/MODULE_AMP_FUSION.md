# CyberDrome – Module v3: Amp, Fusion, Hyperfusion

Stand 20. Nov. 2026 · Status: **Richtung vom Spieler festgelegt (19./20. Nov. 2026), noch nicht gebaut.**
Ersetzt die Grundmodule und Rezepte aus `MODULE_KONZEPT.md` (Abschnitte 4 und 5). Was dort zu
Modulplätzen, BIOS-Vergabe, Laden und Gegner-Profilen steht, gilt weiter, soweit hier nichts
anderes steht. Zahlen sind Startwerte für den Bench.

## 1. Die vier Stufen

| Stufe | Was | Wie entsteht es | Grenze |
|---|---|---|---|
| **Amp** (Amplifikator) | ein Wert, sofort lesbar | Laden, Beute | keine |
| **Fusion** | zwei **verschiedene** Amps: beide Werte + eigener Effekt | kostenlos im Rezeptbuch | keine |
| **Hyperfusion** | zwei **gleiche** Amps + **Fusion Core**: dreifacher Wert eines Amps + Sondereffekt | Fusion Core nötig | **1 je DROME**, jede Sorte **1× je Einsatz** |
| **BIOS** | wertet eine Fusion oder eine Hyperfusion auf | Elite-Sieg (wie bisher) | 1 je DROME |

* **Fusion Core:** bedingungslos, passt für jede Hyperfusion. Vorerst **seltenes Angebot im Laden**.
* Eine Hyperfusion **und** ein BIOS dürfen auf demselben Teil liegen (BIOS-Hyperfusion,
  das „Powerhouse“). Da es nur ein BIOS je DROME gibt, begrenzt sich das selbst.
* Beim Molok (zwei Waffen) gelten die Grenzen **je DROME**, nicht je Waffe.
* Zwei gleiche Amps ohne Core bleiben einfach zwei Amps (je einfacher Wert).

## 2. Amps (6)

Sechs Amps ergeben genau **15 Fusionen** (jedes Paar) und **6 Hyperfusionen**.

| Amp | Wert je Stück | Hyperfusion (×3) | Art |
|---|---|---|---|
| **Attack** | +10 % Angriffstempo | +30 % | Prozent |
| **Power** | +1 Power | +3 Power | fest (Power ist selbst ein Faktor: Schaden und Heilung = Grundwert × Power / 10) |
| **Integrity** | +10 % max. Integrität | +30 % | Prozent |
| **Shield** | +10 % max. Schild | +30 % | Prozent |
| **Armor** | offen (Abschnitt 5) | | |
| **Tech** | offen (Abschnitt 5) | | |

**Grundsatz (Spieler):** lieber Prozent. Feste Abwehrwerte wären für Tanks uninteressant oder für
Damage Dealer zu stark. Prozent verstärkt, was ein Chassis schon kann.

## 3. Hyperfusionen

| Hyperfusion | Sondereffekt | Status |
|---|---|---|
| **Power** | 20 % des Schadens werden **Virusschaden** | entschieden |
| Attack, Integrity, Shield, Armor, Tech | je ein Wert auf die Spitze getrieben | offen, Vorschläge unten |

**Virusschaden** (als Schadensart, wie beim Virus-Puls): ignoriert die Panzerung und die
Schild-Faktoren (physisch 0,8 / Energie 1,2), trifft aber weiter **zuerst den Schild**, dann die
Integrität.

Vorschläge (nicht entschieden):

* Attack: jeder 4. Angriff trifft doppelt.
* Integrity: einmal je Kampf bei 0 Integrität mit 30 % zurück.
* Shield: Schild lädt auch unter Beschuss, mit halber Rate.
* Armor: Panzerung wirkt auch gegen Virusschaden (Konter zur Power-Hyperfusion).
* Tech: die Fähigkeit wird sofort ein zweites Mal ausgelöst.

## 4. Fusionen

**Grundsatz (Spieler):** lieber wenige handgefertigte Fusionen, die Sinn ergeben, als eine volle
Tabelle mit kaum nutzbaren Effekten. Eine Fusion muss nutzbar sein, aber nicht jeder Waffe
gleich viel bringen (ein Support braucht keine Power-Hyperfusion, darf sie aber tragen). Was aus
dem alten System wegfällt (Köder-, Peilsender, Stachelgitter, Markierung ...), muss nicht als
Fusion zurückkommen. Leere Felder sind erlaubt. **Welche Fusionen es gibt, entscheidet der Spieler.**

Vom Spieler genannt:

* **Integrity + Power:** Heilung und Schildgabe werden stärker.
* **Attack + Armor:** ein Teil des eingesteckten Schadens verstärkt die eigenen Angriffe
  (entspricht dem alten Raufbold).

Vorschläge zum Auswählen (aus den alten Rezepten, nicht entschieden):

|  | Power | Integrity | Shield | Armor | Tech |
|---|---|---|---|---|---|
| **Attack** | Doppellauf (Zusatztreffer) | Lebensraub (Treffer heilen) | Überspannung (kinetisch wird Energie, solange der Schild steht) | **Raufbold** (Spieler) | Taktchip (Angriffe zählen mehr für den Takt) |
| **Power** | | **Heilung stärker** (Spieler) | Entladung (Schildbruch löst Energie-Stoß aus) | Rammbock (kinetischer Zusatzschaden aus Panzerung) | Peilsender (Markierung) |
| **Integrity** | | | Bollwerk (Schild lädt früher) | Stachelgitter (Angreifer nehmen Schaden) | Brandmarke (Angreifer werden markiert) |
| **Shield** | | | | Schutzimpuls (Panzerung für Nachbarn) | Hologramm (Sprung weg, Köder bleibt) |
| **Armor** | | | | | Fesselkette (zieht Gegner heran) |

Kinetischer und Energieschaden sind **keine Amps**, sondern höchstens Effekte von Fusionen
(etwa Überspannung, Rammbock, Entladung).

## 5. Offen

1. **Tech-Amp:** gesucht ist ein Wert, der wie Power automatisch wirkt, und zwar auf
   **Wirksamkeit und Dauer** von Fähigkeiten und Statuseffekten. Der Spieler denkt noch darüber
   nach. Idee: Tech als eigener Wert am DROME (Grundwert 10, Wirkung und Dauer × Tech / 10),
   das Amp gibt +1. Risiko: Fähigkeitsschaden hängt schon an Power und würde dann doppelt wachsen.
   Dann sollte Tech nur Dauer und Nicht-Schadenswirkungen tragen (Heilung? Schildgabe? Betäubung,
   Wurzeln, Markierung ...).
2. **Armor-Amp in Prozent:** Vireo, Nimbus und Strix haben 1 bis 2 Panzerung. +10 % davon sind
   praktisch nichts, nur der Molok (14) bekäme etwas. Panzerung wirkt schon über eine Kurve mit
   abnehmendem Ertrag (höchstens +50 % eHP). Vorschlag: Armor wie Power **fest** (+3), weil die
   Kurve den Wert selbst schon in einen Faktor verwandelt. Entscheidung des Spielers.
3. Sondereffekte der übrigen fünf Hyperfusionen (Abschnitt 3).
4. Auswahl der Fusionen (Abschnitt 4).
5. Preis und Häufigkeit des Fusion Core im Laden.
6. Hinweis zu Prozentwerten: Shield +10 % bringt dem Molok (10 Schild) nur +1. Das passt zu
   „Prozent verstärkt Stärken“, sollte aber bekannt sein.
