# Identitaeten der DROMEs und Waffen

> **Stand 26. Nov. 2026: Chronik.** Entscheidungen vom 8./9. Nov. 2026 zum Werte-Satz und zu
> den Identitaeten. Gestrichen: die Bestandsaufnahme davor (alter Werte-Satz mit ATK, Waffen,
> die es nicht mehr gibt) und die EP (seit 24. Nov. 2026 werden Level mit Fabrik-Waren gekauft,
> `SKILLBAUM_KONZEPT.md` 5d). Aktuelle Werte stehen im Werkblatt
> `docs/spot/CyberDrome_Werkblatt_DROMEs_Waffen.xlsx`, die Passiven im Kernplan. Ueberholt: Sprint
> (seit 25. Nov. Cyberspeed), Praesenz (entfernt 26. Nov.), Orbit-Fokus und Koedersender
> (seit den Amps weg).

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
| Schildpuls | 7 | 3 | 10 | 5 |
| Ruestung | 2 | 10 | 0 | 2 |
| Halter | 1 leicht | 2 bis mittel | 1 bis mittel | 1 bis schwer |
| Power | 10 | 6 | 12 | 15 |
| Modulplaetze je Halter | 3 | 2 | 3 | 3 |
| Passive | ~~Sprint~~ Cyberspeed | ~~Praesenz~~ (keine, neu im Kernplan) | Echo | Anlegen (4 s still: +20 % Schaden/Reichweite) |

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
  Hangar; die Lauf-Kopie uebernimmt die Level sofort. Beute-Waffen sammeln
  keine EP (sie sind noch kein Exemplar zuhause). **Seit 9. Nov. 2026
  (`MODULE_AMP_FUSION.md` 6): Waffen sind im Lauf fest** -- Beute-Teile gehen in
  die Tasche und erst nach dem Lauf in den Hangar, im Lauf baut man sie
  nicht mehr ein.

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
Integritaet immer -- die (inzwischen entfernte) Praesenz zog alles auf ihn. Der Vireo macht wenig
Schaden (Power 10, leichte Waffe). Naechster Schritt laut Spieler: die
Waffen.

## 8. Schildpuls und Unterstuetzung (9. Nov. 2026, entschieden)

* **Schildpuls** je DROME: Vireo 7 (laedt zwischen Gefechten schnell
  nach), Strix 5, Molok 3, Nimbus 10.
* **Heilung und Schildgabe** = Grundwert x Power des Anwenders / 10 + 3 %
  der maximalen Integritaet des Ziels (`ActionResolver.support_amount`,
  `combat.support.target_share`).
* **Ueberschild** (Schildgaben ueber das Maximum) gedeckelt bei Maximum +
  50 % (`combat.support.overshield`).
* **Ueberheilung** wird zu Schild, aber nur bis zum normalen Maximum -- kein
  Ueberschild aus Heilung. Sind Integritaet und Schild voll, geht die
  Heilung ins Leere.
