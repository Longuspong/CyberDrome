# Neuanfang: CyberDrome als Autobattler

Stand 6. November 2026. **Zur Besprechung.** Gebaut sind bisher: die
KI-Grundlage (Abschnitt 5), der Nimbus (6a), ein Ausruestungsplatz je DROME
mit Molok zwei (6c), der Vireo mit Passive, Doppelschuss, Plasmaklinge und
Neon-Blaster (6c), der Leucht-Prototyp fuer Neon (7c), der Molok (6d) und
die Aufstellung vor dem Kampf (6e) und die Zielregel je Rolle (6f).
Entschieden, aber noch nicht gebaut: Begriffe, Module, Level, Karte (6g).
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
| **Vireo** | wendig, Assassine oder Kiter | **Sprint** (Vorgabe, gebaut): jeder Treffer gibt 2 s lang +40 % Lauftempo (`data/config.json` -> `passives`) | schnittig: mit Fernwaffe Abstand halten und kiten, mit Klinge am Ziel kleben |
| **Molok** | Tank, Frontlinie | **Praesenz: zieht Aggro und faengt Schaden fuer Verbuendete ab** (Vorgabe). Vorschlag: Gegner in 2 Feldern Umkreis bekommen Aggro auf ihn gebucht, und 30 % des Schadens an Verbuendeten neben ihm gehen auf ihn | geht IN den Schadensbereich, stellt sich zwischen Gegner und die eigene Hinterreihe, weicht nie aus |
| **Strix** | Scharfschuetze | **+30 % Schaden auf maximaler Reichweite** (Vorgabe, "koennte ich mir vorstellen") | sucht das Feld auf genau maximaler Reichweite und bleibt dort; weicht nur aus, wenn jemand direkt danebensteht |
| **Nimbus** | Magier, Kontrolle | **Echo** (gebaut 7. Nov., ersetzt den Zauberwirker): Takt 50 % laenger, jede Faehigkeit wirkt zweimal (6g) | wartet hinter der Frontlinie, dann auf Blaster-Reichweite |

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
2. ~~Kopf und Antrieb~~ -- **entschieden:** fest am Chassis. Ein DROME ist
   ein ganzes, immer gesamt gestaltetes Modell, nichts davon austauschbar.
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
6. ~~Nimbus-Passive~~ -- **entschieden und gebaut:** Zauberwirker (siehe
   Tabelle in Abschnitt 2).
7. **Chaos-Virus** als zweiter Modus: behalten, oder alles auf den Lauf?
8. **Zahlen:** Vireo-Tempo +40 % fuer 2 s, Strix +30 % auf maximaler
   Reichweite, Verwundbar +50 % fuer 5 s, Betaeubung 1 s -- passt das als
   Startpunkt?

## 6a. Runenstab und Vortex (entschieden und gebaut, 6. Nov. 2026)

* **Runenschlag:** Einzelziel, Reichweite 3 wie der Blaster (vorher Nahkampf
  mit Kreuzflaeche -- "sonst sehr unausgeglichen"), reine Energie, 1,2 s.
* **Vortex** (jeder 5. Angriff, also nach vier normalen): angezielt auf einen
  Gegner, zieht die Gegner im Umkreis 2 zu ihm heran (Sog von aussen nach
  innen), 0,6 s spaeter eine Schockwelle von innen nach aussen (14 Energie im
  Umkreis 2), danach 2,5 s um 40 % verlangsamt.
* Statuseffekte laufen in Sekunden; Verlangsamung wirkt als Faktor auf das
  Lauftempo. Verzoegerte Wirkungen: `ActionResolver.delayed`/`advance()`.
* Gemessen (200 Spiegelkaempfe, Standard-Squad): der Nimbus faellt in 58 %
  statt 80 % der Kaempfe zuerst. Auffaellig: der Strix richtet mit Abstand
  den meisten Integritaetsschaden an (187 je Kampf gegen 48-72 bei den
  anderen).
* Folge: es gibt bis zu Plasmaklinge und Hammer **keine Nahkampfwaffe** mehr;
  der Hologramm-Boost (loest aus, wenn ein Gegner danebensteht) kommt im
  Kampf deshalb gerade nicht vor.

## 6c. Ein Platz je DROME und der Vireo (gebaut, 6. Nov. 2026)

* **Halter:** Vireo und Nimbus links bis mittel (Waffe oder Gadget, kein
  Schild), Strix zentral schwer (Waffe oder Gadget), Molok links alles bis
  schwer, rechts Schild oder Gadget. Die uebrigen Anker sind reine Optik
  (`slot_rules` -> `off`); die Molok-Schulter entfaellt. Startbestand:
  Vireo Blaster, Molok Kanone + Deflektor, Nimbus Runenstab, Strix Lanze;
  die Gadgets liegen frei im Inventar.
* **Puls-Blaster:** jeder 3. Schuss ist der **Doppelschuss** (2 x 7, auf bis
  zu zwei Gegner, sonst zweimal aufs Ziel).
* **Plasmaklinge** (EQP-010): Nahkampf, kinetisch, 12 alle 1,0 s; jeder 3.
  Hieb (Aufschlitzen, 18) macht 5 s **verwundbar** (+50 % Schaden).
* **Neon-Blaster** (EQP-011): Form des Blasters, Neon-Farben, leuchtet; jeder
  3. Schuss ist der **Schildbrecher** (12 Energie, doppelter Schaden am
  Schild).
* **Gemessen** (je 200 Spiegelkaempfe, Standard-Squad):
  * Spiegel 101:99, Kampfdauer 27 s.
  * Zuerst faellt der Nimbus in 58 %, der Vireo in 38 %.
  * Integritaetsschaden je Kampf: Strix 169, Nimbus 63, Molok 51, Vireo 39
    -- der Strix dominiert weiter.
  * Vireo-Waffen gegeneinander: Klinge gegen Blaster 92:108, Neon-Blaster
    gegen Blaster 117:83 (heute traegt jeder DROME Schild -- ausserhalb von
    Neon City ist er dadurch zu stark), Klinge gegen Neon 80:120.
* Seit es eine Nahkampfwaffe gibt, kommt der Hologramm-Boost wieder vor --
  aber der Startbestand traegt keine Klinge.

## 6d. Molok (gebaut, 6. Nov. 2026)

* **Tank:** 200 Integritaet, 10 Schild (Tanks: viel Integritaet, kaum Schild).
* **Praesenz:** je Puls buchen Gegner im Umkreis 2 Aggro auf ihn; 30 % des
  Schadens an Verbuendeten im Umkreis 3 gehen auf ihn
  (`data/config.json` -> `passives.presence`).
* **Hammer** (EQP-012, neues Modell): schwer, Nahkampf, kinetisch, 16 alle
  1,8 s; jeder 3. Schlag betaeubt 1 s. Startbestand: Hammer + Deflektor,
  die Kanone liegt frei.
* **Gemessen** (200 Spiegelkaempfe): der Molok faellt jetzt in 93 % zuerst und
  nimmt ~209 Schaden je Kampf -- er tankt. Der Nimbus faellt kaum noch zuerst.
  **Aber:** Hammer-Molok gegen Kanonen-Molok 38:162 -- mit Hammer laeuft er
  allein nach vorn und richtet wenig an (43 je Kampf).
* **Entscheidung (6. Nov.):** der Hammer bleibt wie er ist -- jeder 3. Schlag
  betaeubt 1 s. Nachgemessen (je 200 Kaempfe, Hammer gegen Kanone, mit
  Aufstellung): heute 31:169; Molok wartet auf sein Team 24:176; Hammer 22
  statt 16 Schaden 53:147; beides 44:156. Das Warten hilft nicht, und mehr
  Schaden nur wenig. Die eigentliche Ursache ist die Kanone (Reichweite 6,
  Flaeche -- erst recht nach dem Vortex). Sie ist eher zu stark als der
  Hammer zu schwach; Thema fuers Balancing nach dem Strix.

## 6e. Aufstellung vor dem Kampf (gebaut, 6. Nov. 2026)

* Vorgabe des Spielers: vor dem Kampf zieht der Spieler seine DROMEs per
  Ziehen und Ablegen in einer Zone von 3 x 5 Feldern unten links; erst nach
  dem Bestaetigen beginnt der Kampf.
* Gebaut: Zone 3 x 5 (`deployment.rows/columns`), Gegner gespiegelt. Ohne
  Zutun stellt die Aufstellung nach Rolle auf (Molok vorn, Strix hinten),
  beim Gegner ebenso. Ziehen auf einen eigenen DROME tauscht beide, Ziehen
  daneben schiebt die Kamera. Die bestaetigte Aufstellung wird fuer den
  naechsten Kampf gemerkt.
* Die Zonen sitzen weiter 5 Felder von den Ecken eingerueckt
  (`deployment.inset`) -- direkt in der Ecke dauert der Anlauf rund doppelt
  so lange.
* **Entschieden (6. Nov.): Zwischenstopp nach dem Kampf** fuer Beute, Laden,
  Lager und Rezepte; die Aufstellung bekommt einen Knopf "Umruesten".
* Begruendung der Empfehlung zur Frage "Ausruesten vor dem Kampf oder im
  Beute-/Laden-Menue": Ausruesten, Kaufen und Rezepte gehoeren in einen eigenen
  Zwischenstopp nach dem Kampf (Beute, Laden, Lager). Die Aufstellung bleibt
  schlank: Feld, Gegnervorschau, ein Knopf "Umruesten", der ins Lager und
  zurueck fuehrt. Grund: auf dem Handy braucht das Feld den ganzen Platz, und
  "womit" und "wo" sind zwei Entscheidungen -- aber weil die Aufstellung vom
  Aufbau abhaengt, darf der Weg zurueck nur einen Tipp kosten.

## 6f. Zielregel je Rolle statt Aggro-Tabelle (gebaut, 6. Nov. 2026)

* Entscheidung: die versteckte Aggro-Tabelle ist raus. Im Autobattler muss
  man beim Zuschauen verstehen, warum wer auf wen schiesst.
* Zielregel (`AIController.choose_target`):

  | Rolle | greift an |
  |---|---|
  | vanguard (Molok), skirmisher (Vireo) | den naechsten Gegner |
  | controller (Nimbus) | den, um den die meisten Gegner stehen |
  | sniper (Strix) | in Reichweite den, der am meisten Schaden macht |
  | hunter (geplante Jaegerklasse) | den verwundbarsten: wenig Integritaet, verwundbar oder betaeubt |

  Gleichstand: wen Verbuendete schon angreifen, dann wer weniger aushaelt.
* **Locken** vor allem anderen: wer im Lockradius eines Gegners steht
  (Molok-Praesenz 2 Felder, Koedersender 2 Felder), greift ihn an -- sichtbar
  als oranges Ausrufezeichen am Balken. Der Koedersender lockt jetzt statt
  einen Aggro-Bonus zu geben.
* Entfernt: AggroTable, Aggro-Buchung und -Verfall, `aggro_coeff`/
  `aggro_flat` (leise/laute Waffen), `aggro_bonus`, Konfigurationsteil
  `aggro`, die Aggro-Gewichte der KI.
* Gemessen (200 Spiegelkaempfe): Zielwechsel 6,2 -> 2,5 je DROME und Minute;
  sonst kaum Unterschied (Molok faellt zuerst, nimmt ~205). Auffaellig im
  Bild: der Molok zieht jetzt alle auf sich und ist nach 5 s fast leer --
  Balancing-Thema (Schutz-Anteil, Integritaet).
* Strix bleibt wie er ist (Entscheidung 6. Nov.); Ausgleich spaeter ueber eine
  **Jaegerklasse**, die verwundbare Ziele jagt (Zielregel "hunter" steht
  schon bereit).

## 6g. Begriffe, Module, Level, Karte (entschieden 6. Nov. 2026, teils gebaut)

Ersetzt in Teilen Abschnitt 1 (Lauf-Verbesserungen), 4 (Kerne) und 7a/7e
(Module, Rezepte).

**Begriffe**

* Alles, was in einen Halter passt, heisst **Waffe** (auch Deflektor und
  Drohnen-Pod) -- ein DROME ohne Angriff ist sinnlos. Jede Waffe hat einen
  **Angriff** (ohne eigenen Namen, heisst einfach "Angriff") und eine
  **Faehigkeit** (mit Namen, z. B. Doppelschuss, Vortex).
* Welche Waffe passt, regelt allein der **Halter** (leicht/mittel/schwer,
  leicht passt nach oben). Keine Liste "wer darf was" -- ein Strix darf einen
  Blaster tragen, auch wenn es wenig Sinn ergibt.
* **Module** gibt es nur im Lauf; sie veraendern, wie eine Waffe
  funktioniert. Drei Klassen: **Angriff** (Modifikatoren), **Abwehr/Konter**,
  **Taktik** (Spezialeffekte, Dauer von Faehigkeiten und Effekten). Module
  koennen Bedingungen haben (z. B. nur an Fernwaffen).

**Waffen, die bleiben:** Blaster, Neon-Blaster, Plasmaklinge, Hammer, Lanze,
Runenstab, Deflektor, Drohnen-Pod (als Heilwaffe, Vorschlag unten).
**Faellt weg:** Belagerungskanone. **Werden Module:** Koedersender (Taktik:
loest die Faehigkeit des Traegers aus, muss ihr Ziel 3 s lang den Traeger
angreifen), Hologramm-Boost und Orbit-Fokus (Vorschlag).

**Kerne entfallen als Gegenstand.** Die Kern-Idee (Synergie) lebt in den
**Varianten** weiter: man waehlt, welcher Blaster zum DROME passt (Puls oder
Neon). Nicht jede Waffe hat jede Variante; Neon-Gegner tragen gemischte
Ausruestung. Die Kernwerte (Schildnachfuellung 5-10 je Puls, Schild +5-20 %,
Strix ATK +2) fallen ersatzlos weg; der Kern-Halter (Kreis) ebenso.

**Schild:** keine Grundregeneration mehr. Der Schild laedt erst wieder, wenn
der DROME eine Weile keinen Schaden genommen hat (Vorschlag: 4 s, dann 10 %
des Maximums je Sekunde, Wert in `config.json`).

**Module ohne Stufen.** Feste Werte; staerker werden sie nur durch
**Rezepte**: mehrere Module ergeben einen neuen Gegenstand mit den
**aufaddierten Werten plus einem eigenen Effekt**. Die Zutaten sind danach
weg, das Ergebnis belegt einen Platz. Zusammengefuegt wird im Lager (Ziehen
oder Verbindungsmodus). Beispiel (Werte vorlaeufig):

| Modul | Klasse | Bedingung | Wert |
|---|---|---|---|
| Schnellfeuer | Angriff | Fernwaffe | +8 % Angriffstempo |
| Langer Lauf | Angriff | Fernwaffe | +1 Reichweite |
| Doppellauf | Angriff | Fernwaffe | 20 % Chance: Querschlaeger aufs selbe Ziel, 15 % Schaden |
| **Gunslinger** = alle drei | Angriff | Fernwaffe | Summe + jeder 5. Angriff trifft zusaetzlich einen Gegner irgendwo auf dem Feld |

**Angriff oder Faehigkeit:** jede Faehigkeit traegt eine Markierung "zaehlt
als Angriff" (ja beim Doppelschuss -- ein kuenstlicher Autoangriff; nein bei
Vortex, Schutzdrohne). Zaehler und Modifikatoren wie Schnellfeuer und
Gunslinger wirken nur auf Angriffe.

**Modulplaetze:** 3 je Waffe, Molok 2 je Waffe (sonst ist ein Squad aus vier
Moloks nicht auszubalancieren). Auf DROME-Level 1, 3 und 5 je ein Platz
mehr -- am Ende 6. Der Molok startet mit 2 je Waffe und bekommt auf Level 2
und 4 je Waffe einen dazu -- am Ende 4 je Waffe.

**Level bleiben nach dem Lauf.** DROMEs bekommen EP je Sieg, Level 0-5.
Waffen bekommen EP fuer Siege, in denen sie getragen wurden (Abschuesse
etwas dazu), Level 0-10. Jede Waffe ist ein eigenes Stueck mit eigenem
Level. Spaeter: kleiner Skillbaum fuer DROMEs und Waffen, ein Punkt je
Levelaufstieg (TODO, nach Zwischenstopp und Modulen).

**Gegnerstaerke** haengt an Region und Runde, **nicht** an der Staerke des
eigenen Squads (heute `RunState.enemy_power` aus `base_power`). So bringt ein
neuer Lauf mit gelevelten DROMEs weiter und an mehr Beute.

**Nur Module als Verstaerkung** im normalen Lauf -- keine "1 aus 3"-Buffs fuer
den Squad (Abschnitt 1 ist damit ueberholt).

**Karte wie bei FTL:** der Lauf zeigt eine Karte mit Symbolen fuer die
naechsten Kaempfe (leicht, mittel, schwer). Ein Tipp zeigt die Details (die
Gegner mit sichtbarer Ausruestung), "Kaempfen" startet. Ab und zu ersetzt
ein **Chaos-Kampf** die Wahl: Gegner vorher unsichtbar, bessere Beute. Der
Chaos-Virus als eigener Modus entfaellt.

**Takt** heisst die Ausloesevoraussetzung einer Faehigkeit (Entscheidung
7. Nov.): "Takt: jeder 3. Angriff" oder "Takt: alle 3 s".

**Nimbus-Passive Echo** (entschieden und gebaut 7. Nov., ersetzt den
Zauberwirker): der Takt ist 50 % laenger, dafuer wirkt jede Faehigkeit
**zweimal hintereinander**. Runenstab: alle 4,5 s zwei Vortex; Blaster: jeder
4. statt jeder 3. Angriff, dann zwei Doppelschuesse. Im Schnitt genauso
stark wie das Halbieren (2 Faehigkeiten je 4,5 s), aber als ein grosser,
sichtbarer Moment. Gemessen (je 200 Kaempfe): Spiegel 100:100, gegen
gewuerfelte Gegner 136:64, Nimbus 11,2 Schaden/s. Der Nimbus bleibt so stark
(Entscheidung des Spielers -- der Strix ist auch noch nicht ausgeglichen).
(Vorher gebaut, verworfen: einmal halbieren, 3 s / 1,5 s im Wechsel.)

**Runenstab:** die Faehigkeit (Vortex) loest nach Zeit aus (alle 3 s),
Reichweite 5 -- der Nimbus muss nicht angreifen, um zu zaubern, und kann
auf seine Stellung achten.

**Gebaut (Aufraeumen, 6. Nov. 2026):** Ueberschuss am Schild, Schild nur nach
Ruhe (`combat.shield_recharge`), Kerne ohne Werte und ohne Halter, Kanone
entfernt, Gegnerstaerke nach `RunState.reference_power`, Nimbus-Passive neu
(seit 7. Nov. Echo),
Vortex nach Zeit (Rw 5), Angriffe ohne Namen. Noch offen: Deflektor und
Drohnen-Pod als Waffen, Module, Level, Karte.

Gemessen (je 200 Kaempfe, Standard-Squad):

| | vorher | nachher |
|---|---|---|
| gegen gewuerfelte Gegner | 107:93, 27 s | 155:45, 17 s |
| Spiegel | 101:99 | 95:105, 20 s |
| Schaden je s: Molok / Nimbus / Strix / Vireo | 4,6 / 5,5 / 6,7 / 3,7 | 5,6 / 11,0 / 8,0 / 4,9 (Spiegel) |
| Vortex je Minute | 12 | 23 |

Lesart: der Nimbus ist jetzt der staerkste Schadensmacher -- der Vortex
(14 Energie im Umkreis 2, Sog, Verlangsamung) kommt im Schnitt alle 2,25 s.
Entscheidung (7. Nov.): so lassen, erst den Strix mit ausgleichen.
Gewuerfelte Gegner tragen selten Runenstab am Nimbus, deshalb das deutliche
155:45; der Kampfwert (`power_score`) bildet den Vortex nach Zeit noch nicht
ab. Balancing-Thema: Vortex-Schaden oder Takt.

**Ebenfalls entschieden (Vorschlaege angenommen):**

* **Gebaut 7. Nov.:** Deflektor und Drohnen-Pod als Waffen (Werte unten;
  Aktionsfelder `heal`, `shield_gain`, `support`). Gemessen (je 200 Kaempfe,
  Standard-Squad, Molok mit Hammer + Deflektor): Spiegel 108:92, gegen
  gewuerfelte Gegner 145:55; der Molok macht 6,7 statt 5,6 Schaden/s.
* **Drohnen-Pod:** Angriff Reparaturstrahl (Rw 3, heilt den Verbuendeten
  mit dem geringsten Anteil Integritaet); ist niemand verletzt oder der
  Traeger allein, schiessen die Drohnen schwach auf den naechsten Gegner.
  Faehigkeit "Schutzdrohne" (Takt: jeder 4. Angriff): der am staerksten
  verletzte Verbuendete bekommt 15 Schild. Gebaut: Heilung 6, Schuss 4
  Energie, alle 1,5 s. KI: steht ein Verletzter ausser Reichweite, geht der
  Traeger zu ihm. Die passive Selbstheilung (5 % je Puls) ist weg.
* **Deflektor:** Angriff 6 kinetisch, Rw 1, alle 1,5 s; Faehigkeit
  "Schildladung" (Takt: jeder 4. Angriff): 15 Schild fuer den Traeger, auch
  ueber das Maximum (hoechstens Maximum + 15). DEF +5 bleibt.
* **Karte:** verzweigte Wege ueber mehrere Kaempfe (wie FTL / Slay the
  Spire), man plant 2-3 Kaempfe voraus.
* **Ueberschuss am Schild** (`ActionResolver.resolve_damage`): der Rest nach
  dem Schildbruch wird in Rohschaden zurueckgerechnet (gebaut).

## 6b. Brainstorming -- als Naechstes zu besprechen

Vom Spieler angestossen (6. Nov. 2026):

1. **Die vier Identitaeten** im Ganzen: Passive, KI, passende Waffen.
2. **Die Zusatzidentitaet der Neon-DROMEs** (Schild als Ressource fuer
   Faehigkeiten, leuchtende Roehren).
3. **Schadensarten:** kinetisch, Energie -- und "Faehigkeitsschaden"? Im
   Cyber-Setting gibt es keine Magie. Vorschlag zur Diskussion: es bleibt bei
   **zwei Schadensarten** (kinetisch, Energie), jede Aktion hat ihre Art.
   Dazu ein neuer Wert **Leistung (LST)** am DROME, der nur
   Faehigkeitsschaden verstaerkt (+X % je Punkt). Der Nimbus hat viel
   Leistung, der Strix kaum. So bleibt eine kinetische Faehigkeit gut gegen
   Integritaet, und "Faehigkeitsschaden" ist eine Skalierung, keine dritte
   Art.

4. **Tanks: viel Integritaet, kaum Schild** (Gedanke des Spielers, 6. Nov.).
   Durchgerechnet (je 200 Kaempfe, Molok mit Kanone + Deflektor):

   | Molok | Siege | Molok lebt |
   |---|---|---|
   | heute 145 HP / 55 Schild (Spiegel) | 101:99 | 20,6 s |
   | 200 HP / 10 Schild gegen heute | 115:85 | 21,3 s |
   | 185 HP / 15 Schild gegen heute | 104:96 | 20,6 s |
   | heute gegen Neon-Blaster-Gegner | 84:116 | 19,9 s |
   | 200 HP / 10 Schild gegen Neon-Blaster-Gegner | 97:103 | 20,4 s |

   Lesart: die Summe bleibt fast gleich, aber die Rollen werden klar -- Energie
   und Schildbrecher fuer Schild-DROMEs, kinetisch (Lanze, Klinge, Hammer) fuer
   Tanks. Laenger leben tut der Molok erst mit der Praesenz, die Schaden auf
   ihn zieht. Neon-Blaster bleibt wie er ist (Entscheidung 6. Nov.).

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
* **Prototyp gebaut (6. Nov. 2026):** Teile mit Tag `neon` bekommen beim
  Backen eine Leuchtebene (`_glow.svg`, nur die Roehren mit breitem Strich);
  `NeonGlow` legt sie additiv darueber, pulsiert und flackert. Kein Shader
  noetig, laeuft also auch im GL-Compatibility-Renderer. Erstes Teil: der
  Neon-Blaster. Ein Neon-DROME (ganzes Chassis) waere der naechste Schritt.

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

Erledigt: 1-5 (KI, ein Platz, Vireo, Molok, Strix/Nimbus). Die Kerne (alt 6)
entfallen (6g). Weiter:

1. ~~Aufraeumen nach 6g~~ (gebaut 6. Nov.), dazu Nimbus-Passive Echo und
   Deflektor/Drohnen-Pod als Waffen (gebaut 7. Nov.); der Nimbus bleibt
   vorerst so stark.
2. ~~Zwischenstopp nach dem Kampf: Lager, Credits, Ausruesten~~ (gebaut
   7. Nov.: Phase STOP in `RunState`, Lager 8 Plaetze, Credits je Kampf und
   fuer Verkaeufe, Beute geht am Ende nach Hause). Credits werden erst mit
   dem Laden (Punkt 3) ausgegeben.
3. Module und Rezepte (6g), dann der Laden.
4. Level fuer DROMEs und Waffen, die nach dem Lauf bleiben.
5. Karte wie bei FTL mit Chaos-Kaempfen.
6. Neon City als erste Region mit Neon-Gegnern und Neon-Varianten.
7. Spaeter: Skillbaeume.
