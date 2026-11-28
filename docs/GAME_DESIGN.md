# CyberDrome – Game Design (Hintergrund)

> **Stand 26. Nov. 2026: Hintergrund, nicht Leitplan.** Leitplan ist `docs/KERNPLAN.md`,
> was gebaut ist steht in `docs/PROJEKTSTAND.md`. Gestrichen wurden die Teile aus der Zeit
> als rundenbasiertes Taktikspiel und der SVG-Zeit (Pixelart-Begruendung, vier Richtungen,
> Asset-Budget, Aggro-Tabelle, Animations-Optionen, alte offene Punkte, SVG-Werkstatt).
> Ebenso Abschnitt 3 (DROME-Aufbau, Teile-Codes, Slots, Silhouettenregel) -- das steht heute
> in `parts/README.md`. Was bleibt, wird aus dem Code zitiert (§9 Huelle, §10 Besitz,
> §11 Schaden, §12, §13); es ist Entwurfsstand vom Aug.–Nov. 2026 und nennt noch Teile, die es
> nicht mehr gibt (Belagerungskanone, Koedersender, Orbit-Fokus, SVG-Werkstatt, Aggro). Gueltig
> ist es nur, soweit es zu PROJEKTSTAND und Kernplan passt.

## 1. Eckdaten

| | |
|---|---|
| Genre | Autobattler in Echtzeit mit Roguelike-Einsatz |
| Setting | Cyberpunk / Neon |
| Engine | Godot |
| Plattformen | Android (Mobile) und Desktop |
| Perspektive | 3D mit fester Iso-Kamera auf ein Hexfeld |
| Grafikstil | aus 3D-Formen generiert (Generator), Arcade-Glitch-Oberflaeche -- *kein* Pixelart |

## 7a. Angriff, Faehigkeit, Schadensart

Drei Begriffe, die auseinandergehalten werden muessen, weil die Oberflaeche sie
inzwischen getrennt anzeigt:

**Angriff** ist, was eine Waffe von sich aus tut -- Puls-Salve, Schienenschuss,
Runenschlag. **Faehigkeit** ist alles darueber hinaus: ziehen, reparieren,
provozieren, ein Flaechenschlag. Die beiden Budgets sind getrennt und nicht
gegeneinander tauschbar (`TurnState`) -- aber ihre Zahl ist seit §13 nicht mehr
je eins:

* **Der Angriff skaliert mit den Waffen.** Jede Waffe bringt einen Angriffs-
  Aktionspunkt mit; zwei Waffen sind zwei Angriffe pro Zug. `attack_actions` ist
  also die Zahl der Waffen, ein gemeinsamer Vorrat -- zwei gleiche Blaster heissen
  dieselbe Puls-Salve zweimal.
* **Die Faehigkeit hat keinen festen Deckel.** Jede Faehigkeit im Loadout ist
  **einmal pro Zug** ziehbar (`TurnState.used_abilities`); wie viele man in einem
  Zug zieht, entscheidet allein, was man bezahlen kann. Gebremst wird nicht mehr
  ueber einen Zaehler, sondern ueber Energie und Abklingzeit (§13).

**Jede Waffe traegt beides** -- ihren Angriff UND eine eigene Faehigkeit (§13).
Die alte Regel „eine Waffe wird als `attack` gefuehrt, nicht als `ability`" ist
damit hinfaellig: es gibt keinen geteilten Ein-Faehigkeits-Slot mehr, den eine
Waffe sich selbst wegnehmen koennte.

**Zweimal dasselbe Teil ergibt EINE Faehigkeit.** Zwei Orbit-Fokusse summieren
ihre Stats weiter, aber die Aktionsliste zeigt den Orbit-Sog einmal: eine
Faehigkeit ist ohnehin nur einmal je Zug ziehbar, ein zweiter Eintrag verspraeche
eine Wahl, die es nicht gibt. Beim **Angriff** ist es anders -- zwei Waffen
zaehlen zwei Angriffspunkte, auch wenn es dieselbe Salve ist.

**Schadensart ist vorerst durchgehend `normal`.** Eine Schadensordnung --
Resistenzen, Anfaelligkeiten, Ruestungstypen -- ist nicht entschieden, und
solange sie es nicht ist, gibt es genau einen Wert. Das Feld existiert
trotzdem schon (`ActionData.damage_type`) und steht in jedem Tooltip: eine
Anzeige, die den Wert verschweigt, muesste beim Nachziehen ueberall gesucht
werden, und `ActionResolver._apply_armor()` ist der Haken, an dem die Ordnung
einmal haengt. Im MVP reicht die Kette den Schaden dort unveraendert durch.

## 9. Vom Baukasten zur Klasse (Vorschlag, in Abstimmung -- Stand 2026-08)

> **Dieser Abschnitt ist noch nicht entschieden.** Er haelt eine Richtung fest,
> die gegengelesen und korrigiert wird, bevor Code faellt. Wo er einer frueheren
> Setzung widerspricht, ist das ausdruecklich vermerkt -- §2 (Regel 1: nie
> backen), §3 (Zusammensetzung) und §5 (Archetypen durch Kombination) werden
> erst umgeschrieben, wenn die Richtung hier steht.

### 9a. Die Diagnose: an der falschen Stelle modular

Das heutige Modell (§3, §5) laesst **alles frei mischen** -- Kopf, Koerper,
Fuesse, Kern und Ausruestung, quer durch alle Sets. Das war als Staerke gedacht
(„Archetypen entstehen dadurch, dass der Spieler Teile kombiniert"), erzeugt in
der Praxis aber zwei Probleme:

1. **Optische Fremdkoerper.** Ein Strix-Kopf auf einem Molok-Torso mit
   Vireo-Beinen ist kein Archetyp, sondern ein Flickwerk. Kopf, Koerper und
   Fuesse gehoeren gestalterisch zusammen -- sie sollen *immer* zueinander
   passen.
2. **Der DROME liest sich nicht als Rolle.** Wer frei mischt, baut keine Klasse,
   sondern einen Werteklumpen. Der Reiz einer Einheit -- „der Strix ist duenn,
   trifft aber hart" -- verduennt sich, sobald man seine Beine gegen die eines
   Tanks tauschen kann.

Die Modularitaet ist also nicht falsch, sie sitzt an der falschen Stelle. Der
Vorschlag verschiebt sie: **weg vom Mischen der Rahmenteile, hin zu Kern,
Ausruestung und Upgrades.** Das ist genau die Achse, die im letzten Schritt
schon aufgemacht wurde -- der 3-Blaster-Spieler, den wir *wollen* (§8: „moeglich,
aber nicht optimal"), baut seinen Aufbau nicht aus fremden Beinen, sondern aus
Waffenwahl innerhalb seiner Huelle.

### 9b. Die vier Bausteine, neu geschnitten

| Baustein | Was er ist | Traegt | Waehlbarkeit |
|---|---|---|---|
| **Huelle** | Kopf + Koerper + Fuesse als EIN Teil, aus demselben Set | Integritaet, ATK, DEF, MOV, SPD, Gewicht, Ausruestungsslots, Traversierung, Sensorik | **die Klasse.** Eine Huelle = ein Archetyp mit fester Silhouette |
| **Kern** | die Energie-Identitaet, **optisch erkennbar** | `en_max`, `en_regen`, kernspezifische Eigenheit UND **je Variante eine aktive Faehigkeit** (§13) | der Spielstil -- was der Bot mit seinem Strom macht, inkl. seiner Signatur-Faehigkeit |
| **Ausruestung** | die Bestueckung in den Slots der Huelle | Waffen, Schilde, Support | die eigentliche Aufbau-Entscheidung (zwei Schilde vs. zwei Nahkampf; Runenstab vs. Schuetze) |
| **Upgrades** | Varianten von Kernen und Ausruestung | Modifikatoren (siehe 9d) | die *tiefe* Modularitaet, ueber Progression erworben |

Ergebnis: **DROMEs sind Klassen, keine modularen Bots.** Man bekommt immer den
optischen Strix und entscheidet dann *innerhalb* der Klasse -- Kern, Bestueckung,
Upgrades. Die Themen bleiben an der Huelle haengen: Strix = wenig Integritaet,
harte Treffer; Molok = ist da und geht nicht.

**Der Spielstil ist auf einen Blick lesbar aus Huelle + Kern + Waffe.** Alle drei
sind optisch erkennbar und sollen es bleiben -- wer eine DROME ansieht, sieht die
Klasse (Huelle), was sie mit ihrer Energie macht (Kern) und womit sie zuschlaegt
(Waffe). Nur die Upgrade-Feinheiten liegen darunter und werden inspiziert (9d).

### 9c. Die Huelle wird gebacken -- und das ist jetzt richtig

Die Gruendungsregel (§2, Regel 1) lautete „nie zusammenbacken, zur Laufzeit
ueber Anker zusammensetzen" -- weil das freie Kombinieren der Rahmenteile sonst
in tausende Sprites explodiert (§2: 12.500). Diese Begruendung traegt **nur,
solange die Rahmen frei kombiniert werden.** Im Klassenmodell ist der Rahmen je
Klasse fest und wird nie getauscht, das Produkt kollabiert: 4 Klassen × 4
Richtungen × wenige Animationsframes statt 5 × 5 × 5 × …

Damit ist das Baken nicht nur erlaubt, sondern **das Richtige**: die Huelle wird
zu **Sprite-Bilddateien vorgerendert** -- am billigsten zu zeichnen (auf Android
entscheidend, §1) und die Garantie, dass Kopf, Koerper und Fuesse *immer* stimmig
sind, ohne Laufzeit-Naht. **Wie** die Datei entsteht, ist egal (in SVG autoren,
als PNG exportieren); massgeblich ist, dass die Laufzeit gebackene Sprites nutzt.

Laufzeit-zusammengesetzt bleibt genau das **Tauschbare**: Kern und Waffe. Sie
lassen sich per Definition nicht in die Huelle backen und bleiben eigene Sprites
ueber den Ankern der Huelle, jedes mit eigenem Rueckstoss/FX. Das Anker-System
ueberlebt also dort, wo es noch gebraucht wird (Tauschbares montieren), und
faellt weg, wo es das nicht wurde (einen festen Rahmen bei jedem Zeichnen neu
zusammennaehen).

Genau daraus faellt auch die Animation (§7): idle/Zucken/Regenerieren ueber
Transform + FX auf der gebackenen Huelle, Schuss als Rueckstoss auf dem
Waffen-Overlay, und der Laufzyklus entweder als kurze Frame-Folge je Huelle oder
ueber separat gebackene Beine. Sprites + Transforms sind der billigste Pfad.

> **Revidiert §2 (Regel 1) und §5 fuer die Huelle.** Die Huelle wird gebacken,
> weil ihre Zusammensetzung fest ist; Ausruestung und Kern bleiben
> Laufzeit-Overlays ueber Anker. „Ausruestung ist set-uebergreifend nutzbar"
> bleibt wahr; „Rahmenteile quer durch alle Sets kombinieren" wird zu:
> Rahmenteile sind an ihr Set gebunden und bilden die Huelle.

### 9d. Wohin die Modularitaet wandert: Upgrades

Hier lebt das „bau dir deinen eigenen" jetzt. Beispiele aus der Vision:

* **Ausruestung:** eine Schienen-Lanze, die eine Reihe Gegner durchschlaegt,
  ODER eine, die zweimal schiesst.
* **Kern:** einer, der weniger Energie je Faehigkeit zieht, ODER einer, der mehr
  zieht und dafuer die Flaeche der Faehigkeit vergroessert.

Das Muster ist jedes Mal ein **Tausch, keine reine Aufwertung** -- Durchschlag
gegen Doppelschuss, Effizienz gegen Wucht. Genau so bleibt es eine
Entscheidung und wird nicht zur Pflichtreihenfolge.

**Upgrades zeigen sich NICHT in der Silhouette -- und das ist so gewollt.** Eine
Lanze bleibt eine Lanze; ob sie eine Reihe durchschlaegt oder zweimal schiesst,
liest man ueber einen **Inspizieren-Knopf**, nicht am Sprite. Das ueberschreibt
§3d bewusst: die GROBE Funktion liest der Spieler weiter an der Form
(Lanze = weitreichende Durchschlagwaffe), die FEINEN Modifikatoren per
Inspektion. Fuer Gegner hat diese Inspektion bereits ein Zuhause -- den Tooltip
aus §6h, der schon die Aggro-Tabelle zeigt und einfach auch Ausruestung und
Upgrades auffuehrt; fuer eigene DROMEs ein Inspizieren-Feld in Werkstatt/Roster.

Der Kompromiss, offen ausgesprochen, damit er bewusst faellt: zwei gleich
aussehende Lanzen koennen sich anders verhalten, und ein Gegner muss den Tooltip
LESEN, nicht nur hinsehen. In einem deterministischen Tactics ist das tragbar,
**solange die Auskunft auf Abruf vollstaendig ist** -- was der Tooltip
garantiert. Es wuerde erst zum Problem, wenn ein Upgrade etwas aenderte, worauf
man sofort reagieren muss und nicht rechtzeitig inspizieren kann. Daraus die
Leitplanke: Upgrade-Wirkungen bleiben bei dem, was ein Tooltip-Blick abdeckt --
keine versteckten Ueberraschungen bei Zugreihenfolge oder Zielwahl.

Zwei Dinge sind noch offen und gehoeren entschieden, bevor gebaut wird:

1. **Form der Upgrades.** Varianten-Gegenstaende (man besitzt „Lanze
   Mk-Durchschlag" als eigenes Teil) oder Mod-Slots am Teil (die Lanze hat N
   Steckplaetze)? Ersteres ist einfacher und passt zum Loot-Gedanken; Letzteres
   ist flexibler, aber ein zweites Inventarsystem.
2. **Herkunft.** Kommen Upgrades aus Beute, Crafting oder beidem? Das haengt am
   offenen Progressionspunkt in §8 („Teile-Loot vs. Crafting").

### 9e. Das Botmenue / Roster

Heute ist der „Squad" eine fluechtige Auswahl frisch gebauter DROMEs. Die Vision
will darueber eine **bleibende Sammlung**: ein Menue, das die *erworbenen* Bots
zeigt, aus dem der Squad fuers Gefecht gezogen wird. Ein Roster-Eintrag ist ein
benannter, besessener Aufbau (Huelle + Kern + Ausruestung + Upgrades).

Das setzt eine Besitz-Schicht voraus, die es noch nicht gibt: man *hat* Huellen,
Kerne, Ausruestung und Upgrades, statt sie frei aus dem Katalog zu waehlen. Das
verbindet sich mit den offenen §8-Punkten „Progression" und „Wie viele DROMEs
bildet der Spieler pro Gefecht auf". Offen: MVP oder spaeter, und woher der
Nachschub kommt (naheliegend: Beute aus dem Chaos-Virus).

### 9f. Was bestehen bleibt -- und was sich sauber einfuegt

* **Baut auf dem letzten Schritt auf.** Die weichen Kosten (Gewicht → Tempo,
  Energie → Mana, §8) sind das Fundament. Die Huelle legt die Rahmenwerte fest,
  die Ausruestung kostet weiter SPD ueber die Zuladung, Faehigkeiten kosten
  Mana. Der 3-Blaster-Aufbau lebt vollstaendig innerhalb der Slots einer Huelle
  -- und soll gewuerdigt, nicht verriegelt werden.
* **§6b ueberlebt unbeschaedigt.** „Aggro entsteht aus Aktionen, nie aus
  Identitaet" bleibt wahr, auch wenn die Huelle jetzt eine Klasse ist: Tanken
  bleibt emergent, es gibt weiterhin keinen `Tank`-Grundwert. Die Klasse gibt
  die Buehne, das Verhalten entsteht im Kampf.
* **Kartiert fast eins zu eins auf den Bestand.** Die vier Sets `bot1`–`bot4`
  SIND bereits die vier Klassen (Vireo/Scout, Molok/Juggernaut, Nimbus/
  Technomant, Strix/Marksman). `scout_head` + `scout_body` + `scout_feet` werden
  zur Vireo-Huelle; `scout_core` & Co. werden die waehlbaren Kern-Chips. Der
  Umbau ist ueberwiegend eine **Umgruppierung plus Kern-Entkopplung**, kein
  Neubau -- das senkt das Risiko erheblich.

### 9g. Die Klassen duerfen sich im Tempo nicht vierteln

Die heutige Spreizung ist kaputt. Grob aus dem Bestand:

| Klasse | SPD (Zugtakt) | MOV (Felder/Zug) |
|---|---|---|
| Vireo | 13 | 4 |
| Nimbus | 13 | 5 |
| Strix | 8 | 4 |
| **Molok** | **~6** | **2** |

Der Molok kommt **halb so oft** dran UND geht **halb so weit** -- verrechnet ist
das rund ein Viertel der Brettpraesenz eines Vireo je Zeit. Das ist kein
„langsamer Tank", das ist „kaum im Spiel". Die Spreizung muss **zusammenrücken**:
langsamer ja, geviertelt nein. Ein Tank soll sich bedaechtig anfuehlen -- etwa
eine Aktivierung hinter dem Flinken --, nicht ueberrundet.

Zwei Stellschrauben, und sie haengen zusammen: die Basiswerte SPD/MOV je Huelle
**und** die Zuladung, die ueber `payload_slowdown()` (§8) zusaetzlich SPD zieht.
Ein schwer bestueckter Molok wird dadurch doppelt gebremst -- Basiswert niedrig
UND Zuladung hoch. Die Kompression muss den Zuladungs-Abzug also mit einplanen,
sonst trifft es die langsame Klasse zweimal. Konkrete Zahlen sind Playtest; das
Verhaeltnis ist die Designaussage und wird beim Festlegen der Huellenwerte im
Reframe gesetzt.

### 9i. Entscheidungen

**Entschieden (Runde 2026-08):**

* **Rendering:** die Huelle wird zu Sprite-Bilddateien gebacken; nur die
  tauschbaren Overlays (Kern, Waffe) bleiben Laufzeit. (9c)
* **Kern:** universal in jede Huelle und **optisch erkennbar** -- der Spielstil
  liest sich aus Huelle + Kern + Waffe. (9b, 9d)
* **Upgrades unsichtbar:** kein Silhouetten-Tell; die Feinheiten laufen ueber
  einen Inspizieren-Knopf bzw. den Gegner-Tooltip. „Lanze bleibt Lanze." (9d)
* **Tempo:** SPD/MOV-Spreizung der Klassen ruecken zusammen -- langsamer ja,
  geviertelt nein. (9g)
* **SVG-Werkstatt bleibt** als Autorenwerkzeug, wird ans neue Modell angepasst.
  (9h)
* **Upgrade-Modell:** Varianten UND Mod-Slots -- zwei Rollen, ein System (§10c).

**Noch offen:**

1. **Fraktionen:** was sind sie ueberhaupt? Neuer Weltbaustein (§10d).
2. **Roster/Progression als eigene Schicht:** der Reframe baut gegen den freien
   Katalog, Besitz + Beute kommen darueber. Reihenfolge okay? (§10)
3. **Klassen-Anzahl:** reichen die vier Huellen fuers Erste, oder brauchst du
   zum Ausprobieren mehr?

## 10. Besitz, Beute, Upgrades (Vorschlag, in Abstimmung -- Stand 2026-08)

> **Wieder in Abstimmung, nicht festgezurrt.** §9 (das Bau-Modell) ist entschieden
> und baubar; dieser Abschnitt ist die Meta-Schicht darueber -- Besitz und
> Progression --, und er hat noch echte Gabelungen. Vor allem gilt: **§9 haengt
> nicht an §10.** Der Reframe baut gegen den freien Katalog (man „besitzt" alles);
> die Besitz-Schicht wird spaeter darueber gelegt, ohne den Reframe anzufassen.

### 10a. Die drei Quellen

Die spontane Idee, geordnet -- und sie hat eine saubere innere Logik:

| Was man findet | Woher | Charakter |
|---|---|---|
| **Ausruestung** (Waffen, Schilde, Module) | **Chaos-Virus** -- der bestehende RNG-Modus | Masse, Grind, Wiederholung. Das ist der Stoff, von dem man viel will |
| **Kerne** | **Kopfgeld-Modus** -- fraktionsdifferenziert | seltener, gezielter. Ein Kern ist eine Identitaets-Entscheidung, keine Handvoll |
| **Huellen** (neue Bots/Klassen) | **Meilenstein-Modus** -- handgebaut, mehrteilig | die groessten Brocken. Eine neue Klasse ist ein Meilenstein, kein Drop |

Das Muster ist gut: **je identitaetsstiftender das Ding, desto kuratierter die
Quelle.** Beliebiges Verschleissmaterial (Ausruestung, Module) faellt aus dem
RNG-Grind; die seltenen Landmarken (Kerne, Huellen) kommen aus gebauten Modi. So
grindet man nie eine ganze Klasse zusammen, und ein Kern fuehlt sich nie an wie
Munition.

### 10b. Roster und Squad-Auswahl

Heute ist der „Squad" eine fluechtige Auswahl frisch gebauter DROMEs. Darueber
soll eine **bleibende Sammlung** liegen: das Botmenue zeigt die *besessenen*
Bots, und vor jedem Gefecht waehlt man daraus -- „ich darf vier mitnehmen, also
Molok, Vireo, Strix-Sniper, und den Rest lasse ich zuhause". Ein Roster-Eintrag
ist ein benannter, besessener Aufbau: **Huelle + verbauter Kern + Ausruestung +
Upgrades**, gespeichert und wiederverwendbar.

Das beantwortet zwei offene §8-Punkte zusammen: „wie viele DROMEs bildet der
Spieler auf" wird zur Vorab-Wahl, und das Squad-Speicherformat (schon JSON,
`GameState`) waechst vom Wegwerf-Squad zum Roster mit Auswahl.

### 10c. Mods und Varianten -- zwei verschiedene Dinge

Praezisiert: es sind **zwei getrennte Mechaniken**, nicht eine.

**Mod-Slot -- das Basteln.** Jede Ausruestung hat **einen freien Mod-Slot**. Man
fuellt ihn mit einem **Mod** aus einer wachsenden Bibliothek, die von einfach bis
charaktervoll reicht:

* **Stat-Boosts** -- +ATK, +Reichweite, −`en_cost`.
* **Passive / bedingte Effekte** -- „trifft fuer jede Runde, in der nicht
  geschossen wurde, 10 % haerter", ein Aufladeeffekt, ein Effekt beim Treffer.

Das ist die tauschbare Bastelseite. Die Mod-Bibliothek muss noch ausdetailliert
werden -- die bedingten Passive sind der interessante Teil und der, der Balancing
braucht.

**Variante -- die Fraktions-Form.** Eine Variante ist eine **leicht veraenderte
Fassung des Originals**, mit eigener Faerbung und leicht anderen Werten, die zu
einer **Fraktion** gehoert (§10d). Kein „verbauter Mod", sondern ein eigenes,
umgefaerbtes und neu abgestimmtes Teil:

* Optisch: statt der schwarzen Umrandung z.B. passives Licht oder Leuchtstreifen
  an Waffe und Chassis (Neon).
* Mechanisch: ein **Neon-Molok** ist weniger gepanzert als der normale, hat dafuer
  ein Schild und etwas mehr Speed; der normale Molok glaenzt mit der meisten
  Panzerung. Dieselbe Klasse, anderes Werteprofil im Thema der Fraktion.

Beide leben nebeneinander: eine **Variante** (Fraktions-Teil) hat genauso ihren
**Mod-Slot** wie das Original. Loot bringt also beides -- neue Varianten UND lose
Mods.

### 10d. Fraktionen sind angepasste Gegnerarten

Entschieden: eine **Fraktion ist eine eigene Gegnerart** mit durchgaengigem
Profil. Sie nutzt Waffen und Ausruestung aus **derselben Variation** (die
Varianten aus §10c), hat ein eigenes **Schadens-/Verteidigungsprofil** (§11) und
ein eigenes **KI-Verhalten**.

**Erste Fraktion: die Neons.** Aus Neon City, optisch leuchtende Waffen
(Leuchtstreifen statt schwarzer Umrandung). Ihr Profil:

* Angriff eher **Energieschaden** (§11).
* Verteidigung eher **Schild** als Panzerung -- ihr Neon-Molok tauscht Panzerung
  gegen Schild und etwas Speed.
* **Strategisch mittelmaessig** -- sie rennen nicht dumm in einen Kill, sind aber
  auch keine reinen Strategen.

**Eigene KI -- als Profil, nicht als zweite Engine.** Die Nutzenbewertung des
`AIController` (§ai) bleibt; eine Fraktion bekommt ein eigenes **Gewichtsprofil**
darueber. „Mittelmaessig" heisst dann: ein Satz Gewichte zwischen „stur auf den
Kill" und „voll optimiert" -- ein paar Zahlen je Fraktion, keine zweite
KI-Codebasis. So bleibt das Verhalten pro Fraktion lesbar und tunebar.

Das blockiert den Reframe (§9) nicht und ist Post-MVP (§12) -- aber die
Fiktionsebene steht jetzt.

### 10e. Modi und Scope

Drei Modi stehen damit im Raum: **Chaos-Virus** (existiert, RNG-Farm),
**Kopfgeld** (neu, Fraktions-Kerne), **Meilenstein** (neu, handgebaute
Kampagne fuer Huellen). Das ist bewusst als Nennung festgehalten, nicht als
Bauauftrag -- **drei Modi plus eine Besitz-Schicht sind weit ueber dem MVP.**

Die Reihenfolge, die daraus faellt und die den Reframe nicht ausbremst:

1. **Reframe (§9)** gegen den freien Katalog -- Huelle, universeller Kern,
   kompaktere SPD/MOV. Man „besitzt" vorlaeufig alles.
2. **Roster + Besitz** -- die Sammlung und die Vorab-Auswahl, zunaechst mit einem
   von Hand gesetzten Startbestand statt Beute.
3. **Upgrades** -- Modulslots an Teilen und Kernen, Varianten als Sonderfall.
4. **Beute-Quellen** -- Chaos-Virus dropt Ausruestung/Module; Kopfgeld und
   Meilenstein danach, wenn Fraktionen und Kampagnenstruktur stehen.

### 10f. Stand der Entscheidungen (§10)

* **Fraktionen:** entschieden -- angepasste Gegnerarten mit eigenem Profil und
  KI-Gewichten; Neons als erste. (10d)
* **Mods und Varianten:** entschieden -- zwei getrennte Dinge. Ein Mod-Slot je
  Teil, dazu Fraktions-Varianten. (10c)
* **Scope-Reihenfolge:** Reframe zuerst gegen den freien Katalog, Besitz/Beute
  darueber. (10e, §12)

### 10g. Inventar, Instanzen und die Auswahl vor der Werkstatt

Die Anforderung: ein **endliches Inventar** (nicht mehr der freie Katalog), ein
**Auswahlmenue vor der Werkstatt**, und ein Teil, das nicht zweimal gleichzeitig
verbaut werden kann. Dafuer braucht es **Instanzen mit IDs**.

**Instanzen statt Katalog.** Heute haelt `DromeBuild.slots` Bauteil-TYPEN
(`eq_rail_lance`), und die Werkstatt ist ein freier Katalog. Neu: man besitzt
einzelne **Instanzen**. Eine Instanz = eindeutige `uid` + Typ (spaeter + Mods +
Level, §10c/§12b). Zwei Schienen-Lanzen sind zwei Instanzen mit zwei uids -- so
ist immer klar, welche wo steckt, und spaeter traegt jede ihre eigenen Mods.

**Drei Schichten:**

* **Inventar** -- alle besessenen Instanzen. Quelle der Wahrheit fuer „was habe
  ich".
* **Roster** -- deine DROMEs. Ein DROME = eine **Chassis-Instanz** plus
  zugewiesene Kern- und Ausruestungs-Instanzen (`assignments: {slot: uid}`). Das
  **Auswahlmenue vor der Werkstatt IST die Roster-Liste**: waehle den DROME
  (= das Chassis), den du gerade anpasst.
* **DromeBuild bleibt typ-basiert und unberuehrt.** Fuer Stats, Render und Kampf
  wird der Build zur Laufzeit aus den assignments abgeleitet (uid → Instanz →
  Typ → slots). **Gegner haben kein Inventar** -- sie werden weiter typ-basiert
  generiert, ganz ohne diese Schicht. So kostet die Besitz-Schicht den
  Kampf-Code nichts (dieselbe Trennsauberkeit wie beim Reframe, §9c).

**Eindeutigkeit faellt von selbst.** Eine uid steckt in **hoechstens einer**
Zuweisung im ganzen Roster. Die Werkstatt bietet fuer einen Slot nur **freie**
Instanzen an (uid nirgends zugewiesen) plus die gerade verbaute. „Schienen-Lanze
nur waehlbar, wenn nicht woanders verbaut" ist damit kein Sonderfall, sondern die
Grundregel.

**Startbestand (handgesetzt, §12c):** die vier Standard-Chassis (= vier DROMEs),
je eine Instanz jedes Standard-Kerns und jeder Standard-Ausruestung. Weil acht
Ausruestungsteile nicht alle Slots von vier DROMEs fuellen, entsteht die knappe
Entscheidung von selbst -- genau der Reiz. Nach jedem Chaos-Virus wandern
erbeutete Teile als neue Instanzen ins Inventar; neue Chassis (Meilenstein) sind
neue Roster-Plaetze.

**Save-Format** waechst: Inventar (Instanzliste) + Roster (DROMEs als {Name,
assignments}). Der heutige Wegwerf-Squad (`GameState`) wird zum Roster; ein
DromeBuild wird beim Laden aus den assignments rekonstruiert. Die spaetere
**Squad-Vorauswahl** (§10b: „vier mitnehmen, Rest zuhause") zieht dann aus dem
Roster -- eigener, kleiner Schritt danach.

**Entschieden:**

* **Start-Kerne:** nur die vier Standard-Kerne. Weitere Kerne kommen als **Drop
  aus dem Chaos-Virus** -- Kerne sind Loot wie Ausruestung.
* **Chassis-Duplikate:** ausdruecklich erlaubt. Hat man zwei Strix, baut man den
  einen mit Blaster auf Mehrfachtreffer, den anderen mit Lanze auf
  Sniper-Brecher -- zwei DROMEs derselben Klasse, verschiedene Rollen. Ein neues
  Chassis (egal ob Duplikat oder neue Klasse) ist ein neuer Roster-Platz.
* **Bad-Luck-Schutz beim Loot** (post-MVP): eine **Zerlegen-Aktion** (Teile in
  Material aufloesen) und eine **Shop-Alternative** federn Pech im Drop ab.
  Bewusst nicht im MVP -- erst notieren, wenn die Beute-Schleife steht.

**Umgesetzt (Stand 2026-08):** Die Besitz-Schicht steht in der Engine.
`PartInstance` (uid + Typ), `RosterEntry` (Chassis-Instanz + `assignments`) und
`Roster` (Inventar, Eindeutigkeit, Ableitung nach `DromeBuild`, Startbestand,
Migration des alten Wegwerf-Squads, Save v2) bilden das Modell; `GameState`
haelt den Roster und leitet den Kampf-Squad aus den `in_squad`-Eintraegen ab.
Die **Garage** (`scenes/garage.tscn`) ist die Roster-Liste und die Auswahl vor
der Werkstatt; die **Werkstatt** passt genau einen DROME an und baut Kern und
Ausruestung nur aus **freien** Instanzen ein. Der handgesetzte Startbestand ist
da (vier Chassis, vier Kerne, acht Ausruestungsteile). Noch offen bleiben die
Beute-Quellen, Mods (§10c) und Fraktions-Varianten (§10c/d) -- die knappe
Auswahl entsteht heute aus dem festen Startbestand.

## 11. Schaden und Verteidigung (Vorschlag, in Abstimmung -- Stand 2026-08)

Das beantwortet die lange offene **Schadensordnung** (§7a, §8): ja, es gibt
mehrere Arten, und sie greifen ueber eine kleine Matrix statt ueber
Multiplikator-Wildwuchs. Zwei Schadensarten, zwei Verteidigungsarten.

**Zwei Verteidigungen -- sie verhalten sich grundverschieden:**

| | Panzerung | Schild |
|---|---|---|
| Natur | flache Schadensreduktion, immer da, **solange HP da ist** (das heutige DEF) | eigene Leiste vor der HP |
| Regeneration | **nein** | **ja** -- fuellt sich ueber die Zeit wieder auf |
| schwach gegen | physischen Schaden | **Energieschaden** |

**Zwei Schadensarten -- jede trifft beide Verteidigungen, nur unterschiedlich
stark:**

* **Physisch** trifft **Panzerung** voll, **Schild** weniger.
* **Energie** trifft **Schild** voll, **Panzerung** weniger (aber sie durchdringt
  Panzerung, sie prallt nicht ab).

Daraus fallen echte Entscheidungen: ein Neon-Gegner (Schild) will mit Energie
geknackt werden; ein schwer gepanzerter Molok mit physischem Schaden. Kein Ziel
ist immun -- die falsche Schadensart ist langsamer, nicht wirkungslos. Das haelt
die Nachrechenbarkeit, die `mitigate()` schuetzt (§8): flache, gedeckelte
Abzuege, keine Multiplikatorketten.

**Andockpunkte im Code stehen schon:** `ActionData.damage_type` existiert (heute
durchgehend `normal`, §7a), und `ActionResolver._apply_armor()` ist der Haken,
an dem die Matrix haengt. Das Schild ist eine neue, regenerierende Leiste vor der
HP; die Panzerung ist das heutige DEF, nur benannt.

**Scope:** Post-MVP. Der MVP bleibt bei einer Schadensart (`normal`), wie §7a es
heute haelt. Die Matrix kommt zusammen mit den **Fraktionen**, weil die Neons ihr
erster Anlass sind (§12).

## 12. Progression, Leveling und der MVP-Schnitt (in Ideenfindung)

> **Terminologie ab hier:** die „Huelle" aus §9 heisst **Chassis** -- der Begriff
> passt am besten, weil das Chassis im Klassenmodell der ganze Rahmen IST. Wo §9
> noch „Huelle" sagt, ist dasselbe gemeint.

### 12a. Die Klassen und die Kerne

Der Bestand deckt vier Klassen ab, und die reichen fuers Erste:

| Chassis | Rolle |
|---|---|
| **Vireo** | flink, Nahdistanz-Skirmisher |
| **Strix** | Fernkampf, physisch, wenig Leben |
| **Molok** | Tank, „ist da und geht nicht" |
| **Nimbus** | Magie/Energie, Caster |

Wichtiger als eine fuenfte Klasse sind **mehr Kerne**, weil der Kern die
Stil-Achse ist (§9b), universal in jedes Chassis passt UND je Variante eine
aktive Faehigkeit traegt (§13). Zum Start gibt es nur die vier Standard-Kerne;
weitere kommen als **Drop aus dem Chaos-Virus** (§10g). Vorschlag fuer zwei
klare Gegensatzpaare als Loot:

* **Effizienz-Kern** -- guenstigere Faehigkeiten (−`en_cost`), belohnt
  Faehigkeits-lastige Aufbauten.
* **Verstaerker-Kern** -- teurere, aber groessere Faehigkeiten (mehr Flaeche/
  Reichweite). Der Tausch Effizienz gegen Wucht, den §9d schon beschreibt.

(Ein spaeterer **Drain-Kern** -- der „Batterieentlader von hinten" aus deiner
Vision -- braucht den Energieschaden aus §11 und wandert damit hinter den MVP.)

### 12b. Leveling -- Waffen und Chassis, zwei Formen

Deine Richtung, festgehalten (Detail folgt, wenn du dir Systeme angesehen hast):

* **Waffen leveln wie in Botworld Adventures.** Ein Level-Up **modifiziert den
  Angriff passiv** -- die Schienen-Lanze des Strix wird ueber die Zeit
  spuerbar besser (mehr Durchschlag, schnellere Aufladung, ein Zusatzeffekt),
  ohne dass der Spieler im Kampf etwas anders bedient. Passt genau zu „Upgrades
  sind unsichtbar, Feinheiten im Inspizieren" (§9d).
* **Chassis ueber einen Skilltree (Yggdrasil-Stil in Godot).** Ein Baum aus
  **Passiv- UND Stat-Nodes**: ein Bruiser-Molok holt sich Zaehigkeit oder ATK
  dran; ein Neon-Molok mehr Energieschild oder eine Passive „**Schild
  aufbrauchen und in den Berserker-Modus gehen**". Das ist die Heimat der
  Chassis-Progression und hat viel Potential.

Zwei Abhaengigkeiten, die die Reihenfolge vorgeben:

1. Die Berserker-Passive **setzt Schilde voraus** -- also §11 zuerst.
2. „Upgrades = Stats oder Passive oder Faehigkeiten?" -- Antwort: **nur Stats und
   Passive, keine aktiven Faehigkeiten.** Stat-Nodes sind billig und sofort,
   Passive brauchen je einen Effekt-Haken. **Aktive Faehigkeiten bleiben aus dem
   BAUM draussen** -- was ein DROME TUN kann, kommt aus seiner Ausruestung
   (Waffen = Angriffe) und seinem **Kern** (die aktive Faehigkeit, §13), nicht
   aus dem Skilltree. Der Baum vertieft nur passiv. Das haelt ihn zugleich
   bezahlbar: mit Stat-Nodes anfangen, nur an Schluesselstellen Passive setzen.

> **Warnung an den Umfang:** ein eigener Skilltree je Chassis × Fraktion
> explodiert wie einst die Sprites (§2). Baeume gehoeren geteilt und
> parametrisiert -- ein Grundbaum je Rolle, Fraktionen setzen nur einzelne Nodes
> anders. Sonst ist die Progression das naechste, was am Umfang scheitert.

### 12c. Der MVP-Schnitt

Damit die Tiefe den MVP nicht auffrisst -- die Linie, klar gezogen:

**Im MVP:**

* Die vier Chassis als Klassen (Reframe §9), Kern universal (+1–2 Kerne, 12a).
* Die Basis-Ausruestung, **noch ohne Mods** (Roster 12d).
* Weiche Kosten (§8), Aggro/Kampf (§6), kohaerente Gegnergenerierung -- steht.
* **Eine** Schadensart (`normal`), wie §7a heute.
* Roster + Squad-Vorauswahl mit handgesetztem Startbestand.
* Chaos-Virus als einziger Modus.

**Nach dem MVP (die Tiefe, in dieser Reihenfolge sinnvoll):**

1. Schadensordnung + Schild/Panzerung (§11).
2. Fraktionen (Neons zuerst) + KI-Profile + Varianten (§10c/d).
3. Mod-System -- ein Slot je Teil, Mod-Bibliothek inkl. bedingter Passive.
4. Leveling: Waffen-Level, dann Chassis-Skilltree (12b).
5. Kopfgeld- und Meilenstein-Modus (§10e).

### 12d. Basis-Ausruestung fuer den MVP

Du hast Schienen-Lanze, Blaster, Belagerungskanone genannt. **Vergessen hast du
den Runenstab** (die Energiewaffe des Nimbus) -- und die Support-Teile, die keine
Waffen sind, aber Aufbauten tragen:

| Teil | Art | im MVP? |
|---|---|---|
| Puls-Blaster | Waffe, Standard | ja |
| Schienen-Lanze | Waffe, Fernkampf schwer | ja |
| Belagerungskanone | Waffe, schwer | ja |
| Runenstab | Waffe, Energie/Nahbereich (Nimbus) | ja -- sonst hat der Nimbus keine Waffe |
| Deflektor-Schild | Support, Verteidigung | ja -- der Tank-Baustein |
| Drohnen-Pod | Support, Heilung | ja |
| Orbit-Fokus | Support, Faehigkeit (Orbit-Sog) | ja -- die Nimbus-Faehigkeit |
| Koedersender | Support, Aggro/Provokation | ja -- Aggro-System haengt dran (§6b) |

Alle acht existieren bereits. **Mods kommen erst nach dem MVP** -- fuer den MVP
sind es die Basisteile ohne Slot-Fuellung. Die „zwei Mods je Waffe" sind das
erste Progressionsziel danach.

## 13. Aktive Faehigkeiten kommen von den Waffen (entschieden und umgesetzt -- Stand 2026-08)

Der fruehere Vorschlag „Faehigkeit kommt vom Kern" ist **verworfen**. Er
verzahnte die Faehigkeit mit der falschen Achse und liess `TurnState` mit seinem
Ein-Faehigkeits-Budget als ungeloesten Knoten zurueck. Die getroffene und
implementierte Entscheidung dreht das um:

**Faehigkeiten kommen von den WAFFEN. Jede Waffe traegt zwei Aktionen:** ihren
Angriff **und** eine eigene Faehigkeit. Der **Kern** ist damit wieder reine
Energie-/Mana-Identitaet (§9b) -- er traegt keine Aktion.

### 13a. Das Aktions-Modell

* **Angriff je Waffe.** Jede Waffe bringt einen Angriffs-Aktionspunkt mit: zwei
  Waffen sind zwei Angriffe pro Zug (`TurnState.attack_actions`, ein gemeinsamer
  Vorrat = Zahl der Waffen). Zwei gleiche Blaster heissen dieselbe Salve zweimal.
* **Kein Faehigkeits-Deckel.** Wenn schon die QUELLE begrenzt ist (Waffen plus
  einzelne Gadgets), muss nicht zusaetzlich die ANZAHL pro Zug gedeckelt werden.
  Jede Faehigkeit im Loadout ist **einmal pro Zug** ziehbar -- mehr Faehigkeiten
  im Aufbau heisst mehr moegliche Faehigkeiten im Zug. Das schafft Diversitaet
  statt eines starren Budgets.
* **Zwei Bremsen, zwei Arten.** Statt eines Zaehlers bremsen:
  - die **Energie** (`en_cost`) die *energetischen* Faehigkeiten -- alles
    rausballern geht, dann ist der Tank leer und regeneriert ein paar Zuege
    („Mana-Cap");
  - die **Abklingzeit** (`cooldown_turns`) die *mechanischen* -- das **Sperrfeuer**
    der Belagerungskanone zieht per Fiktion keinen Strom („Masse bremst, Strom
    kostet", §8), dafuer geht es nur alle paar Zuege.
  Jede Faehigkeit traegt genau eine der beiden; die Voreinstellung
  `abilities.brake = "beides"` liest beide Felder. Das „einmal pro Zug" liegt
  **darunter** und haengt an keiner der beiden Bremsen (`TurnState.used_abilities`),
  damit es in jedem Modus gilt -- auch fuer eine stromlose Faehigkeit.

### 13b. Die Faehigkeit je Waffe

Jede der vier Waffen hat jetzt neben ihrem Angriff eine eigene Faehigkeit, die
ihre Klassenfantasie verstaerkt:

| Waffe | Angriff | Faehigkeit | Bremse |
|---|---|---|---|
| Puls-Blaster (Vireo) | Puls-Salve | **Streusalve** -- leichter Flaechenschlag | Energie |
| Schienen-Lanze (Strix) | Schienenschuss | **Praezisionsschuss** -- harter Fernschuss, leise | Energie |
| Belagerungskanone (Molok) | Belagerungsschlag | **Sperrfeuer** -- grosse Flaeche, Verwehrung | Abklingzeit |
| Runenstab (Nimbus) | Runenschlag | **Arkanwelle** -- Nahbereichs-Nova | Energie |

Die Zahlen (Staerke, Kosten, Reichweite) sind Setzungen fuer den naechsten
Playtest, nicht Endstand.

### 13c. Gadgets bleiben individuell

Die Support-Teile (Ködersender, Orbit-Fokus, Drohnen-Pod, Deflektor) sind **nicht
per Regel** mit einer Aktive versehen -- nur, was ins Thema passt. Der Deflektor
ist passiv (der Beleg, dass ein Gadget keine Aktive tragen muss); Drohnen-Pod,
Orbit-Fokus und Ködersender tragen je eine.

**Notiert fuer spaeter:** thematisch klingt „Orbit-Fokus" eher nach **Aufklaerung**
als nach dem Orbit-Sog. Diese Umdeutung braucht aber eine Sensor-/Haze-Mechanik,
die es noch nicht gibt; bis dahin bleibt der Sog erhalten und funktioniert.

### 13d. Wohin die Varianten-Achse wandert

Weil die Faehigkeit nicht mehr am Kern haengt, wandert die Fraktions-/Varianten-
Achse (§10c/d, „Neon-Variante bringt Energy Overclock") auf **Waffe/Gadget**:
eine Neon-Variante einer Waffe traegt die energetische Auspraegung *ihrer*
Faehigkeit. Kein neues System, nur eine andere Andockstelle.

**Hintergedanke, weiter NICHT MVP:** dass *jede* Waffe eine Faehigkeit traegt,
ist gesetzt; ob spaeter auch Mods zusaetzliche Faehigkeiten einbringen, bleibt
Progressionsthema (§12c). Der X-Faktor-Dial aus dem alten Vorschlag (Kosten und
Wirkung gekoppelt) ist als Tuning-Idee weiter gueltig, aber ihre Zahlen sind
Playtest.
