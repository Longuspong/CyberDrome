# CyberDrome – Waffen-Upgrades: Charger und Energy Phases

Stand 20. Nov. 2026 · Status: **entschieden und gebaut** (20. Nov. 2026; wirken tut vorerst nur Feuer).
Resonanz: die Stufen **zaehlen zusammen** (Spieler im Design-Canvas). Details zum Bau: `docs/PROJEKTSTAND.md`.
Bildschirme dazu: Übergabe an eine Design-Session in `docs/design/UEBERGABEN_DESIGN.md`
(Ü1 Waffen-Upgrade, Ü3 Charger-Crafter).

## 1. Grundidee

* Jede Waffe hat **einen Charger-Platz**. Der Charger ist **dauerhaft**: er bleibt nach dem
  Einsatz an der Waffe (anders als Module, die nur im Einsatz gelten).
* Ein Charger wird im Crafting-Tab aus einem **Charger-Rohling** und **bis zu 6 Energy Phases**
  gebaut (Hexagon, Ü3). Die Phasen werden dabei **verbraucht**.
* Rohlinge droppen aus Caches oder sind im Shop zu kaufen.
* Elemente: **Volt, Cryo, Terra, Feuer, Virus, Chaos** -- je eine Phase.

## 2. Elementarbelastung

* Jede Phase im Charger gibt **20 Elementarbelastung** ihres Elements **je Treffer** der Waffe.
* Die Belastung sammelt sich am Ziel. Der Treffer, mit dem sie **100** übersteigt, legt
  **einen Stapel** des Elements an (danach zählt der Rest weiter).
* Eine einzelne Phase bringt also fast nichts (5 Treffer für einen Stapel).
* **Überwiegt ein Element** im Charger, legt die **Fähigkeit** der Waffe einen Stapel dieses
  Elements an.
* Die Effizienz des Trägers wirkt auf Dauer und Stärke der Statuseffekte
  (`MODULE_AMP_FUSION.md` 5) -- so tragen Tech-Amp und Vireo-On-Hit-Builds.

## 3. Resonanz (gleiche Phasen)

| Gleiche Phasen | Resonanz (Feuer, vom Spieler festgelegt) |
|---|---|
| 2 | Die Fähigkeit legt immer **100** Elementarbelastung an (Nimbus mit Echo: 2 Stapel) |
| 4 | Jeder **5.** Treffer legt **doppelte** Elementarbelastung an |
| 6 | Jeder **3.** Treffer legt doppelte Elementarbelastung an, die Fähigkeit legt **200** an |

Offen: zählen die Stufen zusammen (6 enthält 2 und 4) oder ersetzt die höhere die niedrigere?
Vorschlag: die höhere ersetzt die niedrigere (in der Tabelle so formuliert).

## 4. Elemente und Statuseffekte

| Element | Statuseffekt | Wirkung |
|---|---|---|
| **Feuer** | Kabelbrand | gebaut: je Puls höchstens 10 Stapel, je Stapel 5 kinetisch + 5 Energie |
| **Cryo** | Freeze | langsamer angreifen, langsamer bewegen, auch langsamere Animationen |
| **Volt** | EMP | Silence (keine Fähigkeit) und Schwäche gegen Energie: Energiefaktor +0,2 (Schild 1,4, Integrität 1,2); mehr Stapel = längere Dauer |
| **Terra** | Säure / Stärkung | am Gegner: nimmt Rüstung, verhindert Regeneration und Overgrow. An Verbündeten: mehr Heilung, Regeneration und Rüstung |
| **Virus** | -- | etwas mit Virusschaden (absolut), später |
| **Chaos** | -- | würfelt den Charger je Einsatz neu zwischen den enthaltenen Elementen (wird überdacht) |

**Overgrow:** Fähigkeit der Solar Sentients, eine Art Überschild nur für Integrität (noch nicht gebaut).

**Zuerst gebaut wird nur Feuer.** Es ersetzt dann den übergangsweisen Kabelbrand am
Bumerang-Wirbelwurf.

## 5. Caches (Inhalt entschieden)

Jeder Cache würfelt **4-mal**:

| Ergebnis | Chance je Wurf |
|---|---|
| Fraktions-DROME | 0,5 % |
| Fraktionskern | 2,5 % |
| Baukern | 7 % |
| je Energy Phase (6 Sorten) | 12 % (zusammen 72 %) |
| Charger-Rohling | 12 % |
| sonst Platzhaltercoin (10-20, zufällig) | 6 % |

Später kommen Phasen auch aus einem Ressourcen-Tab.

## 6. Bedienung

Ziehen ist die Hauptbedienung, Doppeltipp zum Einsetzen bleibt als Ersatz.

## 7. Bauplan (Vorschlag)

1. Caches öffnen mit dem Inhalt oben (heute nur Vorschau, `CacheOpener`).
2. Phasen und Rohlinge als Bestand (`Roster`), Anzeige im Shop.
3. Charger als Gegenstand, Charger-Platz an der Waffe, Elementarbelastung und Feuer-Resonanz im Kampf.
4. Bildschirme nach den Entwürfen der Design-Session (Ü1, Ü3).
