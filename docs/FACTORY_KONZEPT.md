# Factory-Builder -- Konzept (22./23. Nov. 2026)

Stand: **Richtung entschieden (Spieler 22./23. Nov. 2026), Prototyp v2 gebaut,
noch nichts im Spiel.** Prototyp als Artefakt:
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

**v3 (Vorschlag):** DROME-Teile und Verschmelzen, Tier 3/4 mit Inhalt, große
Gebäude, Lager-Obergrenze, Rezept-Zahlen nach Abschnitt 5/6.

## 10. Kleinkram vor dem Go-live (aus den Reviews, 22. Nov. 2026)

* Generator/Strom: Zustand aus dem Vortakt wirkt einen Takt verzögert.
* Verarbeitung nach Bau-Reihenfolge statt Flussrichtung (ein Takt Versatz).
* Resonanz-Anzeige mit `Math.round` (in v2 erledigt).
* `relayCount` nutzte die globale Auswahl (in v2 entfallen).
* Bedarfe: „im Lager“ und „reserviert“ trennen, falls mehrere Bedarfe parallel
  oder Teillieferungen kommen.
* Speicherstand mit Version und Umstellung (Prototyp: `cd-factory-v2`).
* Fabrik-Stand muss in den echten Spielstand (`GameState`).
