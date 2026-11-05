# Neuanfang: CyberDrome als Autobattler

Stand 5. November 2026. **Zur Besprechung.** Gebaut ist bisher nur die
KI-Grundlage aus Abschnitt 5 (Ziel halten, Verhalten je DROME, Fokus).
Hier steht, was der Spieler im Gespraech vorgegeben hat, was ich daraus
vorschlage und welche Fragen offen sind. Entschiedenes wandert danach in
`PROJEKTSTAND.md` und `CLAUDE.md`.

---

## 0. Was schon weg ist (Aufraeumen, PR "Taktik-Reste entfernt")

Das Feld ist ein **freies Gitter** mit Iso-Optik -- das Gitter bleibt, weil
Reichweite, Bewegung und Aufstellung darauf rechnen.

Geloescht: Gelaende (Stufen, Pfeiler, Oel/Drift, Nebel), Sichtlinie,
Antriebsflags (durch DROMEs laufen, Stufen, Drift, Blick durch Nebel),
Provokation, aktive Reparatur-Aktionen, Feldmarkierungen/Weg-/Schadens-
vorschau und Aktionssymbole des manuellen Kampfs, Zug-/Zyklus-/Kartenwerte
in der Konfiguration, veraltete Werkzeuge und Planungsdokumente. Davor (PR
#37) schon: Energie, Abklingzeiten, MOV, Strom, Traglast, Mutatoren.

Bewusst **noch drin**, weil sie zum neuen Entwurf gehoeren oder erst mit ihm
fallen sollten: Kopf und Antrieb als eigene Teile, die Halterklassen
(leicht/mittel/schwer), die heutigen Waffen und Gadgets, die Aggro-Tabelle,
der Chaos-Virus als zweiter Modus.

---

## 1. Spielprinzip: der Lauf

**Vorgabe des Spielers:** Wie in einem Roguelike bekommt man waehrend des
Laufs Verbesserungen, die am Ende wieder weg sind, aber das Bild deutlich
praegen. Gleichzeitig pokert man auf bestimmte Items, die man schon kennt,
und passt seinen Aufbau daran an.

**Vorschlag:**

* Zwei Ebenen, klar getrennt:
  * **Sammlung (bleibt):** DROMEs, Waffen, Kerne, die man kennt bzw.
    freigeschaltet hat. Daraus stellt man VOR dem Lauf den Squad zusammen.
  * **Lauf-Verbesserungen (verfallen):** nach jedem Sieg *1 aus 3*. Starke,
    sichtbare Effekte, die eine Richtung vorgeben ("alle Nahkaempfer +25 %
    Angriffstempo", "Faehigkeiten einen Angriff frueher", "Verwundbar haelt
    doppelt so lange").
* **Pokern** entsteht, wenn die Angebote nicht zufaellig aus allem kommen,
  sondern aus Toepfen, die man kennt: wer mit zwei Nahkaempfern startet,
  weiss, dass der Nahkampf-Topf ihn bedienen kann -- garantiert ist es nicht.
  Optional: einmal je Runde neu wuerfeln.
* Die heutige Lauf-Struktur (8 Kaempfe, 3 Leben, Leicht/Normal/Elite) kann
  bleiben; nur die Beute aendert sich von "Teil der Gegner" zu
  "Verbesserung".

## 2. Die DROMEs: Klasse, Passive, eigene KI

**Vorgabe:** Jeder DROME hat eine eigene Eigenschaft (Passive) und eine eigene
KI. Die Waffe entscheidet, WIE er sie ausspielt.

| DROME | Rolle | Passive (Vorgabe/Vorschlag) | KI |
|---|---|---|---|
| **Vireo** | wendig, Assassine oder Kiter | **Trifft er, laeuft er 2 s schneller** (Vorgabe; Hoehe offen, Vorschlag +40 %) | schnittig: mit Fernwaffe Abstand halten und kiten, mit Klinge am Ziel kleben |
| **Molok** | Tank, Frontlinie | **Praesenz: zieht Aggro und faengt Schaden fuer Verbuendete ab** (Vorgabe). Vorschlag: Gegner in 2 Feldern Umkreis bekommen Aggro auf ihn gebucht, und 30 % des Schadens an Verbuendeten neben ihm gehen auf ihn | geht IN den Schadensbereich, stellt sich zwischen Gegner und die eigene Hinterreihe, weicht nie aus |
| **Strix** | Scharfschuetze | **+30 % Schaden auf maximaler Reichweite** (Vorgabe, "koennte ich mir vorstellen") | sucht das Feld auf genau maximaler Reichweite und bleibt dort; weicht nur aus, wenn jemand direkt danebensteht |
| **Nimbus** | Magier, Kontrolle | offen -- Vorschlag: seine Kontrolleffekte (Sog, Betaeubung, Verlangsamung) halten 50 % laenger | mittlerer Abstand, hinter dem Molok; nicht vorpreschen wie ein Assassine |

**Ausruestung:** jeder DROME **1 Ausruestungsplatz, der Molok 2** (Vorgabe:
"erstmal"). Folge: die Halterklassen (leicht/mittel/schwer) verlieren ihren
Zweck -- Vorschlag unten in Frage 5.

## 3. Waffen

**Vorgabe:**

* **Puls-Blaster** (Fernkampf): teils Energieschaden. Faehigkeit **jeder 3.
  Schuss: schneller Schuss auf bis zu 2 Gegner in Reichweite; ist nur einer
  da, zweimal hintereinander auf ihn.** (Ersetzt die heutige Streusalve.)
* **Plasmaklinge** (neu, Nahkampf): dem Blaster aehnlich, aber nur
  kinetischer Schaden, etwas mehr davon und hoeheres Angriffstempo.
  Faehigkeit: **verstaerkter Angriff, Ziel ist 5 s "verwundbar" und nimmt
  50 % mehr Schaden.**
* **Hammer** (neu, Nahkampf fuer den Molok; muss keine Belagerungskanone
  sein): **jeder 3. Angriff betaeubt kurz** (Vorschlag 1 s).

Vorschlag fuer die Zahlen (zum Anpassen):

| Waffe | Rw | Staerke | Intervall | Art | Faehigkeit |
|---|---|---|---|---|---|
| Puls-Blaster | 3 | 10 | 1,4 s | 50 % Energie | jeder 3.: Doppelschuss 2 x 7 |
| Plasmaklinge | 1 | 12 | 1,0 s | kinetisch | jeder 3.: 18 + verwundbar 5 s |
| Hammer | 1 | 16 | 1,8 s | kinetisch | jeder 3.: 16 + betaeubt 1 s |

Offen: was aus Belagerungskanone, Schienen-Lanze, Runenstab, Deflektor,
Hologramm-Boost, Orbit-Fokus, Drohnen-Pod und Koedersender wird (Frage 3).
Der Hologramm-Boost (Sprung weg, wenn ein Gegner danebensteht) ueberschneidet
sich mit der neuen Vireo-Passive.

## 4. Kerne als Synergie-Teil

**Vorgabe (Beispiel):** Ein Kern, der jeden 5. Nahkampfangriff doppelt
treffen laesst -- auf einem Vireo mit Plasmaklinge extrem viel Schaden.

**Vorschlag:** Der Kern verliert die Schildwerte als Hauptaufgabe und wird
das Synergie-Teil. Ein paar Startkerne, je einer Bauart zugeordnet:

* **Klingenkern** -- jeder 5. Nahkampfangriff trifft doppelt.
* **Zielrechner** -- Faehigkeiten kommen einen Angriff frueher.
* **Bollwerkkern** -- +X % Schild, Praesenz reicht ein Feld weiter.
* **Fluxkern** -- Kontrolleffekte halten 1 s laenger.

Damit liegt die Skill-Tiefe im *Womit* (Designpunkt 2): DROME x Waffe x Kern
x Lauf-Verbesserungen.

## 5. KI: Befund und Vorschlag

Gemessen (30 Spiegelkaempfe mit dem Standard-Squad, nach dem Aufraeumen):
**jeder DROME wechselt im Schnitt 11-mal pro Minute sein Ziel**, also etwa
alle 5 Sekunden.

| Beobachtung des Spielers | Ursache im Code |
|---|---|
| "Wenn man ein Ziel hat, sollte man es erstmal angreifen" | Das Ziel wird alle 0,5 s neu bewertet. Der Bonus fuers aktuelle Ziel (3 bzw. 5 Punkte) ist klein gegen die Schadenspunkte (10-26), jede kleine Aenderung kippt die Wahl. |
| Es entstehen keine Teamkaempfe, eher Zweikaempfe | Die Zielwahl zieht je Feld Abstand 2 Punkte ab -- jeder nimmt "seinen" naechsten Gegner, und durch das Wechseln zerfasert es weiter. Es gibt keine Abstimmung im Team. |
| Molok laeuft vor dem Nimbus weg | Die Rolle wird aus der **Waffenreichweite** abgeleitet: ab Reichweite 3 gilt man als Fernkaempfer und weicht aus, wenn jemand naeher als 2 Felder kommt. Der Molok mit Belagerungskanone (Rw 6) gilt deshalb als Fernkaempfer. |
| Molok neben Strix mit Deflektor faengt nichts ab | Der Deflektor gibt nur DEF auf den Molok selbst. Abfangen gibt es als Mechanik nicht. |
| Nimbus verhaelt sich wie ein Assassine | Runenstab = Reichweite 1 = Nahkaempfer -> rueckt bis zum Kontakt vor. |

**Gebaut (5. Nov. 2026)** -- Punkte 1 bis 3. Messung ueber 200 Spiegelkaempfe
mit dem Standard-Squad, vorher -> nachher: Zielwechsel je DROME und Minute
11,3 -> 5,5; Molok-Schritte weg vom Gegner 21 % -> 4 %; Kampfdauer 41 -> 32 s.
**Noch offen:** der Nimbus faellt weiter in rund 80 % der Kaempfe zuerst --
mit dem Runenstab (Rw 1) bleibt er Nahkaempfer mit wenig Integritaet. Das ist
eine Designfrage (Nimbus-Waffe, Frage 3/6), keine KI-Frage.

1. **Ziel halten:** Ein gewaehltes Ziel bleibt, bis es faellt, laenger als
   ca. 2 s nicht erreichbar ist oder ein sicherer Abschuss in Reichweite
   steht. Kein Neubewerten im Halbsekundentakt.
2. **KI je DROME statt je Waffenreichweite:** Das Verhalten (vorruecken,
   halten, kiten, abschirmen) haengt am Chassis; die Waffe gibt nur die
   Reichweite vor. So rennt ein Molok nie weg, egal was er traegt.
3. **Teamkampf:** Ziele, die ein Verbuendeter schon angreift, bekommen einen
   Bonus (Fokus). Dazu eine lose Formation: Molok vorn, Nimbus und Strix
   dahinter, Vireo flankiert.
4. **Aggro-Tabelle:** bleibt als Grundlage, aber mit der Molok-Praesenz als
   wichtigster Quelle. Spaeter der Hebel fuer "Aggro-Platz 1" (Designpunkt 3).

## 6. Offene Fragen an den Spieler

1. **Was bleibt zwischen Laeufen?** Nur freigeschaltete DROMEs/Waffen/Kerne,
   oder auch Erfahrung/Stufen? Gibt es Geld oder einen Laden im Lauf?
2. **Kopf und Antrieb:** weiter als tauschbare Teile, oder fest am Chassis
   (die Huelle ist der DROME)? Vorschlag: fest -- dann gibt es je DROME nur
   noch Kern + Ausruestung zu waehlen, und das liest sich auf dem Handy viel
   klarer.
3. **Die uebrigen Teile** (Belagerungskanone, Schienen-Lanze, Runenstab,
   Deflektor, Hologramm-Boost, Orbit-Fokus, Drohnen-Pod, Koedersender): Welche
   behalten, umbauen oder streichen? Vorschlag: Strix behaelt die Lanze,
   Nimbus behaelt Runenstab und Orbit-Fokus als Kontrollwaffen, die Kanone
   und der Koedersender fallen weg (der Molok bekommt den Hammer und die
   Praesenz), Deflektor und Drohnen-Pod werden Molok-Zweitteile.
4. **Darf jeder DROME jede Waffe tragen?** Oder gibt es je DROME eine
   Auswahl (Vireo: Blaster oder Klinge)? Vorschlag: je DROME 2-3 passende
   Waffen, damit Passive und Waffe immer zusammenpassen.
5. **Halterklassen leicht/mittel/schwer:** Bei einem Platz pro DROME
   ueberfluessig. Vorschlag: streichen, stattdessen "passt zu Vireo/Molok/...".
6. **Nimbus-Passive:** Vorschlag "Kontrolle haelt 50 % laenger" -- oder hast
   du etwas anderes im Kopf?
7. **Chaos-Virus** als zweiter Modus: behalten, oder alles auf den Lauf?
8. **Zahlen:** Vireo-Tempo +40 % fuer 2 s, Strix +30 % auf maximaler
   Reichweite, Verwundbar +50 % fuer 5 s, Betaeubung 1 s -- passt das als
   Startpunkt?

## 7. Ausruestung, Module und Lager im Lauf (Vorschlag, Stand 5. Nov.)

**Vorgabe des Spielers:** kein fester Gegenstand je DROME, sondern modular mit
Grenzen (ein Vireo traegt keinen Deflektor). Varianten wie der **Neon-Blaster**.
Die erste Region **Neon City** hat das Thema Energie/Schild -- Gegner mit viel
Schild und wenig Integritaet, **Neon-Varianten** der DROMEs. Ein Inventar je
Lauf, eine Bank wie bei TFT, Rezepte zum Zusammenfuegen, eine Grenze je DROME.

### 7a. Zwei Arten von Gegenstaenden

| | **Ausruestung** | **Module** |
|---|---|---|
| Was | Waffen, Schilde, Gadgets -- bestimmt, WAS der DROME tut | kleine Chips -- veraendern, WIE gut er es tut |
| Plaetze | **1 je DROME, Molok 2** (wie besprochen) | **3 je DROME** |
| Grenze | passt nur an bestimmte Chassis (Klasse + Art) | passt an jeden DROME |
| Quelle | Startausstattung, Beute, Laden | nur im Lauf: Beute, Laden, Rezepte |
| Nach dem Lauf | bleibt (Sammlung), Varianten werden freigeschaltet | verfaellt |

Drei Module je DROME: genug fuer eine Richtung, zu wenig fuer alles -- bei
vier DROMEs hoechstens zwoelf Module im Feld. Das ist die taktische Grenze.

### 7b. Wer was tragen darf

Die vorhandene Regel bleibt (Klasse leicht/mittel/schwer + Art Waffe/Schild/
Gadget je Halter), nur auf die neuen Plaetze umgelegt:

| DROME | darf tragen |
|---|---|
| Vireo | leichte und mittlere Waffen, Gadgets -- **keine Schilde** |
| Molok | alles, auch schwere Nahkampfwaffen; zweiter Platz Schild oder Gadget |
| Strix | Fernwaffen jeder Klasse, Gadgets |
| Nimbus | leichte und mittlere Waffen, Gadgets |

So kann ein Vireo Blaster, Neon-Blaster oder Plasmaklinge tragen, ein Nimbus
ebenfalls den Blaster -- aber niemand traegt alles.

### 7c. Varianten und Regionsthemen

Jede Grundwaffe bekommt je Region eine Variante mit **anderer Faehigkeit**,
gleiche Grundform:

* **Puls-Blaster** -- jeder 3. Schuss: Doppelschuss auf bis zu 2 Ziele.
* **Neon-Blaster** (Neon City) -- jeder 3. Schuss laedt den naechsten auf:
  doppelter Schaden **am Schild**.

Regionsthemen (Vorschlag, die ersten beiden Regionen nur skizziert):

* **Neon City -- Energie:** Gegner mit viel Schild, hoher Schildregeneration,
  wenig Integritaet. Neon-DROMEs **bezahlen ihre Faehigkeiten mit Schild** --
  wer ihren Schild bricht, nimmt ihnen die Faehigkeiten. Konter: Energieschaden,
  Neon-Blaster, Schild-Module.
* **Gruenzone -- Wucherung:** Regeneration und Ueberzahl (viele kleine Gegner).
  Konter: Flaeche, Verwundbar.
* **Anlage 7 -- Panzerung:** hohe DEF, langsam, schwer. Konter: kinetischer
  Schaden, Durchschlag.

**Markenzeichen Neon: es leuchtet** (Vorgabe des Spielers). Neon-Gegner,
-Waffen und -Ausruestung erkennt man daran, dass ihre Akzente wie
Neonroehren gluehen -- ein Neon-Vireo ist ein Vireo mit leuchtenden Roehren.
Vorschlag zur Umsetzung:

* **Gleiche Form, andere Palette:** die Teile haben schon eigene Farbrollen
  fuer Neon-Streifen (`--c-accent`) und Leuchten (`--c-glow`). Eine
  Neon-Variante bekommt dort grelle, gesaettigte Farben (Pink, Cyan,
  Violett); die Panzerung wird dunkler, damit die Roehren sich abheben.
* **Echtes Leuchten im Spiel:** die Akzent-Flaechen werden beim Backen
  zusaetzlich als eigene Ebene herausgeschrieben und im Kampf weich
  verwischt und additiv ueber die Figur gelegt (Lichthof), mit leichtem
  Pulsieren und gelegentlichem Flackern wie bei einer Roehre. Ob das mit dem
  GL-Compatibility-Renderer im Browser fluessig laeuft, muss ein kleiner
  Prototyp zeigen; Rueckfall waere ein vorgerechneter Lichthof je Teil.
* Gilt fuer alles Neon: DROMEs, Waffen, Ausruestung, auch Schussspuren und
  Schildring der Neon-Gegner. "Animationen reduzieren" schaltet Pulsieren
  und Flackern ab, das Leuchten bleibt.

Varianten werden **freigeschaltet**, indem man die Region schlaegt -- dann
kommen sie in den Beutetopf. Das ist das "pokern auf Items, die man kennt".

### 7d. Das Lager (die "Bank")

* Je Lauf ein **Lager mit 8 Plaetzen** fuer Ausruestung und Module, die gerade
  niemand traegt. Ist es voll, muss man verkaufen oder verschrotten.
* **Ausruesten zwischen den Kaempfen:** Teil im Lager antippen, dann den
  DROME antippen (Ziehen kommt spaeter dazu). Unpassende DROMEs sind
  ausgegraut, mit Grund ("Vireo traegt keine Schilde").
* **Umbauen ist zwischen den Kaempfen frei.** Der Druck kommt aus den drei
  Plaetzen, dem kleinen Lager und dem Zusammenfuegen -- nicht aus einer Strafe
  fuers Umstecken. Auf dem Handy waere eine Strafe vor allem Frust.
* Eine **DROME-Bank wie bei TFT** (DROMEs im Lauf kaufen und tauschen) waere
  der naechste Schritt, aber nicht der erste: erst muessen die Gegenstaende
  tragen.

### 7e. Rezepte (Zusammenfuegen)

* **Fuenf Bauteile** als Grundmodule, jedes fuer sich ein kleiner Wert:
  **Energiezelle** (+Energieschaden), **Panzerplatte** (+DEF),
  **Servomotor** (+Tempo), **Zielchip** (Faehigkeit frueher),
  **Kondensator** (+Schild).
* **Zwei Bauteile ergeben ein fertiges Modul** -- 5 Bauteile, 15 Rezepte
  (auch zwei gleiche). Das fertige Modul ist deutlich staerker als die Summe
  und hat einen Effekt statt nur Werte. Beispiele:
  * Energiezelle + Energiezelle = **Ueberladung** -- Energietreffer springen
    auf ein zweites Ziel ueber.
  * Energiezelle + Kondensator = **Schildbrecher** -- +50 % Schaden an Schilden.
  * Servomotor + Panzerplatte = **Rammbock** -- nach jedem Schritt auf einen
    Gegner zu: naechster Nahkampftreffer +40 %.
  * Zielchip + Servomotor = **Jagdinstinkt** -- Abschuss setzt die Faehigkeit
    sofort auf bereit.
  * Kondensator + Panzerplatte = **Bollwerk** -- 20 % des Schadens an
    Verbuendeten daneben gehen auf den Schild des Traegers.
* Zusammengefuegt wird **im Lager**, mit sichtbarem Rezeptbuch -- nicht
  automatisch am DROME. So sieht man vorher, was entsteht, und kann darauf
  hinsammeln.
* Fertige Module koennen auch direkt als Beute kommen, seltener.

### 7f. Entschieden (5. Nov. 2026)

1. **Drei Module je DROME.** Spaeter vielleicht ein Stufenaufstieg, durch den
   ein DROME vier oder mehr tragen kann.
2. **Laden und Waehrung: ja.** Die Waehrung heisst **Credits**. Beute bleibt
   gleich oder aehnlich wichtig wie der Laden.
3. **Ausruestung bleibt** und geht nach dem Lauf mit ins Lager/den Hangar;
   nur die Module verfallen.

## 8. Vorgeschlagene Reihenfolge

1. KI-Grundlagen: Ziel halten, Rolle je DROME (behebt Molok/Nimbus sofort).
2. Ein Ausruestungsplatz (Molok zwei), Kopf/Antrieb nach Entscheidung.
3. Vireo komplett: Passive, Blaster-Faehigkeit neu, Plasmaklinge, Status
   "verwundbar" (Statuseffekte laufen schon in Sekunden).
4. Molok: Praesenz, Hammer, Betaeubung, abschirmende KI.
5. Strix und Nimbus.
6. Kerne als Synergie-Teile.
7. Module, Lager und Rezepte (Abschnitt 7), dann Laden und Waehrung.
8. Neon City als erste Region mit Neon-Gegnern und Neon-Varianten.
