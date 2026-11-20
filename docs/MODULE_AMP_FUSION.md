# CyberDrome – Module v3: Amp, Fusion, Hyperfusion

Stand 20. Nov. 2026 · Status: **Richtung vom Spieler festgelegt (19./20. Nov. 2026), noch nicht gebaut** (außer Effizienz und Kabelbrand, Abschnitt 5).
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
| **Armor** | +3 Panzerung | +9 | fest (Panzerung wirkt schon über eine Kurve als Faktor, 20. Nov. 2026) |
| **Tech** | +2 Effizienz (Abschnitt 5) | +6 | fest (Effizienz ist selbst ein Faktor) |

**Grundsatz (Spieler):** lieber Prozent -- was schon ein Faktor ist (Power, Panzerung, Effizienz), bleibt fest. Feste Abwehrwerte wären für Tanks uninteressant oder für
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

## 5. Effizienz und Statuseffekte (20. Nov. 2026)

**Effizienz** ist ein versteckter Wert je DROME, Grundwert **10 = 100 % Wirkung**
(`config.json` -> `statuses.efficiency`). Der Tech-Amp gibt **+2** (= +20 %).

* Effizienz ändert **nie die Schadenszahl** (das bleibt Power).
* Sie streckt die **Dauer** jedes Statuseffekts, den der DROME auslöst: Verlangsamen des
  Vortex, Betäuben des Hammers, Wurzeln, Locken, auch den **eigenen Vireo-Sprint**
  (`Unit.apply_status(..., source)`).
* Bei Stapel-Effekten ohne Dauer (Kabelbrand) erhöht sie die **Zahl der Stapel**: Effizienz 15
  legt je Treffer 1,5 Stapel, Bruchteile sammeln sich am Ziel.
* **Gebaut** als Wert am DROME (`Unit.efficiency()`, `DromeBuild.stats()["efficiency"]`).
  Der Tech-Amp selbst ist noch nicht gebaut (Modulsystem in Arbeit).

Offen: ob Effizienz auch die **Stärke** von Effekten hebt (z. B. stärker verlangsamen), oder nur
Dauer und Stapel. Heute nur Dauer und Stapel.

**Kabelbrand** (erster Statuseffekt mit Stapeln, gebaut):

* Jeder Puls des Ziels (alle 3 s) verbraucht **höchstens 10 Stapel**. Je Stapel
  **5 kinetischer + 5 Energieschaden**, ohne Power, durch Schild und Panzerung wie ein Treffer.
* Nicht verbrauchte Stapel bleiben liegen und brennen im nächsten Puls.
* Auslöser übergangsweise: der **Wirbelwurf des Klingenbumerangs** gibt jedem getroffenen Gegner
  einen Stapel. Später kommen die Auslöser über die **Firecharger-Upgrades** des neuen Waffensystems.
* Werte in `config.json` -> `statuses.cable_fire`, Rechnung in `ActionResolver.burn_cable_fire`.

## 6. Offen

1. Sondereffekte der übrigen fünf Hyperfusionen (Abschnitt 3).
2. Auswahl der Fusionen (Abschnitt 4).
3. Preis und Häufigkeit des Fusion Core im Laden.
4. Effizienz: nur Dauer und Stapel, oder auch die Stärke von Effekten (Abschnitt 5)?
5. Hinweis zu Prozentwerten: Shield +10 % bringt dem Molok (10 Schild) nur +1. So gewollt
   (Spieler, 20. Nov. 2026).
