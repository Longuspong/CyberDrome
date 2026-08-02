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
| Grafikstil | **SVG, modular** – ausdruecklich *kein* Pixelart |

## 2. Warum SVG statt Pixelart

Das ist die zentrale Lehre aus dem Vorgaengerprojekt: dort ist die
Asset-Produktion an der Sprite-Kombinatorik gescheitert.

Bei modularen Einheiten mit vier Blickrichtungen waechst der Aufwand
multiplikativ. Ein Bot aus Kern + Kopf + Koerper + Fuessen + zwei
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
   und Spielerfarben sind reines Umfaerben, kein neues Asset.
3. **Vier Richtungen sind das Maximum** – West wird aus Ost gespiegelt, das
   halbiert die Profilansichten. Keine Zwischenwinkel, keine Isometrie-Achtel.

Die Grenze der Skalierbarkeit ist damit nicht mehr die Zeichenarbeit, sondern
die Rendering-Kosten auf Android (siehe `docs/GODOT_INTEGRATION.md`).

## 3. Die Drone

Eine Drone ist die Spieleinheit. Sie besteht aus:

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

## 4. Vier Richtungen

`north` (vom Betrachter weg), `south` (zum Betrachter), `east`, `west`.

Konventionen:

* `west` wird aus `east` gespiegelt – das Generator-Skript macht das automatisch.
* **`links` / `rechts` in Ankernamen sind bildschirmseitig gemeint**, nicht aus
  Sicht des Bots. Sonst waeren die Namen zwischen Nord- und Suedansicht getauscht.
* In der Nordansicht liegt die Ausruestung *hinter* dem Koerper. Das steuert
  das Koerper-Teil ueber `slot_z` – die Ausruestung selbst braucht dafuer keine
  eigene Variante.
* In den Profilansichten wird nicht automatisch gespiegelt: beide Arme zeigen
  nach vorn.

## 5. Asset-Budget

Pro Set (= Bot-Familie) bei vier Richtungen:

| Teil | Dateien |
|---|---|
| Koerper | 4 |
| Kopf | 4 |
| Fuesse | 4 |
| Kern | 4 |
| Ausruestung, je Stueck | 4 |

Ein Set mit zwei Ausruestungs­gegenstaenden = **24 SVGs**. Ausruestung ist
set-uebergreifend nutzbar, solange die Anker passen – die Bibliothek kann im Tool
set-uebergreifend angezeigt werden.

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
* Gitter: quadratisch oder hexagonal (die Tile-Raute im Tool ist bislang nur
  eine optische Orientierungshilfe, keine Festlegung)
* Progression: Teile-Loot vs. Crafting vs. beides
* Wie viele Drones bildet der Spieler pro Gefecht auf
* Mobile-Steuerung: direkte Tile-Beruehrung vs. Cursor + Bestaetigung
