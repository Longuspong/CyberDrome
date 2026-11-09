# Identitaeten der DROMEs und Waffen -- Bestandsaufnahme

Stand 8. Nov. 2026. Grundlage fuer das Gespraech mit dem Spieler, BEVOR Level
fuer DROMEs und Waffen gebaut werden (Wunsch des Spielers: erst Identitaet
und Werte klaeren, daraus folgt, was ein Levelaufstieg bringt). Zahlen aus
`parts/` und `DromeBuild.stats()` der Standardausstattung.

## 1. Die vier DROMEs heute

| | Vireo | Molok | Nimbus | Strix |
|---|---|---|---|---|
| Rolle (KI) | Plaenkler | Vorhut / Tank | Kontrolle | Scharfschuetze |
| Integritaet | 60 | 200 | 85 | 70 |
| Schild | 30 | 10 | 50 | 30 |
| Panzerung (DEF) | 1 | 14 (mit Deflektor) | 2 | 2 |
| SPD (Tempo) | 14 (1,88 Felder/s) | 6 (1,20) | 13 (1,79) | 8 (1,37) |
| ATK | 0 | 0 | 0 | 4 (Kopf) |
| Passive | Sprint: Treffer -> 2 s +40 % Tempo | Praesenz: lockt im Umkreis 2, faengt 30 % Schaden von Nachbarn ab | Echo: Faehigkeiten wirken doppelt, Takt +50 % | **keine** |
| Waffenhalter | 1 (bis mittel) | 2 (schwer + Schild/Support) | 1 (bis mittel) | 1 (bis schwer) |
| Standardwaffe | Puls-Blaster | Hammer + Deflektor | Runenstab | Schienen-Lanze |
| Kampfwert | 130 | 362 | 168 | 186 |

## 2. Die Waffen heute (roher Schaden ohne Panzerung)

| Waffe | Klasse | Angriff | Rw | Faehigkeit (Takt) | grob Schaden/s |
|---|---|---|---|---|---|
| Puls-Blaster | leicht | 10 alle 1,4 s, halb Energie | 3 | Doppelschuss 2x7 (jeder 3.) | ~10 |
| Neon-Blaster | leicht | 10 alle 1,4 s, halb Energie | 3 | Schildbrecher 12, doppelt gegen Schild (jeder 3.) | ~10, viel gegen Schild |
| Plasmaklinge | leicht | 12 alle 1,0 s | 1 | Aufschlitzen 18 + verwundbar 5 s (jeder 3.) | ~18 |
| Runenstab | leicht | 9 alle 1,2 s, Energie | 3 | Vortex 14 Flaeche r2 + Sog + verlangsamt (alle 3 s) | ~14 mit Echo, Flaeche |
| Hammer | schwer | 16 alle 1,8 s | 1 | Betaeubungsschlag 16 + 1 s betaeubt (jeder 3.) | ~12 |
| Schienen-Lanze | schwer | 22 alle 2,6 s | 8 | Praezisionsschuss 26 (jeder 4.) | ~10 (+ ATK 4 -> ~13) |
| Deflektor-Schild | mittel | 6 alle 1,5 s | 1 | Schildladung +15 Schild (jeder 4.), +5 DEF | ~4 |
| Drohnen-Pod | leicht | 4 Schaden / 6 Heilung alle 1,5 s | 3 | Schutzdrohne +15 Schild an Verbuendeten (jeder 4.) | ~3 + Heilung |
| Orbit-Fokus | leicht | -- | 4 | Orbit-Sog: zieht 2 Felder (alle 6 s) | 0 |
| Hologramm-Boost | leicht | -- | 3 | Sprung weg, wenn Gegner daneben (alle 4 s) | 0 |
| Koedersender | leicht | -- | -- | lockt im Umkreis 2 | 0 |

## 3. Was auffaellt

1. **Der Strix hat keine Passive** und keine eigene Idee ausser Reichweite.
   Seine ATK 4 kommt nur aus dem Kopf -- ATK hat sonst niemand.
2. **Vireo und Strix sind sich in den Werten aehnlich** (60-70 / 30 Schild),
   unterscheiden sich nur ueber Tempo und Waffe.
3. **Der Nimbus macht den meisten Schaden** und hat dazu den groessten Schild
   -- er ist Kontrolle UND Schadensquelle.
4. **Drei Teile sind keine Waffen**: Orbit-Fokus, Hologramm-Boost,
   Koedersender. Laut 6g sollten sie Module werden (der Koedersender ist es
   als Modul schon zusaetzlich).
5. **Waffen gehoeren zu niemandem**: jede leichte Waffe passt in jeden Halter.
   Die Identitaet steckt bisher im Chassis, nicht in der Waffe.
6. **Werte-Satz**: Integritaet, Schild, Panzerung, Tempo und ATK -- ATK ist
   fast tot (nur Strix-Kopf). 6b schlug eine "Leistung" (LST) fuer
   Faehigkeitsschaden vor, nie entschieden.

## 4. Fragen zur Klaerung (mit Vorschlag)

**A. Ein Satz Identitaet je DROME** (daraus folgt das Level):

| DROME | Vorschlag Identitaet | Level koennte bringen |
|---|---|---|
| Vireo | schnell, trifft oft, lebt vom Bewegen | Tempo / Sprint laenger |
| Molok | haelt aus und schuetzt andere | Integritaet / mehr abfangen |
| Nimbus | Faehigkeiten, Flaeche, Kontrolle | Faehigkeitsschaden / Takt |
| Strix | wenige, sehr harte Treffer aus der Ferne | Schaden je Treffer / Reichweite |

**B. Passive fuer den Strix**, Vorschlag: "Zielerfassung" -- jeder Treffer
auf dasselbe Ziel macht den naechsten haerter (z. B. +15 % je Treffer, bis
3x), Zielwechsel setzt zurueck. Passt zur Regel "Ziel halten".

**C. Werte-Satz verschlanken**: ATK streichen (der Strix-Kopf gibt dann ueber
die Passive seine Haerte) oder als "Schaden %" je DROME fuehren?

**D. Waffen und Identitaet**: bleiben Waffen frei fuer alle (Halter regelt
nur die Klasse), oder bekommt jede Waffe einen "Heimat-DROME" mit Bonus?

**E. Die drei Nicht-Waffen** (Orbit-Fokus, Hologramm-Boost, Koedersender):
zu Modulen machen und als Ausruestung streichen?

**F. Waffen-Level allgemein**: steigt die Waffe in ihrem Kernwert (Schaden
oder Tempo), oder in ihrer Faehigkeit (Takt kuerzer, Wirkung staerker)?

---

## 5. Entscheidungen des Spielers (8. Nov. 2026)

**Werte eines DROME** -- nur noch diese:

* **Speed** (Lauftempo)
* **Integritaet** (HP)
* **Schild**
* **Schildpuls** -- EIN Wert fuer zwei Dinge: wie lange man ohne Schaden sein
  muss, bis der Schild laedt, UND wie viel Schild je Puls (3 s) zurueckkommt.
* **Ruestung**
* **Slots** (Waffenhalter)
* **Power** (neu) -- Faktor, mit dem der Schaden der Waffe skaliert. Damit
  wird z. B. ein Squad aus vier Moloks mit je zwei Runenstaeben und
  Taktgeber nicht zu stark: der Molok hat wenig Power, der Nimbus viel.

ATK entfaellt. Hohe Power gleicht der Strix mit wenig Speed aus, der Nimbus
mit wenig Integritaet und Ruestung.

**Die vier Identitaeten:**

* **Vireo** -- der schnelle Allrounder, traegt nur eine **leichte** Waffe.
* **Molok** -- der harte Zweihaender, will in die Frontlinie. (Spaeter fuer
  Off-Tank-Aufbauten: eine Waffe, deren Faehigkeit mit der maximalen
  Integritaet des Traegers skaliert.)
* **Nimbus** -- fragil, schildlastig, Richtung Faehigkeiten.
* **Strix** -- Langstrecke mit schwerem Scharfschuetzengewehr. **Passive:**
  nach 4 s ohne Bewegung +20 % Schaden und Reichweite.

**Gewichtsklassen:** Hammer und Schild werden **mittel**, schwer ist nur,
was wirklich schwer ist (Schienen-Lanze). So verwischt der Molok nicht.

**Werte einer Waffe:** Schadensart (Energie oder kinetisch), Schaden,
Angriffstempo, Takt, Faehigkeit, Reichweite. Der Autoangriff ist der normale
Angriff. Dazu gibt **jede Waffe einen DROME-Wert**:

| Waffe | Bonus-Wert |
|---|---|
| Plasmaklinge | Power (damit auch fuer den Molok interessant) |
| Schild (Deflektor) | Ruestung |
| Hammer | Integritaet |
| Puls-Blaster | Speed |
| Neon-Blaster | Schildpuls |
| Drohnen-Pod | Integritaet |
| Runenstab | Schild |
| Schienen-Lanze | Power |

**Frei fuer alle:** keine Heimatwaffe, jede Waffe darf jeder tragen -- nur
die Gewichtsklasse zaehlt.

**Die drei Nicht-Waffen** (Orbit-Fokus, Hologramm-Boost, Koedersender)
werden Module.

**Waffen-Level:** es steigen immer **zwei Werte** -- der Bonus-Wert der
Waffe und der Schaden (oder das Angriffstempo). Faehigkeit und Takt bleiben
gleich; die Faehigkeit wird staerker, weil ihr Schaden am Waffenschaden
haengt. Beispiel Neon-Blaster: Schildpuls und Energieschaden steigen,
kinetischer Schaden und Tempo nicht. Puls-Blaster: Energie- und kinetischer
Schaden sind gleich hoch und steigen gemeinsam, dazu Speed, das Tempo nicht.

## 6. Gebaut (8./9. Nov. 2026)

Zahlen nach der Rueckmeldung des Spielers. Stellschrauben: `tools/build_sample_parts.py`
(STATS), `data/config.json` -> `combat.shield_pulse`, `passives.steady`, `levels`.

| | Vireo | Molok | Nimbus | Strix |
|---|---|---|---|---|
| Speed | 12 | 10 | 12 | 7 |
| Integritaet | 80 | 250 | 60 | 100 |
| Schild | 50 | 50 | 60 | 30 |
| Schildpuls | 5 | 5 | 10 | 5 |
| Ruestung | 2 | 10 | 0 | 2 |
| Halter | 1 leicht | 2 bis mittel | 1 bis mittel | 1 bis schwer |
| Power | 10 | 6 | 12 | 15 |
| Modulplaetze je Halter | 3 | 2 | 3 | 3 |
| Passive | Sprint | Praesenz | Echo | Anlegen (4 s still: +20 % Schaden/Reichweite) |

* **Power:** Rohschaden = Waffenschaden x Power / 10 (1 Punkt = 10 %).
* **Schildpuls S:** Ruhezeit 6 s - 0,3 s je Punkt (mind. 1,5 s), Ladung
  2 x S Schild je Puls (3 s). S 5: 4,5 s / +10; S 10: 3 s / +20.
* Gewicht und ATK sind gestrichen; Kopf, Antrieb, Kern haben keine Werte.

**Schadensrechnung** (`ActionResolver.resolve_damage`):

1. Rohschaden = Schaden der Aktion x Power / 10 (angelegt x 1,2 beim Strix),
   bei "verwundbar" x 1,5.
2. Aufteilen nach Art: Energieanteil und kinetischer Anteil (Puls-Blaster
   5 + 5, Neon-Blaster 4 + 6).
3. **Am Schild:** kinetisch x 0,8, Energie x 1,2 (Schildbrecher dazu x 2).
   Was der Schild nicht mehr fasst, laeuft als Rohschaden (ohne Faktor) auf
   die Integritaet durch.
4. **An der Integritaet:** beide Arten x 1,0, dann die **Ruestung** als
   Teiler mit abnehmendem Ertrag: Schaden / (1 + 0,5 x R / (R + 15)).
   Ruestung 10 nimmt 17 % weg, 15 nimmt 20 %, nie mehr als ein Drittel.
   Mindestens 1 Schaden.

Kinetisch ist also gut gegen Integritaet und Tanks, Energie gegen Schilde.

**Waffen** (Faehigkeit = Anteil des Waffenschadens):

| Waffe | Klasse | Schaden | Tempo | Rw | Faehigkeit | Bonus (Lv 0 -> 10) |
|---|---|---|---|---|---|---|
| Puls-Blaster | leicht | 5 kin + 5 En | 1,4 s | 3 | jeder 3.: Doppelschuss 2 x 70 % | Speed 2 -> 3 |
| Neon-Blaster | leicht | 4 kin + 6 En | 1,4 s | 3 | jeder 3.: Schildbrecher 120 % | Schildpuls 2 -> 4 |
| Plasmaklinge | leicht | 12 kin | 1,0 s | 1 | jeder 3.: Aufschlitzen 150 % + verwundbar | Power 1 -> 2 |
| Runenstab | leicht | 9 En | 1,2 s | 3 | alle 3 s: Vortex 150 % | Schild 10 -> 20 |
| Drohnen-Pod | leicht | 4 En / Heilung 6 | 1,5 s | 3 | jeder 4.: Schutzdrohne +15 | Integritaet 10 -> 20 |
| Hammer | mittel | 16 kin | 1,8 s | 1 | jeder 3.: Betaeubungsschlag 100 % | Integritaet 20 -> 40 |
| Schild | mittel | 6 kin | 1,5 s | 1 | jeder 4.: Schildladung +15 | Ruestung 4 -> 8 |
| Schienen-Lanze | schwer | 22 kin | 2,6 s | 8 | jeder 4.: Praezisionsschuss 120 % | Power 1 -> 2 |

Beispiel Strix mit Lanze: Power 15 + 1 = 16, Angriff 22 x 1,6 = 35,
Praezisionsschuss 26 x 1,6 = 42; angelegt x 1,2 -> 42 / 50.

**Level** (`scripts/core/leveling.gd`):

* **Waffe 0-10:** Schaden +7 % je Level (Level 10 = +70 %), dazu der
  Bonus-Wert linear bis zu seinem Endwert (Tabelle oben). Neon-Blaster:
  nur der Energieanteil waechst. EP: 1 je Sieg, in dem sie getragen wurde,
  +1 je Abschuss ihres Traegers; Schwellen 3, 7, 12, 18, 25, 33, 42, 52,
  63, 75.
* **DROME 0-5:** zwei Hauptwerte +10 % je Level (Level 5 = +50 %), die
  anderen Werte +4 % (+20 %); Speed und Power nie. Hauptwerte (Vorschlag):
  Vireo Integritaet + Schild, Molok Integritaet + Ruestung, Nimbus Schild +
  Schildpuls, Strix Integritaet + Ruestung. Modulplaetze +1 auf Level 1, 3, 5
  (Molok 2, 4). EP: 1 je Sieg, Elite 2; Schwellen 2, 5, 9, 14, 20.
* EP gibt es nach jedem **Sieg im Lauf**, gutgeschrieben am Exemplar im
  Hangar; die Lauf-Kopie uebernimmt die Level sofort. Beute-Waffen, die
  erst im Lauf eingebaut werden, sammeln keine EP (sie sind noch kein
  Exemplar zuhause).

**Module statt Ausruestung:** Orbit-Fokus (`mod_orbit`) und
Hologramm-Boost (`mod_holo`) bringen ihre Faehigkeit als Modul mit
(`modules.json` -> `gadgets`); der Koedersender war schon Modul.

**Gemessen** (200 Spiegelkaempfe, Standard-Squad):

| DROME | Schaden/s | faellt in % der Kaempfe |
|---|---|---|
| Molok | 3,8 | 100 |
| Vireo | 4,7 | 88 |
| Nimbus | 11,4 | 82 |
| Strix | 10,7 | 51 |

Lesart: der Strix ist mit Power 16 und Anlegen jetzt die zweite
Schadensquelle und lebt am laengsten; der Molok faellt trotz 270
Integritaet immer -- die Praesenz zieht alles auf ihn. Der Vireo macht wenig
Schaden (Power 10, leichte Waffe). Naechster Schritt laut Spieler: die
Waffen.

## 7. EP, Gegner-Level, offene Fragen (9. Nov. 2026)

**EP** (Vorgabe des Spielers, Formeln von Claude):

* DROME: Level kosten 100, 200, 300, 400, 500 EP (Level 5 = 1500). Je Sieg
  bekommt jeder DROME des Squads 40 EP x Stufe (Leicht 0,75 / Normal 1 /
  Elite 1,5) x (1 + 10 % je Runde) -- auch wer gefallen ist. Ein Lauf mit
  sieben Siegen bringt rund 380 EP: Level 2 nach dem ersten Lauf, Level 5
  nach etwa vier.
* Waffe: 0,25 EP je Schadenspunkt (Schild und Integritaet) und 25 je
  Abschuss -- ein Abschuss zaehlt so viel wie rund zehn Treffer. In jedem
  Kampf, auch bei einer Niederlage. Level kosten 100, 150, 200, 250, 300
  (1-5), 500, 650, 800 (6-8), 1200, 1600 (9-10). Gemessen bringt eine Waffe
  45-85 EP je Kampf: Level 1 nach ~2 Kaempfen, Level 5 nach 2-3 Laeufen,
  Level 10 nach ~100 Kaempfen.
* Nur Waffen aus dem Hangar, die in einem Squad-DROME stecken. EP sammeln
  sich im Lauf (im Zwischenstopp mit dem kommenden Level zu sehen) und werden
  am Ende zuhause gutgeschrieben.

**Gegner-Level** (Leitplanke, `config.json` -> `run.enemy_levels`): DROME
0, 0, 1, 1, 1, 2, 2, 2 und Waffen 0, 0, 1, 1, 2, 2, 3, 3 ueber die acht
Runden; Leicht -1/-1, Elite +1/+2. Gemessen (Standard-Squad OHNE eigene
Module und Beute, 20 Laeufe, Siege):

| Runde | Stufe | Gegner Lv | frischer Squad (0/0) | erfahrener Squad (2/3) |
|---|---|---|---|---|
| 1 | Normal | 0/0 | 19 | 20 |
| 1 | Elite | 1/2 | 9 | 16 |
| 3 | Normal | 1/1 | 13 | 19 |
| 5 | Normal | 1/2 | 7 | 16 |
| 5 | Elite | 2/4 | 2 | 5 |
| 8 | Leicht | 1/2 | 16 | 19 |
| 8 | Normal | 2/3 | 1 | 7 |
| 8 | Elite | 3/5 | 0 | 3 |

Lesart: ohne eigene Module schafft ein frischer Squad spaet nur noch Leicht,
ein erfahrener auch Normal. Im echten Lauf kommen Module aus dem Laden und
Beute dazu -- die Stages modelliert der Spieler selbst.

**Gemessen: Backline, solange der Molok steht** (100 Spiegelkaempfe): der
Molok faellt nach 10 s; bis dahin bekommen Nimbus 3 % und Strix 4 % ihres
gesamten Schadens ab, der Vireo (vorn) 21 %. Die Praesenz zieht praktisch
alles auf den Molok.
