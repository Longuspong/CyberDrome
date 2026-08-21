# CyberDrome – Game Design (Arbeitsstand)

Lebendes Dokument. Haelt fest, was schon entschieden ist, damit die
Asset-Produktion nicht wieder an unbedachtem Umfang scheitert.

---

## 1. Eckdaten

| | |
|---|---|
| Genre | Rundenbasiertes 2D-Tactics-RPG |
| Setting | Cyberpunk / Neon |
| Engine | Godot |
| Plattformen | Android (Mobile) und Desktop |
| Perspektive | **Isometrisch**, Kamera 45 Grad von oben auf ein gedrehtes Gitter |
| Grafikstil | **SVG, modular** – ausdruecklich *kein* Pixelart |

## 2. Warum SVG statt Pixelart

Das ist die zentrale Lehre aus dem Vorgaengerprojekt: dort ist die
Asset-Produktion an der Sprite-Kombinatorik gescheitert.

Bei modularen Einheiten mit vier Blickrichtungen waechst der Aufwand
multiplikativ. Eine DROME aus Kern + Kopf + Koerper + Fuessen + zwei
Ausruestungsslots braucht als Pixelart **pro Kombination** einen Sprite. Bei
je fuenf Varianten und vier Richtungen sind das

```
5 · 5 · 5 · 5 · 5 · 4  =  12.500 Sprites
```

Mit modularen SVG-Teilen wird daraus eine Summe statt eines Produkts:

```
(5 + 5 + 5 + 5 + 5) · 4  =  100 Dateien
```

Daraus folgen die drei Regeln, die alles andere bestimmen:

1. **Teile werden nie zusammengebacken** – die Kombination entsteht zur Laufzeit
   ueber Anker.
2. **Farbe ist ein Parameter, keine Bildinformation** – Fraktionen, Seltenheits­stufen
   und Spielerfarben sind reines Umfaerben, kein neues Asset. Eingestellt wird
   ueber **vier Kategorien je Bauteiltyp**; die acht CSS-Rollen im SVG leiten
   sich daraus ab (Details in `parts/README.md`, Abschnitt 4a).
3. **Vier Richtungen sind das Maximum** – und sie werden nicht gezeichnet,
   sondern aus einer Quader-Definition projiziert. Keine Zwischenwinkel.

Die Grenze der Skalierbarkeit ist damit nicht mehr die Zeichenarbeit, sondern
die Rendering-Kosten auf Android (siehe `docs/GODOT_INTEGRATION.md`).

## 3. Die DROME

**DROME** = *Death Robot Omni Machine Executor*. Die Spieleinheit. Sie besteht
aus:

| Bestandteil | Anzahl | Rolle im Spiel (Entwurf) |
|---|---|---|
| **Kern** | 1 | Identitaet der Einheit: Energie, Fertigkeitspool, Grundwerte. Sitzt **im** Chassis (Brust- oder Rueckenplatte), nicht davor – die Sitzregel dazu steht in [`parts/README.md`](../parts/README.md), Abschnitt 6b |
| **Kopf** | 1 | Sensorik: Sicht, Trefferchance, Statusresistenz |
| **Koerper** | 1 | Chassis: HP, Panzerung – **bestimmt die Zahl der Ausruestungsanker** |
| **Fuesse** | 1 | Bewegungsreichweite, Gelaendeverhalten, Ausweichen |
| **Ausruestung** | 1–3 | Waffen, Schilde, Support-Module |

**Der Koerper bestimmt die Ausruestungsslots.** Regelfall sind zwei Anker
(links / rechts). Ausnahmen sind ausdruecklich vorgesehen:

* schwere Chassis mit einem zusaetzlichen Schulteranker → drei Slots
* Spezial-Chassis mit einem einzelnen zentralen Anker → ein Slot

Technisch faellt das ohne Sonderfall an: die Slots sind exakt die `equip_*`-Anker
des Koerper-Teils. Ein Chassis bekommt einen dritten Slot, indem es einen dritten
Anker in seine JSON schreibt.

> **Woher der dritte Slot des Molok kommt.** Er ist kein Balancing-Entwurf,
> sondern ein Format-Beleg: `bot2` ist als Beispiel dafuer entstanden, dass die
> Slotzahl allein aus den Ankern faellt und im Code kein Sonderfall noetig ist
> (siehe 3b). Dass daraus eine Einheit mit drei vollwertigen Waffenarmen wird,
> war nie die Absicht -- und ist auch nicht der Fall: der Schulteranker nimmt
> nur leichte Support-Module (Abschnitt 3c). `bot4` (LR-Strix) zeigt seither
> die Gegenrichtung mit genau einem Slot.

## 3a. Teile-Codes

Jedes Teil traegt neben seinem Klarnamen einen kurzen, stabilen **Code**. Der
Klarname ist das, was Spieler und Werkstatt zeigen (*Vireo Chassis*); der Code
ist das, was in Balancing-Tabellen, Loot-Listen, Rezepten und Speicherstaenden
steht. Er aendert sich nie, auch wenn ein Teil umbenannt oder die Datei
verschoben wird.

| Praefix | Teiletyp |
|---|---|
| `COR` | Kern |
| `HED` | Kopf |
| `CHS` | Koerper / Chassis |
| `LEG` | Fuesse |
| `EQP` | Ausruestung |

Die Nummer laeuft je Typ durch, quer ueber alle Sets: `CHS-001` ist das Vireo-,
`CHS-002` das Molok-Chassis. Codes muessen projektweit eindeutig sein – Server
und Generator pruefen das beim Einlesen bzw. Erzeugen.

Aktueller Bestand:

| Code | Teil | Set |
|---|---|---|
| `CHS-001` | Vireo Chassis | bot1 |
| `HED-001` | Vireo Sensorkopf | bot1 |
| `LEG-001` | Vireo Sprintbeine | bot1 |
| `COR-001` | Vireo Impulskern | bot1 |
| `EQP-001` | Puls-Blaster | bot1 |
| `EQP-002` | Deflektor-Schild | bot1 |
| `CHS-002` | Molok Chassis | bot2 |
| `HED-002` | Molok Bunkerkopf | bot2 |
| `LEG-002` | Molok Standbeine | bot2 |
| `COR-002` | Molok Fusionskern | bot2 |
| `EQP-003` | Belagerungskanone | bot2 |
| `EQP-004` | Drohnen-Pod | bot2 |
| `EQP-008` | Koedersender | bot2 |
| `CHS-003` | Nimbus Chassis | bot3 |
| `HED-003` | Nimbus Flachhelm | bot3 |
| `LEG-003` | Nimbus Fahrwerk | bot3 |
| `COR-003` | Nimbus Arkankern | bot3 |
| `EQP-005` | Runenstab | bot3 |
| `EQP-006` | Orbit-Fokus | bot3 |
| `CHS-004` | Strix Chassis | bot4 |
| `HED-004` | Strix Okularkopf | bot4 |
| `LEG-004` | Strix Federbeine | bot4 |
| `COR-004` | Strix Zielrechner | bot4 |
| `EQP-007` | Schienen-Lanze | bot4 |

Der Code ist bewusst getrennt vom Datei-Slug (`scout_body`), der die Dateinamen
traegt und beim Stoebern im Ordner lesbar bleiben soll. Ein exportiertes
Loadout enthaelt beides plus den Klarnamen – damit laesst es sich ohne die
Bibliothek lesen.

## 3b. Die vier Sets und was sie beweisen sollen

Ein Set ist eine Autoren-Schublade, kein Bausatz (siehe Abschnitt 5). Die vier
mitgelieferten Sets decken bewusst je einen anderen Fall ab:

| Set | Silhouette | zeigt |
|---|---|---|
| `bot1` RX-Vireo // Scout | schlank, kantig, zweibeinig | den Standardfall: zwei Ausruestungsanker |
| `bot2` HX-Molok // Juggernaut | geduckt: Panzerschuerze, Keil-Torso, Pauldrons ueber dem Kopfsockel | den dritten Anker (Schulterpod) |
| `bot3` AR-Nimbus // Technomant | **rund**, flacher Helm, **Fahrgestell statt Beinen** | dass Formensprache und Fortbewegung frei sind |
| `bot4` LR-Strix // Marksman | schmal, hoch, **Gegengewichts-Ausleger ueber dem Kopf** | den Ein-Slot-Fall -- eine Waffe, dafuer die schwerste |

`bot3` ist der Gegenentwurf zu den ersten beiden: Rotationskoerper statt
gestapelter Quader, ein weit auskragender flacher Helm statt eines Visierkopfs,
zwei grosse Raeder auf einer Achse statt Beinen. Technisch aendert das nichts –
es ist derselbe Anker-Vertrag, dieselbe Projektion, dieselben vier Richtungen.
Genau das ist der Punkt: ein Rad ist nur ein Rotationskoerper um die
Bot-Links-Achse, kein Sonderfall in Code oder Format.

`bot4` ist der Gegenentwurf auf der **Slot**-Seite. Molok kauft sich drei Anker
mit Masse und Traegheit; Strix macht das Gegenteil und hat genau einen -- zentral
im Joch vor der Brust, dafuer ohne Obergrenze. Damit man das ansieht, traegt der
Rahmen kein Armpaar, sondern ein Joch und dahinter einen Gegengewichts-Ausleger,
der nach hinten-oben ueber den Kopf laeuft. Man erkennt einen Strix an der
schraegen Rueckenlinie, bevor man die Waffe sieht -- genau so, wie es Abschnitt
3d verlangt.

## 3c. Slots sind spezifiziert, nicht nur gezaehlt

Ein Anker sagt, **wo** etwas sitzt. Fuer ein deterministisches Tactics muss ein
Slot aber auch sagen, **was** dort sitzen darf -- sonst traegt ein mobiler
Sprinter eine Belagerungskanone und schiesst damit reihenweise Leuten in den
Ruecken. Nicht weil das ausbalanciert waere, sondern weil ihm niemand
widersprochen hat.

Jede Ausruestung traegt deshalb eine **Montageklasse** (`light` < `medium` <
`heavy` -- was die Halterung an Masse, Rueckstoss und Hebel aushalten muss) und
eine **Bauart** (`weapon` · `shield` · `support`). Jeder Slot eines Chassis
sagt, bis zu welcher Klasse und fuer welche Bauarten er zustaendig ist:

| Chassis | Slot | nimmt |
|---|---|---|
| `CHS-001` RX-Vireo | beide Arme | bis mittel |
| `CHS-002` HX-Molok | beide Arme | bis schwer |
| `CHS-002` HX-Molok | Schulter | bis leicht, nur Support |
| `CHS-003` AR-Nimbus | beide Arme | bis mittel |
| `CHS-004` LR-Strix | Mitte (einziger) | bis schwer |

> **Nachtrag zur Traglast des Molok.** Sie ist mit dem Koedersender von 28 auf
> 31 gestiegen. Das ist keine Aufwertung, sondern eine Korrektur: bis dahin gab
> es im Satz nur zwei Ausruestungsteile fuer drei Anker, deshalb ist nie
> aufgefallen, dass das Chassis seine eigenen drei Anker gar nicht bestuecken
> konnte. Ein Chassis, das das nicht kann, ist ein Datenfehler und kein
> Balancing -- `check_stock_builds()` in `tools/build_sample_parts.py` prueft
> es seither bei jedem Lauf.

Damit ist die Belagerungskanone dort, wo sie hingehoert: an einem Rahmen, der
sie tragen kann und dafuer langsam ist. Und die Molok-Schulter ist das, wonach
sie aussieht -- eine Bruecke hinter dem Kopf, ohne Gegenhalt und ohne Hand:
Sensorik und Drohnen ja, Schild oder schweres Geraet nein.

**Das ist die Balancing-Achse, die ohne eine einzige Zahl auskommt.** Ein
Chassis kauft Slots mit Traegheit (Molok: drei Anker, einer davon eingeschraenkt)
oder verzichtet auf sie und bekommt dafuer die Obergrenze geschenkt (Strix: ein
Anker, dafuer voll belastbar). Erst die Zahlen darueber entscheiden ueber
Feinheiten -- die Grobstruktur steht schon in den Ankern.

Format und Voreinstellungen: `parts/README.md`, Abschnitt 2a.

## 3d. Lesbarkeitsregel: keine zwei Funktionen mit derselben Silhouette

> **Zwei Teile mit unterschiedlicher Spielfunktion muessen sich an der
> SILHOUETTE unterscheiden -- nicht an der Groesse, nicht an der Farbe.**

Das Spiel ist deterministisch: wer eine gegnerische DROME ansieht, soll vor
seinem Zug wissen, was sie kann. Diese Auskunft gibt die Form, und nur die
Form. Groesse gibt sie nicht -- die Kachel ist klein, Teile ueberlappen sich,
und eine Einheit weiter hinten auf der Karte ist ohnehin kleiner.

Eine Belagerungskanone, die nur ein groesser gezogener Blaster ist, ist deshalb
**kein Schoenheitsfehler, sondern ein Regelfehler**: der Spieler trifft seine
Entscheidung ohne die Information, die das Spielsystem ihm verspricht. Dasselbe
gilt fuer ein Energieschwert, das aussieht wie ein Energiedolch.

Die Regel wirkt am schaerfsten dort, wo die Auswahl gross ist und die Funktion
weit auseinanderliegt -- bei **Waffen**. Bei Rahmenteilen ist sie milder: ein
Bein wird im Verbund gelesen, nicht einzeln, und die Auswahl ist klein. Milder
heisst aber nicht "egal": Beine haben unmittelbare Auswirkungen aufs Spiel, und
wenn zwei Beinpaare verschiedene Bewegungswerte haben, gehoert der Unterschied
in die Form. Umgekehrt gilt: **haben zwei Teile dieselbe Funktion, wird das
Bauteil wiederverwendet** statt leicht abgewandelt kopiert -- ein Set ist eine
Autoren-Schublade, kein Bausatz.

`tools/build_sample_parts.py` prueft das bei jedem Lauf: es projiziert jedes
Teil mit derselben Kamera wie die Grafik und vergleicht die gefuellten
Umrissflaechen aus zwei Blickrichtungen. Ab 0.85 Deckung bricht der Generator
bei Ausruestung ab. **Fuer Rahmenteile gibt es keine Grenze**, nur eine
Tabelle: dort saettigt das Mass -- jedes gedrungene Teil wird normiert zum
selben Klumpen, und ein kantiger Bunkerkopf kommt gegen einen runden
Krempenhelm auf 0.88, obwohl die beiden nichts miteinander zu tun haben.

**Der Test ersetzt das Hinsehen nicht.** Er faengt zuverlaessig den Fall
"abgeschrieben und groesser gezogen"; ob zwei Rahmen dieselbe Formensprache
sprechen, entscheidet weiterhin das Auge. Genau daran ist das Molok-Chassis
einmal vorbeigekommen -- ein Vireo mit breiteren Kisten --, bevor es
Panzerschuerze, Keil-Torso und hochsitzende Pauldrons bekam. Wie das Mass
funktioniert, wo es saettigt und welche Merkmale taugen, steht in
`parts/README.md`, Abschnitt 6a.

## 4. Perspektive und die vier Richtungen

Die Kamera steht im 45-Grad-Winkel ueber einem um 45 Grad gedrehten Gitter. Ein
Bodenfeld ist damit eine Raute im Verhaeltnis sqrt(2):1. Von jedem Quader sind
immer genau drei Flaechen sichtbar: zwei Flanken und die Oberseite – das ist
der Unterschied zu einer Frontalansicht, die flach wirkt.

Die vier Richtungen zeigen auf die vier Diagonalen des Bildschirms:

| Richtung | Auf dem Bildschirm |
|---|---|
| `south` | unten-links (zum Betrachter) |
| `east`  | unten-rechts |
| `north` | oben-rechts (vom Betrachter weg) |
| `west`  | oben-links |

Konventionen:

* **`links` / `rechts` in Ankernamen meinen die Seiten des BOTS**, nicht den
  Bildschirm. Beim Drehen bleibt eine Waffe dadurch am selben Arm.
* **Das Licht haengt am Bildschirm, nicht am Bot.** Oberseiten hell, linke
  Flanken mittel, rechte Flanken dunkel – in allen vier Richtungen gleich.
  Deshalb ist Spiegeln auf dem Bildschirm keine gueltige Abkuerzung mehr:
  eine gespiegelte Waffe bekaeme ihre Lichtseite auf die falsche Flanke.
  Waffen werden stattdessen symmetrisch um ihren eigenen Anker modelliert und
  passen so an beide Arme.
* **Die Zeichenreihenfolge ist die Kameratiefe** (`-px - py + pz`) und faellt
  aus der Geometrie ab. In der Nordansicht rutscht die Ausruestung von selbst
  hinter den Koerper, der Schulterpod von selbst vor den Kopf – ohne
  handgepflegte Tabelle und ohne eigene Teil-Variante.

## 5. Asset-Budget

Pro Set bei vier Richtungen entstehen 4 SVG-Dateien je Teil, also **24 SVGs**
fuer ein Set mit zwei Ausruestungs­gegenstaenden.

Ein **Set ist eine Autoren-Schublade, kein Bausatz**: es fasst zusammen, was
gemeinsam entworfen wurde, und bringt eine Startpalette mit. Es gibt keine
fertigen DROMEs zum Auswaehlen – **Archetypen entstehen dadurch, dass der
Spieler Teile kombiniert**, quer durch alle Sets. Die Werkstatt zeigt deshalb
immer die gesamte Bibliothek; eingegrenzt wird ueber den Filter, nicht ueber
das Set.

Entscheidend ist aber der *Autoren*-Aufwand, und der ist ein Viertel davon:
ein Teil wird einmal als Quader-Definition beschrieben, die vier Ansichten
erzeugt der Renderer. Vier handgezeichnete Ansichten pro Teil waeren nicht nur
vierfache Arbeit, sondern wuerden bei jeder Aenderung auseinanderlaufen.

Ausruestung ist set-uebergreifend nutzbar, solange Anker **und Slotregel**
passen: ein Slot nimmt nur, was seine Montageklasse und Bauart zulassen
(Abschnitt 3c). Zusaetzlich kann sich ein Teil ueber `slots` auf bestimmte Anker
festlegen – wie der Drohnen-Pod, der auf die Schulter gehoert.

Realistische Zielgroesse fuer einen ersten spielbaren Stand: 3–4 Chassis-Familien
plus ein gemeinsamer Ausruestungs-Pool. Das sind ~100–150 SVG-Dateien, nicht
mehrere tausend Sprites.

## 6. Aggro: wie ein Gegner sein Ziel waehlt

Jeder Gegner fuehrt Buch darueber, wie sehr ihn jede Spielereinheit stoert,
und bezieht das in seine Zielwahl ein. Mehr ist es nicht. Positionierung,
Faehigkeitswahl und Annaeherung bleiben Sache des `AIController` -- **Aggro
beantwortet WEN, nicht WIE**.

Der Begriff ist bewusst neu. Was frueher `threat_score()` hiess, heisst jetzt
**Kampfwert** und ist etwas anderes: die errechnete Staerke eines *Aufbaus*,
Grundlage des Gegner-Matchings, vor dem Gefecht bekannt und fuer beide Seiten
dieselbe Zahl. **Aggro** sagt, wie sehr eine Einheit *einen bestimmten Gegner*
stoert, entsteht erst im Gefecht und ist fuer jeden Gegner eine andere Zahl.
Das Wort „Threat" kommt im Projekt nicht mehr vor -- es hat zwei Fragen
bezeichnet, die nichts miteinander zu tun haben.

### 6a. Nur Gegner fuehren eine Tabelle

Spieler-DROMEs bekommen keine. Ihre Ziele waehlt der Spieler, und eine
Tabelle, die niemand liest, waere eine zweite Wahrheit ueber die Zielwahl.

Die Tabelle sitzt **pro Gegner**, nicht global. Nur so laesst sich eine
Gegnergruppe aufteilen: zwei Gegner bleiben am Molok haengen, waehrend der
Rest den Techniker verfolgt. Eine gemeinsame Zahl je Spielerfigur wuerde die
ganze Gruppe immer auf dasselbe Ziel synchronisieren.

### 6b. Aggro entsteht aus Aktionen, nie aus Identitaet

Kein Chassis, kein Kern und keine Klasse erzeugt Aggro. Nur ausgefuehrte
Aktionen mit messbarer Wirkung: angerichteter Schaden, tatsaechlich geheilte
Integritaet, der Pauschalwert einer Kontroll-Aktion.

Daraus folgt: **Tanken ist emergent, keine Rolle.** Wer vorne steht und laut
zuschlaegt, haelt die Aufmerksamkeit -- auch ohne dass irgendwo „Tank" steht.
Wer nur herumsteht, verliert sie. Ein Grundwert auf dem Chassis waere genau
die Abkuerzung, die das entwertet: dann taenkt, wer das richtige Teil traegt,
statt wer das Richtige tut.

Der einzige Weg zu Aufmerksamkeit ohne eigene Aktion ist der Bauteil-Stat
`aggro_bonus` -- und der kostet einen **Ausruestungsslot**. Im Bestand fuehrt
ihn genau ein Teil: der **Koedersender** (`EQP-008`), leichtes Support-Modul,
+25 Prozentpunkte, dazu die einzige Provokation des Spiels.

Er ist bewusst **nicht** auf die Schulter festgelegt. Waere er es, koennte ihn
allein der Molok tragen -- und zwar in einem Slot, in dem ohnehin keine Waffe
sitzen darf; er waere damit geschenkt. So kostet er ueberall einen Slot, und die
Achse aus Abschnitt 3c greift von selbst:

| Chassis | was der Sender kostet |
|---|---|
| `CHS-002` Molok | einen von drei Ankern -- auf der Schulter konkurriert er nur mit dem Drohnen-Pod |
| `CHS-001` Vireo, `CHS-003` Nimbus | einen von zwei Ankern, also eine Waffe oder das Schild |
| `CHS-004` Strix | **gar nicht tragbar** -- sein einziger Anker haelt die Lanze, und ein Aufbau ohne Waffe ist ungueltig |

Der Strix ist damit der Beleg, dass die Regel beisst: die Einheit, die am
wenigsten Aufmerksamkeit erzeugen will, kann sie auch nicht kaufen -- ohne dass
irgendwo eine Zahl darueber entscheidet.

### 6c. Die Formel

```
delta = wirkung x aggro_coeff x naehe x (1 + aggro_bonus / 100)
```

| Faktor | Bedeutung | wo er steht |
|---|---|---|
| `wirkung` | die TATSAECHLICHE Menge -- Schaden nach der Mitigationskette, Heilung nach dem Deckeln auf `hp_max` | faellt im `ActionResolver` an |
| `aggro_coeff` | wie laut die Aktion ist | Aktions-Metadaten des Bauteils |
| `naehe` | Nahbereichs-Bonus | `data/config.json` |
| `aggro_bonus` | Generierung aus Ausruestung, in Prozentpunkten | Bauteil-Stats |

Der Koeffizient ist der eigentliche Designhebel: er entkoppelt „wie viel
richtet die Waffe an" von „wie sehr provoziert sie". Das Raster --
Grundlinie `1.0`, Heilung `0.5`, Praezisionswaffen `0.35` -- steht in
`tools/build_sample_parts.py` ueber der STATS-Tabelle. Die Verhaeltnisse sind
der Kern, die absoluten Zahlen sind Setzungen ohne Playtest.

Der Strix ist der Fall, fuer den es das gibt: `0.35` bei Power 16 und
Reichweite 7. Er richtet mehr Schaden an als der Nahkaempfer und zieht
trotzdem weniger Aufmerksamkeit -- ohne eine einzige Sonderregel. Umgekehrt
ist der Runenstab bei Reichweite 1 laut und bekommt den Naehe-Faktor obendrauf.

Der Koeffizient haengt ausdruecklich **nicht** an `range_tiles`. Eine
Ableitung waere untunebar und eine zweite, stillschweigende Wahrheit darueber,
wie auffaellig eine Waffe ist.

### 6d. Gebucht wird an genau einer Stelle

`ActionResolver._book_aggro()` -- aufgerufen aus `apply_damage()` und
`heal()`, sonst nirgends. Dieselbe Regel wie beim Schaden selbst und bei der
Position eines DROME.

Das ist nicht Ordnungsliebe, sondern der Grund, warum die Aggro keine Liste
von Sonderfaellen braucht. Weil **jeder** Schaden durch `apply_damage()`
laeuft, bucht Flaechenschaden von selbst pro getroffenem DROME, und was immer
spaeter dazukommt -- Schaden ueber Zeit, Reflexschaden, Umgebungsschaden --
bucht mit, ohne dass jemand daran denken muss. Ueberheilung ist aus demselben
Grund schon geloest: `heal()` gibt zurueck, was wirklich angekommen ist.

Gebucht wird auch gegen Einheiten, die der Gegner **gerade nicht anvisieren
kann** -- etwa weil sie in einem Haze-Feld stehen. Gefiltert wird
ausschliesslich bei der Zielwahl. Sonst waere ein Haze-Feld ein Aggro-Reset
und aus der Deckung zu schiessen kostenlos.

### 6e. Verfall laeuft im ZYKLUS, nicht im Zug

Einmal je Zyklus verblassen **alle** Eintraege, auch der des aktuellen Ziels --
dieser nur langsamer, um `decay_scale_incumbent`. Ohne Verfall zementiert ein
grosser Treffer aus Zyklus 1 die Zielwahl fuer das ganze Gefecht; mit zu
starkem Verfall wird jeder Zug zur Neuwahl.

**Der Amtsinhaber war einmal ganz ausgenommen, und das hat genau den Zustand
hergestellt, gegen den dieser Absatz antritt.** `add()` ist eine unbegrenzte
Summe; ein Herausforderer, der `d` Aggro je Zyklus erzeugt, saettigt dagegen
bei `d · (1−r)/r` -- bei `decay_rate` 0.15 das 5,67-fache seines Beitrags.
Gegen einen eingefrorenen Wert darueber kam er nie an. Wer in den ersten
Zyklen genug aufgebaut hatte, war ab dann dauerhaft das Ziel, egal wie lange
wer wie hart zuschlug.

Das ist der unangenehme Sorte Fehler: es sieht nicht nach einem aus. Es sieht
nach „der Gegner ist auf meinen Molok fixiert" aus, also nach genau dem, was
das System verspricht. Aufgefallen waere es erst als Frustration -- „ich
kriege ihn nicht von meinem Techniker runter" --, und dann haette man an
`decay_rate` und `aggro_weight` gedreht, wo die Ursache nicht liegt.

Die Traegheit sitzt deshalb jetzt allein im Amtsinhaber-Bonus (§6f), und das
ist auch begrifflich sauber: **Verfall ist ein Parameter des Modells,
Traegheit eine Frage der Nutzenbewertung.** Der langsamere Satz hier ist kein
zweiter Traegheitshebel, sondern nur die Zusicherung, dass ein Ziel nicht
mitten im Anlauf wegrutscht.

**Der Takt ist der Zyklus, weil ein Zug in diesem Spiel keine gleichmaessige
Zeiteinheit ist.** SPD bestimmt, wie oft jemand drankommt. Verfiele die
Tabelle pro eigenem Zug, wuerde ein schneller Gegner die Beitraege aller
Nicht-Ziele schneller abbauen und dadurch *staerker* an seinem Ziel kleben als
ein langsamer. Niemand wuerde das als Absicht lesen. Der Zyklus ist die
einzige gleichmaessige Uhr im Kampf.

### 6f. Aggro ist ein Summand, Provokation ist eine Regel

Die Tabelle **ersetzt** die Zielwahl der KI nicht, sie geht als weiterer Term
in dieselbe Nutzenbewertung ein. Als Filter wuerde ein Gegner an einem
sicheren Abschuss vorbeilaufen, weil ein anderer DROME weiter oben in der
Tabelle steht -- das liest sich als Fehler, nicht als Aggro.

Eingehaengt wird der **Anteil am Tabellenmaximum** (0..1), nicht der Rohwert.
Der Rohwert waechst ueber das Gefecht unbegrenzt und liefe gegen
Schadenspunkte davon; der Anteil traegt dieselbe Rangfolge und skaliert mit
jeder Balancing-Aenderung von selbst mit. Die Zahl an sich bedeutet nichts --
massgeblich ist nur die Rangfolge innerhalb einer Tabelle.

Dazu ein **Amtsinhaber-Bonus** auf das zuletzt angegriffene Ziel. Er
verhindert, dass die Zielwahl bei fast gleichauf liegenden Werten von Zug zu
Zug flackert; fuer den Spieler waere das nicht von Zufall zu unterscheiden.
Seine Hoehe haengt an der eigenen Waffenreichweite: wer aus sieben Feldern
schiesst, hat sich auf sein Ziel eingerichtet und laesst sich nicht von jedem
Kratzer umlenken. Das ist der billigste Charakterisierungshebel im ganzen
System -- ein Wert je Bauart, ohne eine Zeile KI-Code.

**Er muss unter `aggro_weight` bleiben, und das ist keine Geschmacksfrage.**
Der Aggro-Term ist ein Anteil zwischen 0 und 1 und damit nach oben auf
`aggro_weight` gedeckelt. Steht ein Amtsinhaber-Bonus darueber, kann ihn kein
Herausforderer je aufholen -- die Tabelle waere fuer die Zielwahl vollstaendig
wirkungslos, ohne dass irgendetwas danach aussieht. Genau das war mit 12 gegen
10 der Fall: ein Fernkaempfer konnte sein Ziel ueber die Aggro **nie**
wechseln, nur ueber Schadensunterschiede und `kill_bonus`. Zusammen mit dem
eingefrorenen Verfall aus §6e waren das zwei Sperren hintereinander vor
derselben Tuer. `tests/test_aggro.gd` prueft die Invariante.

Der **einzige harte Zwang** ist die Provokation (`Stoersignal`, die Aktion des
Koedersenders). Sie kommt ausschliesslich aus einer Faehigkeit, kostet Energie,
ist auf drei Zuege befristet und darf deshalb maechtig sein: der Provozierte
laeuft an einem sicheren Abschuss vorbei. Genau das ist der Unterschied zur
gewoehnlichen Aggro, die einen Abschuss nie verhindert.

Die KI erneuert eine Sperre, die sie bereits haelt, **nicht** -- eine
Provokation auf ein bereits provoziertes Ziel bewertet sie mit 0, dieselbe
Ueberlegung wie bei einer Heilung auf Vollleben. Ohne das waere aus der
befristeten Zwangsmechanik eine dauerhafte geworden.

### 6g. Was eine Umlenkung wert ist

Der Schaden taugt als Mass nicht: eine Provokation richtet keinen an, und die
Schadensvorschau liefert dann die Mindestmenge 1. Die staerkste Aktion im
Spiel waere damit die billigste der Bewertung -- die KI besaesse sie und
benutzte sie nie.

Gerechnet wird deshalb in **Lebensleisten** statt in Schadenspunkten. Nicht
wie viel Schaden umgelenkt wird, entscheidet, sondern wie viel er dort und
hier jeweils ausmacht:

```
gewinn = anteil_beim_opfer - anteil_bei_mir        (je Zug, in Leisten)
wert   = min(gewinn x sperrdauer, 1) x taunt_weight
```

Zwoelf Schaden auf einen angeschlagenen Techniker sind etwas anderes als
zwoelf Schaden auf ein volles Molok-Chassis -- und aus genau diesem
Unterschied faellt das gewuenschte Verhalten heraus, ohne dass irgendwo
„Tank" steht. Dieselbe Emergenz, auf der auch die Aggro selbst beruht:

* Ein dickes Chassis provoziert, weil sein eigener Anteil klein ist.
* Ein duenner Gegner laesst es bleiben -- sein Anteil ist groesser als der des
  Opfers, der Gewinn negativ. Er wuerde sich nur selbst verheizen.
* Wer ohnehin schon das Ziel ist, gewinnt nichts: das gefaehrdetste Ziel ist
  dann er selbst, und der Gewinn ist exakt null. Kein Sonderfall noetig.

Gemessen wird das gefaehrdetste Ziel am **Anteil** seiner Lebensleiste, nicht
am Schaden -- sonst waere immer der Dickste das vermeintliche Opfer, und die
KI schuetzte ausgerechnet den, der es am wenigsten braucht.

Dazu ein `rescue_bonus`, wenn der Schuetzling sonst ausscheiden wuerde und der
Provozierende den Treffer selbst uebersteht. Die Obergrenze ist bewusst
gesetzt: mehr als eine ganze Lebensleiste laesst sich nicht retten, egal wie
lange die Sperre haelt. `taunt_weight + rescue_bonus` bleibt damit unter
`kill_bonus` -- **ein sicherer Abschuss geht der Umlenkung vor**, und das soll
er auch. `tests/test_aggro.gd` prueft diese Invariante. Durchgesetzt wird sie in
`ActionResolver.target_blocker()` -- der Funktion, die ohnehin beantwortet, ob
ein Ziel gueltig ist, und deren Begruendung unveraendert in den Tooltip wandert.
Damit gilt sie fuer beide Seiten mit einer einzigen Regel: die KI fragt
dieselbe Funktion, und beim Spieler faerbt sich das Feld grau mit dem Grund
daneben. Eine zweite Durchsetzung in der KI waere eine zweite Regel.

Wiederholtes Provozieren eskaliert **nicht**: der neue Wert leitet sich vom
Tabellenmaximum *ohne den Verursacher* ab und wird nicht addiert. Zweimal
hintereinander provozieren bringt dadurch nichts. Nach Ablauf steht die Quelle
knapp vorn, aber nicht uneinholbar -- das Gefecht kippt zurueck ins normale
Tabellenmodell, statt hart umzuschalten.

**Dieselbe Falle stand an einer zweiten Aktion.** Der Orbit-Sog hat Staerke 0
und `push_tiles` -2; ueber `preview_damage()` bewertet kam er auf die
Mindestmenge 1. Weil das Faehigkeitsbudget eines Angriffs-Aufbaus ohnehin frei
ist, hat die KI ihn damit **jeden Zug** gezogen -- ein Strix mit Reichweite
sieben hat sich Zug um Zug seinen eigenen Vorteil weggezogen und den Gegner
ins Handgemenge geholt.

Die Regel daraus ist allgemeiner als beide Faelle: **eine Aktion ohne
Wirkungsmenge darf nie ueber die Schadensvorschau bewertet werden.** Gerechnet
wird auch hier in der Groesse, die zaehlt -- bei der Provokation in
Lebensleisten, beim Stoss in **Reichweiten**:

```
wunsch = sign(reichweite_des_ziels - meine_reichweite)
wert   = (abstand_vorher - abstand_nachher) x wunsch x shove_weight
```

Wer weiter schiesst als sein Ziel, will Abstand: Heranziehen wird negativ, und
eine negative Bewertung faellt in `_best_move()` heraus -- die Aktion bleibt
einfach ungenutzt. Wer kuerzer schiesst, will den Abstand schliessen; fuer ihn
ist derselbe Zug positiv. Bei gleicher Reichweite gewinnt keiner etwas. Kein
Sonderfall fuer „Nahkaempfer" noetig, das faellt aus dem Vergleich heraus --
dieselbe Emergenz wie ueberall sonst in diesem Kapitel.

### 6h. Der Spieler muss die Tabelle sehen koennen

Nicht als Zugabe, sondern als Bedingung. Der Kampf ist deterministisch und
verspricht, dass sich jede Aktion vorher durchrechnen laesst; die TICK-Leiste
legt die Zugreihenfolge sogar acht Zuege im Voraus offen. Eine verdeckte
Aggro-Tabelle waere die einzige Stelle, an der ein Gegner etwas taete, das der
Spieler nicht nachvollziehen kann -- und damit fuer ihn nicht von Zufall zu
unterscheiden.

Im Tooltip einer gegnerischen DROME steht deshalb die Rangfolge in Anteilen,
mit einer Markierung am aktuellen Ziel. Rohwerte werden nicht gezeigt: sie
bedeuten nichts.

### 6i. Was das System nicht ist

* keine Zielwahl fuer den Spieler -- die ist vollstaendig unabhaengig
* keine Positionierung und keine Faehigkeitswahl der KI
* nichts, was das Gefecht ueberlebt: Aggro ist begegnungslokal und wird beim
  Ausfall eines Ziels und beim Gefechtsende verworfen

Die Eigenschaften, die das Modell tragen muss, stehen als Tests in
`tests/test_aggro.gd`. Sie sind vor jedem Balancing geschrieben worden, weil
sie nicht pruefen, ob die Zahlen gut sind, sondern ob Balancing ueberhaupt Sinn
ergibt: emergentes Tanken, kein Flackern, keine Eskalation bei
Provokations-Spam, Schutz der Backline durch den Koeffizienten -- und, spaeter
dazugekommen, dass anhaltende Wirkung ein einmal gesetztes Ziel **ablösen
kann**.

Die fuenfte fehlte, und sie war rot. Die ersten vier pruefen alle die Ober- und
die Kurzfristseite; die Langfristseite hat niemand angesehen, und dort lagen
zwei Sperren gleichzeitig (§6e, §6f). Das ist die Lehre, die ueber das
Aggro-System hinausgeht: **eine Doku, die gut begruendet, wird beim
Codeschreiben nicht mehr gegengeprueft.** Der billigste Schutz ist, die
Kernbehauptungen als Testfaelle zu formulieren statt als Prosa.

## 7. Zustaende und Animation

Bewusst **noch nicht** entschieden – erst wenn die Statik steht. Notiert als
Optionen, damit das Anker-Format sie nicht ausschliesst:

* Animation ueber Transformationen der Teil-Gruppen (Wippen, Rueckstoss,
  Trefferzucken). Braucht keine neuen Dateien und ist der bevorzugte Weg.
* Zusaetzliche Anker wie `muzzle` oder `fx_*` fuer Projektil- und Effekt-Spawns.
  Das Format erlaubt beliebige Zusatzanker bereits heute.
* Eigene Teil-Varianten fuer Zustaende (beschaedigt, offline) – teuer, daher nur
  fuer wenige Schluesselteile.

## 7a. Angriff, Faehigkeit, Schadensart

Drei Begriffe, die auseinandergehalten werden muessen, weil die Oberflaeche sie
inzwischen getrennt anzeigt:

**Angriff** ist, was eine Waffe von sich aus tut -- Puls-Salve, Schienenschuss,
Runenschlag. **Faehigkeit** ist alles darueber hinaus: ziehen, reparieren,
provozieren. Beide sind je Zug einmal verfuegbar und nicht gegeneinander
tauschbar (`TurnState`). Daraus folgt eine Regel fuer neue Teile: **eine Waffe
wird als `attack` gefuehrt, nicht als `ability`** -- sonst nimmt sie dem Aufbau
still seine Faehigkeitsaktion weg, und der Spieler sieht nur, dass etwas fehlt.
`tests/test_drome_build.gd` haelt das fest.

**Zweimal dasselbe Teil ergibt EINE Aktion.** Zwei Orbit-Fokusse summieren ihre
Stats weiter, aber die Aktionsliste zeigt den Orbit-Sog einmal: das Budget gibt
ihn ohnehin nur einmal her, und ein zweiter Eintrag verspraeche eine Wahl, die
es nicht gibt.

**Schadensart ist vorerst durchgehend `normal`.** Eine Schadensordnung --
Resistenzen, Anfaelligkeiten, Ruestungstypen -- ist nicht entschieden, und
solange sie es nicht ist, gibt es genau einen Wert. Das Feld existiert
trotzdem schon (`ActionData.damage_type`) und steht in jedem Tooltip: eine
Anzeige, die den Wert verschweigt, muesste beim Nachziehen ueberall gesucht
werden, und `ActionResolver._apply_armor()` ist der Haken, an dem die Ordnung
einmal haengt. Im MVP reicht die Kette den Schaden dort unveraendert durch.

## 8. Offene Punkte

* Kampfsystem: Aktionspunkte vs. feste Aktionen pro Zug
* **Schadensordnung.** Siehe 7a: bis auf Weiteres ist jede Aktion `normal`.
  Offen ist, ob es ueberhaupt mehrere Arten geben soll -- und wenn ja, ob sie
  multiplikativ wirken (dann bricht die Nachrechenbarkeit im Kopf, die
  `mitigate()` ausdruecklich schuetzt) oder als weiterer flacher, gedeckelter
  Abzug.
* ~~**Der dritte Slot des Molok ist selten bezahlbar.**~~ **Beantwortet, indem
  die Frage selbst weggefallen ist.** Die Zwischenstufe (Traglast 31 → 33,
  Chassis-SPD -2 → 0, Belagerungskanone ohne Strom) lockerte den Deckel, liess
  ihn aber stehen -- und damit blieb der Unsinn: zwei schwere Arme gingen (32
  von 33), drei volle Slots (35) nicht, und ein **Vireo mit zwei Puls-Blastern**
  riss die Traglast um genau einen Punkt (19/18). Der offensichtlichste
  Standard-Aufbau war verboten. Aus Spielersicht war das kaputt.

  Die Konsequenz war nicht, den Deckel weiter zu justieren, sondern ihn ganz zu
  streichen -- beide Bau-Budgets, Traglast wie Energiebedarf. Die Werkstatt ist
  kein Tuersteher mehr: **Energie ist Mana, Gewicht ist Tempo** (siehe den
  naechsten Punkt). Was einen vollen Aufbau bremst, ist der Preis im Kampf --
  Zuladung zieht SPD, Faehigkeiten kosten `en_cost` --, kein Riegel davor. Die
  natuerliche Obergrenze der Masse ist damit `spd >= 1`: man kann laden, bis der
  DROME festfaehrt. `power_draw`, `weight_capacity` und `power_output` stehen
  noch in den Teil-JSONs, werden aber von nichts mehr gelesen; sie fallen beim
  naechsten Neugenerieren des Teilesatzes weg. Ebenso entfaellt der
  Playtest-Schalter `playtest.ignore_build_limits`: ohne Budgetgrenze gibt es
  nichts mehr abzuschalten.
* **Aggro-Zahlen sind ungetestet.** Das Modell steht und ist durch Tests
  abgesichert, aber nie gespielt worden. Die Verhaeltnisse in 6c sind
  durchdacht, die Werte in `data/config.json` sind Setzungen. `decay_rate` und
  die Amtsinhaber-Boni steuern dieselbe Groesse -- die Traegheit der Zielwahl.
  Immer nur eins von beiden anfassen. Die eine Ausnahme ist bereits gemacht:
  beide wurden zusammen umgestellt, weil sie zusammen die Zielwahl blockiert
  haben (§6e, §6f). Ab hier gilt die Regel wieder.
* ~~**Energie ist im Kampf keine Ressource.**~~ **Beantwortet.** Der Befund
  stimmte: fuenf von sieben Aktionen kosteten hoechstens eine Zugregeneration
  und waren damit dauerhaft gratis; Energie wirkte real nur beim *Bauen*. Die
  Antwort ist nicht der vermutete Hebel (`en_regen` halbieren) geworden,
  sondern eine Trennung nach dem, was ein Teil IST:

  > **Masse bremst, Strom kostet.**

  Mechanische Teile zahlen in Gewicht und Tempo, energetische in Energie. Die
  Belagerungskanone ist Pulver und Hebel -- sie hat `power_draw` 0 und
  `en_cost` 0 und bezahlt ueber `DromeBuild.payload_slowdown()` an jedem
  Chassis zwei Punkte SPD. Vorher trug sie `power_draw` 5, und der
  Energiebedarf war ein Universalhebel, der auf jedem Teil klebte, egal ob es
  physikalisch Strom braucht: Balancing im Kostuem der Fiktion.

  Die Kosten der **Faehigkeiten** stehen seither nicht mehr nach Gefuehl,
  sondern nach Regel (`ability_cost()` in `tools/build_sample_parts.py`).
  Bezugsgroesse ist das Energiebudget der ERSTEN HAELFTE eines Gefechts, nicht
  des ganzen: gemessen ist ein DROME zehn bis vierzehn Mal am Zug, ueber ein
  ganzes Gefecht regeneriert ein Nimbus fast 280 Punkte. Bemisst man daran, ist
  die Faehigkeit in der Eroeffnung -- also dann, wenn sie entscheidet --
  praktisch gratis. Gemessen ueber 40 Gefechte kommen jetzt 0.5 (Stoersignal),
  1.9 (Reparaturdrohnen) und 5.3 (Orbit-Sog) Einsaetze je Gefecht heraus;
  `tests/test_battle.gd` haelt dieses Band fest. Die Decke fuer die teuerste
  Stufe ist der kleinste Kern im Bestand (`en_max` 40) -- eine Faehigkeit, die
  an einem Chassis grundsaetzlich unziehbar waere, ist ein Datenfehler und kein
  Balancing, und `check_ability_costs()` laesst sie nicht durch.

  Offen blieb davon ein Punkt: ob eine **Abklingzeit** die feinere Bremse waere
  als der Preis. Sie ist inzwischen gebaut -- als zweiter Weg, nicht als Ersatz,
  umschaltbar ueber `abilities.brake` in `data/config.json`:

  | | `energie` | `abklingzeit` | `beides` |
  |---|---|---|---|
  | Stoersignal | 0,47 | 0,45 | 0,42 |
  | Reparaturdrohnen | 1,88 | 1,80 | 1,50 |
  | Orbit-Sog | **5,35** | **3,08** | 3,05 |
  | Sieg / Niederlage | 17 / 22 | 18 / 21 | 19 / 20 |

  Einsaetze je Gefecht, 40 Gefechte je Modus, dieselben Seeds. Das Ergebnis ist
  eindeutiger als erwartet: **nur der Orbit-Sog aendert sich.** Die anderen
  beiden liegen ohnehin weit unter jeder Grenze -- sie werden nicht vom Preis
  begrenzt, sondern von der Bewertung der KI, und eine Provokation lohnt sich
  eben selten. Die Wartezeit greift also genau dort, wo der Preis nicht griff:
  bei der billigen Faehigkeit, die sich sonst jeden zweiten Zug ziehen laesst.

  Daraus folgen zwei Dinge. Erstens ist `beides` kaum von `abklingzeit` zu
  unterscheiden -- die Wartezeit dominiert, der Preis kommt danach gar nicht
  mehr zum Tragen. Zweitens sind die beiden Bremsen keine Alternativen fuer
  dieselbe Aufgabe: der Preis macht den **Kern** zur Entscheidung (ein
  Arkankern zieht oefter als ein Impulskern), die Wartezeit macht ihn
  gleichgueltig und dafuer den **Zug** zur Entscheidung -- nicht "kann ich mir
  das leisten", sondern "will ich sie jetzt oder gleich". Welche der beiden
  Fragen das Spiel stellen soll, ist eine Designentscheidung und keine
  Messung. Die Zahlen sagen nur, dass beide funktionieren.

  Die Ausgaenge verschieben sich ueber alle drei Modi um weniger als eine
  Standardabweichung -- keiner der Modi ist fuer sich genommen staerker oder
  schwaecher, sie fuehlen sich nur anders an. Genau deshalb ist der Schalter da.
* **`_can_strike()` schaetzt die Gefahr eines Feldes ueber `mov + range`.**
  Ein Strix mit Reichweite 7 und mov 4 bedroht damit alles im Umkreis von 11 --
  im Mittel 43 % einer 20x20-Karte. Weil die Kandidatenfelder der KI nur
  `mov` auseinanderliegen, fallen sie oft alle gemeinsam in diesen Radius oder
  gemeinsam heraus: gemessen in 55 % der Gefechtslagen gegen einen Strix,
  gegen einen Nahkaempfer nur in 14 %. `exposed_penalty` wird dort zu einem
  konstanten Abzug, der nichts mehr unterscheidet. Beobachtungsauftrag: faellt
  im Playtest auf, dass die KI sich nicht positioniert?
* **Das Gegner-Matching filtert den Koedersender heraus.** Gemessen ueber 400
  erzeugte Gegner: im rohen Wurf tragen ihn **11,2 %**, nach dem Abgleich gegen
  den Kampfwert nur noch **4,8 %**. Der Grund ist kein Fehler, sondern die
  Folge einer bewussten Entscheidung -- der Kampfwert sieht `aggro_bonus`
  nicht, ein Sender-Aufbau misst sich deshalb schwaecher und faellt aus der
  Toleranz. Damit ist eine gerade erst gebaute Mechanik bei Gegnern fast nie
  zu sehen. Entweder bekommt `aggro_bonus` ein Gewicht im Kampfwert, oder die
  Seltenheit ist gewollt. Nicht entschieden.
* **Der Kampfwert sieht `aggro_bonus` bewusst nicht.** Der Wert einer
  Aggro-Erhoehung haengt vollstaendig davon ab, wer sie traegt -- auf einem
  Molok viel, auf einem Strix nichts. Eine lineare Gewichtung waere eine
  erfundene Zahl. Der Preis dafuer steht eine Zeile hoeher.
* **Gegner koennen den Spieler provozieren.** Die Sperre sitzt beim
  Provozierten und wirkt in beide Richtungen; beim Spieler faerben sich die
  gesperrten Ziele grau, der Grund steht im Tooltip. Bislang passiert das
  wegen der Seltenheit des Senders kaum -- ob es sich gut anfuehlt, wenn es
  haeufiger passiert, muss ein Playtest zeigen.
* **Aggro-Reduktion** (Aggro abwerfen, sich tot stellen) existiert nicht. Das
  Modell traegt sie problemlos, sie ist nur nicht entworfen.
* Feldgroesse relativ zur Einheit: der Bot ueberragt sein Feld derzeit deutlich
  (Fussabdruck im Feld, Oberkoerper darueber hinaus). Ob das bei vollen Karten
  traegt, zeigt erst die erste echte Map.
* Progression: Teile-Loot vs. Crafting vs. beides
* Wie viele DROMEs bildet der Spieler pro Gefecht auf
* Mobile-Steuerung: direkte Tile-Beruehrung vs. Cursor + Bestaetigung

## 9. Vom Baukasten zur Klasse (Vorschlag, in Abstimmung -- Stand 2026-08)

> **Dieser Abschnitt ist noch nicht entschieden.** Er haelt eine Richtung fest,
> die gegengelesen und korrigiert wird, bevor Code faellt. Wo er einer frueheren
> Setzung widerspricht, ist das ausdruecklich vermerkt -- §3 (Zusammensetzung)
> und §5 (Archetypen durch Kombination) werden erst umgeschrieben, wenn die
> Richtung hier steht.

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
| **Kern** | die Energie-Identitaet | `en_max`, `en_regen`, plus kernspezifische Eigenheit (z.B. +Fernkampf, guenstigere Faehigkeiten, groessere Flaeche) | der Spielstil *innerhalb der Vernunft* -- was der Bot mit seinem Strom macht |
| **Ausruestung** | die Bestueckung in den Slots der Huelle | Waffen, Schilde, Support | die eigentliche Aufbau-Entscheidung (zwei Schilde vs. zwei Nahkampf; Runenstab vs. Schuetze) |
| **Upgrades** | Varianten von Kernen und Ausruestung | Modifikatoren (siehe 9d) | die *tiefe* Modularitaet, ueber Progression erworben |

Ergebnis: **DROMEs sind Klassen, keine modularen Bots.** Man bekommt immer den
optischen Strix und entscheidet dann *innerhalb* der Klasse -- Kern, Bestueckung,
Upgrades. Die Themen bleiben an der Huelle haengen: Strix = wenig Integritaet,
harte Treffer; Molok = ist da und geht nicht.

### 9c. Warum die Huelle EIN Teil ist -- und die SVG-Technik das ueberlebt

Das ist die Stelle, an der der Vorschlag an §2/§5 stossen koennte -- und es nicht
tut. **Die Zusammenlegung ist eine Sache der Werkstatt und der Daten, nicht des
Renderers.** Kopf, Koerper und Fuesse bleiben drei getrennte SVGs, die zur
Laufzeit ueber Anker zusammengesetzt werden; an der Projektion, den vier
Richtungen und dem Asset-Budget (§5: 24 SVGs je Set) aendert sich **nichts**.

Was sich aendert, ist allein die Bindung: die drei Rahmenteile eines Sets werden
als **Set-Tripel** gefuehrt und als eine „Huelle" gewaehlt. Der Spieler trifft
eine Entscheidung statt dreier, und die drei koennen gar nicht mehr auseinander
laufen. Die Werte der Huelle sind weiterhin die Summe ihrer drei Teile (wie
heute). „Summe statt Produkt" (§2) bleibt vollstaendig erhalten -- wir nehmen nur
die drei Frame-Faktoren aus der Kombinatorik heraus, die ohnehin nie frei sein
sollten.

> **Revidiert §5.** „Ausruestung ist set-uebergreifend nutzbar" bleibt wahr.
> „Rahmenteile werden quer durch alle Sets kombiniert" wird zu: Rahmenteile
> sind an ihr Set gebunden und bilden die Huelle. Der gemeinsame
> Ausruestungs-Pool ueberlebt unveraendert.

### 9d. Wohin die Modularitaet wandert: Upgrades

Hier lebt das „bau dir deinen eigenen" jetzt. Beispiele aus der Vision:

* **Ausruestung:** eine Schienen-Lanze, die eine Reihe Gegner durchschlaegt,
  ODER eine, die zweimal schiesst.
* **Kern:** einer, der weniger Energie je Faehigkeit zieht, ODER einer, der mehr
  zieht und dafuer die Flaeche der Faehigkeit vergroessert.

Das Muster ist jedes Mal ein **Tausch, keine reine Aufwertung** -- Durchschlag
gegen Doppelschuss, Effizienz gegen Wucht. Genau so bleibt es eine
Entscheidung und wird nicht zur Pflichtreihenfolge.

Drei Dinge sind daran noch offen und gehoeren entschieden, bevor gebaut wird:

1. **Form der Upgrades.** Varianten-Gegenstaende (man besitzt „Lanze
   Mk-Durchschlag" als eigenes Teil) oder Mod-Slots am Teil (die Lanze hat N
   Steckplaetze)? Ersteres ist einfacher und passt zum Loot-Gedanken; Letzteres
   ist flexibler, aber ein zweites Inventarsystem.
2. **Silhouette (§3d beisst hier).** Ein Upgrade, das die **Funktion** aendert --
   die Lanze trifft jetzt eine Reihe --, ist nach §3d verpflichtet, sich an der
   FORM zu zeigen; sonst trifft der Spieler seine Entscheidung ohne die
   Information, die das deterministische Kampfsystem verspricht. Ein Upgrade, das
   nur **Zahlen** dreht (−`en_cost`), braucht keinen Formhinweis. Vorschlag:
   funktionsaendernde Upgrades bekommen einen kleinen, billigen Anbau-Tell
   (ein Muendungsaufsatz, ein zweiter Emitter) ueber einen Zusatzanker -- teure
   Vollvarianten nur fuer wenige Schluesselteile (§7).
3. **Herkunft.** Kommen Upgrades aus Beute, Crafting oder beidem? Das haengt am
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

### 9g. Nebenentscheidung: die SVG-Werkstatt

Du willst die eigenstaendige SVG-Werkstatt (`index.html` + `main.py`) aus dem
Fluss nehmen, weil die Godot-Werkstatt Aufbau und Optik ohnehin zeigt. **Eine
Praezisierung, damit die Entscheidung mit offenen Augen faellt:** die SVG-Seite
ist nicht nur eine zweite Bau-Ansicht, sie ist das **Autoren-Werkzeug** --
Bauteile zeichnen, Anker setzen, Paletten pflegen (`main_menu.gd` sagt das
selbst). Die Godot-Werkstatt kann heute *bauen und ansehen*, aber nicht
*Anker setzen*. Als Spielflaeche kann die SVG-Seite also sofort weg; als
Zeichen-/Anker-Werkzeug braucht sie einen Nachfolger oder eine bewusste
Entscheidung, dass neue Teile vorerst nicht mehr entstehen. Zu klaeren, bevor
sie geloescht wird.

### 9h. Offene Entscheidungen (bitte gegenlesen)

1. **Kern-Bindung:** universal (jeder Kern in jede Huelle) oder thematische
   Bindung? Vorschlag: universal -- der Kern ist die Stil-Achse, kein Rahmen,
   und ein fremder Kern macht keinen „weirden" Bot, solange die Huelle stimmt.
2. **Kern-Optik:** Der Kern sitzt sichtbar in der Brust-/Rueckenplatte. Bei
   universellen Kernen: auf die Set-Palette der Huelle umfaerben (Farbe ist ein
   Parameter, §2) oder eigener Look je Kern? Vorschlag: umfaerben, dann sieht
   jeder Kern in jeder Huelle heimisch aus.
3. **Upgrade-Form:** Varianten-Gegenstaende oder Mod-Slots? (9d.1)
4. **Upgrade-Silhouette:** billiger Anbau-Tell fuer funktionsaendernde Upgrades
   -- ja, und wie sparsam? (9d.2)
5. **Roster/Progression:** jetzt (MVP) oder spaeter? Woher kommt der Nachschub?
6. **Klassen-Anzahl:** reichen die vier Huellen fuers Erste, oder brauchst du
   zum Ausprobieren mehr?
7. **SVG-Werkstatt:** als Spielflaeche raus (bestaetigt) -- was wird aus dem
   Anker-Autorenwerkzeug? (9g)
