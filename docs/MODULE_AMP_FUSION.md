# CyberDrome – Module v3: Amp, Fusion, Hyperfusion

Stand 20. Nov. 2026 · Status: **gebaut** (20. Nov. 2026): 6 Amps, 15 Fusionen (2 entschieden, 13 Vorschläge), 6 Hyperfusionen mit Fusion Core (Sondereffekt nur Power), BIOS für Fusionen. Offene Punkte: `docs/design/UEBERGABEN_DESIGN.md`, Abschnitt „Offene Logik“.
Ersetzt das Modulsystem v2 (`MODULE_KONZEPT.md`, gelöscht 26. Nov. 2026). Was davon weiter gilt
-- Modulplätze, BIOS, Laden, Lager, Gegner-Profile --, steht jetzt in Abschnitt 6. Zahlen sind
Startwerte für den Bench.

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

**Effizienz** ist ein **sichtbarer Wert am Chassis wie Power** (seit 20. Nov. 2026 abends,
vorher versteckt), **10 = 100 % Wirkung** (`config.json` -> `statuses.efficiency`). Der Tech-Amp
gibt **+2** (= +20 %). Trennung: **Power = wie viel** (Schaden, Heilung, Schildgabe),
**Effizienz = wie gut ein Statuseffekt wirkt** (Dauer, Stapel, Stärke).

| DROME | Power | Effizienz | Gedanke |
|---|---|---|---|
| Vireo | 10 | 10 | |
| Molok | 6 | **14** | Kontrolle über Hammer-Betäubung und Locken |
| Nimbus | 12 | **12** | Allrounder: Fähigkeiten und Schaden |
| Strix | 15 | 10 | |
| Neon Nimbus (Gegner) | **14** | **7** | nur eine Schadensklasse, stark durch doppelte Fähigkeiten (Echo) |

* Effizienz ändert **nie die Schadenszahl** (das bleibt Power).
* **Dauer:** jeder Statuseffekt, den der DROME auslöst, hält × Effizienz / 10: Verlangsamen des
  Vortex, Betäuben des Hammers, Wurzeln, Locken, auch den **eigenen Vireo-Sprint**
  (`Unit.apply_status(..., source)`).
* **Stärke:** die Abweichung von 1 bei Tempo- und Schadensfaktoren wächst mit (Verlangsamen 40 %
  bei Effizienz 12: 48 %). Verlangsamen höchstens 70 % (`slow_cap`). Ob die Stärke langsamer
  wachsen soll als die Dauer, wird später ausbalanciert.
* **Stapel** ohne Dauer (Kabelbrand): Effizienz 15 legt je Treffer 1,5 Stapel, Bruchteile sammeln
  sich am Ziel.
* Der Tech-Amp selbst ist noch nicht gebaut (Modulsystem in Arbeit).

**Kabelbrand** (erster Statuseffekt mit Stapeln, gebaut):

* Jeder Puls des Ziels (alle 3 s) verbraucht **höchstens 10 Stapel**. Je Stapel
  **5 kinetischer + 5 Energieschaden**, ohne Power, durch Schild und Panzerung wie ein Treffer.
* Nicht verbrauchte Stapel bleiben liegen und brennen im nächsten Puls.
* Auslöser übergangsweise: der **Wirbelwurf des Klingenbumerangs** gibt jedem getroffenen Gegner
  einen Stapel. Später kommen die Auslöser über die **Firecharger-Upgrades** des neuen Waffensystems.
* Werte in `config.json` -> `statuses.cable_fire`, Rechnung in `ActionResolver.burn_cable_fire`.

## 6. Was aus dem Modulsystem v2 weiter gilt (9.–19. Nov. 2026)

**Rahmen**

* Module gibt es nur im Einsatz, am Ende verfallen sie. Sie stecken im Waffenhalter: **3 Plätze je
  Waffe** (Molok 2 + 2), fest -- kein Level und kein BIOS gibt Plätze dazu.
* **Waffen sind im Einsatz fest.** Erbeutete Waffen gehen in die Tasche und wirken erst danach.
  Deshalb weiß der Laden, in welchem Halter ein Modul wirkt.
* Eine Fusion nur einmal je Halter, Amps dürfen sich stapeln.

**BIOS** (voller Name Matrix-BIOS; Daten `modules.json` -> `bios`, `bios_recipes`)

* Nach **jedem gewonnenen Elite-Kampf** fest eine Wahl 1 aus 3 (`rules.bios_offers`), nie nach dem
  letzten Kampf, bis drei BIOS vergeben sind (`rules.bios_elite_wins`, eins je DROME). Danach statt
  der Wahl ein Lootcache. Chaos-Kämpfe geben mit 33 % eine Wahl.
* Angeboten wird nur, was nutzbar ist, in dieser Rangfolge: **sofort** (die Fusion steckt in einem
  Halter), **bald** (beide Amps vorhanden), **angefangen** (ein Amp vorhanden). Nie leer.
* Ein BIOS liegt im Lager und wird im Rezeptbuch verschmolzen (Fusion + BIOS oder Amp + Amp +
  BIOS). Nicht trennbar, **höchstens eins je DROME**. Kein Chassis-BIOS, keine Extra-Plätze
  (seit 18. Nov. 2026).
* Heute fünf: Taktgeber (Taktchip: nach der Fähigkeit sofort geladen), Berserker (Raufbold:
  Vergeltung bis 5×, volle Ladung trifft alle daneben), Treibjagd (Brandmarke: die Markierung
  springt weiter), Abrissbirne (Rammbock: jeder 3. Angriff stößt zurück), Phasenbruch
  (Überspannung: +15 % gegen Gegner ohne Schild).

**Laden, Lager, Verkauf** (`modules.json` -> `shop`, `sell_value`; `config.json` -> `run`)

* 3 Angebote je Stopp, Neuwürfeln 2 Credits (+1 je weiterem Wurf). Ziel-Fusion im Rezeptbuch
  markieren: ihre fehlenden Amps kommen 3× so oft, ohne Ziel 2×. Ab Runde 5 gelegentlich eine
  fertige Fusion, selten ein Fusion Core.
* Lager 8 Plätze. Verkauf: Amp 2, Fusion 6, BIOS 8, Core 4 Credits.

**Gegner-Profile = Fraktionen** (`regions.json` -> `faction`)

| Gebiet / Fraktion | Profil | Handschrift |
|---|---|---|
| Neon City / Neon Ninja's | Kämpfer | Nahkämpfer, die dicht ranrücken: Klingen, Hämmer, Rammen |
| Parkanlage / Solar Sentients | Rudel | viele leichte DROMEs, die sich gegenseitig verstärken |
| Factory 5 / Mega Mechas | Festung | schwere Panzer, Schilde, Artillerie aus der zweiten Reihe |
| Dachterrassen / Hipstar Hackers | offen | -- |


## 7. Offen

1. Sondereffekte der übrigen fünf Hyperfusionen (Abschnitt 3).
2. Auswahl der Fusionen (Abschnitt 4).
3. Preis und Häufigkeit des Fusion Core im Laden.
4. Effizienz: soll die Stärke langsamer wachsen als die Dauer (Balance später)?
6. Passiven: Neon Vireo hat eine andere Passive -- bekommt der Neon Nimbus auch eine eigene,
   oder der normale Nimbus eine andere als der Neon Nimbus? (Spieler denkt nach)
5. Hinweis zu Prozentwerten: Shield +10 % bringt dem Molok (10 Schild) nur +1. So gewollt
   (Spieler, 20. Nov. 2026).
