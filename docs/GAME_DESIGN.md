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
Anker in seine JSON schreibt. `parts/bot2` (HX-Molok) zeigt den Drei-Slot-Fall.

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

Der Code ist bewusst getrennt vom Datei-Slug (`scout_body`), der die Dateinamen
traegt und beim Stoebern im Ordner lesbar bleiben soll. Ein exportiertes
Loadout enthaelt beides plus den Klarnamen – damit laesst es sich ohne die
Bibliothek lesen.

## 3b. Die drei Sets und was sie beweisen sollen

Ein Set ist eine Autoren-Schublade, kein Bausatz (siehe Abschnitt 5). Die drei
mitgelieferten Sets decken bewusst je einen anderen Fall ab:

| Set | Silhouette | zeigt |
|---|---|---|
| `bot1` RX-Vireo // Scout | schlank, kantig, zweibeinig | den Standardfall: zwei Ausruestungsanker |
| `bot2` HX-Molok // Juggernaut | breit, gedrungen, kantig | den dritten Anker (Schulterpod) |
| `bot3` AR-Nimbus // Technomant | **rund**, flacher Helm, **Fahrgestell statt Beinen** | dass Formensprache und Fortbewegung frei sind |

`bot3` ist der Gegenentwurf zu den ersten beiden: Rotationskoerper statt
gestapelter Quader, ein weit auskragender flacher Helm statt eines Visierkopfs,
zwei grosse Raeder auf einer Achse statt Beinen. Technisch aendert das nichts –
es ist derselbe Anker-Vertrag, dieselbe Projektion, dieselben vier Richtungen.
Genau das ist der Punkt: ein Rad ist nur ein Rotationskoerper um die
Bot-Links-Achse, kein Sonderfall in Code oder Format.

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

Ausruestung ist set-uebergreifend nutzbar, solange die Anker passen. Ein Teil
schraenkt sich nur dann auf bestimmte Anker ein, wenn es das ueber `slots`
ausdruecklich tut – wie der Drohnen-Pod, der auf die Schulter gehoert.

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
