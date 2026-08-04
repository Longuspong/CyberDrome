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
| **Kern** | 1 | Identitaet der Einheit: Energie, Fertigkeitspool, Grundwerte |
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
| `bot2` HX-Molok // Juggernaut | breit, gedrungen, kantig | den dritten Anker (Schulterpod) |
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

`tools/build_sample_parts.py` prueft das bei jedem Lauf: die Teile werden
uniform normiert und ihre Risse verglichen. Ab 0.80 Deckung bricht der
Generator bei Ausruestung ab, bei Rahmenteilen meldet er einen Hinweis. Wie das
Mass funktioniert und welche Merkmale taugen, steht in `parts/README.md`,
Abschnitt 6a.

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

## 6. Zustaende und Animation

Bewusst **noch nicht** entschieden – erst wenn die Statik steht. Notiert als
Optionen, damit das Anker-Format sie nicht ausschliesst:

* Animation ueber Transformationen der Teil-Gruppen (Wippen, Rueckstoss,
  Trefferzucken). Braucht keine neuen Dateien und ist der bevorzugte Weg.
* Zusaetzliche Anker wie `muzzle` oder `fx_*` fuer Projektil- und Effekt-Spawns.
  Das Format erlaubt beliebige Zusatzanker bereits heute.
* Eigene Teil-Varianten fuer Zustaende (beschaedigt, offline) – teuer, daher nur
  fuer wenige Schluesselteile.

## 7. Offene Punkte

* Kampfsystem: Aktionspunkte vs. feste Aktionen pro Zug
* Feldgroesse relativ zur Einheit: der Bot ueberragt sein Feld derzeit deutlich
  (Fussabdruck im Feld, Oberkoerper darueber hinaus). Ob das bei vollen Karten
  traegt, zeigt erst die erste echte Map.
* Progression: Teile-Loot vs. Crafting vs. beides
* Wie viele DROMEs bildet der Spieler pro Gefecht auf
* Mobile-Steuerung: direkte Tile-Beruehrung vs. Cursor + Bestaetigung
